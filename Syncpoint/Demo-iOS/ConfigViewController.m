//
//  ConfigViewController.m
//  CouchDemo
//
//  Created by Jens Alfke on 8/8/11.
//  Copyright 2011 Couchbase, Inc. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import "DemoAppDelegate.h"
#import "ConfigViewController.h"
#import <Syncpoint/Syncpoint.h>
#import <Security/SecRandom.h>

// This symbol comes from GrocerySync_vers.c, generated by the versioning system.
extern double GrocerySyncVersionNumber;


@implementation ConfigViewController


@synthesize sessionInfo, sessionLabel;


- (id)init {
    self = [super initWithNibName: @"ConfigViewController" bundle: nil];
    if (self) {
        // Custom initialization
        self.navigationItem.title = @"Configure Sync";

        UIBarButtonItem* purgeButton = [[UIBarButtonItem alloc] initWithTitle: @"Done"
                                                                style:UIBarButtonItemStyleDone
                                                               target: self 
                                                               action: @selector(done:)];
        self.navigationItem.leftBarButtonItem = purgeButton;
    }
    return self;
}


#pragma mark - View lifecycle


- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    DemoAppDelegate* appDelegate = (DemoAppDelegate*)[UIApplication sharedApplication].delegate;
    SyncpointClient* syncpoint = appDelegate.syncpoint;
    
    if (syncpoint.session.isPaired) {
        // display user-id
        self.sessionInfo.text = @"Your Syncpoint User Id:";
        self.sessionLabel.text = syncpoint.session.owner_id;
    } else if (syncpoint.session.isReadyToPair) {
        self.sessionInfo.text = @"Show this code to your administrator";
        self.sessionLabel.text = [syncpoint.session getValueOfProperty: @"pairing_token"];
    } else {
        // All authentication passes through this API. For Facebook auth you'd pass
        // the oauth access token as handed back by the Facebook Connect API, like this:
        // [syncpoint pairSessionWithType:@"facebook" andToken:myFacebookAccessToken];
        // for the default console auth, you pass any random string for the token.
        NSString* randomToken = [NSString stringWithFormat:@"%d", arc4random()];
        [syncpoint pairSessionWithType:@"console" andToken:randomToken]; // todo handle error

        self.sessionInfo.text = @"Show this code to your administrator";
        self.sessionLabel.text = [syncpoint.session getValueOfProperty: @"pairing_token"];
    }
}



- (void)pop {
    
    UINavigationController* navController = (UINavigationController*)self.parentViewController;
    [navController popViewControllerAnimated: YES];
}


- (IBAction)done:(id)sender {
    [self pop];
}


- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (buttonIndex > 0) {
        [self pop]; // Go back to the main screen without saving the URL
    }
}


@end
