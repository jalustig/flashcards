//
//  SubscriptionViewController.h
//  FlashCards
//
//  Created by Jason Lustig on 11/13/12.
//  Copyright (c) 2012 Jason Lustig. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "MBProgressHUD.h"

@class InAppPurchaseManager;
@class HelpViewController;

@interface SubscriptionViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, MBProgressHUDDelegate>

- (void)teacherButtonTapped;
- (IBAction)learnMore:(id)sender;
- (HelpViewController*)learnMoreViewController;
- (void)setHUDLabel:(NSString*)labelText;

@property (nonatomic, weak) IBOutlet UITableView *myTableView;
@property (nonatomic, strong) MBProgressHUD *HUD;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *learnMoreButton;
@property (nonatomic, strong) NSString *selectedProductId;
@property (nonatomic, assign) BOOL showTrialEndedPopup;
@property (nonatomic, assign) BOOL giveTrialOption;
@property (nonatomic, assign) BOOL explainSync;
@property (nonatomic, assign) BOOL cancelAlsoCancelsPreviousActivity;
@property (nonatomic, assign) NSString *popupMessage;


@end
