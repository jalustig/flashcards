//
//  FlashCardsAppDelegate.m
//  FlashCards
//
//  Created by Jason Lustig on 5/27/10.
//  Copyright Jason Lustig 2010. All rights reserved.
//

#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED

#import "FlashCardsAppDelegate.h"
#import "FlashCardsCore.h"

#import "RootViewController.h"
#import "SubscriptionViewController.h"
#import "HelpViewController.h"

#import "FCCollection.h"
#import "FCCardSet.h"
#import "FCCard.h"
#import "FCCardRepetition.h"

#import "Appirater.h"
#import "UIColor-Expanded.h"
#import "URLParser.h"
#import "UIAlertView+Blocks.h"
#import "NSDate+Compare.h"

#import "Reachability.h"

#import "sys/sysctl.h"
#import <stdlib.h>
#include <unistd.h>

#import "MBProgressHUD.h"

#import <StoreKit/StoreKit.h>
#import <iAd/iAd.h>

// FROM: http://cocoadev.com/wiki/MethodSwizzling
#import <objc/runtime.h>

#import "JSONKit.h"
#import "ASIHTTPRequest.h"
#import "AFNetworking.h"

#import "QuizletSync.h"
#import "SyncController.h"

#import "StudyViewController.h"

#import "InAppPurchaseManager.h"
#import "AppLoginViewController.h"

#import "UIDevice+IdentifierAddition.h"

#import "sqlite3-new.h"

#import "UIAlertView+Blocks.h"
#import "NSArray+SplitArray.h"
#import "UIImage+ProportionalFill.h"
#import "NSString+Languages.h"

#import "UIAlertView+Blocks.h"

#import "BackupRestoreListFilesViewController.h"
#import "BackupRestoreViewController.h"

#import "DTVersion.h"

@interface FlashCardsAppDelegate (PrivateCoreDataStack)
@property (nonatomic, retain) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@end


@implementation FlashCardsAppDelegate

@synthesize window, navigationController, persistentStoreCoordinator;
@synthesize dateAppOpened, appLockedTimer, appLockedTimerBegin, createDefaultData;
@synthesize managedObjectModel;
@synthesize writerMOC;
@synthesize mainMOC;
@synthesize internetReach;
@synthesize restClient, taskIdentifier;
@synthesize backupUploadErrorCount;
@synthesize backupFileName;
@synthesize backupHUD, backupProgressView, backupActionDelegate;
@synthesize showAlertWhenBackupIsSuccessful;
@synthesize stripParenthesesRegex;
@synthesize inAppPurchaseManager;

@synthesize coredataIsCorrupted;
@synthesize isLoadingBackup;

@synthesize syncController;
@synthesize initialSync;
@synthesize shouldCancelTICoreDataSyncIdCreation;
@synthesize isCurrentlyFixingTICoreDataSyncIds;

@synthesize interstitialAd;
@synthesize bannerAd;

@synthesize hasAskedForAppleIdSigninToRefreshAppReceipt;

// FROM: https://gist.github.com/3725118

void SwapMethodImplementations(Class cls, SEL left_sel, SEL right_sel) {
    Method leftMethod = class_getInstanceMethod(cls, left_sel);
    Method rightMethod = class_getInstanceMethod(cls, right_sel);
    method_exchangeImplementations(leftMethod, rightMethod);
}

+ (void) initialize {
    if (self == [FlashCardsAppDelegate class]) {
#ifdef __IPHONE_6_0
        SwapMethodImplementations([UIViewController class], @selector(supportedInterfaceOrientations), @selector(sp_supportedInterfaceOrientations));
        SwapMethodImplementations([UIViewController class], @selector(shouldAutorotate), @selector(sp_shouldAutorotate));
#endif
    }
}

+ (BOOL) isIpad {
#ifdef UI_USER_INTERFACE_IDIOM
    return (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);
#else
    return NO;
#endif
}


#pragma mark -
#pragma mark Application lifecycle

- (void)initializeAds {
    if (![FlashCardsCore hasFeature:@"HideAds"] && [FlashCardsCore canShowInterstitialAds]) {
        interstitialAd = [[ADInterstitialAd alloc] init];
        interstitialAd.delegate = self;
    }
    if (![FlashCardsCore hasFeature:@"HideAds"]) {
        bannerAd = [[ADBannerView alloc] initWithFrame:CGRectZero];
        bannerAd.delegate = self;
        bannerAd.currentContentSizeIdentifier = ADBannerContentSizeIdentifierPortrait;
    }
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    hasAskedForAppleIdSigninToRefreshAppReceipt = NO;

    coredataIsCorrupted = NO;
    isLoadingBackup = NO;
    
#if !TARGET_IPHONE_SIMULATOR
    BOOL isMe = NO;
    if ([(NSString*)[FlashCardsCore getSetting:@"quizletLoginUsername"] isEqualToString:@"myname"]) {
        isMe = YES;
    }
    if (!isMe) {
        [Flurry startSession:flurryApplicationKey];
    }
#endif
    
//    [[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"1593b07d2c91ad3d89a6245d9b7cb54d"
//                                                           delegate:self];
//    [[BITHockeyManager sharedHockeyManager] startManager];
    
    [[UIApplication sharedApplication] registerUserNotificationSettings:
     [UIUserNotificationSettings settingsForTypes:
      (UIUserNotificationTypeSound | UIUserNotificationTypeAlert | UIUserNotificationTypeBadge) categories:nil]];
    [[UIApplication sharedApplication] registerForRemoteNotifications];

    initialSync = YES;
    shouldCancelTICoreDataSyncIdCreation = NO;
    isCurrentlyFixingTICoreDataSyncIds = NO;
    
    #if TARGET_IPHONE_SIMULATOR
    [TICDSLog setVerbosity:TICDSLogVerbosityEveryStep];
    #else
    [TICDSLog setVerbosity:TICDSLogVerbosityErrorsOnly];
    #endif
    
    syncController = [[SyncController alloc] init];
    
    inAppPurchaseManager = [[InAppPurchaseManager alloc] init];

    NSString *replaceRegexPattern = @"\\([^\\)]*\\)|\\[[^\\]]*\\]";
    self.stripParenthesesRegex = [NSRegularExpression regularExpressionWithPattern:replaceRegexPattern
                                                                           options:NSRegularExpressionCaseInsensitive
                                                                             error:nil];
    
    NSTimeInterval timeInterval = [[NSUserDefaults standardUserDefaults] doubleForKey:kAppiraterFirstUseDate];
    if (timeInterval == 0)
    {
        timeInterval = [[NSDate date] timeIntervalSince1970];
        [[NSUserDefaults standardUserDefaults] setDouble:timeInterval forKey:kAppiraterFirstUseDate];
    }
    
    // central Reachability class for the whole app.
    internetReach = [Reachability reachabilityForInternetConnection];
    [internetReach startNotifier];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reachabilityChanged:)
                                                 name:kReachabilityChangedNotification
                                               object:nil];
    
    [FlashCardsCore setSetting:@"hasUpdatedBadgeOnTerminate" value:[NSNumber numberWithBool:NO]];
    
    createDefaultData = NO;
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    if (![defaults objectForKey:@"DoNotShowEditMessage-Collection-CardListVC"]) {
        [defaults setObject:[NSNumber numberWithBool:NO] forKey:@"DoNotShowEditMessage-Collection-CardListVC"];
        [defaults setObject:[NSNumber numberWithBool:NO] forKey:@"DoNotShowEditMessage-CardSet-CardListVC"];
    }
    
    [defaults synchronize];
    
    // Set up drop box:
    DBSession* dbSession = [[DBSession alloc]
                            initWithAppKey:dropboxApiConsumerKey
                            appSecret:dropboxApiConsumerSecret
                            root:kDBRootDropbox];
    [DBSession setSharedSession:dbSession];
    
    // create the core data source if it doesn't yet exist:
    [self createCoreDataStoreIfNotExists];
    
    // set up the root view controller:
    RootViewController *rootViewController = [[RootViewController alloc] initWithNibName:@"RootViewController" bundle:nil];
    rootViewController.checkMasterCardSets = NO;
    
    // set up the MOC. If it needs to be migrated, then we should set it to NIL.
    NSString *storePath = [[FlashCardsCore documentsDirectory] stringByAppendingPathComponent: @"FlashCards.sqlite"];
    NSURL *storeUrl = [NSURL fileURLWithPath: storePath];
    NSError *error = nil;
    if ([self coreDataStoreIsUpToDateAtUrl:storeUrl
                                    ofType:NSSQLiteStoreType
                                   toModel:[self managedObjectModel]
                                     error:&error]) {
        [self createManagedObjectModel];
    } else {
#ifdef DEBUG
        NSLog(@"Data store not up to date.");
#endif
        rootViewController.checkMasterCardSets = YES;
    }
    rootViewController.createDefaultData = createDefaultData;
    rootViewController.isFirstLoad = YES;
    
    UINavigationController *aNavigationController = [[UINavigationController alloc]
                                                     initWithRootViewController:rootViewController];
    
    self.navigationController = aNavigationController;
    if (![DTVersion osVersionIsLessThen:@"7.0"]) {
        [window setTintColor:[UIColor colorWithHexString:appTintColor]];
    }
    [window addSubview:[navigationController view]];
    // as per: https://devforums.apple.com/message/727861#727861
    [window setRootViewController:navigationController];
    
    [window makeKeyAndVisible];
    
    [Appirater appLaunched:YES];
    
    // ads need to be initialized after Appirater runs - so that we know when the first time the app was launched was
    [self initializeAds];
    if (![DTVersion osVersionIsLessThen:@"7.0"] && ![FlashCardsCore hasFeature:@"HideAds"]) {
        [UIViewController prepareInterstitialAds];
    }

    if ([FlashCardsCore isConnectedToInternet]) {
        
        if ([FlashCardsCore currentlyUsingOneTimeOfflineTTSTrial]) {
            // remind them to sign up for a subscription:
            SubscriptionViewController *vc = [[SubscriptionViewController alloc] initWithNibName:@"SubscriptionViewController" bundle:nil];
            vc.showTrialEndedPopup = YES;
            vc.giveTrialOption = NO;
            vc.explainSync = NO;
            // Pass the selected object to the new view controller.
            [self.navigationController pushViewController:vc animated:YES];
        }
        [FlashCardsCore updateHasUsedOneTimeOfflineTTSTrial];
    }
    
    if ([launchOptions objectForKey:UIApplicationLaunchOptionsLocalNotificationKey]) {
        UILocalNotification *notification = [launchOptions objectForKey:UIApplicationLaunchOptionsLocalNotificationKey];
        [self showSubscriptionViewControllerWithNotification:notification];
    }
    
    return YES;
}

- (BOOL)application:(UIApplication*)application openURL:(NSURL*)url sourceApplication:(NSString*)sourceApplication annotation:(id)annotation {
    NSString *urlString = [url absoluteString];
    if (url) {
        // NSLog(@"%@", [url absoluteString]);
        // NSLog(@"%@", navigationController.viewControllers);
        if ([[DBSession sharedSession] handleOpenURL:url]) {
            if ([[DBSession sharedSession] isLinked]) {
                NSLog(@"App linked successfully!");
                // At this point you can start making API calls
                UIViewController *currentVC = [FlashCardsCore currentViewController];
                if ([currentVC respondsToSelector:@selector(checkDropboxStatus)]) {
                    [currentVC performSelector:@selector(checkDropboxStatus) withObject:nil];
                }
            }
            return YES;
        }
        if ([url isFileURL]) {
            // only load up the file import view if the app is sent a file URL.
            if ([[url absoluteString] hasSuffix:@".sqlite"]) {
                // we are dealing with an sqlite file.
                RootViewController *rootVC = (RootViewController*)[self.navigationController.viewControllers objectAtIndex:0];
                self.coredataIsCorrupted = YES;
                self.isLoadingBackup = YES;
                [rootVC loadBackupFile:url];
            } else {
                // we are dealing with something else - a CSV or excel file of some kind.
                RootViewController *rootVC = (RootViewController*)[self.navigationController.viewControllers objectAtIndex:0];
                rootVC.fileUrl = url;
                [rootVC checkUrl];
            }
        } else {
            // we are authenticating Quizlet.
            
            // First, find out what the quizlet user did. We need to find out if they allowed or denied the request.
            // as per: http://stackoverflow.com/questions/2225814/nsurl-pull-out-a-single-value-for-a-key-in-a-parameter-string
            URLParser *parser = [[URLParser alloc] initWithURLString:[url absoluteString]];
            NSString *errorStr = [parser valueForVariable:@"error"];
            if ([errorStr length] > 0) {
                NSLog(@"Error URL: %@", [url absoluteString]);
                if ([errorStr isEqual:@"access_denied"]) {
                    // the user denied access. return! and tell the user something, or do something...
                    FCDisplayBasicErrorMessage(@"", @"You have denied FlashCards++ access to your Quizlet account; you cannot access your card sets.");
                    return YES;
                } else {
                    FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"Error", @"Error", @""),
                                               [NSString stringWithFormat:NSLocalizedStringFromTable(@"Error: %@", @"Error", @""),
                                                errorStr]);
                }
                return YES;
            }
            
            // 0. Set something up in the app which lets the app know that we are finishing authentication.
            RootViewController *rootVC = (RootViewController*)[self.navigationController.viewControllers objectAtIndex:0];
            // add information about the authentication request:
            rootVC.isAuthenticatingQuizlet = YES;
            rootVC.quizletAuthenticationCode = [parser valueForVariable:@"code"];
            [rootVC dismissViewControllerAnimated:YES completion:nil];
            
            // 1. Reduce the list of view controllers to just the first, so there are no problems.
            NSMutableArray *viewControllers = [[NSMutableArray alloc] initWithArray:[self.navigationController viewControllers]];
            while ([viewControllers count] > 1) {
                [viewControllers removeLastObject];
            }
            [self.navigationController setViewControllers:viewControllers animated:NO];
            
            // Continue as normal. The rest of the code is in RootVC, so it can display an HUD:
            
            // 2. On loading, RootVC will show an HUD which tells the user that it is finishing authentication
            // 3. When authentication is finished, get rid of HUD & rebuild the list of controllers.
        }
    }
    return YES;
}

/**
 applicationWillTerminate: saves changes in the application's managed object context before the application terminates.
 */
- (void)applicationWillTerminate:(UIApplication *)application {
    // update the number of cards due in background (new thread), but do NOT continue as background task:
    [self setupTotalCardsDueNotifications:nil]; // update it for all of the dates
    [FlashCardsCore saveMainMOC];
}

- (void)applicationWillResignActive:(UIApplication *)application {
    appLockedTimerBegin = [NSDate date];
    // NSLog(@"App locked timer begin - %@", appLockedTimerBegin);
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    if (appLockedTimerBegin == nil) {
        return;
    }
    // NSLog(@"App locked timer end - %@ (from %@)", [NSDate date], appLockedTimerBegin);
    appLockedTimer += [[NSDate date] timeIntervalSinceDate:appLockedTimerBegin];
    // NSLog(@"App locked timer count = %d", appLockedTimer);
    
    if ([self.syncController canPotentiallySync]) {
        NSDate *lastSyncAllData = [FlashCardsCore getSettingDate:@"lastSyncAllData"];
        if (!lastSyncAllData || [[NSDate date] timeIntervalSinceDate:lastSyncAllData] > 60 * 60 * 24) {
            // it's been over a day. we should re-sync everything.
            NSArray *vcs = self.navigationController.viewControllers;
            if ([[vcs objectAtIndex:0] isKindOfClass:[RootViewController class]]) {
                // we are not in the login screen.
                if ([vcs count] == 1) {
                    if ([FlashCardsCore isConnectedToInternet]) {
                        [syncController setUserInitiatedSync:YES];
                        [FlashCardsCore showSyncHUD];
                        [FlashCardsCore sync];
                    }
                } else {
                    NSString *className = NSStringFromClass([[vcs lastObject] class]);
                    NSSet *syncClasses = [NSSet setWithObjects:
                                          @"CardEditCardSetsViewController",
                                          @"CardEditViewController",
                                          @"CardListDuplicatesViewController",
                                          @"CardListViewController",
                                          @"CardSetCreateViewController",
                                          @"CardSetListViewController",
                                          @"CardSetViewViewController",
                                          @"CollectionViewViewController",
                                          @"RootViewController",
                                          nil];
                    if ([syncClasses containsObject:className]) {
                        UIViewController *vc = [FlashCardsCore currentViewController];
                        if ([vc respondsToSelector:@selector(HUD)]) {
                            if ([FlashCardsCore isConnectedToInternet]) {
                                [syncController setUserInitiatedSync:YES];
                                [FlashCardsCore showSyncHUD];
                                [FlashCardsCore sync];
                            }
                        }
                    }
                }
            }
        }
    }
    
}

// as per: http://www.cocoanetics.com/2010/07/understanding-ios-4-backgrounding-and-delegate-messaging/
- (void)applicationDidEnterBackground:(UIApplication *)application {
    // as per: http://stackoverflow.com/a/9893656/353137
    UIApplicationState state = [application applicationState];
    if (state == UIApplicationStateInactive) {
        // NSLog(@"Sent to background by locking screen");
    } else if (state == UIApplicationStateBackground) {
        // NSLog(@"Sent to background by home button/switching to other app");
        UIViewController *vc = [self.navigationController.viewControllers lastObject];
        if ([vc respondsToSelector:@selector(setStudyBrowseModePausedB:)]) {
            [vc performSelector:@selector(setStudyBrowseModePausedB:) withObject:@YES];
        }
    }
    // update the number of cards in the background (new thread), and DO continue it as a background task if asked.
    NSLog(@"# Notifications: %d", (int)([[[UIApplication sharedApplication] scheduledLocalNotifications] count]));
    
    // add only 24 hours worth of updates (should be about 32 updates).
    [self setupTotalCardsDueNotifications:[[NSDate date] dateByAddingTimeInterval:(60*60*24)]];
    
    NSLog(@"# Notifications: %d", (int)([[[UIApplication sharedApplication] scheduledLocalNotifications] count]));
    if (!self.syncController.isCurrentlySyncing) {
        if ([DTVersion osVersionIsLessThen:@"7.0"] ||
            [[[FlashCardsCore appDelegate] syncController] syncWillUploadChanges]) {
            UIViewController *vc = [FlashCardsCore currentViewController];
            if (![vc isKindOfClass:[StudyViewController class]]) {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    BOOL shouldRunFcppSync = NO;
                    NSDate *fcppLastSyncAllData = [FlashCardsCore getSettingDate:@"lastSyncAllData"];
                    if (fcppLastSyncAllData && [[NSDate date] timeIntervalSinceDate:fcppLastSyncAllData] > 60 * 15) {
                        shouldRunFcppSync = YES;
                    }
                    NSDate *quizletLastSyncDate = [FlashCardsCore getSettingDate:@"quizletLastSyncAllData"];
                    if (quizletLastSyncDate && [[NSDate date] timeIntervalSinceDate:quizletLastSyncDate] > 60 * 60 * 12) {
                        [syncController setQuizletDidChange:YES];
                    }
                    
                    if (syncController.quizletDidChange || shouldRunFcppSync) {
                        [FlashCardsCore sync];
                    }
                });
            }
        }
    }
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    [Appirater appEnteredForeground:YES];
    
    [FlashCardsCore setSetting:@"hasUpdatedBadgeOnTerminate" value:[NSNumber numberWithBool:NO]];
    
    if ([FlashCardsCore isConnectedToInternet]) {
        if ([FlashCardsCore currentlyUsingOneTimeOfflineTTSTrial]) {
            // remind them to sign up for a subscription:
            SubscriptionViewController *vc = [[SubscriptionViewController alloc] initWithNibName:@"SubscriptionViewController" bundle:nil];
            vc.showTrialEndedPopup = YES;
            vc.giveTrialOption = NO;
            vc.explainSync = NO;
            // Pass the selected object to the new view controller.
            [self.navigationController pushViewController:vc animated:YES];
        }
        [FlashCardsCore updateHasUsedOneTimeOfflineTTSTrial];
        [FlashCardsCore checkLogin];
    }
    

    /*** Check subscription status ***/
    // if the subscription date has passed, then we should get rid of the subscription
    if ([FlashCardsCore getSettingBool:@"hasSubscription"]) {
        NSDate *endDate = [FlashCardsCore getSettingDate:@"subscriptionEndDate"];
        if ([endDate isEarlierThan:[NSDate date]]) { // if (endDate < anotherDate)
            [FlashCardsCore setSetting:@"hasSubscription" value:@NO];
        }
    }
}

- (void)application:(UIApplication *)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    if ([DTVersion osVersionIsLessThen:@"7.0"]) {
        return;
    }
    FCLog(@"application:performFetchWithCompletionHandler:");
    
    [[[FlashCardsCore appDelegate] syncController] setDelegate:self];
    [[[FlashCardsCore appDelegate] syncController] setSyncIsRunningFromBackground:YES];
    [[[FlashCardsCore appDelegate] syncController] setCompletionHandler:completionHandler];
    [FlashCardsCore sync];
}

# pragma mark -
# pragma mark Sync Controller Delegate methods

- (void)syncDidFinish:(SyncController *)sync {
    FCLog(@"application:performFetchWithCompletionHandler: FINISHED");
    // since sync is running in the background, update the badges:
    [[FlashCardsCore appDelegate] setupTotalCardsDueNotifications:nil];
    [[[FlashCardsCore appDelegate] syncController] setSyncIsRunningFromBackground:NO];
    sync.completionHandler(1);
}
- (void)syncDidFinish:(SyncController *)sync withError:(NSError *)error {
    FCLog(@"application:performFetchWithCompletionHandler: ERROR");
    // since sync is running in the background, update the badges:
    [[FlashCardsCore appDelegate] setupTotalCardsDueNotifications:nil];
    [[[FlashCardsCore appDelegate] syncController] setSyncIsRunningFromBackground:NO];
    sync.completionHandler(0);
}

# pragma mark -
# pragma mark HTTP Request functions (catch all for app)

- (void)requestFinished:(ASIHTTPRequest *)request
{
    
    // [HUD hide:YES];

}

- (void)requestFailed:(ASIHTTPRequest *)request
{
}

# pragma mark - Autorotation

- (NSUInteger) application:(UIApplication*)application supportedInterfaceOrientationsForWindow:(UIWindow *)window {
    return UIInterfaceOrientationMaskAll;
}

+ (BOOL)shouldAutorotate:(UIInterfaceOrientation)interfaceOrientation {
    if ([FlashCardsAppDelegate isIpad]) {
        return YES;
    }
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait || interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown);
}

# pragma mark -
# pragma mark Error reporting

+ (NSMutableString *)buildErrorReportEmail:(NSString *)error userInfo:(NSDictionary*)userInfo localizedDescription:(NSString*)localizedDescription viewControllerName:(NSString*)viewControllerName {
    NSMutableString *errorReport = [[NSMutableString alloc] initWithCapacity:0];
    
    [errorReport appendString:NSLocalizedStringFromTable(@"Thank you for sending an error report. We will work to fix the error as quickly as possible and will be in touch if we need more information to track it down. To find the bug more quickly, please tell us exactly what you did before you got this error message:", @"Error", @"Error report email text")];
    // NOTE: We won't actually i18n the error report text.
    [errorReport appendString:@"\n\n"];
    [errorReport appendString:@"1. \n2. \n3. \n\n"];
    [errorReport appendString:@"------\n\nError Information:\n\n"];
    [errorReport appendFormat:@"Date: %@\n\n", [NSDate date]];
    [errorReport appendFormat:@"App Version: %@ (%@)\niOS Version: %@ (%@)\n\n", [FlashCardsCore appVersion], [FlashCardsCore buildNumber], [FlashCardsCore osVersionNumber], [FlashCardsCore osVersionBuild]];
    [errorReport appendFormat:@"Location: %@\n\n", viewControllerName];
    [errorReport appendFormat:@"Error: %@\n\n", error];
    [errorReport appendFormat:@"Userinfo: %@\n\n", userInfo];
    [errorReport appendFormat:@"Localized Description: %@\n\n", localizedDescription];
    
    // as per http://www.freetimestudios.com/2009/11/13/core-data-tips-for-iphone-devs-part-2-better-error-messages/
    NSArray* _ft_detailedErrors = [userInfo objectForKey:NSDetailedErrorsKey];
    if(_ft_detailedErrors != nil && [_ft_detailedErrors count] > 0) {
        for(NSError* _ft_detailedError in _ft_detailedErrors) {
            [errorReport appendFormat:@"Detailed Error: %@", [_ft_detailedError userInfo]];
        }
    }
    
    return errorReport;
}

# pragma mark -
# pragma mark Notification methods

- (int)setupSubscriptionNotifications {
    // don't show subscription notifications if they don't have a subscription
    if (![FlashCardsCore hasSubscription]) {
        return 0;
    }
    
    // don't show subscription notifications if they have a lifetime subscription
    if ([FlashCardsCore getSettingBool:@"hasSubscriptionLifetime"]) {
        return 0;
    }

    int notificationsCreated = 0;
    
    if (![FlashCardsCore isLoggedIn] && [FlashCardsCore hasSubscription]) {
        UILocalNotification *createAccountNotification;
        
        // 2 weeks before subscription ends:
        createAccountNotification = [[UILocalNotification alloc] init];
        [createAccountNotification setAlertBody:NSLocalizedStringFromTable(@"You should create a FlashCards++ account, to protect your FlashCards++ subscription on and use it on multiple devices.", @"Subscription", @"")];
        [createAccountNotification setUserInfo:@{
                                         @"showCreateAccountVC" : @YES,
                                         @"showSubscriptionVC"  : @NO
                                         }];
        // if it's past the time to prompt to create an account:
        NSDate *promptCreateAccount = [FlashCardsCore getSettingDate:@"promptCreateAccount"];
        // if the current date is later than promptCreateAccount
        NSDate *fireDate;
        if ([promptCreateAccount isEarlierThan:[NSDate date]]) {
            fireDate = [NSDate dateWithTimeInterval:(60 * 60 * 10)
                                          sinceDate:[NSDate date]];
        } else {
            fireDate = promptCreateAccount;
        }
        FCLog(@"Create account fires: %@", fireDate);
        [createAccountNotification setFireDate:fireDate];

        // only show the notification if it is AFTER the current date:
        if ([createAccountNotification.fireDate isLaterThan:[NSDate date]]) {
            [[UIApplication sharedApplication] scheduleLocalNotification:createAccountNotification];
            notificationsCreated++;
        }
    }
    
    NSDate *subscriptionEndDate = [FlashCardsCore getSettingDate:@"subscriptionEndDate"];
    UILocalNotification *localNotification;
    
    // 2 weeks before subscription ends:
    localNotification = [[UILocalNotification alloc] init];
    [localNotification setAlertBody:NSLocalizedStringFromTable(@"Your subscription expires in two weeks.", @"Subscription", @"")];
    [localNotification setFireDate:[NSDate dateWithTimeInterval:(60 * 60 * 24 * 14 * -1) sinceDate:subscriptionEndDate]];
    [localNotification setUserInfo:@{
     @"showSubscriptionVC"  : @YES,
     @"showCreateAccountVC" : @NO,
     @"expires" : @"two weeks"
     }];
    // only show the notification if it is AFTER the current date:
    if ([localNotification.fireDate isLaterThan:[NSDate date]]) {
        [[UIApplication sharedApplication] scheduleLocalNotification:localNotification];
        notificationsCreated++;
    }
    
    // 1 week before subscription ends
    localNotification = [[UILocalNotification alloc] init];
    [localNotification setAlertBody:NSLocalizedStringFromTable(@"Your subscription expires in one week.", @"Subscription", @"")];
    [localNotification setFireDate:[NSDate dateWithTimeInterval:(60 * 60 * 24 * 7 * -1) sinceDate:subscriptionEndDate]];
    [localNotification setUserInfo:@{
     @"showSubscriptionVC" : @YES,
     @"showCreateAccountVC" : @NO,
     @"expires" : @"one week"
     }];
    // only show the notification if it is AFTER the current date:
    if ([localNotification.fireDate isLaterThan:[NSDate date]]) {
        [[UIApplication sharedApplication] scheduleLocalNotification:localNotification];
        notificationsCreated++;
    }
    
    // 3 days before subscription ends
    localNotification = [[UILocalNotification alloc] init];
    [localNotification setAlertBody:NSLocalizedStringFromTable(@"Your subscription expires in three days.", @"Subscription", @"")];
    [localNotification setFireDate:[NSDate dateWithTimeInterval:(60 * 60 * 24 * 3 * -1) sinceDate:subscriptionEndDate]];
    [localNotification setUserInfo:@{
     @"showSubscriptionVC" : @YES,
     @"showCreateAccountVC" : @NO,
     @"expires" : @"three days"
     }];
    [[UIApplication sharedApplication] scheduleLocalNotification:localNotification];
    notificationsCreated++;
    
    // 1 day before subscription ends
    localNotification = [[UILocalNotification alloc] init];
    [localNotification setAlertBody:NSLocalizedStringFromTable(@"Your subscription expires tomorrow.", @"Subscription", @"")];
    [localNotification setFireDate:[NSDate dateWithTimeInterval:(60 * 60 * 24 * 1 * -1) sinceDate:subscriptionEndDate]];
    [localNotification setUserInfo:@{
     @"showSubscriptionVC" : @YES,
     @"showCreateAccountVC" : @NO,
     @"expires" : @"tomorrow"
     }];
    // only show the notification if it is AFTER the current date:
    if ([localNotification.fireDate isLaterThan:[NSDate date]]) {
        [[UIApplication sharedApplication] scheduleLocalNotification:localNotification];
        notificationsCreated++;
    }
    
    return notificationsCreated;

}

- (void) setupTotalCardsDueNotifications:(NSDate*)finalDate {
    // make sure this function will only run once during app termination, it appears to run double:
    if (![FlashCardsCore getSettingBool:@"hasUpdatedBadgeOnTerminate"]) {
        [FlashCardsCore setSetting:@"hasUpdatedBadgeOnTerminate" value:@YES];
    }
    
    // make sure it will not run if you are going to get Quizlet authentication:
    if ([FlashCardsCore getSettingBool:@"importProcessRestore"] || [FlashCardsCore getSettingBool:@"uploadProcessRestore"]) {
        // for some users, we found that the "importProcessRestore" or "uploadProcessRestore" options weren't getting updated
        // properly to "@NO" when the process was done -- which means that this function ALWAYS returns so the badges NEVER update!
        // return;
    }
    
    int notificationsCreated = 0;
    
    // don't display the badges if the user doesn't want to:
    if (![FlashCardsCore getSettingBool:@"settingDisplayBadge"]) {
        [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
        [[UIApplication sharedApplication] cancelAllLocalNotifications];
        notificationsCreated += [self setupSubscriptionNotifications];
    }

    if (![FlashCardsCore getSettingBool:@"settingDisplayNotification"] &&
        ![FlashCardsCore getSettingBool:@"settingDisplayBadge"]) {
        return;
    }

    // we used to update the total cards due badge here, but rather we will consolidate it into the main loop
    // so we will only have **one** fetch request taking place.
    if ([FlashCardsCore getSettingBool:@"settingDisplayBadge"]) {
        [self updateTotalCardsDueBadge];
    }
    
    // get out of here if the device doesn't support UILocalNotification items:
    Class LocalNotification = NSClassFromString(@"UILocalNotification");
    if (LocalNotification == nil) {
        return;
    }
    
    [[UIApplication sharedApplication] cancelAllLocalNotifications];
    notificationsCreated += [self setupSubscriptionNotifications];
    
    // we can't simply call [self updateTotalCardsDueBadge] every half an hour,
    // so we set up a set of 60 UILocalNotification items
    // (the maximum, MINUS 3: one for renewing subscription with the periods
    // 2 weeks, 1 week, 3 days, and 1 day before subscription runs out).
    // If we do it every half hour, this only will last 32 hours. So we want to 
    // do it with the following setup:
    // 4 x 15 minutes (1 hr)
    // 10 x 30 minutes (5 hrs - total 6 hours - total 14 items)
    // 18 x 1 hour (18 hrs - total 24 hours - total 32 items)
    // 12 x 2 hrs (1 day - total 2 days - total 44 items)
    // 12 x 4 hrs (2 days - total 4 days - total 56 items)
    // 4 x 24 hrs (4 days - total 8 days - total 60 items)
    // The hope is that the user will come back to use the app within 8 days!
    
    // to set this up, we will first create an array of the intervals:
    NSMutableArray *timeIntervals = [[NSMutableArray alloc] initWithCapacity:0];
    // 4 x 15 minutes (1 hr)
    for (int i = 0; i < 4; i++) {
        // For the first time around, just set the first interval as 15 minutes from now
        if ([timeIntervals count] == 0) {
            [timeIntervals addObject:[[NSDate date] dateByAddingTimeInterval:(15*60)]];
        } else {
            // Then progressively set the interval as 15 minutes since the last interval
            [timeIntervals addObject:[[timeIntervals lastObject] dateByAddingTimeInterval:(15*60)]];
        }
    }
    // 10 x 30 minutes (5 hrs - total 6 hours - total 14 items)
    for (int i = 0; i < 10; i++) {
        //[timeIntervals addObject:[NSNumber numberWithInt:(30*60)]];
        [timeIntervals addObject:[[timeIntervals lastObject] dateByAddingTimeInterval:(30*60)]];
    }
    // 18 x 1 hour (18 hrs - total 24 hours - total 32 items)
    for (int i = 0; i < 18; i++) {
        //[timeIntervals addObject:[NSNumber numberWithInt:(60*60)]];
        [timeIntervals addObject:[[timeIntervals lastObject] dateByAddingTimeInterval:(60*60)]];
    }
    // 12 x 2 hrs (1 day - total 2 days - total 44 items)
    for (int i = 0; i < 12; i++) {
        //[timeIntervals addObject:[NSNumber numberWithInt:(2*60*60)]];
        [timeIntervals addObject:[[timeIntervals lastObject] dateByAddingTimeInterval:(2*60*60)]];
    }
    // 12 x 4 hrs (2 days - total 4 days - total 56 items)
    for (int i = 0; i < 12; i++) {
        //[timeIntervals addObject:[NSNumber numberWithInt:(4*60*60)]];
        [timeIntervals addObject:[[timeIntervals lastObject] dateByAddingTimeInterval:(4*60*60)]];
    }
    // 4 x 24 hrs (4 days - total 8 days - total 60 items)
    for (int i = 0; i < 4; i++) {
        //[timeIntervals addObject:[NSNumber numberWithInt:(24*60*60)]];
        [timeIntervals addObject:[[timeIntervals lastObject] dateByAddingTimeInterval:(24*60*60)]];
    }
    
    if (!finalDate) {
        finalDate = (NSDate*)[timeIntervals lastObject];
    }

    NSDate *beginCountingCardsForBadge = [NSDate date];
    NSDate *beginCountingCardsForNotificationDate = [NSDate date];

    // if we will display study notification, we need to remove the last time interval
    // to make space for an extra notification:
    NSDate *studyNotificationInterval1 = nil;
    NSDate *studyNotificationInterval2 = nil;
    NSDate *studyNotificationInterval3 = nil;
    if ([FlashCardsCore getSettingBool:@"settingDisplayNotification"]) {
        notificationsCreated += 3;
        
        // Get the time **today** at the specific time the user selected in the settings
        // as per: http://stackoverflow.com/a/2411276/353137
        NSCalendar *myCalendar = [NSCalendar currentCalendar];
        NSDateComponents *components = [myCalendar components:NSYearCalendarUnit|NSMonthCalendarUnit|NSDayCalendarUnit
                                                     fromDate:[NSDate date]];
        [components setHour:[FlashCardsCore getSettingInt:@"settingDisplayNotificationTime"]];
        [components setMinute:0];
        [components setSecond:0];
        studyNotificationInterval1 = [myCalendar dateFromComponents:components];
        
        NSDate *oneDayAgo = [NSDate dateWithTimeInterval:(60 * 60 * 24 * -1) sinceDate:studyNotificationInterval1];
        NSDate *lastDateStudied = [FlashCardsCore getSettingDate:@"lastDateStudied"];
        if ([lastDateStudied isEarlierThan:oneDayAgo]) {
            beginCountingCardsForNotificationDate = oneDayAgo;
        } else {
            beginCountingCardsForNotificationDate = lastDateStudied;
        }
        
        // If the notification is in less than an hour, we want to set up the notification
        // for the next day at the specific time.
        NSDate *oneHourFromNow = [NSDate dateWithTimeIntervalSinceNow:(60 * 60 * 1.5)];
        if (self.syncController.syncIsRunningFromBackground) {
            FCLog(@"sync IS running from background");
        } else {
            FCLog(@"sync IS NOT running from background");
        }
        if ([oneHourFromNow isLaterThan:studyNotificationInterval1] && !self.syncController.syncIsRunningFromBackground) {
            studyNotificationInterval1 = [NSDate dateWithTimeInterval:(60 * 60 * 24) sinceDate:studyNotificationInterval1];
        }
        studyNotificationInterval2 = [NSDate dateWithTimeInterval:(60 * 60 * 24) sinceDate:studyNotificationInterval1];
        studyNotificationInterval3 = [NSDate dateWithTimeInterval:(60 * 60 * 24) sinceDate:studyNotificationInterval2];

        // Make sure that the final date is not earlier than the study notification interval.
        // Otherwise we won't get the total number of new cards to study in this time period.
        if ([finalDate isEarlierThan:studyNotificationInterval3]) {
            finalDate = studyNotificationInterval3;
        }
    }
    
    for (int i = 0; i < notificationsCreated; i++) {
        if ([timeIntervals count] > 0) {
            FCLog(@"Removed timeInterval %d", i);
            [timeIntervals removeLastObject]; // removes a notification created earlier in the process
        }
    }
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    // Edit the entity name as appropriate.
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Card"
                                              inManagedObjectContext:[FlashCardsCore mainMOC]];
    if (finalDate != nil) {
        [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"isDeletedObject = NO and isSpacedRepetition = YES and isLapsed = NO and nextRepetitionDate > %@ and nextRepetitionDate < %@", beginCountingCardsForNotificationDate, finalDate]];
    } else {
        [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"isDeletedObject = NO and isSpacedRepetition = YES and isLapsed = NO and nextRepetitionDate > %@", beginCountingCardsForNotificationDate]];
    }
    [fetchRequest setEntity:entity];
    [fetchRequest setPropertiesToFetch:[NSArray arrayWithObjects:@"nextRepetitionDate", nil]];
    [fetchRequest setResultType:NSDictionaryResultType];
    // Edit the sort key as appropriate.
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"nextRepetitionDate" ascending:YES];
    NSArray *sortDescriptors = [[NSArray alloc] initWithObjects:sortDescriptor, nil];
    [fetchRequest setSortDescriptors:sortDescriptors];
    NSArray *cards = [[FlashCardsCore mainMOC] executeFetchRequest:fetchRequest error:nil];
    
    // Go through the cards, and count how many are in each day:
    int cardCounter = 0; // keeps track of the cards as we loop through them.
    int totalCardsCount = (int)[[UIApplication sharedApplication] applicationIconBadgeNumber];

    int totalCardsBeforeNotification1 = totalCardsCount;
    int newCardsBeforeNotification1 = 0;
    
    int totalCardsBeforeNotification2 = totalCardsCount;
    int newCardsBeforeNotification2 = 0;

    int totalCardsBeforeNotification3 = totalCardsCount;
    int newCardsBeforeNotification3 = 0;

    BOOL displayNotification = [FlashCardsCore getSettingBool:@"settingDisplayNotification"];
    FCCard *currentCard;

    for (FCCard *card in cards) {
        if ([(NSDate*)[card valueForKey:@"nextRepetitionDate"] isEarlierThan:beginCountingCardsForBadge]) {
            cardCounter++; // make sure we don't count cards which are due earlier than now
            NSDate *next = (NSDate*)[card valueForKey:@"nextRepetitionDate"];
            if ([next isEarlierThan:studyNotificationInterval1]) {
                newCardsBeforeNotification1++;
                
                // we don't count total cards before notification because it is based
                // on the totalCardsCount item, which is set based on the number **now**,
                // not when the last time the user studied was:
                // totalCardsBeforeNotification++;
            }

        }
    }
    
    // go through each timeInterval, counting the number of cards in the interval.
    for (NSDate *endDate in timeIntervals) {
        if (finalDate != nil) { // if finalDate is nil, then we should be doing ALL the intervals.
            // if we are past the final date, then stop adding new cards.
            if ([finalDate isEarlierThan:endDate]) {
                break;
            }
        }
        do { // until the card's nextRepetitionDate is later than the endDate for this interval
            if (cardCounter >= [cards count]) {
                // if we are displaying the notification and the next repetition date is
                // less than the studyNotificationInterval, then increment:
                if (displayNotification) {
                    if ([(NSDate*)[currentCard valueForKey:@"nextRepetitionDate"] isEarlierThan:studyNotificationInterval1]) {
                        newCardsBeforeNotification1++;
                        totalCardsBeforeNotification1++;
                    }
                    if ([(NSDate*)[currentCard valueForKey:@"nextRepetitionDate"] isEarlierThan:studyNotificationInterval2]) {
                        if ([(NSDate*)[currentCard valueForKey:@"nextRepetitionDate"] isLaterThan:studyNotificationInterval1]) {
                            newCardsBeforeNotification2++;
                        }
                        totalCardsBeforeNotification2++;
                    }
                    if ([(NSDate*)[currentCard valueForKey:@"nextRepetitionDate"] isEarlierThan:studyNotificationInterval3]) {
                        if ([(NSDate*)[currentCard valueForKey:@"nextRepetitionDate"] isLaterThan:studyNotificationInterval2]) {
                            newCardsBeforeNotification3++;
                        }
                        totalCardsBeforeNotification3++;
                    }
                }
                // if we are past the total number of cards, get out!! Otherwise we'll crash:
                totalCardsCount++;  // still increment, because otherwise we will end up with one card
                                    // less than we should when decrementing below:
                break;
            }
            currentCard = [cards objectAtIndex:cardCounter];
            if ([endDate isLaterThan:[currentCard valueForKey:@"nextRepetitionDate"]]) {
                // NSLog(@"Card Due: %@", [currentCard valueForKey:@"nextRepetitionDate"]);
                // if we are displaying the notification and the next repetition date is
                // less than the studyNotificationInterval, then increment:
                if (displayNotification) {
                    // If we have passed the notifiation interval but still haven't found cards to study,
                    // then we should push it to the next day. This makes it so that there will **always**
                    // be a notification to tell the user to study; if they only have a few cards and there won't be any new ones
                    // to review in the coming 24 hours or so, then we'll make sure to remind them when there **are**
                    // cards to study.
                    if ([(NSDate*)[currentCard valueForKey:@"nextRepetitionDate"] isLaterThan:studyNotificationInterval1] && newCardsBeforeNotification1 == 0) {
                        studyNotificationInterval1 = [NSDate dateWithTimeInterval:(60 * 60 * 24) sinceDate:studyNotificationInterval1];
                        studyNotificationInterval2 = [NSDate dateWithTimeInterval:(60 * 60 * 24) sinceDate:studyNotificationInterval1];
                        studyNotificationInterval3 = [NSDate dateWithTimeInterval:(60 * 60 * 24) sinceDate:studyNotificationInterval2];
                    }
                    if ([(NSDate*)[currentCard valueForKey:@"nextRepetitionDate"] isEarlierThan:studyNotificationInterval1]) {
                        newCardsBeforeNotification1++;
                        totalCardsBeforeNotification1++;
                    }
                    if ([(NSDate*)[currentCard valueForKey:@"nextRepetitionDate"] isEarlierThan:studyNotificationInterval2]) {
                        if ([(NSDate*)[currentCard valueForKey:@"nextRepetitionDate"] isLaterThan:studyNotificationInterval1]) {
                            newCardsBeforeNotification2++;
                        }
                        totalCardsBeforeNotification2++;
                    }
                    if ([(NSDate*)[currentCard valueForKey:@"nextRepetitionDate"] isEarlierThan:studyNotificationInterval3]) {
                        if ([(NSDate*)[currentCard valueForKey:@"nextRepetitionDate"] isLaterThan:studyNotificationInterval2]) {
                            newCardsBeforeNotification3++;
                        }
                        totalCardsBeforeNotification3++;
                    }
                }
                totalCardsCount++;
                cardCounter++;
            }
        } while ([endDate isLaterThan:[currentCard valueForKey:@"nextRepetitionDate"]]);
        if ([FlashCardsCore getSettingBool:@"settingDisplayBadge"]) {
            UILocalNotification *localNotification = [[UILocalNotification alloc] init];
            localNotification.applicationIconBadgeNumber = totalCardsCount;
            localNotification.timeZone = [NSTimeZone defaultTimeZone];
            localNotification.fireDate = endDate;
            [[UIApplication sharedApplication] scheduleLocalNotification:localNotification];
            FCLog(@"Notification: %@ - %d cards to review", endDate, totalCardsCount);
        }
        //NSLog(@"%@ - %d cards due", endDate, totalCardsCount);
    }
    
    FCLog(@"New cards to study before the notification #1 fires: %d", newCardsBeforeNotification1);
    FCLog(@"New cards to study before the notification #2 fires: %d", newCardsBeforeNotification2);
    FCLog(@"New cards to study before the notification #3 fires: %d", newCardsBeforeNotification3);
    if (displayNotification) {
        if (newCardsBeforeNotification1 > 0) {
            UILocalNotification *localNotification = [[UILocalNotification alloc] init];
            NSMutableString *message = [NSMutableString stringWithFormat:FCPluralLocalizedStringFromTable(@"You have %d new flashcards to review today", @"Plural", @"",
                                        [NSNumber numberWithInt:newCardsBeforeNotification1]),
                                        newCardsBeforeNotification1];
            if (newCardsBeforeNotification1 != totalCardsBeforeNotification1) {
                [message appendString:@" "];
                [message appendFormat:NSLocalizedStringFromTable(@"(%d total)", @"Study", @""), totalCardsBeforeNotification1];
            }
            [message appendString:@"."];
            FCLog(@"Notification: %@", message);
            [localNotification setAlertBody:message];
            localNotification.timeZone = [NSTimeZone defaultTimeZone];
            localNotification.fireDate = studyNotificationInterval1;
            [[UIApplication sharedApplication] scheduleLocalNotification:localNotification];
        }
        if (newCardsBeforeNotification2 > 0) {
            UILocalNotification *localNotification = [[UILocalNotification alloc] init];
            NSMutableString *message = [NSMutableString stringWithFormat:FCPluralLocalizedStringFromTable(@"You have %d new flashcards to review today", @"Plural", @"",
                                        [NSNumber numberWithInt:newCardsBeforeNotification2]),
                                        newCardsBeforeNotification2];
            if (newCardsBeforeNotification2 != totalCardsBeforeNotification2) {
                [message appendString:@" "];
                [message appendFormat:NSLocalizedStringFromTable(@"(%d total)", @"Study", @""), totalCardsBeforeNotification2];
            }
            [message appendString:@"."];
            FCLog(@"Notification: %@", message);
            [localNotification setAlertBody:message];
            localNotification.timeZone = [NSTimeZone defaultTimeZone];
            localNotification.fireDate = studyNotificationInterval2;
            [[UIApplication sharedApplication] scheduleLocalNotification:localNotification];
        }
        if (newCardsBeforeNotification3 > 0) {
            UILocalNotification *localNotification = [[UILocalNotification alloc] init];
            NSMutableString *message = [NSMutableString stringWithFormat:FCPluralLocalizedStringFromTable(@"You have %d new flashcards to review today", @"Plural", @"",
                                        [NSNumber numberWithInt:newCardsBeforeNotification3]),
                                        newCardsBeforeNotification3];
            if (newCardsBeforeNotification3 != totalCardsBeforeNotification3) {
                [message appendString:@" "];
                [message appendFormat:NSLocalizedStringFromTable(@"(%d total)", @"Study", @""), totalCardsBeforeNotification3];
            }
            [message appendString:@"."];
            FCLog(@"Notification: %@", message);
            [localNotification setAlertBody:message];
            localNotification.timeZone = [NSTimeZone defaultTimeZone];
            localNotification.fireDate = studyNotificationInterval3;
            [[UIApplication sharedApplication] scheduleLocalNotification:localNotification];
        }
    }
}
- (void) updateTotalCardsDueBadge {
    int totalCount = [FlashCardsCore numCardsToStudy];
    if (totalCount < 0) {
        return;
    }
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:totalCount];
}

- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification {
    NSLog(@"%@", notification.userInfo);
    // as per: http://stackoverflow.com/a/7169287/353137
    UIApplicationState state = [application applicationState];
    if (state == UIApplicationStateInactive) {
        // Application was in the background when notification was delivered.
        [self showSubscriptionViewControllerWithNotification:notification];
    } else {
        // show a UIAlertView to ask them what they want to do
        UIViewController *vc = (UIViewController*)[self.navigationController.viewControllers lastObject];
        if (![vc isKindOfClass:[SubscriptionViewController class]]) {
            RIButtonItem *cancelItem = [RIButtonItem item];
            cancelItem.label = NSLocalizedStringFromTable(@"Not Now", @"Feedback", @"");
            cancelItem.action = ^{};
            
            RIButtonItem *subscribeItem = [RIButtonItem item];
            subscribeItem.label = NSLocalizedStringFromTable(@"Renew Subscription", @"Settings", @"");
            subscribeItem.action = ^{
                SubscriptionViewController *vc = [[SubscriptionViewController alloc] initWithNibName:@"SubscriptionViewController" bundle:nil];
                vc.showTrialEndedPopup = NO;
                vc.giveTrialOption = NO;
                vc.explainSync = NO;
                // Pass the selected object to the new view controller.
                [self.navigationController pushViewController:vc animated:YES];
            };
            
            RIButtonItem *learnMoreItem = [RIButtonItem item];
            learnMoreItem.label = NSLocalizedStringFromTable(@"Learn More About Subscriptions", @"Subscription", @"");
            learnMoreItem.action = ^{
                NSMutableArray *vcs = [NSMutableArray arrayWithArray:self.navigationController.viewControllers];
                SubscriptionViewController *subscriptionVC = [[SubscriptionViewController alloc] initWithNibName:@"SubscriptionViewController" bundle:nil];
                subscriptionVC.showTrialEndedPopup = NO;
                subscriptionVC.giveTrialOption = NO;
                subscriptionVC.explainSync = NO;
                [vcs addObject:subscriptionVC];
                
                [vcs addObject:[subscriptionVC learnMoreViewController]];
                
                [self.navigationController setViewControllers:vcs animated:YES];
            };
            
            NSString *message;
            NSString *expires = [notification.userInfo objectForKey:@"expires"];
            if ([expires isEqualToString:@"two weeks"]) {
                message = NSLocalizedStringFromTable(@"Your subscription expires in two weeks.", @"Subscription", @"");
            } else if ([expires isEqualToString:@"one week"]) {
                message = NSLocalizedStringFromTable(@"Your subscription expires in one week.", @"Subscription", @"");
            } else if ([expires isEqualToString:@"three days"]) {
                message = NSLocalizedStringFromTable(@"Your subscription expires in three days.", @"Subscription", @"");
            } else if ([expires isEqualToString:@"tomorrow"]) {
                message = NSLocalizedStringFromTable(@"Your subscription expires tomorrow.", @"Subscription", @"");
            }
            
            if (!message) {
                return;
            }
            
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@""
                                                            message:message
                                                   cancelButtonItem:cancelItem
                                                   otherButtonItems:subscribeItem, learnMoreItem, nil];
            [alert show];
        }
    }
}

- (void)showSubscriptionViewControllerWithNotification:(UILocalNotification*)notification {
    UIViewController *vc = (UIViewController*)[self.navigationController.viewControllers lastObject];
    if (![vc isKindOfClass:[SubscriptionViewController class]] && ![vc isKindOfClass:[AppLoginViewController class]]) {
        if (notification.userInfo) {
            NSNumber *showSubscriptionVC = [notification.userInfo objectForKey:@"showSubscriptionVC"];
            NSNumber *showCreateAccountVC = [notification.userInfo objectForKey:@"showCreateAccountVC"];
            if (showSubscriptionVC && [showSubscriptionVC boolValue]) {
                SubscriptionViewController *vc = [[SubscriptionViewController alloc] initWithNibName:@"SubscriptionViewController" bundle:nil];
                vc.showTrialEndedPopup = NO;
                vc.giveTrialOption = NO;
                vc.explainSync = NO;
                // Pass the selected object to the new view controller.
                [self.navigationController pushViewController:vc animated:YES];
            } else if (showCreateAccountVC && [showCreateAccountVC boolValue]) {
                AppLoginViewController *vc = [[AppLoginViewController alloc] initWithNibName:@"AppLoginViewController" bundle:nil];
                vc.isCreatingNewAccount = YES;
                [self.navigationController pushViewController:vc animated:YES];
            }
        }
    }
}

# pragma mark -
# pragma mark Push Notification methods
- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    NSLog(@"My token is: %@", deviceToken);
    
    // as per: http://stackoverflow.com/a/9372848/353137
    const void *devTokenBytes = [deviceToken bytes];
    const unsigned *tokenBytes = [deviceToken bytes];
    NSString *hexToken = [NSString stringWithFormat:@"%08x%08x%08x%08x%08x%08x%08x%08x",
                          ntohl(tokenBytes[0]), ntohl(tokenBytes[1]), ntohl(tokenBytes[2]),
                          ntohl(tokenBytes[3]), ntohl(tokenBytes[4]), ntohl(tokenBytes[5]),
                          ntohl(tokenBytes[6]), ntohl(tokenBytes[7])];

    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/push/register", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    [request addPostValue:[[UIDevice currentDevice] uniqueDeviceIdentifier] forKey:@"device_id"];
    [request addPostValue:[[UIDevice currentDevice] advertisingIdentifier] forKey:@"device_adid"];
    // pass the device token to the server:
    [request addPostValue:hexToken
                   forKey:@"push_token"];
    
    
    // Send information to the server as to if the device has a production or sandbox
    // token. Then the server will know which to contact later on.
#if PUSH_PRODUCTION
    [request addPostValue:@1 forKey:@"push_production"];
#else
    [request addPostValue:@0 forKey:@"push_production"];
#endif
    
    [request setCompletionBlock:^{
        FCLog(@"Push notification registration completed");
        FCLog(@"%@", requestBlock.responseString);
    }];
    [request setFailedBlock:^{
        FCLog(@"Push notification registration failed");
        FCLog(@"%@", requestBlock.responseString);
    }];
    [request startAsynchronous];
}

- (void)application:(UIApplication *)app didFailToRegisterForRemoteNotificationsWithError:(NSError *)err {
    FCLog(@"Error registering for remote notifications: %@", err);
}


- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
    FCLog(@"remote notification WITHOUT completion handler");
    NSLog(@"%@", userInfo);
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    // FCLog(@"remote notification with completion handler");
    // NSLog(@"%@", userInfo);
    
    if ([DTVersion osVersionIsLessThen:@"7.0"]) {
        return;
    }
    
    if ([FlashCardsCore appIsActive]) {
        return;
    }
    FCLog(@"application:performFetchWithCompletionHandler:");
    
    [[[FlashCardsCore appDelegate] syncController] setDelegate:self];
    [[[FlashCardsCore appDelegate] syncController] setSyncIsRunningFromBackground:YES];
    [[[FlashCardsCore appDelegate] syncController] setCompletionHandler:completionHandler];
    [FlashCardsCore sync];
}

#pragma mark -
#pragma mark Backup/Restore methods

- (DBRestClient*)restClient {
    if (!restClient) {
        restClient = [[DBRestClient alloc] initWithSession:[DBSession sharedSession]];
        restClient.delegate = self;
    }
    return restClient;
}

- (void)backupWithFileName:(NSString*)uploadFileName withDelegate:(UIViewController*)theDelegate andHUD:(MBProgressHUD*)HUD andProgressView:(UIProgressView*)progressView {
    backupProgressView = progressView;
    backupHUD = HUD;
    backupActionDelegate = theDelegate;
    backupFileName = uploadFileName;
    
    backupProgressView.progress = 0.0;
    NSString *storePath = [[FlashCardsCore documentsDirectory] stringByAppendingPathComponent: @"FlashCards.sqlite"];
    self.taskIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:self.taskIdentifier];
        self.taskIdentifier = UIBackgroundTaskInvalid;
    }];

    backupUploadErrorCount = 0;
    [[self restClient] uploadFileChunk:nil
                                offset:0
                              fromPath:storePath];
}

-(void)loadRestoreFile {
    // set up the file:
    [self setShouldCancelTICoreDataSyncIdCreation:YES];
    [self setCoredataIsCorrupted:NO];
    
    NSString *tempStorePath = [[FlashCardsCore documentsDirectory] stringByAppendingPathComponent: @"FlashCards-Temp.sqlite"];
    NSString *realStorePath = [[FlashCardsCore documentsDirectory] stringByAppendingPathComponent: @"FlashCards.sqlite"];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:tempStorePath]) {
        [fileManager removeItemAtPath:realStorePath error:NULL];
        [fileManager copyItemAtPath:tempStorePath toPath:realStorePath error:NULL];
    } else {
        NSLog(@"Oops, it looks like the temp file doesn't exist.");
    }
    [self reloadDatabase:@YES]; // @YES = loading restore
}

- (void)reloadDatabase:(NSNumber*)_isLoadingRestoreData {
    @autoreleasepool {
        BOOL isLoadingRestoreData = [_isLoadingRestoreData boolValue];
        // set managedObjectContext to NIL to force the app to migrate the data if necessary.
        self.mainMOC = nil;
        self.writerMOC = nil;
        self.persistentStoreCoordinator = nil;
        self.managedObjectModel = nil;
        
        [FlashCardsCore setSetting:@"lastSyncAllData" value:[NSDate date]];
        
        RootViewController *rootViewController = [[RootViewController alloc]  initWithNibName:@"RootViewController" bundle:nil];
        rootViewController.createDefaultData = NO;
        rootViewController.checkMasterCardSets = YES;
        rootViewController.isLoadingRestoreData = isLoadingRestoreData;
        rootViewController.isFirstLoad = YES;
        
        NSMutableArray *viewControllers = [[NSMutableArray alloc] initWithArray:[self.navigationController viewControllers]];
        [viewControllers removeAllObjects];
        [viewControllers addObject:rootViewController];
        [self.navigationController setViewControllers:viewControllers animated:YES];
    }
}


// as per: http://stackoverflow.com/questions/13776630/using-ios-dropbox-sdk-to-do-a-chunked-upload-of-core-data
- (void)restClient:(DBRestClient *)client uploadedFileChunk:(NSString *)uploadId newOffset:(unsigned long long)offset fromFile:(NSString *)localPath expires:(NSDate *)expiresDate {
    NSString *storePath = [[FlashCardsCore documentsDirectory] stringByAppendingPathComponent: @"FlashCards.sqlite"];
    unsigned long long fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:localPath error:nil] fileSize];
    
    if (offset >= fileSize) {
        //Upload complete, commit the file.
        NSString *backupFilePath = (NSString*)[FlashCardsCore getSetting:@"dropboxBackupFilePath"];
        [[self restClient] uploadFile:backupFileName
                               toPath:backupFilePath
                        withParentRev:nil
                         fromUploadId:uploadId];
    } else {
        //Send the next chunk and update the progress HUD.
        float progress = (float)((float)offset / (float)fileSize);
        if (self.backupProgressView) {
            backupProgressView.progress = progress;
        }
        if (self.backupHUD) {
            [backupHUD setLabelText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Uploaded: %1.1f%%", @"Backup", @""), (progress*100.0)]];
        }
        [self.restClient uploadFileChunk:uploadId
                                  offset:offset
                                fromPath:storePath];
    }
}

- (void)restClient:(DBRestClient *)client uploadFileChunkFailedWithError:(NSError *)error {
    self.backupUploadErrorCount++;
    if (error != nil && (self.backupUploadErrorCount < 10)) {
        NSString *storePath = [[FlashCardsCore documentsDirectory] stringByAppendingPathComponent: @"FlashCards.sqlite"];
        NSString* uploadId = [error.userInfo objectForKey:@"upload_id"];
        unsigned long long offset = [[error.userInfo objectForKey:@"offset"]unsignedLongLongValue];
        [self.restClient uploadFileChunk:uploadId
                                  offset:offset
                                fromPath:storePath];
    } else {
        //show an error message and cancel the process
        [self uploadFailed:error];
    }
}


- (void)restClient:(DBRestClient *)client uploadedFile:(NSString *)destPath fromUploadId:(NSString *)uploadId metadata:(DBMetadata *)metadata {
    NSLog(@"Uploaded Successfully!");
    [[UIApplication sharedApplication] endBackgroundTask:self.taskIdentifier];
    self.taskIdentifier = UIBackgroundTaskInvalid;
    
    if (backupActionDelegate && [backupActionDelegate respondsToSelector:@selector(backupFinishedSuccessfully)]) {
        [backupActionDelegate performSelector:@selector(backupFinishedSuccessfully)];
    }
    
    [FlashCardsCore setSetting:@"lastBackupDate" value:[NSDate date]];
    
    if (backupHUD) {
        [backupHUD hide:YES];
    }
    
    if (showAlertWhenBackupIsSuccessful) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@""
                                                         message:NSLocalizedStringFromTable(@"FlashCards++ has successfully backed up its database to Dropbox.", @"Backup", @"message")
                                                        delegate:nil
                                               cancelButtonTitle:NSLocalizedStringFromTable(@"OK", @"FlashCards", @"cancelButtonTitle")
                                               otherButtonTitles:nil];
        [alert show];
    }
    showAlertWhenBackupIsSuccessful = YES;
    
}

- (void)restClient:(DBRestClient *)client uploadProgress:(CGFloat)progress forFile:(NSString *)destPath from:(NSString *)srcPath {
    if (self.backupProgressView) {
        backupProgressView.progress = progress;
    }
    if (self.backupHUD) {
        [backupHUD setLabelText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Uploaded: %1.2f%%", @"Backup", @""), (progress*100.0)]];
    }
}

- (void)restClient:(DBRestClient*)client uploadFileFailedWithError:(NSError*)error {
    [self uploadFailed:error];
}

- (void)uploadFailed:(NSError*)error {
    if (self.backupHUD) {
        [backupHUD hide:YES];
    }
    NSLog(@"Upload Failed!");
    [[UIApplication sharedApplication] endBackgroundTask:self.taskIdentifier];
    self.taskIdentifier = UIBackgroundTaskInvalid;
    
    if (backupActionDelegate && [backupActionDelegate respondsToSelector:@selector(backupFailed)]) {
        [backupActionDelegate performSelector:@selector(backupFailed)];
    }
    
    if (error.code == -1009 && error.domain == NSURLErrorDomain) {
        FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"Error", @"Error", @"UIAlert title"),
                                   NSLocalizedStringFromTable(@"You are not connected to the internet.", @"Error", @"message"));
        return;
    }
    
    FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"Error", @"Error", @"UIAlert title"),
                               [NSString stringWithFormat:NSLocalizedStringFromTable(@"Error: %@ (%@)", @"Error", @"message"), error, [error userInfo]]);
}

#pragma mark - Reachability
- (void)reachabilityChanged:(NSNotification*)note {
    Reachability* r = [note object];
    NetworkStatus ns = r.currentReachabilityStatus;
    
    if (ns == NotReachable) {
        // not connected to the internet. Need to stop sync if necessary:
        if (!syncController) {
            return;
        }
        if (syncController.isCurrentlySyncing) {
            FCDisplayBasicErrorMessage(@"",
                                       NSLocalizedStringFromTable(@"You have lost internet connectivity. Sync was canceled.", @"Error", @""));
            [syncController cancel];
        }
        
    }
    
}

#pragma mark -
#pragma mark Core Data stack

/**
 Returns the managed object model for the application.
 If the model doesn't already exist, it is created by merging all of the models found in the application bundle.
 */
- (NSManagedObjectModel *)managedObjectModel {
    
    if (managedObjectModel != nil) {
        return managedObjectModel;
    }
    managedObjectModel = [NSManagedObjectModel mergedModelFromBundles:nil];    
    return managedObjectModel;
}

- (void)createManagedObjectModel {
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
        writerMOC = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        [writerMOC setPersistentStoreCoordinator:coordinator];
        [writerMOC setUndoManager:nil];
        
        // create main thread MOC
        mainMOC = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        mainMOC.parentContext = writerMOC;
        mainMOC.undoManager = nil;
    }
}

- (BOOL)coreDataStoreIsUpToDateAtUrl:(NSURL*)sourceStoreURL
                              ofType:(NSString*)type 
                             toModel:(NSManagedObjectModel*)finalModel 
                               error:(NSError**)error
{
    NSDictionary *sourceMetadata = 
    [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:type
                                                               URL:sourceStoreURL
                                                             error:error];
    if (!sourceMetadata) return NO;
    
    if ([finalModel isConfiguration:nil 
        compatibleWithStoreMetadata:sourceMetadata]) {
        *error = nil;
        return YES;
    }
    return NO;
}

/**
 Returns the persistent store coordinator for the application.
 If the coordinator doesn't already exist, it is created and the application's store added to it.
 */
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    return [self persistentStoreCoordinatorWithRebuild:NO];
}
- (NSPersistentStoreCoordinator *)persistentStoreCoordinatorWithRebuild:(BOOL)isRebuild {
    if (persistentStoreCoordinator != nil) {
        return persistentStoreCoordinator;
    }
    return [self reloadPersistentStoreCoordinator:isRebuild];
}
- (NSPersistentStoreCoordinator*)reloadPersistentStoreCoordinator:(BOOL)isRebuild {
    if (coredataIsCorrupted) {
        persistentStoreCoordinator = nil;
        return nil;
    }
    // auto-create default data store if we are starting from scratch
    // based upon http://www.raywenderlich.com/980/core-data-tutorial-how-to-preloadimport-existing-data
    NSString *storePath = [[FlashCardsCore documentsDirectory] stringByAppendingPathComponent: @"FlashCards.sqlite"];
    
    NSURL *storeUrl = [NSURL fileURLWithPath: storePath];
    NSError *error = nil;

    NSMutableDictionary *options = [NSMutableDictionary dictionaryWithCapacity:0];
    [options setValue:@YES forKey:NSMigratePersistentStoresAutomaticallyOption];
    [options setValue:@YES forKey:NSInferMappingModelAutomaticallyOption];
    if (![DTVersion osVersionIsLessThen:@"7.0"]) {
        NSDictionary *journalingOptions = [NSDictionary dictionaryWithObject:@"DELETE" forKey:@"journal_mode"];
        [options setValue:journalingOptions forKey:NSSQLitePragmasOption];
    }
    if (isRebuild) {
        [options setObject:[NSNumber numberWithBool:YES] forKey:NSSQLiteManualVacuumOption];
        [options setObject:[NSNumber numberWithBool:YES] forKey:NSSQLiteAnalyzeOption];
    }

    persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
        
    if (![persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                  configuration:nil
                                                            URL:storeUrl
                                                        options:options
                                                          error:&error]) {
        RIButtonItem *cancelItem = [RIButtonItem item];
        cancelItem.label = NSLocalizedStringFromTable(@"Quit", @"FlashCards", @"");
        cancelItem.action = ^{
            exit(1);
        };
        
        RIButtonItem *originalItem = [RIButtonItem item];
        originalItem.label = NSLocalizedStringFromTable(@"Restore Original Database", @"FlashCards", @"");
        originalItem.action = ^{
            [FlashCardsCore setSetting:@"appIsSyncing" value:@NO];
            self.coredataIsCorrupted = NO;

            NSString *storePath = [[FlashCardsCore documentsDirectory] stringByAppendingPathComponent: @"FlashCards.sqlite"];
            NSFileManager *fileManager = [NSFileManager defaultManager];
            [fileManager removeItemAtPath:storePath error:nil];
            [self createCoreDataStoreIfNotExists];
            [self reloadDatabase:@NO];
        };
        
        RIButtonItem *backupItem = [RIButtonItem item];
        backupItem.label = NSLocalizedStringFromTable(@"Load Backup File", @"Backup", @"");
        backupItem.action = ^{
            // dispatch_sync(dispatch_get_main_queue(), ^{
                NSArray *vcs;
                if ([[DBSession sharedSession] isLinked]) {
                    BackupRestoreListFilesViewController *vc = [[BackupRestoreListFilesViewController alloc] initWithNibName:@"BackupRestoreListFilesViewController" bundle:nil];
                    vcs = @[vc];
                } else {
                    BackupRestoreViewController *vc = [[BackupRestoreViewController alloc] initWithNibName:@"BackupRestoreViewController" bundle:nil];
                    vcs = @[vc];
                }
                [self.navigationController setViewControllers:vcs animated:YES];
            // });
        };
        

        dispatch_sync(dispatch_get_main_queue(), ^{
            NSString *message = [NSString stringWithFormat:@"Error establishing persistent store coordinator: %@, %@", error, [error userInfo] ];
            NSString *userMessage =
            [NSString stringWithFormat:NSLocalizedStringFromTable(@"It appears that your FlashCards++ database has been corrupted. You can load a previous backup, reset your data to the initial install, or quit the app.\n\n%@", @"Error", @""),
             message];
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@""
                                                            message:userMessage
                                                   cancelButtonItem:cancelItem
                                                   otherButtonItems:backupItem, originalItem, nil];
            [alert show];
        });
        persistentStoreCoordinator = nil;
        coredataIsCorrupted = YES;

        return nil;
    }
    
    coredataIsCorrupted = NO;
    
    return persistentStoreCoordinator;
}


- (void)createCoreDataStoreIfNotExists {
    // auto-create default data store if we are starting from scratch
    // based upon http://www.raywenderlich.com/980/core-data-tutorial-how-to-preloadimport-existing-data
    NSString *storePath = [[FlashCardsCore documentsDirectory] stringByAppendingPathComponent: @"FlashCards.sqlite"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:storePath]) {
        NSString *defaultStorePath = [[NSBundle mainBundle]  pathForResource:@"FlashCards-DefaultData" ofType:@"sqlite"];
        if (defaultStorePath) {
            createDefaultData = YES;
            [fileManager copyItemAtPath:defaultStorePath toPath:storePath error:NULL];
        }
    }
}

#pragma mark -
#pragma mark TICoreDataSync methods

// only runs if the user has a subscription
- (void)setupSyncInterface {
    if ([FlashCardsCore isLoggedIn]) {
        // check to see if the sync data has already been uploaded
        UIViewController *vc = [FlashCardsCore currentViewController];
        MBProgressHUD *HUD = [FlashCardsCore currentHUD:@"syncHUD"];
        if (!HUD && [vc respondsToSelector:@selector(createSyncHUD)]) {
            [vc performSelectorOnMainThread:@selector(createSyncHUD) withObject:nil waitUntilDone:YES];
            HUD = [vc valueForKey:@"syncHUD"];
        }
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/user/check", flashcardsServer]];
        ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
        __block ASIFormDataRequest *requestBlock = request;
        [request setupFlashCardsAuthentication:@"user/check"];
        [request addPostValue:[FlashCardsCore getSetting:@"fcppUsername"] forKey:@"email"];
        [request addPostValue:[FlashCardsCore getSetting:@"fcppLoginKey"] forKey:@"login_key"];
        [request addPostValue:[[UIDevice currentDevice] uniqueDeviceIdentifier] forKey:@"device_id"];
        [request addPostValue:[[UIDevice currentDevice] advertisingIdentifier] forKey:@"device_adid"];
        
        NSString *callKey = [FlashCardsCore randomStringOfLength:20];
        FCLog(@"Call Key: %@", callKey);
        
        [request addPostValue:[callKey encryptWithKey:flashcardsServerCallKeyEncryptionKey] forKey:@"call"];
        
        [request setCompletionBlock:^{
            MBProgressHUD *HUD = [FlashCardsCore currentHUD:@"syncHUD"];
            if (HUD) {
                [HUD hide:YES];
            }
            
            FCLog(@"%@", requestBlock.responseString);
            NSDictionary *response = [requestBlock.responseData objectFromJSONData];
            
            BOOL sync_created = [(NSNumber*)[response objectForKey:@"sync_created"] boolValue];
            [FlashCardsCore presentSyncOptions:sync_created];
        }];
        [request startAsynchronous];
    } else {
        // send them to sign up with a username:
        AppLoginViewController *vc = [[AppLoginViewController alloc] initWithNibName:@"AppLoginViewController" bundle:nil];
        vc.isCreatingNewAccount = YES;
        [self.navigationController pushViewController:vc animated:YES];
    }
}

- (void)setupSyncWorker {
    @autoreleasepool {
        [self.syncController setDownloadStoreAfterRegistering:NO];
        [self.syncController setIsCurrentlyUploading:YES];
        [self.syncController setIsCurrentlyUploadingForFirstTime:YES];
        
        UIViewController *vc = [FlashCardsCore currentViewController];
        MBProgressHUD *HUD;
        if ([vc respondsToSelector:@selector(syncHUD)]) {
            HUD = [vc valueForKey:@"syncHUD"];
            if (!HUD && [vc respondsToSelector:@selector(createSyncHUD)]) {
                [vc performSelectorOnMainThread:@selector(createSyncHUD) withObject:nil waitUntilDone:YES];
                HUD = [vc valueForKey:@"syncHUD"];
            }
        }
        if (!HUD) {
            HUD = [FlashCardsCore currentHUD:@"syncHUD"];
        }
        
        BOOL fixSyncIdsDidFinish = [FlashCardsCore getSettingBool:@"fixSyncIdsDidFinish"];
        if (!fixSyncIdsDidFinish) {
            if (HUD) {
                [HUD performSelectorOnMainThread:@selector(setLabelText:)
                                      withObject:NSLocalizedStringFromTable(@"Preparing to Sync", @"Sync", @"HUD")
                                   waitUntilDone:NO];
                [HUD performSelectorOnMainThread:@selector(setDetailsLabelText:)
                                      withObject:NSLocalizedStringFromTable(@"Tap to Cancel", @"Import", @"HUD")
                                   waitUntilDone:NO];
            }
            [[FlashCardsCore appDelegate] setShouldCancelTICoreDataSyncIdCreation:YES];
            sleep(1);
            [TICDSWholeStoreUploadOperation fixSyncIdsAnd:@selector(setupSyncWorkerPart2) withDelegate:self onMainThread:NO];
        } else {
            [self setupSyncWorkerPart2];
        }
    }
}
- (void)setupSyncWorkerPart2 {
    MBProgressHUD *HUD = [FlashCardsCore currentHUD:@"syncHUD"];
    if (HUD) {
        [HUD performSelectorOnMainThread:@selector(setLabelText:)
                              withObject:NSLocalizedStringFromTable(@"Replacing Sync Data", @"Sync", @"HUD")
                           waitUntilDone:NO];
        [HUD performSelectorOnMainThread:@selector(setDetailsLabelText:)
                              withObject:NSLocalizedStringFromTable(@"Tap to Cancel", @"Import", @"HUD")
                           waitUntilDone:NO];
    }
    
    SyncController *controller = [[FlashCardsCore appDelegate] syncController];
    [controller setUploadStoreAfterRegistering:YES];
    [controller setDownloadStoreAfterRegistering:NO];
    [controller setIsCurrentlyUploading:YES];
    [controller setIsCurrentlyUploadingForFirstTime:YES];
    
    TICDSWebServerBasedApplicationSyncManager *aSyncManager = [TICDSWebServerBasedApplicationSyncManager defaultApplicationSyncManager];
    NSString *clientUuid = [[NSUserDefaults standardUserDefaults]
                            stringForKey:@"SyncClientUUID"];
    if(!clientUuid) {
        clientUuid = [TICDSUtilities uuidString];
    }
    NSString *deviceDescription = [[UIDevice currentDevice] name];
    [aSyncManager registerWithDelegate:nil
                   globalAppIdentifier:@"com.iPhoneFlashCards.FlashCards"
                uniqueClientIdentifier:clientUuid
                           description:deviceDescription
                              userInfo:nil];
    
    TICDSWebServerBasedDocumentSyncManager *docSyncManager = [[TICDSWebServerBasedDocumentSyncManager alloc] init];
    [docSyncManager registerWithDelegate:nil
                          appSyncManager:aSyncManager
                    managedObjectContext:[FlashCardsCore writerMOC]
                      documentIdentifier:@"FlashCards"
                             description:@"Application's data"
                                userInfo:nil];
    [docSyncManager performSelectorInBackground:@selector(removeHelperFileDirectory:) withObject:nil];
    
    UIViewController *vc = [FlashCardsCore currentViewController];
    if ([vc respondsToSelector:@selector(syncHUD)]) {
        HUD = [vc valueForKey:@"syncHUD"];
        if (!HUD && [vc respondsToSelector:@selector(createSyncHUD)]) {
            [vc performSelectorOnMainThread:@selector(createSyncHUD) withObject:nil waitUntilDone:YES];
        }
        HUD = [FlashCardsCore currentHUD:@"syncHUD"];
    }
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/clear", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    [request addPostValue:[FlashCardsCore getSetting:@"fcppUsername"] forKey:@"email"];
    [request addPostValue:[FlashCardsCore getSetting:@"fcppLoginKey"] forKey:@"login_key"];
    [request setShouldContinueWhenAppEntersBackground:YES];
    [request setShouldAttemptPersistentConnection:YES];
    [request setDelegate:nil];
    [request setCompletionBlock:^{
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/updatesyncdates", flashcardsServer]];
        ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
        [request prepareCoreDataSyncRequest];
        NSDate *lastSyncDate;
        lastSyncDate = [FlashCardsCore getSettingDate:@"flashcardExchangeLastSyncAllData"];
        if (lastSyncDate) {
            [request addPostValue:[NSNumber numberWithInt:[lastSyncDate timeIntervalSince1970]]
                           forKey:@"flashcardExchange"];
        } else {
            [request addPostValue:[NSNumber numberWithInt:0]
                           forKey:@"flashcardExchange"];
        }
        lastSyncDate = [FlashCardsCore getSettingDate:@"quizletLastSyncAllData"];
        if (lastSyncDate) {
            [request addPostValue:[NSNumber numberWithInt:[lastSyncDate timeIntervalSince1970]]
                           forKey:@"quizlet"];
        } else {
            [request addPostValue:[NSNumber numberWithInt:0]
                           forKey:@"quizlet"];
        }
        [request setCompletionBlock:^{
            SyncController *controller = [[FlashCardsCore appDelegate] syncController];
            [controller setUploadStoreAfterRegistering:YES];
            [controller setDownloadStoreAfterRegistering:NO];
            [controller setIsCurrentlyUploading:YES];
            [controller setIsCurrentlyUploadingForFirstTime:YES];
            [FlashCardsCore syncSetup];
        }];
        [request setFailedBlock:^{
            MBProgressHUD *sHUD = [FlashCardsCore currentHUD:@"syncHUD"];
            if (sHUD) {
                [sHUD hide:YES];
            }
            FCDisplayBasicErrorMessage(@"",
                                       @"Sync setup failed");
        }];
        [request startAsynchronous];
    }];
    [request startAsynchronous];
}

- (void)preconfigureSyncManager {
    
    TICDSWebServerBasedApplicationSyncManager *manager = [TICDSWebServerBasedApplicationSyncManager defaultApplicationSyncManager];
    NSString *clientUuid = [[NSUserDefaults standardUserDefaults]
                            stringForKey:@"SyncClientUUID"];
    if(!clientUuid) {
        clientUuid = [TICDSUtilities uuidString];
        [[NSUserDefaults standardUserDefaults] setValue:clientUuid forKey:@"SyncClientUUID"];
    }
    NSString *deviceDescription = [[UIDevice currentDevice] name];
    [manager configureWithDelegate:self
              globalAppIdentifier:@"com.iPhoneFlashCards.FlashCards"
           uniqueClientIdentifier:clientUuid
                      description:deviceDescription
                         userInfo:nil];

    TICDSWebServerBasedDocumentSyncManager *docSyncManager = [[TICDSWebServerBasedDocumentSyncManager alloc] init];
    [docSyncManager configureWithDelegate:self.syncController
                           appSyncManager:[TICDSWebServerBasedApplicationSyncManager defaultApplicationSyncManager]
                     managedObjectContext:[FlashCardsCore mainMOC]
                       documentIdentifier:@"FlashCards"
                              description:@"Application's data"
                                 userInfo:nil];
    [self.syncController setDocumentSyncManager:docSyncManager];
    [docSyncManager setPrimaryDocumentMOC:self.mainMOC];
    [self.mainMOC setDocumentSyncManager:docSyncManager];

}

- (void)registerSyncManager {
    self.syncController.isCurrentlyRegisteringSyncManagers = YES;
    TICDSWebServerBasedApplicationSyncManager *manager = [TICDSWebServerBasedApplicationSyncManager defaultApplicationSyncManager];
    NSString *clientUuid = [[NSUserDefaults standardUserDefaults]
                            stringForKey:@"SyncClientUUID"];
    if(!clientUuid) {
        clientUuid = [TICDSUtilities uuidString];
        [[NSUserDefaults standardUserDefaults] setValue:clientUuid forKey:@"SyncClientUUID"];
    }
    NSString *deviceDescription = [[UIDevice currentDevice] name];
    [manager registerWithDelegate:self
              globalAppIdentifier:@"com.iPhoneFlashCards.FlashCards"
           uniqueClientIdentifier:clientUuid
                      description:deviceDescription
                         userInfo:nil];
}

- (void)applicationSyncManagerDidPauseRegistrationToAskWhetherToUseEncryptionForFirstTimeRegistration:(TICDSApplicationSyncManager *)aSyncManager {
    [aSyncManager continueRegisteringWithEncryptionPassword:nil];
}

- (void)applicationSyncManagerDidPauseRegistrationToRequestPasswordForEncryptedApplicationSyncData:(TICDSApplicationSyncManager *)aSyncManager {
    [aSyncManager continueRegisteringWithEncryptionPassword:nil];
}

- (TICDSDocumentSyncManager *)applicationSyncManager:(TICDSApplicationSyncManager *)aSyncManager preConfiguredDocumentSyncManagerForDownloadedDocumentWithIdentifier:(NSString *)anIdentifier atURL:(NSURL *)aFileURL {
    return nil;
}

- (void)applicationSyncManager:(TICDSApplicationSyncManager *)aSyncManager didFailToRegisterWithError:(NSError *)anError {
    self.syncController.isCurrentlyRegisteringSyncManagers = NO;
}

- (void)applicationSyncManagerDidFinishRegistering:(TICDSApplicationSyncManager *)aSyncManager {
    TICDSWebServerBasedDocumentSyncManager *docSyncManager = [[TICDSWebServerBasedDocumentSyncManager alloc] init];
    [docSyncManager registerWithDelegate:self.syncController
                          appSyncManager:aSyncManager
                    managedObjectContext:[FlashCardsCore mainMOC]
                      documentIdentifier:@"FlashCards"
                             description:@"Application's data"
                                userInfo:nil];
    [self.syncController setDocumentSyncManager:docSyncManager];
    [docSyncManager setPrimaryDocumentMOC:self.mainMOC];
    [self.mainMOC setDocumentSyncManager:docSyncManager];
    [self.mainMOC setSynchronized:YES];
}

// TODO: Update the HUD when the sync functions start saving

- (void)displayMesasge:(NSString *)message {
    FCDisplayBasicErrorMessage(@"Error", message);
}

# pragma mark - Compress & Optimize Database

- (void)compressAndSync {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[FlashCardsCore appDelegate] compressImagesAndPerformSelector:@selector(setupSyncWorker)
                                                            onDelegate:[FlashCardsCore appDelegate]
                                                            withObject:nil
                                                    inBackgroundThread:YES];
    });
}

- (void)compressImagesAndPerformSelector:(SEL)completionSelector onDelegate:(NSObject*)delegate withObject:(id)object inBackgroundThread:(BOOL)backgroundThread {
    @autoreleasepool {
        [self setShouldCancelTICoreDataSyncIdCreation:YES];
        // [[[FlashCardsCore appDelegate] syncController] cancel];
        // sleep(1);
        
        NSManagedObjectContext *threadMOC = [[NSManagedObjectContext alloc] init];
        [threadMOC setPersistentStoreCoordinator:[[FlashCardsCore mainMOC] persistentStoreCoordinator]];
        [threadMOC setMergePolicy:NSMergeByPropertyObjectTrumpMergePolicy];
        
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        [fetchRequest setEntity:[NSEntityDescription entityForName:@"Card" inManagedObjectContext:threadMOC]];
        [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"hasImages = YES"]];
        NSError *error;
        NSArray *cards = [threadMOC executeFetchRequest:fetchRequest error:&error];
        
        NSArray *cardsSplit = [cards splitIntoSubarraysOfMaxSize:50];
        for (NSArray *cardsList in cardsSplit) {
            @autoreleasepool {
                UIImage *image;
                NSData *imageData;
                
                int maxImageSize = 1000;
                float compression = 0.4;
                
                for (FCCard *card in cardsList) {
                    if (card.frontImageData && [card.frontImageData length] > 0) {
                        FCLog(@"Previous size: %d", [card.frontImageData length]);
                        int oldSize = (int)[card.frontImageData length];
                        image = [UIImage imageWithData:card.frontImageData];
                        if (image.size.height > maxImageSize || image.size.width > maxImageSize) {
                            image = [image imageToFitSize:CGSizeMake(maxImageSize, maxImageSize) method:MGImageResizeScale];
                        }
                        imageData = UIImageJPEGRepresentation(image, compression);
                        FCLog(@"New size: %d", [imageData length]);
                        int newSize = (int)[imageData length];
                        if (newSize < oldSize) {
                            [card setFrontImageData:imageData];
                        }
                    }
                    
                    if (card.backImageData && [card.backImageData length] > 0) {
                        FCLog(@"Previous size: %d", [card.backImageData length]);
                        int oldSize = (int)[card.backImageData length];
                        image = [UIImage imageWithData:card.backImageData];
                        FCLog(@"Dimensions: %1f x %1f", image.size.height, image.size.width);
                        if (image.size.height > maxImageSize || image.size.width > maxImageSize) {
                            image = [image imageToFitSize:CGSizeMake(maxImageSize, maxImageSize) method:MGImageResizeScale];
                            FCLog(@"New dimensions: %1f x %1f", image.size.height, image.size.width);
                        }
                        imageData = UIImageJPEGRepresentation(image, compression);
                        FCLog(@"New size: %d", [imageData length]);
                        int newSize = [imageData length];
                        if (newSize < oldSize) {
                            [card setBackImageData:imageData];
                        }
                    }
                }
                
                [threadMOC save:nil];
                [threadMOC reset];
            }
        }
        
        if (completionSelector != @selector(reloadDatabase:)) {
            FlashCardsAppDelegate *del = (FlashCardsAppDelegate*)[[UIApplication sharedApplication] delegate];
            FCLog(@"actuallySetupDataStore");
            [del reloadPersistentStoreCoordinator:YES]; // it is a rebuild
            [del createManagedObjectModel];
        }
        
        if (completionSelector && delegate && [delegate respondsToSelector:completionSelector]) {
            if (backgroundThread) {
                [delegate performSelectorInBackground:completionSelector withObject:object];
            } else {
                [delegate performSelectorOnMainThread:completionSelector withObject:object waitUntilDone:NO];
            }
        }
    }
}

#pragma mark -
#pragma mark Store Kit delegates
-(void)requestDidFinish:(SKRequest *)request {
    // [FlashCardsCore processGrandUnifiedReceipt];
}
-(void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    NSLog(@"%@", error);
    FCDisplayBasicErrorMessage(@"", NSLocalizedStringFromTable(@"iTunes App Store could not be reached.", @"errors", @""));
}

#pragma mark -
#pragma mark iAd delegate methods

-(void)interstitialAd:(ADInterstitialAd *)_interstitialAd didFailWithError:(NSError *)error {
    NSLog(@"%@", error);
}
-(void)interstitialAdDidUnload:(ADInterstitialAd *)_interstitialAd {
    _interstitialAd = nil;
    
    interstitialAd = [[ADInterstitialAd alloc] init];
    interstitialAd.delegate = self;
}

-(void)bannerViewDidLoadAd:(ADBannerView *)banner {
    NSString *bannerView;
    if ([banner isEqual:self.bannerAd]) {
        bannerView = @"Back";
    } else {
        bannerView = @"Front";
    }
    FCLog(@"%@ ad loaded", bannerView);
    
    UIViewController *currentVC = [FlashCardsCore currentViewController];
    if ([currentVC respondsToSelector:@selector(showBannerAd)]) {
        [currentVC performSelector:@selector(showBannerAd)];
    }
}

-(void)bannerView:(ADBannerView *)banner didFailToReceiveAdWithError:(NSError *)_error {
    NSString *bannerView;
    if ([banner isEqual:self.bannerAd]) {
        bannerView = @"Back";
    } else {
        bannerView = @"Front";
    }
    if (_error.code == ADErrorAdUnloaded) {
        FCLog(@"%@ ad unloaded", bannerView);
    } else {
        FCLog(@"banner error: %@", _error);
    }
    UIViewController *currentVC = [FlashCardsCore currentViewController];
    if ([currentVC respondsToSelector:@selector(hideBannerAd)]) {
        [currentVC performSelector:@selector(hideBannerAd)];
    }

}

-(BOOL)bannerViewActionShouldBegin:(ADBannerView *)banner
              willLeaveApplication:(BOOL)willLeave {
    FCLog(@"Banner view is beginning an ad action");
    // appLockedTimerBegin = [NSDate date];
    UIViewController *vc = [FlashCardsCore currentViewController];
    if (vc) {
        NSString *className = NSStringFromClass([vc class]);
        [Flurry logEvent:@"AdTapped" withParameters:@{@"UIViewController": className}];
    }
    return YES;
}

-(void)bannerViewActionDidFinish:(ADBannerView *)banner {
    
    FCLog(@"Banner view is finished");
    /*
    if ([studyController.cardList count] > 0 && studyController.currentCardIndex < [studyController.cardList count]) {
        CardTest *testCard = [studyController currentCard];
        [testCard markStudyPause:appLockedTimerBegin];
        appLockedTimerBegin = nil;
    }
    if (studyBrowseMode != studyBrowseModeManual && self.studyBrowseModePaused) {
        [self pausePlayAutoBrowse:nil];
    }
    */
}


@end

#endif

