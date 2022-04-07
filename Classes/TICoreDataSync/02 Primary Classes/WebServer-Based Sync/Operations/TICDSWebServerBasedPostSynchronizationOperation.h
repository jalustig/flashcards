//
//  TICDSDropboxSDKBasedPostSynchronizationOperation.h
//  iOSNotebook
//
//  Created by Tim Isted on 14/05/2011.
//  Copyright 2011 Tim Isted. All rights reserved.
//


#import "TICDSPostSynchronizationOperation.h"

/**
 `TICDSWebServerBasedPostSynchronizationOperation` is a synchronization operation designed for use with a `TICDSWebServerBasedDocumentSyncManager`.
 */

@interface TICDSWebServerBasedPostSynchronizationOperation : TICDSPostSynchronizationOperation

/** @name Paths */

/** The path to this document's `SyncChanges` directory. */
@property (copy) NSString *thisDocumentSyncChangesDirectoryPath;

/** The path this client's directory inside this document's `SyncChanges` directory. */
@property (copy) NSString *thisDocumentSyncChangesThisClientDirectoryPath;

/** The path this client's RecentSync file inside this document's `RecentSyncs` directory. */
@property (copy) NSString *thisDocumentRecentSyncsThisClientFilePath;

@end

