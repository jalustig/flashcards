//
//  CardListDuplicatesViewController.h
//  FlashCards
//
//  Created by Jason Lustig on 7/2/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "MBProgressHUD.h"

@class FCCardSet;
@class FCCollection;
@protocol MBProgressHUDDelegate;
@class MBProgressHUD;

@interface CardListDuplicatesViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, NSFetchedResultsControllerDelegate, UIAlertViewDelegate, MBProgressHUDDelegate>

- (void) setCardCountTitle;
- (IBAction) displayAllCards:(id)sender;
- (IBAction) helpEvent:(id)sender;
- (void) deleteCard:(NSIndexPath *)indexPath;
- (void) removeCardFromCardSet:(NSIndexPath *)indexPath;

- (void)checkDeletedCardsForSync;
- (void)isDoneSaving;

@property (nonatomic, weak) IBOutlet UITableView *tableView;
@property (nonatomic, weak) IBOutlet UIToolbar *duplicatesToolbar;

@property (nonatomic, strong) UIBarButtonItem *buttonEdit;
@property (nonatomic, strong) UIBarButtonItem *buttonDone;


@property (nonatomic, strong) NSMutableArray *cardList;
@property (nonatomic, strong) FCCardSet *cardSet;
@property (nonatomic, strong) FCCollection *collection;

@property (nonatomic, strong) NSFetchedResultsController *fetchedResultsController;

@property (nonatomic, weak) IBOutlet UIBarButtonItem *displayAllCardsButton;

@property (nonatomic, strong) NSIndexPath *cardToDeleteIndexPath;

@property (nonatomic, strong) MBProgressHUD *HUD;
@property (nonatomic, strong) NSMutableArray *cardsDeleted;


@end
