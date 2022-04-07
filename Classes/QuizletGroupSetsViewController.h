//
//  QuizletGroupSetsViewController.h
//  FlashCards
//
//  Created by Jason Lustig on 4/13/11.
//  Copyright 2011-2014 Jason Lustig Lustig. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "FCSetsTableViewController.h"
#import "QuizletLoginController.h"
#import "MBProgressHUD.h"

@class FCCardSet;
@class FCCollection;

@interface QuizletGroupSetsViewController : FCSetsTableViewController <UITableViewDelegate, FCRestClientDelegate, MBProgressHUDDelegate, UIAlertViewDelegate, QuizletLoginControllerDelegate>

- (void)reloadCardSets;
- (void)setJoinButtonText;
- (IBAction)joinButtonPressed:(id)sender;
- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath;

-(IBAction)importAllSets:(id)sender;
-(IBAction)importSelectedSets:(id)sender;

@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@property (nonatomic, strong) ImportGroup *group;

@property (nonatomic, weak) IBOutlet UIToolbar *joinGroupToolbar;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *joinGroupButton;

@property (nonatomic, assign) bool alertedUserFlashcardsServerAPINotAvailable;

@property (nonatomic, strong) NSDateFormatter *dateStringFormatter;

@property (nonatomic, strong) QuizletRestClient *restClient;
@property (nonatomic, strong) MBProgressHUD *HUD;
@property (nonatomic, strong) NSIndexPath *selectedIndexPath;

@property (nonatomic, weak) IBOutlet UIToolbar *pseudoEditToolbar;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *importAllSetsButton;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *importSelectedSetsButton;

@end
