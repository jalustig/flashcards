//
//  TICDSWebServerBasedPostSynchronizationOperation.m
//  iOSNotebook
//
//  Created by Tim Isted on 14/05/2011.
//  Copyright 2011 Tim Isted. All rights reserved.
//


#import "TICoreDataSync.h"
#import "MBProgressHUD.h"
#import "FlashCardsAppDelegate.h"

@interface TICDSWebServerBasedPostSynchronizationOperation ()

/** When we fail to download a changeset file we re-request it and put its path in this set so that we can keep track of the fact that we've re-requested it. */
@property (nonatomic, strong) NSMutableDictionary *failedDownloadRetryDictionary;

/** When uploading the local sync changes we need to first ask the Dropbox for any parent revisions. We store off the file path of the file we intend to upload while we get its revisions. */
@property (nonatomic, copy) NSString *localSyncChangeSetFilePath;

/** When uploading recent sync files we need to first ask the Dropbox for any parent revisions. We store off the file path of the file we intend to upload while we get its revisions. */
@property (nonatomic, copy) NSString *recentSyncFilePath;

@property (nonatomic, copy) NSString *localSyncChangeSetFileParentRevision;
@property (nonatomic, copy) NSString *recentSyncFileParentRevision;

- (void)uploadLocalSyncChangeSetFileWithParentRevision:(NSString *)parentRevision;
- (void)uploadRecentSyncFileWithParentRevision:(NSString *)parentRevision;

@end

@implementation TICDSWebServerBasedPostSynchronizationOperation

#pragma mark - Overridden Methods
- (BOOL)needsMainThread
{
    return NO;
}

#pragma mark Uploading Change Sets
- (void)uploadLocalSyncChangeSetFileAtLocation:(NSURL *)aLocation
{
    if (self.isCancelled) {
        [self operationWasCancelled];
        return;
    }
    
    NSString *finalFilePath = [aLocation path];
    
    self.localSyncChangeSetFilePath = finalFilePath;
    
    
    ASIBasicBlock completionBlock = ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            MBProgressHUD *syncHUD = [FlashCardsCore currentHUD:@"syncHUD"];
            if (!syncHUD) {
                return;
            }
            [syncHUD setMode:MBProgressHUDModeIndeterminate];
            NSString *labelText = NSLocalizedStringFromTable(@"Tap to Cancel", @"Import", @"");
            [syncHUD setDetailsLabelText:labelText];
        });
        
        [self uploadedLocalSyncChangeSetFileSuccessfully:YES];
    };
    ASIBasicBlock failedBlock = ^{
        // FCDisplayBasicErrorMessage(@"", @"Upload recent sync file failed");
        [self uploadedLocalSyncChangeSetFileSuccessfully:NO];
    };
    
    NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:self.localSyncChangeSetFilePath error:nil];
    UInt32 fileSize = [[fileAttributes objectForKey:NSFileSize] intValue];
    BOOL showUploadProgress = NO;
    if (fileSize > 1024*200) {
        showUploadProgress = YES;
    }
    
    // make sure we let the server know that we uploaded change sets:
    [[[FlashCardsCore appDelegate] syncController] setSyncDidUploadChanges:YES];
    
    [FlashCardsCore uploadFileChunk:self.localSyncChangeSetFilePath
                    toFinalLocation:[self thisDocumentSyncChangesThisClientDirectoryPath]
                  withFinalFileName:[self.localSyncChangeSetFilePath lastPathComponent]
                         uploadUUID:@""
                             offset:0
                         errorCount:0
                withCompletionBlock:completionBlock
                    withFailedBlock:failedBlock
                 showUploadProgress:showUploadProgress];
}

#pragma mark Uploading Recent Sync File
- (void)uploadRecentSyncFileAtLocation:(NSURL *)aLocation
{
    if (self.isCancelled) {
        [self operationWasCancelled];
        return;
    }
    
    self.recentSyncFilePath = [aLocation path];
    
    
    ASIBasicBlock completionBlock = ^{
        [self uploadedRecentSyncFileSuccessfully:YES];
    };
    ASIBasicBlock failedBlock = ^{
        FCDisplayBasicErrorMessage(@"", @"Upload recent sync file failed");
        [self uploadedRecentSyncFileSuccessfully:NO];
    };
    
    NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:self.recentSyncFilePath error:nil];
    UInt32 fileSize = [[fileAttributes objectForKey:NSFileSize] intValue];
    BOOL showUploadProgress = NO;
    if (fileSize > 1024*200) {
        showUploadProgress = YES;
    }
    
    [FlashCardsCore uploadFileChunk:self.recentSyncFilePath
                    toFinalLocation:[[self thisDocumentRecentSyncsThisClientFilePath] stringByDeletingLastPathComponent]
                  withFinalFileName:[self.recentSyncFilePath lastPathComponent]
                         uploadUUID:@""
                             offset:0
                         errorCount:0
                withCompletionBlock:completionBlock
                    withFailedBlock:failedBlock
                 showUploadProgress:showUploadProgress];
}

#pragma mark - Initialization and Deallocation
- (void)dealloc
{
    _thisDocumentSyncChangesDirectoryPath = nil;
    _thisDocumentSyncChangesThisClientDirectoryPath = nil;
    _thisDocumentRecentSyncsThisClientFilePath = nil;

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
@synthesize thisDocumentSyncChangesDirectoryPath = _thisDocumentSyncChangesDirectoryPath;
@synthesize thisDocumentSyncChangesThisClientDirectoryPath = _thisDocumentSyncChangesThisClientDirectoryPath;
@synthesize thisDocumentRecentSyncsThisClientFilePath = _thisDocumentRecentSyncsThisClientFilePath;
@synthesize failedDownloadRetryDictionary = _failedDownloadRetryDictionary;
@synthesize localSyncChangeSetFilePath = _localSyncChangeSetFilePath;
@synthesize recentSyncFilePath = _recentSyncFilePath;
@end

