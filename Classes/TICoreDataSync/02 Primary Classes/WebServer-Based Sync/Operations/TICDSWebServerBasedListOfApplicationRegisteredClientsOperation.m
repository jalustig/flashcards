//
//  TICDSWebServerBasedListOfApplicationRegisteredClientsOperation.m
//  iOSNotebook
//
//  Created by Tim Isted on 23/05/2011.
//  Copyright 2011 Tim Isted. All rights reserved.
//

#if TARGET_OS_IPHONE

#import "TICoreDataSync.h"
#import "JSONKit.h"


@implementation TICDSWebServerBasedListOfApplicationRegisteredClientsOperation

- (BOOL)needsMainThread
{
    return NO;
}

- (void)fetchArrayOfClientUUIDStrings
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/metadata", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    [request addPostValue:[self clientDevicesDirectoryPath] forKey:@"filePath"];
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
    NSString *path = [[[self clientDevicesDirectoryPath] stringByAppendingPathComponent:anIdentifier] stringByAppendingPathComponent:TICDSDeviceInfoPlistFilenameWithExtension];
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
        [self fetchedDeviceInfoDictionary:nil forClientWithIdentifier:anIdentifier];
    }];
    [request startAsynchronous];
}

- (void)fetchArrayOfDocumentUUIDStrings
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/metadata", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    [request addPostValue:[self documentsDirectoryPath] forKey:@"filePath"];
    [request addPostValue:[NSNumber numberWithInt:0] forKey:@"files"];
    [request setCompletionBlock:^{
        FCLog(@"Response: %@", requestBlock.responseString);
        NSDictionary *results = [requestBlock.responseString objectFromJSONString];
        NSMutableArray *documentIdentifiers = [NSMutableArray arrayWithCapacity:0];
        
        for (NSDictionary *path in [results objectForKey:@"contents"]) {
            if ([[path valueForKey:@"fileName"] length] < 5) {
                continue;
            }
            [documentIdentifiers addObject:[path valueForKey:@"fileName"]];
        }
        
        [self fetchedArrayOfDocumentUUIDStrings:documentIdentifiers];
        
    }];
    [request setFailedBlock:^{
        [self fetchedArrayOfDocumentUUIDStrings:nil];
    }];
    [request startAsynchronous];
}

- (void)fetchArrayOfClientsRegisteredForDocumentWithIdentifier:(NSString *)anIdentifier
{
    NSString *path = [[[self documentsDirectoryPath] stringByAppendingPathComponent:anIdentifier] stringByAppendingPathComponent:TICDSSyncChangesDirectoryName];
    
    
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
        
        [self fetchedArrayOfClients:clientIdentifiers registeredForDocumentWithIdentifier:[[path stringByDeletingLastPathComponent] lastPathComponent]];
    }];
    [request setFailedBlock:^{
        [self fetchedArrayOfClients:nil registeredForDocumentWithIdentifier:[[path stringByDeletingLastPathComponent] lastPathComponent]];
    }];
    [request startAsynchronous];
}

#pragma mark -
#pragma mark Initialization and Deallocation
- (void)dealloc
{
    _clientDevicesDirectoryPath = nil;
    _documentsDirectoryPath = nil;

}

#pragma mark -
#pragma mark Properties
@synthesize clientDevicesDirectoryPath = _clientDevicesDirectoryPath;
@synthesize documentsDirectoryPath = _documentsDirectoryPath;

@end

#endif