//
//  TICDSWebServerBasedWholeStoreUploadOperation.h
//  iOSNotebook
//
//  Created by Tim Isted on 14/05/2011.
//  Copyright 2011 Tim Isted. All rights reserved.
//

#if TARGET_OS_IPHONE

#import "TICDSWholeStoreUploadOperation.h"

/**
 `TICDSWebServerBasedWholeStoreUploadOperation` is a "whole store upload" operation designed for use with a `TICDSWebServerBasedDocumentSyncManager`.
 */

@interface TICDSWebServerBasedWholeStoreUploadOperation : TICDSWholeStoreUploadOperation {
@private
    NSString *_thisDocumentTemporaryWholeStoreThisClientDirectoryPath;
    NSString *_thisDocumentTemporaryWholeStoreThisClientDirectoryWholeStoreFilePath;
    NSString *_thisDocumentTemporaryWholeStoreThisClientDirectoryAppliedSyncChangeSetsFilePath;
    NSString *_thisDocumentWholeStoreThisClientDirectoryPath;
}

/** @name Properties */

/** @name Paths */

/** The path to this client's directory within the temporary directory in this document's `WholeStore` directory. */
@property (strong) NSString *thisDocumentTemporaryWholeStoreThisClientDirectoryPath;

/** The path to which the whole store file should be copied. */
@property (strong) NSString *thisDocumentTemporaryWholeStoreThisClientDirectoryWholeStoreFilePath;

/** The path to which the applied sync change sets file should be copied. */
@property (strong) NSString *thisDocumentTemporaryWholeStoreThisClientDirectoryAppliedSyncChangeSetsFilePath;

/** The path to this client's directory within this document's `WholeStore` directory. */
@property (strong) NSString *thisDocumentWholeStoreThisClientDirectoryPath;

@end

#endif