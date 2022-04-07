//
//  TICDSWebServerBasedListOfApplicationRegisteredClientsOperation.h
//  iOSNotebook
//
//  Created by Tim Isted on 23/05/2011.
//  Copyright 2011 Tim Isted. All rights reserved.
//

#if TARGET_OS_IPHONE

#import "TICDSListOfApplicationRegisteredClientsOperation.h"

/**
 `TICDSWebServerBasedListOfApplicationRegisteredClientsOperation` is a "List of Registered Clients for an Application" operation designed for use with a `TICDSWebServerBasedDocumentSyncManager`.
 */
@interface TICDSWebServerBasedListOfApplicationRegisteredClientsOperation : TICDSListOfApplicationRegisteredClientsOperation {
@private
    NSString *_clientDevicesDirectoryPath;
    NSString *_documentsDirectoryPath;
}

/** @name Properties */

/** @name Paths */

/** The path to the application's `ClientDevices` directory. */
@property (nonatomic, strong) NSString *clientDevicesDirectoryPath;

/** The path to the application's `Documents` directory. */
@property (nonatomic, strong) NSString *documentsDirectoryPath;

@end

#endif