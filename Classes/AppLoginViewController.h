//
//  AppLoginViewController.h
//  FlashCards
//
//  Created by Jason Lustig on 11/19/12.
//  Copyright (c) 2012 Jason Lustig. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "MBProgressHUD.h"

@class MBProgressHUD;
@protocol MBProgressHUDDelegate;
@class ResignableTableView;

@interface AppLoginViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, MBProgressHUDDelegate, UITextFieldDelegate>

- (void)setTableFooter;
- (IBAction)alreadyHaveAccountButtonPressed:(id)sender;
-(IBAction)createAccountButtonPressed:(id)sender;

@property (nonatomic, weak) IBOutlet UITextField *emailField;
@property (nonatomic, weak) IBOutlet UITextField *passwordField;

@property (nonatomic, weak) IBOutlet UITextField *emailField2;
@property (nonatomic, weak) IBOutlet UITextField *passwordField2;

@property (nonatomic, strong) IBOutlet UITableViewCell *emailCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *passwordCell;

@property (nonatomic, strong) IBOutlet UITableViewCell *emailCell2;
@property (nonatomic, strong) IBOutlet UITableViewCell *passwordCell2;

@property (nonatomic, weak) IBOutlet ResignableTableView *myTableView;

@property (nonatomic, weak) IBOutlet UIButton *createAccountButton;
@property (nonatomic, weak) IBOutlet UIButton *alreadyHaveAccountButton;

@property (nonatomic, strong) NSArray *textFields;
@property (nonatomic, strong) NSArray *textFieldsIndexPaths;

@property (nonatomic, strong) id currentFirstResponder;

@property (nonatomic, assign) BOOL isCreatingNewAccount;

@property (nonatomic, strong) MBProgressHUD *HUD;

@end
