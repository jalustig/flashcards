//
//  InAppPurchaseManager.h
//  FlashCards
//
//  Created by Jason Lustig on 11/15/12.
//  Copyright (c) 2012 Jason Lustig. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

#define kInAppPurchaseManagerProductsFetchedNotification @"kInAppPurchaseManagerProductsFetchedNotification"

// add a couple notifications sent out when the transaction completes
#define kInAppPurchaseManagerTransactionFailedNotification @"kInAppPurchaseManagerTransactionFailedNotification"
#define kInAppPurchaseManagerTransactionSucceededNotification @"kInAppPurchaseManagerTransactionSucceededNotification"

@interface InAppPurchaseManager : NSObject <SKProductsRequestDelegate, SKPaymentTransactionObserver>
{
    NSMutableArray *proUpgradeProducts;
    SKProductsRequest *productsRequest;
    NSMutableArray *transactionQueue;
}

// public methods
- (void)uploadAllQueuedTransactions;

// UIViewController methods
- (void)exitSubscriptionScreen;
- (void)exitSubscriptionScreen:(BOOL)isCreatingNewAccount hasCreatedSync:(BOOL)hasCreatedSync;

- (void)verifyTransaction:(SKPaymentTransaction *)transaction;
- (void)displayError:(NSError*)error;

@property (nonatomic, strong) NSMutableArray *proUpgradeProducts;
@property (nonatomic, strong) SKProductsRequest *productsRequest;
@property (nonatomic, strong) NSMutableArray *transactionQueue;

@end
