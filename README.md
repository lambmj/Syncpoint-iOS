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

That is the code that instantiates Syncpoint. The code that triggers paring with the cloud is in <a href="https://github.com/couchbaselabs/Syncpoint-iOS/blob/master/Syncpoint/Demo-iOS/ConfigViewController.m#L63">`/Syncpoint/Demo-iOS/ConfigViewController.m`</a>

So that's how you tie your app to a Syncpoint instance in the cloud.

## JSON Data API

You might be wondering how you do data stuff with Syncpoint. This is really more of a <strong>CouchCocoa</strong> question.

Here is an example of how we save a document (we use the (onCompletion handler to asynchronously respond to query)):


```Objective-C
// create the new document properties
NSDictionary* docData = [NSDictionary dictionaryWithObjectsAndKeys:
                          [NSNumber numberWithBool:NO], @"check"
                                                  text, @"text",
                                                  nil];
// save the document
CouchDocument* doc = [database untitledDocument];
RESTOperation *op = [doc putProperties: docData];
// asynchronous handler
[op onCompletion: ^{
    if (op.error) {
      NSLog(@"REST error %@", op.dump);
    }
    // do your thing
    [self savedDocument: doc];
}]
[op start];
```


## Contribute:

We are active on the mailing list here: https://groups.google.com/forum/#!forum/mobile-couchbase

License is Apache 2.0.
