//
//  RootViewController.m
//  Couchbase Mobile
//
//  Created by Jan Lehnardt on 27/11/2010.
//  Copyright 2011 Couchbase, Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License"); you may not
// use this file except in compliance with the License. You may obtain a copy of
// the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
// WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
// License for the specific language governing permissions and limitations under
// the License.
//

#import "RootViewController.h"
#import "ConfigViewController.h"
#import "ChannelsViewController.h"
#import "DemoAppDelegate.h"

#import <Syncpoint/CouchCocoa.h>
#import <Syncpoint/CouchDesignDocument_Embedded.h>


@interface RootViewController ()
@property(nonatomic, strong)CouchDatabase *database;
@property(nonatomic, strong)NSURL* remoteSyncURL;
@end


@implementation RootViewController


@synthesize dataSource;
@synthesize database;
@synthesize tableView;
@synthesize remoteSyncURL;


#pragma mark - View lifecycle

- (void) viewDidLoadWithDatabase {
    if (_viewDidLoad && self.database) {
        // Create a query sorted by descending date, i.e. newest items first:
        CouchLiveQuery* query = [[[database designDocumentWithName: @"default"]
                                queryViewNamed: @"byDate"] asLiveQuery];
        query.descending = YES;
        
        self.dataSource.query = query;
        // Document property to display in the cell label
        self.dataSource.labelProperty = @"text"; 
        [self observeSync];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [CouchUITableSource class];     // Prevents class from being dead-stripped by linker

//    UIBarButtonItem* channelsButton = [[UIBarButtonItem alloc] initWithTitle: @"Lists"
//                                                            style:UIBarButtonItemStylePlain
//                                                           target: self 
//                                                           action: @selector(gotoChannelsView:)];
//    self.navigationItem.leftBarButtonItem = channelsButton;
    
    [self.tableView setBackgroundView:nil];
    [self.tableView setBackgroundColor:[UIColor clearColor]];
    if([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    {
        [addItemTextField setFrame:CGRectMake(56, 8, 665, 43)];
    }
    _viewDidLoad = YES;
    [self viewDidLoadWithDatabase];
}


- (void)dealloc {
    [self forgetSync];
}


- (void)viewWillDisappear:(BOOL)animated {
    self.navigationItem.leftBarButtonItem = nil;
    showingPairButton = NO;
    [super viewWillDisappear: animated];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear: animated];
    DemoAppDelegate* delegate = (DemoAppDelegate*)[[UIApplication sharedApplication] delegate];    
    if (!delegate.syncpoint.session.isPaired) {
        [self showPairButton];
    }
    // Check for changes after returning from the sync config view:
    [self observeSync];
}

//- (IBAction)gotoChannelsView:(id)sender {
//    UINavigationController* navController = (UINavigationController*)self.parentViewController;
////    ChannelsViewController* controller = [[ChannelsViewController alloc] init];
////    controller.root = self;
////    we should pop to channels view
//    [navController popViewControllerAnimated: YES];
//}

- (void)useDatabase:(CouchDatabase*)theDatabase {
    self.database = theDatabase;
    
    // Create a 'view' containing list items sorted by date:
    CouchDesignDocument* design = [database designDocumentWithName: @"default"];
    [design defineViewNamed: @"byDate" mapBlock: MAPBLOCK({
        id date = [doc objectForKey: @"created_at"];
        NSNumber* checked = [NSNumber numberWithBool: ![[doc objectForKey: @"check"] boolValue]];
        if (date) emit([NSArray arrayWithObjects:checked, date, nil], doc);
    }) version: @"1.1"];
    
    // and a validation function requiring parseable dates:
    design.validationBlock = VALIDATIONBLOCK({
        if ([newRevision objectForKey: @"_deleted"])
            return YES;
        id date = [newRevision objectForKey: @"created_at"];
        if (date && ! [RESTBody dateWithJSONObject: date]) {
            context.errorMessage = [@"invalid date " stringByAppendingString: date];
            return NO;
        }
        return YES;
    });
    
    [self viewDidLoadWithDatabase];
}


- (void)showErrorAlert: (NSString*)message forOperation: (RESTOperation*)op {
    NSLog(@"%@: op=%@, error=%@", message, op, op.error);
    [(DemoAppDelegate*)[[UIApplication sharedApplication] delegate] 
        showAlert: message error: op.error fatal: NO];
}


#pragma mark - Couch table source delegate


// Customize the appearance of table view cells.
- (void)couchTableSource:(CouchUITableSource*)source
             willUseCell:(UITableViewCell*)cell
                  forRow:(CouchQueryRow*)row
{
    // Set the cell background and font:
    cell.backgroundColor = [UIColor whiteColor];
    cell.selectionStyle = UITableViewCellSelectionStyleGray;

    cell.textLabel.font = [UIFont fontWithName: @"Helvetica" size:18.0];
    cell.textLabel.backgroundColor = [UIColor clearColor];
    
    // Configure the cell contents. Our view function (see above) copies the document properties
    // into its value, so we can read them from there without having to load the document.
    // cell.textLabel.text is already set, thanks to setting up labelProperty above.
    NSDictionary* properties = row.value;
    BOOL checked = [[properties objectForKey:@"check"] boolValue];
    cell.textLabel.textColor = checked ? [UIColor grayColor] : [UIColor blackColor];
    cell.imageView.image = [UIImage imageNamed:
            (checked ? @"list_area___checkbox___checked" : @"list_area___checkbox___unchecked")];
}


#pragma mark - Table view delegate


- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 50;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    CouchQueryRow *row = [self.dataSource rowAtIndex:indexPath.row];
    CouchDocument *doc = [row document];

    // Toggle the document's 'checked' property:
    NSMutableDictionary *docContent = [doc.properties mutableCopy];
    BOOL wasChecked = [[docContent valueForKey:@"check"] boolValue];
    [docContent setObject:[NSNumber numberWithBool:!wasChecked] forKey:@"check"];

    // Save changes, asynchronously:
    RESTOperation* op = [doc putProperties:docContent];
    [op onCompletion: ^{
        if (op.error)
            [self showErrorAlert: @"Failed to update item" forOperation: op];
        // Re-run the query:
		[self.dataSource.query start];
    }];
    [op start];
}


#pragma mark - Editing:

- (void)couchTableSource:(CouchUITableSource*)source
         operationFailed:(RESTOperation*)op
{
    NSString* message = op.isDELETE ? @"Couldn't delete item" : @"Operation failed";
    [self showErrorAlert: message forOperation: op];
}


#pragma mark - UITextField delegate


- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	[textField resignFirstResponder];
	return YES;
}


//- (void)textFieldDidBeginEditing:(UITextField *)textField {
//    [addItemBackground setImage:[UIImage imageNamed:@"textfield___active.png"]];
//}


-(void)textFieldDidEndEditing:(UITextField *)textField {
    // Get the name of the item from the text field:
	NSString *text = addItemTextField.text;
    if (text.length == 0) {
        return;
    }
    [addItemTextField setText:nil];

    // Create the new document's properties:
	NSDictionary *inDocument = [NSDictionary dictionaryWithObjectsAndKeys:text, @"text",
                                [NSNumber numberWithBool:NO], @"check",
                                [RESTBody JSONObjectWithDate: [NSDate date]], @"created_at",
                                nil];

    // Save the document, asynchronously:
    CouchDocument* doc = [database untitledDocument];
    RESTOperation* op = [doc putProperties:inDocument];
    [op onCompletion: ^{
        if (op.error)
            [self showErrorAlert: @"Couldn't save the new item" forOperation: op];
        // Re-run the query:
		[self.dataSource.query start];
	}];
    [op start];
}


#pragma mark - SYNC:


- (IBAction) configureSync:(id)sender {
    UINavigationController* navController = (UINavigationController*)self.parentViewController;
    ConfigViewController* controller = [[ConfigViewController alloc] init];
    [navController pushViewController: controller animated: YES];
}


- (void) observeSync {
    if (!self.database)
        return;
    [self forgetSync];
    
    NSArray* repls = self.database.replications;
    if (repls.count < 2)
        return;
    _pull = [repls objectAtIndex: 0];
    _push = [repls objectAtIndex: 1];
    [_pull addObserver: self forKeyPath: @"completed" options: 0 context: NULL];
    [_push addObserver: self forKeyPath: @"completed" options: 0 context: NULL];
}


- (void) forgetSync {
    [_pull removeObserver: self forKeyPath: @"completed"];
    _pull = nil;
    [_push removeObserver: self forKeyPath: @"completed"];
    _push = nil;
}


- (void)showPairButton {
    if (!showingPairButton) {
        showingPairButton = YES;
        UIBarButtonItem* syncButton =
                [[UIBarButtonItem alloc] initWithTitle: @"Pair"
                                                 style:UIBarButtonItemStylePlain
                                                target: self 
                                                action: @selector(configureSync:)];
        self.navigationItem.leftBarButtonItem = syncButton;
    }
}


- (void)showSyncStatus {
    if (!progress) {
        progress = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];
        CGRect frame = progress.frame;
        frame.size.width = self.view.frame.size.width / 4.0f;
        progress.frame = frame;
    }
    UIBarButtonItem* progressItem = [[UIBarButtonItem alloc] initWithCustomView:progress];
    progressItem.enabled = NO;
    self.navigationItem.rightBarButtonItem = progressItem;
}


- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object 
                         change:(NSDictionary *)change context:(void *)context
{
    if (object == _pull || object == _push) {
        unsigned completed = _pull.completed + _push.completed;
        unsigned total = _pull.total + _push.total;
        NSLog(@"SYNC progress: %u / %u", completed, total);
        if (total > 0 && completed < total) {
            [self showSyncStatus];
            [progress setProgress:(completed / (float)total)];
        } else {
            self.navigationItem.rightBarButtonItem = nil;

        }
    }
}


@end
