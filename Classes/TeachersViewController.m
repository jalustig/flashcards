//
//  SubscriptionViewController.m
//  FlashCards
//
//  Created by Jason Lustig on 6/8/12.
//  Copyright (c) 2013 Jason Lustig. All rights reserved.
//

#import "TeachersViewController.h"

#import "FlashCardsAppDelegate.h"
#import "InAppPurchaseManager.h"
#import "AppLoginViewController.h"

#import "UIAlertView+Blocks.h"

#import "HelpViewController.h"
#import "TeacherSubscriptionOptionCell.h"
#import "CardSetImportChoicesViewController.h"
#import "CardEditViewController.h"

#import "UIDevice+IdentifierAddition.h"

#import "RMStore.h"

#import "NSString+HTML.h"

@interface TeachersViewController ()

@end

@implementation TeachersViewController

@synthesize myTableView;
@synthesize HUD;
@synthesize selectedProductId;
@synthesize popupMessage;
@synthesize requestPromoCodeButton;

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
        
    [self.myTableView registerNib:[UINib nibWithNibName:@"TeacherSubscriptionCell" bundle:[NSBundle mainBundle]]
           forCellReuseIdentifier:@"TeacherCell"];
    
    self.title = NSLocalizedStringFromTable(@"Teacher Subscription", @"Subscription", @"");
    
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                  target:self
                                                                                  action:@selector(cancelEvent)];
    self.navigationItem.leftBarButtonItem = cancelButton;
    
    requestPromoCodeButton.title = NSLocalizedStringFromTable(@"Request Free Trial", @"Subscription", @"");
    
    if ([FlashCardsCore isConnectedToInternet]) {
        [self showHUD];
        NSSet *products = [NSSet setWithArray:@[kInAppPurchaseProUpgradeTeachers10,
                                                kInAppPurchaseProUpgradeTeachers25,
                                                kInAppPurchaseProUpgradeTeachers100]];
        [[RMStore defaultStore] requestProducts:products success:^(NSArray *products, NSArray *invalidProductIdentifiers) {
            FCLog(@"Products loaded");
            [self.HUD hide:YES];
            [self.myTableView reloadData];
        } failure:^(NSError *error) {
            FCLog(@"Something went wrong");
            FCLog(@"Error: %@", error);
            [self.HUD hide:YES];
            FCDisplayBasicErrorMessage(@"", [NSString stringWithFormat:@"Error connecting to App Store: %@", error.description]);
        }];
    }

    
    [Flurry logEvent:@"Subscription/TeacherPage"
      withParameters:@{
     @"HasInternetConnection" : [NSNumber numberWithBool:[FlashCardsCore isConnectedToInternet]]}];
}

- (void)viewWillDisappear:(BOOL)animated {
    if (HUD) {
        HUD.delegate = nil;
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

# pragma mark -
# pragma mark MFMailComposeViewControllerDelegate functions

- (void)mailComposeController:(MFMailComposeViewController*)controller
          didFinishWithResult:(MFMailComposeResult)result
                        error:(NSError*)error;
{
    if (result == MFMailComposeResultSent) {
        // thank the user for sending feedback:
        FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"Thank You", @"Feedback", @"UIAlert title"),
                                   NSLocalizedStringFromTable(@"Thank you for sending your message. We will be in touch shortly.", @"Feedback", @"message"));
        //    NSLog(@"It's away!");
    } else if (result == MFMailComposeResultFailed) {
        FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"Error", @"Error", @"UIAlert title"),
                                   [NSString stringWithFormat:NSLocalizedStringFromTable(@"An error occurred sending your message: %@ %@", @"Error", @"message"), error, [error userInfo]]);
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

# pragma mark - Event methods

- (IBAction)requestPromoCode:(id)sender {
    [self showForm:NO];
}

- (void)sendInquiry {
    [self showForm:YES];
}
- (void)showForm:(BOOL)isInquiry {
    /*
    QRootElement *root = [[QRootElement alloc] init];
    if (isInquiry) {
        root.title = NSLocalizedStringFromTable(@"FlashCards++ Inquiry", @"Feedback", @"");
    } else {
        root.title = NSLocalizedStringFromTable(@"FlashCards++ Trial Request", @"Feedback", @"");
    }
    root.grouped = YES;
    
    QSection *info = [[QSection alloc] init];
    UIView *headerView;
    if (isInquiry) {
        headerView = [FlashCardsCore explanationLabelViewWithString:@"Thanks for your interest in FlashCards++. I'm happy to work with educational institutions who are interested in using FlashCards++ on a large scale, thank you for being in touch. Please answer the following questions and to tell me about yourself and what you want to do with FlashCards++. --Jason, FlashCards++ developer"
                                                             inView:self.view];
    } else {
        headerView = [FlashCardsCore explanationLabelViewWithString:@"I'm happy to provide a free trial of FlashCards++ to teachers and educators. Please answer the following questions and I'll be in touch. --Jason, FlashCards++ developer"
                                                             inView:self.view];
    }

    [headerView setFrame:CGRectMake(headerView.frame.origin.x,
                                    headerView.frame.origin.y,
                                    headerView.frame.size.width,
                                    headerView.frame.size.height + 20)];
    [info setHeaderView:headerView];
    QEntryElement *name = [[QEntryElement alloc] initWithTitle:@"Your Name" Value:@""];
    [name setShowKeyboardOnAppear:YES];
    QEntryElement *institution = [[QEntryElement alloc] initWithTitle:@"Educational Institution" Value:@""];
    QEntryElement *position = [[QEntryElement alloc] initWithTitle:@"Your Position" Value:@""];
    
    [root addSection:info];
    [info addElement:name];
    [info addElement:institution];
    [info addElement:position];
    
    QSection *details = [[QSection alloc] init];
    QMultilineElement *tell = [[QMultilineElement alloc] initWithTitle:@"About yourself" value:@""];
    QMultilineElement *interest = [[QMultilineElement alloc] initWithTitle:@"Why are you interested in this app?" value:@""];
    QMultilineElement *questions = [[QMultilineElement alloc] initWithTitle:@"Any specific questions?" Value:@""];
    QMultilineElement *hear = [[QMultilineElement alloc] initWithTitle:@"Where did you hear about the app?" Value:@""];
    
    [root addSection:details];
    [details addElement:tell];
    [details addElement:interest];
    [details addElement:questions];
    [details addElement:hear];

    QSection *submit = [[QSection alloc] init];
    QButtonElement *submitButton = [[QButtonElement alloc] initWithTitle:@"Submit"];
    [submitButton setOnSelected:^{
        if ([[name.textValue stringByRemovingNewLinesAndWhitespace] length] == 0) {
            FCDisplayBasicErrorMessage(@"", @"Please enter your name");
            return;
        }
        if ([[institution.textValue stringByRemovingNewLinesAndWhitespace] length] == 0) {
            FCDisplayBasicErrorMessage(@"", @"Please enter your educational institution");
            return;
        }
        if ([[position.textValue stringByRemovingNewLinesAndWhitespace] length] == 0) {
            FCDisplayBasicErrorMessage(@"", @"Please enter your position at your educational institution");
            return;
        }

        if ([[tell.textValue stringByRemovingNewLinesAndWhitespace] length] == 0) {
            FCDisplayBasicErrorMessage(@"", @"Please tell me a bit about yourself");
            return;
        }

        
        MFMailComposeViewController *feedbackController = [[MFMailComposeViewController alloc] init];
        feedbackController.mailComposeDelegate = self;
        [feedbackController setToRecipients:[NSArray arrayWithObject:contactEmailAddress]];
        [feedbackController setSubject:root.title];
        
        NSString *subscription;
        if ([FlashCardsCore hasSubscription]) {
            NSDate *subscriptionEndDate = [FlashCardsCore getSettingDate:@"subscriptionEndDate"];
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            [dateFormatter setDateStyle:NSDateFormatterMediumStyle];
            NSString *endDate = [dateFormatter stringFromDate:subscriptionEndDate];
            subscription = [NSString stringWithFormat:@"S: %@", endDate];
        } else {
            subscription = @"";
        }
        
        [feedbackController setMessageBody:[NSString stringWithFormat:
                                            @"Thanks for your interest in FlashCards++. Please submit your inquiry by sending this email, and I'll get back to you shortly. --Jason, FlashCards++ developer\n\n"
                                            @"Your Name: %@\n"
                                            @"Your Educational institution: %@\n"
                                            @"Your position: %@\n\n"
                                            @"Tell me about yourself: %@\n\n"
                                            @"Why are you interestsed in FlashCards++? %@\n\n"
                                            @"Do you have any questions about FlashCards++ that I can answer? %@\n\n"
                                            @"Where did you hear about FlashCards++? %@\n\n"
                                            @"\n\nVersion: %@ (%@) [init: %@]\niOS: %@ (%@)\nDevice: %@ (%@, %@)\n%@\n\n",
                                            name.textValue,
                                            institution.textValue,
                                            position.textValue,
                                            tell.textValue,
                                            interest.textValue,
                                            questions.textValue,
                                            hear.textValue,
                                            [FlashCardsCore appVersion],
                                            [FlashCardsCore buildNumber],
                                            [FlashCardsCore getSetting:@"firstVersionInstalled"],
                                            [FlashCardsCore osVersionNumber],
                                            [FlashCardsCore osVersionBuild],
                                            [FlashCardsCore deviceName],
                                            [[UIDevice currentDevice] uniqueDeviceIdentifier],
                                            [[UIDevice currentDevice] advertisingIdentifier],
                                            subscription
                                            ]
                                    isHTML:NO];
        [self.navigationController.modalViewController dismissModalViewControllerAnimated:NO];
        [self presentViewController:feedbackController animated:NO completion:nil];

    }];
    [root addSection:submit];
    [submit addElement:submitButton];
    
    UINavigationController *navigation = [QuickDialogController controllerWithNavigationForRoot:root];
    navigation.navigationBar.topItem.leftBarButtonItem = [[UIBarButtonItem alloc] bk_initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                                         handler:^(id sender){
        [self.navigationController.modalViewController dismissViewControllerAnimated:YES completion:nil];
    }];
    
    [self presentViewController:navigation animated:YES completion:nil];
*/
    return;
}

- (void)cancelEvent {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)showHUD {
    HUD = [[MBProgressHUD alloc] initWithView:self.view];
    
    // Add HUD to screen
    [self.view addSubview:HUD];
    
    // Regisete for HUD callbacks so we can remove it from the window at the right time
    HUD.delegate = self;
    HUD.minShowTime = 1.0;
    // HUD.detailsLabelText = NSLocalizedStringFromTable(@"Tap to Cancel", @"Import", @"HUD");
    [HUD show:YES];
}

- (void)hideHUD {
    [self.HUD hide:YES];
}

#pragma mark -
#pragma mark MBProgressHUDDelegate methods

- (void)hudWasHidden:(MBProgressHUD *)hud {
    // Remove HUD from screen when the HUD was hidded
    if (hud) {
        [hud removeFromSuperview];
        hud = nil;
    }
}

- (void)hudWasTapped:(MBProgressHUD *)hud {
}
- (void)setHUDLabel:(NSString*)labelText {
    [HUD setLabelText:labelText];
}

# pragma mark - Explanation of subscription

- (NSString *)subscriptionExplanationHeader {
    return NSLocalizedStringFromTable(@"FlashCards++ is a unique teaching and learning tool. Share it with your students: Purchase the Teacher Edition and you will get a Lifetime Subscription for yourself as well as for your students at a heavily discounted rate.\n\n"
                                      @"With the Teacher Edition you can create a login code for your class or school. When students enter the login code they will automatically receive a Lifetime Subscription.", @"Subscription", @"");
}

- (NSString *)schoolExplanationHeader {
    return NSLocalizedStringFromTable(@"Interested in purchasing FlashCards++ licenses for more students, or for your school? Please contact me about discounted bulk pricing.", @"Subscription", @"");
}

- (NSString*)subscriptionExplanationFooter {
    return @"";
}

# pragma mark - UITableViewDelegate methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    int numSections = 2;
    return numSections;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return 3;
    }
    return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return [FlashCardsCore explanationLabelHeightWithString:[self subscriptionExplanationHeader] inView:self.view];
    } else {
        return [FlashCardsCore explanationLabelHeightWithString:[self schoolExplanationHeader] inView:self.view];
    }
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return [FlashCardsCore explanationLabelViewWithString:[self subscriptionExplanationHeader] inView:self.view];
    } else {
        return [FlashCardsCore explanationLabelViewWithString:[self schoolExplanationHeader] inView:self.view];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    int showFooterInSection = 0;
    if (section != showFooterInSection) {
        return 0;
    }
    return [FlashCardsCore explanationLabelHeightWithString:[self subscriptionExplanationFooter] inView:self.view];
}
- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    int showFooterInSection = 0;
    if (section != showFooterInSection) {
        return nil;
    }
    return [FlashCardsCore explanationLabelViewWithString:[self subscriptionExplanationFooter] inView:self.view];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        return 59;
    }
    return 44;
}
// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    int section = indexPath.section;
    if (section == 1) {
        static NSString *CellIdentifier = @"Cell0";
        // Dequeue or create a new cell
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        if (cell == nil) {
            // cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier];
        }
        
        [cell setAccessoryType:UITableViewCellAccessoryNone];
        
        cell.textLabel.text = NSLocalizedStringFromTable(@"Inquire about School Pricing", @"Subscription", @"");
        cell.detailTextLabel.text = @"";
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return cell;
    }
    NSString *name;
    NSString *description;
    NSString *price;
    if (indexPath.row == 0) {
        // $50 = $5/student
        name = NSLocalizedStringFromTable(@"Teacher + 10 Students", @"Subscription", @"");
        description = NSLocalizedStringFromTable(@"$5 per Student (each gets a Lifetime Subscription)", @"Subscription", @"");
        price = [self priceForProduct:kInAppPurchaseProUpgradeTeachers10];
    } else if (indexPath.row == 1) {
        // $100 = $4/student
        name = NSLocalizedStringFromTable(@"Teacher + 25 Students", @"Subscription", @"");
        description = NSLocalizedStringFromTable(@"$4 per Student (each gets a Lifetime Subscription)", @"Subscription", @"");
        price = [self priceForProduct:kInAppPurchaseProUpgradeTeachers25];
    } else if (indexPath.row == 2) {
        // $250 = $2.50/student
        name = NSLocalizedStringFromTable(@"Teacher + 100 Students", @"Subscription", @"");
        description = NSLocalizedStringFromTable(@"$2.50 per Student (each gets a Lifetime Subscription)", @"Subscription", @"");
        price = [self priceForProduct:kInAppPurchaseProUpgradeTeachers100];
    }

    TeacherSubscriptionOptionCell *teacherCell = (TeacherSubscriptionOptionCell*) [self.myTableView dequeueReusableCellWithIdentifier:@"TeacherCell"];
    if (teacherCell == nil) {
        teacherCell = [[TeacherSubscriptionOptionCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"TeacherCell"];
    }
    teacherCell.subscriptionName.text = name;
    teacherCell.subscriptionDescription.text = description;
    teacherCell.subscriptionPrice.text = price;
    
    teacherCell.accessoryType = UITableViewCellAccessoryNone;

    return teacherCell;
    
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.myTableView deselectRowAtIndexPath:indexPath animated:YES];
    int section = indexPath.section;
    if (section == 1) {
        [self sendInquiry];
        return;
    }
    if (![FlashCardsCore isConnectedToInternet]) {
        FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"No Internet Connection", @"Error", @""),
                                   NSLocalizedStringFromTable(@"Sorry, the App Store cannot be reached now for Subscriptions.", @"Subscription", @""));
        return;
    }
    NSString *productId;
    if (indexPath.row == 0) {
        productId = kInAppPurchaseProUpgradeTeachers10;
    } else if (indexPath.row == 1) {
        productId = kInAppPurchaseProUpgradeTeachers25;
    } else {
        productId = kInAppPurchaseProUpgradeTeachers100;
    }
    FCLog(@"PRODUCT: %@", productId);
    if (![SKPaymentQueue canMakePayments]) {
        FCDisplayBasicErrorMessage(@"",
                                   NSLocalizedStringFromTable(@"Sorry, you cannot currently make in-app purchases.", @"Error", @""));
        return;
    }
    // because we checked if the user is connected to the internet above, we can assume it's true now:
    [self showHUD];
    [[RMStore defaultStore] addPayment:productId success:^(SKPaymentTransaction *transaction) {
        FCLog(@"Product purchased: %@", productId);
        [Flurry logEvent:@"Subscription/Purchased"
          withParameters:@{
                           @"ProductId" : transaction.payment.productIdentifier
                           }];
        [[[FlashCardsCore appDelegate] inAppPurchaseManager] verifyTransaction:transaction];
    } failure:^(SKPaymentTransaction *transaction, NSError *error) {
        [self.HUD hide:YES];
        [[[FlashCardsCore appDelegate] inAppPurchaseManager] displayError:error];
    }];
}

# pragma mark - In-App Purchase

- (NSString*)priceForProduct:(NSString*)productId {
    if (![FlashCardsCore isConnectedToInternet]) {
        return [self basicPriceForProduct:productId];
    }
    SKProduct *product = [[RMStore defaultStore] productForIdentifier:productId];
    if (product) {
        return [RMStore localizedPriceOfProduct:product];
    }
    return [self basicPriceForProduct:productId];
}
- (NSString*)basicPriceForProduct:(NSString*)productId {
    if ([productId isEqualToString:kInAppPurchaseProUpgradeTeachers10]) {
        return @"$49.99";
    } else if ([productId isEqualToString:kInAppPurchaseProUpgradeTeachers25]) {
        return @"$99.99";
    } else if ([productId isEqualToString:kInAppPurchaseProUpgradeTeachers100]) {
        return @"$249.99";
    } else {
        return @"$49.99";
    }
}

@end
