//
//  TICDSWebServerBasedWholeStoreDownloadOperation.h
//  iOSNotebook
//
//  Created by Tim Isted on 14/05/2011.
//  Copyright 2011 Tim Isted. All rights reserved.
//

#if TARGET_OS_IPHONE

#import "TICDSWholeStoreDownloadOperation.h"
#import "ASIHTTPRequest.h"

/**
 `TICDSWebServerBasedWholeStoreDownloadOperation` is a "whole store download" operation designed for use with a `TICDSWebServerBasedDocumentSyncManager`.
 */

@interface TICDSWebServerBasedWholeStoreDownloadOperation : TICDSWholeStoreDownloadOperation <ASIProgressDelegate> {
@private
    
    int totalBytesReceived;
    
    NSString *_thisDocumentDirectoryPath;
    NSString *_thisDocumentWholeStoreDirectoryPath;
    
    NSUInteger _numberOfWholeStoresToCheck;
    NSMutableDictionary *_wholeStoreModifiedDates;
}

/** @name Properties */

/** @name Paths */

/** The path to a given client's `WholeStore.ticdsync` file within this document's `WholeStore` directory.
 
 @param anIdentifier The unique sync identifier of the document. */
- (NSString *)pathToWholeStoreFileForClientWithIdentifier:(NSString *)anIdentifier;

/** The path to a given client's `AppliedSyncChanges.ticdsync` file within this document's `WholeStore` directory.
 
 @param anIdentifier The unique sync identifier of the document. */
- (NSString *)pathToAppliedSyncChangesFileForClientWithIdentifier:(NSString *)anIdentifier;

@property (nonatomic, assign) int totalBytesReceived;

/** The path to this document's directory. */
@property (strong) NSString *thisDocumentDirectoryPath;

/** The path to this document's `WholeStore` directory. */
@property (strong) NSString *thisDocumentWholeStoreDirectoryPath;

@end

#endif