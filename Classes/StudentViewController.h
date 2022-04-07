//
//  StudentViewController.h
//  FlashCards
//
//  Created by Jason Lustig on 6/11/13.
//  Copyright (c) 2013 Jason Lustig. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "MBProgressHUD.h"

@class MBProgressHUD;
@protocol MBProgressHUDDelegate;
@class ResignableTableView;

@interface StudentViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, MBProgressHUDDelegate, UITextFieldDelegate>

- (void)setTableFooter;
- (IBAction)alreadyHaveAccountButtonPressed:(id)sender;
- (IBAction)createAccountButtonPressed:(id)sender;

@property (nonatomic, weak) IBOutlet UITextField *emailField;
@property (nonatomic, weak) IBOutlet UITextField *passwordField;

@property (nonatomic, strong) IBOutlet UITableViewCell *emailCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *passwordCell;

@property (nonatomic, weak) IBOutlet ResignableTableView *myTableView;

@property (nonatomic, weak) IBOutlet UIButton *createAccountButton;
@property (nonatomic, weak) IBOutlet UIButton *alreadyHaveAccountButton;

@property (nonatomic, strong) id currentFirstResponder;

@property (nonatomic, assign) BOOL hasExistingAccount;

@property (nonatomic, strong) MBProgressHUD *HUD;

@end
