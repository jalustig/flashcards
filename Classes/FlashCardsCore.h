//
//  FlashCardsCore.h
//  FlashCards
//
//  Created by Jason Lustig on 5/18/11.
//  Copyright 2011-2014 Jason Lustig Lustig. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "ASIHTTPRequest.h"

@class FCCardSet;
@class FCCollection;
@class FlashCardsAppDelegate;
@class MBProgressHUD;

@interface FlashCardsCore : NSObject {
    
}

#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
+ (void) writeAppReview;
+ (void) shareWithEmail:(UIViewController*)delegate;
#endif

+ (BOOL)iOSisGreaterThan:(float)versionNumber;

+ (BOOL)appIsActive;

+ (UIViewController*)currentViewController;
+ (UIViewController*)parentViewController;
+ (UIViewController*)parentViewController:(int)extraDown;

+ (MBProgressHUD*)currentHUD;
+ (MBProgressHUD*)currentHUD:(NSString*)HUDname;

+ (NSString*)managedObjectModelHash;

+ (void)sync;
+ (void)sync:(UIViewController*)syncDelegate;
+ (void)presentSyncOptions:(BOOL)hasCreatedSync;
+ (void)showSyncHUD;
+ (void)syncSetup;
+ (void)syncCancel;

+ (NSString*)createChunkOfFile:(NSString*)filePath atOffset:(UInt32)offset withLength:(UInt32)chunkLength;
+ (void)uploadFileChunk:(NSString*)localFilePath
        toFinalLocation:(NSString*)finalLocation
      withFinalFileName:(NSString*)finalFileName
             uploadUUID:(NSString*)uploadUUID
                 offset:(int)newOffset
             errorCount:(int)errorCount
    withCompletionBlock:(ASIBasicBlock) completionBlock
        withFailedBlock:(ASIBasicBlock) failedBlock
     showUploadProgress:(BOOL)showUploadProgress;

+ (void)finishChunkedUpload:(NSString *)localFilePath
            toFinalLocation:(NSString *)finalLocation
          withFinalFileName:(NSString *)finalFileName
                 uploadUUID:(NSString *)uploadUUID
        withCompletionBlock:(ASIBasicBlock) completionBlock
            withFailedBlock:(ASIBasicBlock) failedBlock;


+ (NSMutableArray*)loadGoogleLanguageFromManagedObjectContext:(NSManagedObjectContext*)managedObjectContext;
+ (NSString*)getLanguageAcronymFor:(NSString*)acronym fromKey:(NSString*)fromKey toKey:(NSString*)toKey;

+ (void) resetAllRestoreProcessSettings;
+ (void) loadSettingsFile;
+ (void) setSetting:(NSString*)settingName value:(NSObject*)userSetting;
+ (NSObject*) getSetting:(NSString*)defaultString;
+ (BOOL)getSettingBool:(NSString*)settingName;
+ (int)getSettingInt:(NSString*)settingName;
+ (NSDate*)getSettingDate:(NSString*)settingName;

+ (void)uploadLastSyncDates;
+ (BOOL)appIsSyncing;
+ (BOOL)appIsSyncingNoSubscription;
+ (BOOL)hasGrandfatherClause;
+ (BOOL)hasFeature:(NSString*)featureName;
+ (BOOL)hasSubscription;
+ (void)updateHasUsedOneTimeOfflineTTSTrial;
+ (BOOL)currentlyUsingOneTimeOfflineTTSTrial;
+ (void)setHasUsedOneTimeOfflineTTSTrial;
+ (BOOL)hasUsedOneTimeOfflineTTSTrial;
+ (void)provideComplementarySubscription;
+ (int)numCardsToStudy;
+ (int)numCardsToStudy:(NSManagedObjectContext*)context;
+ (int)numTotalCards;
+ (int)numTotalCards:(NSManagedObjectContext*)context;
+ (void)checkUnlimitedCards;
+ (void)showSubscriptionEndedPopup:(BOOL)force;
+ (BOOL)canStudyCardsWithUnlimitedCards;
+ (void)showPurchasePopup:(NSString*)featureName;
+ (void)showPurchasePopup:(NSString*)featureName withMessage:(NSString*)message;

+ (NSString*) randomStringOfLength:(int)length;

+ (NSString *)osVersionNumber;
+ (NSString *)osVersionBuild;
+ (NSString *)appVersion;
+ (NSString *)buildNumber;
+ (NSString *)deviceName;

+ (BOOL) isConnectedToInternet;
+ (BOOL) isConnectedToWifi;

+ (void)saveImportProcessRestoreDataWithVCChoice:(NSString*)vcChoice andCollection:(FCCollection*)collection andCardSet:(FCCardSet*)cardSet;

+ (int)numberCollectionsInManagedContext:(NSManagedObjectContext*)managedObjectContext;

+ (NSString*)documentsDirectory;
+ (FlashCardsAppDelegate*)appDelegate;

+ (NSManagedObjectContext*)writerMOC;
+ (NSManagedObjectContext*)mainMOC;
+ (NSManagedObjectContext*)tempMOC;
+ (void)saveMainMOC;
+ (void)saveMainMOC:(BOOL)wait;
+ (void)saveMainMOC:(BOOL)wait andRunSelector:(SEL)selector onDelegate:(NSObject*)delegate onMainThread:(BOOL)onMainThread;

+ (BOOL)isLoggedIn;
+ (void)checkLogin;
+ (void)checkLoginAndPerformBlock:(ASIBasicBlock)block;
+ (void)login:(NSDictionary*)response;
+ (void)logout;

+ (UIView*)explanationLabelViewWithString:(NSString*)explanation inView:(UIView*)view;
+ (CGFloat)explanationLabelHeightWithString:(NSString*)explanation inView:(UIView*)view;

+ (NSData*) debuggingData;
+ (NSString*) debuggingString;

+ (BOOL)addSkipBackupAttributeToItemAtURL:(NSURL *)URL;

+ (BOOL)deviceCanSendEmail;

+ (void)writeStringToFile:(NSString *)dir
                 fileName:(NSString *)strFileName
                 pathName:(NSString *)strPath
                  content:(NSString *)strContent;
+ (NSURL*) urlForLatexMathString:(NSString*)xContent withJustification:(NSString*)justification withSize:(int)size;
+ (NSURL*) urlForLatexMathString:(NSString*)xContent withJustification:(NSString *)justification withSize:(int)size withFilename:(NSString*)fileName;

+ (BOOL)canShowInterstitialAds;

+ (void)processGrandUnifiedReceipt;

@end
