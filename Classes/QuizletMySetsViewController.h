//
//  QuizletMySetsViewController.h
//  FlashCards
//
//  Created by Jason Lustig on 7/27/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "FCSetsTableViewController.h"
#import "QuizletLoginController.h"
#import "MBProgressHUD.h"

@class FCCardSet;
@class FCCollection;

@interface QuizletMySetsViewController : FCSetsTableViewController <UITableViewDelegate, FCRestClientDelegate, MBProgressHUDDelegate, UIAlertViewDelegate, QuizletLoginControllerDelegate>

- (void)setLoginButtonText;
- (IBAction)loginButtonPressed:(id)sender;
- (IBAction)refreshDataAndSaveUsername:(id)sender;
- (IBAction)cancelRefreshData:(id)sender;
- (IBAction)didEndEditingQuizletUsernameField:(id)sender;

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath;
- (void) loadCardSets;
- (void) loadCardSetsWithPageNumber:(int)pageNumber;

-(IBAction)importAllSets:(id)sender;
-(IBAction)importSelectedSets:(id)sender;

@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@property (nonatomic, strong) NSMutableArray *myCardSets;
@property (nonatomic, weak) IBOutlet UITextField *quizletUsernameField;
@property (nonatomic, strong) IBOutlet UITableViewCell *loadingCell;
@property (nonatomic, weak) IBOutlet UIActivityIndicatorView *loadingCellActivityIndicator;

@property (nonatomic, weak) IBOutlet UILabel *loadingLabel;
@property (nonatomic, weak) IBOutlet UIButton *loadingCancelButton;

@property (nonatomic, weak) IBOutlet UIToolbar *loginNavigationBar;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *loginToAccessPrivateCardSetsButton;

@property (nonatomic, assign) int currentPageNumber;
@property (nonatomic, assign) int numberSetsTotal;
@property (nonatomic, assign) int numberSetsLoaded;
@property (nonatomic, assign) bool isLoadingNextPage;

@property (nonatomic, assign) BOOL hasStartedSearch;
@property (nonatomic, assign) bool connectionIsLoading;
@property (nonatomic, assign) bool alertedUserFlashcardsServerAPINotAvailable;

@property (nonatomic, strong) NSDateFormatter *dateStringFormatter;

@property (nonatomic, strong) QuizletRestClient *restClient;
@property (nonatomic, strong) MBProgressHUD *HUD;
@property (nonatomic, strong) NSIndexPath *selectedIndexPath;

@property (nonatomic, weak) IBOutlet UIToolbar *pseudoEditToolbar;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *importAllSetsButton;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *importSelectedSetsButton;

@end
