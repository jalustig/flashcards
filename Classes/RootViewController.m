//
//  RootViewController.m
//  FlashCards
//
//  Created by Jason Lustig on 5/27/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import "FlashCardsAppDelegate.h"
#import "FlashCardsCore.h"

#import "RootViewController.h"
#import "CollectionCreateViewController.h"
#import "CollectionViewViewController.h"
#import "FAQViewController.h"
#import "SettingsStudyViewController.h"
#import "BackupRestoreViewController.h"
#import "BackupRestoreListFilesViewController.h"
#import "CardSetImportChoicesViewController.h"
#import "CardSetImportViewController.h"
#import "SubscriptionViewController.h"
#import "TeachersViewController.h"
#import "StudentViewController.h"

#import "FCCollection.h"
#import "FCCard.h"
#import "FCCardSet.h"

#import "FCMatrix.h"
#import "ASIFormDataRequest.h"
#import "Reachability.h"

#import "HelpConstants.h"
#import "HelpViewController.h"
#import "FeedbackViewController.h"
#import "JSONKit.h"
#import "InAppPurchaseManager.h"

#import "CardSetListViewController.h"
#import "CardSetViewViewController.h"
#import "CardSetImportChoicesViewController.h"
#import "QuizletMySetsViewController.h"
#import "QuizletMyGroupsViewController.h"
#import "QuizletSearchGroupsViewController.h"
#import "QuizletGroupSetsViewController.h"
#import "CardSetUploadToQuizletViewController.h"

#import "Appirater.h"

#import "sqlite3-new.h"
#import <MessageUI/MessageUI.h>
#import <Social/Social.h>
#import <Accounts/Accounts.h>

#import "TICoreDataSync.h"
#import "NSArray+SplitArray.h"

#import "NSString+Markdown.h"

#import "UIAlertView+Blocks.h"
#import "UIActionSheet+Blocks.h"
#import "ActionSheetStringPicker.h"

#import "SubscriptionCodeSetupControllerViewController.h"

#import "DTVersion.h"
#import "UIView+Layout.h"

@implementation RootViewController


@synthesize createDefaultData;
@synthesize checkMasterCardSets;
@synthesize cardsDueCountDict, isUpdatingData, isLoadingRestoreData;
@synthesize fileData, fileUrl;
@synthesize myTableView;
@synthesize collections;
@synthesize backupRestoreButton;
@synthesize settingsButton;
@synthesize teachersButton;
@synthesize sendFeedbackButton;
@synthesize bottomToolbar;
@synthesize importCardsButton;
@synthesize twitterButton;
@synthesize automaticallySyncButton;
@synthesize HUD;
@synthesize isAuthenticatingQuizlet, quizletAuthenticationCode;
@synthesize hasBegunGetImageIds;
@synthesize internetReach;
@synthesize isFirstLoad;
@synthesize isUpdatingCardsDueCount;
@synthesize hasPromptedCreateAccount;

#pragma mark -
#pragma mark View lifecycle

- (void)viewDidLoad {

    [super viewDidLoad];

    if (![DTVersion osVersionIsLessThen:@"7.0"]) {
        self.edgesForExtendedLayout= UIRectEdgeNone;
    }

    isUpdatingCardsDueCount = NO;
    
    NSString *firstVersion = [FlashCardsCore getSetting:@"firstVersionInstalled"];
        
    collections = [NSMutableArray arrayWithCapacity:0];
    
    [backupRestoreButton setAccessibilityLabel:NSLocalizedStringFromTable(@"Backup & Restore", @"Backup", @"UIBarButtonItem")];
    [backupRestoreButton setAccessibilityHint: NSLocalizedStringFromTable(@"Backup & Restore", @"Backup", @"UIBarButtonItem")];

    [twitterButton setTitle: NSLocalizedStringFromTable(@"Follow on Twitter", @"FlashCards", @"") forState:UIControlStateNormal];
    [twitterButton setTitle: NSLocalizedStringFromTable(@"Follow on Twitter", @"FlashCards", @"") forState:UIControlStateSelected];
    
    [teachersButton setTitle: NSLocalizedStringFromTable(@"Students & Teachers", @"Help", @"") forState:UIControlStateNormal];
    [teachersButton setTitle: NSLocalizedStringFromTable(@"Students & Teachers", @"Help", @"") forState:UIControlStateSelected];
    
    [settingsButton setAccessibilityLabel:NSLocalizedStringFromTable(@"Settings", @"Settings", @"UIView title")];
    [settingsButton setAccessibilityHint: NSLocalizedStringFromTable(@"Settings", @"Settings", @"UIView title")];

    [importCardsButton setTitle:NSLocalizedStringFromTable(@"Import Cards", @"CardManagement", @"UIButton") forState:UIControlStateNormal]; 
    [importCardsButton setTitle:NSLocalizedStringFromTable(@"Import Cards", @"CardManagement", @"UIButton") forState:UIControlStateSelected];

    NSString *message;
    if ([FlashCardsCore getSettingBool:@"hasEverHadASubscription"] && ![FlashCardsCore hasSubscription]) {
        message = NSLocalizedStringFromTable(@"Renew Subscription", @"Settings", @"");
    } else {
        NSString *messageFormat = NSLocalizedStringFromTable(@"Automatically Sync With %@", @"Sync", @"UIButton");
        NSString *currentDevice = [FlashCardsCore deviceName];
        NSString *syncDevice;
        if ([currentDevice isEqualToString:@"iPad"]) {
            syncDevice = @"iPhone";
        } else {
            syncDevice = @"iPad";
        }
        message = [NSString stringWithFormat:messageFormat, syncDevice];
    }
    
    [automaticallySyncButton setTitle:message forState:UIControlStateNormal];
    [automaticallySyncButton setTitle:message forState:UIControlStateSelected];

    [sendFeedbackButton setTitle:NSLocalizedStringFromTable(@"Send Feedback", @"Feedback", @"UIButton") forState:UIControlStateNormal];
    [sendFeedbackButton setTitle:NSLocalizedStringFromTable(@"Send Feedback", @"Feedback", @"UIButton") forState:UIControlStateSelected];

    cardsDueCountDict = [[NSMutableDictionary alloc] initWithCapacity:0];

    isUpdatingData = NO;

    self.myTableView.tableFooterView.hidden = YES;
    
    self.title = NSLocalizedStringFromTable(@"FlashCards++", @"FlashCards", @"Title of app");
    
    hasBegunGetImageIds = NO;

    UIBarButtonItem *helpButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedStringFromTable(@"Help", @"Help", @"UIBarButtonItem")
                                                                   style:UIBarButtonItemStyleBordered
                                                                  target:self
                                                                  action:@selector(showActionSheet:)];
    helpButton.enabled = YES;
    self.navigationItem.leftBarButtonItem = helpButton;    
    
    NSMutableArray *rightBarButtonItems = [[NSMutableArray alloc] initWithCapacity:0];

    UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addEvent)];
    addButton.enabled = YES;
    [rightBarButtonItems addObject:addButton];

    UIBarButtonItem *editButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(editEvent)];
    editButton.enabled = YES;
    [rightBarButtonItems addObject:editButton];
    
    [self.navigationItem setRightBarButtonItems:rightBarButtonItems];
    
    internetReach = [Reachability reachabilityForInternetConnection];
    [internetReach startNotifier];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reachabilityChanged:)
                                                 name:kReachabilityChangedNotification
                                               object:nil];

    [self checkUrl];
}

- (void)checkAddSyncButton {
    NSMutableArray *rightBarButtonItems = [[NSMutableArray alloc] initWithArray:self.navigationItem.rightBarButtonItems];
    if ([rightBarButtonItems count] == 3) {
        [rightBarButtonItems removeLastObject];
    }
    if ([[[FlashCardsCore appDelegate] syncController] canPotentiallySync]) {
        UIBarButtonItem *syncButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                                    target:self
                                                                                    action:@selector(syncEvent)];
        syncButton.enabled = YES;
        [rightBarButtonItems addObject:syncButton];
        if (!hasBegunGetImageIds) {
            hasBegunGetImageIds = YES;
            [[[FlashCardsCore appDelegate] syncController] getImageIds];
        }
    }
    [self.navigationItem setRightBarButtonItems:rightBarButtonItems];
    [self checkAutomaticallySyncButton];
    [self checkTwitterButton];
}

- (void)checkAutomaticallySyncButton {
    // show the "automatically sync" button (but as "Renew Subscription") if you
    // once had a subscription but don't now.
    if ([FlashCardsCore getSettingBool:@"hasEverHadASubscription"] && ![FlashCardsCore hasSubscription]) {
        return;
    }
    if ([FlashCardsCore getSettingBool:@"appIsSyncing"] || ![FlashCardsCore getSettingBool:@"shouldShowSyncButton"]) {
        [automaticallySyncButton setHidden:YES];
        if (sendFeedbackButton.center.y != automaticallySyncButton.center.y) {
            [twitterButton setCenter:CGPointMake(teachersButton.center.x,
                                                 teachersButton.center.y)];
            [teachersButton setCenter:CGPointMake(sendFeedbackButton.center.x,
                                                  sendFeedbackButton.center.y)];
        }
        [sendFeedbackButton setCenter:CGPointMake(automaticallySyncButton.center.x,
                                                  automaticallySyncButton.center.y)];
    }
    
    if (![FlashCardsCore getSettingBool:@"showForTeachersButton"]) {
        [teachersButton setHidden:YES];
    }

}

- (void)checkTwitterButton {
    // only show twitter button if the user has Twitter:
    if (![self canUseTwitter]) {
        twitterButton.hidden = YES;
        return;
    }
    
    // see if the user is already a follower:
    if ([FlashCardsCore getSettingBool:@"hasFollowedOnTwitter"]) {
        twitterButton.hidden = YES;
        return;
    }
    
    twitterButton.hidden = NO;
}

- (void)checkUrl {
    
    if (fileUrl) {
        NSData *data = [NSData dataWithContentsOfURL:fileUrl];
        NSString *fileName = [fileUrl lastPathComponent];
        NSArray *fileComponents = [fileName componentsSeparatedByString:@"."];
        NSString *extension = [[fileComponents lastObject] lowercaseString];
        if ([extension isEqualToString:@"fcpp"]) {
            // it's a native file:
            fileData = [NSKeyedUnarchiver unarchiveObjectWithData:data];
            [self processFileData];
        } else {
            // it's a spreadsheet:
            
            HUD = [[MBProgressHUD alloc] initWithView:self.view];
            
            // Add HUD to screen
            [self.view addSubview:HUD];
            
            // Regisete for HUD callbacks so we can remove it from the window at the right time
            HUD.delegate = self;
            HUD.minShowTime = 2.0;
            HUD.labelText = NSLocalizedStringFromTable(@"Processing File", @"Import", @"HUD");
            [HUD show:YES];
            
            ImportCSV *csv = [[ImportCSV alloc] init];
            [csv setDelegate:self];
            
            NSString *localFilePath = [[FlashCardsCore documentsDirectory] stringByAppendingPathComponent:[NSString stringWithFormat:@"temp.%@", extension]];
            [data writeToFile:localFilePath atomically:YES];
            [csv setLocalFilePath:localFilePath];
            [csv setDropboxFilePath:localFilePath];
            [csv processLocalFile];
        }
    }

}

- (void)loadBackupFile:(NSURL *)_fileUrl {
    
    if (![FlashCardsCore hasFeature:@"Backup"]) {
        [FlashCardsCore showPurchasePopup:@"Backup"];
        return;
    }

    NSData *data = [NSData dataWithContentsOfURL:_fileUrl];
    NSString *fileName = [_fileUrl lastPathComponent];
    NSArray *fileComponents = [fileName componentsSeparatedByString:@"."];
    NSString *extension = [[fileComponents lastObject] lowercaseString];
    if ([extension isEqualToString:@"sqlite"]) {
        [[[FlashCardsCore appDelegate] syncController] cancel];
        [[FlashCardsCore appDelegate] setShouldCancelTICoreDataSyncIdCreation:YES];

        NSString *tempStorePath = [[FlashCardsCore documentsDirectory] stringByAppendingPathComponent: @"FlashCards-Temp.sqlite"];
        /* Loads the file contents at the given root/path and stores the result into destinationPath */
        [data writeToFile:tempStorePath atomically:NO];
        // ask if the user wants to restore the backup file:
        
        UIAlertView *alert;
        if ([[DBSession sharedSession] isLinked]) {
            alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Load Backup File", @"Backup", @"")
                                                message:NSLocalizedStringFromTable(@"Are you sure you want to load this backup file? It will overwrite ALL of your current FlashCards++ data.", @"Backup", @"")
                                               delegate:self
                                      cancelButtonTitle:NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"")
                                      otherButtonTitles:NSLocalizedStringFromTable(@"Load File Now", @"Backup", @""), NSLocalizedStringFromTable(@"Make A Backup First", @"Backup", @""), nil];
            [alert show];
        } else {
            alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Load Backup File", @"Backup", @"")
                                                message:NSLocalizedStringFromTable(@"Are you sure you want to load this backup file? It will overwrite ALL of your current FlashCards++ data.", @"Backup", @"")
                                               delegate:self
                                      cancelButtonTitle:NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"")
                                      otherButtonTitles:NSLocalizedStringFromTable(@"Load File Now", @"Backup", @""), nil];
            [alert show];
        }
    }
}

- (void)loadBackupFileAction {
    [FlashCardsCore setSetting:@"fixSyncIdsDidFinish" value:@NO];
    [[FlashCardsCore appDelegate] setShouldCancelTICoreDataSyncIdCreation:NO];
    
    HUD = [[MBProgressHUD alloc] initWithView:self.view];

    // Add HUD to screen
    [self.view addSubview:HUD];
    
    // Regisete for HUD callbacks so we can remove it from the window at the right time
    HUD.delegate = self;
    HUD.minShowTime = 2.0;
    HUD.labelText = NSLocalizedStringFromTable(@"Processing File", @"Import", @"HUD");
    [HUD show:YES];
    
    FlashCardsAppDelegate *appDelegate = (FlashCardsAppDelegate *)[[UIApplication sharedApplication] delegate];
    [appDelegate loadRestoreFile];

}

- (void)saveCurrentBackupAction {
    HUD = [[MBProgressHUD alloc] initWithView:self.view];

    // Add HUD to screen
    [self.view addSubview:HUD];
    
    // Regisete for HUD callbacks so we can remove it from the window at the right time
    HUD.delegate = self;
    HUD.minShowTime = 2.0;
    HUD.labelText = NSLocalizedStringFromTable(@"Processing File", @"Import", @"HUD");
    [HUD show:YES];
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd 'at' HH:mm"];
    NSString *uploadFileName = [NSString stringWithFormat:@"%@.sqlite", [dateFormatter stringFromDate:[NSDate date]]];

    FlashCardsAppDelegate *appDelegate = (FlashCardsAppDelegate *)[[UIApplication sharedApplication] delegate];
    appDelegate.showAlertWhenBackupIsSuccessful = NO;
    [appDelegate backupWithFileName:uploadFileName withDelegate:self andHUD:self.HUD andProgressView:nil];

}

# pragma mark -
# pragma mark DBRestClientDelegate functions - uploading

- (void)backupFinishedSuccessfully {
    // add the new item:
    [self loadBackupFileAction];
}

- (void)backupFailed {
    FCDisplayBasicErrorMessage(@"Error", @"Error uploading backup file.");
}


- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [self setTableShouldScroll];
    
    if ([FlashCardsCore mainMOC]) {
        [self performSelectorOnMainThread:@selector(loadDataFromStore) withObject:nil waitUntilDone:YES];
        BOOL fixSyncIdsDidFinish = [FlashCardsCore getSettingBool:@"fixSyncIdsDidFinish"];
        if (!fixSyncIdsDidFinish && ![[FlashCardsCore appDelegate] isCurrentlyFixingTICoreDataSyncIds]) {
            [self performSelectorInBackground:@selector(fixSyncIds) withObject:nil];
        }
    } else {
        self.myTableView.tableFooterView.hidden = YES;
        [self performSelector:@selector(setupDataStore) withObject:nil afterDelay:0.5];
    }

    BOOL isLoggedIntoQuizlet = [(NSNumber*)[FlashCardsCore getSetting:@"quizletIsLoggedIn"] boolValue];
    if (isAuthenticatingQuizlet && !isLoggedIntoQuizlet) {
        // we are authenticating quizlet, so run the appropriate functions:
        [self getQuizletAuthenticationToken];
    }
    
    if ([FlashCardsCore getSettingBool:@"hasEverHadASubscription"] && ![FlashCardsCore hasSubscription]) {
        NSString *message = NSLocalizedStringFromTable(@"Renew Subscription", @"Settings", @"");
        
        [automaticallySyncButton setTitle:message forState:UIControlStateNormal];
        [automaticallySyncButton setTitle:message forState:UIControlStateSelected];
    }
    [self showBannerAd];
}

- (void)showBannerAd {
    if (![FlashCardsCore hasFeature:@"HideAds"]) {
        ADBannerView *bannerAd = [[FlashCardsCore appDelegate] bannerAd];
        BOOL alreadyDisplayed = [[self.view subviews] containsObject:bannerAd];
        if (bannerAd.bannerLoaded) {
            if (!alreadyDisplayed) {
                if (UIInterfaceOrientationIsLandscape([self interfaceOrientation]) && [FlashCardsAppDelegate isIpad]) {
                    bannerAd.currentContentSizeIdentifier = ADBannerContentSizeIdentifierLandscape;
                } else {
                    bannerAd.currentContentSizeIdentifier = ADBannerContentSizeIdentifierPortrait;
                }
                
                [myTableView setPositionHeight:self.view.frame.size.height - bottomToolbar.frame.size.height - bannerAd.frame.size.height];
                [myTableView setPositionY:bannerAd.frame.size.height];
                [self.view addSubview:bannerAd];
                [bannerAd setPositionY:0];
            }
        }
    } else {
        ADBannerView *bannerAd = [[FlashCardsCore appDelegate] bannerAd];
        if (bannerAd) {
            BOOL alreadyDisplayed = [[self.view subviews] containsObject:bannerAd];
            if (alreadyDisplayed) {
                [bannerAd removeFromSuperview];
                [myTableView setPositionHeight:self.view.frame.size.height - bottomToolbar.frame.size.height];
                [myTableView setPositionY:0];
            }
        }
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if ([FlashCardsCore mainMOC]) {
        [self loadCollections];
        [self updateCardsDueCount];
        [self askToViewGettingStartedTour];
        [self checkAddSyncButton];
        if ([FlashCardsCore isConnectedToInternet]) {
            [[[FlashCardsCore appDelegate] inAppPurchaseManager] uploadAllQueuedTransactions];
        }
    }
    
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[[FlashCardsCore appDelegate] syncController] setDelegate:nil];
}
/*
 - (void)viewDidDisappear:(BOOL)animated {
 [super viewDidDisappear:animated];
 }
 */

- (BOOL)shouldAutorotate {
    UIInterfaceOrientation interfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    return [FlashCardsAppDelegate shouldAutorotate:interfaceOrientation];
}

# pragma mark -
# pragma mark Quizlet Authentication Functions

// the user has granted us quizlet access. Now, we need to get the token as per the second step:
- (void)getQuizletAuthenticationToken {
    
    // check if we have internet. If no internet, then cannot complete the authentication:
    if (![FlashCardsCore isConnectedToInternet]) {
        // give the user a notice
        FCDisplayBasicErrorMessage(@"",
                                   [NSString stringWithFormat:@"%@ %@",
                                    NSLocalizedStringFromTable(@"You are not connected to the internet.", @"Error", @""),
                                    NSLocalizedStringFromTable(@"Quizlet Authentication will only work with an active internet connection.", @"Error", @""), 
                                    nil]);
        return;
    }

    HUD = [[MBProgressHUD alloc] initWithView:self.view];
    // Add HUD to screen
    [self.view addSubview:HUD];
    // Regisete for HUD callbacks so we can remove it from the window at the right time
    HUD.delegate = self;
    HUD.minShowTime = 1.0;
    HUD.labelText = NSLocalizedStringFromTable(@"Completing Authentication", @"Import", @"HUD");
    [HUD show:YES];
    
    // execute the HTTPS request to get the token:
    NSString *urlstring = @"https://api.quizlet.com/oauth/token/";
    NSURL *url = [NSURL URLWithString:urlstring];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    [request setAuthenticationScheme:(NSString *)kCFHTTPAuthenticationSchemeBasic];
    [request setUsername:quizletApiKey];
    [request setPassword:quizletAuthenticationSecretKey];
    [request setPostValue:@"authorization_code" forKey:@"grant_type"];
    [request setPostValue:self.quizletAuthenticationCode forKey:@"code"];
    [request setPostValue:quizletApiRedirectUri forKey:@"redirect_uri"];
    [request setValidatesSecureCertificate:NO]; // as per: http://stackoverflow.com/questions/3430104/asihttprequest-authentification
    [request setUserInfo:[NSDictionary dictionaryWithObject:@"quizlet" forKey:@"website"]];
    [request setDelegate:self];
    [request startAsynchronous];
}

# pragma mark -

- (void)requestFinished:(ASIHTTPRequest *)request
{
    
    isAuthenticatingQuizlet = NO;
    NSString *website = [[request userInfo] objectForKey:@"website"];
    
    [HUD hide:YES];
    // Use when fetching text data
    NSString *responseString = [request responseString];
    FCLog(@"%@", responseString);
    NSMutableDictionary *parsedJson = [NSMutableDictionary dictionaryWithDictionary:[responseString objectFromJSONString]];
    if ([website isEqualToString:@"quizlet"]) {
        [FlashCardsCore setSetting:@"quizletIsLoggedIn" value:[NSNumber numberWithBool:YES]];
        [FlashCardsCore setSetting:@"quizletReadScope" value:[NSNumber numberWithBool:YES]];
        [FlashCardsCore setSetting:@"quizletWriteSetScope" value:[NSNumber numberWithBool:YES]];
        [FlashCardsCore setSetting:@"quizletWriteGroupScope" value:[NSNumber numberWithBool:YES]];
        [FlashCardsCore setSetting:@"quizletLoginUsername" value:[parsedJson valueForKey:@"user_id"]];
        [FlashCardsCore setSetting:@"quizletUsername" value:[parsedJson valueForKey:@"user_id"]];
        [FlashCardsCore setSetting:@"quizletAPI2AccessToken" value:[parsedJson valueForKey:@"access_token"]];
        [FlashCardsCore setSetting:@"quizletAPI2AccessTokenType" value:[parsedJson valueForKey:@"token_type"]];
        
        [Flurry setUserID:[NSString stringWithFormat:@"Quizlet/%@", [parsedJson valueForKey:@"user_id"]]];
    }
    // restore the user to the proper place that they were supposed to be before:
    // NB, since we know that the user is ONLY looking at the "home" screen, we can just add VCs to the stack per usual:
    
    // 1. We check to see what kind of place we want to restore to:
    // importProcessRestore (we are going back to import),
    // uploadProcessRestore (we are going back to upload to Quizlet)
    if ([FlashCardsCore getSettingBool:@"importProcessRestore"] || [FlashCardsCore getSettingBool:@"uploadProcessRestore"]) {
        // we were going back to import, so set that up:
        NSString *collectionId = (NSString*)[FlashCardsCore getSetting:@"importProcessRestoreCollectionId"];
        NSString *cardSetId =    (NSString*)[FlashCardsCore getSetting:@"importProcessRestoreCardsetId"];
        int groupId =            [(NSNumber*)[FlashCardsCore getSetting:@"importProcessRestoreGroupId"] intValue];
        NSString *choiceVC =     (NSString*)[FlashCardsCore getSetting:@"importProcessRestoreChoiceViewController"];
        
        // as per: http://stackoverflow.com/questions/516443/nsmanagedobjectid-into-nsdata
        // as per: http://stackoverflow.com/questions/5035057/how-to-get-core-data-object-from-specific-object-id
        FCCollection *importCollection = nil;
        if ([collectionId length] > 0) {
            NSManagedObjectID *collectionMOID = [[FlashCardsCore mainMOC].persistentStoreCoordinator managedObjectIDForURIRepresentation:[NSURL URLWithString:collectionId]];
            importCollection =  (FCCollection*)[[FlashCardsCore mainMOC] existingObjectWithID:collectionMOID error:nil];
        }
        FCCardSet *importCardSet = nil;
        if ([cardSetId length] > 0) {
            NSManagedObjectID *cardSetMOID    = [[FlashCardsCore mainMOC].persistentStoreCoordinator managedObjectIDForURIRepresentation:[NSURL URLWithString:cardSetId]];
            importCardSet =         (FCCardSet*)[[FlashCardsCore mainMOC] existingObjectWithID:cardSetMOID error:nil];
        }
        
        // set up our VC setup
        NSMutableArray *viewControllers = [[NSMutableArray alloc] initWithArray:[self.navigationController viewControllers]];
        if (importCollection) {
            // 1. add the collection 
            CollectionViewViewController *collectionViewVC = [[CollectionViewViewController alloc] initWithNibName:@"CollectionViewViewController" bundle:nil];
            collectionViewVC.collection = importCollection;
            collectionViewVC.cardsDue = 0;
            if ([cardsDueCountDict objectForKey:[collectionViewVC.collection objectID]]) {
                collectionViewVC.cardsDue = [[cardsDueCountDict objectForKey:[collectionViewVC.collection objectID]] intValue];
            }
            [viewControllers addObject:collectionViewVC];
            
            // 2. if we have a card set, then set up the card set:
            if (importCardSet) {
                // View All Card Sets
                CardSetListViewController *cardSetListVC = [[CardSetListViewController alloc] initWithNibName:@"CardSetListViewController" bundle:nil];
                cardSetListVC.collection = importCollection;
                cardSetListVC.collectionCardsDueCount = collectionViewVC.cardsDue;
                [viewControllers addObject:cardSetListVC];

                // The card set itself
                CardSetViewViewController *cardSetViewVC = [[CardSetViewViewController alloc] initWithNibName:@"CardSetViewViewController" bundle:nil];
                cardSetViewVC.cardSet = importCardSet;
                cardSetViewVC.cardsDue = 0;
                [viewControllers addObject:cardSetViewVC];


            }
            

        }
        // if we are importing, show us to the import screen:
        if ([FlashCardsCore getSettingBool:@"importProcessRestore"]) {
            // After that, we will go to the import choice screen:
            CardSetImportChoicesViewController *importVC = [[CardSetImportChoicesViewController alloc] initWithNibName:@"CardSetImportChoicesViewController" bundle:nil];
            if (importCardSet) {
                importVC.cardSet = importCardSet;
                importVC.cardSetCreateMode = modeEdit;
            } else {
                importVC.collection = importCollection;
                importVC.cardSetCreateMode = modeCreate;
            }
            [viewControllers addObject:importVC];
            
            int pop = [viewControllers count] - 2;
            FCSetsTableViewController *vc;
            if ([choiceVC isEqual:@"QuizletMySetsViewController"]) {
                vc = [[QuizletMySetsViewController alloc] initWithNibName:@"QuizletMySetsViewController" bundle:nil];
                [vc setHasDownloadedFirstTime:NO];
                [vc setImportFromWebsite:@"quizlet"];
                [vc setPopToViewControllerIndex:pop];
                [vc setCardSetCreateMode:importVC.cardSetCreateMode];
                [vc setCollection:importCollection];
                [vc setCardSet:importCardSet];
                [viewControllers addObject:vc];
            } else if ([choiceVC isEqual:@"QuizletMyGroupsViewController"]) {
                vc = [[QuizletMyGroupsViewController alloc] initWithNibName:@"QuizletMyGroupsViewController" bundle:nil];
                [vc setHasDownloadedFirstTime:NO];
                [vc setImportFromWebsite:@"quizlet"];
                [vc setPopToViewControllerIndex:pop];
                [vc setCardSetCreateMode:importVC.cardSetCreateMode];
                [vc setCollection:importCollection];
                [vc setCardSet:importCardSet];
                [viewControllers addObject:vc];
            } else if ([choiceVC isEqual:@"QuizletSearchGroupsViewController"]) {
                vc = [[QuizletSearchGroupsViewController alloc] initWithNibName:@"QuizletSearchGroupsViewController" bundle:nil];
                [vc setHasDownloadedFirstTime:NO];
                [vc setImportFromWebsite:@"quizlet"];
                [vc setPopToViewControllerIndex:pop];
                [vc setCardSetCreateMode:importVC.cardSetCreateMode];
                [vc setCollection:importCollection];
                [vc setCardSet:importCardSet];
                NSString *searchTerm = [NSString stringWithString:(NSString*)[FlashCardsCore getSetting:@"importProcessRestoreSearchTerm"]];
                [vc setValue:searchTerm forKey:@"savedSearchTerm"];
                [viewControllers addObject:vc];
            } else if ([choiceVC isEqual:@"QuizletMyGroupsViewController"]) {
                vc = [[QuizletMyGroupsViewController alloc] initWithNibName:@"QuizletMyGroupsViewController" bundle:nil];
                // pass the managed object context to the view controller.
                [vc setHasDownloadedFirstTime:NO];
                [vc setImportFromWebsite:@"quizlet"];
                [vc setPopToViewControllerIndex:pop];
                [vc setCardSetCreateMode:importVC.cardSetCreateMode];
                [vc setCollection:importCollection];
                [vc setCardSet:importCardSet];
                [viewControllers addObject:vc];
            }
            
            if ([choiceVC isEqual:@"QuizletSearchGroupsViewController"] || [choiceVC isEqual:@"QuizletMyGroupsViewController"]) {
                if (groupId > 0) {
                    QuizletGroupSetsViewController *setVc = [[QuizletGroupSetsViewController alloc] initWithNibName:@"QuizletGroupSetsViewController" bundle:nil];
                    [setVc setImportFromWebsite:@"quizlet"];
                    [setVc setPopToViewControllerIndex:pop];
                    [setVc setCardSetCreateMode:importVC.cardSetCreateMode];
                    [setVc setCollection:importCollection];
                    [setVc setCardSet:importCardSet];
                    
                    ImportGroup *group = [[ImportGroup alloc] init];
                    group.groupId = groupId;
                    [setVc setGroup:group];
                    
                    [viewControllers addObject:setVc];

                }
            }
            
        } else {
            // otherwise, we are going to the upload screen:
            if ([choiceVC isEqual:@"CardSetUploadToQuizletViewController"]) {
                // show the Quizlet upload screen:
                CardSetUploadToQuizletViewController *vc = [[CardSetUploadToQuizletViewController alloc] initWithNibName:@"CardSetUploadToQuizletViewController" bundle:nil];
                if (importCardSet) {
                    vc.cardSet = importCardSet;
                    vc.collection = importCardSet.collection;
                    vc.cardsToUpload = [NSMutableArray arrayWithArray:[importCardSet allCardsInOrder]];
                } else {
                    vc.collection = importCollection;
                    vc.cardsToUpload = [NSMutableArray arrayWithArray:[importCollection.masterCardSet allCardsInOrder]];
                }
                [viewControllers addObject:vc];
            } else {
            }
        }
        
        [FlashCardsCore resetAllRestoreProcessSettings];

        // restore the VCs
        [self.navigationController setViewControllers:viewControllers animated:YES];
    }
    
    [FlashCardsCore resetAllRestoreProcessSettings];
}

- (void)requestFailed:(ASIHTTPRequest *)request
{
    isAuthenticatingQuizlet = NO;
    [FlashCardsCore resetAllRestoreProcessSettings];
    
    [HUD hide:YES];
    NSError *error = [request error];
    FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"Error", @"Error", @""),
                               [NSString stringWithFormat:NSLocalizedStringFromTable(@"Error downloading data: %@ %@", @"Error", @""),
                                error, [error userInfo]]);
}

// we have recieved the token and we want to return the user to the screen they were headed to, so that
// they can actually access their data:
- (void)quizletAuthenticationTokenReceived {
    
}

# pragma mark -
# pragma mark Data store functions

- (void)loadDataFromStore {
    
    // if we are creating the default data store, update all dates to now:

     if ((createDefaultData || checkMasterCardSets) && ![[FlashCardsCore appDelegate] coredataIsCorrupted]) {
        NSManagedObjectContext *tempMOC = [FlashCardsCore tempMOC];
        [tempMOC performBlock:^{
            NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
            // Edit the entity name as appropriate.
            NSEntityDescription *entity = [NSEntityDescription entityForName:@"Collection"
                                                      inManagedObjectContext:tempMOC];
            [fetchRequest setEntity:entity];
            NSArray *allCollections = [tempMOC executeFetchRequest:fetchRequest error:nil];
            FCCardSet *masterSet;
            BOOL changed = NO;
            for (FCCollection *collection in allCollections) {
                if (createDefaultData) {
                    changed = YES;
                    [collection resetDatesObjectsCreated];
                }
                if (!collection.masterCardSet) {
                    changed = YES;
                    masterSet = (FCCardSet *)[NSEntityDescription insertNewObjectForEntityForName:@"CardSet"
                                                                           inManagedObjectContext:tempMOC];
                    [masterSet setName:collection.name];
                    [masterSet setCollection:collection];
                    [masterSet setIsMasterCardSet:[NSNumber numberWithBool:YES]];
                    [masterSet setCards:collection.cards];
                    [collection setMasterCardSet:masterSet];
                }
            }
            [tempMOC save:nil];
            [FlashCardsCore saveMainMOC];
        }];
    }

    
    // as per: http://www.techotopia.com/index.php/IPhone_Database_Implementation_using_SQLite
    // This is meant to fix a problem with ios5 compatibility.
    sqlite3 *db; //Declare a pointer to sqlite database structure
    NSString *storePath = [[FlashCardsCore documentsDirectory] stringByAppendingPathComponent: @"FlashCards.sqlite"];
    char *dbpath = [storePath UTF8String]; // Convert NSString to UTF-8
    if (sqlite3_open(dbpath, &db) == SQLITE_OK)
    {
        //Database opened successfully
    } else {
        //Failed to open database
    }
    // as per: http://stackoverflow.com/questions/6526015/question-about-sqlite3-and-updating-iphone-app/6526129#6526129
    const char *sql = "PRAGMA table_info(Z_1RELATEDCARDS)";
    sqlite3_stmt *stmt;
    
    if (sqlite3_prepare_v2(db, sql, -1, &stmt, NULL) != SQLITE_OK)
    {
        // it didn't work
        // return NO;
    }
    BOOL FOK_REFLEXIVE = NO;
    while(sqlite3_step(stmt) == SQLITE_ROW)
    {
        NSString *fieldName = [NSString stringWithUTF8String:(char *)sqlite3_column_text(stmt, 1)];
        if ([fieldName isEqual:@"FOK_REFLEXIVE"]) {
            FOK_REFLEXIVE = YES;
        }
        // NSLog(@"%@", fieldName);
    }
    sqlite3_finalize(stmt);
    
    if (!FOK_REFLEXIVE) {
        const char *sqlUpdate = "ALTER TABLE Z_1RELATEDCARDS ADD COLUMN FOK_REFLEXIVE INTEGER DEFAULT 0";
        if (sqlite3_prepare_v2(db, sqlUpdate, -1, &stmt, NULL) != SQLITE_OK)
        {
            // it didn't work
            // return NO;
        }
        sqlite3_step(stmt);
        sqlite3_finalize(stmt);

    }
    
    sqlite3_close(db);


    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateCardsDueCount) name:UIApplicationWillEnterForegroundNotification object:NULL];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateCardsDueCount) name:UIApplicationDidBecomeActiveNotification  object:NULL];
    
    [self loadCollections];
    [self updateCardsDueCount];
    
    // only show the Facebook section if they haven't hit the 'x' button and if the device is currently connected to the internet.
    self.myTableView.tableFooterView.hidden = NO;

    [self.myTableView reloadData];

    [self setTableShouldScroll];
    
    if (isFirstLoad) {
        if ([FlashCardsCore appIsSyncing]) {
            [[FlashCardsCore appDelegate] preconfigureSyncManager];
            [[FlashCardsCore appDelegate] registerSyncManager];
        } else {
            [self performSelectorInBackground:@selector(checkLoginStatus) withObject:nil];
        }
    }
    isFirstLoad = NO;

    [self checkAddSyncButton];
    
    NSString *hash = [FlashCardsCore managedObjectModelHash];

    // LOAD SETTINGS FROM USER FILE
    // [FlashCardsCore loadSettingsFile];

}

- (void)setupDataStore {
    HUD = [[MBProgressHUD alloc] initWithView:self.view];
    // Add HUD to screen
    [self.view addSubview:HUD];
    // Regisete for HUD callbacks so we can remove it from the window at the right time
    HUD.delegate = self;
    HUD.minShowTime = 6.0;
    HUD.labelText = NSLocalizedStringFromTable(@"Updating Database", @"FlashCards", @"HUD");
    HUD.detailsLabelText = NSLocalizedStringFromTable(@"May take a minute on large databases.", @"FlashCards", @"HUD");
    [HUD showWhileExecuting:@selector(actuallySetupDataStore) onTarget:self withObject:nil animated:YES];
    //[HUD hide:YES];
    if (isLoadingRestoreData) {
        FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"Restore Successful", @"Backup", @"UIAlert title"),
                                   NSLocalizedStringFromTable(@"FlashCards++ has successfully restored its database.", @"Backup", @"message"));
        
    }
}

- (void)actuallySetupDataStore {
    FlashCardsAppDelegate *del = (FlashCardsAppDelegate*)[[UIApplication sharedApplication] delegate];
    FCLog(@"actuallySetupDataStore");
    [del reloadPersistentStoreCoordinator:YES]; // it is a rebuild
    [del createManagedObjectModel];
    if ([FlashCardsCore mainMOC]) {
        [self performSelectorOnMainThread:@selector(loadDataFromStore) withObject:nil waitUntilDone:YES];
        [self performSelectorInBackground:@selector(fixSyncIds) withObject:nil];
    }
}

- (void)fixSyncIds {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);
    dispatch_async(queue, ^{
        TICDSLog(TICDSLogVerbosityStartAndEndOfEachOperationPhase, @"Checking whether there are any missing ticdsSyncIDs in any managed objects");
        BOOL success = [TICDSWholeStoreUploadOperation fixSyncIdsAnd:nil
                                                        withDelegate:nil
                                                        onMainThread:NO];
        if (success) {
        }
    });
}

# pragma mark -
# pragma mark Event functions

- (BOOL)canUseTwitter {
    if ([FlashCardsCore iOSisGreaterThan:6.0f]) {
        if ([SLComposeViewController isAvailableForServiceType:SLServiceTypeTwitter]) {
            return YES;
        }
    }
    
    NSString *twitterAccount = @"studyflashcards";
    
    NSArray *urls = @[
                     @"twitter://user?screen_name={handle}", // Twitter
                     @"tweetbot:///user_profile/{handle}", // TweetBot
                     @"echofon:///user_timeline?{handle}", // Echofon
                     @"twit:///user?screen_name={handle}", // Twittelator Pro
                     @"x-seesmic://twitter_profile?twitter_screen_name={handle}", // Seesmic
                     @"x-birdfeed://user?screen_name={handle}", // Birdfeed
                     @"tweetings:///user?screen_name={handle}", // Tweetings
                     @"simplytweet:?link=http://twitter.com/{handle}", // SimplyTweet
                     @"icebird://user?screen_name={handle}", // IceBird
                     @"fluttr://user/{handle}" // Fluttr
                     ];

    for (NSString *candidate in urls) {
        NSURL *url = [NSURL URLWithString:[candidate stringByReplacingOccurrencesOfString:@"{handle}" withString:twitterAccount]];
        if ([[UIApplication sharedApplication] canOpenURL:url]) {
            return YES;
        }
    }
    
    return NO;
}

- (void)followOnTwitterWithAccount:(ACAccount*)twitterAccount {
    if (![FlashCardsCore isConnectedToInternet]) {
        FCDisplayBasicErrorMessage(@"",
                                   NSLocalizedStringFromTable(@"This feature will only work with an active internet connection.", @"Error", @""));
        return;
    }

    if (!HUD) {
        HUD = [[MBProgressHUD alloc] initWithView:self.view];
        
        // Add HUD to screen
        [self.view addSubview:HUD];
        
        // Regisete for HUD callbacks so we can remove it from the window at the right time
        HUD.delegate = self;
        HUD.minShowTime = 1.0;
        [HUD show:YES];
    }
    NSMutableDictionary *tempDict = [[NSMutableDictionary alloc] init];
    [tempDict setValue:@"studyflashcards" forKey:@"screen_name"];
    [tempDict setValue:@"true" forKey:@"follow"];
    
    SLRequest *postRequest = [SLRequest requestForServiceType:SLServiceTypeTwitter
                                                requestMethod:SLRequestMethodPOST
                                                          URL:[NSURL URLWithString:@"https://api.twitter.com/1/friendships/create.json"]
                                                   parameters:tempDict];

    ACAccountStore *accountStore = [[ACAccountStore alloc] init];
    ACAccountType *accountTypeTwitter = [accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
    twitterAccount.accountType = accountTypeTwitter;

    [postRequest setAccount:twitterAccount];
    
    [postRequest performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
        NSString *output = [NSString stringWithFormat:@"HTTP response status: %i", [urlResponse statusCode]];
        NSLog(@"%@", output);
        [self performSelectorOnMainThread:@selector(twitterFinished:) withObject:urlResponse waitUntilDone:NO];
    }];
}

- (void)twitterFinished:(NSHTTPURLResponse*)urlResponse {
    [HUD hide:YES];
    if (urlResponse.statusCode == 200) {
        FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"Thank you for Following!", @"FlashCards", @""),
                                   NSLocalizedStringFromTable(@"You are now following us on Twitter!", @"FlashCards", @""));
        [FlashCardsCore setSetting:@"hasFollowedOnTwitter" value:@YES];
    }
}

- (void)displayTwitterAccounts {
    HUD = [[MBProgressHUD alloc] initWithView:self.view];
    
    // Add HUD to screen
    [self.view addSubview:HUD];
    
    // Regisete for HUD callbacks so we can remove it from the window at the right time
    HUD.delegate = self;
    HUD.minShowTime = 1.0;
    [HUD show:YES];
    
    // Get the list of Twitter accounts.
    ACAccountStore *accountStore = [[ACAccountStore alloc] init];
    ACAccountType *accountType = [accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
    __strong NSArray *accountsArray = [accountStore accountsWithAccountType:accountType];
    
    // For the sake of brevity, we'll assume there is only one Twitter account present.
    // You would ideally ask the user which account they want to tweet from, if there is more than one Twitter account present.
    if ([accountsArray count] == 0) {
        FCDisplayBasicErrorMessage(@"",
                                   NSLocalizedStringFromTable(@"You currently do not have any Twitter accounts.", @"FlashCards", @""));
        return;
    }
    if ([accountsArray count] > 1) {
        ActionStringCancelBlock cancel = ^(ActionSheetStringPicker *picker) {
            NSLog(@"Block Picker Canceled");
        };
        ActionStringDoneBlock done = ^(ActionSheetStringPicker *picker, NSInteger selectedIndex, id selectedValue) {
            ACAccount *twitterAccount = [accountsArray objectAtIndex:selectedIndex];
            [self followOnTwitterWithAccount:twitterAccount];
        };
        NSMutableArray *screenNames = [NSMutableArray arrayWithCapacity:0];
        for (ACAccount *account in accountsArray) {
            NSString *name = [account username];
            [screenNames addObject:name];
        }
        [HUD hide:YES];
        // front side: show the picker
        [ActionSheetStringPicker showPickerWithTitle:NSLocalizedStringFromTable(@"Select Twitter Account", @"FlashCards", @"UILabel")
                                                rows:screenNames
                                    initialSelection:0
                                           doneBlock:done
                                         cancelBlock:cancel
                                              origin:self.navigationItem.rightBarButtonItem];
        
        return;
    }
    // Grab the initial Twitter account to tweet from.
    ACAccount *twitterAccount = [accountsArray objectAtIndex:0];
    [self followOnTwitterWithAccount:twitterAccount];
}

- (IBAction)followOnTwitter:(id)sender {
    NSString *twitterAccount = @"studyflashcards";
    
    if (![FlashCardsCore isConnectedToInternet]) {
        FCDisplayBasicErrorMessage(@"",
                                   NSLocalizedStringFromTable(@"This feature will only work with an active internet connection.", @"Error", @""));
        return;
    }
    
    if ([FlashCardsCore iOSisGreaterThan:6.0f]) {
        if ([SLComposeViewController isAvailableForServiceType:SLServiceTypeTwitter]) {
            // as per: http://stackoverflow.com/a/14430788/353137
            ACAccountStore *accountStore = [[ACAccountStore alloc] init];
            ACAccountType *accountType = [accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
            
            [accountStore requestAccessToAccountsWithType:accountType
                                                  options:nil
                                               completion:^(BOOL granted, NSError *error) {
                                                   if(granted) {
                                                       [self performSelectorOnMainThread:@selector(displayTwitterAccounts)
                                                                              withObject:nil
                                                                           waitUntilDone:NO];
                                                   }
                                               }];
            
            return;
        }
    }

    // as per: https://github.com/chrismaddern/Follow-Me-On-Twitter-iOS-Button
    NSArray *urls = [NSArray arrayWithObjects:
                     @"twitter://user?screen_name={handle}", // Twitter
                     @"tweetbot:///user_profile/{handle}", // TweetBot
                     @"echofon:///user_timeline?{handle}", // Echofon
                     @"twit:///user?screen_name={handle}", // Twittelator Pro
                     @"x-seesmic://twitter_profile?twitter_screen_name={handle}", // Seesmic
                     @"x-birdfeed://user?screen_name={handle}", // Birdfeed
                     @"tweetings:///user?screen_name={handle}", // Tweetings
                     @"simplytweet:?link=http://twitter.com/{handle}", // SimplyTweet
                     @"icebird://user?screen_name={handle}", // IceBird
                     @"fluttr://user/{handle}", // Fluttr
                     @"http://twitter.com/{handle}",
                     nil];
    
    UIApplication *application = [UIApplication sharedApplication];
    
    for (NSString *candidate in urls) {
        NSURL *url = [NSURL URLWithString:[candidate stringByReplacingOccurrencesOfString:@"{handle}" withString:twitterAccount]];
        if ([application canOpenURL:url]) {
            [FlashCardsCore setSetting:@"hasFollowedOnTwitter" value:@YES];
            [application openURL:url];
            return;
        }
    }
}

- (void)reachabilityChanged:(NSNotification*)note {
    Reachability* r = [note object];
    NetworkStatus ns = r.currentReachabilityStatus;

    if (ns == NotReachable) {
        // not connected to the internet.
    } else {
        // the user is connected to the internet:
        if ([FlashCardsCore currentlyUsingOneTimeOfflineTTSTrial]) {
            // make sure that we have marked if they have used the one-time offline TTS trial:
            [FlashCardsCore updateHasUsedOneTimeOfflineTTSTrial];

            // remind them to sign up for a subscription:
            SubscriptionViewController *vc = [[SubscriptionViewController alloc] initWithNibName:@"SubscriptionViewController" bundle:nil];
            vc.showTrialEndedPopup = YES;
            vc.giveTrialOption = NO;
            vc.explainSync = NO;
            // Pass the selected object to the new view controller.
            [self.navigationController pushViewController:vc animated:YES];
        }
        if ([FlashCardsCore appIsSyncing]) {
            if (![[[FlashCardsCore appDelegate] syncController] documentSyncManagerHasRegistered] &&
                ![[[FlashCardsCore appDelegate] syncController] isCurrentlyRegisteringSyncManagers]) {
                [[FlashCardsCore appDelegate] registerSyncManager];
            }
        }
        [self performSelectorInBackground:@selector(checkLoginStatus) withObject:nil];
        [FlashCardsCore setSetting:@"lastDisplayedOfflineMessage" value:[NSDate dateWithTimeIntervalSince1970:0]];
        if ([(NSNumber*)[FlashCardsCore getSetting:@"shouldSyncWhenComesOnline"] boolValue]) {
            [FlashCardsCore setSetting:@"shouldSyncWhenComesOnline" value:[NSNumber numberWithBool:NO]];
            // TODO: Set up sync online
        }
    }
}

- (void)checkLoginStatus {
    @autoreleasepool {
        NSManagedObjectContext *context = [FlashCardsCore mainMOC];
        if (!context) {
            return;
        }
        [[[FlashCardsCore appDelegate] inAppPurchaseManager] uploadAllQueuedTransactions];
        [FlashCardsCore checkLogin];
    }
}

- (void)startOfflineTTSQueue {
}

- (void) addEvent {
    
    CollectionCreateViewController *collectionCreate = [[CollectionCreateViewController alloc] initWithNibName:@"CollectionCreateViewController" bundle:nil];
    collectionCreate.editMode = modeCreate;
    
    // Pass the selected object to the new view controller.
    [self.navigationController pushViewController:collectionCreate animated:YES];
}

- (IBAction)loadTeachersView:(id)sender {
    
    RIButtonItem *cancelItem = [RIButtonItem item];
    cancelItem.label = NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"");
    cancelItem.action = ^{};

    RIButtonItem *notTeacher = [RIButtonItem item];
    notTeacher.label = NSLocalizedStringFromTable(@"I'm Not a Teacher or a Student", @"Subscription", @"");
    notTeacher.action = ^{
        RIButtonItem *cancelItem2 = [RIButtonItem item];
        cancelItem2.label = NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"");
        cancelItem2.action = ^{};
        
        RIButtonItem *hideItem = [RIButtonItem item];
        hideItem.label = NSLocalizedStringFromTable(@"Yes", @"FlashCards", @"");
        hideItem.action = ^{
            [FlashCardsCore setSetting:@"showForTeachersButton" value:@NO];
            [self checkAutomaticallySyncButton];
            [self.navigationController popViewControllerAnimated:YES];
        };
        
        NSString *message = [NSString stringWithFormat:NSLocalizedStringFromTable(@"Would you like to hide the '%@' button?", @"Subscription", @""),
                             [[teachersButton titleLabel] text]];
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@""
                                                        message:message
                                               cancelButtonItem:cancelItem
                                               otherButtonItems:hideItem, nil];
        [alert show];
    };

    RIButtonItem *studentItem = [RIButtonItem item];
    studentItem.label = NSLocalizedStringFromTable(@"I'm a Student", @"Subscription", @"");
    studentItem.action = ^{
        StudentViewController *vc = [[StudentViewController alloc] initWithNibName:@"StudentViewController" bundle:nil];
        vc.hasExistingAccount = NO;
        [self.navigationController pushViewController:vc animated:YES];
    };

    RIButtonItem *teacherItem = [RIButtonItem item];
    teacherItem.label = NSLocalizedStringFromTable(@"I'm a Teacher", @"Subscription", @"");
    teacherItem.action = ^{
        TeachersViewController *vc = [[TeachersViewController alloc] initWithNibName:@"TeachersViewController" bundle:nil];
        [self.navigationController pushViewController:vc animated:YES];
    };

    
    UIActionSheet *action = [[UIActionSheet alloc] initWithTitle:@""
                                                cancelButtonItem:cancelItem
                                           destructiveButtonItem:notTeacher
                                                otherButtonItems:studentItem, teacherItem, nil];
    action.actionSheetStyle = UIActionSheetStyleBlackOpaque;
    [action showFromToolbar:bottomToolbar];
}


- (IBAction)loadSettingsView:(id)sender {
    SettingsStudyViewController *vc = [[SettingsStudyViewController alloc] initWithNibName:@"SettingsStudyViewController" bundle:nil];
    vc.goToStudySettings = NO;
    [self.navigationController pushViewController:vc animated:YES];
}

- (void) goToBackupRestoreChooseFile {
    BackupRestoreListFilesViewController *vc = [[BackupRestoreListFilesViewController alloc] initWithNibName:@"BackupRestoreListFilesViewController" bundle:nil];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)checkDropboxStatus {
    if ([[DBSession sharedSession] isLinked]) {
        [self goToBackupRestoreChooseFile];
    }
}

- (IBAction)loadBackupView:(id)sender {
    if ([[DBSession sharedSession] isLinked]) {
        [self goToBackupRestoreChooseFile];
    } else {

        RIButtonItem *cancelItem = [RIButtonItem item];
        cancelItem.label = NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"");
        cancelItem.action = ^{};
        
        RIButtonItem *linkItem = [RIButtonItem item];
        linkItem.label = NSLocalizedStringFromTable(@"Link Dropbox", @"Dropbox", @"");
        linkItem.action = ^{
        
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(checkDropboxStatus)
                                                         name:UIApplicationDidBecomeActiveNotification
                                                       object:nil];
            
            // On iOS 4.0+ only, listen for foreground notification
            if(&UIApplicationWillEnterForegroundNotification != nil)
            {
                [[NSNotificationCenter defaultCenter] addObserver:self
                                                         selector:@selector(checkDropboxStatus)
                                                             name:UIApplicationWillEnterForegroundNotification
                                                           object:nil];
            }

            [[DBSession sharedSession] linkFromController:self];
        };
        
        
        NSString *message = NSLocalizedStringFromTable(@"FlashCards++ uses the free Dropbox service to store backups in the cloud. Please sign in or create a free Dropbox account below to set up backups.", @"Backup", @"");
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@""
                                                        message:message
                                               cancelButtonItem:cancelItem
                                               otherButtonItems:linkItem, nil];
        [alert show];
    }
}

- (IBAction)helpHelp:(id)sender {
    FAQViewController *faqVC = [[FAQViewController alloc] initWithNibName:@"FAQViewController" bundle:nil];
    [self.navigationController pushViewController:faqVC animated:YES];
}

- (void)loadCollections {
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    // Edit the entity name as appropriate.
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Collection"
                                              inManagedObjectContext:[FlashCardsCore mainMOC]];
    [fetchRequest setEntity:entity];
    
    // Edit the sort key as appropriate.
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)];
    NSArray *sortDescriptors = [[NSArray alloc] initWithObjects:sortDescriptor, nil];
    
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    [collections removeAllObjects];
    [collections addObjectsFromArray:
     [[FlashCardsCore mainMOC] executeFetchRequest:fetchRequest error:nil]];

}

- (void) updateCardsDueCount {
    // 1. Get all the cards that are due
    // 2. Create a dictionary with key as each card set, and increment each one for each due card.
    if (isUpdatingCardsDueCount) {
        return;
    }
    isUpdatingCardsDueCount = YES;
    NSManagedObjectContext *tempMOC = [FlashCardsCore tempMOC];
    [tempMOC performBlock:^{
        @autoreleasepool {
            NSMutableDictionary *newCardsDueCountDict = [NSMutableDictionary dictionaryWithCapacity:0];
            NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
            [fetchRequest setEntity:[NSEntityDescription entityForName:@"Card"
                                                inManagedObjectContext:tempMOC]];
            [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"isDeletedObject = NO and isSpacedRepetition = YES and nextRepetitionDate <= %@", [NSDate date]]];
            NSArray *cards = [tempMOC executeFetchRequest:fetchRequest error:nil];
            int mycount;
            for (FCCard *card in cards) {
                FCCollection *collection = card.collection;
                if (!collection) {
                    continue;
                }
                NSManagedObjectID *collectionId = [collection objectID];
                if (![newCardsDueCountDict objectForKey:collectionId]) {
                    [newCardsDueCountDict setObject:[NSNumber numberWithInt:0]
                                             forKey:collectionId];
                }
                mycount = [[newCardsDueCountDict objectForKey:collectionId] intValue];
                [newCardsDueCountDict setObject:[NSNumber numberWithInt:(mycount+1)]
                                      forKey:collectionId];
            }
            
            // add up all of the card counts:
            int totalCount = 0;
            for (NSNumber *num in [newCardsDueCountDict allValues]) {
                totalCount += [num intValue];
            }
            cardsDueCountDict = nil;
            cardsDueCountDict = newCardsDueCountDict;
            [self performSelectorOnMainThread:@selector(finishUpdateCardsDueCount:)
                                   withObject:[NSNumber numberWithInt:totalCount]
                                waitUntilDone:NO];
            [tempMOC reset];
        }
    }];
}
- (void) finishUpdateCardsDueCount:(NSNumber*)_totalCount {
    int totalCount = [_totalCount intValue];
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:totalCount];
    isUpdatingCardsDueCount = NO;
    //Reload the table view
    [self.myTableView reloadData];
    
}

- (void) setTableShouldScroll {
    // self.navigationItem.leftBarButtonItem.enabled = ([collections count] > 0);
    if ([self shouldDisplayHelpCell] && !isUpdatingData) {
        self.myTableView.scrollEnabled = YES;
        self.myTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    } else {
        self.myTableView.scrollEnabled = YES;
        self.myTableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    }
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row >= [collections count]) {
        // for some reason we are trying to modify a cell for an object that is
        // outside the range of the fetchedResultsController's fetchedObjects.
        // This happens sometimes when we have merged collections and the one to be
        // deleted was listed **above** the destination collection. In this case, it
        // seems that the deletion of the top one causes the bottom one to be outside the
        // range of the fetchResultsController's fetchedObjects!
        return;
    }
    NSManagedObject *managedObject = [collections objectAtIndex:indexPath.row];
    cell.textLabel.text = [[managedObject valueForKey:@"name"] description];

    [cell.imageView setImage:[UIImage imageNamed:@"Collection.png"]];

    if ([cardsDueCountDict objectForKey:[managedObject objectID]]) {
        NSUInteger count = [[cardsDueCountDict objectForKey:[managedObject objectID]] intValue];
        if (count > 0) {
            cell.detailTextLabel.text = [NSString stringWithFormat:FCPluralLocalizedStringFromTable(@"%d cards due", @"Plural", @"", [NSNumber numberWithInt:(int)count]), count];
        } else {
            cell.detailTextLabel.text = @"";
        }
    } else {
        cell.detailTextLabel.text = @"";
    }

}

- (void)askToViewGettingStartedTour {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDate *dateOfFirstLaunch = [NSDate dateWithTimeIntervalSince1970:[defaults doubleForKey:@"kAppiraterFirstUseDate"]];
    NSInteger daysSinceInstall = [[NSDate date] timeIntervalSinceDate:dateOfFirstLaunch] / 86400;
    NSLog(@"days: %d", daysSinceInstall);
    BOOL hasBeenAskedToViewGettingStartedTour = [FlashCardsCore getSettingBool:@"hasBeenAskedToViewGettingStartedTour"];
    // BOOL hasBeenAskedToBecomeBetaTester       = [FlashCardsCore getSettingBool:@"hasBeenAskedToBecomeBetaTester"];
    if (!hasBeenAskedToViewGettingStartedTour && daysSinceInstall < 3 && NO) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Get Started", @"Help", @"")
                                                         message:NSLocalizedStringFromTable(@"Would you like to read the 'Getting Started' tour for FlashCards++?", @"Help", @"")
                                                        delegate:self
                                               cancelButtonTitle:NSLocalizedStringFromTable(@"No, Thanks", @"Appirater", @"")
                                               otherButtonTitles:NSLocalizedStringFromTable(@"Go to Tour", @"Help", @""), nil];
        [alert show];
        [FlashCardsCore setSetting:@"hasBeenAskedToViewGettingStartedTour" value:[NSNumber numberWithBool:YES]];
    /*
    } else if (!hasBeenAskedToBecomeBetaTester && [MFMailComposeViewController canSendMail]) {
        int useCount = [(NSNumber*)[FlashCardsCore getSetting:kAppiraterUseCount] intValue];
        if (useCount > 5 && daysSinceInstall > 5) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Apply to be a Beta Tester", @"Help", @"")
                                                            message:NSLocalizedStringFromTable(@"Would you like to help make FlashCards++ a better app? I am always working on new updates and am looking for customers who want to help to beta test them by reporting bugs and making suggestions. I am inviting you to apply to be a beta tester. Would you like to join us? -- Jason, FlashCards++ Developer", @"Help", @"")
                                                           delegate:self
                                                  cancelButtonTitle:NSLocalizedStringFromTable(@"No, Thanks", @"Appirater", @"")
                                                  otherButtonTitles:NSLocalizedStringFromTable(@"Apply Now", @"Help", @""), nil];
            [alert show];
            [FlashCardsCore setSetting:@"hasBeenAskedToBecomeBetaTester" value:[NSNumber numberWithBool:YES]];
        }
    */
    }
}

- (BOOL)shouldDisplayHelpCell {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDate *dateOfFirstLaunch = [NSDate dateWithTimeIntervalSince1970:[defaults doubleForKey:@"kAppiraterFirstUseDate"]];
    NSInteger daysSinceInstall = [[NSDate date] timeIntervalSinceDate:dateOfFirstLaunch] / 86400;
    if (daysSinceInstall > 3) {
        return NO;
    }
    int numObjects = (int)[collections count];
    if (numObjects == 0) {
        return YES;
    } else if (numObjects == 1) {
        NSManagedObject *managedObject = [collections objectAtIndex:0];
        if ([[managedObject valueForKey:@"name"] isEqual:@"GRE Vocabulary"]) {
            return YES;
        }
    }
    return NO;
}

# pragma mark -
# pragma mark UIActionSheet methods

- (IBAction)showActionSheet:(id)sender {
    UIActionSheet *popupQuery = [[UIActionSheet alloc] initWithTitle:@""
                                                            delegate:self
                                                   cancelButtonTitle:NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"")
                                              destructiveButtonTitle:nil
                                                   otherButtonTitles:
                                 NSLocalizedStringFromTable(@"Getting Started", @"Help", @""),
                                 NSLocalizedStringFromTable(@"Frequently Asked Questions", @"Help", @""),
                                 NSLocalizedStringFromTable(@"Send Feedback", @"Feedback", @"UIBarButtonItem"),
                                 NSLocalizedStringFromTable(@"Send Love", @"Feedback", @""),
                                 nil];
    popupQuery.actionSheetStyle = UIActionSheetStyleBlackOpaque;
    [popupQuery showFromBarButtonItem:sender animated:YES];
}

- (void)actionSheet:(UIActionSheet*)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 0) {
        // getting started
        [self goToGettingStarted];
    } else if (buttonIndex == 1) {
        // faq
        [self helpHelp:nil];
    } else if (buttonIndex == 2) {
        // send feedback
        [self sendFeedback:nil];

    } else if (buttonIndex == 3) {
        // send love
        [self sendLove:nil];
    }
}

- (void)goToGettingStarted {
    NSString *question = NSLocalizedStringFromTable(@"Getting Started", @"Help", @"");
    NSString *answer = [GettingStartedText stringByAppendingString:GlossaryText];
    
    HelpViewController *helpVC = [[HelpViewController alloc] initWithNibName:@"HelpViewController" bundle:nil];
    helpVC.title = NSLocalizedStringFromTable(@"Help", @"Help", @"UIView title");
    helpVC.helpText = [NSString stringWithFormat:@"**%@**\n\n%@", question, answer];
    [self.navigationController pushViewController:helpVC animated:YES];
}

-(IBAction)sendLove:(id)sender {
    
    // thank the user for sending feedback:
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Send Love", @"Feedback", @"")
                                                     message:NSLocalizedStringFromTable(@"Your love makes us work harder. Please review this app.", @"Feedback", @"")
                                                    delegate:self
                                           cancelButtonTitle:NSLocalizedStringFromTable(@"Not Now", @"Feedback", @"")
                                           otherButtonTitles:NSLocalizedStringFromTable(@"Review", @"Feedback", @""), nil];
    [alert show];
}

- (IBAction)sendFeedback:(id)sender {
    FeedbackViewController *vc = [[FeedbackViewController alloc] initWithNibName:@"FeedbackViewController" bundle:nil];
    [self.navigationController pushViewController:vc animated:YES];
}

- (IBAction)importCards:(id)sender {
    CardSetImportChoicesViewController *importVC = [[CardSetImportChoicesViewController alloc] initWithNibName:@"CardSetImportChoicesViewController" bundle:nil];
    importVC.cardSetCreateMode = modeCreate;
    
    // Pass the selected object to the new view controller.
    [self.navigationController pushViewController:importVC animated:YES];
    
}

- (IBAction)automaticallySync:(id)sender {
    if (![FlashCardsCore isConnectedToInternet]) {
        FCDisplayBasicErrorMessage(@"",
                                   NSLocalizedStringFromTable(@"This feature will only work with an active internet connection.", @"Error", @""));
        return;
    }
    
    // option 1: Renew Subscription
    if ([FlashCardsCore getSettingBool:@"hasEverHadASubscription"] && ![FlashCardsCore hasSubscription]) {
        [FlashCardsCore showPurchasePopup:@"UnlimitedCards"];
        return;
    }

    // Setup sync
    if ([FlashCardsCore hasSubscription]) {
        // set up automatic sync
        [[FlashCardsCore appDelegate] setupSyncInterface];
    } else {
        // show subscription screen
        SubscriptionViewController *vc = [[SubscriptionViewController alloc] initWithNibName:@"SubscriptionViewController" bundle:nil];
        vc.showTrialEndedPopup = NO;
        vc.giveTrialOption = NO;
        vc.explainSync = YES;
        // Pass the selected object to the new view controller.
        [self.navigationController pushViewController:vc animated:YES];
    }
}

# pragma mark -
# pragma mark Alert view functions

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    NSString *buttonTitle = [alertView buttonTitleAtIndex:buttonIndex];
    
    if ([buttonTitle isEqualToString:NSLocalizedStringFromTable(@"Apply Now", @"Help", @"")]) {
        
        MFMailComposeViewController *feedbackController = [[MFMailComposeViewController alloc] init];
        feedbackController.mailComposeDelegate = self;
        [feedbackController setToRecipients:[NSArray arrayWithObject:contactEmailAddress]];
        [feedbackController setSubject:NSLocalizedStringFromTable(@"Beta Tester Application for FlashCards++", @"Help", @"")];
        [feedbackController setMessageBody:[NSString stringWithFormat:
                                            @"Thank you for your interest in being a beta tester for FlashCards++. Please answer the following questions and we will get back to you shortly. If selected, you will have early access to FlashCards++ features & updates, and will help by submitting any bugs that you find or suggestions you may have."
                                            @"\n\n"
                                            @"By sending this application, I agree to send feedback and bug reports promptly."
                                            @"\n\n"
                                            @"Your Name: \n"
                                            @"Where are you from? \n"
                                            @"Tell me about yourself: \n"
                                            @"Why do you want to be a beta tester? \n"
                                            @"\n"
                                            @"How long have you used FlashCards++? \n"
                                            @"How often do you use FlashCards++? \n"
                                            @"Do you import your flash cards from an external website or service? If so, which ones?\n"
                                            @"\n"
                                            @"Quizlet: YES or NO\n"
                                            @"Dropbox (Excel): YES or NO\n"
                                            @"\n"
                                            @"\n"
                                            @"\n\nVersion: %@\niOS: %@ (%@)\nDevice: %@\n\n",
                                            [FlashCardsCore appVersion],
                                            [FlashCardsCore osVersionNumber],
                                            [FlashCardsCore osVersionBuild],
                                            [FlashCardsCore deviceName]
                                            ]
                                    isHTML:NO];
        
        [self presentViewController:feedbackController animated:YES completion:nil];

        return;
    }

    if ([alertView.title isEqual:NSLocalizedStringFromTable(@"Load Backup File", @"Backup", @"")]) {
        if (buttonIndex == 1) {
            // do it now!
            [self loadBackupFileAction];
        } else if (buttonIndex == 2) {
            // make a backup first.
            [self saveCurrentBackupAction];
        }
        return;
    }
    if ([alertView.title isEqual:NSLocalizedStringFromTable(@"Get Started", @"Help", @"")]) {
        if (buttonIndex == 1) {
            // yes please, go to "Getting Started"
            [self goToGettingStarted];
        } else {
            [self askToViewGettingStartedTour];
        }
        return;
    }
    // we are sending love:
    if (buttonIndex == 1) {
        [FlashCardsCore writeAppReview];
    }
}

# pragma mark -
# pragma mark MFMailComposeViewControllerDelegate functions

- (void)mailComposeController:(MFMailComposeViewController*)controller
          didFinishWithResult:(MFMailComposeResult)result
                        error:(NSError*)error;
{
    if (result == MFMailComposeResultSent) {
        // thank the user for sending feedback:
        FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"Thank You", @"Feedback", @"UIAlert title"),
                                   NSLocalizedStringFromTable(@"Thank you for your application. We will be in touch shortly.", @"Help", @"message"));
        //    NSLog(@"It's away!");
    } else if (result == MFMailComposeResultFailed) {
        FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"Error", @"Error", @"UIAlert title"),
                                   [NSString stringWithFormat:NSLocalizedStringFromTable(@"An error occurred sending your message: %@ %@", @"Error", @"message"), error, [error userInfo]]);
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark -
#pragma mark MBProgressHUDDelegate methods

- (void)hudWasHidden:(MBProgressHUD *)hud {
    // Remove HUD from screen when the HUD was hidded
    FCLog(@"Hiding HUD");
    if (hud) {
        if ([hud.labelText isEqualToString:NSLocalizedStringFromTable(@"Updating Database", @"FlashCards", @"HUD")]) {
            [self askToViewGettingStartedTour];
        }
        // Remove HUD from screen when the HUD was hidded
        [hud removeFromSuperview];
        if ([hud isEqual:syncHUD]) {
            syncHUD = nil;
        }
        if ([hud isEqual:HUD]) {
            HUD = nil;
        }
        hud = nil;
    }
}

- (void)hudWasTapped:(MBProgressHUD *)hud {
    if (![SyncController hudCanCancel:hud]) {
        return;
    }
    [FlashCardsCore syncCancel];
}

#pragma mark - TICoreDataSync methods

- (void)persistentStoresDidChange {
    [self loadCollections];
    [self updateCardsDueCount];
    [self.myTableView reloadData];
}


#pragma mark - Sync finished

- (void)syncDidFinish:(SyncController *)sync {
    [self persistentStoresDidChange];
    [self checkAutomaticallySyncButton];
    [self checkTwitterButton];
}
- (void)syncDidFinish:(SyncController *)sync withError:(NSError *)error {
    [self persistentStoresDidChange];
    [self checkAutomaticallySyncButton];
    [self checkTwitterButton];
}

- (void)updateHUDLabel:(NSString*)labelText {
    HUD.labelText = labelText;
}



# pragma mark -
# pragma mark ImportCSVDelegate functions

- (void)importClient:(ImportCSV *)importCSV csvFileLoadFailedWithError:(NSError *)error {
    [HUD hide:YES];
    if (error.code == kCSVErrorFileSizeExceeded) {
        FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"Error", @"Error", @"UIAlert title"),
                                   NSLocalizedStringFromTable(@"This file exceeds the maximum file size for processing (8 megabytes). Please select a smaller file.", @"Import", @"message"));
        return;
    }
    FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"Error", @"Error", @"UIAlert title"),
                               [NSString stringWithFormat:NSLocalizedStringFromTable(@"There was an error reading your data file, please ensure that it has not been corrupted: %@ (%d)", @"Import", @"message"), 
                                [[error userInfo] valueForKey:@"errorMessage"],
                                error.code]);
    // [self.navigationController popViewControllerAnimated:NO];
}

- (void)csvFileDidLoad:(ImportCSV *)importCSV {
    [HUD hide:YES];
    fileData = [importCSV convertToFlashCardsFormat];
    [self processFileData];
}

# pragma mark -
# pragma mark Process file data

- (void)processFileData {
    
    if (!fileData) {
        // if there is no data, get out of here:
        FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"Error", @"Error", @"UIAlert title"),
                                   [NSString stringWithFormat:NSLocalizedStringFromTable(@"There was an error reading your data file, please ensure that it has not been corrupted: %@ (%d)", @"Import", @"message"), 
                                    @"empty file data",
                                    0]);
        [self.navigationController popViewControllerAnimated:NO];
    }
    
    NSMutableArray *cardSets = [ImportSet convertFCPPFileFormat:fileData];
    
    CardSetImportViewController *vc = [[CardSetImportViewController alloc] initWithNibName:@"CardSetImportViewController" bundle:nil];
    
    vc.shouldImmediatelyImportTerms = NO;
    vc.shouldImmediatelyPressImportButton = NO;
    vc.hasCheckedIfCardSetWithIdExistsOnDevice = NO;
    vc.importMethod = @"Email";
    vc.importFunction = @"MySets";
    [vc setCardSet:nil];
    [vc setCollection:nil];
    vc.allCardSets = cardSets;
    vc.popToViewControllerIndexSave = 0;
    vc.popToViewControllerIndexCancel = 0;
    vc.cardSetCreateMode = modeCreate;
    [self.navigationController pushViewController:vc animated:YES];
    
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    if ([FlashCardsCore mainMOC]) {
        return 1;
    } else {
        return 0;
    }
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (![FlashCardsCore mainMOC]) {
        return 0;
    }
    // Return the number of rows in the section.
    int numObjects = (int)[collections count];
    if ([self shouldDisplayHelpCell] && !isUpdatingData) {
        return numObjects + 1;
    }
    // NSLog(@"numObjects: %d", numObjects);
    return numObjects;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([cell.detailTextLabel.text length] > 0) {
        [cell setBackgroundColor:[UIColor yellowColor]];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row >= [collections count] && !isUpdatingData) {
        NSString *message = NSLocalizedStringWithDefaultValue(@"RootVCHelp", @"Help", [NSBundle mainBundle], @""
                                                              "Thanks for downloading FlashCards++! Tap the button above to create a new \"Collection\" of flash cards, "
                                                              "e.g. French, Human Anatomy, or Constitutional Law.\n\n"
                                                              "To create flash cards, enter your Collection and tap \"Create Cards.\n\n"
                                                              "To import flash cards, enter your Collection and tap \"Import Cards.\" You can import from "
                                                              "Quizlet, or CSV or Excel files with Dropbox.", @"");
        UIFont *messageFont = [UIFont systemFontOfSize:13.7f];
        int messageWidth = 275;
        
        float fudgeFactor = 16.0;
        CGSize tallerSize = CGSizeMake(messageWidth-fudgeFactor, 9999);
        CGSize stringSize = [message sizeWithFont:messageFont constrainedToSize:tallerSize lineBreakMode:NSLineBreakByWordWrapping];
        return stringSize.height;
    } else {
        return 44;
    }
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    

    if (indexPath.row >= [collections count] && !isUpdatingData) {
        UITableViewCell *help = [tableView dequeueReusableCellWithIdentifier:@"HelpCell"];
        if (help == nil) {
            help = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"HelpCell"];
        }
        
        
        NSString *message = NSLocalizedStringWithDefaultValue(@"RootVCHelp", @"Help", [NSBundle mainBundle], @""
                                                              "Thanks for downloading FlashCards++! Tap the button above to create a new \"Collection\" of flash cards, "
                                                              "e.g. French, Human Anatomy, or Constitutional Law.\n\n"
                                                              "To create flash cards, enter your Collection and tap \"Create Cards.\n\n"
                                                              "To import flash cards, enter your Collection and tap \"Import Cards.\" You can import from "
                                                              "Quizlet, or CSV or Excel files with Dropbox.", @"");
        UIFont *messageFont = [UIFont systemFontOfSize:13.7f];
        int messageWidth = 275;
        
        float fudgeFactor = 16.0;
        CGSize tallerSize = CGSizeMake(messageWidth-fudgeFactor, 9999);
        CGSize stringSize = [message sizeWithFont:messageFont constrainedToSize:tallerSize lineBreakMode:NSLineBreakByWordWrapping];
        
        
        [help.contentView setFrame:CGRectMake(0, 0, 320, stringSize.height)];
        [help setFrame:help.contentView.frame];
        help.selectionStyle = UITableViewCellSelectionStyleNone;
        help.editingAccessoryView = UITableViewCellEditingStyleNone;
        help.editingAccessoryType = UITableViewCellEditingStyleNone;
        help.shouldIndentWhileEditing = NO;
        
        UIImageView *helpImage = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 320, stringSize.height)];
        NSString *helpImagePath = [[NSBundle mainBundle] pathForResource:@"Arrow-Up" ofType:@"png"];
        helpImage.image = [UIImage imageWithContentsOfFile:helpImagePath];
        helpImage.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        [help.contentView addSubview:helpImage];
        
        UITextView *helpText = [[UITextView alloc] initWithFrame:CGRectMake(0, 0, messageWidth, stringSize.height)];
        helpText.textColor = [UIColor blackColor];
        helpText.backgroundColor = [UIColor whiteColor];
        helpText.font = messageFont;
        helpText.editable = NO;
        helpText.scrollEnabled = NO;
        helpText.text = message;
        helpText.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
        [help.contentView addSubview:helpText];

        
        return help;
    }
    
    static NSString *CellIdentifier = @"Cell";
    
    
    // Dequeue or create a new cell
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        // cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }

    [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
    
    
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
    
}


/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/


- (void)deleteCollection:(NSManagedObjectID*)objectID {
    NSManagedObjectContext *tempMOC = [FlashCardsCore tempMOC];
    int i = 0;
    int indexToDelete = -1;
    for (FCCollection *c in collections) {
        if ([[c objectID] isEqual:objectID]) {
            indexToDelete = i;
            break;
        }
        i++;
    }

    [tempMOC performBlockAndWait:^{
        dispatch_async(dispatch_get_main_queue(), ^{
        //    [self.myTableView beginUpdates];
        });
        NSManagedObject *objectToDelete = [tempMOC objectWithID:objectID];
        FCCollection *collectionToDelete = (FCCollection*)objectToDelete;
        for (FCCard *cardToDelete in [collectionToDelete allCardsIncludingDeletedOnes]) {
            [tempMOC deleteObject:cardToDelete];
        }
        [tempMOC deleteObject:objectToDelete];
        [tempMOC save:nil];
        [FlashCardsCore saveMainMOC:YES];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (indexToDelete >= 0) {
                [collections removeObjectAtIndex:indexToDelete];
            //    [self.myTableView deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:indexToDelete inSection:0]]
            //                            withRowAnimation:UITableViewRowAnimationFade];
            }
            [self.myTableView reloadData];
        });
    }];

}

// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        FCCollection *collectionToDelete = [collections objectAtIndex:indexPath.row];
        NSManagedObjectID *objectId = [collectionToDelete objectID];
        if (!HUD) {
            HUD = [[MBProgressHUD alloc] initWithView:self.view];
            
            // Add HUD to screen
            [self.view addSubview:HUD];
            
            // Regisete for HUD callbacks so we can remove it from the window at the right time
            HUD.delegate = self;
        }
        HUD.minShowTime = 1.0;
        HUD.labelText = NSLocalizedStringFromTable(@"Saving", @"Import", @"HUD");
        [HUD showWhileExecuting:@selector(deleteCollection:) onTarget:self withObject:objectId animated:YES];
    }
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}


/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/


// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return NO;
}


#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // Navigation logic may go here. Create and push another view controller.
    
    if (indexPath.row >= [collections count]) {
        return;
    }
    
    CollectionViewViewController *collectionView = [[CollectionViewViewController alloc] initWithNibName:@"CollectionViewViewController" bundle:nil];
    collectionView.collection = [collections objectAtIndex:indexPath.row];

    collectionView.cardsDue = 0;
    if ([cardsDueCountDict objectForKey:[collectionView.collection objectID]]) {
        collectionView.cardsDue = [[cardsDueCountDict objectForKey:[collectionView.collection objectID]] intValue];
    }
    
    // Pass the selected object to the new view controller.
    [self.navigationController pushViewController:collectionView animated:YES];
}
#pragma mark -
#pragma mark Fetched results controller delegate

- (void) editEvent {
    if (self.myTableView.editing) {
        [self.myTableView setEditing:NO animated:YES];
        UIBarButtonItem *editButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(editEvent)];
        editButton.enabled = ([collections count] > 0);
        NSMutableArray *rightBarButtonItems = [NSMutableArray arrayWithArray:[self.navigationItem rightBarButtonItems]];
        [rightBarButtonItems setObject:editButton atIndexedSubscript:1];
        [self.navigationItem setRightBarButtonItems:rightBarButtonItems animated:NO];
    } else {
        if ([collections count] == 0) {
            return;
        }
        [self.myTableView setEditing:YES animated:YES];
        UITableViewCell *helpCell = [self.myTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:[collections count] inSection:0]];
        helpCell.editing = NO;
        UIBarButtonItem *editButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(editEvent)];
        editButton.enabled = YES;

        NSMutableArray *rightBarButtonItems = [NSMutableArray arrayWithArray:[self.navigationItem rightBarButtonItems]];
        [rightBarButtonItems setObject:editButton atIndexedSubscript:1];
        [self.navigationItem setRightBarButtonItems:rightBarButtonItems animated:NO];
    }
}

#pragma mark -
#pragma mark Memory management

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Relinquish ownership any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
    // Relinquish ownership of anything that can be recreated in viewDidLoad or on demand.
    // For example: self.myOutlet = nil;
    
    [[NSNotificationCenter defaultCenter]
     removeObserver:self
     name:NSPersistentStoreCoordinatorStoresDidChangeNotification
     object:[[FlashCardsCore mainMOC] persistentStoreCoordinator]];
    

    [super viewDidUnload];

}




@end

