//
//  ChannelsViewController.m
//  Syncpoint
//
//  Created by John Anderson on 4/27/12.
//  Copyright (c) 2012 Couchbase, Inc. All rights reserved.
//

#import "DemoAppDelegate.h"
#import "RootViewController.h"
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

- (void)dealloc {
    self.dataSource = nil;
}


- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    delegate = (DemoAppDelegate *)[[UIApplication sharedApplication] delegate];
    SyncpointClient* syncpoint = delegate.syncpoint;
    if (syncpoint.session.isPaired) {
        self.dataSource.query = [syncpoint myChannelsQuery];
        // Document property to display in the cell label
        self.dataSource.labelProperty = @"name";
        [self.dataSource.query start];
    }
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    CouchQueryRow *row = [self.dataSource rowAtIndex:indexPath.row];
    CouchDocument *doc = [row document];    
    //    make it into a channel model and then pop it
    SyncpointChannel *channel = [SyncpointChannel modelForDocument: doc];
    [self pop: channel];    
}


//    yield name back to main content to be used as context
- (void)pop: (SyncpointChannel*)channel {
    NSError *error;
    CouchDatabase *database = [channel ensureLocalDatabase:&error];
    if (!database) {
        NSLog(@"error `%@` making database for channel %@", error, channel.description);
        return;
    }
    UINavigationController* navController = (UINavigationController*)self.parentViewController;
    
    RootViewController* listController = [[RootViewController alloc] init];
    [listController useDatabase: database];
    listController.navigationItem.title = channel.name;
    [navController pushViewController:listController animated:YES];    
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
