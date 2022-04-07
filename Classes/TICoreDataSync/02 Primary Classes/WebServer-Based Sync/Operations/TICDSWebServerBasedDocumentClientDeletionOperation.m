//
//  TICDSWebServerBasedDocumentClientDeletionOperation.m
//  iOSNotebook
//
//  Created by Tim Isted on 04/06/2011.
//  Copyright 2011 Tim Isted. All rights reserved.
//

#if TARGET_OS_IPHONE

#import "TICoreDataSync.h"
#import "JSONKit.h"

@implementation TICDSWebServerBasedDocumentClientDeletionOperation

- (BOOL)needsMainThread
{
    return NO;
}

- (void)checkWhetherClientDirectoryExistsInDocumentSyncChangesDirectory
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/exists", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    [request addPostValue:[[self thisDocumentSyncChangesDirectoryPath] stringByAppendingPathComponent:[self identifierOfClientToBeDeleted]] forKey:@"filePath"];
    [request setCompletionBlock:^{
        FCLog(@"Response: %@", requestBlock.responseString);
        NSDictionary *response = (NSDictionary*)[requestBlock.responseString objectFromJSONString];
        TICDSRemoteFileStructureExistsResponseType status = TICDSRemoteFileStructureExistsResponseTypeDoesNotExist;
        if ([[response objectForKey:@"exists"] intValue] == 1) {
            status = TICDSRemoteFileStructureExistsResponseTypeDoesExist;
        }
        [self discoveredStatusOfClientDirectoryInDocumentSyncChangesDirectory:status];
    }];
    [request setFailedBlock:^{
        [self discoveredStatusOfClientDirectoryInDocumentSyncChangesDirectory:TICDSRemoteFileStructureExistsResponseTypeError];
    }];
    [request startAsynchronous];
}

- (void)checkWhetherClientIdentifierFileAlreadyExistsInDocumentDeletedClientsDirectory
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/exists", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    [request addPostValue:[[[self thisDocumentDeletedClientsDirectoryPath] stringByAppendingPathComponent:[self identifierOfClientToBeDeleted]] stringByAppendingPathExtension:TICDSDeviceInfoPlistExtension] forKey:@"filePath"];
    [request setCompletionBlock:^{
        FCLog(@"Response: %@", requestBlock.responseString);
        NSDictionary *response = (NSDictionary*)[requestBlock.responseString objectFromJSONString];
        TICDSRemoteFileStructureExistsResponseType status = TICDSRemoteFileStructureExistsResponseTypeDoesNotExist;
        if ([[response objectForKey:@"exists"] intValue] == 1) {
            status = TICDSRemoteFileStructureExistsResponseTypeDoesExist;
        }
        [self discoveredStatusOfClientIdentifierFileInDocumentDeletedClientsDirectory:status];
    }];
    [request setFailedBlock:^{
        [self discoveredStatusOfClientIdentifierFileInDocumentDeletedClientsDirectory:TICDSRemoteFileStructureExistsResponseTypeError];
    }];
    [request startAsynchronous];
}

- (void)deleteClientIdentifierFileFromDeletedClientsDirectory
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/delete", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    [request addPostValue:[[[self thisDocumentDeletedClientsDirectoryPath] stringByAppendingPathComponent:[self identifierOfClientToBeDeleted]] stringByAppendingPathExtension:TICDSDeviceInfoPlistExtension]
                   forKey:@"files[]"];
    [request setCompletionBlock:^{
        FCLog(@"Response: %@", requestBlock.responseString);
        [self deletedClientIdentifierFileFromDeletedClientsDirectoryWithSuccess:YES];
    }];
    [request setFailedBlock:^{
        [self deletedClientIdentifierFileFromDeletedClientsDirectoryWithSuccess:NO];
    }];
    [request startAsynchronous];
}

- (void)copyClientDeviceInfoPlistToDeletedClientsDirectory
{
    NSString *deviceInfoFilePath = [[[self clientDevicesDirectoryPath] stringByAppendingPathComponent:[self identifierOfClientToBeDeleted]] stringByAppendingPathComponent:TICDSDeviceInfoPlistFilenameWithExtension];
    
    NSString *finalFilePath = [[[self thisDocumentDeletedClientsDirectoryPath] stringByAppendingPathComponent:[self identifierOfClientToBeDeleted]] stringByAppendingPathExtension:TICDSDeviceInfoPlistExtension];
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/copy", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    [request addPostValue:deviceInfoFilePath forKey:@"fromPath"];
    [request addPostValue:finalFilePath forKey:@"toPath"];
    [request setCompletionBlock:^{
        FCLog(@"Response: %@", requestBlock.responseString);
        [self copiedClientDeviceInfoPlistToDeletedClientsDirectoryWithSuccess:YES];
    }];
    [request setFailedBlock:^{
        [self copiedClientDeviceInfoPlistToDeletedClientsDirectoryWithSuccess:NO];
    }];
    [request startAsynchronous];
}

- (void)deleteClientDirectoryFromDocumentSyncChangesDirectory
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/delete", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    [request addPostValue:[[self thisDocumentSyncChangesDirectoryPath] stringByAppendingPathComponent:[self identifierOfClientToBeDeleted]] forKey:@"files[]"];
    [request setCompletionBlock:^{
        FCLog(@"Response: %@", requestBlock.responseString);
        [self deletedClientDirectoryFromDocumentSyncChangesDirectoryWithSuccess:YES];
    }];
    [request setFailedBlock:^{
        [self deletedClientDirectoryFromDocumentSyncChangesDirectoryWithSuccess:NO];
    }];
    [request startAsynchronous];
}

- (void)deleteClientDirectoryFromDocumentSyncCommandsDirectory
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/delete", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    [request addPostValue:[[self thisDocumentSyncCommandsDirectoryPath] stringByAppendingPathComponent:[self identifierOfClientToBeDeleted]] forKey:@"files[]"];
    [request setCompletionBlock:^{
        FCLog(@"Response: %@", requestBlock.responseString);
        [self deletedClientDirectoryFromDocumentSyncCommandsDirectoryWithSuccess:YES];
    }];
    [request setFailedBlock:^{
        [self deletedClientDirectoryFromDocumentSyncCommandsDirectoryWithSuccess:NO];
    }];
    [request startAsynchronous];
}

- (void)checkWhetherClientIdentifierFileExistsInRecentSyncsDirectory
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/exists", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    [request addPostValue:[[[self thisDocumentRecentSyncsDirectoryPath] stringByAppendingPathComponent:[self identifierOfClientToBeDeleted]] stringByAppendingPathExtension:TICDSRecentSyncFileExtension] forKey:@"filePath"];
    [request setCompletionBlock:^{
        FCLog(@"Response: %@", requestBlock.responseString);
        NSDictionary *response = (NSDictionary*)[requestBlock.responseString objectFromJSONString];
        TICDSRemoteFileStructureExistsResponseType status = TICDSRemoteFileStructureExistsResponseTypeDoesNotExist;
        if ([[response objectForKey:@"exists"] intValue] == 1) {
            status = TICDSRemoteFileStructureExistsResponseTypeDoesExist;
        }
        [self discoveredStatusOfClientIdentifierFileInDocumentRecentSyncsDirectory:status];
    }];
    [request setFailedBlock:^{
        [self discoveredStatusOfClientIdentifierFileInDocumentRecentSyncsDirectory:TICDSRemoteFileStructureExistsResponseTypeError];
    }];
    [request startAsynchronous];
}

- (void)deleteClientIdentifierFileFromRecentSyncsDirectory
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/delete", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    [request addPostValue:[[[self thisDocumentRecentSyncsDirectoryPath] stringByAppendingPathComponent:[self identifierOfClientToBeDeleted]] stringByAppendingPathExtension:TICDSRecentSyncFileExtension] forKey:@"files[]"];
    [request setCompletionBlock:^{
        FCLog(@"Response: %@", requestBlock.responseString);
        [self deletedClientIdentifierFileFromRecentSyncsDirectoryWithSuccess:YES];
    }];
    [request setFailedBlock:^{
        [self deletedClientIdentifierFileFromRecentSyncsDirectoryWithSuccess:NO];
    }];
    [request startAsynchronous];
}

- (void)checkWhetherClientDirectoryExistsInDocumentWholeStoreDirectory
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/exists", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    [request addPostValue:[[self thisDocumentWholeStoreDirectoryPath] stringByAppendingPathComponent:[self identifierOfClientToBeDeleted]] forKey:@"filePath"];
    [request setCompletionBlock:^{
        FCLog(@"Response: %@", requestBlock.responseString);
        NSDictionary *response = (NSDictionary*)[requestBlock.responseString objectFromJSONString];
        TICDSRemoteFileStructureExistsResponseType status = TICDSRemoteFileStructureExistsResponseTypeDoesNotExist;
        if ([[response objectForKey:@"exists"] intValue] == 1) {
            status = TICDSRemoteFileStructureExistsResponseTypeDoesExist;
        }
        [self discoveredStatusOfClientDirectoryInDocumentWholeStoreDirectory:status];
    }];
    [request setFailedBlock:^{
        [self discoveredStatusOfClientDirectoryInDocumentWholeStoreDirectory:TICDSRemoteFileStructureExistsResponseTypeError];
    }];
    [request startAsynchronous];
}

- (void)deleteClientDirectoryFromDocumentWholeStoreDirectory
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/delete", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    [request addPostValue:[[self thisDocumentWholeStoreDirectoryPath] stringByAppendingPathComponent:[self identifierOfClientToBeDeleted]] forKey:@"files[]"];
    [request setCompletionBlock:^{
        FCLog(@"Response: %@", requestBlock.responseString);
        [self deletedClientDirectoryFromDocumentWholeStoreDirectoryWithSuccess:YES];
    }];
    [request setFailedBlock:^{
        [self deletedClientDirectoryFromDocumentWholeStoreDirectoryWithSuccess:NO];
    }];
    [request startAsynchronous];
}

#pragma mark -
#pragma mark Initialization and Deallocation
- (void)dealloc
{
    _clientDevicesDirectoryPath = nil;
    _thisDocumentDeletedClientsDirectoryPath = nil;
    _thisDocumentSyncChangesDirectoryPath = nil;
    _thisDocumentSyncCommandsDirectoryPath = nil;
    _thisDocumentRecentSyncsDirectoryPath = nil;
    _thisDocumentWholeStoreDirectoryPath = nil;
    
}

#pragma mark -
#pragma mark Properties
@synthesize clientDevicesDirectoryPath = _clientDevicesDirectoryPath;
@synthesize thisDocumentDeletedClientsDirectoryPath = _thisDocumentDeletedClientsDirectoryPath;
@synthesize thisDocumentSyncChangesDirectoryPath = _thisDocumentSyncChangesDirectoryPath;
@synthesize thisDocumentSyncCommandsDirectoryPath = _thisDocumentSyncCommandsDirectoryPath;
@synthesize thisDocumentRecentSyncsDirectoryPath = _thisDocumentRecentSyncsDirectoryPath;
@synthesize thisDocumentWholeStoreDirectoryPath = _thisDocumentWholeStoreDirectoryPath;

@end

#endif