//
//  TICDSWebServerBasedApplicationRegistrationOperation.h
//  iOSNotebook
//
//  Created by Tim Isted on 13/05/2011.
//  Copyright 2011 Tim Isted. All rights reserved.
//

#if TARGET_OS_IPHONE

#import "TICoreDataSync.h"

/**
 `TICDSWebServerBasedApplicationRegistrationOperation` is an application registration operation designed for use with a `TICDSWebServerBasedApplicationSyncManager`.
 */

@interface TICDSWebServerBasedApplicationRegistrationOperation : TICDSApplicationRegistrationOperation {
@private
    NSString *_applicationDirectoryPath;
    NSString *_encryptionDirectorySaltDataFilePath;
    NSString *_encryptionDirectoryTestDataFilePath;
    NSString *_clientDevicesThisClientDeviceDirectoryPath;
    
    NSUInteger _numberOfAppDirectoriesToCreate;
    NSUInteger _numberOfAppDirectoriesThatFailedToBeCreated;
    NSUInteger _numberOfAppDirectoriesThatWereCreated;
}

/** @name Properties */

/** @name Paths */

/** The path to the root of the application. */
@property (strong) NSString *applicationDirectoryPath;

/** The path to the `salt.ticdsync` file inside the application's `Encryption` directory. */
@property (strong) NSString *encryptionDirectorySaltDataFilePath;

/** The path to the `test.ticdsync` file inside the application's `Encryption` directory. */
@property (strong) NSString *encryptionDirectoryTestDataFilePath;

/** The path to this client's directory in the `ClientDevices` directory. */
@property (strong) NSString *clientDevicesThisClientDeviceDirectoryPath;

@end

#endif