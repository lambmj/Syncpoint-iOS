//
//  SyncpointClient.h
//  Syncpoint
//
//  Created by Jens Alfke on 2/23/12.
//  Copyright (c) 2012 Couchbase, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
@class CouchServer, SyncpointSession, SyncpointInstallation, SyncpointChannel;


typedef enum {
    kSyncpointHasError,         /**< Server failed to authenticate/activate. */
    kSyncpointUnauthenticated,  /**< No session, and no auth token to pair with */
    kSyncpointAuthenticating,   /**< Authenticating user credentials (e.g. by OAuth) */
    kSyncpointActivating,       /**< Got auth token, now setting up with the server */
    kSyncpointUpdatingControlDatabase,  /**< Syncing session changes with the server */
    kSyncpointReady             /**< In sync with the server, ready to go */
} SyncpointState;


/** Syncpoint client-side controller: pairs with the server and tracks channels and subscriptions. */
@interface SyncpointClient : NSObject

/** Initializes a SyncpointClient instance that creates its own TouchDB server instance.
 @param remoteServer  The URL of the remote Syncpoint-enabled server.
 @param appId  The id used to relate the client code to the server storage.
 @param error  If initialization fails, this parameter will be filled in with an error.
 @return  The Syncpoint instance, or nil on failure. */
- (id) initWithRemoteServer: (NSURL*)remoteServerURL
                     appId: (NSString*)syncpointAppId
                     error: (NSError**)error;

/** Initializes a SyncpointClient instance.
    @param localServer  The application's local server object.
    @param remoteServer  The URL of the remote Syncpoint-enabled server.
    @param appId  The id used to relate the client code to the server storage.
    @param error  If initialization fails, this parameter will be filled in with an error.
    @return  The Syncpoint instance, or nil on failure. */
- (id) initWithLocalServer: (CouchServer*)localServer
              remoteServer: (NSURL*)remoteServerURL
                     appId: (NSString*)syncpointAppId
                     error: (NSError**)error;

/** All authentication passes through [pairSessionWithType andToken]. 
    For Facebook auth you'd pass the oauth access token as provided by the Facebook Connect API, like this:
    [syncpoint pairSessionWithType:@"facebook" andToken:myFacebookAccessToken];
    for the console auth, you pass any random string for the token. */
- (void) pairSessionWithType: (NSString*)pairingType andToken: (NSString*)pairingToken;

- (CouchDatabase*) databaseForMyChannelNamed: (NSString*) channelName error: (NSError**)error;

- (CouchLiveQuery*) myChannelsQuery;

@property (readonly, nonatomic) CouchServer* localServer;

/** The id used to relate the client code to the server storage. */
@property (readonly, nonatomic) NSString* appId;

/** Current state (see SyncpointState enum above). Observable. */
@property (readonly, nonatomic) SyncpointState state;

/** The session object, which manages channels and subscriptions. */
@property (readonly) SyncpointSession* session;


@end
