//
//  SubscriptionCodeSetupControllerViewController.m
//  FlashCards
//
//  Created by Jason Lustig on 11/19/12.
//  Copyright (c) 2012 Jason Lustig. All rights reserved.
//

#import "SubscriptionCodeSetupControllerViewController.h"

#import "FlashCardsAppDelegate.h"
#import "InAppPurchaseManager.h"

#import "Swipeable.h"
#import "MBProgressHUD.h"
#import "JSONKit.h"
#import "UIDevice+IdentifierAddition.h"

#import "NSString+VerifyEmail.h"

#pragma mark CGRect Utility function
CGRect IASKCGRectSwap_Sub(CGRect rect) {
    CGRect newRect;
    newRect.origin.x = rect.origin.y;
    newRect.origin.y = rect.origin.x;
    newRect.size.width = rect.size.height;
    newRect.size.height = rect.size.width;
    return newRect;
}

@interface SubscriptionCodeSetupControllerViewController ()

@end

@implementation SubscriptionCodeSetupControllerViewController

@synthesize myTableView;
@synthesize emailCell, emailCell2;
@synthesize emailField, emailField2;
@synthesize passwordCell, passwordCell2;
@synthesize passwordField, passwordField2;

@synthesize subscriptionCodeCell, subscriptionCodeCell2;
@synthesize subscriptionPasswordCell, subscriptionPasswordCell2;
@synthesize subscriptionCodeField, subscriptionCodeField2;
@synthesize subscriptionPasswordField, subscriptionPasswordField2;

@synthesize createAccountButton;
@synthesize isCreatingNewAccount;
@synthesize HUD;
@synthesize currentFirstResponder;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    [myTableView setResignObjectsOnTouchesEnded:@[emailField, emailField2, passwordField, passwordField2, subscriptionCodeField, subscriptionCodeField2, subscriptionPasswordField, subscriptionPasswordField2]];
    [self setTableFooter];
    
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(keyboardWillShow:)
     name:UIKeyboardWillShowNotification
     object:nil];
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(keyboardWillHide:)
     name:UIKeyboardWillHideNotification
     object:nil];
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

# pragma mark - Event methods

- (void)setTableFooter {
    self.title = NSLocalizedStringFromTable(@"Student Access", @"Subscription", @"");
    
    if (isCreatingNewAccount) {
        [createAccountButton setTitle:NSLocalizedStringFromTable(@"Create Account", @"Subscription", @"UIButton") forState:UIControlStateNormal];
        [createAccountButton setTitle:NSLocalizedStringFromTable(@"Create Account", @"Subscription", @"UIButton") forState:UIControlStateSelected];

        [emailField becomeFirstResponder];
    } else {
        [createAccountButton setTitle:NSLocalizedStringFromTable(@"Set Up Teacher Account", @"Subscription", @"UIButton") forState:UIControlStateNormal];
        [createAccountButton setTitle:NSLocalizedStringFromTable(@"Set Up Teacher Account", @"Subscription", @"UIButton") forState:UIControlStateSelected];
        
        // [subscriptionCodeField becomeFirstResponder];
    }
    
    [self.myTableView reloadData];
}

- (void)forgotPassword {
    if (![FlashCardsCore isConnectedToInternet]) {
        FCDisplayBasicErrorMessage(@"",
                                   NSLocalizedStringFromTable(@"You must be connected to the internet to create a new account or log in.", @"Error", @""));
        return;
    }
    if ([emailField.text length] == 0) {
        FCDisplayBasicErrorMessage(@"", NSLocalizedStringFromTable(@"Please enter an email address.", @"Subscription", @""));
        return;
    }
    
    if (![[emailField.text lowercaseString] isValidEmailAddress]) {
        FCDisplayBasicErrorMessage(@"", NSLocalizedStringFromTable(@"Please enter a valid email address.", @"Subscription", @""));
        return;
    }
    
    [emailField resignFirstResponder];
    [emailField2 resignFirstResponder];
    [passwordField resignFirstResponder];
    [passwordField2 resignFirstResponder];
    self.currentFirstResponder = nil;
    
    // try to log in:
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/user/forgotpassword", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request addPostValue:emailField.text forKey:@"email"];
    [request setCompletionBlock:^{
        [HUD hide:YES];
        NSDictionary *response = [requestBlock.responseData objectFromJSONData];
        NSLog(@"%@", requestBlock.responseString);
        if ([[response objectForKey:@"is_error"] boolValue]) {
            FCDisplayBasicErrorMessage(@"",
                                       [NSString stringWithFormat:NSLocalizedStringFromTable(@"Error: %@", @"Error", @""), [response valueForKey:@"error_message"]]
                                       );
            return;
        }
        FCDisplayBasicErrorMessage(@"",
                                   NSLocalizedStringFromTable(@"Your password reset request has been received. You will get an email in a few minutes with a link to reset your password.", @"Subscription", @""));
    }];
    [request startAsynchronous];
    [self showHUD];
}

-(IBAction)createAccountButtonPressed:(id)sender {
    if (![FlashCardsCore isConnectedToInternet]) {
        FCDisplayBasicErrorMessage(@"",
                                   NSLocalizedStringFromTable(@"You must be connected to the internet to create a new account or log in.", @"Error", @""));
        return;
    }
    if (isCreatingNewAccount) {
        if ([emailField.text length] == 0) {
            FCDisplayBasicErrorMessage(@"", NSLocalizedStringFromTable(@"Please enter an email address.", @"Subscription", @""));
            return;
        }
        if ([passwordField.text length] < 4) {
            FCDisplayBasicErrorMessage(@"", NSLocalizedStringFromTable(@"Please enter a password of at least 4 characters.", @"Subscription", @""));
            return;
        }
        if (![[emailField.text lowercaseString] isValidEmailAddress]) {
            FCDisplayBasicErrorMessage(@"", NSLocalizedStringFromTable(@"Please enter a valid email address.", @"Subscription", @""));
            return;
        }
    }
    
    if ([subscriptionCodeField.text length] < 8) {
        FCDisplayBasicErrorMessage(@"", NSLocalizedStringFromTable(@"The Student Code must be at least 8 characters in length.", @"Subscription", @""));
        return;
    }
    if ([subscriptionPasswordField.text length] < 8) {
        FCDisplayBasicErrorMessage(@"", NSLocalizedStringFromTable(@"The Student Password must be at least 8 characters in length.", @"Subscription", @""));
        return;
    }
    
    [emailField resignFirstResponder];
    [emailField2 resignFirstResponder];
    [passwordField resignFirstResponder];
    [passwordField2 resignFirstResponder];
    self.currentFirstResponder = nil;
    
    if (isCreatingNewAccount) {
        if (![emailField.text isEqualToString:emailField2.text]) {
            FCDisplayBasicErrorMessage(@"",
                                       NSLocalizedStringFromTable(@"Your email addresses do not match.", @"Subscription", @""));
            return;
        }
        if (![passwordField.text isEqualToString:passwordField2.text]) {
            FCDisplayBasicErrorMessage(@"",
                                       NSLocalizedStringFromTable(@"Your passwords do not match.", @"Subscription", @""));
            return;
        }
    }
    
    if (![subscriptionCodeField.text isEqualToString:subscriptionCodeField2.text]) {
        FCDisplayBasicErrorMessage(@"",
                                   NSLocalizedStringFromTable(@"The Student Codes do not match.", @"Subscription", @""));
        return;
    }
    if (![subscriptionPasswordField.text isEqualToString:subscriptionPasswordField2.text]) {
        FCDisplayBasicErrorMessage(@"",
                                   NSLocalizedStringFromTable(@"The Student Passwords do not match.", @"Subscription", @""));
        return;
    }
    
    
    if (isCreatingNewAccount) {
        // create the account:
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/user/register", flashcardsServer]];
        ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
        __block ASIFormDataRequest *requestBlock = request;
        [request setupFlashCardsAuthentication:@"user/register"];
        [request addPostValue:[emailField.text encryptWithKey:flashcardsServerSecondaryKeyEncryptionKey] forKey:@"email"];
        [request addPostValue:[passwordField.text encryptWithKey:flashcardsServerCallKeyEncryptionKey] forKey:@"password"];

        [request addPostValue:[subscriptionCodeField.text encryptWithKey:flashcardsServerSecondaryKeyEncryptionKey] forKey:@"subscription_code"];
        [request addPostValue:[subscriptionPasswordField.text encryptWithKey:flashcardsServerCallKeyEncryptionKey] forKey:@"subscription_password"];
        
        [request addPostValue:[[UIDevice currentDevice] uniqueDeviceIdentifier] forKey:@"device_id"];
        [request addPostValue:[[UIDevice currentDevice] advertisingIdentifier] forKey:@"device_adid"];
        [request setCompletionBlock:^{
            [HUD hide:YES];
            NSDictionary *response = [requestBlock.responseData objectFromJSONData];
            NSLog(@"%@", requestBlock.responseString);
            if ([[response objectForKey:@"is_error"] boolValue]) {
                FCDisplayBasicErrorMessage(@"",
                                           [NSString stringWithFormat:NSLocalizedStringFromTable(@"Error: %@", @"Error", @""), [response valueForKey:@"error_message"]]
                                           );
                return;
            }
            [FlashCardsCore login:response];
            FCDisplayBasicErrorMessage(@"", NSLocalizedStringFromTable(@"Your Teacher account has been set up. You can now use your personal password to log in on your other devices, and your students can use the Student Code and Password to unlock the app for themselves.", @"Subscription", @""));
            [[[FlashCardsCore appDelegate] inAppPurchaseManager] exitSubscriptionScreen];
        }];
        [request startAsynchronous];
        [self showHUD];
    } else {
        // try to log in:
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/user/teacher", flashcardsServer]];
        ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
        __block ASIFormDataRequest *requestBlock = request;
        [request setupFlashCardsAuthentication:@"user/teacher"];
        
        [request addPostValue:[subscriptionCodeField.text encryptWithKey:flashcardsServerSecondaryKeyEncryptionKey] forKey:@"subscription_code"];
        [request addPostValue:[subscriptionPasswordField.text encryptWithKey:flashcardsServerCallKeyEncryptionKey] forKey:@"subscription_password"];
        
        [request addPostValue:[[UIDevice currentDevice] uniqueDeviceIdentifier] forKey:@"device_id"];
        [request addPostValue:[[UIDevice currentDevice] advertisingIdentifier] forKey:@"device_adid"];
        [request setCompletionBlock:^{
            [HUD hide:YES];
            NSDictionary *response = [requestBlock.responseData objectFromJSONData];
            NSLog(@"%@", requestBlock.responseString);
            if ([[response objectForKey:@"is_error"] boolValue]) {
                FCDisplayBasicErrorMessage(@"",
                                           [NSString stringWithFormat:NSLocalizedStringFromTable(@"Error: %@", @"Error", @""), [response valueForKey:@"error_message"]]
                                           );
                return;
            }
            [FlashCardsCore login:response];
            FCDisplayBasicErrorMessage(@"", NSLocalizedStringFromTable(@"Your Teacher account has been set up. Your students can use the Student Code and Password to unlock the app for themselves.", @"Subscription", @""));
            [[[FlashCardsCore appDelegate] inAppPurchaseManager] exitSubscriptionScreen];
        }];
        [request startAsynchronous];
        [self showHUD];
    }
}


#pragma mark -
#pragma mark MBProgressHUDDelegate methods

- (void)hudWasHidden:(MBProgressHUD *)hud {
    FCLog(@"Hiding HUD");
    // Remove HUD from screen when the HUD was hidded
    [hud removeFromSuperview];
    hud = nil;
}

- (void)showHUD {
    HUD = [[MBProgressHUD alloc] initWithView:self.view];
    
    // Add HUD to screen
    [self.view addSubview:HUD];
    
    // Regisete for HUD callbacks so we can remove it from the window at the right time
    HUD.delegate = self;
    HUD.minShowTime = 1.0;
    [HUD show:YES];
    [HUD hide:YES afterDelay:30];
}

# pragma mark - UITableViewDelegate & UITableViewDataSource methods


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    if (isCreatingNewAccount) {
        return 4;
    } else {
        return 2;
    }
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 2;
}

- (NSString*)studentCodeExplanation {
    return NSLocalizedStringFromTable(@"The School Code should be something related to your school, e.g. the name of your school, the name of your class, or your name.", @"Subscription", @"");
}

- (NSString*)studentSetupExplanation {
    return NSLocalizedStringFromTable(@"Enter a School Code & Activation Passcode so that your students can activate their FlashCards++ licenses. This is NOT your personal username and password but an activation code you will provide to your students.", @"Subscription", @"");
}

- (NSString*)loginExplanation {
    return NSLocalizedStringFromTable(@"Create a FlashCards++ account for you personal Lifetime Subscription and to give access to FlashCards++ to your students.", @"Subscription", @"");
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (section == 1 || section == 3) {
        return 0.0f;
    }
    if (!isCreatingNewAccount) {
        section += 2;
    }
    if (section == 0) {
        return [FlashCardsCore explanationLabelHeightWithString:[self loginExplanation] inView:self.view];
    } else {
        return [FlashCardsCore explanationLabelHeightWithString:[self studentSetupExplanation] inView:self.view];
    }
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (section == 1 || section == 3) {
        return nil;
    }
    if (!isCreatingNewAccount) {
        section += 2;
    }
    if (section == 0) {
        return [FlashCardsCore explanationLabelViewWithString:[self loginExplanation] inView:self.view];
    } else {
        return [FlashCardsCore explanationLabelViewWithString:[self studentSetupExplanation] inView:self.view];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    if (section == 1 || section == 3) {
        return 0.0f;
    }
    if (!isCreatingNewAccount) {
        section += 2;
    }
    if (section == 2) {
        return [FlashCardsCore explanationLabelHeightWithString:[self studentCodeExplanation] inView:self.view];
    }
    return 0.0f;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    if (section == 1 || section == 3) {
        return nil;
    }
    if (!isCreatingNewAccount) {
        section += 2;
    }
    if (section == 2) {
        return [FlashCardsCore explanationLabelViewWithString:[self studentCodeExplanation] inView:self.view];
    }
    return nil;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    int section = indexPath.section;
    if (!isCreatingNewAccount) {
        section += 2;
    }
    NSArray *rows = @[
                      @[emailCell, emailCell2],
                      @[passwordCell, passwordCell2],
                      @[subscriptionCodeCell, subscriptionCodeCell2],
                      @[subscriptionPasswordCell, subscriptionPasswordCell2]
                      ];
    return [[rows objectAtIndex:section] objectAtIndex:indexPath.row];
}

#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // Navigation logic may go here. Create and push another view controller.
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
}

#pragma mark - Keyboard methods


// developed based on: http://stackoverflow.com/a/4430737/353137

- (void)keyboardWillShow:(NSNotification*)notification {
    if (self.navigationController.topViewController == self) {
        NSDictionary* userInfo = [notification userInfo];
        
        // we don't use SDK constants here to be universally compatible with all SDKs ≥ 3.0
        NSValue* keyboardFrameValue = [userInfo objectForKey:@"UIKeyboardBoundsUserInfoKey"];
        if (!keyboardFrameValue) {
            keyboardFrameValue = [userInfo objectForKey:@"UIKeyboardFrameEndUserInfoKey"];
        }
        
        // Reduce the tableView height by the part of the keyboard that actually covers the tableView
        CGRect windowRect = [[UIApplication sharedApplication] keyWindow].bounds;
        if (UIInterfaceOrientationLandscapeLeft == self.interfaceOrientation ||UIInterfaceOrientationLandscapeRight == self.interfaceOrientation ) {
            windowRect = IASKCGRectSwap_Sub(windowRect);
        }
        CGRect viewRectAbsolute = [self.myTableView convertRect:self.myTableView.bounds toView:[[UIApplication sharedApplication] keyWindow]];
        if (UIInterfaceOrientationLandscapeLeft == self.interfaceOrientation ||UIInterfaceOrientationLandscapeRight == self.interfaceOrientation ) {
            viewRectAbsolute = IASKCGRectSwap_Sub(viewRectAbsolute);
        }
        CGRect frame = self.myTableView.frame;
        frame.size.height -= [keyboardFrameValue CGRectValue].size.height - CGRectGetMaxY(windowRect) + CGRectGetMaxY(viewRectAbsolute);
        
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:[[userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue]];
        [UIView setAnimationCurve:[[userInfo objectForKey:UIKeyboardAnimationCurveUserInfoKey] intValue]];
        self.myTableView.frame = frame;
        [UIView commitAnimations];
        
        UITableViewCell *textFieldCell = (id)((UITextField *)self.currentFirstResponder).superview.superview;
        NSIndexPath *textFieldIndexPath = [self.myTableView indexPathForCell:textFieldCell];
        
        // iOS 3 sends hide and show notifications right after each other
        // when switching between textFields, so cancel -scrollToOldPosition requests
        [NSObject cancelPreviousPerformRequestsWithTarget:self];
        
        [self.myTableView scrollToRowAtIndexPath:textFieldIndexPath atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
    }
}

- (void) scrollToOldPosition {
    // [self.myTableView scrollToRowAtIndexPath:_topmostRowBeforeKeyboardWasShown atScrollPosition:UITableViewScrollPositionTop animated:YES];
}

- (void)keyboardWillHide:(NSNotification*)notification {
    if (self.navigationController.topViewController == self) {
        NSDictionary* userInfo = [notification userInfo];
        
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:[[userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue]];
        [UIView setAnimationCurve:[[userInfo objectForKey:UIKeyboardAnimationCurveUserInfoKey] intValue]];
        self.myTableView.frame = self.view.bounds;
        [UIView commitAnimations];
        
        [self performSelector:@selector(scrollToOldPosition) withObject:nil afterDelay:0.1];
    }
}

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
    self.currentFirstResponder = textField;
    return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    if (self.currentFirstResponder == textField) {
        self.currentFirstResponder = nil;
    }
}

@end
