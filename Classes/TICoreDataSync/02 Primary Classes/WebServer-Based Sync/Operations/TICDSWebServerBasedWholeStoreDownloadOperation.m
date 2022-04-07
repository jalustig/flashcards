//
//  TICDSWebServerBasedWholeStoreDownloadOperation.m
//  iOSNotebook
//
//  Created by Tim Isted on 14/05/2011.
//  Copyright 2011 Tim Isted. All rights reserved.
//

#if TARGET_OS_IPHONE

#import "TICoreDataSync.h"
#import "JSONKit.h"
#import "MBProgressHUD.h"
#import "FlashCardsCore.h"
#import "FlashCardsAppDelegate.h"

@interface TICDSWebServerBasedWholeStoreDownloadOperation ()

/** A mutable dictionary to hold the last modified dates of each client identifier's whole store. */
@property (nonatomic, strong) NSMutableDictionary *wholeStoreModifiedDates;

@end

@implementation TICDSWebServerBasedWholeStoreDownloadOperation

@synthesize totalBytesReceived;

- (BOOL)needsMainThread
{
    return NO;
}

- (void)checkForMostRecentClientWholeStore
{
    NSString *path = [self thisDocumentWholeStoreDirectoryPath];
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/metadata", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    [request addPostValue:path forKey:@"filePath"];
    [request addPostValue:[NSNumber numberWithInt:1] forKey:@"recursive"];
    [request setCompletionBlock:^{
        FCLog(@"Response: %@", requestBlock.responseString);
        NSDictionary *results = [requestBlock.responseString objectFromJSONString];
        int dateModified;
        NSDate *lastModifiedDate;

        [self setWholeStoreModifiedDates:[NSMutableDictionary dictionaryWithCapacity:0]];
        
        for (NSDictionary *devices in [results objectForKey:@"contents"]) {
            NSString *deviceId = [devices valueForKey:@"fileName"];
            lastModifiedDate = nil;
            for (NSDictionary *file in [devices objectForKey:@"contents"]) {
                if ([[file valueForKey:@"fileName"] isEqualToString:TICDSWholeStoreFilename]) {
                    dateModified = [(NSNumber*)[file objectForKey:@"dateModified"] intValue];
                    lastModifiedDate = [NSDate dateWithTimeIntervalSince1970:dateModified];
                }
            }
            if (lastModifiedDate) {
                [[self wholeStoreModifiedDates] setValue:lastModifiedDate forKey:deviceId];
            }
        }

        NSDate *mostRecentDate = nil;
        NSString *identifier = nil;
        for (NSString *eachIdentifier in [self wholeStoreModifiedDates] ) {
            NSDate *eachDate = [[self wholeStoreModifiedDates] valueForKey:eachIdentifier];
            
            if ([eachDate isKindOfClass:[NSNull class]]) {
                continue;
            }
            
            if (!mostRecentDate) {
                mostRecentDate = eachDate;
                identifier = eachIdentifier;
                continue;
            }
            
            if ([mostRecentDate compare:eachDate] == NSOrderedAscending) {
                mostRecentDate = eachDate;
                identifier = eachIdentifier;
                continue;
            }
        }
        
        if (!identifier) {
            [self setError:[TICDSError errorWithCode:TICDSErrorCodeNoPreviouslyUploadedStoreExists classAndMethod:__PRETTY_FUNCTION__]];
        }
        
        [self determinedMostRecentWholeStoreWasUploadedByClientWithIdentifier:identifier];
        
    }];
    [request setFailedBlock:^{
        [self determinedMostRecentWholeStoreWasUploadedByClientWithIdentifier:nil];
    }];
    [request startAsynchronous];
}

- (void)downloadWholeStoreFile
{
    NSString *storeToDownload = [self pathToWholeStoreFileForClientWithIdentifier:[self requestedWholeStoreClientIdentifier]];
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/metadata", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    [request addPostValue:storeToDownload forKey:@"filePath"];
    [request setCompletionBlock:^{
        FCLog(@"Response: %@", requestBlock.responseString);
        
        NSDictionary *response = [requestBlock.responseString objectFromJSONString];

        NSString *path = storeToDownload;
        NSString *destPath = [[self tempFileDirectoryPath] stringByAppendingPathComponent:TICDSWholeStoreFilename];
        
        totalBytesReceived = 0;
        
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/download", flashcardsServer]];
        ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
        __block ASIFormDataRequest *requestBlock2 = request;
        [request prepareCoreDataSyncRequest];
        [request addPostValue:path forKey:@"filePath"];
        [request setCompletionBlock:^{
            // FCLog(@"Response: %@", requestBlock2.responseString);
            [requestBlock2.responseData writeToFile:destPath atomically:YES];
            
            NSError *anyError;
            BOOL success = [[self fileManager] moveItemAtPath:destPath toPath:[[self localWholeStoreFileLocation] path] error:&anyError];
            
            if( !success ) {
                [self setError:[TICDSError errorWithCode:TICDSErrorCodeFileManagerError underlyingError:anyError classAndMethod:__PRETTY_FUNCTION__]];
            }
            [self downloadedWholeStoreFileWithSuccess:success];
        }];
        [request setFailedBlock:^{
            [self downloadedWholeStoreFileWithSuccess:NO];
        }];
        [request setShowAccurateProgress:YES];
        [request setDelegate:self];
        // [request setDownloadProgressDelegate:self];
        MBProgressHUD *HUD = [FlashCardsCore currentHUD:@"syncHUD"];
        if (HUD) {
            [HUD setLabelText:NSLocalizedStringFromTable(@"Downloading Database", @"Sync", @"")];
        }

        [request startAsynchronous];

    }];
    [request setFailedBlock:^{
        [self downloadedWholeStoreFileWithSuccess:NO];
    }];
    [request startAsynchronous];
}

- (void)request:(ASIHTTPRequest *)request didReceiveBytes:(long long)bytes {
    dispatch_async(dispatch_get_main_queue(), ^{
        int totalBytesExpected = [[request.responseHeaders objectForKey:@"Content-Length"] intValue];
        if (totalBytesExpected < 1) {
            return;
        }
        totalBytesReceived += (int)bytes;
        float progress = ((float)totalBytesReceived / (float)totalBytesExpected);
        NSLog(@"%d / %d = %1.2f%%", totalBytesReceived, totalBytesExpected, progress*100);
        MBProgressHUD *syncHUD = [FlashCardsCore currentHUD:@"syncHUD"];
        if (!syncHUD) {
            return;
        }
        NSString *labelText = [NSString stringWithFormat:NSLocalizedStringFromTable(@"Downloaded: %1.2f%%", @"Backup", @""), (progress*100.0)];
        [syncHUD setMode:MBProgressHUDModeDeterminate];
        if (progress > 0.99) {
            [syncHUD setMode:MBProgressHUDModeIndeterminate];
        }
        [syncHUD setDetailsLabelText:labelText];
        [syncHUD setProgress:progress];
    });
    
}

- (void)downloadAppliedSyncChangeSetsFile
{
    NSString *fileToDownload = [self pathToAppliedSyncChangesFileForClientWithIdentifier:[self requestedWholeStoreClientIdentifier]];
    
    NSString *path = fileToDownload;
    NSString *destPath = [[self tempFileDirectoryPath] stringByAppendingPathComponent:TICDSAppliedSyncChangeSetsFilename];
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/download", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    [request addPostValue:path forKey:@"filePath"];
    [request setCompletionBlock:^{
        FCLog(@"Response: %@", requestBlock.responseString);
        if ([requestBlock.responseString isEqualToString:@"404 file not found"]) {
            [self setError:nil];
            [self downloadedAppliedSyncChangeSetsFileWithSuccess:YES];
            return;
        }
        [requestBlock.responseData writeToFile:destPath atomically:YES];
        
        NSError *anyError;
        BOOL success = [[self fileManager] moveItemAtPath:destPath toPath:[[self localAppliedSyncChangeSetsFileLocation] path] error:&anyError];
        
        if( !success ) {
            [self setError:[TICDSError errorWithCode:TICDSErrorCodeFileManagerError underlyingError:anyError classAndMethod:__PRETTY_FUNCTION__]];
        }
        
        [self downloadedAppliedSyncChangeSetsFileWithSuccess:success];
    }];
    [request setFailedBlock:^{
        if([requestBlock.error code] == 404) {
            [self setError:nil];
            [self downloadedAppliedSyncChangeSetsFileWithSuccess:YES];
        } else {
            [self downloadedAppliedSyncChangeSetsFileWithSuccess:NO];
        }
    }];
    [request startAsynchronous];
}

- (void)fetchRemoteIntegrityKey
{
    NSString *directoryPath = [[self thisDocumentDirectoryPath] stringByAppendingPathComponent:TICDSIntegrityKeyDirectoryName];
    NSString *path = directoryPath;
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/metadata", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    [request addPostValue:path forKey:@"filePath"];
    [request addPostValue:[NSNumber numberWithInt:1] forKey:@"recursive"];
    [request setCompletionBlock:^{
        FCLog(@"Response: %@", requestBlock.responseString);
        if ([requestBlock.responseString isEqualToString:@"404 file not found"]) {
            [self setError:[TICDSError errorWithCode:TICDSErrorCodeUnexpectedOrIncompleteFileLocationOrDirectoryStructure classAndMethod:__PRETTY_FUNCTION__]];
            [self fetchedRemoteIntegrityKey:nil];
            return;
        }
        NSDictionary *results = [requestBlock.responseString objectFromJSONString];

        for (NSDictionary *file in [results valueForKey:@"contents"] ) {
            if ([[file valueForKey:@"name"] length] < 5 ) {
                continue;
            }
            [self fetchedRemoteIntegrityKey:[file valueForKey:@"name"]];
            return;
        }
        
        [self setError:[TICDSError errorWithCode:TICDSErrorCodeUnexpectedOrIncompleteFileLocationOrDirectoryStructure classAndMethod:__PRETTY_FUNCTION__]];
        [self fetchedRemoteIntegrityKey:nil];
    }];
    [request setFailedBlock:^{
        [self setError:[TICDSError errorWithCode:TICDSErrorCodeUnexpectedOrIncompleteFileLocationOrDirectoryStructure classAndMethod:__PRETTY_FUNCTION__]];
        [self fetchedRemoteIntegrityKey:nil];
    }];
    [request startAsynchronous];
}

#pragma mark -
#pragma mark Paths
- (NSString *)pathToWholeStoreFileForClientWithIdentifier:(NSString *)anIdentifier
{
    return [[[self thisDocumentWholeStoreDirectoryPath] stringByAppendingPathComponent:anIdentifier] stringByAppendingPathComponent:TICDSWholeStoreFilename];
}

- (NSString *)pathToAppliedSyncChangesFileForClientWithIdentifier:(NSString *)anIdentifier
{
    return [[[self thisDocumentWholeStoreDirectoryPath] stringByAppendingPathComponent:anIdentifier] stringByAppendingPathComponent:TICDSAppliedSyncChangeSetsFilename];
}

#pragma mark -
#pragma mark Properties
@synthesize thisDocumentDirectoryPath = _thisDocumentDirectoryPath;
@synthesize thisDocumentWholeStoreDirectoryPath = _thisDocumentWholeStoreDirectoryPath;
@synthesize wholeStoreModifiedDates = _wholeStoreModifiedDates;

@end

#endif