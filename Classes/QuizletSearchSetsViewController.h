//
//  QuizletSearchSetsViewController.h
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
@class FCSetsTableViewController;

@interface QuizletSearchSetsViewController : FCSetsTableViewController <UITableViewDelegate, UISearchDisplayDelegate, UISearchBarDelegate, UIAlertViewDelegate, FCRestClientDelegate, MBProgressHUDDelegate, QuizletLoginControllerDelegate>

- (IBAction)cancelUpdateSearch:(id)sender;
- (void) updateSearch;
- (void) updateSearchWithPageNumber:(int)pageNumber;
- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath;

-(IBAction)togglePseudoEditMode:(id)sender;
-(IBAction)importAllSets:(id)sender;
-(IBAction)importSelectedSets:(id)sender;

@property (nonatomic, strong) NSMutableArray *myCardSets;
@property (nonatomic, strong) NSString *savedSearchTerm;
@property (nonatomic, assign) int savedScopeButtonIndex;
@property (nonatomic, assign) BOOL searchIsActive;
@property (nonatomic, weak) IBOutlet UISearchBar *theSearchBar;

@property (nonatomic, strong) NSDateFormatter *dateFormatter;

@property (nonatomic, strong) IBOutlet UITableViewCell *loadingCell;
@property (nonatomic, weak) IBOutlet UIActivityIndicatorView *loadingCellActivityIndicator;
@property (nonatomic, weak) IBOutlet UILabel *loadingLabel;
@property (nonatomic, weak) IBOutlet UIButton *loadingCancelButton;

@property (nonatomic, assign) int currentPageNumber;
@property (nonatomic, assign) int numberSetsTotal;
@property (nonatomic, assign) int numberSetsLoaded;
@property (nonatomic, assign) bool isLoadingNextPage;
@property (nonatomic, assign) bool connectionIsLoading;
@property (nonatomic, assign) bool hasStartedSearch;
@property (nonatomic, assign) bool alertedUserFlashcardsServerAPINotAvailable;

@property (nonatomic, strong) NSDateFormatter *dateStringFormatter;

@property (nonatomic, strong) FCRestClient *restClient;
@property (nonatomic, strong) MBProgressHUD *HUD;
@property (nonatomic, strong) NSIndexPath *selectedIndexPath;

@property (nonatomic, weak) IBOutlet UIToolbar *pseudoEditToolbar;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *importAllSetsButton;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *importSelectedSetsButton;


@end
