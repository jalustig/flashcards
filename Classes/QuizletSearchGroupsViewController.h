//
//  QuizletSearchGroupsViewController.h
//  FlashCards
//
//  Created by Jason Lustig on 4/14/11.
//  Copyright 2011-2014 Jason Lustig Lustig. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "FCSetsTableViewController.h"
#import "QuizletLoginController.h"
#import "MBProgressHUD.h"

@class FCCardSet;
@class FCCollection;
@class FCSetsTableViewController;

@interface QuizletSearchGroupsViewController : FCSetsTableViewController <UITableViewDelegate, UISearchDisplayDelegate, UISearchBarDelegate, UIAlertViewDelegate, FCRestClientDelegate, MBProgressHUDDelegate, QuizletLoginControllerDelegate>

- (void)setLoginButtonText;
- (IBAction)loginButtonPressed:(id)sender;

- (IBAction)cancelUpdateSearch:(id)sender;
- (void) updateSearch;
- (void) updateSearchWithPageNumber:(int)pageNumber;
- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath;

@property (nonatomic, strong) NSMutableArray *myCardSets;
@property (nonatomic, strong) NSString *savedSearchTerm;
@property (nonatomic, assign) BOOL searchIsActive;
@property (nonatomic, weak) IBOutlet UISearchBar *theSearchBar;

@property (nonatomic, strong) NSDateFormatter *dateFormatter;

@property (nonatomic, strong) IBOutlet UITableViewCell *loadingCell;
@property (nonatomic, weak) IBOutlet UIActivityIndicatorView *loadingCellActivityIndicator;
@property (nonatomic, weak) IBOutlet UILabel *loadingLabel;
@property (nonatomic, weak) IBOutlet UIButton *loadingCancelButton;

@property (nonatomic, weak) IBOutlet UIBarButtonItem *loginToAccessPrivateGroupsButton;

@property (nonatomic, assign) int currentPageNumber;
@property (nonatomic, assign) int numberSetsTotal;
@property (nonatomic, assign) int numberSetsLoaded;
@property (nonatomic, assign) bool isLoadingNextPage;
@property (nonatomic, assign) bool connectionIsLoading;
@property (nonatomic, assign) bool hasStartedSearch;
@property (nonatomic, assign) bool alertedUserFlashcardsServerAPINotAvailable;

@property (nonatomic, strong) NSDateFormatter *dateStringFormatter;

@property (nonatomic, strong) QuizletRestClient *restClient;
@property (nonatomic, strong) MBProgressHUD *HUD;
@property (nonatomic, strong) NSIndexPath *selectedIndexPath;

@end
