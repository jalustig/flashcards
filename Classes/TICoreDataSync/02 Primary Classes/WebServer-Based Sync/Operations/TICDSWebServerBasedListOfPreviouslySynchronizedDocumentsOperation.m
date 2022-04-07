//
//  TICDSWebServerBasedListOfPreviouslySynchronizedDocumentsOperation.m
//  iOSNotebook
//
//  Created by Tim Isted on 15/05/2011.
//  Copyright 2011 Tim Isted. All rights reserved.
//

#if TARGET_OS_IPHONE

#import "TICoreDataSync.h"
#import "JSONKit.h"


@implementation TICDSWebServerBasedListOfPreviouslySynchronizedDocumentsOperation

- (BOOL)needsMainThread
{
    return NO;
}

- (void)buildArrayOfDocumentIdentifiers
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

        [self builtArrayOfDocumentIdentifiers:documentIdentifiers];
    }];
    [request setFailedBlock:^{
        [self builtArrayOfDocumentIdentifiers:nil];
    }];
    [request startAsynchronous];
}

- (void)fetchInfoDictionaryForDocumentWithSyncID:(NSString *)aSyncID
{
    NSString *path = [self pathToDocumentInfoForDocumentWithIdentifier:aSyncID];
    NSString *destPath = [[self tempFileDirectoryPath] stringByAppendingPathComponent:aSyncID];
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/download", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    [request addPostValue:path forKey:@"filePath"];
    [request setCompletionBlock:^{
        FCLog(@"Response: %@", requestBlock.responseString);
        [requestBlock.responseData writeToFile:destPath atomically:YES];

        // If we're loading files, this is for the documentInfo.plist fetch phase
        NSString *documentIdentifier = [destPath lastPathComponent];
        NSDictionary *documentInfo = nil;
        documentInfo = [NSDictionary dictionaryWithContentsOfFile:destPath];
        if( !documentInfo ) {
            [self setError:[TICDSError errorWithCode:TICDSErrorCodeFileManagerError classAndMethod:__PRETTY_FUNCTION__]];
        }
        [self fetchedInfoDictionary:documentInfo forDocumentWithSyncID:documentIdentifier];
    }];
    [request setFailedBlock:^{
        [self fetchedInfoDictionary:nil forDocumentWithSyncID:[path lastPathComponent]];
    }];
    [request startAsynchronous];
}

- (void)fetchLastSynchronizationDateForDocumentWithSyncID:(NSString *)aSyncID
{
    
    NSString *path = [self pathToDocumentRecentSyncsDirectoryForIdentifier:aSyncID];
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/metadata", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    [request addPostValue:path forKey:@"filePath"];
    [request setCompletionBlock:^{
        FCLog(@"Response: %@", requestBlock.responseString);
        NSDictionary *results = [requestBlock.responseString objectFromJSONString];
        NSDictionary *eachSubMetadata;

        NSDate *mostRecentSyncDate = nil;
        
        NSString *documentIdentifier = [path stringByDeletingLastPathComponent];
        documentIdentifier = [documentIdentifier lastPathComponent];

        int dateModified;
        NSDate *lastModifiedDate;
        
        for (eachSubMetadata in [results objectForKey:@"contents"] ) {
            dateModified = [(NSNumber*)[eachSubMetadata objectForKey:@"dateModified"] intValue];
            lastModifiedDate = [NSDate dateWithTimeIntervalSince1970:dateModified];
            if (!mostRecentSyncDate) {
                mostRecentSyncDate = lastModifiedDate;
                continue;
            }
            
            if ([mostRecentSyncDate compare:lastModifiedDate] == NSOrderedAscending ) {
                mostRecentSyncDate = lastModifiedDate;
                continue;
            }
        }
        
        [self fetchedLastSynchronizationDate:mostRecentSyncDate forDocumentWithSyncID:documentIdentifier];
    }];
    [request setFailedBlock:^{
        NSString *documentIdentifier = [path stringByDeletingLastPathComponent];
        documentIdentifier = [documentIdentifier lastPathComponent];
        
        [self fetchedLastSynchronizationDate:nil forDocumentWithSyncID:documentIdentifier];
    }];
    [request startAsynchronous];
}

#pragma mark -
#pragma mark Paths
- (NSString *)pathToDocumentInfoForDocumentWithIdentifier:(NSString *)anIdentifier
{
    return [[[self documentsDirectoryPath] stringByAppendingPathComponent:anIdentifier] stringByAppendingPathComponent:TICDSDocumentInfoPlistFilenameWithExtension];
}

- (NSString *)pathToDocumentRecentSyncsDirectoryForIdentifier:(NSString *)anIdentifier
{
    return [[[self documentsDirectoryPath] stringByAppendingPathComponent:anIdentifier] stringByAppendingPathComponent:TICDSRecentSyncsDirectoryName];
}

#pragma mark -
#pragma mark Initialization and Deallocation
- (void)dealloc
{
    _documentsDirectoryPath = nil;

}

#pragma mark -
#pragma mark Properties
@synthesize documentsDirectoryPath = _documentsDirectoryPath;

@end

#endif