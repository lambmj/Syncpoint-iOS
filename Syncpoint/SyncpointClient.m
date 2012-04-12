//
//  SyncpointClient.m
//  Syncpoint
//
//  Created by Jens Alfke on 2/23/12.
//  Copyright (c) 2012 Couchbase, Inc. All rights reserved.
//

#import "SyncpointClient.h"
#import "SyncpointModels.h"
#import "SyncpointInternal.h"
#import "CouchCocoa.h"
#import "TDMisc.h"
#import "MYBlockUtils.h"


#define kLocalControlDatabaseName @"sp_control"
#define kRemoteHandshakeDatabaseName @"sp_handshake"


@interface SyncpointClient ()
@property (readwrite, nonatomic) SyncpointState state;
@end


@implementation SyncpointClient
{
    @private
    NSURL* _remote;
    NSString* _appId;
    CouchServer* _server;
    CouchDatabase* _localControlDatabase;
    SyncpointSession* _session;
    CouchReplication *_controlPull;
    CouchReplication *_controlPush;
    BOOL _observingControlPull;
    SyncpointState _state;
}


@synthesize localServer=_server, state=_state, session=_session, appId=_appId;


- (id) initWithLocalServer: (CouchServer*)localServer
              remoteServer: (NSURL*)remoteServerURL
                     appId: (NSString*)syncpointAppId
                     error: (NSError**)outError
{
    CAssert(localServer);
    CAssert(remoteServerURL);
    self = [super init];
    if (self) {
        _server = localServer;
        _remote = remoteServerURL;
        _appId = syncpointAppId;
        // Create the control database on the first run of the app.
        _localControlDatabase = [_server databaseNamed: kLocalControlDatabaseName];
        if (![_localControlDatabase ensureCreated: outError])
            return nil;
        _localControlDatabase.tracksChanges = YES;
        _session = [SyncpointSession sessionInDatabase: _localControlDatabase];

        if (_session) {
            if (_session.isActive) {
                LogTo(Syncpoint, @"Session is active");
                [self connectToControlDB];
            } else if (nil != _session.error) {
                LogTo(Syncpoint, @"Session has error: %@", _session.error.localizedDescription);
                _state = kSyncpointHasError;
                [self pairSession];
            } else {
                LogTo(Syncpoint, @"Session is not active");
                [self pairSession];
            }
        } else {
            LogTo(Syncpoint, @"No session -- authentication needed");
            _state = kSyncpointUnauthenticated;
        }
    }
    return self;
}


- (void)dealloc {
    [self stopObservingControlPull];
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}


- (BOOL) isActivated {
    return _state > kSyncpointActivating;
}

- (void) createSessionWithType: (NSString*)sessionType andToken: (NSString*)sessionToken {
    if (_session.isActive) return;
    _session = [SyncpointSession makeSessionInDatabase: _localControlDatabase
                                              withType: sessionType
                                                 token: sessionToken
                                                 appId: _appId
                                                 error: nil];   // TODO: Report error
    if (_session)
        [self pairSession];
    else
        self.state = kSyncpointUnauthenticated;
}


#pragma mark - CONTROL DATABASE & SYNC:


- (CouchReplication*) pullControlDataFromDatabaseNamed: (NSString*)dbName {
    NSURL* url = [NSURL URLWithString: dbName relativeToURL: _remote];
    return [_localControlDatabase pullFromDatabaseAtURL: url];
}

- (CouchReplication*) pushControlDataToDatabaseNamed: (NSString*)dbName {
    NSURL* url = [NSURL URLWithString: dbName relativeToURL: _remote];
    return [_localControlDatabase pushToDatabaseAtURL: url];
}

- (void) pairingDidComplete: (CouchDocument*)userDoc {
    NSMutableDictionary* props = [[userDoc properties] mutableCopy];

    [_session setValue:@"active" forKey:@"state"];
    [_session setValue:[props valueForKey:@"control_database"] ofProperty:@"control_database"];
    RESTOperation* op = [_session save];
    [op onCompletion:^{
        LogTo(Syncpoint, @"Session is now active!");
        [props setObject:[NSNumber numberWithBool:YES] forKey:@"_deleted"];
        [[userDoc currentRevision] putProperties: props];
    }];
}

- (void) waitForPairingToComplete: (CouchDocument*)userDoc {
    MYAfterDelay(5.0, ^{
        RESTOperation* op = [userDoc GET];
        [op onCompletion:^{
            NSDictionary* resp = $castIf(NSDictionary, op.responseBody.fromJSON);
            NSString* state = [resp objectForKey:@"state"];
            if ([state isEqualToString:@"paired"]) {
                [self pairingDidComplete: userDoc];
            } else {
                [self waitForPairingToComplete: userDoc];                
            }
        }];
        [op start];
    });
}

- (void) savePairingUserToRemote {
    CouchServer* anonRemote = [[CouchServer alloc] initWithURL: _remote];
    RESTResource* remoteSession = [[RESTResource alloc] initWithParent: anonRemote relativePath: @"_session"];
    RESTOperation* op = [remoteSession GET];
    [op onCompletion: ^{
        NSDictionary* resp = $castIf(NSDictionary, op.responseBody.fromJSON);
        NSString* userDbName = [[resp objectForKey:@"info"] objectForKey:@"authentication_db"];
        CouchDatabase* anonUserDb = [anonRemote databaseNamed:userDbName];
        NSDictionary* userProps = [_session pairingUserProperties];
        CouchDocument* newUserDoc = [anonUserDb documentWithID:[userProps objectForKey:@"_id"]];
        RESTOperation* docPut = [newUserDoc putProperties:userProps];
        [docPut onCompletion:^{
            NSString* remoteURLString = [[_remote absoluteString] 
                                         stringByReplacingOccurrencesOfString:@"://" 
                                         withString:$sprintf(@"://%@:%@@", 
                                                             [_session.pairing_creds objectForKey:@"username"], 
                                                             [_session.pairing_creds objectForKey:@"password"])];
            CouchServer* userRemote = [[CouchServer alloc] initWithURL: [NSURL URLWithString:remoteURLString]];
            CouchDatabase* userUserDb = [userRemote databaseNamed:userDbName];
            CouchDocument* readUserDoc = [userUserDb documentWithID: [newUserDoc documentID]];
            [self waitForPairingToComplete: readUserDoc];
        }];
    }];
    [op start];
}

- (void) pairSession {
    LogTo(Syncpoint, @"Pairing session...");
    Assert(!_session.isActive);
    [_session clearState: nil];
    self.state = kSyncpointActivating;
    [self savePairingUserToRemote];
}


// Begins observing document changes in the _localControlDatabase.
- (void) observeControlDatabase {
    Assert(_localControlDatabase);
    [[NSNotificationCenter defaultCenter] addObserver: self 
                                             selector: @selector(controlDatabaseChanged)
                                                 name: kCouchDatabaseChangeNotification 
                                               object: _localControlDatabase];
}

- (void) controlDatabaseChanged {
    if (_state > kSyncpointActivating) {
        LogTo(Syncpoint, @"Control DB changed");
        [self getUpToDateWithSubscriptions];
        
    } else if (_session.isActive) {
        LogTo(Syncpoint, @"Session is now active!");
        [_controlPull stop];
        _controlPull = nil;
        [_controlPush stop];
        _controlPush = nil;
        [self connectToControlDB];
    } else if (_state != kSyncpointHasError) {
        NSError* error = _session.error;
        if (error) {
            self.state = kSyncpointHasError;
            LogTo(Syncpoint, @"Session has error: %@", error);
        }
    }
}


// Start bidirectional sync with the control database.
- (void) connectToControlDB {
    NSString* controlDBName = _session.control_database;
    LogTo(Syncpoint, @"Syncing with control database %@", controlDBName);
    Assert(controlDBName);
    
    // During the initial sync, make the pull non-continuous, and observe when it stops.
    // That way we know when the control DB has been fully updated from the server.
    _controlPull = [self pullControlDataFromDatabaseNamed: controlDBName];
    [_controlPull addObserver: self forKeyPath: @"running" options: 0 context: NULL];
    _observingControlPull = YES;
    
    _controlPush = [self pushControlDataToDatabaseNamed: controlDBName];
    _controlPush.continuous = YES;

    self.state = kSyncpointUpdatingControlDatabase;
}


// Observes when the initial _controlPull stops running, after -connectToControlDB.
- (void) observeValueForKeyPath: (NSString*)keyPath ofObject: (id)object 
                         change: (NSDictionary*)change context: (void*)context
{
    if (object == _controlPull && !_controlPull.running) {
        LogTo(Syncpoint, @"Up-to-date with control database");
        [self stopObservingControlPull];
        // Now start the pull up again, in continuous mode:
        _controlPull = [self pullControlDataFromDatabaseNamed: _session.control_database];
        _controlPull.continuous = YES;
        self.state = kSyncpointReady;
        LogTo(Syncpoint, @"**READY**");
        
        [_session didSyncControlDB];

        [self getUpToDateWithSubscriptions];
    }
}


- (void) stopObservingControlPull {
    if (_observingControlPull) {
        [_controlPull removeObserver: self forKeyPath: @"running"];
        _observingControlPull = NO;
    }
}


// Called when the control database changes or is initial pulled from the server.
- (void) getUpToDateWithSubscriptions {
    // Make installations for any subscriptions that don't have one:
    NSSet* installedSubscriptions = _session.installedSubscriptions;
    for (SyncpointSubscription* sub in _session.activeSubscriptions) {
        if (![installedSubscriptions containsObject: sub]) {
            LogTo(Syncpoint, @"Making installation db for %@", sub);
            [sub makeInstallationWithLocalDatabase: nil error: nil];    // TODO: Report error
        }

    }
    // Sync all installations whose channels are ready:
    for (SyncpointInstallation* inst in _session.allInstallations)
        if (inst.channel.isReady)
            [self syncInstallation: inst];
}


// Starts bidirectional sync of an application database with its server counterpart.
- (void) syncInstallation: (SyncpointInstallation*)installation {
    CouchDatabase *localChannelDb = installation.localDatabase;
    NSURL *cloudChannelURL = [NSURL URLWithString: installation.channel.cloud_database
                                    relativeToURL: _remote];
    LogTo(Syncpoint, @"Syncing local db '%@' with remote %@", localChannelDb, cloudChannelURL);
    NSArray* repls = [localChannelDb replicateWithURL: cloudChannelURL exclusively: NO];
    for (CouchPersistentReplication* repl in repls)
        repl.continuous = YES;
}


@end
