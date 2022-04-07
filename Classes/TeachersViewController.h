//
//  TeachersViewController.h
//  FlashCards
//
//  Created by Jason Lustig on 6/8/13.
//  Copyright (c) 2013 Jason Lustig. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "MBProgressHUD.h"
#import <MessageUI/MessageUI.h>


@interface TeachersViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, MBProgressHUDDelegate, MFMailComposeViewControllerDelegate>

- (IBAction)requestPromoCode:(id)sender;

@property (nonatomic, weak) IBOutlet UIBarButtonItem *requestPromoCodeButton;

@property (nonatomic, weak) IBOutlet UITableView *myTableView;
@property (nonatomic, strong) MBProgressHUD *HUD;
@property (nonatomic, strong) NSString *selectedProductId;
@property (nonatomic, assign) NSString *popupMessage;

@end
