//
//  StudentFinishViewController.h
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

@interface StudentFinishViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, MBProgressHUDDelegate, UITextFieldDelegate>

- (void)setTableFooter;
- (IBAction)createAccountButtonPressed:(id)sender;

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

@property (nonatomic, strong) id currentFirstResponder;

@property (nonatomic, strong) MBProgressHUD *HUD;

@property (nonatomic, strong) NSString* subscriptionCode;
@property (nonatomic, strong) NSString* subscriptionPassword;

@end
