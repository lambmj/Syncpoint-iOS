//
//  ChannelsViewController.h
//  Syncpoint
//
//  Created by John Anderson on 4/27/12.
//  Copyright (c) 2012 Couchbase, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Syncpoint/CouchUITableSource.h>
#import <Syncpoint/Syncpoint.h>

@class DemoAppDelegate;

@interface ChannelsViewController : UIViewController <CouchUITableDelegate>

// todo remove
@property (nonatomic, readonly) DemoAppDelegate *delegate;

@property(nonatomic, strong) IBOutlet UITableView *tableView;
@property(nonatomic, strong) IBOutlet CouchUITableSource* dataSource;

@end

