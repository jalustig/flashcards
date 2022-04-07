//
//  TICDSWebServerBasedVacuumOperation.m
//  iOSNotebook
//
//  Created by Tim Isted on 15/05/2011.
//  Copyright 2011 Tim Isted. All rights reserved.
//

#if TARGET_OS_IPHONE

#import "TICoreDataSync.h"
#import "JSONKit.h"


@implementation TICDSWebServerBasedVacuumOperation

- (BOOL)needsMainThread
{
    return NO;
}

- (void)findOutDateOfOldestWholeStore
{
    NSString *path = [self thisDocumentWholeStoreDirectoryPath];

    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/metadata", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    [request addPostValue:path forKey:@"filePath"];
    [request addPostValue:[NSNumber numberWithInt:1] forKey:@"recursive"];
    [request setCompletionBlock:^{
        FCLog(@"Response: %@", requestBlock.responseString);
        NSDictionary *results = [requestBlock.responseString objectFromJSONString];
        int dateModified;
        NSDate *lastModifiedDate;
        
        for (NSDictionary *device in [results objectForKey:@"contents"]) {
            for (NSDictionary *file in [device objectForKey:@"contents"]) {
                if ([[file valueForKey:@"fileName"] isEqualToString:TICDSWholeStoreFilename]) {
                    dateModified = [(NSNumber*)[file objectForKey:@"dateModified"] intValue];
                    lastModifiedDate = [NSDate dateWithTimeIntervalSince1970:dateModified];
                    
                    if (![self oldestStoreDate]) {
                        [self setOldestStoreDate:lastModifiedDate];
                        continue;
                    }
                    
                    if ([[self oldestStoreDate] compare:lastModifiedDate] == NSOrderedDescending) {
                        [self setOldestStoreDate:lastModifiedDate];
                    }
                }
            }
        }
        [self foundOutDateOfOldestWholeStoreFile:[self oldestStoreDate]];
    }];
    [request setFailedBlock:^{
        [self foundOutDateOfOldestWholeStoreFile:nil];
    }];
    [request startAsynchronous];

}

- (void)findOutLeastRecentClientSyncDate
{
    NSString *path = [self thisDocumentRecentSyncsDirectoryPath];

    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/metadata", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    [request addPostValue:path forKey:@"filePath"];
    [request setCompletionBlock:^{
        FCLog(@"Response: %@", requestBlock.responseString);
        NSDictionary *results = [requestBlock.responseString objectFromJSONString];
        int dateModified;
        NSDate *lastModifiedDate;
        
        NSDate *leastRecentSyncDate = nil;
        
        for (NSDictionary *file in [results objectForKey:@"contents"]) {
            if (![[file valueForKey:@"extension"] isEqualToString:TICDSRecentSyncFileExtension] ) {
                continue;
            }
            
            dateModified = [(NSNumber*)[file objectForKey:@"dateModified"] intValue];
            lastModifiedDate = [NSDate dateWithTimeIntervalSince1970:dateModified];
            
            if (!leastRecentSyncDate) {
                leastRecentSyncDate = lastModifiedDate;
                continue;
            }
            
            if ([leastRecentSyncDate compare:lastModifiedDate] == NSOrderedDescending) {
                leastRecentSyncDate = lastModifiedDate;
                continue;
            }
        }
        
        if (!leastRecentSyncDate) {
            leastRecentSyncDate = [NSDate date];
        }
        
        [self foundOutLeastRecentClientSyncDate:leastRecentSyncDate];
    }];
    [request setFailedBlock:^{
        [self foundOutLeastRecentClientSyncDate:nil];
    }];
    [request startAsynchronous];
}

- (void)removeOldSyncChangeSetFiles
{
    NSString *path = [self thisDocumentSyncChangesThisClientDirectoryPath];
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/metadata", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    [request addPostValue:path forKey:@"filePath"];
    [request setCompletionBlock:^{
        FCLog(@"Response: %@", requestBlock.responseString);
        NSDictionary *results = [requestBlock.responseString objectFromJSONString];
        int dateModified;
        NSDate *lastModifiedDate;
        
        NSMutableArray *filesToDelete = [NSMutableArray arrayWithCapacity:0];
        for (NSDictionary *file in [results valueForKey:@"contents"]) {
            dateModified = [(NSNumber*)[file objectForKey:@"dateModified"] intValue];
            lastModifiedDate = [NSDate dateWithTimeIntervalSince1970:dateModified];
            if ([lastModifiedDate compare:[self earliestDateForFilesToKeep]] == NSOrderedDescending) {
                continue;
            }
            
            [filesToDelete addObject:[file valueForKey:@"relativeFilePath"]];
        }
        
        if ([filesToDelete count] == 0) {
            [self removedOldSyncChangeSetFilesWithSuccess:YES];
            return;
        }
        
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/delete", flashcardsServer]];
        ASIFormDataRequest *request2 = [[ASIFormDataRequest alloc] initWithURL:url];
        [request2 prepareCoreDataSyncRequest];
        for (NSString *filePath in filesToDelete) {
            [request2 addPostValue:filePath forKey:@"files[]"];
        }
        [request2 setCompletionBlock:^{
            [self removedOldSyncChangeSetFilesWithSuccess:YES];
        }];
        [request2 setFailedBlock:^{
            [self removedOldSyncChangeSetFilesWithSuccess:NO];
        }];
        [request2 startAsynchronous];
    }];
    [request setFailedBlock:^{
        [self removedOldSyncChangeSetFilesWithSuccess:NO];
    }];
    [request startAsynchronous];

}

#pragma mark -
#pragma mark Paths
- (NSString *)pathToWholeStoreFileForClientWithIdentifier:(NSString *)anIdentifier
{
    return [[[self thisDocumentWholeStoreDirectoryPath] stringByAppendingPathComponent:anIdentifier] stringByAppendingPathComponent:TICDSWholeStoreFilename];
}

#pragma mark -
#pragma mark Initialization and Deallocation
- (void)dealloc
{
    _oldestStoreDate = nil;
    _thisDocumentWholeStoreDirectoryPath = nil;
    _thisDocumentSyncChangesThisClientDirectoryPath = nil;
    _thisDocumentRecentSyncsDirectoryPath = nil;

}

#pragma mark -
#pragma mark Properties
@synthesize oldestStoreDate = _oldestStoreDate;
@synthesize thisDocumentWholeStoreDirectoryPath = _thisDocumentWholeStoreDirectoryPath;
@synthesize thisDocumentRecentSyncsDirectoryPath = _thisDocumentRecentSyncsDirectoryPath;
@synthesize thisDocumentSyncChangesThisClientDirectoryPath = _thisDocumentSyncChangesThisClientDirectoryPath;

@end

#endif