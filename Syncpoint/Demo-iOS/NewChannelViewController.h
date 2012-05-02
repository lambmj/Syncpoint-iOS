//
//  NewChannelViewController.h
//  Syncpoint
//
//  Created by John Anderson on 5/2/12.
//  Copyright (c) 2012 Couchbase, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface NewChannelViewController : UIViewController <UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UITextField *channelNameField;

@end
