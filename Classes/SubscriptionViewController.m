//
//  SubscriptionViewController.m
//  FlashCards
//
//  Created by Jason Lustig on 11/13/12.
//  Copyright (c) 2012 Jason Lustig. All rights reserved.
//

#import "SubscriptionViewController.h"

#import "FlashCardsAppDelegate.h"
#import "InAppPurchaseManager.h"
#import "AppLoginViewController.h"

#import "HelpViewController.h"
#import "TeachersViewController.h"

#import "CardSetImportChoicesViewController.h"
#import "CardEditViewController.h"

#import "RMStore.h"

@interface SubscriptionViewController ()

@end

@implementation SubscriptionViewController

@synthesize myTableView;
@synthesize HUD;
@synthesize selectedProductId;
@synthesize learnMoreButton;
@synthesize showTrialEndedPopup;
@synthesize giveTrialOption;
@synthesize explainSync;
@synthesize cancelAlsoCancelsPreviousActivity;
@synthesize popupMessage;

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
    
    self.title = NSLocalizedStringFromTable(@"Subscription", @"Subscription", @"");
    
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                  target:self
                                                                                  action:@selector(cancelEvent)];
    self.navigationItem.leftBarButtonItem = cancelButton;
    
    learnMoreButton.title = NSLocalizedStringFromTable(@"Learn About Subscriptions", @"Subscription", @"");
    
    if ([FlashCardsCore isConnectedToInternet]) {
        [self showHUD];
        NSSet *products = [NSSet setWithArray:@[kInAppPurchaseProUpgrade3Months,
                                                kInAppPurchaseProUpgrade6Months,
                                                kInAppPurchaseProUpgrade12Months,
                                                kInAppPurchaseProUpgradeLifetime]];
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
    // ******
    // This line, below, is changed because for some reason when the trial is ended because reachability
    // changed, the reachability status in RootVC is DIFFERENT(!!!) from the reachability status in this
    // view controller!!! It is really bizarre and we need a workaround, that is, whenever the popup for
    // the trial ending is shown, never say that you can't connect to the internet.
    if (![FlashCardsCore isConnectedToInternet] && !showTrialEndedPopup) {
        NSString *noInternetConnection = NSLocalizedStringFromTable(@"Sorry, the App Store cannot be reached now for Subscriptions.", @"Subscription", @"");
        NSString *trialOption = NSLocalizedStringFromTable(@"However, you can try the offline text-to-speak function while you are offline, and then subscribe if you would like when you are connected to the internet again.", @"Subscription", @"");
        if (![FlashCardsCore hasUsedOneTimeOfflineTTSTrial] && giveTrialOption) {
            FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"No Internet Connection", @"Error", @""),
                                       [NSString stringWithFormat:@"%@ %@", noInternetConnection, trialOption]);
        } else {
            // We want to let the user try to do things, rather than just saying that the app store cannot be reached.
            // The user will be confused why they are trying to reach the app store.
            // FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"No Internet Connection", @"Error", @""),
            //                            noInternetConnection);
        }
    }
    if (showTrialEndedPopup) {
        FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"Free Trial Ended", @"Subscription", @""),
                                   NSLocalizedStringFromTable(@"You are now re-connected to the internet, so your free trial of the offline text-to-speech feature has concluded. If you would like to continue to use this feature offline, please consider supporting FlashCards++ by becoming a Subscriber. Thank you.", @"Subscription", @""));
    } else if (explainSync) {
        FCDisplayBasicErrorMessage(@"",
                                   NSLocalizedStringFromTable(@"Automatically syncing flash cards between devices, e.g. iPhone and iPad, is only available to Subscribers. Please log in to your FlashCards++ account, or subscribe to support FlashCards++ and sync your flash cards between your devices.", @"Subscription", @""));
    } else if (popupMessage && [popupMessage respondsToSelector:@selector(length)]) {
        if ([popupMessage length] > 0) {
            FCDisplayBasicErrorMessage(@"", popupMessage);
        }
    }
    [Flurry logEvent:@"Subscription/PurchasePage"
      withParameters:@{
     @"TrialEnded" : [NSNumber numberWithBool:showTrialEndedPopup],
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

# pragma mark - Event methods

- (BOOL)shouldDoTrial {
    if (![FlashCardsCore isConnectedToInternet]) {
        if (![FlashCardsCore hasUsedOneTimeOfflineTTSTrial] && giveTrialOption) {
            return YES;
        }
    }
    return NO;
}

- (void)teacherButtonTapped {
    NSMutableArray *vcs = [NSMutableArray arrayWithArray:[self.navigationController viewControllers]];
    TeachersViewController *vc = [[TeachersViewController alloc] initWithNibName:@"TeachersViewController" bundle:nil];
    [vcs removeLastObject];
    [vcs addObject:vc];
    [self.navigationController setViewControllers:vcs animated:YES];
}

- (IBAction)learnMore:(id)sender {
    [self.navigationController pushViewController:[self learnMoreViewController] animated:YES];
}

- (HelpViewController*)learnMoreViewController {
    [Flurry logEvent:@"Subscription/HelpPage"];
    
    HelpViewController *helpVC = [[HelpViewController alloc] initWithNibName:@"HelpViewController" bundle:nil];
    
    helpVC.title = NSLocalizedStringFromTable(@"About Subscriptions", @"Help", @"UIView title");

    NSString *firstVersionInstalled = (NSString*)[FlashCardsCore getSetting:@"firstVersionInstalled"];
    float version = [firstVersionInstalled floatValue];
    if (version < firstVersionWithFreeDownload) {
        // the user downloaded the app and paid for it; we will explain that only a few features are paid.
        helpVC.helpText = NSLocalizedStringFromTable(@"AboutSubscriptionsHelp", @"Help", @"");
    } else {
        // we have the free download, so most everything is shut off.
        helpVC.helpText = NSLocalizedStringFromTable(@"AboutSubscriptionsFreeHelp", @"Help", @"");
    }
    return helpVC;
}

- (void)cancelEvent {
    UIViewController *parentVC = [FlashCardsCore parentViewController];
    NSMutableArray *vcs = [NSMutableArray arrayWithArray:[self.navigationController viewControllers]];
    if ([parentVC isKindOfClass:[CardSetImportChoicesViewController class]] && cancelAlsoCancelsPreviousActivity) {
        [vcs removeLastObject];
        [vcs removeLastObject];
        [self.navigationController setViewControllers:vcs animated:YES];
    } else if ([parentVC isKindOfClass:[CardEditViewController class]] && cancelAlsoCancelsPreviousActivity) {
        [vcs removeLastObject];
        [vcs removeLastObject];
        [self.navigationController setViewControllers:vcs animated:YES];
    } else {
        [self.navigationController popViewControllerAnimated:YES];
    }
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
    NSString *firstVersionInstalled = (NSString*)[FlashCardsCore getSetting:@"firstVersionInstalled"];
    float version = [firstVersionInstalled floatValue];
    if (version < firstVersionWithFreeDownload) {
        // the user downloaded the app and paid for it; we will explain that only a few features are paid.
        return @"FlashCards++'s new automatic sync, user-recorded audio, and offline text-to-speech features, which caches text-to-speech for your cards so that it will work without an active internet connection, are available to subscribers.\n"
        @"\n"
        @"Subscribers also support the continued development of new features for FlashCards++.\n";
    } else {
        // we have the free download, so most everything is shut off.
        return [NSString stringWithFormat:@"FlashCards++'s free version lets you study up to %d cards, but many of its robust features are only available to subscribers. This includes unlimited cards, the ability to add photos and audio to cards, text-to-speech, automatic sync, and backup. Subscribing also hide ads while studying.\n"
        @"\n"
        @"Subscribers also support the continued development of new features for FlashCards++.\n",
                maxCardsLite];
    }
}

- (NSString*)subscriptionExplanationFooter {
    return @"Subscriptions apply to all of your personal devices.\n"
    @"\n"
    @"After you subscribe, there may be a brief delay before text-to-speech works offline. For text-to-speech to work, you must specify the language of the front & back of your cards.\n";
}

# pragma mark - UITableViewDelegate methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    int numSections = 1;
    if ([FlashCardsCore isLoggedIn]) {
        numSections = 1;
    } else {
        numSections = 2;
    }
    if ([self shouldDoTrial]) {
        numSections++;
    }
    if ([FlashCardsCore getSettingBool:@"showForTeachersButton"]) {
        numSections++;
    }
    return numSections;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if ([self shouldDoTrial]) {
        section--;
    }
    if (section == -1) {
        return 1;
    }
    if (section == 0) {
        return 4;
    }
    return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (section != 0) {
        return 0;
    }
    return [FlashCardsCore explanationLabelHeightWithString:[self subscriptionExplanationHeader] inView:self.view];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (section != 0) {
        return nil;
    }
    return [FlashCardsCore explanationLabelViewWithString:[self subscriptionExplanationHeader] inView:self.view];
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    int showFooterInSection = 0;
    if (![FlashCardsCore isLoggedIn]) {
        showFooterInSection++;
    }
    if ([self shouldDoTrial]) {
        showFooterInSection++;
    }
    if (section != showFooterInSection) {
        return 0;
    }
    return [FlashCardsCore explanationLabelHeightWithString:[self subscriptionExplanationFooter] inView:self.view];
}
- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    int showFooterInSection = 0;
    if (![FlashCardsCore isLoggedIn]) {
        showFooterInSection++;
    }
    if ([self shouldDoTrial]) {
        showFooterInSection++;
    }
    if (section != showFooterInSection) {
        return nil;
    }
    return [FlashCardsCore explanationLabelViewWithString:[self subscriptionExplanationFooter] inView:self.view];
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    
    static NSString *CellIdentifier = @"Cell";
    // Dequeue or create a new cell
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        // cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier];
    }
    
    [cell setAccessoryType:UITableViewCellAccessoryNone];
    
    int section = indexPath.section;
    
    if ([self shouldDoTrial]) {
        section--;
    }
    
    if (section == -1) {
        cell.textLabel.text = NSLocalizedStringFromTable(@"Activate Trial", @"Subscription", @"");
        cell.detailTextLabel.text = @"";
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else if (section == 0) {
        if (indexPath.row == 0) {
            cell.textLabel.text = NSLocalizedStringFromTable(@"Subscribe: 3 Months", @"Subscription", @"");
            cell.detailTextLabel.text = [self priceForProduct:kInAppPurchaseProUpgrade3Months];
        } else if (indexPath.row == 1) {
            cell.textLabel.text = NSLocalizedStringFromTable(@"Subscribe: 6 Months", @"Subscription", @"");
            cell.detailTextLabel.text = [self priceForProduct:kInAppPurchaseProUpgrade6Months];
        } else if (indexPath.row == 2) {
            cell.textLabel.text = NSLocalizedStringFromTable(@"Subscribe: 12 Months", @"Subscription", @"");
            cell.detailTextLabel.text = [self priceForProduct:kInAppPurchaseProUpgrade12Months];
        } else {
            cell.textLabel.text = NSLocalizedStringFromTable(@"Lifetime Subscription", @"Subscription", @"");
            cell.detailTextLabel.text = [self priceForProduct:kInAppPurchaseProUpgradeLifetime];
        }
        cell.accessoryType = UITableViewCellAccessoryNone;
    } else {
        if ([FlashCardsCore isLoggedIn]) {
            section++;
        }
        if (section == 1) {
            cell.textLabel.text = NSLocalizedStringFromTable(@"Already a Subscriber? Log In", @"Subscription", @"");
            cell.detailTextLabel.text = @"";
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        } else if (section == 2) {
            cell.textLabel.text = NSLocalizedStringFromTable(@"I'm a Teacher", @"Subscription", @"");
            cell.detailTextLabel.text = @"";
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
    }
    return cell;
    
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.myTableView deselectRowAtIndexPath:indexPath animated:YES];
    int section = (int)indexPath.section;
    if ([self shouldDoTrial]) {
        section--;
    }
    if (section == -1) {
        // start the offline TTS trial:
        [Flurry logEvent:@"Subscription/OfflineTTSTrial"];
        [FlashCardsCore setSetting:@"currentlyUsingOneTimeOfflineTTSTrial" value:@YES];
        FCDisplayBasicErrorMessage(@"",
                                   NSLocalizedStringFromTable(@"Your one-time trial of the offline text-to-speech function has begun. When you re-connect to the internet, you will be returned to this screen. I hope that you choose to support FlashCards++ by becoming a Subscriber. Thank you.", @"Subscription", @""));
        [self cancelEvent];
        return;
    }
    if (section == 0) {
        if (![FlashCardsCore isConnectedToInternet] && !showTrialEndedPopup) {
            FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"No Internet Connection", @"Error", @""),
                                       NSLocalizedStringFromTable(@"Sorry, the App Store cannot be reached now for Subscriptions.", @"Subscription", @""));
            return;
        }
        NSString *productId;
        if (indexPath.row == 0) {
            productId = kInAppPurchaseProUpgrade3Months;
        } else if (indexPath.row == 1) {
            productId = kInAppPurchaseProUpgrade6Months;
        } else if (indexPath.row == 2) {
            productId = kInAppPurchaseProUpgrade12Months;
        } else {
            productId = kInAppPurchaseProUpgradeLifetime;
        }
        FCLog(@"PRODUCT: %@", productId);
        if (![SKPaymentQueue canMakePayments]) {
            FCDisplayBasicErrorMessage(@"",
                                       NSLocalizedStringFromTable(@"Sorry, you cannot currently make in-app purchases.", @"Error", @""));
            return;
        }
        if ([FlashCardsCore isConnectedToInternet]) {
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
        return;
    }
    if ([FlashCardsCore isLoggedIn]) {
        section++;
    }
    if (section == 1) {
        // Go to login screen
        if (![FlashCardsCore isConnectedToInternet]) {
            FCDisplayBasicErrorMessage(@"",
                                       NSLocalizedStringFromTable(@"You must be connected to the internet to create a new account or log in.", @"Error", @""));
            return;
        }
        AppLoginViewController *vc = [[AppLoginViewController alloc] initWithNibName:@"AppLoginViewController" bundle:nil];
        vc.isCreatingNewAccount = NO;
        [self.navigationController pushViewController:vc animated:YES];
        return;
    }
    if (section == 2) {
        [self teacherButtonTapped];
        return;
    }
    return;
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
    if ([productId isEqualToString:kInAppPurchaseProUpgrade3Months]) {
        return @"$2.99";
    } else if ([productId isEqualToString:kInAppPurchaseProUpgrade6Months]) {
        return @"$5.99";
    } else if ([productId isEqualToString:kInAppPurchaseProUpgrade12Months]) {
        return @"$9.99";
    } else {
        return @"$24.99";
    }
}

@end
