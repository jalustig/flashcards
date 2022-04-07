//
//  TICDSWebServerBasedDocumentDeletionOperation.h
//  iOSNotebook
//
//  Created by Tim Isted on 29/05/2011.
//  Copyright 2011 Tim Isted. All rights reserved.
//

#if TARGET_OS_IPHONE

#import "TICDSDocumentDeletionOperation.h"

/**
 `TICDSWebServerBasedDocumentDeletionOperation` is a Document Deletion operation designed for use with a `TICDSWebServerBasedDocumentSyncManager`.
 */
@interface TICDSWebServerBasedDocumentDeletionOperation : TICDSDocumentDeletionOperation {
@private
    NSString *_documentDirectoryPath;
    NSString *_documentInfoPlistFilePath;
    NSString *_deletedDocumentsDirectoryIdentifierPlistFilePath;
}

/** @name Properties */

/** @name Paths */

/** The path to the directory that should be deleted. */
@property (strong) NSString *documentDirectoryPath;

/** The path to the document's `documentInfo.plist` file. */
@property (strong) NSString *documentInfoPlistFilePath;

/** The path to the document's `identifier.plist` file inside the application's `DeletedDocuments` directory. */
@property (strong) NSString *deletedDocumentsDirectoryIdentifierPlistFilePath;

@end

#endif