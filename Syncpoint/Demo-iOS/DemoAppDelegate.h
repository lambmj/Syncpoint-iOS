//
//  DemoAppDelegate.h
//  iOS Demo
//
//  Created by Jens Alfke on 12/9/11.
//  Copyright (c) 2011 Couchbase, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "FBConnect.h"

@class CouchDatabase, SyncpointClient, SyncpointChannel;


@interface DemoAppDelegate : UIResponder <UIApplicationDelegate, FBSessionDelegate>

@property (nonatomic, strong) CouchDatabase *database;
@property (nonatomic, strong) SyncpointChannel* channel;
@property (nonatomic, strong) SyncpointClient* syncpoint;
@property (nonatomic, retain) Facebook *facebook;


@property (strong, nonatomic) IBOutlet UIWindow *window;
@property (nonatomic, strong) IBOutlet UINavigationController *navigationController;

- (void)showAlert: (NSString*)message error: (NSError*)error fatal: (BOOL)fatal;

@end
