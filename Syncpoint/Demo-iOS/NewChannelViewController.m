//
//  NewChannelViewController.m
//  Syncpoint
//
//  Created by John Anderson on 5/2/12.
//  Copyright (c) 2012 Couchbase, Inc. All rights reserved.
//

#import "NewChannelViewController.h"
#import "DemoAppDelegate.h"
#import <Syncpoint/Syncpoint.h>


@interface NewChannelViewController ()

@end

@implementation NewChannelViewController

@synthesize channelNameField;


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (void)viewDidUnload
{
    [self setChannelNameField:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void) updateString {
    NSString* channelName = channelNameField.text;
    DemoAppDelegate *delegate = (DemoAppDelegate *)[[UIApplication sharedApplication] delegate];
    [delegate.syncpoint.session installChannelNamed:channelName toDatabase:nil error:nil];
    [self pop];
}

- (void)pop {
    UINavigationController* navController = (UINavigationController*)self.parentViewController;
    [navController popViewControllerAnimated: YES];
}

- (BOOL)textFieldShouldReturn:(UITextField *)theTextField {
	// When the user presses return, take focus away from the text field so that the keyboard is dismissed.
	if (theTextField == channelNameField) {
		[channelNameField resignFirstResponder];
        // Invoke the method that changes the greeting.
        [self updateString];
	}
	return YES;
}


//- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
//{
//    // Dismiss the keyboard when the view outside the text field is touched.
//    [textField resignFirstResponder];
//    [super touchesBegan:touches withEvent:event];
//}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

@end
