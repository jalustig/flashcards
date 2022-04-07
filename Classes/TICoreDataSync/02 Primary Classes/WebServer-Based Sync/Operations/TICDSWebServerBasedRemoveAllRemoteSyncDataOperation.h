//
//  TICDSWebServerBasedRemoveAllRemoteSyncDataOperation.h
//  iOSNotebook
//
//  Created by Tim Isted on 05/08/2011.
//  Copyright 2011 Tim Isted. All rights reserved.
//

#if TARGET_OS_IPHONE

#import "TICDSRemoveAllRemoteSyncDataOperation.h"

/**
 `TICDSWebServerBasedApplicationRegistrationOperation` is an application registration operation designed for use with a `TICDSWebServerBasedApplicationSyncManager`.
 */

@interface TICDSWebServerBasedRemoveAllRemoteSyncDataOperation : TICDSRemoveAllRemoteSyncDataOperation {
@private
    NSString *_applicationDirectoryPath;
}

/** @name Properties */

/** @name Paths */

/** The path to the root of the application. */
@property (strong) NSString *applicationDirectoryPath;

@end

#endif