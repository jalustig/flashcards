//
//  FlashCardsAppDelegate.h
//  FlashCards
//
//  Created by Jason Lustig on 5/27/10.
//  Copyright Jason Lustig 2010. All rights reserved.
//

#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>
#import "ASIHTTPRequest.h"
#import "TICoreDataSync.h"
#import "SyncController.h"
#import <iAd/iAd.h>
#import <StoreKit/StoreKit.h>

@class Reachability;
@class MBProgressHUD;
@class InAppPurchaseManager;
@protocol DBRestClientDelegate;

@interface FlashCardsAppDelegate : NSObject
    <UIApplicationDelegate,
    UIAlertViewDelegate,
    ASIHTTPRequestDelegate,
    DBRestClientDelegate,
    TICDSApplicationSyncManagerDelegate,
    // BITHockeyManagerDelegate,
    // BITUpdateManagerDelegate,
    // BITCrashManagerDelegate,
    SyncControllerDelegate,
    ADInterstitialAdDelegate,
    ADBannerViewDelegate,
    SKRequestDelegate>


+ (BOOL) isIpad;
+ (BOOL)shouldAutorotate:(UIInterfaceOrientation)interfaceOrientation;

- (void) setupTotalCardsDueNotifications:(NSDate*)finalDate;
- (void) updateTotalCardsDueBadge;

- (void)backupWithFileName:(NSString*)uploadFileName withDelegate:(UIViewController*)theDelegate andHUD:(MBProgressHUD*)HUD andProgressView:(UIProgressView*)progressView;
- (void)loadRestoreFile;

- (NSPersistentStoreCoordinator *)persistentStoreCoordinatorWithRebuild:(BOOL)isRebuild;
- (NSPersistentStoreCoordinator*)reloadPersistentStoreCoordinator:(BOOL)isRebuild;
- (void)reloadDatabase:(NSNumber*)_isLoadingRestoreData;
- (void)createManagedObjectModel;

+ (NSMutableString *)buildErrorReportEmail:(NSString *)error userInfo:(NSDictionary*)userInfo localizedDescription:(NSString*)localizedDescription viewControllerName:(NSString*)viewControllerName;


- (BOOL)coreDataStoreIsUpToDateAtUrl:(NSURL*)sourceStoreURL
                              ofType:(NSString*)type 
                             toModel:(NSManagedObjectModel*)finalModel 
                               error:(NSError**)error;

- (void)createCoreDataStoreIfNotExists;

- (void)setupSyncInterface;
- (void)setupSyncWorker;
- (void)preconfigureSyncManager;
- (void)registerSyncManager;
- (void)displayMesasge:(NSString*)message;

- (void)compressAndSync;
- (void)compressImagesAndPerformSelector:(SEL)completionSelector onDelegate:(NSObject*)delegate withObject:(id)object inBackgroundThread:(BOOL)backgroundThread;

@property (nonatomic, assign) BOOL coredataIsCorrupted;
@property (nonatomic, assign) BOOL isLoadingBackup;

@property (nonatomic, strong) Reachability *internetReach;
@property (nonatomic, assign) BOOL createDefaultData;
@property (nonatomic, strong) NSDate *dateAppOpened;
@property (nonatomic, assign) int appLockedTimer;
@property (nonatomic, strong) NSDate *appLockedTimerBegin;

@property (nonatomic, strong) DBRestClient *restClient;
@property (nonatomic) UIBackgroundTaskIdentifier taskIdentifier;

@property (nonatomic, assign) int backupUploadErrorCount;
@property (nonatomic, strong) NSString *backupFileName;
@property (nonatomic, strong) MBProgressHUD *backupHUD;
@property (nonatomic, strong) UIProgressView *backupProgressView;
@property (nonatomic, strong) UIViewController *backupActionDelegate;
@property (nonatomic, assign) BOOL showAlertWhenBackupIsSuccessful;

@property (nonatomic, strong) IBOutlet UIWindow *window;
@property (nonatomic, strong) UINavigationController *navigationController;
@property (nonatomic, strong) NSPersistentStoreCoordinator *persistentStoreCoordinator;

@property (nonatomic, strong) NSManagedObjectContext *writerMOC;
@property (nonatomic, strong) NSManagedObjectContext *mainMOC;

@property (nonatomic, strong) NSManagedObjectModel *managedObjectModel;

@property (nonatomic, strong) NSRegularExpression *stripParenthesesRegex;

@property (nonatomic, strong) InAppPurchaseManager *inAppPurchaseManager;

@property (nonatomic, strong) SyncController *syncController;

@property (nonatomic, assign) BOOL initialSync;
@property (nonatomic, assign) BOOL shouldCancelTICoreDataSyncIdCreation;
@property (nonatomic, assign) BOOL isCurrentlyFixingTICoreDataSyncIds;

@property (nonatomic, strong) ADInterstitialAd *interstitialAd;
@property (nonatomic, strong) ADBannerView     *bannerAd;

@property (nonatomic, assign) BOOL hasAskedForAppleIdSigninToRefreshAppReceipt;

@end

#endif

