//
//  TICDSWebServerBasedListOfDocumentRegisteredClientsOperation.m
//  iOSNotebook
//
//  Created by Tim Isted on 23/05/2011.
//  Copyright 2011 Tim Isted. All rights reserved.
//

#if TARGET_OS_IPHONE

#import "TICoreDataSync.h"
#import "JSONKit.h"


@implementation TICDSWebServerBasedListOfDocumentRegisteredClientsOperation

- (BOOL)needsMainThread
{
    return NO;
}

- (void)fetchArrayOfClientUUIDStrings
{
    NSString *path = [self thisDocumentSyncChangesDirectoryPath];
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/metadata", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    [request addPostValue:path forKey:@"filePath"];
    [request addPostValue:[NSNumber numberWithInt:0] forKey:@"files"];
    [request setCompletionBlock:^{
        FCLog(@"Response: %@", requestBlock.responseString);
        NSDictionary *results = [requestBlock.responseString objectFromJSONString];
        
        NSMutableArray *clientIdentifiers = [NSMutableArray arrayWithCapacity:0];
        
        for (NSDictionary *path in [results objectForKey:@"contents"]) {
            if ([[path valueForKey:@"fileName"] length] < 5) {
                continue;
            }
            [clientIdentifiers addObject:[path valueForKey:@"fileName"]];
        }
        
        [self fetchedArrayOfClientUUIDStrings:clientIdentifiers];
    }];
    [request setFailedBlock:^{
        [self fetchedArrayOfClientUUIDStrings:nil];
    }];
    [request startAsynchronous];
}

- (void)fetchDeviceInfoDictionaryForClientWithIdentifier:(NSString *)anIdentifier
{
    NSString *path = [self pathToInfoDictionaryForDeviceWithIdentifier:anIdentifier];
    NSString *destPath = [[self tempFileDirectoryPath] stringByAppendingPathComponent:anIdentifier];
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/download", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    [request addPostValue:path forKey:@"filePath"];
    [request setCompletionBlock:^{
        FCLog(@"Response: %@", requestBlock.responseString);
        [requestBlock.responseData writeToFile:destPath atomically:YES];
        
        NSString *identifier = [destPath lastPathComponent];
        NSDictionary *dictionary = [NSDictionary dictionaryWithContentsOfFile:destPath];
        if( !dictionary ) {
            [self setError:[TICDSError errorWithCode:TICDSErrorCodeFileManagerError classAndMethod:__PRETTY_FUNCTION__]];
        }
        
        [self fetchedDeviceInfoDictionary:dictionary forClientWithIdentifier:identifier];
    }];
    [request setFailedBlock:^{
        [self fetchedDeviceInfoDictionary:nil forClientWithIdentifier:[path lastPathComponent]];
    }];
    [request startAsynchronous];
}

- (void)fetchLastSynchronizationDates
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/metadata", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    [request addPostValue:[self thisDocumentRecentSyncsDirectoryPath] forKey:@"filePath"];
    [request setCompletionBlock:^{
        FCLog(@"Response: %@", requestBlock.responseString);
        NSDictionary *results = [requestBlock.responseString objectFromJSONString];
        NSDictionary *subMetadata;
        
        for (NSString *eachClientIdentifier in [self synchronizedClientIdentifiers]) {
            subMetadata = nil;
            for (NSDictionary *eachSubMetadata in [results objectForKey:@"contents"] ) {
                if(![[[eachSubMetadata valueForKey:@"name"] stringByDeletingPathExtension] isEqualToString:eachClientIdentifier]) {
                    continue;
                }
                subMetadata = eachSubMetadata;
            }
            if (!subMetadata) {
                [self fetchedLastSynchronizationDate:nil forClientWithIdentifier:eachClientIdentifier];
                continue;
            }
            int dateModified = [(NSNumber*)[subMetadata objectForKey:@"dateModified"] intValue];
            NSDate *lastModifiedDate = [NSDate dateWithTimeIntervalSince1970:dateModified];
            [self fetchedLastSynchronizationDate:lastModifiedDate forClientWithIdentifier:eachClientIdentifier];
        }
    }];
    [request setFailedBlock:^{
        for (NSString *eachClientIdentifer in [self synchronizedClientIdentifiers]) {
            [self fetchedLastSynchronizationDate:nil forClientWithIdentifier:eachClientIdentifer];
        }
        
    }];
    [request startAsynchronous];
}

- (void)fetchModificationDateOfWholeStoreForClientWithIdentifier:(NSString *)anIdentifier
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/metadata", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    [request addPostValue:[self pathToWholeStoreFileForDeviceWithIdentifier:anIdentifier] forKey:@"filePath"];
    [request setCompletionBlock:^{
        FCLog(@"Response: %@", requestBlock.responseString);
        NSDictionary *results = [requestBlock.responseString objectFromJSONString];
        
        int dateModified = [(NSNumber*)[results objectForKey:@"dateModified"] intValue];
        NSDate *lastModifiedDate = [NSDate dateWithTimeIntervalSince1970:dateModified];
        
        [self fetchedModificationDate:lastModifiedDate
  ofWholeStoreForClientWithIdentifier:anIdentifier];
    }];
    [request setFailedBlock:^{
        [self fetchedModificationDate:nil
  ofWholeStoreForClientWithIdentifier:anIdentifier];
        
    }];
    [request startAsynchronous];
}

#pragma mark -
#pragma mark Paths
- (NSString *)pathToInfoDictionaryForDeviceWithIdentifier:(NSString *)anIdentifier
{
    return [[[self clientDevicesDirectoryPath] stringByAppendingPathComponent:anIdentifier] stringByAppendingPathComponent:TICDSDeviceInfoPlistFilenameWithExtension]; 
}

- (NSString *)pathToWholeStoreFileForDeviceWithIdentifier:(NSString *)anIdentifier
{
    return [[[self thisDocumentWholeStoreDirectoryPath] stringByAppendingPathComponent:anIdentifier] stringByAppendingPathComponent:TICDSWholeStoreFilename];
}

#pragma mark -
#pragma mark Initialization and Deallocation
- (void)dealloc
{
    _thisDocumentSyncChangesDirectoryPath = nil;
    _clientDevicesDirectoryPath = nil;
    _thisDocumentRecentSyncsDirectoryPath = nil;
    _thisDocumentWholeStoreDirectoryPath = nil;

}

#pragma mark -
#pragma mark Properties
@synthesize thisDocumentSyncChangesDirectoryPath = _thisDocumentSyncChangesDirectoryPath;
@synthesize clientDevicesDirectoryPath = _clientDevicesDirectoryPath;
@synthesize thisDocumentRecentSyncsDirectoryPath = _thisDocumentRecentSyncsDirectoryPath;
@synthesize thisDocumentWholeStoreDirectoryPath = _thisDocumentWholeStoreDirectoryPath;

@end

#endif