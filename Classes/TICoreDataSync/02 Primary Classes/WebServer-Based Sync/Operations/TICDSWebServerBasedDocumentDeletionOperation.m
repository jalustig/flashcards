//
//  TICDSWebServerBasedDocumentDeletionOperation.m
//  iOSNotebook
//
//  Created by Tim Isted on 29/05/2011.
//  Copyright 2011 Tim Isted. All rights reserved.
//

#if TARGET_OS_IPHONE

#import "TICoreDataSync.h"
#import "JSONKit.h"

@implementation TICDSWebServerBasedDocumentDeletionOperation

- (BOOL)needsMainThread
{
    return NO;
}

- (void)checkWhetherIdentifiedDocumentDirectoryExists
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/exists", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    [request addPostValue:[self documentDirectoryPath] forKey:@"filePath"];
    [request setCompletionBlock:^{
        FCLog(@"Response: %@", requestBlock.responseString);
        NSDictionary *response = (NSDictionary*)[requestBlock.responseString objectFromJSONString];
        TICDSRemoteFileStructureExistsResponseType status = TICDSRemoteFileStructureExistsResponseTypeDoesNotExist;
        if ([[response objectForKey:@"exists"] intValue] == 1) {
            status = TICDSRemoteFileStructureExistsResponseTypeDoesExist;
        }
        [self discoveredStatusOfIdentifiedDocumentDirectory:status];
    }];
    [request setFailedBlock:^{
        [self discoveredStatusOfIdentifiedDocumentDirectory:TICDSRemoteFileStructureExistsResponseTypeError];
    }];
    [request startAsynchronous];
}

- (void)checkForExistingIdentifierPlistInDeletedDocumentsDirectory
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/exists", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    [request addPostValue:[self deletedDocumentsDirectoryIdentifierPlistFilePath] forKey:@"filePath"];
    [request setCompletionBlock:^{
        FCLog(@"Response: %@", requestBlock.responseString);
        NSDictionary *response = (NSDictionary*)[requestBlock.responseString objectFromJSONString];
        TICDSRemoteFileStructureExistsResponseType status = TICDSRemoteFileStructureExistsResponseTypeDoesNotExist;
        if ([[response objectForKey:@"exists"] intValue] == 1) {
            status = TICDSRemoteFileStructureExistsResponseTypeDoesExist;
        }
        [self discoveredStatusOfIdentifierPlistInDeletedDocumentsDirectory:status];
    }];
    [request setFailedBlock:^{
        [self discoveredStatusOfIdentifierPlistInDeletedDocumentsDirectory:TICDSRemoteFileStructureExistsResponseTypeError];
    }];
    [request startAsynchronous];
}

- (void)deleteDocumentInfoPlistFromDeletedDocumentsDirectory
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/delete", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    [request addPostValue:[self deletedDocumentsDirectoryIdentifierPlistFilePath] forKey:@"files[]"];
    [request setCompletionBlock:^{
        FCLog(@"Response: %@", requestBlock.responseString);
        [self deletedDocumentInfoPlistFromDeletedDocumentsDirectoryWithSuccess:YES];
    }];
    [request setFailedBlock:^{
        [self deletedDocumentInfoPlistFromDeletedDocumentsDirectoryWithSuccess:NO];
    }];
    [request startAsynchronous];
}

- (void)copyDocumentInfoPlistToDeletedDocumentsDirectory
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/copy", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    [request addPostValue:[self documentInfoPlistFilePath] forKey:@"fromPath"];
    [request addPostValue:[self deletedDocumentsDirectoryIdentifierPlistFilePath] forKey:@"toPath"];
    [request setCompletionBlock:^{
        FCLog(@"Response: %@", requestBlock.responseString);
        [self copiedDocumentInfoPlistToDeletedDocumentsDirectoryWithSuccess:YES];
    }];
    [request setFailedBlock:^{
        [self copiedDocumentInfoPlistToDeletedDocumentsDirectoryWithSuccess:NO];
    }];
    [request startAsynchronous];
}

- (void)deleteDocumentDirectory
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/delete", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    [request addPostValue:[self documentDirectoryPath] forKey:@"files[]"];
    [request setCompletionBlock:^{
        FCLog(@"Response: %@", requestBlock.responseString);
        [self deletedDocumentDirectoryWithSuccess:YES];
    }];
    [request setFailedBlock:^{
        [self deletedDocumentDirectoryWithSuccess:NO];
    }];
    [request startAsynchronous];
}

#pragma mark -
#pragma mark Initialization and Deallocation
- (void)dealloc
{
    _documentDirectoryPath = nil;
    _documentInfoPlistFilePath = nil;
    _deletedDocumentsDirectoryIdentifierPlistFilePath = nil;

}


#pragma mark -
#pragma mark Properties
@synthesize documentDirectoryPath = _documentDirectoryPath;
@synthesize documentInfoPlistFilePath = _documentInfoPlistFilePath;
@synthesize deletedDocumentsDirectoryIdentifierPlistFilePath = _deletedDocumentsDirectoryIdentifierPlistFilePath;

@end

#endif