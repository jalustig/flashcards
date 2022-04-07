//
//  TICDSWebServerBasedApplicationSyncManager.h
//  iOSNotebook
//
//  Created by Tim Isted on 13/05/2011.
//  Copyright 2011 Tim Isted. All rights reserved.
//

#if TARGET_OS_IPHONE

#import "TICDSApplicationSyncManager.h"

@interface TICDSWebServerBasedApplicationSyncManager : TICDSApplicationSyncManager {
}

/** @name Properties */

/** @name Paths */
/** The path to root application directory (will be `/globalAppIdentifier`). */
@property (weak, nonatomic, readonly) NSString *applicationDirectoryPath;

/** The path to the `DeletedDocuments` directory inside the `Information` directory at the root of the application. */
@property (weak, nonatomic, readonly) NSString *deletedDocumentsDirectoryPath;

/** The path to the `salt.ticdsync` file inside the `Encryption` directory at the root of the application. */
@property (weak, nonatomic, readonly) NSString *encryptionDirectorySaltDataFilePath;

/** The path to the `test.ticdsync` file inside the `Encryption` directory at the root of the application. */
@property (weak, nonatomic, readonly) NSString *encryptionDirectoryTestDataFilePath;

/** The path to the `ClientDevices` directory at the root of the application. */
@property (weak, nonatomic, readonly) NSString *clientDevicesDirectoryPath;

/** The path to this client's directory inside the `ClientDevices` directory at the root of the application. */
@property (weak, nonatomic, readonly) NSString *clientDevicesThisClientDeviceDirectoryPath;

/** The path to the `Documents` directory at the root of the application. */
@property (weak, nonatomic, readonly) NSString *documentsDirectoryPath;

/** The path to the `WholeStore` directory for a document with a given identifier.
 
 @param anIdentifier The unique sync identifier of the document. */
- (NSString *)pathToWholeStoreDirectoryForDocumentWithIdentifier:(NSString *)anIdentifier;

@end

#endif