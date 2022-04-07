//
//  CardSetListViewController.h
//  FlashCards
//
//  Created by Jason Lustig on 5/28/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "MBProgressHUD.h"

#import "FCSyncViewController.h"
#import "SyncController.h"

@class FCCollection;
@class MBProgressHUD;
@protocol MBProgressHUDDelegate;

@interface CardSetListViewController : FCSyncViewController <UITableViewDelegate, NSFetchedResultsControllerDelegate, MBProgressHUDDelegate, SyncControllerDelegate>

- (void) addEvent;
- (void) editEvent;
- (void) editDoneEvent;
- (void) updateCardsDueCount;
- (IBAction)displayCardSetsOrderSegmentedControlDidTouchUpInside:(id)sender;

@property (nonatomic, strong) FCCollection *collection;
@property (nonatomic, strong) FCCardSet *deletedCardSet;
@property (nonatomic, strong) NSMutableDictionary *cardsDueCountDict;
@property (nonatomic, assign) int collectionCardsDueCount;
@property (nonatomic, assign) int displayCardSetsOrder;

@property (nonatomic, weak) IBOutlet UITableView *myTableView;
@property (nonatomic, weak) IBOutlet UISegmentedControl *displayCardSetsOrderSegmentedControl;

@property (nonatomic, strong) NSFetchedResultsController *fetchedResultsController;

@property (nonatomic, strong) MBProgressHUD *HUD;

@property (nonatomic, assign) BOOL shouldSync;

@end
