//
//  TICDSWebServerBasedRemoveAllRemoteSyncDataOperation.m
//  iOSNotebook
//
//  Created by Tim Isted on 05/08/2011.
//  Copyright 2011 Tim Isted. All rights reserved.
//

#if TARGET_OS_IPHONE

#import "TICoreDataSync.h"
#import "JSONKit.h"


@implementation TICDSWebServerBasedRemoveAllRemoteSyncDataOperation

- (BOOL)needsMainThread
{
    return NO;
}

- (void)removeRemoteSyncDataDirectory
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/delete", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    [request addPostValue:[self applicationDirectoryPath] forKey:@"files[]"];
    [request setCompletionBlock:^{
        FCLog(@"Response: %@", requestBlock.responseString);
        [self removedRemoteSyncDataDirectoryWithSuccess:YES];
    }];
    [request setFailedBlock:^{
        [self removedRemoteSyncDataDirectoryWithSuccess:NO];
    }];
    [request startAsynchronous];
}

#pragma mark -
#pragma mark Properties
@synthesize applicationDirectoryPath = _applicationDirectoryPath;

@end

#endif