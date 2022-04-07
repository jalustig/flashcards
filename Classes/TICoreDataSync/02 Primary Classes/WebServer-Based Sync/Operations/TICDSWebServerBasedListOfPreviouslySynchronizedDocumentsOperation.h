//
//  TICDSWebServerBasedListOfPreviouslySynchronizedDocumentsOperation.h
//  iOSNotebook
//
//  Created by Tim Isted on 15/05/2011.
//  Copyright 2011 Tim Isted. All rights reserved.
//

#if TARGET_OS_IPHONE

#import "TICDSListOfPreviouslySynchronizedDocumentsOperation.h"

/**
 `TICDSWebServerBasedListOfPreviouslySynchronizedDocumentsOperation` is a "List of Previously Synchronized Documents" operation designed for use with a `TICDSWebServerBasedDocumentSyncManager`.
 */

@interface TICDSWebServerBasedListOfPreviouslySynchronizedDocumentsOperation : TICDSListOfPreviouslySynchronizedDocumentsOperation {
@private
    NSString *_documentsDirectoryPath;
}

/** @name Properties */

/** @name Paths */

/** The path to the `Documents` directory. */
@property (strong) NSString *documentsDirectoryPath;

/** Returns the path to the `documentInfo.plist` file for a document with the specified identifier.
 
 @param anIdentifier The identifier of the document.
 
 @return A path to the specified document. */
- (NSString *)pathToDocumentInfoForDocumentWithIdentifier:(NSString *)anIdentifier;

/** Returns the path to the `RecentSyncs` directory for a document with the specified identifier.
 
 @param anIdentifier The identifier of the document.
 
 @return A path to the `RecentSyncs` directory. */
- (NSString *)pathToDocumentRecentSyncsDirectoryForIdentifier:(NSString *)anIdentifier;

@end

#endif