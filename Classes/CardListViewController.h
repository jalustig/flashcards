//
//  CardListViewController.h
//  FlashCards
//
//  Created by Jason Lustig on 5/28/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "MBProgressHUD.h"

#import "FCSyncViewController.h"
#import "SyncController.h"

@class FCCardSet;
@class FCCollection;
@protocol MBProgressHUDDelegate;
@class MBProgressHUD;

@interface CardListViewController : FCSyncViewController <UITableViewDelegate, NSFetchedResultsControllerDelegate, UISearchDisplayDelegate, UISearchBarDelegate, UIAlertViewDelegate, MBProgressHUDDelegate, SyncControllerDelegate>

- (void) showEditDoneButton:(BOOL)yesno;
- (void) addEvent;
- (void) editEvent;
- (void) editDoneEvent;
- (void) setCardCountTitle;
- (IBAction) displayDuplicates:(id)sender;
- (void) findDuplicateCards;
- (void) deleteCard:(NSIndexPath *)indexPath;
- (void) removeCardFromCardSet:(NSIndexPath *)indexPath;

- (void)checkDeletedCardsForSync;
- (void)sync;
- (void)isDoneSaving;

- (void)tableView:(UITableView*)tableView configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath;
- (NSFetchedResultsController *) activeResultsControllerForTableView: (UITableView *)tableView;
- (NSFetchedResultsController *) buildFetchedResultsController: (NSString *)cacheName;

- (IBAction)displayOptionsDidTouchUpInside:(id)sender;

@property (nonatomic, strong) FCCardSet *cardSet;
@property (nonatomic, strong) FCCollection *collection;

@property (nonatomic, copy) NSString *savedSearchTerm;
@property (nonatomic, assign) BOOL searchIsActive;
@property (nonatomic, assign) BOOL viewAlphabetical;
@property (nonatomic, strong) NSMutableArray *duplicatesListContent;

@property (nonatomic, strong) NSFetchedResultsController *fetchedResultsController;
@property (nonatomic, strong) NSFetchedResultsController *searchResultsController;

@property (nonatomic, weak) IBOutlet UITableView *myTableView;

@property (nonatomic, weak) IBOutlet UISegmentedControl *displayOptions;

@property (nonatomic) NSIndexPath *cardToDeleteIndexPath;

@property (nonatomic, strong) MBProgressHUD *HUD;
@property (nonatomic, strong) NSMutableArray *cardsDeleted;

@property (nonatomic, strong) NSMutableArray *cardsOrdered;
@property (nonatomic) int displayOptionSelected;

@property (nonatomic, assign) BOOL shouldSync;


@end
