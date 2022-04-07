//
//  StudentViewController.m
//  FlashCards
//
//  Created by Jason Lustig on 6/11/13.
//  Copyright (c) 2013 Jason Lustig. All rights reserved.
//

#import "StudentViewController.h"

#import "FlashCardsAppDelegate.h"
#import "InAppPurchaseManager.h"
#import "StudentFinishViewController.h"

#import "Swipeable.h"
#import "MBProgressHUD.h"
#import "JSONKit.h"
#import "UIDevice+IdentifierAddition.h"

#import "NSString+VerifyEmail.h"

#pragma mark CGRect Utility function
CGRect IASKCGRectSwap3(CGRect rect) {
    CGRect newRect;
    newRect.origin.x = rect.origin.y;
    newRect.origin.y = rect.origin.x;
    newRect.size.width = rect.size.height;
    newRect.size.height = rect.size.width;
    return newRect;
}

@interface StudentViewController ()

@end

@implementation StudentViewController

@synthesize myTableView;
@synthesize emailCell;
@synthesize emailField;
@synthesize passwordCell;
@synthesize passwordField;
@synthesize createAccountButton, alreadyHaveAccountButton;
@synthesize hasExistingAccount;
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
    
    [myTableView setResignObjectsOnTouchesEnded:@[emailField, passwordField]];
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
    if (hasExistingAccount) {
        self.title = NSLocalizedStringFromTable(@"Log In", @"FlashCards", @"");

        [createAccountButton setTitle:NSLocalizedStringFromTable(@"Log In", @"FlashCards", @"UIButton") forState:UIControlStateNormal];
        [createAccountButton setTitle:NSLocalizedStringFromTable(@"Log In", @"FlashCards", @"UIButton") forState:UIControlStateSelected];
        
        [alreadyHaveAccountButton setTitle:NSLocalizedStringFromTable(@"I Forgot My Password", @"Subscription", @"UIButton") forState:UIControlStateNormal];
        [alreadyHaveAccountButton setTitle:NSLocalizedStringFromTable(@"I Forgot My Password", @"Subscription", @"UIButton") forState:UIControlStateSelected];
        
        [emailField setPlaceholder:NSLocalizedStringFromTable(@"Email Address", @"FlashCards", @"")];
        [passwordField setPlaceholder:NSLocalizedStringFromTable(@"Password", @"FlashCards", @"")];
    } else {
        self.title = NSLocalizedStringFromTable(@"Create Account", @"Subscription", @"");
        
        [createAccountButton setTitle:NSLocalizedStringFromTable(@"Create Account", @"Subscription", @"UIButton") forState:UIControlStateNormal];
        [createAccountButton setTitle:NSLocalizedStringFromTable(@"Create Account", @"Subscription", @"UIButton") forState:UIControlStateSelected];
        
        [alreadyHaveAccountButton setTitle:NSLocalizedStringFromTable(@"I already have an account", @"Subscription", @"UIButton") forState:UIControlStateNormal];
        [alreadyHaveAccountButton setTitle:NSLocalizedStringFromTable(@"I already have an account", @"Subscription", @"UIButton") forState:UIControlStateSelected];
        
        [emailField setPlaceholder:NSLocalizedStringFromTable(@"School Code", @"Subscription", @"")];
        [passwordField setPlaceholder:NSLocalizedStringFromTable(@"Activation Passcode", @"Subscription", @"")];
    }

    [self.myTableView reloadData];
}
- (IBAction)alreadyHaveAccountButtonPressed:(id)sender {
    if (hasExistingAccount) {
        [self forgotPassword];
    } else {
        [emailField setText:@""];
        [passwordField setText:@""];
        hasExistingAccount = YES;
    }
    [self setTableFooter];
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
    [passwordField resignFirstResponder];
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
    
    if ([FlashCardsCore getSettingBool:@"isTeacher"]) {
        FCDisplayBasicErrorMessage(@"",
                                   NSLocalizedStringFromTable(@"You currently are logged in to a Teacher account, and so cannot set up a Student account unless you log out.", @"Subscription", @""));
        return;
    }
    
    [emailField resignFirstResponder];
    [passwordField resignFirstResponder];
    self.currentFirstResponder = nil;
    
    if (hasExistingAccount) {
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
    } else {
        if ([emailField.text length] == 0) {
            FCDisplayBasicErrorMessage(@"", NSLocalizedStringFromTable(@"Please enter your School Code.", @"Subscription", @""));
            return;
        }
        if ([passwordField.text length] < 4) {
            FCDisplayBasicErrorMessage(@"", NSLocalizedStringFromTable(@"Please enter the Activation Passcode.", @"Subscription", @""));
            return;
        }
    }
    
    if (hasExistingAccount) {
        // try to log in:
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/user/login", flashcardsServer]];
        ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
        __block ASIFormDataRequest *requestBlock = request;
        [request setupFlashCardsAuthentication:@"user/login"];
        [request addPostValue:[emailField.text encryptWithKey:flashcardsServerSecondaryKeyEncryptionKey] forKey:@"email"];
        [request addPostValue:[passwordField.text encryptWithKey:flashcardsServerCallKeyEncryptionKey] forKey:@"password"];
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
            BOOL hasCreatedSync = [(NSNumber*)[response objectForKey:@"sync_created"] boolValue];
            BOOL isCreatingNewAccount = NO;
            [[[FlashCardsCore appDelegate] inAppPurchaseManager] exitSubscriptionScreen:isCreatingNewAccount hasCreatedSync:hasCreatedSync];
        }];
        [request startAsynchronous];
        [self showHUD];
    } else {

        
        // create the account:
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/user/studentcheck", flashcardsServer]];
        ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
        __block ASIFormDataRequest *requestBlock = request;
        [request setupFlashCardsAuthentication:@"user/studentcheck"];
        [request addPostValue:[emailField.text encryptWithKey:flashcardsServerSecondaryKeyEncryptionKey] forKey:@"subscription_code"];
        [request addPostValue:[passwordField.text encryptWithKey:flashcardsServerCallKeyEncryptionKey] forKey:@"subscription_password"];
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
            
            FCDisplayBasicErrorMessage(@"",
                                       NSLocalizedStringFromTable(@"School Code & Activation Passcode accepted. Please create a FlashCards++ account to activate FlashCards++.", @"Subscription", @""));
            
            StudentFinishViewController *vc = [[StudentFinishViewController alloc] initWithNibName:@"StudentFinishViewController" bundle:nil];
            vc.subscriptionCode = emailField.text;
            vc.subscriptionPassword = passwordField.text;
            [self.navigationController pushViewController:vc animated:YES];
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
    return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 2;
}

- (NSString*)loginExplanation {
    if (hasExistingAccount) {
        return NSLocalizedStringFromTable(@"Already have a FlashCards++ subscription? Log in to activate your subscription.", @"Subscription", @"");
    } else {
        return NSLocalizedStringFromTable(@"Create a FlashCards++ account to use your Subscription on your personal devices. We will not share your email address.", @"Subscription", @"");
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (section > 0) {
        return 0.0f;
    }
    return [FlashCardsCore explanationLabelHeightWithString:[self loginExplanation] inView:self.view];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (section > 0) {
        return nil;
    }
    return [FlashCardsCore explanationLabelViewWithString:[self loginExplanation] inView:self.view];
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == 0) {
        return emailCell;
    } else {
        return passwordCell;
    }
    return nil;
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
            windowRect = IASKCGRectSwap3(windowRect);
        }
        CGRect viewRectAbsolute = [self.myTableView convertRect:self.myTableView.bounds toView:[[UIApplication sharedApplication] keyWindow]];
        if (UIInterfaceOrientationLandscapeLeft == self.interfaceOrientation ||UIInterfaceOrientationLandscapeRight == self.interfaceOrientation ) {
            viewRectAbsolute = IASKCGRectSwap3(viewRectAbsolute);
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
