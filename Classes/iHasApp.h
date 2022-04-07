//
//  iHasApp.h
//    iHasApp API
//
//  Copyrights / Disclaimer
//  Copyright 2011, Daniel Amitay. All rights reserved.
//  Use of the software programs described herein is subject to applicable
//  license agreements and nondisclosure agreements. Unless specifically
//  otherwise agreed in writing, all rights, title, and interest to this
//  software and documentation remain with Daniel Amitay. Unless
//  expressly agreed in a signed license agreement, Daniel Amitay makes
//  no representations about the suitability of this software for any purpose
//  and it is provided "as is" without express or implied warranty.
//

@protocol iHasAppDelegate <NSObject>
@optional

// Scheme load callback
- (void) appSchemesSuccess;

// Connectivity fail callback
- (void) loadFailure:(NSError *)error;

// App search callback, returns detected apps
// Returns NSArray full of NSDictionaries
- (void) appSearchSuccess:(NSArray *)appList;
// NSDictionary keys:                 
// "APP_ID" - the appstore id number
// "APP_NAME" - the app's bundle display name
// "ICON_IMAGE" - the 57x57 icon png

@end

@interface iHasApp : NSObject {
    id<iHasAppDelegate> delegate;
    
}
@property (nonatomic, assign) id<iHasAppDelegate> delegate;

//Returns whether or not the URL schemes have already been loaded
-(BOOL) schemesLoaded;

//Returns the list of previously found apps
-(NSArray *) pastFound;

//Initiates a request to reload the URL schemes
-(void)loadSchemes;

//Initiates a request to detect currently installed apps
-(void)findApps;

@end