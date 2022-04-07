//
//  SettingsAdvancedViewController.m
//  FlashCards
//
//  Created by Jason Lustig on 2/2/13.
//  Copyright (c) 2013 Jason Lustig. All rights reserved.
//

#import "SettingsAdvancedViewController.h"

#import "UIAlertView+Blocks.h"
#import "MBProgressHUD.h"
#import "JSONKit.h"
#import "NSData+MD5.h"

#import "FlashCardsAppDelegate.h"
#import "InAppPurchaseManager.h"

#import "DTVersion.h"

@interface SettingsAdvancedViewController ()

@end

@implementation SettingsAdvancedViewController

@synthesize optimizeDatabaseButton;
@synthesize resetAllSettingsButton;
@synthesize completelyDisableSyncButton;
@synthesize enterCodeButton;
@synthesize validateReceiptsButton;
@synthesize HUD;
@synthesize syncHUD;

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

    if (![DTVersion osVersionIsLessThen:@"7.0"]) {
        self.edgesForExtendedLayout= UIRectEdgeNone;
    }
    
    self.title = NSLocalizedStringFromTable(@"Advanced Settings", @"Settings", @"");
    
    [resetAllSettingsButton setTitle:NSLocalizedStringFromTable(@"Reset All Settings", @"Settings", @"UIButton") forState:UIControlStateNormal];
    [resetAllSettingsButton setTitle:NSLocalizedStringFromTable(@"Reset All Settings", @"Settings", @"UIButton") forState:UIControlStateSelected];
    
    [optimizeDatabaseButton setTitle:NSLocalizedStringFromTable(@"Optimize Database", @"Settings", @"UIButton") forState:UIControlStateNormal];
    [optimizeDatabaseButton setTitle:NSLocalizedStringFromTable(@"Optimize Database", @"Settings", @"UIButton") forState:UIControlStateSelected];

    [enterCodeButton setTitle:NSLocalizedStringFromTable(@"Enter Code", @"Settings", @"UIView title") forState:UIControlStateNormal];
    [enterCodeButton setTitle:NSLocalizedStringFromTable(@"Enter Code", @"Settings", @"UIView title") forState:UIControlStateSelected];
    
    [validateReceiptsButton setTitle:NSLocalizedStringFromTable(@"Validate In-App Purchase Receipts", @"Settings", @"UIView title") forState:UIControlStateNormal];
    [validateReceiptsButton setTitle:NSLocalizedStringFromTable(@"Validate In-App Purchase Receipts", @"Settings", @"UIView title") forState:UIControlStateSelected];
    
    [completelyDisableSyncButton setTitle:NSLocalizedStringFromTable(@"Completely Disable Sync", @"Settings", @"UIView title") forState:UIControlStateNormal];
    [completelyDisableSyncButton setTitle:NSLocalizedStringFromTable(@"Completely Disable Sync", @"Settings", @"UIView title") forState:UIControlStateSelected];

    [self checkDisplayButtons];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)checkDisplayButtons {
    if ([FlashCardsCore appIsSyncing]) {
        completelyDisableSyncButton.hidden = NO;
    } else {
        completelyDisableSyncButton.hidden = YES;
    }
}

# pragma mark - events

-(void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if(buttonIndex == 1)
    {
        /*  get the user iputted text  */
        NSString *inputValue = [[alertView textFieldAtIndex:0] text];
        
        HUD = [[MBProgressHUD alloc] initWithView:self.view];
        [self.view addSubview:HUD];
        
        // Regisete for HUD callbacks so we can remove it from the window at the right time
        HUD.delegate = self;
        HUD.minShowTime = 0.0;
        HUD.labelText = NSLocalizedStringFromTable(@"Checking Code", @"Settings", @"HUD");
        [HUD show:YES];
        
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/user/code", flashcardsServer]];
        ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
        __block ASIFormDataRequest *requestBlock = request;
        [request setupFlashCardsAuthentication:@"user/code"];
        
        NSString *callKey = [FlashCardsCore randomStringOfLength:20];
        FCLog(@"Call Key: %@", callKey);
        
        /*
         NSData *callKeyData = [callKey dataUsingEncoding:NSUTF8StringEncoding];
         NSData *keyCallKey = [NSData dataWithBytes:[[flashcardsServerCallKeyEncryptionKey sha256] bytes] length:kCCKeySizeAES128];
         NSData *encryptedCallKey = [callKeyData aesEncryptedDataWithKey:keyCallKey];
         */
        [request addPostValue:[callKey encryptWithKey:flashcardsServerCallKeyEncryptionKey] forKey:@"call"];
        
        [request addPostValue:inputValue forKey:@"code"];
        
        [request setCompletionBlock:^{
            FCLog(@"%@", requestBlock.responseString);
            NSDictionary *response = [requestBlock.responseData objectFromJSONData];
            NSString *responseKey = [response objectForKey:@"response"];
            NSString *doubledCallKey = [NSString stringWithFormat:@"%@%@", callKey, callKey];
            // compare the response key to the call key. It should be an MD5 hash of hte call key
            // which was appended to itself. This is how we know that we actually communicated with
            // the proper server.
            [HUD hide:YES];

            if (![responseKey isEqualToString:[doubledCallKey md5]]) {
                return;
            }
            
            int ok = [(NSNumber*)[response objectForKey:@"ok"] intValue];
            if (ok == 1) {
                [FlashCardsCore setSetting:@"firstVersionInstalled" value:@"5.3"];
                [FlashCardsCore setSetting:@"firstBuildInstalled" value:@"1"];
                FCDisplayBasicErrorMessage(@"",
                                           NSLocalizedStringFromTable(@"Code accepted. FlashCards++ will now be usable without a subscription, because you purchased the app before it was available for free.", @"Settings", @""));
            } else {
                FCDisplayBasicErrorMessage(@"",
                                           NSLocalizedStringFromTable(@"Invalid code.", @"Settings", @""));
            }
        }];
        
        [request startAsynchronous];
    }
}

-(IBAction)validateReceipts:(id)sender {
    if (![FlashCardsCore isConnectedToInternet]) {
        FCDisplayBasicErrorMessage(@"",
                                   NSLocalizedStringFromTable(@"You are not connected to the internet.", @"Error", @""));
        return;
    }
    
    NSData *data = (NSData*)[FlashCardsCore getSetting:@"fcppTransactionReceiptsToBeUploaded"];
    NSMutableArray *transactions = [NSMutableArray arrayWithArray:(NSArray*)[NSKeyedUnarchiver unarchiveObjectWithData:data]];
    if ([transactions count] == 0) {
        FCDisplayBasicErrorMessage(@"",
                                   NSLocalizedStringFromTable(@"You do not have any in-app purchases to validate.", @"Subscription", @""));
        return;
    }
    
    [[[FlashCardsCore appDelegate] inAppPurchaseManager] uploadAllQueuedTransactions];

}

-(IBAction)enterCode:(id)sender {
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@""
                                                        message:NSLocalizedStringFromTable(@"Enter Code", @"Settings", @"")
                                                       delegate:self
                                             cancelButtonTitle:NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"")
                                             otherButtonTitles:NSLocalizedStringFromTable(@"OK", @"FlashCards", @""), nil];
    alertView.alertViewStyle = UIAlertViewStylePlainTextInput;
    [alertView show];

}


-(IBAction)completelyDisableSync:(id)sender {
    RIButtonItem *cancelItem = [RIButtonItem item];
    cancelItem.label = NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"");
    cancelItem.action = ^{};
    
    RIButtonItem *disableItem = [RIButtonItem item];
    disableItem.label = NSLocalizedStringFromTable(@"Turn Off Sync", @"Sync", @"");
    disableItem.action = ^{
        [[[FlashCardsCore appDelegate] syncController] clearAllLocalAndRemoteData];
    };
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Are You Sure?", @"FlashCards", @"")
                                                    message:NSLocalizedStringFromTable(@"This will disable Automatic Sync on all your devices and remove all sync data from this device. Your currently existing flash cards and card sets will not be affected.", @"Settings", @"")
                                           cancelButtonItem:cancelItem
                                           otherButtonItems:disableItem, nil];
    [alert show];

}

-(IBAction)optimizeDatabase:(id)sender {
    RIButtonItem *cancelItem = [RIButtonItem item];
    cancelItem.label = NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"");
    cancelItem.action = ^{};
    
    RIButtonItem *optimizeItem = [RIButtonItem item];
    optimizeItem.label = NSLocalizedStringFromTable(@"Optimize Database", @"Settings", @"");
    optimizeItem.action = ^{
        HUD = [[MBProgressHUD alloc] initWithView:self.view];
        // Add HUD to screen
        [self.view addSubview:HUD];
        // Regisete for HUD callbacks so we can remove it from the window at the right time
        HUD.delegate = self;
        HUD.minShowTime = 1.0;
        HUD.labelText = NSLocalizedStringFromTable(@"Compressing Database", @"Import", @"HUD");
        HUD.detailsLabelText = NSLocalizedStringFromTable(@"May take a minute on large databases.", @"FlashCards", @"HUD");
        [HUD show:YES];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[FlashCardsCore appDelegate] compressImagesAndPerformSelector:@selector(reloadDatabase:)
                                                                onDelegate:[FlashCardsCore appDelegate]
                                                                withObject:@NO
                                                        inBackgroundThread:YES];
        });
    };
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@""
                                                    message:NSLocalizedStringFromTable(@"Are you sure you want to optimize your database? It is highly recommended that you first make a backup, just in case.", @"Settings", @"")
                                           cancelButtonItem:cancelItem
                                           otherButtonItems:optimizeItem, nil];
    [alert show];
    
}

-(IBAction)resetAllSettings:(id)sender {
    
    RIButtonItem *cancelItem = [RIButtonItem item];
    cancelItem.label = NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"");
    cancelItem.action = ^{};
    
    RIButtonItem *resetItem = [RIButtonItem item];
    resetItem.label = NSLocalizedStringFromTable(@"Reset Settings", @"Settings", @"");
    resetItem.action = ^{
        [self resetAllSettings];
    };
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Are You Sure?", @"FlashCards", @"")
                                                    message:NSLocalizedStringFromTable(@"Are you sure you want to reset all settings? You will be logged out of Dropbox and Quizlet. If you are a FlashCards++ Subscriber, you will need to log in again to restore your subscription. All of your flash card and study data will remain.", @"Settings", @"")
                                           cancelButtonItem:cancelItem
                                           otherButtonItems:resetItem, nil];
    [alert show];
    
}
- (void)resetAllSettings {
    // as per: http://stackoverflow.com/a/6358936/353137
    NSDictionary *defaultsDictionary = [[NSUserDefaults standardUserDefaults] dictionaryRepresentation];
    for (NSString *key in [defaultsDictionary allKeys]) {
        if ([key isEqualToString:@"firstVersionInstalled"]) {
            continue;
        }
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
    // [self displayAll];
    // [self.myTableView reloadData];
    FCDisplayBasicErrorMessage(@"",
                               NSLocalizedStringFromTable(@"Your settings have been reset.", @"Settings", @""));
}

- (void)hudWasHidden:(MBProgressHUD *)hud {
    // Remove HUD from screen when the HUD was hidded
    [hud removeFromSuperview];
    if ([hud isEqual:HUD]) {
        HUD = nil;
    }
    if ([hud isEqual:syncHUD]) {
        syncHUD = nil;
    }
    hud = nil;
    
    self.navigationItem.leftBarButtonItem = nil;
}




@end
