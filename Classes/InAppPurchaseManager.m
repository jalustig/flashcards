//
//  InAppPurchaseManager.m
//  FlashCards
//
//  Created by Jason Lustig on 11/15/12.
//  Copyright (c) 2012 Jason Lustig. All rights reserved.
//

#import "InAppPurchaseManager.h"
#import "FlashCardsCore.h"
#import "FlashCardsAppDelegate.h"

#import "AppLoginViewController.h"
#import "SubscriptionViewController.h"
#import "AppLoginViewController.h"
#import "SubscriptionCodeSetupControllerViewController.h"
#import "TeachersViewController.h"
#import "StudentViewController.h"
#import "StudentFinishViewController.h"

#import "ASIFormDataRequest.h"
#import "ASINetworkQueue.h"

#import "UIDevice+IdentifierAddition.h"
#import "JSONKit.h"

#import "UIAlertView+Blocks.h"
#import "NSDate+Compare.h"

@implementation InAppPurchaseManager

@synthesize proUpgradeProducts;
@synthesize productsRequest;
@synthesize transactionQueue;

#pragma -
#pragma Public methods

#pragma -
#pragma Purchase helpers

//
// saves a record of the transaction by storing the receipt to disk
//
- (void)recordTransaction:(SKPaymentTransaction *)transaction
{
    int timeInterval = 0;
    NSString *productIdentifier = transaction.payment.productIdentifier;
    if ([productIdentifier isEqualToString:kInAppPurchaseProUpgrade3Months]) {
        timeInterval = (60 * 60 * 24) * 30 * 3;
    } else if ([productIdentifier isEqualToString:kInAppPurchaseProUpgrade6Months]) {
        timeInterval = (60 * 60 * 24) * 182;
    } else if ([productIdentifier isEqualToString:kInAppPurchaseProUpgrade12Months]) {
        timeInterval = (60 * 60 * 24) * 365;
    } else if ([productIdentifier isEqualToString:kInAppPurchaseProUpgradeLifetime]) {
        timeInterval = (60 * 60 * 24) * 365 * 99;
        [FlashCardsCore setSetting:@"hasSubscriptionLifetime" value:@YES];
    } else if ([productIdentifier isEqualToString:kInAppPurchaseProUpgradeTeachers10]) {
        timeInterval = (60 * 60 * 24) * 365 * 99;
        [FlashCardsCore setSetting:@"hasSubscriptionLifetime" value:@YES];
        [FlashCardsCore setSetting:@"isTeacher" value:@YES];
    } else if ([productIdentifier isEqualToString:kInAppPurchaseProUpgradeTeachers25]) {
        timeInterval = (60 * 60 * 24) * 365 * 99;
        [FlashCardsCore setSetting:@"hasSubscriptionLifetime" value:@YES];
        [FlashCardsCore setSetting:@"isTeacher" value:@YES];
    } else if ([productIdentifier isEqualToString:kInAppPurchaseProUpgradeTeachers100]) {
        timeInterval = (60 * 60 * 24) * 365 * 99;
        [FlashCardsCore setSetting:@"hasSubscriptionLifetime" value:@YES];
        [FlashCardsCore setSetting:@"isTeacher" value:@YES];
    }
    // save the transaction receipt to disk
    [FlashCardsCore setSetting:@"hasSubscription" value:@YES];
    [FlashCardsCore setSetting:@"subscriptionProductId" value:transaction.payment.productIdentifier];
    [FlashCardsCore setSetting:@"subscriptionBeginDate" value:transaction.transactionDate];
    
    // If the user already is subscribed, add the period of time purchased to the existing end-date.
    if ([FlashCardsCore getSettingBool:@"hasSubscription"]) {
        NSDate *endDate = [FlashCardsCore getSettingDate:@"subscriptionEndDate"];
        // if the old subscription end date is earlier than now, then update it to the current date
        // so that when we add the end dates together we get 3 (6/9/etc) months from NOW, not the old end date.
        if ([endDate isEarlierThan:[NSDate date]]) {
            endDate = [NSDate date];
        }
        [FlashCardsCore setSetting:@"subscriptionEndDate" value:[NSDate dateWithTimeInterval:timeInterval
                                                                                   sinceDate:endDate]];
    } else {
        [FlashCardsCore setSetting:@"subscriptionEndDate" value:[NSDate dateWithTimeInterval:timeInterval
                                                                                   sinceDate:transaction.transactionDate]];
    }
}

# pragma mark - Internal API Methods

// Sends the transaction to api.iphoneflashcards.com for verification.
// On verification, it thanks the user for purchasing and potentially
- (void)verifyTransaction:(SKPaymentTransaction *)transaction {
    
    // update the subscription end date:
    [self recordTransaction:transaction];
    
    UIViewController *vc = [FlashCardsCore currentViewController];
    if ([vc respondsToSelector:@selector(setHUDLabel:)]) {
        [vc performSelectorOnMainThread:@selector(setHUDLabel:)
                             withObject:NSLocalizedStringFromTable(@"Processing Purchase", @"Subscription", @"")
                          waitUntilDone:NO];
    }

    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/user/receipt", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request setupFlashCardsAuthentication:@"user/receipt"];
    if ([FlashCardsCore isLoggedIn]) {
        [request addPostValue:[FlashCardsCore getSetting:@"fcppUsername"] forKey:@"email"];
        [request addPostValue:[FlashCardsCore getSetting:@"fcppLoginKey"] forKey:@"login_key"];
    } else {
        [request addPostValue:[[UIDevice currentDevice] uniqueDeviceIdentifier] forKey:@"device_id"];
        [request addPostValue:[[UIDevice currentDevice] advertisingIdentifier] forKey:@"device_adid"];
    }
    NSString *receiptString = [[NSString alloc] initWithData:transaction.transactionReceipt encoding:NSUTF8StringEncoding];
    [request addPostValue:receiptString forKey:@"transaction_receipt"];

    NSData *data = (NSData*)[FlashCardsCore getSetting:@"fcppTransactionReceiptsToBeUploaded"];
    NSMutableArray *transactions = [NSMutableArray arrayWithArray:(NSArray*)[NSKeyedUnarchiver unarchiveObjectWithData:data]];
    [transactions addObject:receiptString];
    NSData *transactionsAsData = [NSKeyedArchiver archivedDataWithRootObject:transactions];
    [FlashCardsCore setSetting:@"fcppTransactionReceiptsToBeUploaded" value:transactionsAsData];

    [request setCompletionBlock:^{
        FCLog(@"%@", requestBlock.responseString);
        NSMutableDictionary *json = [requestBlock.responseString objectFromJSONString];
        BOOL isHacker = NO;
        BOOL isError = NO;
        // For teachers:
        BOOL isTeacher = NO;
        int maxSubscriptions = 0;
        int allocatedSubscriptions = 0;
        BOOL subscriptionCodeSetup = NO;
        NSString *errorMessage = @"";
        if (json) {
            isHacker = [(NSNumber*)[json objectForKey:@"is_hacker"] boolValue];
            isError  = [(NSNumber*)[json objectForKey:@"is_error"] boolValue];
            isTeacher  = [(NSNumber*)[json objectForKey:@"is_teacher"] boolValue];
            maxSubscriptions = [(NSNumber*)[json objectForKey:@"max_subscriptions"] intValue];
            allocatedSubscriptions = [(NSNumber*)[json objectForKey:@"allocated_subscriptions"] intValue];
            subscriptionCodeSetup = [(NSNumber*)[json objectForKey:@"subscription_code_setup"] boolValue];
            errorMessage = [json objectForKey:@"error_message"];
            // valid JSON, so we can remove the transaction from the queue:
            NSData *data = (NSData*)[FlashCardsCore getSetting:@"fcppTransactionReceiptsToBeUploaded"];
            NSMutableArray *transactions = [NSMutableArray arrayWithArray:(NSArray*)[NSKeyedUnarchiver unarchiveObjectWithData:data]];
            [transactions removeObject:receiptString];
            NSData *transactionsAsData = [NSKeyedArchiver archivedDataWithRootObject:transactions];
            [FlashCardsCore setSetting:@"fcppTransactionReceiptsToBeUploaded" value:transactionsAsData];
        }
        [Flurry logEvent:@"Subscription/Verified"
          withParameters:@{
         @"ProductId" : transaction.payment.productIdentifier,
         @"FromQueue" : @NO
         }];
        // hide the HUD:
        UIViewController *vc = [FlashCardsCore currentViewController];
        if ([vc respondsToSelector:@selector(hideHUD)]) {
            [vc performSelectorOnMainThread:@selector(hideHUD) withObject:nil waitUntilDone:NO];
        }
        if (isError) {
            FCDisplayBasicErrorMessage(@"",
                                       [NSString stringWithFormat:NSLocalizedStringFromTable(@"There was an error processing your purchase: %@", @"Subscription", @""),
                                        errorMessage]);
            return;
        }
        // Let the user know how long their subscription will last for:
        // We should ALWAYS thank the user and let them know how long it'll last for.
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateStyle:NSDateFormatterMediumStyle];
        NSDate *subscriptionEndDate = [FlashCardsCore getSettingDate:@"subscriptionEndDate"];
        NSString *thankYou = NSLocalizedStringFromTable(@"Thank you for subscribing.", @"Subscription", @"");
        NSString *willContinue = [NSString stringWithFormat:NSLocalizedStringFromTable(@"Your subscription will continue until %@.", @"Subscription", @""),
                                             [dateFormatter stringFromDate:subscriptionEndDate]];
        NSString *subscriptionsRemaining = [NSString stringWithFormat:FCPluralLocalizedStringFromTable(@"You now have %d of %d Subscriptions available for your students.", @"Plural", @"", [NSNumber numberWithInt:maxSubscriptions]),
                                            (maxSubscriptions-allocatedSubscriptions),
                                            maxSubscriptions];
        
        NSString *subscriptionExplanation;
        if (isTeacher) {
            subscriptionExplanation = [NSString stringWithFormat:@"%@ %@", thankYou, subscriptionsRemaining];
        } else if ([transaction.payment.productIdentifier isEqualToString:kInAppPurchaseProUpgradeLifetime] ||
            [FlashCardsCore getSettingBool:@"hasSubscriptionLifetime"]) {
            subscriptionExplanation = thankYou;
        } else {
            subscriptionExplanation = [NSString stringWithFormat:@"%@ %@", thankYou, willContinue];
        }
        
        FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"Purchase Successful", @"Subscription", @""),
                                   subscriptionExplanation);
        if (isTeacher && !subscriptionCodeSetup) {
            SubscriptionCodeSetupControllerViewController *vc = [[SubscriptionCodeSetupControllerViewController alloc] initWithNibName:@"SubscriptionCodeSetupControllerViewController" bundle:nil];
            if ([FlashCardsCore getSettingBool:@"fcppIsLoggedIn"]) {
                vc.isCreatingNewAccount = NO;
            } else {
                vc.isCreatingNewAccount = YES;
            }
            [[[FlashCardsCore appDelegate] navigationController] pushViewController:vc animated:YES];
        } else if ([FlashCardsCore getSettingBool:@"fcppIsLoggedIn"]) {
            // if the user is logged in, then exit the whole subscription screen:
            [self exitSubscriptionScreen];
        } else {
            // if the user isn't logged in, prompt them to register or log in:
            AppLoginViewController *vc = [[AppLoginViewController alloc] initWithNibName:@"AppLoginViewController" bundle:nil];
            vc.isCreatingNewAccount = YES;
            [[[FlashCardsCore appDelegate] navigationController] pushViewController:vc animated:YES];
        }
    }];
    [request setFailedBlock:^{
        // hide the HUD:
        UIViewController *vc = [FlashCardsCore currentViewController];
        if ([vc respondsToSelector:@selector(hideHUD)]) {
            [vc performSelectorOnMainThread:@selector(hideHUD) withObject:nil waitUntilDone:NO];
        }
        NSData *data = (NSData*)[FlashCardsCore getSetting:@"fcppTransactionReceiptsToBeUploaded"];
        NSMutableArray *transactions = [NSMutableArray arrayWithArray:(NSArray*)[NSKeyedUnarchiver unarchiveObjectWithData:data]];
        [transactions addObject:receiptString];
        NSData *transactionsAsData = [NSKeyedArchiver archivedDataWithRootObject:transactions];
        [FlashCardsCore setSetting:@"fcppTransactionReceiptsToBeUploaded" value:transactionsAsData];
    }];
    [request startAsynchronous];
}
- (void)uploadAllQueuedTransactions {
    // NSLog(@"%@", [FlashCardsCore getSetting:@"fcppTransactionReceiptsToBeUploaded"]);
    NSData *data = (NSData*)[FlashCardsCore getSetting:@"fcppTransactionReceiptsToBeUploaded"];
    self.transactionQueue = [NSMutableArray arrayWithArray:(NSArray*)[NSKeyedUnarchiver unarchiveObjectWithData:data]];
    if ([self.transactionQueue count] == 0) {
        return;
    }
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/user/receipt", flashcardsServer]];
    ASIFormDataRequest *request;
    ASINetworkQueue *queue = [ASINetworkQueue queue];
    
    // keep track of how many items there are to upload
    __block int totalQueue = [self.transactionQueue count];
    __block int current = 0;
    
    // show HUD, if possible
    UIViewController *vc = [FlashCardsCore currentViewController];
    MBProgressHUD *HUD;
    if (vc) {
        if ([vc respondsToSelector:@selector(syncHUD)]) {
            HUD = [vc valueForKey:@"syncHUD"];
            if (!HUD) {
                HUD = [[MBProgressHUD alloc] initWithView:vc.view];
                
                // Add HUD to screen
                [vc.view addSubview:HUD];
                // Register for HUD callbacks so we can remove it from the window at the right time
                HUD.delegate = (UIViewController<MBProgressHUDDelegate>*)vc;
                HUD.minShowTime = 2.0;
                [HUD show:YES];
                [vc setValue:HUD forKey:@"syncHUD"];
            }
            HUD.labelText = NSLocalizedStringFromTable(@"Validating Purchase Receipts", @"Import", @"HUD");
            HUD.detailsLabelText = [NSString stringWithFormat:NSLocalizedStringFromTable(@"%d of %d Complete", @"Subscription", @""),
                                    current, totalQueue];
            [HUD show:YES];
        }
    }
    
    for (NSString *receiptString in self.transactionQueue) {
        request = [[ASIFormDataRequest alloc] initWithURL:url];
        __block ASIFormDataRequest *requestBlock = request;
        [request setupFlashCardsAuthentication:@"user/receipt"];
        if ([FlashCardsCore isLoggedIn]) {
            [request addPostValue:[FlashCardsCore getSetting:@"fcppUsername"] forKey:@"email"];
            [request addPostValue:[FlashCardsCore getSetting:@"fcppLoginKey"] forKey:@"login_key"];
        } else {
            [request addPostValue:[[UIDevice currentDevice] uniqueDeviceIdentifier] forKey:@"device_id"];
            [request addPostValue:[[UIDevice currentDevice] advertisingIdentifier] forKey:@"device_adid"];
        }
        [request addPostValue:receiptString forKey:@"transaction_receipt"];
        [request setCompletionBlock:^{
            NSLog(@"%@", requestBlock.responseString);
            NSMutableDictionary *json = [requestBlock.responseString objectFromJSONString];
            current++;
            if (HUD) {
                HUD.detailsLabelText = [NSString stringWithFormat:NSLocalizedStringFromTable(@"%d of %d Complete", @"Subscription", @""),
                                        current, totalQueue];
            }
            if (!json) {
                return;
            }
            [Flurry logEvent:@"Subscription/Verified"
              withParameters:@{
             @"FromQueue" : @YES
             }];
            [self.transactionQueue removeObject:receiptString];
        }];
        [queue addOperation:request];
    }
    [queue setDelegate:self];
    [queue setQueueDidFinishSelector:@selector(uploadAllQueuedTransactionsDidFinish)];
    [queue go];
}
- (void)uploadAllQueuedTransactionsDidFinish {
    UIViewController *vc = [FlashCardsCore currentViewController];
    if (vc) {
        if ([vc respondsToSelector:@selector(syncHUD)]) {
            MBProgressHUD *HUD = [vc valueForKey:@"syncHUD"];
            if (HUD) {
                [HUD hide:YES afterDelay:0.5];
            }
        }
    }
    
    NSData *transactionsAsData = [NSKeyedArchiver archivedDataWithRootObject:self.transactionQueue];
    [FlashCardsCore setSetting:@"fcppTransactionReceiptsToBeUploaded" value:transactionsAsData];
    [FlashCardsCore checkLogin];
}

- (void)exitSubscriptionScreen {
    NSMutableArray *vcs = [NSMutableArray arrayWithArray:[[[FlashCardsCore appDelegate] navigationController] viewControllers]];
    for (int i = [vcs count]-1; i >= 0; i--) {
        UIViewController *vc = [vcs objectAtIndex:i];
        if ([vc isKindOfClass:[StudentFinishViewController class]]) {
            [vcs removeLastObject];
        } else if ([vc isKindOfClass:[StudentViewController class]]) {
            [vcs removeLastObject];
        } else if ([vc isKindOfClass:[TeachersViewController class]]) {
            [vcs removeLastObject];
        } else if ([vc isKindOfClass:[SubscriptionCodeSetupControllerViewController class]]) {
            [vcs removeLastObject];
        } else if ([vc isKindOfClass:[AppLoginViewController class]]) {
            [vcs removeLastObject];
        } else if ([vc isKindOfClass:[SubscriptionViewController class]]) {
            [vcs removeLastObject];
        } else {
            break;
        }
    }
    [[[FlashCardsCore appDelegate] navigationController] setViewControllers:vcs animated:NO];
}
// manage the view controllers and go back to the previous screen:
- (void)exitSubscriptionScreen:(BOOL)isCreatingNewAccount hasCreatedSync:(BOOL)hasCreatedSync {
    [self exitSubscriptionScreen];
    NSMutableString *message;
    if (isCreatingNewAccount) {
        message = [NSMutableString stringWithString:NSLocalizedStringFromTable(@"Thank you for registering. You can log in on your personal devices to use your subscription.", @"Subscription", @"")];
    } else {
        message = [NSMutableString stringWithString:NSLocalizedStringFromTable(@"You have been logged in successfully.", @"Subscription", @"")];
    }
    if (![FlashCardsCore hasSubscription]) {
        NSDate *subscriptionEndDate = [FlashCardsCore getSettingDate:@"subscriptionEndDate"];
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateStyle:NSDateFormatterMediumStyle];
        NSString *endDate = [dateFormatter stringFromDate:subscriptionEndDate];
        NSString *expired = [NSString stringWithFormat:NSLocalizedStringFromTable(@"However, your FlashCards++ subscription expired on %@.", @"Subscription", @""), endDate];
        [message appendFormat:@" %@", expired];
    }
    
    RIButtonItem *ok = [RIButtonItem item];
    ok.label = NSLocalizedStringFromTable(@"OK", @"FlashCards", @"");
    ok.action = ^{
        if ([FlashCardsCore hasSubscription]) {
            [FlashCardsCore presentSyncOptions:hasCreatedSync];
        }
    };

    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@""
                                                    message:message
                                           cancelButtonItem:ok
                                           otherButtonItems: nil];
    [alert show];
}

- (void)displayError:(NSError *)error {
    if ([error.domain isEqualToString:@"SKErrorDomain"]) {
        if (error.code == SKErrorPaymentCancelled) {
            // user canceled - no error
            return;
        }
        if (error.code == SKErrorStoreProductNotAvailable) {
            // product not available
            FCDisplayBasicErrorMessage(@"", @"Error completing purchae: Product is not available in the store.");
            return;
        }
        if (error.code == SKErrorPaymentNotAllowed) {
            // user not allowed to authorize payments
            FCDisplayBasicErrorMessage(@"", @"Error completing purchae: This user is not allowed to authorize payments.");
            return;
        }
    }
    [Flurry logEvent:@"Subscription/Failed"];
    NSString *desc = desc = [error description];
    FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"Purchase Failed", @"Subscription", @""),
                               [NSString stringWithFormat:NSLocalizedStringFromTable(@"Sorry, your Subscription purchase failed. Please try again. %@", @"Subscription", @""),
                                desc]);
}
@end
