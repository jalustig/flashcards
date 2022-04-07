//
//  TICDSWebServerBasedDocumentClientDeletionOperation.h
//  iOSNotebook
//
//  Created by Tim Isted on 04/06/2011.
//  Copyright 2011 Tim Isted. All rights reserved.
//

#if TARGET_OS_IPHONE

#import "TICDSDocumentClientDeletionOperation.h"
/**
 `TICDSWebServerBasedDocumentClientDeletionOperation` is a "deletion of client's sync data from a document" operation designed for use with a `TICDSWebServerBasedDocumentSyncManager`.
 */

@interface TICDSWebServerBasedDocumentClientDeletionOperation : TICDSDocumentClientDeletionOperation {
@private
    NSString *_clientDevicesDirectoryPath;
    NSString *_thisDocumentDeletedClientsDirectoryPath;
    NSString *_thisDocumentSyncChangesDirectoryPath;
    NSString *_thisDocumentSyncCommandsDirectoryPath;
    NSString *_thisDocumentRecentSyncsDirectoryPath;
    NSString *_thisDocumentWholeStoreDirectoryPath;
}

/** @name Properties */

/** @name Paths */

/** The path to the `ClientDevices` directory. */
@property (strong) NSString *clientDevicesDirectoryPath;

/** The path to the document's `DeletedClients` directory. */
@property (strong) NSString *thisDocumentDeletedClientsDirectoryPath;

/** The path to the document's `SyncChanges` directory. */
@property (strong) NSString *thisDocumentSyncChangesDirectoryPath;

/** The path to the document's `SyncCommands` directory. */
@property (strong) NSString *thisDocumentSyncCommandsDirectoryPath;

/** The path to the document's `RecentSyncs` directory. */
@property (strong) NSString *thisDocumentRecentSyncsDirectoryPath;

/** The path to the document's `WholeStore` directory. */
@property (strong) NSString *thisDocumentWholeStoreDirectoryPath;

@end

#endif