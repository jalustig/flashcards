//
//  TICDSWebServerBasedWholeStoreUploadOperation.m
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

@implementation TICDSWebServerBasedWholeStoreUploadOperation

#pragma mark -
#pragma mark Overridden Methods
- (BOOL)needsMainThread
{
    return NO;
}

- (void)checkWhetherThisClientTemporaryWholeStoreDirectoryExists
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/exists", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    [request addPostValue:[self thisDocumentTemporaryWholeStoreThisClientDirectoryPath] forKey:@"filePath"];
    [request setCompletionBlock:^{
        FCLog(@"Response: %@", requestBlock.responseString);
        NSDictionary *response = (NSDictionary*)[requestBlock.responseString objectFromJSONString];
        TICDSRemoteFileStructureExistsResponseType status = TICDSRemoteFileStructureExistsResponseTypeDoesNotExist;
        if ([[response objectForKey:@"exists"] intValue] == 1) {
            status = TICDSRemoteFileStructureExistsResponseTypeDoesExist;
        }
        [self discoveredStatusOfThisClientTemporaryWholeStoreDirectory:status];
    }];
    [request setFailedBlock:^{
        [self discoveredStatusOfThisClientTemporaryWholeStoreDirectory:TICDSRemoteFileStructureExistsResponseTypeError];
    }];
    [request startAsynchronous];
}

- (void)deleteThisClientTemporaryWholeStoreDirectory
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/delete", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    [request addPostValue:[self thisDocumentTemporaryWholeStoreThisClientDirectoryPath] forKey:@"files[]"];
    [request setCompletionBlock:^{
        FCLog(@"Response: %@", requestBlock.responseString);
        [self deletedThisClientTemporaryWholeStoreDirectoryWithSuccess:YES];
    }];
    [request setFailedBlock:^{
        [self deletedThisClientTemporaryWholeStoreDirectoryWithSuccess:NO];
    }];
    [request startAsynchronous];
}

- (void)createThisClientTemporaryWholeStoreDirectory
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/createfolder", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    [request addPostValue:[self thisDocumentTemporaryWholeStoreThisClientDirectoryPath] forKey:@"folders[]"];
    [request setCompletionBlock:^{
        FCLog(@"Response: %@", requestBlock.responseString);
        [self createdThisClientTemporaryWholeStoreDirectoryWithSuccess:YES];
    }];
    [request setFailedBlock:^{
        [self createdThisClientTemporaryWholeStoreDirectoryWithSuccess:NO];
    }];
    [request startAsynchronous];
}

- (void)uploadLocalWholeStoreFileToThisClientTemporaryWholeStoreDirectory
{
    
    NSString *localFilePath = [[self localWholeStoreFileLocation] path];
    
    ASIBasicBlock completionBlock = ^{
        [self uploadedWholeStoreFileToThisClientTemporaryWholeStoreDirectoryWithSuccess:YES];
    };
    ASIBasicBlock failedBlock = ^{
        FCDisplayBasicErrorMessage(@"", @"Upload whole store failed");
        [self uploadedWholeStoreFileToThisClientTemporaryWholeStoreDirectoryWithSuccess:NO];
    };

    [FlashCardsCore uploadFileChunk:localFilePath
                    toFinalLocation:[self thisDocumentTemporaryWholeStoreThisClientDirectoryPath]
                  withFinalFileName:TICDSWholeStoreFilename
                         uploadUUID:@""
                             offset:0
                         errorCount:0
                withCompletionBlock:completionBlock
                    withFailedBlock:failedBlock
                 showUploadProgress:YES];
    
}

- (void)uploadLocalAppliedSyncChangeSetsFileToThisClientTemporaryWholeStoreDirectory
{
    NSString *localFilePath = [[self localAppliedSyncChangeSetsFileLocation] path];
    
    ASIBasicBlock completionBlock = ^{
        [self uploadedAppliedSyncChangeSetsFileToThisClientTemporaryWholeStoreDirectoryWithSuccess:YES];
    };
    ASIBasicBlock failedBlock = ^{
        FCDisplayBasicErrorMessage(@"", @"Upload applied sync changesets failed");
        [self uploadedAppliedSyncChangeSetsFileToThisClientTemporaryWholeStoreDirectoryWithSuccess:NO];
    };
    
    NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:localFilePath error:nil];
    UInt32 fileSize = [[fileAttributes objectForKey:NSFileSize] intValue];
    BOOL showUploadProgress = NO;
    if (fileSize > 1024*200) {
        showUploadProgress = YES;
    }

    [FlashCardsCore uploadFileChunk:localFilePath
                    toFinalLocation:[self thisDocumentTemporaryWholeStoreThisClientDirectoryPath]
                  withFinalFileName:TICDSAppliedSyncChangeSetsFilename
                         uploadUUID:@""
                             offset:0
                         errorCount:0
                withCompletionBlock:completionBlock
                    withFailedBlock:failedBlock
                 showUploadProgress:showUploadProgress];
}

- (void)checkWhetherThisClientWholeStoreDirectoryExists
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/exists", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    [request addPostValue:[self thisDocumentWholeStoreThisClientDirectoryPath] forKey:@"filePath"];
    [request setCompletionBlock:^{
        FCLog(@"Response: %@", requestBlock.responseString);
        NSDictionary *response = (NSDictionary*)[requestBlock.responseString objectFromJSONString];
        TICDSRemoteFileStructureExistsResponseType status = TICDSRemoteFileStructureExistsResponseTypeDoesNotExist;
        if ([[response objectForKey:@"exists"] intValue] == 1) {
            status = TICDSRemoteFileStructureExistsResponseTypeDoesExist;
        }
        [self discoveredStatusOfThisClientWholeStoreDirectory:status];
    }];
    [request setFailedBlock:^{
        [self discoveredStatusOfThisClientWholeStoreDirectory:TICDSRemoteFileStructureExistsResponseTypeError];
    }];
    [request startAsynchronous];
}

- (void)deleteThisClientWholeStoreDirectory
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/delete", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    [request addPostValue:[self thisDocumentWholeStoreThisClientDirectoryPath] forKey:@"files[]"];
    [request setCompletionBlock:^{
        FCLog(@"Response: %@", requestBlock.responseString);
        [self deletedThisClientWholeStoreDirectoryWithSuccess:YES];
    }];
    [request setFailedBlock:^{
        [self deletedThisClientWholeStoreDirectoryWithSuccess:NO];
    }];
    [request startAsynchronous];
}

- (void)copyThisClientTemporaryWholeStoreDirectoryToThisClientWholeStoreDirectory
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/copy", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    [request addPostValue:[self thisDocumentTemporaryWholeStoreThisClientDirectoryPath] forKey:@"fromPath"];
    [request addPostValue:[self thisDocumentWholeStoreThisClientDirectoryPath] forKey:@"toPath"];
    [request setCompletionBlock:^{
        FCLog(@"Response: %@", requestBlock.responseString);
        [self copiedThisClientTemporaryWholeStoreDirectoryToThisClientWholeStoreDirectoryWithSuccess:YES];
    }];
    [request setFailedBlock:^{
        [self copiedThisClientTemporaryWholeStoreDirectoryToThisClientWholeStoreDirectoryWithSuccess:NO];
    }];
    [request startAsynchronous];
}

#pragma mark -
#pragma mark Properties
@synthesize thisDocumentTemporaryWholeStoreThisClientDirectoryPath = _thisDocumentTemporaryWholeStoreThisClientDirectoryPath;
@synthesize thisDocumentTemporaryWholeStoreThisClientDirectoryWholeStoreFilePath = _thisDocumentTemporaryWholeStoreThisClientDirectoryWholeStoreFilePath;
@synthesize thisDocumentTemporaryWholeStoreThisClientDirectoryAppliedSyncChangeSetsFilePath = _thisDocumentTemporaryWholeStoreThisClientDirectoryAppliedSyncChangeSetsFilePath;
@synthesize thisDocumentWholeStoreThisClientDirectoryPath = _thisDocumentWholeStoreThisClientDirectoryPath;

@end

#endif