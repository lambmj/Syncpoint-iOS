//
//  SyncpointClient.h
//  Syncpoint
//
//  Created by Jens Alfke on 2/23/12.
//  Copyright (c) 2012 Couchbase, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
@class CouchServer, SyncpointSession, SyncpointInstallation;


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

- (void) createSessionWithType: (NSString*)sessionType andToken: (NSString*)pairingToken;

@property (readonly, nonatomic) CouchServer* localServer;

/** The id used to relate the client code to the server storage. */
@property (readonly, nonatomic) NSString* appId;

/** Current state (see SyncpointState enum above). Observable. */
@property (readonly, nonatomic) SyncpointState state;

/** The session object, which manages channels and subscriptions. */
@property (readonly) SyncpointSession* session;


@end
