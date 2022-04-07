//
//  TICDSWebServerBasedPreSynchronizationOperation.h
//  iOSNotebook
//
//  Created by Tim Isted on 14/05/2011.
//  Copyright 2011 Tim Isted. All rights reserved.
//


#import "TICDSPreSynchronizationOperation.h"

/**
 `TICDSWebServerBasedPreSynchronizationOperation` is a synchronization operation designed for use with a `TICDSWebServerBasedDocumentSyncManager`.
 */

@interface TICDSWebServerBasedPreSynchronizationOperation : TICDSPreSynchronizationOperation {
@private
    
    BOOL hasCompletedDownloadingSyncChanges;
    NSMutableDictionary *totalBytesExpectedForFiles;
    NSMutableDictionary *totalBytesReceivedForFiles;

    NSMutableDictionary *_clientIdentifiersForChangeSetIdentifiers;
    NSMutableDictionary *_changeSetModificationDates;
    NSMutableDictionary *_changeSetFileSizes;
    
    NSString *_thisDocumentDirectoryPath;
    NSString *_thisDocumentSyncChangesDirectoryPath;

    NSMutableDictionary *_failedDownloadRetryDictionary;
}

/** @name Paths */

@property (nonatomic, assign) BOOL hasCompletedDownloadingSyncChanges;
@property (nonatomic, strong) NSMutableDictionary *totalBytesExpectedForFiles;
@property (nonatomic, strong) NSMutableDictionary *totalBytesReceivedForFiles;

/** The path to this document's directory. */
@property (copy) NSString *thisDocumentDirectoryPath;

/** The path to this document's `SyncChanges` directory. */
@property (copy) NSString *thisDocumentSyncChangesDirectoryPath;

/** The path to a given client's `SyncChanges` directory.
 
 @param anIdentifier The unique sync identifier of the document. */
- (NSString *)pathToSyncChangesDirectoryForClientWithIdentifier:(NSString *)anIdentifier;

/** The path to a `SyncChangeSet` uploaded by a given client.
 
 @param aChangeSetIdentifier The unique identifier of the sync change set.
 @param aClientIdentifier The unique sync identifier of the client. */
- (NSString *)pathToSyncChangeSetWithIdentifier:(NSString *)aChangeSetIdentifier forClientWithIdentifier:(NSString *)aClientIdentifier;

@end

