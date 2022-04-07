//
//  CollectionViewViewController.h
//  FlashCards
//
//  Created by Jason Lustig on 5/27/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MBProgressHUD.h"

#import "FCSyncViewController.h"
#import "SyncController.h"

@class FCCollection;
@class MBProgressHUD;

@interface CollectionViewViewController : FCSyncViewController <UITableViewDelegate, NSFetchedResultsControllerDelegate, MBProgressHUDDelegate, UIAlertViewDelegate, UIActionSheetDelegate, SyncControllerDelegate>

- (void)editEvent;
- (void)updateCardsDueCount;
- (void)updateTableFooter;

- (IBAction)createCards:(id)sender;
- (IBAction)statistics:(id)sender;
- (IBAction)share:(id)sender;

- (IBAction)viewOnWebsite:(id)sender;

@property (nonatomic, weak) IBOutlet UITableView *myTableView;

@property (nonatomic, strong) FCCollection *collection;
@property (nonatomic, assign) int cardsDue;
@property (nonatomic, assign) int cardsLapsed;

@property (nonatomic, strong) NSMutableArray* tableListGroups;

@property (nonatomic, strong) NSFetchedResultsController *fetchedResultsController;

@property (nonatomic, strong) MBProgressHUD *HUD;
@property (nonatomic, assign) BOOL isBuildingExportFile;
@property (nonatomic, strong) NSString *savedFileName;

@property (nonatomic, weak) IBOutlet UIToolbar *bottomBar;
@property (nonatomic, weak) IBOutlet UIButton *createCardsButton;
@property (nonatomic, weak) IBOutlet UIButton *createCardsButton2;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *statisticsButton;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *shareButton;

@property (nonatomic, strong) IBOutlet UIView *tableFooterUpload;

@property (nonatomic, weak) IBOutlet UIButton *viewOnWebsiteButton;
@property (nonatomic, weak) IBOutlet UILabel *syncsWithLabel;
@property (nonatomic, strong) IBOutlet UIView *tableFooterSync;

@property (nonatomic, weak) IBOutlet UIImageView *quizletImage;

@property (nonatomic, assign) BOOL shouldSync;

@end
