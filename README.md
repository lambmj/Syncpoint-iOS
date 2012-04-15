# Syncpoint iOS Client

This driver includes building TouchDB and CouchCocoa to make and all in one sync engine that connects with <a href="link to syncpoint">Couchbase Syncpoint</a> to do higher level APIs like sharing and channels.

In your `~/code` directory:

    git clone --recursive git://github.com/couchbaselabs/Syncpoint-iOS.git
    cd Syncpoint-iOS
    open Syncpoint.xcworkspace

And **XCode** will come up and you'll be staring at some Objective-C.

Please direct your attention to the <a href="code">`Syncpoint/Demo-iOS/DemoAppDelegate.m`</a>, where we setup `SyncpointClient` with our remote URL, and then ask it for a <a href="link to couch cocoa docs">CouchCocoa `CouchDatabase`</a> using the <a href="link to code">`databaseForChannelNamed` call</a>.

```Objective-C
    NSLog(@"Setting up Syncpoint...");
    NSURL* remoteURL = [NSURL URLWithString: kServerURLString];
    NSError* error;

    self.syncpoint = [[SyncpointClient alloc] 
                       initWithRemoteServer: remoteURL
                                      appId: kSyncpointAppId
                                      error: &error];

    if (error) {
        [self showAlert: @"Syncpoint failed to start." error: error fatal: YES];
        return YES;
    }
    
    self.database = [syncpoint databaseForChannelNamed: @"grocery-sync" error: &error];
    
    if (!self.database) {
        NSLog(@"error <%@>", error);
        [self showAlert: @"Couldn't create local channel." error: error fatal: YES];
        return YES;
    }

    database.tracksChanges = YES;
    NSLog(@"...using CouchDatabase at <%@>", self.database.URL);
    
    // Tell the RootViewController:
    RootViewController* root = (RootViewController*)navigationController.topViewController;
    [root useDatabase: database];
```
