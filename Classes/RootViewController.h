//
//  RootViewController.h
//  FlashCards
//
//  Created by Jason Lustig on 5/27/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MBProgressHUD.h"
#import "ImportCSV.h"
#import <MessageUI/MessageUI.h>

#import "QuizletSync.h"
#import "FCSyncViewController.h"

@class FCCollection;
@class FCCardSet;
@protocol ImportCSVDelegate;
@class Reachability;

@interface RootViewController : FCSyncViewController <UIAlertViewDelegate, UITableViewDelegate, MBProgressHUDDelegate, ImportCSVDelegate, UIActionSheetDelegate, QuizletSyncDelegate, MFMailComposeViewControllerDelegate, SyncControllerDelegate>

- (void)addEvent;
- (void)editEvent;

- (void)checkAddSyncButton;

- (IBAction)helpHelp:(id)sender;
- (IBAction)loadBackupView:(id)sender;
- (IBAction)loadSettingsView:(id)sender;
- (IBAction)followOnTwitter:(id)sender;

- (void)getQuizletAuthenticationToken;
- (void)quizletAuthenticationTokenReceived;

- (void)loadDataFromStore;
- (void)setupDataStore;

- (void)updateCardsDueCount;
- (void)goToGettingStarted;
- (void)askToViewGettingStartedTour;
- (BOOL)shouldDisplayHelpCell;
- (void)setTableShouldScroll;
- (void)reachabilityChanged:(NSNotification*)note;

- (IBAction)showActionSheet:(id)sender;
- (IBAction)sendLove:(id)sender;
- (IBAction)sendFeedback:(id)sender;
- (IBAction)importCards:(id)sender;
- (IBAction)automaticallySync:(id)sender;
- (IBAction)loadTeachersView:(id)sender;

- (void)checkUrl;
- (void)loadBackupFile:(NSURL*)fileUrl;
- (void)loadBackupFileAction;
- (void)saveCurrentBackupAction;

- (void)showBannerAd;

@property (nonatomic, assign) BOOL hasPromptedCreateAccount;
@property (nonatomic, assign) BOOL createDefaultData;
@property (nonatomic, assign) BOOL checkMasterCardSets;
@property (nonatomic, assign) BOOL isUpdatingData;
@property (nonatomic, assign) BOOL isLoadingRestoreData;
@property (nonatomic, assign) BOOL isUpdatingCardsDueCount;
@property (nonatomic, assign) BOOL isFirstLoad;

@property (nonatomic, assign) BOOL isAuthenticatingQuizlet;
@property (nonatomic, strong) NSString *quizletAuthenticationCode;

@property (nonatomic, assign) BOOL hasBegunGetImageIds;

@property (nonatomic, strong) NSURL *fileUrl;
@property (nonatomic, strong) NSMutableDictionary *fileData;


@property (nonatomic, weak) IBOutlet UITableView *myTableView;

@property (nonatomic, strong) NSMutableDictionary *cardsDueCountDict;

@property (nonatomic, strong) NSMutableArray *collections;

@property (nonatomic, weak) IBOutlet UIBarButtonItem *backupRestoreButton;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *settingsButton;
@property (nonatomic, weak) IBOutlet UIButton *teachersButton;

@property (nonatomic, weak) IBOutlet UIToolbar *bottomToolbar;

@property (nonatomic, weak) IBOutlet UIButton *sendFeedbackButton;
@property (nonatomic, weak) IBOutlet UIButton *importCardsButton;
@property (nonatomic, weak) IBOutlet UIButton *automaticallySyncButton;
@property (nonatomic, weak) IBOutlet UIButton *twitterButton;

@property (nonatomic, strong) MBProgressHUD *HUD;
@property (nonatomic, strong) Reachability *internetReach;

@end
