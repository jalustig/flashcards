//
//  TICDSWebServerBasedDocumentSyncManager.m
//  iOSNotebook
//
//  Created by Tim Isted on 14/05/2011.
//  Copyright 2011 Tim Isted. All rights reserved.
//

#if TARGET_OS_IPHONE

#import "TICoreDataSync.h"


@implementation TICDSWebServerBasedDocumentSyncManager

#pragma mark -
#pragma mark Registration
- (void)registerWithDelegate:(id<TICDSDocumentSyncManagerDelegate>)aDelegate appSyncManager:(TICDSApplicationSyncManager *)anAppSyncManager managedObjectContext:(NSManagedObjectContext *)aContext documentIdentifier:(NSString *)aDocumentIdentifier description:(NSString *)aDocumentDescription userInfo:(NSDictionary *)someUserInfo
{
    if( [anAppSyncManager isKindOfClass:[TICDSWebServerBasedApplicationSyncManager class]] ) {
        [self setApplicationDirectoryPath:[(TICDSWebServerBasedApplicationSyncManager *)anAppSyncManager applicationDirectoryPath]];
    }
    
    [super registerWithDelegate:aDelegate appSyncManager:anAppSyncManager managedObjectContext:aContext documentIdentifier:aDocumentIdentifier description:aDocumentDescription userInfo:someUserInfo];
}

- (void)registerConfiguredDocumentSyncManager
{
    if( [[self applicationSyncManager] isKindOfClass:[TICDSWebServerBasedApplicationSyncManager class]] ) {
        [self setApplicationDirectoryPath:[(TICDSWebServerBasedApplicationSyncManager *)[self applicationSyncManager] applicationDirectoryPath]];
    }
    
    [super registerConfiguredDocumentSyncManager];
}

#pragma mark -
#pragma mark Operation Classes
- (TICDSDocumentRegistrationOperation *)documentRegistrationOperation
{
    TICDSWebServerBasedDocumentRegistrationOperation *operation = [[TICDSWebServerBasedDocumentRegistrationOperation alloc] initWithDelegate:self];
    
    [operation setClientDevicesDirectoryPath:[self clientDevicesDirectoryPath]];
    [operation setThisDocumentDirectoryPath:[self thisDocumentDirectoryPath]];
    [operation setThisDocumentDeletedClientsDirectoryPath:[self thisDocumentDeletedClientsDirectoryPath]];
    [operation setDeletedDocumentsDirectoryIdentifierPlistFilePath:[self deletedDocumentsDirectoryIdentifierPlistFilePath]];
    [operation setThisDocumentSyncChangesThisClientDirectoryPath:[self thisDocumentSyncChangesThisClientDirectoryPath]];
    [operation setThisDocumentSyncCommandsThisClientDirectoryPath:[self thisDocumentSyncCommandsThisClientDirectoryPath]];
    
    return operation;
}

- (TICDSWholeStoreDownloadOperation *)wholeStoreDownloadOperation
{
    TICDSWebServerBasedWholeStoreDownloadOperation *operation = [[TICDSWebServerBasedWholeStoreDownloadOperation alloc] initWithDelegate:self];
    
    [operation setThisDocumentDirectoryPath:[self thisDocumentDirectoryPath]];
    [operation setThisDocumentWholeStoreDirectoryPath:[self thisDocumentWholeStoreDirectoryPath]];
    
    return operation;
}

- (TICDSWholeStoreUploadOperation *)wholeStoreUploadOperation
{
    TICDSWebServerBasedWholeStoreUploadOperation *operation = [[TICDSWebServerBasedWholeStoreUploadOperation alloc] initWithDelegate:self];
    
    [operation setThisDocumentTemporaryWholeStoreThisClientDirectoryPath:[self thisDocumentTemporaryWholeStoreThisClientDirectoryPath]];
    [operation setThisDocumentTemporaryWholeStoreThisClientDirectoryWholeStoreFilePath:[self thisDocumentTemporaryWholeStoreFilePath]];
    [operation setThisDocumentTemporaryWholeStoreThisClientDirectoryAppliedSyncChangeSetsFilePath:[self thisDocumentTemporaryAppliedSyncChangeSetsFilePath]];
    [operation setThisDocumentWholeStoreThisClientDirectoryPath:[self thisDocumentWholeStoreThisClientDirectoryPath]];
    
    return operation;
}

- (TICDSPreSynchronizationOperation *)preSynchronizationOperation
{
    TICDSWebServerBasedPreSynchronizationOperation *operation = [[TICDSWebServerBasedPreSynchronizationOperation alloc] initWithDelegate:self];
    
    [operation setThisDocumentDirectoryPath:[self thisDocumentDirectoryPath]];
    [operation setThisDocumentSyncChangesDirectoryPath:[self thisDocumentSyncChangesDirectoryPath]];
    
    return operation;
}

- (TICDSPostSynchronizationOperation *)postSynchronizationOperation
{
    TICDSWebServerBasedPostSynchronizationOperation *operation = [[TICDSWebServerBasedPostSynchronizationOperation alloc] initWithDelegate:self];
    
    [operation setThisDocumentSyncChangesDirectoryPath:[self thisDocumentSyncChangesDirectoryPath]];
    [operation setThisDocumentSyncChangesThisClientDirectoryPath:[self thisDocumentSyncChangesThisClientDirectoryPath]];
    [operation setThisDocumentRecentSyncsThisClientFilePath:[self thisDocumentRecentSyncsThisClientFilePath]];
    
    return operation;
}

- (TICDSVacuumOperation *)vacuumOperation
{
    TICDSWebServerBasedVacuumOperation *operation = [[TICDSWebServerBasedVacuumOperation alloc] initWithDelegate:self];
    
    [operation setThisDocumentWholeStoreDirectoryPath:[self thisDocumentWholeStoreDirectoryPath]];
    [operation setThisDocumentRecentSyncsDirectoryPath:[self thisDocumentRecentSyncsDirectoryPath]];
    [operation setThisDocumentSyncChangesThisClientDirectoryPath:[self thisDocumentSyncChangesThisClientDirectoryPath]];
    
    return operation;
}

- (TICDSListOfDocumentRegisteredClientsOperation *)listOfDocumentRegisteredClientsOperation
{
    TICDSWebServerBasedListOfDocumentRegisteredClientsOperation *operation = [[TICDSWebServerBasedListOfDocumentRegisteredClientsOperation alloc] initWithDelegate:self];
    
    [operation setThisDocumentSyncChangesDirectoryPath:[self thisDocumentSyncChangesDirectoryPath]];
    [operation setClientDevicesDirectoryPath:[self clientDevicesDirectoryPath]];
    [operation setThisDocumentRecentSyncsDirectoryPath:[self thisDocumentRecentSyncsDirectoryPath]];
    [operation setThisDocumentWholeStoreDirectoryPath:[self thisDocumentWholeStoreDirectoryPath]];
    
    return operation;
}

- (TICDSDocumentClientDeletionOperation *)documentClientDeletionOperation
{
    TICDSWebServerBasedDocumentClientDeletionOperation *operation = [[TICDSWebServerBasedDocumentClientDeletionOperation alloc] initWithDelegate:self];
    
    [operation setClientDevicesDirectoryPath:[self clientDevicesDirectoryPath]];
    [operation setThisDocumentDeletedClientsDirectoryPath:[self thisDocumentDeletedClientsDirectoryPath]];
    [operation setThisDocumentSyncChangesDirectoryPath:[self thisDocumentSyncChangesDirectoryPath]];
    [operation setThisDocumentSyncCommandsDirectoryPath:[self thisDocumentSyncCommandsDirectoryPath]];
    [operation setThisDocumentRecentSyncsDirectoryPath:[self thisDocumentRecentSyncsDirectoryPath]];
    [operation setThisDocumentWholeStoreDirectoryPath:[self thisDocumentWholeStoreDirectoryPath]];
    
    return operation;
}

#pragma mark -
#pragma mark Paths
- (NSString *)clientDevicesDirectoryPath
{
    return [[self applicationDirectoryPath] stringByAppendingPathComponent:[self relativePathToClientDevicesDirectory]];
}

- (NSString *)deletedDocumentsDirectoryIdentifierPlistFilePath
{
    return [[self applicationDirectoryPath] stringByAppendingPathComponent:[self relativePathToDeletedDocumentsThisDocumentIdentifierPlistFile]];
}

- (NSString *)documentsDirectoryPath
{
    return [[self applicationDirectoryPath] stringByAppendingPathComponent:[self relativePathToDocumentsDirectory]];
}

- (NSString *)thisDocumentDirectoryPath
{
    return [[self applicationDirectoryPath] stringByAppendingPathComponent:[self relativePathToThisDocumentDirectory]];
}

- (NSString *)thisDocumentDeletedClientsDirectoryPath
{
    return [[self applicationDirectoryPath] stringByAppendingPathComponent:[self relativePathToThisDocumentDeletedClientsDirectory]];
}

- (NSString *)thisDocumentSyncChangesDirectoryPath
{
    return [[self applicationDirectoryPath] stringByAppendingPathComponent:[self relativePathToThisDocumentSyncChangesDirectory]];
}

- (NSString *)thisDocumentSyncChangesThisClientDirectoryPath
{
    return [[self applicationDirectoryPath] stringByAppendingPathComponent:[self relativePathToThisDocumentSyncChangesThisClientDirectory]];
}

- (NSString *)thisDocumentSyncCommandsDirectoryPath
{
    return [[self applicationDirectoryPath] stringByAppendingPathComponent:[self relativePathToThisDocumentSyncCommandsDirectory]];
}

- (NSString *)thisDocumentSyncCommandsThisClientDirectoryPath
{
    return [[self applicationDirectoryPath] stringByAppendingPathComponent:[self relativePathToThisDocumentSyncCommandsThisClientDirectory]];
}

- (NSString *)thisDocumentTemporaryWholeStoreThisClientDirectoryPath
{
    return [[self applicationDirectoryPath] stringByAppendingPathComponent:[self relativePathToThisDocumentTemporaryWholeStoreThisClientDirectory]];
}

- (NSString *)thisDocumentTemporaryWholeStoreFilePath
{
    return [[self applicationDirectoryPath] stringByAppendingPathComponent:[self relativePathToThisDocumentTemporaryWholeStoreThisClientDirectoryWholeStoreFile]];
}

- (NSString *)thisDocumentTemporaryAppliedSyncChangeSetsFilePath
{
    return [[self applicationDirectoryPath] stringByAppendingPathComponent:[self relativePathToThisDocumentWholeStoreThisClientDirectoryAppliedSyncChangeSetsFile]];
}

- (NSString *)thisDocumentWholeStoreDirectoryPath
{
    return [[self applicationDirectoryPath] stringByAppendingPathComponent:[self relativePathToThisDocumentWholeStoreDirectory]];
}

- (NSString *)thisDocumentWholeStoreThisClientDirectoryPath
{
    return [[self applicationDirectoryPath] stringByAppendingPathComponent:[self relativePathToThisDocumentWholeStoreThisClientDirectory]];
}

- (NSString *)thisDocumentWholeStoreFilePath
{
    return [[self applicationDirectoryPath] stringByAppendingPathComponent:[self relativePathToThisDocumentWholeStoreThisClientDirectoryWholeStoreFile]];
}

- (NSString *)thisDocumentAppliedSyncChangeSetsFilePath
{
    return [[self applicationDirectoryPath] stringByAppendingPathComponent:[self relativePathToThisDocumentWholeStoreThisClientDirectoryAppliedSyncChangeSetsFile]];
}

- (NSString *)thisDocumentRecentSyncsDirectoryPath
{
    return [[self applicationDirectoryPath] stringByAppendingPathComponent:[self relativePathToThisDocumentRecentSyncsDirectory]];
}

- (NSString *)thisDocumentRecentSyncsThisClientFilePath
{
    return [[self applicationDirectoryPath] stringByAppendingPathComponent:[self relativePathToThisDocumentRecentSyncsDirectoryThisClientFile]];
}

#pragma mark -
#pragma mark Initialization and Deallocation
- (void)dealloc
{
    _applicationDirectoryPath = nil;

}

- (void)stopPollingRemoteStorageForChanges
{
}


#pragma mark -
#pragma mark Properties
@synthesize applicationDirectoryPath = _applicationDirectoryPath;

@end

#endif