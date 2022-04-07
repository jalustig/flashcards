//
//  AppLoginViewController.m
//  FlashCards
//
//  Created by Jason Lustig on 11/19/12.
//  Copyright (c) 2012 Jason Lustig. All rights reserved.
//

#import "AppLoginViewController.h"

#import "FlashCardsAppDelegate.h"
#import "InAppPurchaseManager.h"

#import "Swipeable.h"
#import "MBProgressHUD.h"
#import "JSONKit.h"
#import "UIDevice+IdentifierAddition.h"

#import "NSString+VerifyEmail.h"

#pragma mark CGRect Utility function
CGRect IASKCGRectSwap(CGRect rect) {
    CGRect newRect;
    newRect.origin.x = rect.origin.y;
    newRect.origin.y = rect.origin.x;
    newRect.size.width = rect.size.height;
    newRect.size.height = rect.size.width;
    return newRect;
}

@interface AppLoginViewController ()

@end

@implementation AppLoginViewController

@synthesize myTableView;
@synthesize emailCell, emailCell2;
@synthesize emailField, emailField2;
@synthesize passwordCell, passwordCell2;
@synthesize passwordField, passwordField2;
@synthesize createAccountButton, alreadyHaveAccountButton;
@synthesize isCreatingNewAccount;
@synthesize HUD;
@synthesize currentFirstResponder;
@synthesize textFields;
@synthesize textFieldsIndexPaths;

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

    [createAccountButton setTitle:NSLocalizedStringFromTable(@"Create Account", @"Subscription", @"UIButton") forState:UIControlStateNormal];
    [createAccountButton setTitle:NSLocalizedStringFromTable(@"Create Account", @"Subscription", @"UIButton") forState:UIControlStateSelected];
    
    [alreadyHaveAccountButton setTitle:NSLocalizedStringFromTable(@"I already have an account", @"Subscription", @"UIButton") forState:UIControlStateNormal];
    [alreadyHaveAccountButton setTitle:NSLocalizedStringFromTable(@"I already have an account", @"Subscription", @"UIButton") forState:UIControlStateSelected];
    
    [myTableView setResignObjectsOnTouchesEnded:@[emailField, emailField2, passwordField, passwordField2]];
    [self setTableFooter];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
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
    if (isCreatingNewAccount) {
        self.title = NSLocalizedStringFromTable(@"Create Account", @"Subscription", @"");
        textFields = @[emailField, emailField2, passwordField, passwordField2];
        textFieldsIndexPaths = @[[NSIndexPath indexPathForRow:0 inSection:0],
                                 [NSIndexPath indexPathForRow:1 inSection:0],
                                 [NSIndexPath indexPathForRow:0 inSection:1],
                                 [NSIndexPath indexPathForRow:1 inSection:1]];
    } else {
        self.title = NSLocalizedStringFromTable(@"Log In", @"FlashCards", @"");
        textFields = @[emailField, passwordField];
        textFieldsIndexPaths = @[[NSIndexPath indexPathForRow:0 inSection:0],
                                 [NSIndexPath indexPathForRow:1 inSection:0]];

        [createAccountButton setTitle:NSLocalizedStringFromTable(@"Log In", @"FlashCards", @"UIButton") forState:UIControlStateNormal];
        [createAccountButton setTitle:NSLocalizedStringFromTable(@"Log In", @"FlashCards", @"UIButton") forState:UIControlStateSelected];

        [alreadyHaveAccountButton setTitle:NSLocalizedStringFromTable(@"I Forgot My Password", @"Subscription", @"UIButton") forState:UIControlStateNormal];
        [alreadyHaveAccountButton setTitle:NSLocalizedStringFromTable(@"I Forgot My Password", @"Subscription", @"UIButton") forState:UIControlStateSelected];
        
        [emailField becomeFirstResponder];
    }
    int i = 0;
    for (UITextField *field in textFields) {
        [field setTag:i];
        [field setReturnKeyType:UIReturnKeyNext];
        i++;
    }
    [(UITextField*)[textFields lastObject] setReturnKeyType:UIReturnKeyDone];

    [self.myTableView reloadData];
}
- (IBAction)alreadyHaveAccountButtonPressed:(id)sender {
    if (isCreatingNewAccount) {
        isCreatingNewAccount = NO;
        [self setTableFooter];
    } else {
        [self forgotPassword];
    }
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
        // create the account:
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/user/register", flashcardsServer]];
        ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
        __block ASIFormDataRequest *requestBlock = request;
        [request setupFlashCardsAuthentication:@"user/register"];
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
            [[[FlashCardsCore appDelegate] inAppPurchaseManager] exitSubscriptionScreen:isCreatingNewAccount hasCreatedSync:hasCreatedSync];
        }];
        [request startAsynchronous];
        [self showHUD];
    } else {
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
            [[[FlashCardsCore appDelegate] inAppPurchaseManager] exitSubscriptionScreen:isCreatingNewAccount hasCreatedSync:hasCreatedSync];
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
        return 2;
    } else {
        return 1;
    }
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 2;
}

- (NSString*)loginExplanation {
    if (isCreatingNewAccount) {
        return NSLocalizedStringFromTable(@"Create a FlashCards++ account to use your Subscription on your personal devices. We will not share your email address.", @"Subscription", @"");
    } else {
        return NSLocalizedStringFromTable(@"Already have a FlashCards++ subscription? Log in to activate your subscription.", @"Subscription", @"");
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
    if (isCreatingNewAccount) {
        if (indexPath.section == 0) {
            if (indexPath.row == 0) {
                return emailCell;
            } else {
                return emailCell2;
            }
        } else {
            if (indexPath.row == 0) {
                return passwordCell;
            } else {
                return passwordCell2;
            }
        }
    } else {
        if (indexPath.row == 0) {
            return emailCell;
        } else {
            return passwordCell;
        }
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
            windowRect = IASKCGRectSwap(windowRect);
        }
        CGRect viewRectAbsolute = [self.myTableView convertRect:self.myTableView.bounds toView:[[UIApplication sharedApplication] keyWindow]];
        if (UIInterfaceOrientationLandscapeLeft == self.interfaceOrientation ||UIInterfaceOrientationLandscapeRight == self.interfaceOrientation ) {
            viewRectAbsolute = IASKCGRectSwap(viewRectAbsolute);
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
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textFields) {
        int tag = textField.tag;
        int nextFieldTag = tag + 1;
        if (nextFieldTag < [textFields count]) {
            UITextField *nextField = [textFields objectAtIndex:nextFieldTag];
            [nextField becomeFirstResponder];
            if (textFieldsIndexPaths) {
                if (nextFieldTag < [textFieldsIndexPaths count]) {
                    NSIndexPath *path = [textFieldsIndexPaths objectAtIndex:nextFieldTag];
                    [self.myTableView scrollToRowAtIndexPath:path
                                            atScrollPosition:UITableViewScrollPositionBottom
                                                    animated:YES];
                }
            }
        } else {
            [self createAccountButtonPressed:nil];
        }
    }
    return YES;
}

@end
