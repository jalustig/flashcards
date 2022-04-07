//
//  CardSetImportViewController.h
//  FlashCards
//
//  Created by Jason Lustig on 6/2/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "MBProgressHUD.h"

#import "QuizletSync.h"
#import "SyncController.h"

@class FCCardSet;
@class FCCard;
@class FCCollection;
@protocol SyncControllerDelegate;
@class MBProgressHUD;

@interface CardSetImportViewController : UIViewController <UIAlertViewDelegate, UITableViewDelegate, MBProgressHUDDelegate, ImportSetDelegate, SyncControllerDelegate, FCRestClientDelegate>

- (BOOL)isLoggedIn;
- (NSString*)username;

// Download functions:
- (void)checkInternetStatus;

// Quizlet functions
- (void)showImportButton;
- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath;
- (NSMutableArray*)cardSetCharacteristicsList:(ImportSet*)cardSetData;
- (BOOL)setsArePasswordProtected;

// Settings functions
- (void)filterTermsListByOptions;
- (IBAction)reverseCardsOptionSegmentedControlChanged:(id)sender;
- (IBAction)mergeExactDuplicatesOptionSwitchChanged:(id)sender;
- (IBAction)syncOptionSwitchChanged:(id)sender;
- (IBAction)syncOrderSwitchChanged:(id)sender;

// Event functions
- (void)cancelEvent;
- (void)clearCardSetActionData;

// Import functions
- (bool)importCardSet;
- (void)finishDuplicates:(ImportSet*)cardSetData;
- (bool)saveCards:(ImportSet*)cardSetData;
- (void)checkNumberCardsToAdd;

// Helper functions
- (NSString*)syncExplanationString;
- (BOOL)canSyncSets;
- (BOOL)canShowSyncOptions;

@property (nonatomic, strong) NSString *csvFilePath;
@property (nonatomic, strong) NSString *importMethod;
@property (nonatomic, strong) NSString *importFunction;

@property (nonatomic, assign) BOOL shouldImmediatelyImportTerms;
@property (nonatomic, assign) BOOL shouldImmediatelyPressImportButton;
@property (nonatomic, assign) BOOL hasCheckedIfCardSetWithIdExistsOnDevice;

// Quizlet Set View

@property (nonatomic, weak) IBOutlet UITableView *quizletSetTableView;

@property (nonatomic, strong) ImportSet *currentlyImportingSet;
@property (nonatomic, strong) NSMutableArray *allCardSets;

@property (nonatomic, strong) IBOutlet UITableViewCell *reverseCardsOptionTableViewCell;
@property (nonatomic, weak) IBOutlet UILabel *reverseCardsOptionLabel;
@property (nonatomic, weak) IBOutlet UISwitch *reverseCardsOptionSwitch;

@property (nonatomic, strong) IBOutlet UITableViewCell *checkDuplicatesOptionTableViewCell;
@property (nonatomic, weak) IBOutlet UILabel *checkDuplicatesOptionLabel;
@property (nonatomic, weak) IBOutlet UISwitch *checkDuplicatesOptionSwitch;

@property (nonatomic, strong) IBOutlet UITableViewCell *importAsSeparateSetsOptionTableViewCell;
@property (nonatomic, weak) IBOutlet UILabel *importAsSeparateSetsOptionLabel;
@property (nonatomic, weak) IBOutlet UISwitch *importAsSeparateSetsOptionSwitch;

@property (nonatomic, strong) IBOutlet UITableViewCell *mergeExactDuplicatesOptionTableViewCell;
@property (nonatomic, weak) IBOutlet UILabel *mergeExactDuplicatesOptionLabel;
@property (nonatomic, weak) IBOutlet UISwitch *mergeExactDuplicatesOptionSwitch;

@property (nonatomic, strong) IBOutlet UITableViewCell *resetStatisticsOfExactDuplicatesOptionTableViewCell;
@property (nonatomic, weak) IBOutlet UILabel *resetStatisticsOfExactDuplicatesOptionLabel;
@property (nonatomic, weak) IBOutlet UISwitch *resetStatisticsOfExactDuplicatesOptionSwitch;

@property (nonatomic, strong) IBOutlet UITableViewCell *keepSetInSyncOptionTableViewCell;
@property (nonatomic, weak) IBOutlet UILabel *keepSetInSyncOptionLabel;
@property (nonatomic, weak) IBOutlet UISwitch *keepSetInSyncOptionSwitch;

@property (nonatomic, strong) IBOutlet UITableViewCell *syncOrderTableViewCell;
@property (nonatomic, weak) IBOutlet UILabel *syncOrderLabel;
@property (nonatomic, weak) IBOutlet UISwitch *syncOrderSwitch;

@property (nonatomic, strong) IBOutlet UITableViewCell *subscribeOptionTableViewCell;
@property (nonatomic, weak) IBOutlet UILabel *subscribeOptionLabel;
@property (nonatomic, weak) IBOutlet UISwitch *subscribeOptionSwitch;


// Other variables

@property (nonatomic, strong) NSMutableArray *duplicateCards;

@property (nonatomic, assign) int popToViewControllerIndexSave;
@property (nonatomic, assign) int popToViewControllerIndexCancel;

@property (nonatomic, assign) int cardSetCreateMode;

@property (nonatomic, assign) BOOL matchCardSetDecisionGoesDirectlyToImport;
@property (nonatomic, strong) ImportSet *matchCardSetImportSet;
@property (nonatomic, strong) NSManagedObjectID *matchCardSetId;

@property (nonatomic, strong) NSManagedObjectID *cardSetId;
@property (nonatomic, strong) FCCardSet *cardSet;
@property (nonatomic, strong) NSManagedObjectID *collectionId;
@property (nonatomic, strong) FCCollection *collection;

@property (nonatomic, assign) bool isConnectedToInternet;
@property (nonatomic, assign) bool reverseFrontAndBackOfCards;
@property (nonatomic, assign) int initialNumCards;
@property (nonatomic, assign) int totalCardsSaved;
@property (nonatomic, assign) BOOL autoMergeIdenticalCards;

@property (nonatomic, strong) MBProgressHUD *HUD;

@end
