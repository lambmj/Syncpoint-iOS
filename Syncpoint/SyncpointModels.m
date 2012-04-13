//
//  SyncpointModels.m
//  Syncpoint
//
//  Created by Jens Alfke on 3/7/12.
//  Copyright (c) 2012 Couchbase, Inc. All rights reserved.
//

#import "SyncpointModels.h"
#import "SyncpointInternal.h"
#import "CouchModelFactory.h"
#import "TDMisc.h"
#import "CollectionUtils.h"
#import <Security/SecRandom.h>


@interface CouchModel (Internal)
- (CouchModel*) getModelProperty: (NSString*)property;
- (void) setModel: (CouchModel*)model forProperty: (NSString*)property;
@end


static NSString* randomString(void) {
    uint8_t randomBytes[16];    // 128 bits of entropy
    SecRandomCopyBytes(kSecRandomDefault, sizeof(randomBytes), randomBytes);
    return TDHexString(randomBytes, sizeof(randomBytes), true);
}


//TODO: This would be useful as a method in CouchModelFactory or CouchDatabase...
static NSEnumerator* modelsOfType(CouchDatabase* database, NSString* type) {
    NSEnumerator* e = [[database getAllDocuments] rows];
    LogTo(Syncpoint, @"modelsOfType %@ for database with %u docs", type, [[[database getAllDocuments] rows] count]);
    return [e my_map: ^(CouchQueryRow* row) {
//        LogTo(Syncpoint, @"modelsOfType row type %@", [row.documentProperties objectForKey: @"type"]);
        if ([type isEqual: [row.documentProperties objectForKey: @"type"]]) {
//            LogTo(Syncpoint, @"equal %@", row.documentProperties.description);
            CouchModel* model = [CouchModel modelForDocument: row.document];
//            LogTo(Syncpoint, @"class %@", [model class]);
            return model;
        }
        else
            return nil;
    }];
}




@implementation SyncpointModel

@dynamic state;

- (bool) isActive {
    return [self.state isEqual: @"active"];
}

// FIX: This name-mapping should be moved into CouchModel itself somehow.
- (CouchModel*) getModelProperty: (NSString*)property {
    return [super getModelProperty: [property stringByAppendingString: @"_id"]];
}

- (void) setModel: (CouchModel*)model forProperty: (NSString*)property {
    [super setModel: model forProperty: [property stringByAppendingString: @"_id"]];
}

+ (Class) classOfProperty: (NSString*)property {
    if ([property hasSuffix: @"_id"])
        property = [property substringToIndex: property.length-3];
    return [super classOfProperty: property];
}

@end




@implementation SyncpointSession
{
    NSMutableArray* _toBeInstalled;
}

@dynamic owner_id, oauth_creds, pairing_creds, control_database, control_db_synced;

- (bool) isPaired {
    return [self.state isEqual: @"paired"];
}

- (bool) isReadyToPair {
    return !![self getValueOfProperty:@"pairing_token"];
}

- (bool) controlDBSynced {
    return self.control_db_synced;
}

+ (SyncpointSession*) sessionInDatabase: (CouchDatabase *)database {
    NSString* sessID = [[NSUserDefaults standardUserDefaults] objectForKey:@"Syncpoint_SessionDocID"];
    if (!sessID)
        return nil;
    CouchDocument* doc = [database documentWithID: sessID];
    if (!doc)
        return nil;
    if (!doc.properties) {
        // Oops -- the session ID in user-defaults is out of date, so clear it
        [[NSUserDefaults standardUserDefaults] removeObjectForKey: @"Syncpoint_SessionDocID"];
        return nil;
    }
    return [self modelForDocument: doc];
}


+ (SyncpointSession*) makeSessionInDatabase: (CouchDatabase*)database
                                      appId: (NSString*)appId
                                      error: (NSError**)outError
{
    LogTo(Syncpoint, @"Creating session for %@ in %@", appId, database);
    SyncpointSession* session = [[self alloc] initWithNewDocumentInDatabase: database];
    [session setValue: appId ofProperty: @"app_id"];
    session.state = @"new";
    NSDictionary* oauth_creds = $dict({@"consumer_key", randomString()},
                                      {@"consumer_secret", randomString()},
                                      {@"token_secret", randomString()},
                                      {@"token", randomString()});
    session.oauth_creds = oauth_creds;

    NSDictionary* pairingCreds = $dict({@"username", [@"pairing-" stringByAppendingString:randomString()]},
                                  {@"password", randomString()});
    session.pairing_creds = pairingCreds;
    
    if (![[session save] wait: outError]) {
        Warn(@"SyncpointSession: Couldn't save new session");
        return nil;
    }
    
    NSString* sessionID = session.document.documentID;
    LogTo(Syncpoint, @"...session ID = %@", sessionID);
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject: sessionID forKey: @"Syncpoint_SessionDocID"];
    [defaults synchronize];
    return session;
}


- (id) initWithDocument: (CouchDocument*)document {
    self = [super initWithDocument: document];
    if (self) {
        // Register the other model classes with the database's model factory:
        CouchModelFactory* factory = self.database.modelFactory;
        [factory registerClass: @"SyncpointChannel" forDocumentType: @"channel"];
        [factory registerClass: @"SyncpointSubscription" forDocumentType: @"subscription"];
        [factory registerClass: @"SyncpointInstallation" forDocumentType: @"installation"];
    }
    return self;
}

- (NSDictionary*) pairingUserProperties {
    NSString* username = [self.pairing_creds objectForKey:@"username"];
    NSString* password = [self.pairing_creds objectForKey:@"password"];
    NSAssert(username, @"needs the pairing username set first");
    NSAssert(password, @"needs the pairing password set first");
    
    return $dict({@"_id", $sprintf(@"org.couchdb.user:%@", username)},
                 {@"name", username},
                 {@"type", @"user"},
                 {@"sp_oauth",self.oauth_creds},
                 {@"pairing_state", @"new"},
                 {@"pairing_type",[self getValueOfProperty:@"pairing_type"]},
                 {@"pairing_token",[self getValueOfProperty:@"pairing_token"]},
                 {@"pairing_app_id",[self getValueOfProperty:@"app_id"]},
                 {@"roles", [NSArray array]},
                 {@"password", password});
}

- (NSError*) error {
    if (![self.state isEqual: @"error"])
        return nil;
    NSDictionary* errDict = [self getValueOfProperty: @"error"];
    int code = [$castIf(NSNumber, [errDict objectForKey: @"errno"]) intValue];
    NSString* message = $castIf(NSString, [errDict objectForKey: @"message"]);
    return [NSError errorWithDomain: NSPOSIXErrorDomain
                               code: (code ? code : -1)     // don't allow a zero code
                           userInfo: $dict({NSLocalizedDescriptionKey, message})];
}


- (BOOL) clearState: (NSError**)outError {
    self.state = @"new";
    [self setValue: nil ofProperty: @"error"];
    return [[self save] wait: outError];
}


- (SyncpointChannel*) makeChannelWithName: (NSString*)name
                                    error: (NSError**)outError
{
    LogTo(Syncpoint, @"Create channel named '%@'", name);
    SyncpointChannel* channel = [[SyncpointChannel alloc] initWithNewDocumentInDatabase: self.database];
    [channel setValue: @"channel" ofProperty: @"type"];
    [channel setValue: self.owner_id ofProperty: @"owner_id"];
    channel.state = @"new";
    channel.name = name;
    return [[channel save] wait: outError] ? channel : nil;
}


- (SyncpointChannel*) channelWithName: (NSString*)name andOwner: (NSString*)ownerId{
    // TODO: Make this into a view query
    for (CouchQueryRow* row in [[self.database getAllDocuments] rows]) {
        if ([@"channel" isEqual:[row.documentProperties objectForKey: @"type"]]) {
            NSString* rowState = [row.documentProperties objectForKey: @"state"];
            NSString* rowName = [row.documentProperties objectForKey: @"name"];
            NSString* rowOwnerId = [row.documentProperties objectForKey: @"owner_id"];
            
            LogTo(Syncpoint, @"Saw channel named %@ with owner_id %@ and state %@", 
                  rowName,
                  rowOwnerId,
                  rowState);
            if (![@"error" isEqual:rowState] && [rowName isEqual: name] && [rowOwnerId isEqual:ownerId]) {
                LogTo(Syncpoint, @"found doc %@", row.document.description);
                SyncpointChannel* channel = [SyncpointChannel modelForDocument: row.document];
                LogTo(Syncpoint, @"found channel %@", channel.description);
                return channel;
            }
        }
    }
    LogTo(Syncpoint, @"channelWithName %@ returning nil ", name);

    return nil;
}

- (SyncpointChannel*) channelWithName: (NSString*)name {
    return [self channelWithName:name andOwner:self.owner_id];
}


- (SyncpointInstallation*) installChannelNamed: (NSString*)channelName
                                    toDatabase: (CouchDatabase*)localDatabase
                                         error: (NSError**)outError
{
    LogTo(Syncpoint, @"Install channel named '%@' to %@", channelName, localDatabase);
    if (self.isPaired && [self controlDBSynced]) {
        SyncpointChannel* channel = [self channelWithName: channelName];
        if (!channel) {
//            return nil;
            channel = [self makeChannelWithName: channelName error: outError];            
        }
        return [channel makeInstallationWithLocalDatabase: localDatabase error: outError];
    } else {
        // If not activated yet, make a note of what to install:
        LogTo(Syncpoint, @"    ...deferring till session becomes active");
        if (!_toBeInstalled)
            _toBeInstalled = $marray();
        // TODO if we persist _toBeInstalled to user defaults we can allow
        // users to create databases before pairing
//        OR if we require that channelName and localDatabase name are the same
//        then we can do a call to _all_dbs at channel kick off time to rebuild this array.
        [_toBeInstalled addObject: $array(channelName, localDatabase)];
        if (outError) *outError = nil;
        return nil;
    }
}


- (void) doPendingInstalls {
    if (_toBeInstalled && self.isPaired && [self controlDBSynced]) {
        LogTo(Syncpoint, @"Installing %u pending channels...", _toBeInstalled.count);
        NSMutableArray* toInstall = _toBeInstalled;
        _toBeInstalled = nil;
        for (NSArray* info in toInstall) {
            [self installChannelNamed: [info objectAtIndex: 0]
                           toDatabase: [info objectAtIndex: 1]
                                error: nil];
        }
    }
}


- (void) didSyncControlDB {
    if(![self controlDBSynced]) {
        self.control_db_synced = TRUE;
        [[self save] wait: nil];
        [self doPendingInstalls];
    }
}


- (void) didLoadFromDocument {
    [super didLoadFromDocument];
    [self doPendingInstalls];
}


- (NSEnumerator*) readyChannels {
    // TODO: Make this into a view query
    return [modelsOfType(self.database, @"channel") my_map: ^(SyncpointChannel* channel) {
        return channel.isReady ? channel : nil;
    }];
}


- (NSEnumerator*) activeSubscriptions {
    // TODO: Make this into a view query
    return [modelsOfType(self.database, @"subscripton") my_map: ^(SyncpointSubscription* sub) {
        return sub.isActive ? sub : nil;
    }];
}


- (NSSet*) installedSubscriptions {
    NSMutableSet* subscriptions = [NSMutableSet set];
    for (SyncpointInstallation* inst in self.allInstallations)
        [subscriptions addObject: inst.subscription];
    return subscriptions;
}


- (NSEnumerator*) allInstallations {
    // TODO: Make this into a view query
    return [modelsOfType(self.database, @"installation") my_map: ^(SyncpointInstallation* inst) {
        return ([inst.state isEqual: @"created"] && inst.session == self) ? inst : nil;
    }];
}


@end




@implementation SyncpointChannel

@dynamic name, owner_id, cloud_database;

- (bool) isReady {
    return [self.state isEqual: @"ready"];
}


- (SyncpointSubscription*) subscription {
    // TODO: Make this into a view query
    for (SyncpointSubscription* sub in modelsOfType(self.database, @"subscription"))
        if (sub.channel == self)
            return sub;
    return nil;
}

- (CouchDatabase*) localDatabase {
    SyncpointInstallation* inst = [self installation];
    if (inst) {
        return [inst localDatabase];
    } else {
        return nil;
    }
}

- (SyncpointInstallation*) installation {
    // TODO: Make this into a view query
    for (SyncpointInstallation* inst in modelsOfType(self.database, @"installation"))
        if (inst.channel == self && inst.isLocal)
            return inst;
    return nil;
}


- (SyncpointInstallation*) makeInstallationWithLocalDatabase: (CouchDatabase*)localDatabase
                                                       error: (NSError**)outError

{
    SyncpointSubscription* subscription = self.subscription;
    SyncpointInstallation* installation = self.installation;
    if (!subscription) {
        if (installation)
            Warn(@"already have an install doc %@ with no subscription for channel %@",
                 installation, self);
        subscription = [self subscribe: outError];
        if (!subscription)
            return nil;
    }
    
    if (!installation)
        installation = [subscription makeInstallationWithLocalDatabase: localDatabase
                                                                 error: outError];
    return installation;
}


- (SyncpointSubscription*) subscribe: (NSError**)outError {
    LogTo(Syncpoint, @"Subscribing to %@", self);
    SyncpointSubscription* sub = [[SyncpointSubscription alloc] initWithNewDocumentInDatabase: self.database];
    [sub setValue: @"subscription" ofProperty: @"type"];
    sub.state = @"active";
    [sub setValue: [self getValueOfProperty: @"owner_id"] ofProperty: @"owner_id"];
    sub.channel = self;
    return [[sub save] wait: outError] ? sub : nil;
}

@end




@implementation SyncpointSubscription

@dynamic channel;


- (SyncpointInstallation*) installation {
    return self.channel.installation;
}


- (SyncpointInstallation*) allInstallations {
    SyncpointChannel* channel = self.channel;
    // TODO: Make this into a view query
    for (SyncpointInstallation* inst in modelsOfType(self.database, @"installation"))
        if (inst.channel == channel)
            return inst;
    return nil;
}


- (SyncpointInstallation*) makeInstallationWithLocalDatabase: (CouchDatabase*)localDB
                                                       error: (NSError**)outError
{
    NSString* name;
    if (localDB)
        name = localDB.relativePath;
    else { 
        name = [@"channel-" stringByAppendingString: randomString()];
        localDB = [self.database.server databaseNamed: name];
    }
    
    LogTo(Syncpoint, @"Installing %@ to %@", self, localDB);
    if (![localDB ensureCreated: nil]) {
        Warn(@"SyncpointSubscription could not create channel db %@", name);
        return nil;
    }

    SyncpointInstallation* inst = [[SyncpointInstallation alloc] initWithNewDocumentInDatabase: self.database];
    [inst setValue: @"installation" ofProperty: @"type"];
    inst.state = @"created";
    inst.session = [SyncpointSession sessionInDatabase: self.database];
    [inst setValue: [self getValueOfProperty: @"owner_id"] ofProperty: @"owner_id"];
    inst.channel = self.channel;
    inst.subscription = self;
    [inst setValue: name ofProperty: @"local_db_name"];
    return [[inst save] wait: outError] ? inst : nil;
}


- (BOOL) unsubscribe: (NSError**)outError {
    SyncpointInstallation* inst = self.installation;
    if (inst && ![inst uninstall: outError])
        return NO;
    return [[self deleteDocument] wait: outError];
    //????: Is this how to do it?
}


@end




@implementation SyncpointInstallation

@dynamic subscription, channel, session;

- (CouchDatabase*) localDatabase {
    if (!self.isLocal)
        return nil;
    NSString* name = $castIf(NSString, [self getValueOfProperty: @"local_db_name"]);
    return name ? [self.database.server databaseNamed: name] : nil;
}

- (bool) isLocal {
    SyncpointSession* session = [SyncpointSession sessionInDatabase: self.database];
    return [session.document.documentID isEqual: [self getValueOfProperty: @"session_id"]];
}

- (BOOL) uninstall: (NSError**)outError {
//    todo delete the database file here
    return [[self deleteDocument] wait: outError];
}

@end
