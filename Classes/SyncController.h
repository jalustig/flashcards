//
//  SyncController.h
//  FlashCards
//
//  Created by Jason Lustig on 1/17/13.
//  Copyright (c) 2013 Jason Lustig. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "QuizletSync.h"
#import "TICoreDataSync.h"

typedef void (^BackgroundFetchCompletionHandler)(UIBackgroundFetchResult);

@protocol SyncControllerDelegate;

@interface SyncController : NSObject <QuizletSyncDelegate, TICDSDocumentSyncManagerDelegate>

- (void)clearAllLocalAndRemoteData;

- (void)sync;
- (void)cancel;
- (void)getImageIds;
- (BOOL)canPotentiallySync;
+ (BOOL)hudCanCancel:(MBProgressHUD*)hud;

@property (nonatomic) UIBackgroundTaskIdentifier taskIdentifier;

@property (nonatomic, strong) QuizletSync *quizletSync;
@property (nonatomic, strong) TICDSDocumentSyncManager *documentSyncManager;

@property (nonatomic, assign) BOOL syncIsRunningFromBackground;
@property (nonatomic, assign) BOOL syncDidUploadChanges;
@property (nonatomic, assign) BOOL syncWillUploadChanges;

@property (nonatomic, assign) BOOL isDoneFcppSyncFirstRun;
@property (nonatomic, assign) BOOL isDoneFcppSyncFinalRun;
@property (nonatomic, assign) BOOL isDoneQuizletSync;

@property (nonatomic, assign) BOOL isCurrentlyUploadingForFirstTime;
@property (nonatomic, assign) BOOL isCurrentlyUploading;
@property (nonatomic, assign) BOOL isCurrentlyDownloading;

@property (nonatomic, assign) BOOL downloadStoreAfterRegistering;
@property (nonatomic, assign) BOOL uploadStoreAfterRegistering;
@property (nonatomic, assign) BOOL isFirstDownload;

@property (nonatomic, assign) BOOL isCurrentlyRegisteringSyncManagers;
@property (nonatomic, assign) BOOL documentSyncManagerHasRegistered;

@property (nonatomic, assign) BOOL quizletDidChange;

@property (nonatomic, assign) BOOL userInitiatedSync;

@property (nonatomic, strong) id <SyncControllerDelegate> delegate;

@property (nonatomic, assign) BOOL isCurrentlySyncing;

@property (nonatomic, copy) BackgroundFetchCompletionHandler completionHandler;


@end

@protocol SyncControllerDelegate <NSObject>

@optional

- (void)syncDidFinish:(SyncController*)sync;
- (void)syncDidFinish:(SyncController*)sync withError:(NSError*)error;

@end
