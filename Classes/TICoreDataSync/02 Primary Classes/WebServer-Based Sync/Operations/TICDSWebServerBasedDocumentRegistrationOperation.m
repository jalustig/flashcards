//
//  TICDSWebServerBasedDocumentRegistrationOperation.m
//  iOSNotebook
//
//  Created by Tim Isted on 14/05/2011.
//  Copyright 2011 Tim Isted. All rights reserved.
//

#if TARGET_OS_IPHONE

#import "TICDSWebServerBasedDocumentRegistrationOperation.h"
#import "JSONKit.h"

@implementation TICDSWebServerBasedDocumentRegistrationOperation

#pragma mark -
#pragma mark Overridden Document Methods
- (BOOL)needsMainThread
{
    return NO;
}

#pragma mark -
#pragma mark Document Directory
- (void)checkWhetherRemoteDocumentDirectoryExists
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/exists", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    [request addPostValue:[self thisDocumentDirectoryPath] forKey:@"filePath"];
    [request setCompletionBlock:^{
        FCLog(@"Response: %@", requestBlock.responseString);
        NSDictionary *response = (NSDictionary*)[requestBlock.responseString objectFromJSONString];
        TICDSRemoteFileStructureExistsResponseType status = TICDSRemoteFileStructureExistsResponseTypeDoesNotExist;
        if ([[response objectForKey:@"exists"] intValue] == 1) {
            status = TICDSRemoteFileStructureExistsResponseTypeDoesExist;
        }
        [self discoveredStatusOfRemoteDocumentDirectory:status];
    }];
    [request setFailedBlock:^{
        [self discoveredStatusOfRemoteDocumentDirectory:TICDSRemoteFileStructureExistsResponseTypeError];
    }];
    [request startAsynchronous];
}

- (void)checkWhetherRemoteDocumentWasDeleted
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/exists", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    [request addPostValue:[self deletedDocumentsDirectoryIdentifierPlistFilePath] forKey:@"filePath"];
    [request setCompletionBlock:^{
        FCLog(@"Response: %@", requestBlock.responseString);
        NSDictionary *response = (NSDictionary*)[requestBlock.responseString objectFromJSONString];
        TICDSRemoteFileStructureExistsResponseType status = TICDSRemoteFileStructureDeletionResponseTypeNotDeleted;
        if ([[response objectForKey:@"exists"] intValue] == 1) {
            status = TICDSRemoteFileStructureDeletionResponseTypeDeleted;
        }
        [self discoveredDeletionStatusOfRemoteDocument:status];
    }];
    [request setFailedBlock:^{
        [self discoveredDeletionStatusOfRemoteDocument:TICDSRemoteFileStructureExistsResponseTypeError];
    }];
    [request startAsynchronous];
}

- (void)createRemoteDocumentDirectoryStructure
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/establish", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    [request addPostValue:[[TICDSUtilities remoteDocumentDirectoryHierarchy] JSONString]
                   forKey:@"hierarchy"];
    [request addPostValue:[self thisDocumentDirectoryPath]
                   forKey:@"in_folder"];
    [request setCompletionBlock:^{
        FCLog(@"Response: %@", requestBlock.responseString);
        [self createdRemoteDocumentDirectoryStructureWithSuccess:YES];
    }];
    [request setFailedBlock:^{
        [self createdRemoteDocumentDirectoryStructureWithSuccess:NO];
    }];
    [request startAsynchronous];
}

#pragma mark documentInfo.plist
- (void)saveRemoteDocumentInfoPlistFromDictionary:(NSDictionary *)aDictionary
{
    BOOL success = YES;
    
    NSString *finalFilePath = [[self tempFileDirectoryPath] stringByAppendingPathComponent:TICDSDocumentInfoPlistFilenameWithExtension];
    
    success = [aDictionary writeToFile:finalFilePath atomically:NO];
    
    if( !success ) {
        [self setError:[TICDSError errorWithCode:TICDSErrorCodeFileManagerError classAndMethod:__PRETTY_FUNCTION__]];
    }
    
    if( !success ) {
        [self savedRemoteDocumentInfoPlistWithSuccess:NO];
        return;
    }
    
    // The document info plist will not exist in this point in the workflow. There is no point in doing the dance to figure out if there is a parent revision because there won't be one.
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/upload", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    [request addPostValue:[self thisDocumentDirectoryPath]
                   forKey:@"toPath"];
    [request addPostValue:TICDSDocumentInfoPlistFilenameWithExtension
                   forKey:@"fileName"];
    [request addFile:finalFilePath
        withFileName:TICDSDocumentInfoPlistFilenameWithExtension
      andContentType:@"application/octet-stream"
              forKey:@"fileData"];
    [request setCompletionBlock:^{
        FCLog(@"Response: %@", requestBlock.responseString);
        [self savedRemoteDocumentInfoPlistWithSuccess:YES];
    }];
    [request setFailedBlock:^{
        [self savedRemoteDocumentInfoPlistWithSuccess:NO];
    }];
    [request startAsynchronous];
}

#pragma mark Integrity Key
- (void)fetchRemoteIntegrityKey
{
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

- (void)saveIntegrityKey:(NSString *)aKey
{
    NSString *remoteDirectory = [[self thisDocumentDirectoryPath] stringByAppendingPathComponent:TICDSIntegrityKeyDirectoryName];
    NSString *localFilePath = [[self tempFileDirectoryPath] stringByAppendingPathComponent:aKey];
    
    NSDictionary *dictionary = [NSDictionary dictionaryWithObject:[self clientIdentifier] forKey:kTICDSOriginalDeviceIdentifier];
    
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:dictionary];
    
    NSError *anyError = nil;
    if( [[self fileManager] fileExistsAtPath:localFilePath] && ![[self fileManager] removeItemAtPath:localFilePath error:&anyError] ) {
        [self setError:[TICDSError errorWithCode:TICDSErrorCodeFileManagerError underlyingError:anyError classAndMethod:__PRETTY_FUNCTION__]];
        return;
    }
    
    BOOL success = [data writeToFile:localFilePath options:0 error:&anyError];
    
    if( !success ) {
        [self setError:[TICDSError errorWithCode:TICDSErrorCodeFileManagerError underlyingError:anyError classAndMethod:__PRETTY_FUNCTION__]];
        [self savedIntegrityKeyWithSuccess:success];
        return;
    }
  
    // The integrity will not exist in this point in the workflow. There is no point in doing the dance to figure out if there is a parent revision because there won't be one.
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/upload", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    [request addPostValue:remoteDirectory
                   forKey:@"toPath"];
    [request addPostValue:aKey
                   forKey:@"fileName"];
    [request addFile:localFilePath
        withFileName:aKey
      andContentType:@"application/octet-stream"
              forKey:@"fileData"];
    [request setCompletionBlock:^{
        FCLog(@"Response: %@", requestBlock.responseString);
        [self savedIntegrityKeyWithSuccess:YES];
    }];
    [request setFailedBlock:^{
        [self savedIntegrityKeyWithSuccess:NO];
    }];
    [request startAsynchronous];
}

#pragma mark Adding Other Clients to Document's DeletedClients Directory
- (void)fetchListOfIdentifiersOfAllRegisteredClientsForThisApplication
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/metadata", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    [request addPostValue:[self clientDevicesDirectoryPath]
                   forKey:@"filePath"];
    [request setCompletionBlock:^{
        FCLog(@"Response: %@", requestBlock.responseString);
        NSDictionary *results = [requestBlock.responseString objectFromJSONString];
        NSMutableArray *identifiers = [NSMutableArray arrayWithCapacity:0];
        
        for (NSDictionary *path in [results objectForKey:@"contents"]) {
            if ([[path valueForKey:@"fileName"] length] < 5 ) {
                continue;
            }
            
            [identifiers addObject:[path valueForKey:@"fileName"]];
        }
        
        [self fetchedListOfIdentifiersOfAllRegisteredClientsForThisApplication:identifiers];
    }];
    [request setFailedBlock:^{
        [self fetchedListOfIdentifiersOfAllRegisteredClientsForThisApplication:nil];
    }];
    [request startAsynchronous];
}

- (void)addDeviceInfoPlistToDocumentDeletedClientsForClientWithIdentifier:(NSString *)anIdentifier
{
    NSString *documentInfoPlistPath = [[[self clientDevicesDirectoryPath] stringByAppendingPathComponent:anIdentifier] stringByAppendingPathComponent:TICDSDeviceInfoPlistFilenameWithExtension];
    
    NSString *finalFilePath = [[[self thisDocumentDeletedClientsDirectoryPath] stringByAppendingPathComponent:anIdentifier] stringByAppendingPathExtension:TICDSDeviceInfoPlistExtension];
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/copy", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    [request addPostValue:documentInfoPlistPath forKey:@"fromPath"];
    [request addPostValue:finalFilePath forKey:@"toPath"];
    [request setCompletionBlock:^{
        FCLog(@"Response: %@", requestBlock.responseString);
        [self addedDeviceInfoPlistToDocumentDeletedClientsForClientWithIdentifier:[[finalFilePath lastPathComponent] stringByDeletingPathExtension] withSuccess:YES];
    }];
    [request setFailedBlock:^{
        [self addedDeviceInfoPlistToDocumentDeletedClientsForClientWithIdentifier:[[finalFilePath lastPathComponent] stringByDeletingPathExtension] withSuccess:NO];
    }];
    [request startAsynchronous];
}

#pragma mark Removing DeletedDocuments file
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

#pragma mark -
#pragma mark Client Directories
- (void)checkWhetherClientDirectoryExistsInRemoteDocumentSyncChangesDirectory
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/exists", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    [request addPostValue:[self thisDocumentSyncChangesThisClientDirectoryPath] forKey:@"filePath"];
    [request setCompletionBlock:^{
        FCLog(@"Response: %@", requestBlock.responseString);
        NSDictionary *response = (NSDictionary*)[requestBlock.responseString objectFromJSONString];
        TICDSRemoteFileStructureExistsResponseType status = TICDSRemoteFileStructureExistsResponseTypeDoesNotExist;
        if ([[response objectForKey:@"exists"] intValue] == 1) {
            status = TICDSRemoteFileStructureExistsResponseTypeDoesExist;
        }
        [self discoveredStatusOfClientDirectoryInRemoteDocumentSyncChangesDirectory:status];
    }];
    [request setFailedBlock:^{
        [self discoveredStatusOfClientDirectoryInRemoteDocumentSyncChangesDirectory:TICDSRemoteFileStructureExistsResponseTypeError];
    }];
    [request startAsynchronous];
}

- (void)checkWhetherClientWasDeletedFromRemoteDocument
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/exists", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    [request addPostValue:[[[self thisDocumentDeletedClientsDirectoryPath] stringByAppendingPathComponent:[self clientIdentifier]] stringByAppendingPathExtension:TICDSDeviceInfoPlistExtension] forKey:@"filePath"];
    [request setCompletionBlock:^{
        FCLog(@"Response: %@", requestBlock.responseString);
        NSDictionary *response = (NSDictionary*)[requestBlock.responseString objectFromJSONString];
        TICDSRemoteFileStructureExistsResponseType status = TICDSRemoteFileStructureDeletionResponseTypeNotDeleted;
        if ([[response objectForKey:@"exists"] intValue] == 1) {
            status = TICDSRemoteFileStructureDeletionResponseTypeDeleted;
        }
        [self discoveredDeletionStatusOfClient:status];
    }];
    [request setFailedBlock:^{
        [self discoveredDeletionStatusOfClient:TICDSRemoteFileStructureExistsResponseTypeError];
    }];
    [request startAsynchronous];
}

- (void)deleteClientIdentifierFileFromDeletedClientsDirectory
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/delete", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    [request addPostValue:[[[self thisDocumentDeletedClientsDirectoryPath] stringByAppendingPathComponent:[self clientIdentifier]] stringByAppendingPathExtension:TICDSDeviceInfoPlistExtension] forKey:@"files[]"];
    [request setCompletionBlock:^{
        FCLog(@"Response: %@", requestBlock.responseString);
        [self deletedClientIdentifierFileFromDeletedClientsDirectoryWithSuccess:YES];
    }];
    [request setFailedBlock:^{
        [self deletedClientIdentifierFileFromDeletedClientsDirectoryWithSuccess:NO];
    }];
    [request startAsynchronous];
}

- (void)createClientDirectoriesInRemoteDocumentDirectories
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/createfolder", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    [request addPostValue:[self thisDocumentSyncChangesThisClientDirectoryPath] forKey:@"folders[]"];
    [request addPostValue:[self thisDocumentSyncCommandsThisClientDirectoryPath] forKey:@"folders[]"];
    [request setCompletionBlock:^{
        FCLog(@"Response: %@", requestBlock.responseString);
        [self createdClientDirectoriesInRemoteDocumentDirectoriesWithSuccess:YES];
    }];
    [request setFailedBlock:^{
        [self createdClientDirectoriesInRemoteDocumentDirectoriesWithSuccess:NO];
    }];
    [request startAsynchronous];
}

#pragma mark -
#pragma mark Initialization and Deallocation
- (void)dealloc
{
    _documentsDirectoryPath = nil;
    _clientDevicesDirectoryPath = nil;
    _thisDocumentDirectoryPath = nil;
    _thisDocumentDeletedClientsDirectoryPath = nil;
    _deletedDocumentsDirectoryIdentifierPlistFilePath = nil;
    _thisDocumentSyncChangesThisClientDirectoryPath = nil;
    _thisDocumentSyncCommandsThisClientDirectoryPath = nil;
    
}

#pragma mark -
#pragma mark Properties
@synthesize documentsDirectoryPath = _documentsDirectoryPath;
@synthesize clientDevicesDirectoryPath = _clientDevicesDirectoryPath;
@synthesize thisDocumentDirectoryPath = _thisDocumentDirectoryPath;
@synthesize thisDocumentDeletedClientsDirectoryPath = _thisDocumentDeletedClientsDirectoryPath;
@synthesize deletedDocumentsDirectoryIdentifierPlistFilePath = _deletedDocumentsDirectoryIdentifierPlistFilePath;
@synthesize thisDocumentSyncChangesThisClientDirectoryPath = _thisDocumentSyncChangesThisClientDirectoryPath;
@synthesize thisDocumentSyncCommandsThisClientDirectoryPath = _thisDocumentSyncCommandsThisClientDirectoryPath;

@end

#endif