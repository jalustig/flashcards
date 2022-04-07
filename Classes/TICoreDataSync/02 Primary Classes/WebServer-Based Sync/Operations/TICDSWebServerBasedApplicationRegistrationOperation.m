//
//  TICDSWebServerBasedApplicationRegistrationOperation.m
//  iOSNotebook
//
//  Created by Tim Isted on 13/05/2011.
//  Copyright 2011 Tim Isted. All rights reserved.
//

#if TARGET_OS_IPHONE

#import "TICDSWebServerBasedApplicationRegistrationOperation.h"
#import "JSONKit.h"

@implementation TICDSWebServerBasedApplicationRegistrationOperation

#pragma mark -
#pragma mark Overridden Methods
- (BOOL)needsMainThread
{
    return NO;
}

#pragma mark Global App Directory Methods
- (void)checkWhetherRemoteGlobalAppDirectoryExists
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/exists", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    [request addPostValue:[self applicationDirectoryPath] forKey:@"filePath"];
    [request setCompletionBlock:^{
        FCLog(@"Response: %@", requestBlock.responseString);
        NSDictionary *response = (NSDictionary*)[requestBlock.responseString objectFromJSONString];
        TICDSRemoteFileStructureExistsResponseType status = TICDSRemoteFileStructureExistsResponseTypeDoesNotExist;
        if ([[response objectForKey:@"exists"] intValue] == 1) {
            status = TICDSRemoteFileStructureExistsResponseTypeDoesExist;
        }
        [self discoveredStatusOfRemoteGlobalAppDirectory:status];
    }];
    [request setFailedBlock:^{
        [self discoveredStatusOfRemoteGlobalAppDirectory:TICDSRemoteFileStructureExistsResponseTypeError];
    }];
    [request startAsynchronous];
}

- (void)createRemoteGlobalAppDirectoryStructure
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/establish", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    [request addPostValue:[[TICDSUtilities remoteGlobalAppDirectoryHierarchy] JSONString]
                   forKey:@"hierarchy"];
    [request addPostValue:[self applicationDirectoryPath]
                   forKey:@"in_folder"];
    [request setCompletionBlock:^{
        FCLog(@"Response: %@", requestBlock.responseString);
        [self createdRemoteGlobalAppDirectoryStructureWithSuccess:YES];
    }];
    [request setFailedBlock:^{
        [self createdRemoteGlobalAppDirectoryStructureWithSuccess:NO];
    }];
    [request startAsynchronous];
}

- (void)copyReadMeTxtFileToRootOfGlobalAppDirectoryFromPath:(NSString *)aPath
{
    [self copiedReadMeTxtFileToRootOfGlobalAppDirectoryWithSuccess:YES];
}

#pragma mark Salt
- (void)checkWhetherSaltFileExists
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/exists", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    [request addPostValue:[self encryptionDirectorySaltDataFilePath] forKey:@"filePath"];
    [request setCompletionBlock:^{
        FCLog(@"Response: %@", requestBlock.responseString);
        NSDictionary *response = (NSDictionary*)[requestBlock.responseString objectFromJSONString];
        TICDSRemoteFileStructureExistsResponseType status = TICDSRemoteFileStructureExistsResponseTypeDoesNotExist;
        if ([[response objectForKey:@"exists"] intValue] == 1) {
            status = TICDSRemoteFileStructureExistsResponseTypeDoesExist;
        }
        [self discoveredStatusOfSaltFile:status];
    }];
    [request setFailedBlock:^{
        [self discoveredStatusOfSaltFile:TICDSRemoteFileStructureExistsResponseTypeError];
    }];
    [request startAsynchronous];
}

- (void)fetchSaltData
{
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/download", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    [request addPostValue:[self encryptionDirectorySaltDataFilePath] forKey:@"filePath"];
    [request setCompletionBlock:^{
        FCLog(@"Response: %@", requestBlock.responseString);
        NSString *path = [[self tempFileDirectoryPath] stringByAppendingPathComponent:TICDSSaltFilenameWithExtension];
        [requestBlock.responseData writeToFile:path atomically:YES];
        
        NSError *anyError;
        NSData *saltData = [NSData dataWithContentsOfFile:path options:0 error:&anyError];
        
        if( !saltData ) {
            [self setError:[TICDSError errorWithCode:TICDSErrorCodeFileManagerError underlyingError:anyError classAndMethod:__PRETTY_FUNCTION__]];
        }
        
        [self fetchedSaltData:saltData];
    }];
    [request setFailedBlock:^{
        [self fetchedSaltData:nil];
    }];
    [request startAsynchronous];
}

- (void)saveSaltDataToRemote:(NSData *)saltData
{
    NSString *tempFile = [[self tempFileDirectoryPath] stringByAppendingPathComponent:TICDSSaltFilenameWithExtension];
    
    NSError *anyError = nil;
    BOOL success = [saltData writeToFile:tempFile options:0 error:&anyError];
    
    if( !success ) {
        [self setError:[TICDSError errorWithCode:TICDSErrorCodeFileManagerError underlyingError:anyError classAndMethod:__PRETTY_FUNCTION__]];
        [self savedSaltDataToRootOfGlobalAppDirectoryWithSuccess:success];
        return;
    }
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/upload", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    [request addPostValue:[[self encryptionDirectorySaltDataFilePath] stringByDeletingLastPathComponent]
                   forKey:@"toPath"];
    [request addPostValue:TICDSSaltFilenameWithExtension
                   forKey:@"fileName"];
    [request addFile:tempFile
        withFileName:TICDSSaltFilenameWithExtension
      andContentType:@"application/octet-stream"
              forKey:@"fileData"];
    [request setCompletionBlock:^{
        FCLog(@"Response: %@", requestBlock.responseString);
        [self savedSaltDataToRootOfGlobalAppDirectoryWithSuccess:YES];
    }];
    [request setFailedBlock:^{
        [self savedSaltDataToRootOfGlobalAppDirectoryWithSuccess:NO];
    }];
    [request startAsynchronous];
}

#pragma mark Password Test
- (void)savePasswordTestData:(NSData *)testData
{
    NSError *anyError = nil;
    BOOL success = YES;
    
    NSString *finalFilePath = [[self tempFileDirectoryPath] stringByAppendingPathComponent:TICDSEncryptionTestFilenameWithExtension];
    
    NSString *tmpFilePath = [finalFilePath stringByAppendingPathExtension:@"crypt"];
    
    success = [testData writeToFile:tmpFilePath options:0 error:&anyError];
    if( !success ) {
        [self setError:[TICDSError errorWithCode:TICDSErrorCodeFileManagerError underlyingError:anyError classAndMethod:__PRETTY_FUNCTION__]];
        [self savedPasswordTestDataWithSuccess:success];
        return;
    }
    
    success = [[self cryptor] encryptFileAtLocation:[NSURL fileURLWithPath:tmpFilePath] writingToLocation:[NSURL fileURLWithPath:finalFilePath] error:&anyError];
    
    if( !success ) {
        [self setError:[TICDSError errorWithCode:TICDSErrorCodeEncryptionError underlyingError:anyError classAndMethod:__PRETTY_FUNCTION__]];
        [self savedPasswordTestDataWithSuccess:success];
        return;
    }
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/upload", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    [request addPostValue:[[self encryptionDirectoryTestDataFilePath] stringByDeletingLastPathComponent]
                   forKey:@"toPath"];
    [request addPostValue:TICDSEncryptionTestFilenameWithExtension
                   forKey:@"fileName"];
    [request addFile:finalFilePath
        withFileName:TICDSEncryptionTestFilenameWithExtension
      andContentType:@"application/octet-stream"
              forKey:@"fileData"];
    [request setCompletionBlock:^{
        FCLog(@"Response: %@", requestBlock.responseString);
        [self savedPasswordTestDataWithSuccess:YES];
    }];
    [request setFailedBlock:^{
        [self savedPasswordTestDataWithSuccess:NO];
    }];
    [request startAsynchronous];
}

- (void)fetchPasswordTestData
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/download", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    [request addPostValue:[self encryptionDirectoryTestDataFilePath] forKey:@"filePath"];
    [request setCompletionBlock:^{
        FCLog(@"Response: %@", requestBlock.responseString);
        NSString *destPath = [[self tempFileDirectoryPath] stringByAppendingPathComponent:TICDSEncryptionTestFilenameWithExtension];
        [requestBlock.responseData writeToFile:destPath atomically:YES];
        
        
        NSString *unencryptPath = [destPath stringByAppendingPathExtension:@"tst"];

        NSError *anyError;
        BOOL success = [[self cryptor] decryptFileAtLocation:[NSURL fileURLWithPath:destPath] writingToLocation:[NSURL fileURLWithPath:unencryptPath] error:&anyError];
        
        if( !success ) {
            [self setError:[TICDSError errorWithCode:TICDSErrorCodeEncryptionError underlyingError:anyError classAndMethod:__PRETTY_FUNCTION__]];
            [self fetchedPasswordTestData:nil];
            return;
        }
        
        NSData *testData = [NSData dataWithContentsOfFile:unencryptPath options:0 error:&anyError];
        
        if( !testData ) {
            [self setError:[TICDSError errorWithCode:TICDSErrorCodeFileManagerError underlyingError:anyError classAndMethod:__PRETTY_FUNCTION__]];
        }
        
        [self fetchedPasswordTestData:testData];
        return;
    }];
    [request setFailedBlock:^{
        // TODO: Set up error
    }];
    [request startAsynchronous];
}

#pragma makr Client Device Directories Methods
- (void)checkWhetherRemoteClientDeviceDirectoryExists
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/exists", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    [request addPostValue:[self clientDevicesThisClientDeviceDirectoryPath] forKey:@"filePath"];
    [request setCompletionBlock:^{
        FCLog(@"Response: %@", requestBlock.responseString);
        NSDictionary *response = (NSDictionary*)[requestBlock.responseString objectFromJSONString];
        TICDSRemoteFileStructureExistsResponseType status = TICDSRemoteFileStructureExistsResponseTypeDoesNotExist;
        if ([[response objectForKey:@"exists"] intValue] == 1) {
            status = TICDSRemoteFileStructureExistsResponseTypeDoesExist;
        }
        [self discoveredStatusOfRemoteClientDeviceDirectory:status];
    }];
    [request setFailedBlock:^{
        [self discoveredStatusOfRemoteClientDeviceDirectory:TICDSRemoteFileStructureExistsResponseTypeError];
    }];
    [request startAsynchronous];
}

- (void)createRemoteClientDeviceDirectory
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/createfolder", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    [request addPostValue:[self clientDevicesThisClientDeviceDirectoryPath] forKey:@"folders[]"];
    [request setCompletionBlock:^{
        FCLog(@"Response: %@", requestBlock.responseString);
        [self createdRemoteClientDeviceDirectoryWithSuccess:YES];
    }];
    [request setFailedBlock:^{
        [self createdRemoteClientDeviceDirectoryWithSuccess:NO];
    }];
    [request startAsynchronous];
}

- (void)saveRemoteClientDeviceInfoPlistFromDictionary:(NSDictionary *)aDictionary
{
    BOOL success = YES;
    NSString *finalFilePath = [[self tempFileDirectoryPath] stringByAppendingPathComponent:TICDSDeviceInfoPlistFilenameWithExtension];
    
    success = [aDictionary writeToFile:finalFilePath atomically:NO];
    
    if( !success ) {
        [self setError:[TICDSError errorWithCode:TICDSErrorCodeFileManagerError classAndMethod:__PRETTY_FUNCTION__]];
        [self savedRemoteClientDeviceInfoPlistWithSuccess:success];
        return;
    }
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/upload", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    [request addPostValue:[self clientDevicesThisClientDeviceDirectoryPath] forKey:@"toPath"];
    [request addPostValue:TICDSDeviceInfoPlistFilenameWithExtension forKey:@"fileName"];
    [request addFile:finalFilePath
        withFileName:TICDSDeviceInfoPlistFilenameWithExtension
      andContentType:@"application/octet-stream"
              forKey:@"fileData"];
    [request setCompletionBlock:^{
        FCLog(@"Response: %@", requestBlock.responseString);
        [self savedRemoteClientDeviceInfoPlistWithSuccess:YES];
    }];
    [request setFailedBlock:^{
        [self savedRemoteClientDeviceInfoPlistWithSuccess:NO];
    }];
    [request startAsynchronous];
}

#pragma mark -
#pragma mark Initialization and Deallocation
- (void)dealloc
{

    _applicationDirectoryPath = nil;
    _encryptionDirectorySaltDataFilePath = nil;
    _encryptionDirectoryTestDataFilePath = nil;
    _clientDevicesThisClientDeviceDirectoryPath = nil;

}

#pragma mark -
#pragma mark Properties
@synthesize applicationDirectoryPath = _applicationDirectoryPath;
@synthesize encryptionDirectorySaltDataFilePath = _encryptionDirectorySaltDataFilePath;
@synthesize encryptionDirectoryTestDataFilePath = _encryptionDirectoryTestDataFilePath;
@synthesize clientDevicesThisClientDeviceDirectoryPath = _clientDevicesThisClientDeviceDirectoryPath;

@end

#endif