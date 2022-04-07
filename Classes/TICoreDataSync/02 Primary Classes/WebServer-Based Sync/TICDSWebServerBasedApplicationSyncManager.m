//
//  TICDSWebServerBasedApplicationSyncManager.m
//  iOSNotebook
//
//  Created by Tim Isted on 13/05/2011.
//  Copyright 2011 Tim Isted. All rights reserved.
//

#if TARGET_OS_IPHONE

#import "TICoreDataSync.h"

@implementation TICDSWebServerBasedApplicationSyncManager

#pragma mark -
#pragma mark Overridden Methods
- (TICDSApplicationRegistrationOperation *)applicationRegistrationOperation
{
    TICDSWebServerBasedApplicationRegistrationOperation *operation = [[TICDSWebServerBasedApplicationRegistrationOperation alloc] initWithDelegate:self];
    
    [operation setApplicationDirectoryPath:[self applicationDirectoryPath]];
    [operation setEncryptionDirectorySaltDataFilePath:[self encryptionDirectorySaltDataFilePath]];
    [operation setEncryptionDirectoryTestDataFilePath:[self encryptionDirectoryTestDataFilePath]];
    [operation setClientDevicesThisClientDeviceDirectoryPath:[self clientDevicesThisClientDeviceDirectoryPath]];
    
    return operation;
}

- (TICDSListOfPreviouslySynchronizedDocumentsOperation *)listOfPreviouslySynchronizedDocumentsOperation
{
    TICDSWebServerBasedListOfPreviouslySynchronizedDocumentsOperation *operation = [[TICDSWebServerBasedListOfPreviouslySynchronizedDocumentsOperation alloc] initWithDelegate:self];
    
    [operation setDocumentsDirectoryPath:[self documentsDirectoryPath]];
    
    return operation;
}

- (TICDSWholeStoreDownloadOperation *)wholeStoreDownloadOperationForDocumentWithIdentifier:(NSString *)anIdentifier
{
    TICDSWebServerBasedWholeStoreDownloadOperation *operation = [[TICDSWebServerBasedWholeStoreDownloadOperation alloc] initWithDelegate:self];
    
    [operation setThisDocumentDirectoryPath:[[self documentsDirectoryPath] stringByAppendingPathComponent:anIdentifier]];
    [operation setThisDocumentWholeStoreDirectoryPath:[self pathToWholeStoreDirectoryForDocumentWithIdentifier:anIdentifier]];
    
    return operation;
}

- (TICDSListOfApplicationRegisteredClientsOperation *)listOfApplicationRegisteredClientsOperation
{
    TICDSWebServerBasedListOfApplicationRegisteredClientsOperation *operation = [[TICDSWebServerBasedListOfApplicationRegisteredClientsOperation alloc] initWithDelegate:self];
    
    [operation setClientDevicesDirectoryPath:[self clientDevicesDirectoryPath]];
    [operation setDocumentsDirectoryPath:[self documentsDirectoryPath]];
    
    return operation;
}

- (TICDSDocumentDeletionOperation *)documentDeletionOperationForDocumentWithIdentifier:(NSString *)anIdentifier
{
    TICDSWebServerBasedDocumentDeletionOperation *operation = [[TICDSWebServerBasedDocumentDeletionOperation alloc] initWithDelegate:self];
    
    [operation setDeletedDocumentsDirectoryIdentifierPlistFilePath:[[self deletedDocumentsDirectoryPath] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.%@", anIdentifier, TICDSDocumentInfoPlistExtension]]];
    [operation setDocumentDirectoryPath:[[self documentsDirectoryPath] stringByAppendingPathComponent:anIdentifier]];
    [operation setDocumentInfoPlistFilePath:[[[self documentsDirectoryPath] stringByAppendingPathComponent:anIdentifier] stringByAppendingPathComponent:TICDSDocumentInfoPlistFilenameWithExtension]];
    
    return operation;
}

- (TICDSRemoveAllRemoteSyncDataOperation *)removeAllSyncDataOperation
{
    TICDSWebServerBasedRemoveAllRemoteSyncDataOperation *operation = [[TICDSWebServerBasedRemoveAllRemoteSyncDataOperation alloc] initWithDelegate:self];
    
    [operation setApplicationDirectoryPath:[self applicationDirectoryPath]];
    
    return operation;
}

#pragma mark -
#pragma mark Paths
- (NSString *)applicationDirectoryPath
{
    return [NSString stringWithFormat:@"/%@", [self appIdentifier]];
}

- (NSString *)deletedDocumentsDirectoryPath
{
    return [[self applicationDirectoryPath] stringByAppendingPathComponent:[self relativePathToInformationDeletedDocumentsDirectory]];
}

- (NSString *)encryptionDirectorySaltDataFilePath
{
    return [[self applicationDirectoryPath] stringByAppendingPathComponent:[self relativePathToEncryptionDirectorySaltDataFilePath]];
}

- (NSString *)encryptionDirectoryTestDataFilePath
{
    return [[self applicationDirectoryPath] stringByAppendingPathComponent:[self relativePathToEncryptionDirectoryTestDataFilePath]];
}

- (NSString *)clientDevicesDirectoryPath
{
    return [[self applicationDirectoryPath] stringByAppendingPathComponent:[self relativePathToClientDevicesDirectory]];
}

- (NSString *)clientDevicesThisClientDeviceDirectoryPath
{
    return [[self applicationDirectoryPath] stringByAppendingPathComponent:[self relativePathToClientDevicesThisClientDeviceDirectory]];
}

- (NSString *)documentsDirectoryPath
{
    return [[self applicationDirectoryPath] stringByAppendingPathComponent:[self relativePathToDocumentsDirectory]];
}

- (NSString *)pathToWholeStoreDirectoryForDocumentWithIdentifier:(NSString *)anIdentifier
{
    return [[self applicationDirectoryPath] stringByAppendingPathComponent:[self relativePathToWholeStoreDirectoryForDocumentWithIdentifier:anIdentifier]];
}

#pragma mark -
#pragma mark Initialization and Deallocation

@end

#endif