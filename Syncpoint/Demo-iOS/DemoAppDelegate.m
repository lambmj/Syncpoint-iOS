//
//  DemoAppDelegate.m
//  iOS Demo
//
//  Created by Jens Alfke on 12/9/11.
//  Copyright (c) 2011 Couchbase, Inc. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import "DemoAppDelegate.h"
#import "RootViewController.h"
#import <Syncpoint/Syncpoint.h>


#define kServerURLString @"http://localhost:5984/"

#define kSyncpointAppId @"demo-app"
#define sFacebookAppID @"251541441584833"

@implementation DemoAppDelegate


@synthesize window, navigationController, syncpoint, channel, facebook;


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Add the navigation controller's view to the window and display.
    NSAssert(navigationController, @"navigationController outlet not wired up");
	[window addSubview:navigationController.view];
	[window makeKeyAndVisible];
    
//    gRESTLogLevel = kRESTLogRequestHeaders;
//    gCouchLogLevel = 1;
    
    NSLog(@"Setting up Syncpoint...");
    NSURL* remote = [NSURL URLWithString: kServerURLString];
    NSError* error;

    self.syncpoint = [[SyncpointClient alloc] initWithRemoteServer: remote
                                                            appId: kSyncpointAppId
                                                            error: &error];

    if (error) {
        [self showAlert: @"Syncpoint failed to start." error: error fatal: YES];
        return YES;
    }

    CouchDatabase *database = [syncpoint databaseForMyChannelNamed: @"grocery-sync" error: &error];
    
    if (!database) {
        NSLog(@"error <%@>", error);
        [self showAlert: @"Couldn't create local channel." error: error fatal: YES];
        return YES;
    }

    database.tracksChanges = YES;
    NSLog(@"...using CouchDatabase at <%@>", database.URL);
    
    // Tell the RootViewController:
    RootViewController* root = (RootViewController*)navigationController.topViewController;
    [root useDatabase: database];

    if (sFacebookAppID) {
        facebook = [[Facebook alloc] initWithAppId: sFacebookAppID andDelegate: self];
        NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
        NSString* accessToken = [defaults objectForKey:@"FBAccessToken"];
        NSDate* expirationDate = [defaults objectForKey:@"FBExpirationDate"];
        NSLog(@"Created Facebook instance; token=%@, expiration=%@", accessToken, expirationDate);
        if (accessToken && expirationDate) {
            facebook.accessToken = accessToken;
            facebook.expirationDate = expirationDate;
        }
    }
    return YES;
}

/** 
 * delegates openURL calls through to Facebook. This gets called when Facebook redirects 
 * back to our app.
 */

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
    return [self.facebook handleOpenURL:url];
}

/**
 * Called when the user logged into Facebook.
 */
- (void)fbDidLogin {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[facebook accessToken] forKey:@"FBAccessTokenKey"];
    [defaults setObject:[facebook expirationDate] forKey:@"FBExpirationDateKey"];
    [defaults synchronize];
    NSLog(@"logged into Facebook have token: %@", [facebook accessToken]);
    [syncpoint pairSessionWithType:@"facebook" andToken:[facebook accessToken]]; // todo handle error
}

/**
 * Called when the user canceled the authorization dialog.
 */
-(void)fbDidNotLogin:(BOOL)cancelled {
    // we don't have anything really to do here
}

- (void)fbDidExtendToken:(NSString*)accessToken
               expiresAt:(NSDate*)expiresAt {
    
}

- (void)fbSessionInvalidated {
}

- (void)fbDidLogout{
}

// Display an error alert, without blocking.
// If 'fatal' is true, the app will quit when it's pressed.
- (void)showAlert: (NSString*)message error: (NSError*)error fatal: (BOOL)fatal {
    if (error) {
        message = [NSString stringWithFormat: @"%@\n\n%@", message, error.localizedDescription];
    }
    UIAlertView* alert = [[UIAlertView alloc] initWithTitle: (fatal ? @"Fatal Error" : @"Error")
                                                    message: message
                                                   delegate: (fatal ? self : nil)
                                          cancelButtonTitle: (fatal ? @"Quit" : @"Sorry")
                                          otherButtonTitles: nil];
    [alert show];
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    exit(0);
}


@end
