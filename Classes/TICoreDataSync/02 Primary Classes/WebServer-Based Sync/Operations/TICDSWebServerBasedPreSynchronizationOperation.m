//
//  TICDSWebServerBasedPreSynchronizationOperation.m
//  iOSNotebook
//
//  Created by Tim Isted on 14/05/2011.
//  Copyright 2011 Tim Isted. All rights reserved.
//


#import "TICoreDataSync.h"

#import "JSONKit.h"
#import "MBProgressHUD.h"

#import "ASINetworkQueue.h"


@interface TICDSWebServerBasedPreSynchronizationOperation ()

/** A dictionary used by this operation to find out the client responsible for creating a change set. */
@property (nonatomic, strong) NSMutableDictionary *clientIdentifiersForChangeSetIdentifiers;

/** A dictionary used to keep hold of the modification dates of sync change sets. */
@property (nonatomic, strong) NSMutableDictionary *changeSetModificationDates;

/** When we fail to download a changeset file we re-request it and put its path in this set so that we can keep track of the fact that we've re-requested it. */
@property (nonatomic, strong) NSMutableDictionary *failedDownloadRetryDictionary;

@property (nonatomic, strong) NSMutableDictionary *changeSetFileSizes;

@end

@implementation TICDSWebServerBasedPreSynchronizationOperation

#pragma mark - Overridden Methods
- (BOOL)needsMainThread
{
    return NO;
}

- (void)fetchRemoteIntegrityKey
{
    if (self.isCancelled) {
        [self operationWasCancelled];
        return;
    }
    
#if TARGET_OS_IPHONE
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
#endif

    NSString *directoryPath = [[self thisDocumentDirectoryPath] stringByAppendingPathComponent:TICDSIntegrityKeyDirectoryName];
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/metadata", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    [request addPostValue:directoryPath forKey:@"filePath"];
    [request setCompletionBlock:^{
        FCLog(@"Response: %@", requestBlock.responseString);
        NSDictionary *results = [requestBlock.responseString objectFromJSONString];
        
        for (NSDictionary *path in [results objectForKey:@"contents"]) {
            if ([[path valueForKey:@"fileName"] length] < 5) {
                continue;
            }
            [self fetchedRemoteIntegrityKey:[path valueForKey:@"fileName"]];
            return;
        }
        
        [self setError:[TICDSError errorWithCode:TICDSErrorCodeUnexpectedOrIncompleteFileLocationOrDirectoryStructure classAndMethod:__PRETTY_FUNCTION__]];
        [self fetchedRemoteIntegrityKey:nil];
    }];
    [request setFailedBlock:^{
        [self fetchedRemoteIntegrityKey:nil];
    }];
    [request startAsynchronous];
}


#pragma mark Sync Change Sets
- (void)buildArrayOfClientDeviceIdentifiers
{
    if (self.isCancelled) {
        [self operationWasCancelled];
        return;
    }
    
    NSString *path = [self thisDocumentSyncChangesDirectoryPath];
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/metadata", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    [request addPostValue:path forKey:@"filePath"];
    [request setCompletionBlock:^{
        FCLog(@"Response: %@", requestBlock.responseString);
        NSDictionary *results = [requestBlock.responseString objectFromJSONString];
        
        NSMutableArray *clientDeviceIdentifiers = [NSMutableArray arrayWithCapacity:0];
        NSString *identifier = nil;
        for (NSDictionary *item in [results valueForKey:@"contents"] ) {
            identifier = [[item valueForKey:@"relativeFilePath"] lastPathComponent];
            if ([identifier length] < 5) {
                continue;
            }
            [clientDeviceIdentifiers addObject:identifier];
        }
        
        [self builtArrayOfClientDeviceIdentifiers:clientDeviceIdentifiers];
        
    }];
    [request setFailedBlock:^{
        [self builtArrayOfClientDeviceIdentifiers:nil];
    }];
    [request startAsynchronous];
    
    
}

- (void)buildArrayOfSyncChangeSetIdentifiersForClientIdentifier:(NSString *)anIdentifier
{
    if (self.isCancelled) {
        [self operationWasCancelled];
        return;
    }
    
    NSString *path = [self pathToSyncChangesDirectoryForClientWithIdentifier:anIdentifier];
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/metadata", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    [request addPostValue:path forKey:@"filePath"];
    [request setCompletionBlock:^{
        FCLog(@"Response: %@", requestBlock.responseString);
        NSDictionary *results = [requestBlock.responseString objectFromJSONString];
        
        if (![self changeSetModificationDates]) {
            [self setChangeSetModificationDates:[NSMutableDictionary dictionaryWithCapacity:20]];
        }
        
        if (![self changeSetFileSizes]) {
            [self setChangeSetFileSizes:[NSMutableDictionary dictionaryWithCapacity:20]];
        }
        
        int dateModified;
        NSDate *lastModifiedDate;
        
        NSMutableArray *syncChangeSetIdentifiers = [NSMutableArray arrayWithCapacity:0];
        NSString *identifier = nil;
        for (NSDictionary *file in [results valueForKey:@"contents"] ) {
            identifier = [[[file valueForKey:@"relativeFilePath"] lastPathComponent] stringByDeletingPathExtension];
            
            if ([identifier length] < 5) {
                continue;
            }
            
            [syncChangeSetIdentifiers addObject:identifier];
            
            dateModified = [(NSNumber*)[file objectForKey:@"dateModified"] intValue];
            lastModifiedDate = [NSDate dateWithTimeIntervalSince1970:dateModified];
            
            [[self changeSetModificationDates] setValue:lastModifiedDate forKey:identifier];
            [[self changeSetFileSizes] setValue:[file objectForKey:@"fileSize"] forKey:identifier];
        }
        
        [self builtArrayOfClientSyncChangeSetIdentifiers:syncChangeSetIdentifiers forClientIdentifier:[path lastPathComponent]];
    }];
    [request setFailedBlock:^{
        [self builtArrayOfClientSyncChangeSetIdentifiers:nil forClientIdentifier:[path lastPathComponent]];
    }];
    [request startAsynchronous];
    
}

- (void)fetchSyncChangeSets:(NSArray *)changeSets
{
    if (self.isCancelled) {
        [self operationWasCancelled];
        return;
    }
    
    
    if( ![self clientIdentifiersForChangeSetIdentifiers] ) {
        [self setClientIdentifiersForChangeSetIdentifiers:[NSMutableDictionary dictionaryWithCapacity:10]];
    }
    
    if( ![self totalBytesExpectedForFiles] ) {
        [self setTotalBytesExpectedForFiles:[NSMutableDictionary dictionaryWithCapacity:10]];
    }
    
    if( ![self totalBytesReceivedForFiles] ) {
        [self setTotalBytesReceivedForFiles:[NSMutableDictionary dictionaryWithCapacity:10]];
    }
    
    for (NSDictionary *changeSet in changeSets) {
        NSString *identifier = [changeSet valueForKey:@"syncChangeIdentifier"];
        NSNumber *size = [[self changeSetFileSizes] objectForKey:identifier];
        if (size) {
            [[self totalBytesExpectedForFiles] setObject:size forKey:identifier];
        }
    }
    [totalBytesReceivedForFiles removeAllObjects];
    hasCompletedDownloadingSyncChanges = NO;
    
    ASINetworkQueue *queue = [ASINetworkQueue queue];
    
    for (NSDictionary *changeSet in changeSets) {
        if (self.isCancelled) {
            [self operationWasCancelled];
            return;
        }
        
        //@{@"syncChangeIdentifier": eachSyncChangeSetIdentifier,
        //  @"clientIdentifier": eachClientIdentifier,
        //  @"fileURLWithPath":fileLocation}];
        
        NSString *aChangeSetIdentifier = [changeSet valueForKey:@"syncChangeIdentifier"];
        NSString *aClientIdentifier    = [changeSet valueForKey:@"clientIdentifier"];
        NSURL    *aLocation            = [changeSet valueForKey:@"fileURLWithPath"];
        
        [[self clientIdentifiersForChangeSetIdentifiers] setValue:aClientIdentifier forKey:aChangeSetIdentifier];
        
        NSString *path = [self pathToSyncChangeSetWithIdentifier:aChangeSetIdentifier forClientWithIdentifier:aClientIdentifier];
        NSString *destPath = [aLocation path];
        
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/download", flashcardsServer]];
        ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
        [request prepareCoreDataSyncRequest];
        [request addPostValue:path forKey:@"filePath"];
        __block ASIFormDataRequest *myRequest = request;
        [request setUserInfo:@{@"identifier": aChangeSetIdentifier}];
        [request setCompletionBlock:^{
            // FCLog(@"Response: %@", myRequest.responseString);
            NSString *identifier = [myRequest.userInfo valueForKey:@"identifier"];
            int contentLength = [[myRequest.responseHeaders objectForKey:@"Content-Length"] intValue];
            [[self totalBytesExpectedForFiles] setObject:[NSNumber numberWithInt:contentLength]
                                                  forKey:identifier];
            dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);
            dispatch_async(queue, ^{
                [myRequest.responseData writeToFile:destPath atomically:YES];
            });
            NSString *changeSetIdentifier = [[destPath lastPathComponent] stringByDeletingPathExtension];
            NSString *clientIdentifier = [[self clientIdentifiersForChangeSetIdentifiers] valueForKey:changeSetIdentifier];
            
            [self fetchedSyncChangeSetWithIdentifier:changeSetIdentifier
                                 forClientIdentifier:clientIdentifier
                                    modificationDate:[[self changeSetModificationDates] valueForKey:changeSetIdentifier]
                                         withSuccess:YES];
        }];
        [request setFailedBlock:^{
            NSString *changeSetIdentifier = [[path lastPathComponent] stringByDeletingPathExtension];
            NSString *clientIdentifier = [[self clientIdentifiersForChangeSetIdentifiers] valueForKey:changeSetIdentifier];
            
            [self fetchedSyncChangeSetWithIdentifier:changeSetIdentifier
                                 forClientIdentifier:clientIdentifier
                                    modificationDate:nil
                                         withSuccess:NO];
        }];
        [request setShowAccurateProgress:YES];
        [request setDelegate:self];
        [queue addOperation:request];
    }
    
    
    [queue setShowAccurateProgress:YES];
    [queue setDelegate:self];
    [queue setDownloadProgressDelegate:self];
    [queue setQueueDidFinishSelector:@selector(downloadAllSyncChangeSetsDidFinish)];
    [queue go];
}

- (void)request:(ASIHTTPRequest *)request bytesReceivedSoFar:(long long)bytesReceivedSoFar {
    if (hasCompletedDownloadingSyncChanges) {
        return;
    }
    NSString *identifier = [request.userInfo valueForKey:@"identifier"];
    int contentLength = [[request.responseHeaders objectForKey:@"Content-Length"] intValue];
    [[self totalBytesExpectedForFiles] setObject:[NSNumber numberWithInt:contentLength]
                                          forKey:identifier];
    [[self totalBytesReceivedForFiles] setObject:[NSNumber numberWithLongLong:bytesReceivedSoFar]
                                          forKey:identifier];
    int totalBytesExpected = 0;
    int totalBytesReceived = 0;
    // resolves: https://rink.hockeyapp.net/manage/apps/20975/app_versions/63/crash_reasons/8311768
    NSArray *keys = [NSArray arrayWithArray:[[[self totalBytesExpectedForFiles] keyEnumerator] allObjects]];
    for (NSString *key in keys) {
        NSNumber *length = [[self totalBytesExpectedForFiles] objectForKey:key];
        totalBytesExpected += [length intValue];
        NSNumber *received = [[self totalBytesReceivedForFiles] objectForKey:key];
        if (received && [received isKindOfClass:[NSNumber class]]) {
            totalBytesReceived += [received intValue];
        }
    }
    if (totalBytesExpected < 1) {
        return;
    }
    
    float progress = ((float)totalBytesReceived / (float)totalBytesExpected);
    if (progress > 1.0f) {
        progress = 1.0f;
    }
    FCLog(@"%d / %d = %1.2f%%", totalBytesReceived, totalBytesExpected, progress*100);
    MBProgressHUD *syncHUD = [FlashCardsCore currentHUD:@"syncHUD"];
    if (!syncHUD) {
        return;
    }
    NSString *labelText = [NSString stringWithFormat:NSLocalizedStringFromTable(@"Downloaded: %1.2f%%", @"Backup", @""), (progress*100.0)];
    if (progress >= 0.98f) {
        // [syncHUD setMode:MBProgressHUDModeIndeterminate];
    } else {
        [syncHUD setMode:MBProgressHUDModeDeterminate];
    }
    [syncHUD setDetailsLabelText:labelText];
    [syncHUD setProgress:progress];
}

- (void)downloadAllSyncChangeSetsDidFinish {
    NSLog(@"Finished fetchSyncChangeSets");
    hasCompletedDownloadingSyncChanges = YES;
    MBProgressHUD *syncHUD = [FlashCardsCore currentHUD:@"syncHUD"];
    if (syncHUD) {
        // [syncHUD setMode:MBProgressHUDModeIndeterminate];
        NSString *labelText = NSLocalizedStringFromTable(@"Tap to Cancel", @"Import", @"");
        [syncHUD setDetailsLabelText:labelText];
    }
    double delayInSeconds = 0.1;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [self operationDidCompleteSuccessfully];
    });
}

#pragma mark - Paths
- (NSString *)pathToSyncChangesDirectoryForClientWithIdentifier:(NSString *)anIdentifier
{
    return [[self thisDocumentSyncChangesDirectoryPath] stringByAppendingPathComponent:anIdentifier];
}

- (NSString *)pathToSyncChangeSetWithIdentifier:(NSString *)aChangeSetIdentifier forClientWithIdentifier:(NSString *)aClientIdentifier
{
    return [[[self pathToSyncChangesDirectoryForClientWithIdentifier:aClientIdentifier] stringByAppendingPathComponent:aChangeSetIdentifier] stringByAppendingPathExtension:TICDSSyncChangeSetFileExtension];
}

#pragma mark - Initialization and Deallocation
- (void)dealloc
{
    _clientIdentifiersForChangeSetIdentifiers = nil;
    _changeSetModificationDates = nil;
    _thisDocumentDirectoryPath = nil;
    _thisDocumentSyncChangesDirectoryPath = nil;
}

#pragma mark - Lazy Accessors
- (NSMutableDictionary *)failedDownloadRetryDictionary
{
    if (_failedDownloadRetryDictionary == nil) {
        _failedDownloadRetryDictionary = [[NSMutableDictionary alloc] init];
    }
    
    return _failedDownloadRetryDictionary;
}

#pragma mark - Properties
@synthesize clientIdentifiersForChangeSetIdentifiers = _clientIdentifiersForChangeSetIdentifiers;
@synthesize changeSetModificationDates = _changeSetModificationDates;
@synthesize thisDocumentDirectoryPath = _thisDocumentDirectoryPath;
@synthesize thisDocumentSyncChangesDirectoryPath = _thisDocumentSyncChangesDirectoryPath;
@synthesize failedDownloadRetryDictionary = _failedDownloadRetryDictionary;

@end

