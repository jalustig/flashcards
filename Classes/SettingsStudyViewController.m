//
//  SettingsStudyViewController.m
//  FlashCards
//
//  Created by Jason Lustig on 10/4/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import "FlashCardsAppDelegate.h"
#import "FlashCardsCore.h"

#import "SettingsStudyViewController.h"
#import "SettingsAdvancedViewController.h"
#import "SettingsStudyBackgroundColorViewController.h"
#import "HelpViewController.h"
#import "SubscriptionViewController.h"
#import "InAppPurchaseManager.h"
#import "AppLoginViewController.h"
#import "TeachersViewController.h"

#import "UIDevice+IdentifierAddition.h"
#import "UIColor-Expanded.h"
#import "NSString+StripParentheses.h"

#import <ActionSheetPicker-3.0/ActionSheetStringPicker.h>
#import "UIAlertView+Blocks.h"

#import "FCCard.h"

#import "NSArray+SplitArray.h"
#import "JSONKit.h"

#import "UIAlertView+Blocks.h"

@implementation SettingsStudyViewController

@synthesize myTableView;
@synthesize goToStudySettings;
@synthesize tableFooter, advancedSettingsButton;
@synthesize syncLabel, syncCell, syncSwitch;
@synthesize ignoreParenthesesLabel, ignoreParenthesesCell, ignoreParenthesesSwitch;
@synthesize textJustificationLabel, textJustificationCell, textJustificationDescriptionLabel;
@synthesize swipeToProceedCardLabel, swipeToProceedCardCell, swipeToProceedCardSwitch;
@synthesize displayBadgeLabel, displayBadgeCell, displayBadgeSwitch;
@synthesize useMarkdownLabel, useMarkdownCell, useMarkdownSwitch;
@synthesize displayNotificationLabel, displayNotificationCell, displayNotificationSwitch;
@synthesize proceedNextCardLabel, proceedNextCardCell, proceedNextCardSwitch;
@synthesize autoMergeIdenticalCardsLabel, autoMergeIdenticalCardsCell, autoMergeIdenticalCardsSwitch;
@synthesize autocorrectTextLabel, autocorrectTextCell, autocorrectTextSwitch;
@synthesize autocapitalizeTextLabel, autocapitalizeTextCell, autocapitalizeTextSwitch;
@synthesize textSizeOptions, fontOptions, textJustificationOptions, autoBrowseSpeedOptions;
@synthesize backgroundTask;
@synthesize HUD;

#pragma mark -
#pragma mark View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = NSLocalizedStringFromTable(@"Settings", @"Settings", @"UIView title");
    
    autoMergeIdenticalCardsLabel.text   = NSLocalizedStringFromTable(@"Merge Exact Matches", @"Settings", @"UILabel");
    displayNotificationLabel.text       = NSLocalizedStringFromTable(@"Display Study Notification", @"Settings", @"UILabel");
    displayBadgeLabel.text              = NSLocalizedStringFromTable(@"Display Badge", @"Settings", @"UILabel");
    proceedNextCardLabel.text           = NSLocalizedStringFromTable(@"Go To Next On Score", @"Settings", @"UILabel");
    swipeToProceedCardLabel.text        = NSLocalizedStringFromTable(@"Swipe to Next Card", @"Settings", @"UILabel");
    textJustificationLabel.text         = NSLocalizedStringFromTable(@"Text Justification", @"Settings", @"UILabel");
    autocorrectTextLabel.text           = NSLocalizedStringFromTable(@"Auto-correct Text", @"Settings", @"UILabel");
    autocapitalizeTextLabel.text        = NSLocalizedStringFromTable(@"Auto-capitalize Text", @"Settings", @"UILabel");
    ignoreParenthesesLabel.text         = NSLocalizedStringFromTable(@"Ignore Parentheses", @"Settings", @"UILabel");
    syncLabel.text                      = NSLocalizedStringFromTable(@"Automatically Sync Data", @"Sync", @"UILabel");
    useMarkdownLabel.text               = NSLocalizedStringFromTable(@"Format with MarkDown", @"Settings", @"UILabel");
    
    [advancedSettingsButton setTitle:NSLocalizedStringFromTable(@"Advanced Settings", @"Settings", @"UIButton") forState:UIControlStateNormal];
    [advancedSettingsButton setTitle:NSLocalizedStringFromTable(@"Advanced Settings", @"Settings", @"UIButton") forState:UIControlStateSelected];

    textSizeOptions =  [[NSMutableArray alloc] initWithObjects:
                        [NSDictionary dictionaryWithObjectsAndKeys:
                         NSLocalizedStringFromTable(@"Extra-Extra Large", @"Settings", @""), @"text",
                         [NSNumber numberWithInt:sizeExtraExtraLarge], @"value", nil],
                        [NSDictionary dictionaryWithObjectsAndKeys:
                         NSLocalizedStringFromTable(@"Extra Large", @"Settings", @""), @"text",
                         [NSNumber numberWithInt:sizeExtraLarge], @"value", nil],
                        [NSDictionary dictionaryWithObjectsAndKeys:
                         NSLocalizedStringFromTable(@"Large", @"Settings", @""), @"text",
                         [NSNumber numberWithInt:sizeLarge], @"value", nil],
                        [NSDictionary dictionaryWithObjectsAndKeys:
                         NSLocalizedStringFromTable(@"Normal", @"Settings", @""), @"text",
                         [NSNumber numberWithInt:sizeNormal], @"value", nil],
                        [NSDictionary dictionaryWithObjectsAndKeys:
                         NSLocalizedStringFromTable(@"Small", @"Settings", @""), @"text",
                         [NSNumber numberWithInt:sizeSmall], @"value", nil],
                        nil];
    if ([FlashCardsAppDelegate isIpad]) {
        [textSizeOptions addObject:@{@"text": NSLocalizedStringFromTable(@"Extra Small", @"Settings", @""),
                                     @"value": [NSNumber numberWithInteger:sizeExtraSmall]}];
        [textSizeOptions addObject:@{@"text": NSLocalizedStringFromTable(@"Extra-Extra Small", @"Settings", @""),
                                     @"value": [NSNumber numberWithInteger:sizeExtraExtraSmall]}];
    }
    
    fontOptions = [[NSMutableArray alloc]
                   initWithArray:[[UIFont familyNames]
                                  sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]];
    
    NSArray *badFonts = [NSArray arrayWithObjects:
                         @"AppleColorEmoji",
                         @"AppleGothic",
                         @"Arial Rounded MT Bold",
                         @"Bodoni Ornaments",
                         @"DB LCD Temp",
                         @"Zapf Dingbats",
                         @"Heiti J",
                         @"Heiti K",
                         @"Heiti SC",
                         @"Heiti TC",
                         nil];
    for (NSString *font in badFonts) {
        for (int i = (int)[fontOptions count]-1; i >= 0; i--) {
            if ([[fontOptions objectAtIndex:i] isEqual:font]) {
                [fontOptions removeObjectAtIndex:i];
                break;
            }
        }
    }

    textJustificationOptions = [[NSMutableArray alloc] initWithObjects:
                                NSLocalizedStringFromTable(@"Left", @"Settings", @""),
                                NSLocalizedStringFromTable(@"Center", @"Settings", @""),
                                NSLocalizedStringFromTable(@"Right", @"Settings", @""),
                                nil];

    autoBrowseSpeedOptions = [[NSMutableArray alloc] initWithCapacity:0];
    [autoBrowseSpeedOptions addObject:[NSNumber numberWithFloat:0.5f]];
    [autoBrowseSpeedOptions addObject:[NSNumber numberWithFloat:1.0f]];
    [autoBrowseSpeedOptions addObject:[NSNumber numberWithFloat:1.5f]];
    [autoBrowseSpeedOptions addObject:[NSNumber numberWithFloat:2.0f]];
    [autoBrowseSpeedOptions addObject:[NSNumber numberWithFloat:2.5f]];
    [autoBrowseSpeedOptions addObject:[NSNumber numberWithFloat:3.0f]];
    [autoBrowseSpeedOptions addObject:[NSNumber numberWithFloat:3.5f]];
    [autoBrowseSpeedOptions addObject:[NSNumber numberWithFloat:4.0f]];
    [autoBrowseSpeedOptions addObject:[NSNumber numberWithFloat:4.5f]];
    [autoBrowseSpeedOptions addObject:[NSNumber numberWithFloat:5.0f]];
    [autoBrowseSpeedOptions addObject:[NSNumber numberWithFloat:6.0f]];
    [autoBrowseSpeedOptions addObject:[NSNumber numberWithFloat:7.0f]];
    [autoBrowseSpeedOptions addObject:[NSNumber numberWithFloat:8.0f]];
    [autoBrowseSpeedOptions addObject:[NSNumber numberWithFloat:9.0f]];
    [autoBrowseSpeedOptions addObject:[NSNumber numberWithFloat:10.0f]];
    [autoBrowseSpeedOptions addObject:[NSNumber numberWithFloat:15.0f]];
    [autoBrowseSpeedOptions addObject:[NSNumber numberWithFloat:20.f]];

    [self displayAll];
    
    // Help buttons
    UIButton *helpButton = [UIButton buttonWithType:UIButtonTypeInfoLight];
    [helpButton addTarget:self action:@selector(helpEvent) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *rightItem = [[UIBarButtonItem alloc] initWithCustomView:helpButton];
    [rightItem setAccessibilityLabel:NSLocalizedStringFromTable(@"Help", @"Help", @"UIView title")];
    [rightItem setAccessibilityHint:NSLocalizedStringFromTable(@"Help", @"Help", @"UIView title")];
    self.navigationItem.rightBarButtonItem = rightItem;
    
    [self.myTableView setTableFooterView:tableFooter];
    
    if (self.goToStudySettings) {
        [self.myTableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:2]
                                atScrollPosition:UITableViewScrollPositionMiddle
                                        animated:NO];
    }
}

- (void) displayAll {
    [self displayUseMarkdown];
    [self displayAutoMergeIdenticalCards];
    [self displayAutoBrowseSpeed];
    [self displayProceedNextCard];
    [self displayDisplayBadge];
    [self displayDisplayNotification];
    [self displayAutocorrectText];
    [self displayAutocapitalizeText];
    [self displayIgnoreParentheses];
    [self displaySync];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self displayAll];

    [self.myTableView reloadData];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.myTableView reloadData];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [FlashCardsCore setSetting:@"uploadIsCanceled" value:@YES];
}


- (BOOL)shouldAutorotate {
    UIInterfaceOrientation interfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    return [FlashCardsAppDelegate shouldAutorotate:interfaceOrientation];
}

- (void) displayUseMarkdown {
    bool studySettingsUseMarkdown = [FlashCardsCore getSettingBool:@"studySettingsUseMarkdown"];
    [useMarkdownSwitch setOn:studySettingsUseMarkdown];
}

- (void) displayAutocapitalizeText {
    bool autocapitalizeText = [FlashCardsCore getSettingBool:@"shouldUseAutoCapitalizeText"];
    [autocapitalizeTextSwitch setOn:autocapitalizeText];
}

- (void) displayAutocorrectText {
    bool autocorrectText = [FlashCardsCore getSettingBool:@"shouldUseAutoCorrect"];
    [autocorrectTextSwitch setOn:autocorrectText];
}

- (void) displayDisplayBadge {
    bool settingDisplayBadge = [FlashCardsCore getSettingBool:@"settingDisplayBadge"];
    [displayBadgeSwitch setOn:settingDisplayBadge];
}

- (void) displayDisplayNotification {
    bool settingDisplayNotification = [FlashCardsCore getSettingBool:@"settingDisplayNotification"];
    [displayNotificationSwitch setOn:settingDisplayNotification];
}

- (void) displaySwipeToProceedCard {
    bool studySwipeToProceedCard = [FlashCardsCore getSettingBool:@"studySwipeToProceedCard"];
    [swipeToProceedCardSwitch setOn:studySwipeToProceedCard];
}

- (void) displayAutoBrowseSpeed:(UITableViewCell*)cell {
    float autoBrowseSpeed = [(NSNumber*)[FlashCardsCore getSetting:@"studySettingsAutoBrowseSpeed"] floatValue];
    NSString *desc = [NSString stringWithFormat:FCPluralLocalizedStringFromTable(@"%1.1f Secs", @"Plural", @"", [NSNumber numberWithFloat:autoBrowseSpeed]), autoBrowseSpeed];
    cell.detailTextLabel.text = desc;
}

- (void) displayAutoBrowseSpeed {
    int row = 6;
    int section = 2;
    UITableViewCell *cell = [self.myTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:section]];
    if (!cell) {
        return;
    }
    [self displayAutoBrowseSpeed:cell];
}

- (void) displayAutoMergeIdenticalCards {
    BOOL autoMergeIdenticalCards = [FlashCardsCore getSettingBool:@"importSettingsAutoMergeIdenticalCards"];
    [autoMergeIdenticalCardsSwitch setOn:autoMergeIdenticalCards];
}

- (void) displayProceedNextCard {
    BOOL proceedNextCard = [FlashCardsCore getSettingBool:@"studySettingsProceedNextCardOnScore"];
    [proceedNextCardSwitch setOn:proceedNextCard];
}

- (void) displayIgnoreParentheses {
    BOOL ignoreParentheses = [FlashCardsCore getSettingBool:@"TTSIgnoresParentheses"];
    [ignoreParenthesesSwitch setOn:ignoreParentheses];
}

- (void) displaySync {
    BOOL sync = [FlashCardsCore appIsSyncing];
    [syncSwitch setOn:sync];
}

/*
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}
*/
/*
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}
*/

# pragma mark -
# pragma mark Event functions

-(IBAction)advancedSettings:(id)option {
    SettingsAdvancedViewController *vc = [[SettingsAdvancedViewController alloc] initWithNibName:@"SettingsAdvancedViewController" bundle:nil];
    [self.navigationController pushViewController:vc animated:YES];
}


-(IBAction)ignoreParenthesesSwitchChangeEvent:(id)sender {
    BOOL oldValue = [FlashCardsCore getSettingBool:@"TTSIgnoresParentheses"];
    BOOL newValue = [sender isOn];
    [FlashCardsCore setSetting:@"TTSIgnoresParentheses" value:[NSNumber numberWithBool:[sender isOn]]];
}

- (void)hideHUD {
    [HUD hide:YES];
}

-(IBAction)useMarkdownChangeEvent:(id)sender {
    [FlashCardsCore setSetting:@"studySettingsUseMarkdown" value:[NSNumber numberWithBool:[sender isOn]]];
    [self.myTableView reloadData];
}

-(IBAction)autocapitalizeTextSwitchChangeEvent:(id)sender {
    [FlashCardsCore setSetting:@"shouldUseAutoCapitalizeText" value:[NSNumber numberWithBool:[sender isOn]]];
}

-(IBAction)autocorrectTextSwitchChangeEvent:(id)sender {
    [FlashCardsCore setSetting:@"shouldUseAutoCorrect" value:[NSNumber numberWithBool:[sender isOn]]];
}

-(IBAction)displayBadgeSwitchChangeEvent:(id)sender {
    [FlashCardsCore setSetting:@"settingDisplayBadge" value:[NSNumber numberWithBool:[sender isOn]]];
}

-(IBAction)displayNotificationSwitchChangeEvent:(id)sender {
    [FlashCardsCore setSetting:@"settingDisplayNotification" value:[NSNumber numberWithBool:[sender isOn]]];
    [self.myTableView reloadData];
}

-(IBAction)swipeToProceedCardSwitchChangeEvent:(id)sender {
    [FlashCardsCore setSetting:@"studySwipeToProceedCard" value:[NSNumber numberWithBool:[sender isOn]]];
}

-(IBAction)proceedNextCardSwitchChangeEvent:(id)sender {
    [FlashCardsCore setSetting:@"studySettingsProceedNextCardOnScore" value:[NSNumber numberWithBool:[sender isOn]]];
}

-(IBAction)autoMergeIdenticalCardsSwitchChangeEvent:(id)sender {
    [FlashCardsCore setSetting:@"importSettingsAutoMergeIdenticalCards" value:[NSNumber numberWithBool:[sender isOn]]];
}

-(IBAction)syncSwitchChangeEvent:(id)sender {
    if ([FlashCardsCore hasSubscription]) {
        if (![sender isOn]) {
            // verify if they want to turn off sync
            RIButtonItem *cancel = [RIButtonItem item];
            cancel.label = NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"");
            cancel.action = ^{
                [syncSwitch setOn:YES];
            };
            
            RIButtonItem *disableLocal = [RIButtonItem item];
            disableLocal.label = NSLocalizedStringFromTable(@"Turn Off On This Device Only", @"Sync", @"");
            disableLocal.action = ^{
                if (![FlashCardsCore isConnectedToInternet]) {
                    NSString *message = NSLocalizedStringFromTable(@"This feature will only work with an active internet connection.", @"Error", @"");
                    FCDisplayBasicErrorMessage(@"", message);
                    [syncSwitch setOn:YES];
                    return;
                }
                
                // Tell server that sync is stopped:
                NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/stop", flashcardsServer]];
                ASIFormDataRequest *requestNum = [[ASIFormDataRequest alloc] initWithURL:url];
                [requestNum prepareCoreDataSyncRequest];
                __block ASIFormDataRequest *requestBlock = requestNum;
                [requestNum setupFlashCardsAuthentication:@"sync/stop"];
                [requestNum addPostValue:[[UIDevice currentDevice] uniqueDeviceIdentifier] forKey:@"device_id"];
                [requestNum addPostValue:[[UIDevice currentDevice] advertisingIdentifier] forKey:@"device_adid"];
                NSString *callKey = [FlashCardsCore randomStringOfLength:20];
                FCLog(@"Call Key: %@", callKey);
                [requestNum addPostValue:[callKey encryptWithKey:flashcardsServerCallKeyEncryptionKey] forKey:@"call"];
                [requestNum setCompletionBlock:^{
                    FCLog(@"Response: %@", requestBlock.responseString);
                }];
                [requestNum startAsynchronous];

                [FlashCardsCore setSetting:@"appIsSyncing" value:@NO];
                [FlashCardsCore setSetting:@"hasExecutedFirstSync" value:@NO];
                TICDSDocumentSyncManager *manager = [[[FlashCardsCore appDelegate] syncController] documentSyncManager];
                NSError *error;
                [manager deregisterDocumentSyncManager];
                if (![manager removeHelperFileDirectory:&error]) {
                    FCDisplayBasicErrorMessage(@"",
                                               [NSString stringWithFormat:@"Error deleting sync directories: %@", error]);
                }
                [self showHUD:2];
                [[[FlashCardsCore appDelegate] syncController] setDocumentSyncManager:nil];
            };

            RIButtonItem *disableAll = [RIButtonItem item];
            disableAll.label = NSLocalizedStringFromTable(@"Turn Off On All Devices", @"Sync", @"");
            disableAll.action = ^{
                if (![FlashCardsCore isConnectedToInternet]) {
                    NSString *message = NSLocalizedStringFromTable(@"This feature will only work with an active internet connection.", @"Error", @"");
                    FCDisplayBasicErrorMessage(@"", message);
                    [syncSwitch setOn:YES];
                    return;
                }
                [[[FlashCardsCore appDelegate] syncController] clearAllLocalAndRemoteData];
            };
            
            RIButtonItem *turnOffSync = [RIButtonItem item];
            turnOffSync.label = NSLocalizedStringFromTable(@"Turn Off Sync", @"Sync", @"");
            turnOffSync.action = ^{
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@""
                                                                message:@""
                                                       cancelButtonItem:cancel
                                                       otherButtonItems:disableAll, disableLocal, nil];
                [alert show];
            };

            if (![FlashCardsCore isConnectedToInternet]) {
                NSString *message = NSLocalizedStringFromTable(@"This feature will only work with an active internet connection.", @"Error", @"");
                FCDisplayBasicErrorMessage(@"", message);
                [syncSwitch setOn:YES];
                return;
            }
            NSString *message = NSLocalizedStringFromTable(@"Are you sure you want to turn off sync? Any changes you make will not automatically be synced with the FlashCards++ server.", @"Sync", @"");
            
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@""
                                                            message:message
                                                   cancelButtonItem:cancel
                                                   otherButtonItems:turnOffSync, nil];
            [alert show];
        } else { // if they don't have a subscription
            if (![FlashCardsCore isConnectedToInternet]) {
                FCDisplayBasicErrorMessage(@"",
                                           NSLocalizedStringFromTable(@"This feature will only work with an active internet connection.", @"Error", @""));
                [syncSwitch setOn:NO];
                return;
            }
            [[FlashCardsCore appDelegate] setupSyncInterface];
        }
    } else {
        if (![FlashCardsCore isConnectedToInternet]) {
            FCDisplayBasicErrorMessage(@"",
                                       NSLocalizedStringFromTable(@"This feature will only work with an active internet connection.", @"Error", @""));
            [syncSwitch setOn:NO];
            return;
        }
        // send them to the subscription screen to either sign up, or sign in:
        SubscriptionViewController *vc = [[SubscriptionViewController alloc] initWithNibName:@"SubscriptionViewController" bundle:nil];
        vc.giveTrialOption = NO;
        vc.showTrialEndedPopup = NO;
        vc.explainSync = YES;
        [self.navigationController pushViewController:vc animated:YES];
    }
}

- (void) helpEvent {
    HelpViewController *helpVC = [[HelpViewController alloc] initWithNibName:@"HelpViewController" bundle:nil];
    
    helpVC.title = self.title;
    helpVC.helpText = NSLocalizedStringWithDefaultValue(@"SettingsStudyVCHelp", @"Help", [NSBundle mainBundle], @""
            "<p><strong>Explanation of FlashCards++ Settings</strong></p>"
            "<ul>"
            "    <li><i>Large Text Mode:</i> Increase the font size when studying your cards.</li>"
            "    <li><i>Background Color:</i> Change the background color when studying your cards.</li>"
            "    <li><i>Auto-Browse Speed:</i> Set how fast you want cards to flip, and proceed to the next card, "
            "when using auto-browse mode.</li>"
            "    <li><i>Go To Next On Store:</i> FlashCards++ can automatically proceed to the next card when you "
            "tap on a score, rather than making you swipe to go to the next card.</li>"
            "    <li><i>Merge Exact Matches:</i> If you turn this on, then when importing cards, FlashCards++ "
            "will automatically merge new cards with previously existing cards when both the front and back "
            "sides of the card match exactly.</li>"
            "</ul>", @"");
    // Pass the selected object to the new view controller.
    [self.navigationController pushViewController:helpVC animated:YES];
    
}


#pragma mark -
#pragma mark MBProgressHUDDelegate methods

- (void)showHUD {
    [self showHUD:0];
}
- (void)showHUD:(int)maxShowTime {
    HUD = [[MBProgressHUD alloc] initWithView:self.view];
    // Add HUD to screen
    [self.view addSubview:HUD];
    // Regisete for HUD callbacks so we can remove it from the window at the right time
    HUD.delegate = self;
    HUD.minShowTime = 1.0;
    [HUD show:YES];
    if (maxShowTime > 0) {
        [HUD hide:YES afterDelay:maxShowTime];
    }
}

- (void)hudWasHidden:(MBProgressHUD *)hud {
    // Remove HUD from screen when the HUD was hidded
    [hud removeFromSuperview];
    if ([hud isEqual:syncHUD]) {
        syncHUD = nil;
    }
    if ([hud isEqual:HUD]) {
        HUD = nil;
    }
    hud = nil;

    self.navigationItem.leftBarButtonItem = nil;
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 6;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    if (section == 0) {
        // Subscription
        NSArray *rows = [self subscriptionRows];
        return [rows count];
    } else if (section == 1) {
        // Text-to-speech - now only has the option about ignoring parens
        return 1;
    } else if (section == 2) {
        return 8; // study settings
    } else if (section == 3) {
        // general settings
        if ([FlashCardsCore getSettingBool:@"settingDisplayNotification"]) {
            return 5;
        } else {
            return 4;

        }
    } else if (section == 4) {
        return 1; // import settings (merge exact matches)
    } else {
        return 1; // database size
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (section < 5) {
        
    }
    return 40;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    
    UIView* customView = [[UIView alloc] initWithFrame:CGRectMake(10.0, 0.0, 300.0, 44.0)];
    
    // create the button object
    UILabel * headerLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    headerLabel.backgroundColor = [UIColor clearColor];
    headerLabel.opaque = NO;
    headerLabel.textColor = [UIColor blackColor];
    headerLabel.highlightedTextColor = [UIColor whiteColor];
    headerLabel.font = [UIFont boldSystemFontOfSize:20];
    if ([FlashCardsAppDelegate isIpad]) {
        headerLabel.frame = CGRectMake(60.0, 0.0, 300.0, 44.0);
    } else {
        headerLabel.frame = CGRectMake(10.0, 0.0, 300.0, 44.0);
    }
    
    if (section == 0) {
        headerLabel.text = NSLocalizedStringFromTable(@"Your Account", @"Settings", @"");
    } else if (section == 1) {
        headerLabel.text = NSLocalizedStringFromTable(@"Text-to-Speech", @"Settings", @"");
    } else if (section == 2) {
        headerLabel.text = NSLocalizedStringFromTable(@"Study Settings", @"Settings", @"");
    } else if (section == 3) {
        headerLabel.text = NSLocalizedStringFromTable(@"General Settings", @"Settings", @"");
    } else if (section == 4) {
        headerLabel.text = NSLocalizedStringFromTable(@"Import Settings", @"Settings", @"");
    } else {
        return nil;
    }
    
    [customView addSubview:headerLabel];
    
    return customView;
}

- (NSString*)subscriptionExplanationString {
    NSString *firstVersionInstalled = (NSString*)[FlashCardsCore getSetting:@"firstVersionInstalled"];
    float version = [firstVersionInstalled floatValue];
    if (version < firstVersionWithFreeDownload) {
        // the user downloaded the app and paid for it; we will explain that only a few features are paid.
        return NSLocalizedStringFromTable(@"Subscribers support the continued development of new features for FlashCards++ and can use text-to-speech features offline.", @"Subscription", @"");
    } else {
        // we have the free download, so most everything is shut off.
        return NSLocalizedStringFromTable(@"Subscribers support the continued development of new features for FlashCards++, can have an unlimited number of cards, and have access to advanced FlashCards++ features like automatic sync, adding images to cards, and text-to-speech.", @"Subscription", @"");
    }
}
- (NSString*)cellularExplanationString {
    return @"";
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    
    if (section != 1 && section != 0) {
        return 0;
    }
    NSString *explanation;
    if (section == 0) {
        explanation = [self subscriptionExplanationString];
    } else {
        explanation = [self cellularExplanationString];
    }
    if ([explanation length] == 0) {
        return 0.0;
    }
    
    // create the button object
    UITextView * footerLabel = [[UITextView alloc] initWithFrame:CGRectMake(0.0f,
                                                                            0.0f,
                                                                            self.view.frame.size.width-16.0,
                                                                            0.0f)];
    footerLabel.backgroundColor = [UIColor clearColor];
    footerLabel.opaque = NO;
    footerLabel.textColor = [UIColor blackColor];
    footerLabel.text = explanation;
    [footerLabel setFont:[UIFont systemFontOfSize:12.0f]];
    [footerLabel setTextAlignment:NSTextAlignmentCenter];
    
    CGSize tallerSize, stringSize;
    tallerSize = CGSizeMake(self.view.frame.size.width-16.0, kMaxFieldHeight);
    CGRect boundingRect = [footerLabel.text boundingRectWithSize:tallerSize
                                                         options:NSStringDrawingUsesLineFragmentOrigin
                                                      attributes:@{NSFontAttributeName:footerLabel.font}
                                                         context:nil];
    stringSize = boundingRect.size;
    return stringSize.height+10.0f;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    if (section != 1 && section != 0) {
        return nil;
    }

    NSString *explanation;
    if (section == 0) {
        explanation = [self subscriptionExplanationString];
    } else {
        explanation = [self cellularExplanationString];
    }

    if ([explanation length] == 0) {
        return nil;
    }
    
    // create the button object
    UITextView * footerLabel = [[UITextView alloc] initWithFrame:CGRectMake(0.0f,
                                                                            0.0f,
                                                                            self.view.frame.size.width-16.0,
                                                                            0.0f)];
    footerLabel.backgroundColor = [UIColor clearColor];
    footerLabel.opaque = NO;
    footerLabel.textColor = [UIColor blackColor];
    footerLabel.text = explanation;
    [footerLabel setFont:[UIFont systemFontOfSize:12.0f]];
    [footerLabel setTextAlignment:NSTextAlignmentCenter];
    footerLabel.userInteractionEnabled = NO;
    
    CGSize tallerSize, stringSize;
    tallerSize = CGSizeMake(self.view.frame.size.width-16.0, kMaxFieldHeight);
    stringSize = [footerLabel.text sizeWithFont:footerLabel.font constrainedToSize:tallerSize lineBreakMode:NSLineBreakByWordWrapping];
    [footerLabel setFrame:CGRectMake(footerLabel.frame.origin.x,
                                     footerLabel.frame.origin.y,
                                     footerLabel.frame.size.width,
                                     stringSize.height+10.0f)];
    
    return footerLabel;
}

- (NSArray*)subscriptionRows {
    NSArray *rows;
    if ([FlashCardsCore isLoggedIn]) {
        if ([FlashCardsCore getSettingBool:@"isTeacher"]) {
            rows =
            @[
              @"name",
              @"subscriptionStatus",
              @"subscriptionEndDate",
              @"studentCount",
              @"purchaseStudentLicenses",
              @"sync"
              ];
        } else if ([FlashCardsCore hasSubscription]) {
            if ([FlashCardsCore getSettingBool:@"hasSubscriptionLifetime"]) {
                rows =
                @[
                  @"name",
                  @"subscriptionStatus",
                  @"subscriptionEndDate",
                  @"sync"
                  ];
            } else {
                rows =
                @[
                  @"name",
                  @"subscriptionStatus",
                  @"subscriptionEndDate",
                  @"renewSubscription",
                  @"sync"
                  ];
            }
        } else {
            rows =
            @[
            @"name",
            @"subscriptionStatus",
            @"renewSubscription",
            @"sync"
            ];
        }
    } else {
        if ([FlashCardsCore hasSubscription]) {
            if ([FlashCardsCore getSettingBool:@"hasSubscriptionLifetime"]) {
                rows =
                @[
                  @"createAccount",
                  @"subscriptionStatus",
                  @"subscriptionEndDate",
                  @"sync"
                  ];
            } else {
                rows =
                @[
                  @"createAccount",
                  @"subscriptionStatus",
                  @"subscriptionEndDate",
                  @"renewSubscription",
                  @"sync"
                  ];
            }
        } else {
            rows =
            @[
            @"subscriptionStatus",
            @"renewSubscription",
            @"restorePurchases",
            @"sync"
            ];
        }
    }
    if (![FlashCardsCore hasFeature:@"HideAds"]) {
        NSMutableArray *mutableRows = [NSMutableArray arrayWithObject:@"hideAds"];
        [mutableRows addObjectsFromArray:rows];
        rows = [NSArray arrayWithArray:mutableRows];
    }
    return rows;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    int row = (int)indexPath.row;
    if (indexPath.section == 0) {
        NSArray *rows = [self subscriptionRows];
        NSString *rowName = [rows objectAtIndex:indexPath.row];
        if ([rowName isEqualToString:@"hideAds"]) {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"hideAdsCell"];
            if (cell == nil) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"hideAdsCell"];
            }
            cell.userInteractionEnabled = YES;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.textLabel.text = NSLocalizedStringFromTable(@"Hide Ads", @"Subscription", @"UILabel");
            return cell;
        } else if ([rowName isEqualToString:@"studentCount"]) {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"hasSubscriptionCell"];
            if (cell == nil) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"hasSubscriptionCell"];
            }
            cell.userInteractionEnabled = YES;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.textLabel.text = NSLocalizedStringFromTable(@"Students Activated", @"Settings", @"UIView title");

            int studentSubscriptionsTotal = [FlashCardsCore getSettingInt:@"studentSubscriptionsTotal"];
            int studentSubscriptionsAllocated = [FlashCardsCore getSettingInt:@"studentSubscriptionsAllocated"];
            
            cell.detailTextLabel.text = [NSString stringWithFormat:NSLocalizedStringFromTable(@"%d of %d", @"CardManagement", @""),
                                         studentSubscriptionsAllocated,
                                         studentSubscriptionsTotal];
            return cell;
        } else if ([rowName isEqualToString:@"purchaseStudentLicenses"]) {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"subscribeCell"];
            if (cell == nil) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"subscribeCell"];
            }
            cell.userInteractionEnabled = YES;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.textLabel.text = NSLocalizedStringFromTable(@"Increase Student Activations", @"Settings", @"UIView title");
            return cell;
        } else if ([rowName isEqualToString:@"createAccount"]) {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"createAccountCell"];
            if (cell == nil) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"createAccountCell"];
            }
            cell.userInteractionEnabled = YES;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.textLabel.text = NSLocalizedStringFromTable(@"Create Account", @"Settings", @"UIView title");
            return cell;
        } else if ([rowName isEqualToString:@"name"]) {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"nameCell"];
            if (cell == nil) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"nameCell"];
            }
            cell.userInteractionEnabled = YES;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.textLabel.text = NSLocalizedStringFromTable(@"Name", @"Settings", @"UIView title");
            cell.detailTextLabel.text = (NSString*)[FlashCardsCore getSetting:@"fcppUsername"];
            return cell;
        } else if ([rowName isEqualToString:@"subscriptionStatus"]) {
            // Subscription: (Active|Inactive)
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"hasSubscriptionCell"];
            if (cell == nil) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"hasSubscriptionCell"];
            }
            cell.userInteractionEnabled = YES;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.textLabel.text = NSLocalizedStringFromTable(@"Subscription Status", @"Settings", @"UIView title");
            if ([FlashCardsCore hasSubscription]) {
                cell.detailTextLabel.text = NSLocalizedStringFromTable(@"Active", @"Settings", @"");
            } else {
                cell.detailTextLabel.text = NSLocalizedStringFromTable(@"Inactive", @"Settings", @"");
            }
            return cell;
        } else if ([rowName isEqualToString:@"renewSubscription"]) {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"subscribeCell"];
            if (cell == nil) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"subscribeCell"];
            }
            cell.userInteractionEnabled = YES;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            if ([FlashCardsCore hasSubscription]) {
                cell.textLabel.text = NSLocalizedStringFromTable(@"Renew Subscription", @"Settings", @"UIView title");
            } else {
                cell.textLabel.text = NSLocalizedStringFromTable(@"Subscribe", @"Settings", @"UIView title");
            }
            return cell;
        } else if ([rowName isEqualToString:@"restorePurchases"]) {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"restorePurchasesCell"];
            if (cell == nil) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"restorePurchasesCell"];
            }
            cell.userInteractionEnabled = YES;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.textLabel.text = NSLocalizedStringFromTable(@"Log In to Restore Purchases", @"Settings", @"UIView title");
            return cell;
        } else if ([rowName isEqualToString:@"subscriptionEndDate"]) {
            // they have purchased the subscription -- show the date when it'll be expired:
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"hasSubscriptionCell"];
            if (cell == nil) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"hasSubscriptionCell"];
            }
            cell.userInteractionEnabled = YES;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.textLabel.text = NSLocalizedStringFromTable(@"Active Until", @"Settings", @"UIView title");
            if ([FlashCardsCore getSettingBool:@"hasSubscriptionLifetime"]) {
                cell.detailTextLabel.text = NSLocalizedStringFromTable(@"Lifetime Subscription", @"Subscription", @"");
            } else {
                NSDate *subscriptionEndDate = [FlashCardsCore getSettingDate:@"subscriptionEndDate"];
                NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                [dateFormatter setDateStyle:NSDateFormatterMediumStyle];
                cell.detailTextLabel.text = [dateFormatter stringFromDate:subscriptionEndDate];
            }
            return cell;
        } else if ([rowName isEqualToString:@"sync"]) {
            return self.syncCell;
        }
    } else if (indexPath.section == 1) {
        // Text-to-speech
        if (row == 0) {
            return self.ignoreParenthesesCell;
        }
    } else if (indexPath.section == 2) {
        // Study settings
        if (row == 0) {
            return self.useMarkdownCell;
        } else if (row == 1) {
            UITableViewCell *cell4 = [tableView dequeueReusableCellWithIdentifier:@"Cell4"];
            if (cell4 == nil) {
                cell4 = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"Cell4"];
            }
            cell4.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell4.textLabel.text = NSLocalizedStringFromTable(@"Text Size", @"Settings", @"UIView title");
            return cell4;
        } else if (row == 2) {
            UITableViewCell *cell3 = [tableView dequeueReusableCellWithIdentifier:@"Cell3"];
            if (cell3 == nil) {
                cell3 = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"Cell3"];
            }
            cell3.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell3.textLabel.text = NSLocalizedStringFromTable(@"Text Justification", @"Settings", @"");
            return cell3;
        } else if (row == 3) {
            UITableViewCell *cell5 = [tableView dequeueReusableCellWithIdentifier:@"Cell5"];
            if (cell5 == nil) {
                cell5 = [[UITableViewCell alloc] initWithStyle: UITableViewCellStyleValue1 reuseIdentifier:@"Cell5"];
            }
            cell5.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell5.textLabel.text = NSLocalizedStringFromTable(@"Text Font", @"Settings", @"");
            return cell5;
        } else if (row == 4) {
            return self.swipeToProceedCardCell;
        } else if (row == 5) {
            UITableViewCell *cell2 = [tableView dequeueReusableCellWithIdentifier:@"Cell2"];
            if (cell2 == nil) {
                cell2 = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"Cell2"];
            }
            cell2.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell2.textLabel.text = NSLocalizedStringFromTable(@"Background Color", @"Settings", @"");
            cell2.detailTextLabel.frame = CGRectMake(cell2.detailTextLabel.frame.origin.x,
                                                     cell2.detailTextLabel.frame.origin.y,
                                                     80,
                                                     cell2.detailTextLabel.frame.size.height);
            cell2.detailTextLabel.textAlignment = NSTextAlignmentCenter;
            return cell2;
        } else if (row == 6) {
            static NSString *CellIdentifier = @"Cell";
            
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
            if (cell == nil) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier];
            }
            
            cell.textLabel.text = NSLocalizedStringFromTable(@"Auto-Browse Speed", @"Settings", @"");
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            
            return cell;
        } else if (row == 7) {
            return self.proceedNextCardCell;
        } else {
            return nil;
        }
    } else if (indexPath.section == 3) {
        if (row > 0 && ![FlashCardsCore getSettingBool:@"settingDisplayNotification"]) {
            row++;
        }
        // general settings
        if (row == 0) {
            return self.displayNotificationCell;
        } else if (row == 1) {
            static NSString *CellIdentifier = @"CellTime";
            
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
            if (cell == nil) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier];
            }
            
            cell.textLabel.text = NSLocalizedStringFromTable(@"Display Notification At", @"Settings", @"");
            int time = [FlashCardsCore getSettingInt:@"settingDisplayNotificationTime"];
            if (time < 12) {
                cell.detailTextLabel.text = [NSString stringWithFormat:NSLocalizedStringFromTable(@"%d AM", @"Settings", @""), time];
            } else {
                time -= 12;
                if (time == 0) {
                    time = 12;
                }
                cell.detailTextLabel.text = [NSString stringWithFormat:NSLocalizedStringFromTable(@"%d PM", @"Settings", @""), time];
            }
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

            return cell;
        } else if (row == 2) {
            return self.displayBadgeCell;
        } else if (row == 3) {
            return self.autocorrectTextCell;
        } else {
            return self.autocapitalizeTextCell;
        }
    } else if (indexPath.section == 4) {
        // import settings
        return self.autoMergeIdenticalCardsCell;
    } else {
        // database size
        static NSString *CellIdentifier = @"CellSize";
        
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier];
        }
        
        cell.userInteractionEnabled = YES;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        
        // as per: http://stackoverflow.com/questions/7846495/how-to-get-file-size-properly-and-convert-it-to-mb-gb-in-cocoa
        NSString *storePath = [[FlashCardsCore documentsDirectory] stringByAppendingPathComponent: @"FlashCards.sqlite"];
        NSError *error = nil;
        NSString *fileSize = nil;
        NSDictionary *attribs = [[NSFileManager defaultManager] attributesOfItemAtPath:storePath error:&error];
        if (!attribs) {
            fileSize = @"unknown";
        }
        if (!fileSize && [FlashCardsCore iOSisGreaterThan:6.0]) {
            fileSize = [NSByteCountFormatter stringFromByteCount:[attribs fileSize] countStyle:NSByteCountFormatterCountStyleFile];
        }
        // for iOS 5
        if (!fileSize) {
            double convertedValue = [[NSNumber numberWithLongLong:[attribs fileSize]] doubleValue];
            int multiplyFactor = 0;
            
            NSArray *tokens = [NSArray arrayWithObjects:@"bytes",@"kb",@"mb",@"gb",@"tb",nil];
            
            while (convertedValue > 1024) {
                convertedValue /= 1024;
                multiplyFactor++;
            }
            
            fileSize = [NSString stringWithFormat:@"%4.2f %@", convertedValue, [tokens objectAtIndex:multiplyFactor]];;
        }

        
        cell.textLabel.text = NSLocalizedStringFromTable(@"Database Size", @"Settings", @"");
        cell.detailTextLabel.text = fileSize;
        cell.accessoryType = UITableViewCellAccessoryNone;
        
        return cell;
    }
    return nil;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0 || indexPath.section == 1 || indexPath.section == 5) {
        return;
    }
    if (indexPath.row == 1) {
        int studyTextSize = [FlashCardsCore getSettingInt:@"studyTextSize"];
        
        if (studyTextSize >= [textSizeOptions count]) {
            studyTextSize = sizeNormal;
        }
        
        for (NSDictionary *option in textSizeOptions) {
            if ([[option objectForKey:@"value"] intValue] == studyTextSize) {
                cell.detailTextLabel.text = [option valueForKey:@"text"];
            }
        }
    } else if (indexPath.row == 2 && indexPath.section == 2) {
        int studyCardJustification = [FlashCardsCore getSettingInt:@"studyCardJustification"];
        cell.detailTextLabel.text = [textJustificationOptions objectAtIndex:studyCardJustification];
    } else if (indexPath.row == 3) {
        NSString *studyCardFont = (NSString*)[FlashCardsCore getSetting:@"studyCardFont"];
        cell.detailTextLabel.text = studyCardFont;
        cell.detailTextLabel.font = [UIFont fontWithName:studyCardFont size:14.0];
    } else  if (indexPath.row == 5) {
        UIColor *backgroundColor = [UIColor colorWithString:(NSString *)[FlashCardsCore getSetting:@"studySettingsBackgroundColor"]];
        UIColor *backgroundTextColor = [UIColor colorWithString:(NSString *)[FlashCardsCore getSetting:@"studySettingsBackgroundTextColor"]];

        if ([FlashCardsCore getSettingBool:@"studyDisplayLikeIndexCard"]) {
            cell.detailTextLabel.text = NSLocalizedStringFromTable(@"Index Card", @"Settings", @"color");
            backgroundColor = [UIColor whiteColor];
            backgroundTextColor = [UIColor blackColor];
        } else if ([backgroundColor isEqual:[UIColor blackColor]]) {
            cell.detailTextLabel.text = NSLocalizedStringFromTable(@"Black", @"Settings", @"color");
        } else if ([backgroundColor isEqual:[UIColor whiteColor]]) {
            cell.detailTextLabel.text = NSLocalizedStringFromTable(@"White", @"Settings", @"color");
        } else if ([backgroundColor isEqual:[UIColor redColor]]) {
            cell.detailTextLabel.text = NSLocalizedStringFromTable(@"Red", @"Settings", @"color");
        } else if ([backgroundColor isEqual:[UIColor orangeColor]]) {
            cell.detailTextLabel.text = NSLocalizedStringFromTable(@"Orange", @"Settings", @"color");
        } else if ([backgroundColor isEqual:[UIColor yellowColor]]) {
            cell.detailTextLabel.text = NSLocalizedStringFromTable(@"Yellow", @"Settings", @"color");
        } else if ([backgroundColor isEqual:[UIColor greenColor]]) {
            cell.detailTextLabel.text = NSLocalizedStringFromTable(@"Green", @"Settings", @"color");
        } else if ([backgroundColor isEqual:[UIColor cyanColor]]) {
            cell.detailTextLabel.text = NSLocalizedStringFromTable(@"Cyan", @"Settings", @"color");
        } else if ([backgroundColor isEqual:[UIColor blueColor]]) {
            cell.detailTextLabel.text = NSLocalizedStringFromTable(@"Blue", @"Settings", @"color");
        } else if ([backgroundColor isEqual:[UIColor purpleColor]]) {
            cell.detailTextLabel.text = NSLocalizedStringFromTable(@"Purple", @"Settings", @"color");
        } else if ([backgroundColor isEqual:[UIColor brownColor]]) {
            cell.detailTextLabel.text = NSLocalizedStringFromTable(@"Brown", @"Settings", @"color");
        } else if ([backgroundColor isEqual:[UIColor grayColor]]) {
            cell.detailTextLabel.text = NSLocalizedStringFromTable(@"Gray", @"Settings", @"color");
        }
        
        cell.detailTextLabel.backgroundColor = backgroundColor;
        cell.detailTextLabel.textColor = backgroundTextColor;
    } else if (indexPath.row == 6) {
        [self displayAutoBrowseSpeed:cell];
    }
}

#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // Navigation logic may go here. Create and push another view controller.
    int row = (int)indexPath.row;
    if (indexPath.section != 2) {
        [tableView deselectRowAtIndexPath:indexPath animated:NO];
        if (indexPath.section == 0) {
            NSArray *rows = [self subscriptionRows];
            NSString *rowName = [rows objectAtIndex:indexPath.row];
            if ([rowName isEqualToString:@"hideAds"]) {
                [Flurry logEvent:@"HideAds"];
                SubscriptionViewController *vc = [[SubscriptionViewController alloc] initWithNibName:@"SubscriptionViewController" bundle:nil];
                vc.showTrialEndedPopup = NO;
                vc.giveTrialOption = NO;
                vc.explainSync = NO;
                [self.navigationController pushViewController:vc animated:YES];
            } else if ([rowName isEqualToString:@"purchaseStudentLicenses"]) {
                TeachersViewController *vc = [[TeachersViewController alloc] initWithNibName:@"TeachersViewController" bundle:nil];
                [self.navigationController pushViewController:vc animated:YES];
            } else if ([rowName isEqualToString:@"createAccount"]) {
                AppLoginViewController *vc = [[AppLoginViewController alloc] initWithNibName:@"AppLoginViewController" bundle:nil];
                vc.isCreatingNewAccount = YES;
                [self.navigationController pushViewController:vc animated:YES];
            } else if ([rowName isEqualToString:@"renewSubscription"]) {
                SubscriptionViewController *vc = [[SubscriptionViewController alloc] initWithNibName:@"SubscriptionViewController" bundle:nil];
                vc.giveTrialOption = NO;
                vc.showTrialEndedPopup = NO;
                vc.explainSync = NO;
                [self.navigationController pushViewController:vc animated:YES];
            } else if ([rowName isEqualToString:@"restorePurchases"]) {
                AppLoginViewController *vc = [[AppLoginViewController alloc] initWithNibName:@"AppLoginViewController" bundle:nil];
                vc.isCreatingNewAccount = NO;
                [self.navigationController pushViewController:vc animated:YES];
            } else if ([rowName isEqualToString:@"name"]) {
                NSMutableString *message = [NSMutableString stringWithString:NSLocalizedStringFromTable(@"Do you want to log out of your FlashCards++ account?", @"Settings", @"")];
                if ([FlashCardsCore hasSubscription]) {
                    [message appendFormat:@" %@", NSLocalizedStringFromTable(@"Your subscription will be suspended on this device when you log out.", @"Subscription", @"")];
                }
                UIAlertView *alert;
                
                
                RIButtonItem *cancel = [RIButtonItem item];
                cancel.label = NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"");
                cancel.action = ^{
                };

                RIButtonItem *resetPassword = [RIButtonItem item];
                resetPassword.label = NSLocalizedStringFromTable(@"Reset Password", @"Subscription", @"");
                resetPassword.action = ^{
                    if (![FlashCardsCore isConnectedToInternet]) {
                        FCDisplayBasicErrorMessage(@"",
                                                   NSLocalizedStringFromTable(@"You must be connected to the internet to create a new account or log in.", @"Error", @""));
                        return;
                    }
                    
                    // try to log in:
                    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/user/forgotpassword", flashcardsServer]];
                    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
                    __block ASIFormDataRequest *requestBlock = request;
                    [request addPostValue:[FlashCardsCore getSetting:@"fcppUsername"] forKey:@"email"];
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
                };

                RIButtonItem *logOut = [RIButtonItem item];
                logOut.label = NSLocalizedStringFromTable(@"Log Out", @"Subscription", @"");
                logOut.action = ^{
                    if (![FlashCardsCore isConnectedToInternet]) {
                        FCDisplayBasicErrorMessage(@"",
                                                   NSLocalizedStringFromTable(@"You must be connected to the internet to log out.", @"Error", @""));
                        return;
                    }
                    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/user/logout", flashcardsServer]];
                    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
                    [request setupFlashCardsAuthentication:@"user/logout"];
                    [request addPostValue:[[UIDevice currentDevice] uniqueDeviceIdentifier] forKey:@"device_id"];
                    [request addPostValue:[[UIDevice currentDevice] advertisingIdentifier] forKey:@"device_adid"];
                    [request setCompletionBlock:^{
                        [HUD hide:YES];
                        [FlashCardsCore logout];
                        [self.myTableView reloadData];
                        NSString *message = NSLocalizedStringFromTable(@"You have been logged out successfully.", @"Subscription", @"");
                        FCDisplayBasicErrorMessage(@"", message);
                    }];
                    [request startAsynchronous];
                    [self showHUD];
                };

                RIButtonItem *logOutAll = [RIButtonItem item];
                logOutAll.label = NSLocalizedStringFromTable(@"Log Out All Devices", @"Subscription", @"");
                logOutAll.action = ^{
                    if (![FlashCardsCore isConnectedToInternet]) {
                        FCDisplayBasicErrorMessage(@"",
                                                   NSLocalizedStringFromTable(@"You must be connected to the internet to log out.", @"Error", @""));
                        return;
                    }
                    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/user/logoutall", flashcardsServer]];
                    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
                    [request setupFlashCardsAuthentication:@"user/logoutall"];
                    [request addPostValue:[[UIDevice currentDevice] uniqueDeviceIdentifier] forKey:@"device_id"];
                    [request addPostValue:[[UIDevice currentDevice] advertisingIdentifier] forKey:@"device_adid"];
                    [request setCompletionBlock:^{
                        [HUD hide:YES];
                        [FlashCardsCore logout];
                        [self.myTableView reloadData];
                        NSString *message = NSLocalizedStringFromTable(@"All devices associated with this account have been logged out.", @"Subscription", @"");
                        FCDisplayBasicErrorMessage(@"", message);
                    }];
                    [request startAsynchronous];
                    [self showHUD];
                };
                
                
                if ([FlashCardsCore getSettingInt:@"fcppLoginNumberDevices"] > 1) {
                    alert = [[UIAlertView alloc] initWithTitle:@""
                                                       message:message
                                              cancelButtonItem:cancel
                                              otherButtonItems:logOut, logOutAll, resetPassword, nil];
                } else {
                    alert = [[UIAlertView alloc] initWithTitle:@""
                                                       message:message
                                              cancelButtonItem:cancel
                                              otherButtonItems:logOut, resetPassword, nil];
                }
                [alert show];
            }
        } else if (indexPath.section == 3) {
            if (indexPath.row == 1 && [FlashCardsCore getSettingBool:@"settingDisplayNotification"]) {
                [tableView deselectRowAtIndexPath:indexPath animated:YES];
                ActionStringCancelBlock cancel = ^(ActionSheetStringPicker *picker) {
                    NSLog(@"Block Picker Canceled");
                };
                ActionStringDoneBlock done = ^(ActionSheetStringPicker *picker, NSInteger selectedIndex, id selectedValue) {
                    [FlashCardsCore setSetting:@"settingDisplayNotificationTime" value:[NSNumber numberWithInt:selectedIndex]];
                    [self.myTableView reloadData];
                };
                NSMutableArray *options = [NSMutableArray arrayWithCapacity:0];
                for (int i = 0; i < 24; i++) {
                    int time = i;
                    if (time < 12) {
                        [options addObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"%d AM", @"Settings", @""), time]];
                    } else {
                        time -= 12;
                        if (time == 0) {
                            time = 12;
                        }
                        [options addObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"%d PM", @"Settings", @""), time]];
                    }
                }
                UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
                [ActionSheetStringPicker showPickerWithTitle:cell.textLabel.text
                                                        rows:options
                                            initialSelection:[FlashCardsCore getSettingInt:@"settingDisplayNotificationTime"]
                                                   doneBlock:done
                                                 cancelBlock:cancel
                                                      origin:self.navigationItem.rightBarButtonItem];
            }
        }
        return; // do nothing if we are not looking at the first section.
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    ActionStringCancelBlock cancel = ^(ActionSheetStringPicker *picker) {
        NSLog(@"Block Picker Canceled");
    };
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    if (row == 1) {
        // first side: show the picker
        ActionStringDoneBlock done = ^(ActionSheetStringPicker *picker, NSInteger selectedIndex, id selectedValue) {
            NSDictionary *option = [textSizeOptions objectAtIndex:selectedIndex];
            int studyTextSize = [[option valueForKey:@"value"] intValue];
            [FlashCardsCore setSetting:@"studyTextSize" value:[NSNumber numberWithFloat:studyTextSize]];
            [self.myTableView reloadData];
        };
        NSMutableArray *options = [NSMutableArray arrayWithCapacity:0];
        int i = 0;
        int initialSelection = 0;
        int studyTextSize = [FlashCardsCore getSettingInt:@"studyTextSize"];
        for (NSDictionary *option in textSizeOptions) {
            [options addObject:[option valueForKey:@"text"]];
            if ([[option objectForKey:@"value"] intValue] == studyTextSize) {
                initialSelection = i;
            }
            i++;
        }
        [ActionSheetStringPicker showPickerWithTitle:cell.textLabel.text
                                                rows:options
                                    initialSelection:initialSelection
                                           doneBlock:done
                                         cancelBlock:cancel
                                              origin:self.navigationItem.rightBarButtonItem];

    } else if (row == 2) {
        ActionStringDoneBlock done = ^(ActionSheetStringPicker *picker, NSInteger selectedIndex, id selectedValue) {
            [FlashCardsCore setSetting:@"studyCardJustification" value:[NSNumber numberWithFloat:selectedIndex]];
            [self.myTableView reloadData];
        };
        
        int studyCardJustification = [FlashCardsCore getSettingInt:@"studyCardJustification"];
        [ActionSheetStringPicker showPickerWithTitle:cell.textLabel.text
                                                rows:textJustificationOptions
                                    initialSelection:studyCardJustification
                                           doneBlock:done
                                         cancelBlock:cancel
                                              origin:self.navigationItem.rightBarButtonItem];
    } else if (row == 3) {
        ActionStringDoneBlock done = ^(ActionSheetStringPicker *picker, NSInteger selectedIndex, id selectedValue) {
            [FlashCardsCore setSetting:@"studyCardFont" value:[fontOptions objectAtIndex:selectedIndex]];
            [self.myTableView reloadData];
        };
        
        NSString *studyCardFont = (NSString*)[FlashCardsCore getSetting:@"studyCardFont"];
        int initialSelection = 0;
        for (NSString *font in fontOptions) {
            if ([font isEqualToString:studyCardFont]) {
                break;
            }
            initialSelection++;
        }
        [ActionSheetStringPicker showPickerWithTitle:cell.textLabel.text
                                                rows:fontOptions
                                    initialSelection:initialSelection
                                           doneBlock:done
                                         cancelBlock:cancel
                                              origin:self.navigationItem.rightBarButtonItem];
    } else {
        if (row == 5) {
            SettingsStudyBackgroundColorViewController *vc = [[SettingsStudyBackgroundColorViewController alloc] initWithNibName:@"SettingsStudyBackgroundColorViewController" bundle:nil];
            [self.navigationController pushViewController:vc animated:YES];
        } else if (row == 6) {
            ActionStringDoneBlock done = ^(ActionSheetStringPicker *picker, NSInteger selectedIndex, id selectedValue) {
                float cellSpeed = [[autoBrowseSpeedOptions objectAtIndex:selectedIndex] floatValue];
                [FlashCardsCore setSetting:@"studySettingsAutoBrowseSpeed" value:[NSNumber numberWithFloat:cellSpeed]];
                [self displayAutoBrowseSpeed];
            };
            
            float userSpeed = [(NSNumber*)[FlashCardsCore getSetting:@"studySettingsAutoBrowseSpeed"] floatValue];
            NSMutableArray *autoBrowseSpeedOptionsStrings = [NSMutableArray arrayWithCapacity:0];
            int i = 0;
            int initialSelection = 0;
            NSString *speedString;
            for (NSNumber *speed in autoBrowseSpeedOptions) {
                speedString = [NSString stringWithFormat:FCPluralLocalizedStringFromTable(@"%1.1f Seconds", @"Plural", @"", speed), [speed floatValue], nil];
                [autoBrowseSpeedOptionsStrings addObject:speedString];
                if ([speed floatValue] == userSpeed) {
                    initialSelection = i;
                }
                i++;
            }
            [ActionSheetStringPicker showPickerWithTitle:cell.textLabel.text
                                                    rows:autoBrowseSpeedOptionsStrings
                                        initialSelection:initialSelection
                                               doneBlock:done
                                             cancelBlock:cancel
                                                  origin:self.navigationItem.rightBarButtonItem];
        } else {
            [self.myTableView deselectRowAtIndexPath:indexPath animated:NO];
        }
    }
}


#pragma mark -
#pragma mark Memory management

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Relinquish ownership any cached data, images, etc that aren't in use.
}

@end

