//
//  ConfigViewController.h
//  CouchDemo
//
//  Created by Jens Alfke on 8/8/11.
//  Copyright 2011 Couchbase, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
@class CouchServer, DemoAppDelegate;

@interface ConfigViewController : UIViewController

@property (nonatomic, readonly) DemoAppDelegate *delegate;
@property (weak, nonatomic, readonly) IBOutlet UILabel* sessionInfo;
@property (weak, nonatomic, readonly) IBOutlet UILabel* sessionLabel;
@property (weak, nonatomic, readonly) IBOutlet UIButton* facebookButton;
@property (weak, nonatomic, readonly) IBOutlet UIButton* consoleButton;


- (IBAction)pairViaConsole:(id)sender;
- (IBAction)pairViaFacebook:(id)sender;

- (IBAction)done:(id)sender;

@end
