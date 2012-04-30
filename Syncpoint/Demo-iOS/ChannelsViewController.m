//
//  ChannelsViewController.m
//  Syncpoint
//
//  Created by John Anderson on 4/27/12.
//  Copyright (c) 2012 Couchbase, Inc. All rights reserved.
//

#import "DemoAppDelegate.h"
#import "ChannelsViewController.h"
#import <Syncpoint/Syncpoint.h>

@interface ChannelsViewController ()

@end

@implementation ChannelsViewController

@synthesize dataSource, delegate, tableView;

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
    delegate = (DemoAppDelegate *)[[UIApplication sharedApplication] delegate];
    SyncpointClient* syncpoint = delegate.syncpoint;

    self.dataSource.query = [syncpoint myChannelsQuery];
    // Document property to display in the cell label
    self.dataSource.labelProperty = @"name";
    RESTOperation* op = [self.dataSource.query start];
    NSLog(@"start %@", op.dump);
    [op onCompletion:^{
        NSLog(@"result %@", op.dump);
    }];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

@end
