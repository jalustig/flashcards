//
//  SubscriptionCodeSetupControllerViewController.h
//  FlashCards
//
//  Created by Jason Lustig on 6/10/13.
//  Copyright (c) 2013 Jason Lustig. All rights reserved.
//

#import <UIKit/UIKit.h>

@class MBProgressHUD;
@protocol MBProgressHUDDelegate;
@class ResignableTableView;

@interface SubscriptionCodeSetupControllerViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, MBProgressHUDDelegate, UITextFieldDelegate>

- (void)setTableFooter;
- (IBAction)createAccountButtonPressed:(id)sender;

@property (nonatomic, weak) IBOutlet UITextField *emailField;
@property (nonatomic, weak) IBOutlet UITextField *passwordField;

@property (nonatomic, weak) IBOutlet UITextField *emailField2;
@property (nonatomic, weak) IBOutlet UITextField *passwordField2;

@property (nonatomic, weak) IBOutlet UITextField *subscriptionCodeField;
@property (nonatomic, weak) IBOutlet UITextField *subscriptionPasswordField;

@property (nonatomic, weak) IBOutlet UITextField *subscriptionCodeField2;
@property (nonatomic, weak) IBOutlet UITextField *subscriptionPasswordField2;

@property (nonatomic, strong) IBOutlet UITableViewCell *emailCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *passwordCell;

@property (nonatomic, strong) IBOutlet UITableViewCell *emailCell2;
@property (nonatomic, strong) IBOutlet UITableViewCell *passwordCell2;

@property (nonatomic, strong) IBOutlet UITableViewCell *subscriptionCodeCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *subscriptionPasswordCell;

@property (nonatomic, strong) IBOutlet UITableViewCell *subscriptionCodeCell2;
@property (nonatomic, strong) IBOutlet UITableViewCell *subscriptionPasswordCell2;

@property (nonatomic, weak) IBOutlet ResignableTableView *myTableView;

@property (nonatomic, weak) IBOutlet UIButton *createAccountButton;

@property (nonatomic, strong) id currentFirstResponder;

@property (nonatomic, assign) BOOL isCreatingNewAccount;

@property (nonatomic, strong) MBProgressHUD *HUD;

@end
