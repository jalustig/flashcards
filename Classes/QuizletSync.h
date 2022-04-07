//
//  QuizletSync.h
//  APlusFlashCards
//
//  Created by Jason Lustig on 11/9/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "FCSync.h"

#import "ASIFormDataRequest.h"
#import "ASIHTTPRequest.h"
#import "ASINetworkQueue.h"

@protocol QuizletSyncDelegate;
@class FCCardSet;
@class FCCard;
@class Reachability;

@interface QuizletSync : FCSync {
    
    id<QuizletSyncDelegate> __weak delegate;
    
    NSDateFormatter *dateStringFormatter;
    
    NSMutableArray *userGroups;
    NSMutableDictionary *cards;
    NSMutableDictionary *cardSets;
        
    NSMutableSet *currentHTTPRequests;
    
    BOOL isSyncing;
    BOOL isSaving;
    
    BOOL isSyncingAllData;
    BOOL isSyncingUpAllSets;
    BOOL isCanceled;
    
    BOOL isDoneSyncingDownQuizletPlusStatus;
    BOOL isDoneSyncingDownGroups;
    BOOL isDoneSyncingDownUserData;
    BOOL isDoneSyncingDownSubscribedSets;
    BOOL isDoneSyncingDownImages;
    
    BOOL isDoneSyncingUpImages;
    BOOL isDoneSyncingUpAllSets;
    
    BOOL hasStartedSyncingDownUserSets;
    BOOL hasStartedSyncingDownImages;
    
    Reachability *internetReach;
    
    NSString *username;
    NSString *password;
    NSData *encryptedUsername;
    NSData *encryptedPassword;
    NSMutableSet* requests;
    
    BOOL didSync;
}

// helper functions

- (NSManagedObjectContext *)context;
+ (NSString *)username;
- (void) resetStateValues;

- (BOOL)isOnline;
- (void)displayOfflineMessage:(BOOL)isUploadingData;

+ (BOOL)needsToSyncInMOC:(NSManagedObjectContext*)managedObjectContext;
- (BOOL)hasDataToSyncInCollection:(FCCollection*)collection;
- (BOOL)hasDataToSync;

// helper functions
- (void)handleErrorWithRequest:(ASIHTTPRequest*)theRequest fromFunction:(NSString*)functionName;
- (void)handleHTTPError:(NSError*)error;

- (void)connectionFailed:(ASIFormDataRequest *)theRequest;
- (void) checkIfSyncIsFinished;
- (void)checkIfSyncIsFinishedWithSelector:(SEL)selector;

// Download methods
- (void) syncAllData;
- (void) syncUpData;
- (void) cancel;

// download methods: Quizlet Plus status
- (void)downloadQuizletPlusStatus;
- (void)downloadQuizletPlusStatusConnectionFinished:(ASIHTTPRequest *)theRequest;

// download methods: User Data
- (void) downloadUserData;
- (void) downloadUserDataAndRunSelector:(SEL)selector;
- (void) downloadUserDataConnectionFinished:(ASIHTTPRequest *)theRequest;

// download methods: Subscribed Sets
- (void) downloadSubscribedSets;
- (void) downloadSubscribedSetsConnectionFinished:(ASIFormDataRequest *)theRequest;

// download methods: images
- (void) downloadAllImages;
- (void) downloadAllImagesConnectionFinished:(ASIHTTPRequest*)theRequest;
- (void) setDoneDownloadingImages;

// upload methods: cards
- (void) uploadAllCards;
- (void) deleteCardConnectionDidFinish:(ASIHTTPRequest*)theRequest;
- (void) uploadAllCardsQueueDidFinish;

// puload methods: card sets
- (void) uploadAllCardSets;
- (void) uploadAllCardSetsConnectionDidFinish:(ASIHTTPRequest*)theRequest;
- (void) uploadAllCardSetsQueueDidFinish;

- (void) uploadImages;
- (void) uploadAllImagesQueueDidFinish;

- (void) getImageIds;

- (void)purgeDeletedObjects;

- (void)encryptCredentials;

@property (nonatomic, strong) NSString *username;
@property (nonatomic, strong) NSString *password;
@property (nonatomic, strong) NSData *encryptedUsername;
@property (nonatomic, strong) NSData *encryptedPassword;


@property (nonatomic, strong) NSMutableArray *userGroups;
@property (nonatomic, strong) NSMutableDictionary *cards;
@property (nonatomic, strong) NSMutableDictionary *cardSets;

@property (nonatomic, strong) NSMutableSet *currentHTTPRequests;

@property (nonatomic, weak) id<QuizletSyncDelegate> delegate;
@property (nonatomic, strong) NSDateFormatter *dateStringFormatter;

@property (nonatomic, assign) BOOL isSyncing;
@property (nonatomic, assign) BOOL isSaving;

@property (nonatomic, assign) BOOL isSyncingAllData;
@property (nonatomic, assign) BOOL isSyncingUpAllSets;
@property (nonatomic, assign) BOOL isCanceled;

@property (nonatomic, assign) BOOL isDoneSyncingDownQuizletPlusStatus;
@property (nonatomic, assign) BOOL isDoneSyncingDownGroups;
@property (nonatomic, assign) BOOL isDoneSyncingDownUserData;
@property (nonatomic, assign) BOOL isDoneSyncingDownSubscribedSets;
@property (nonatomic, assign) BOOL isDoneSyncingDownImages;

@property (nonatomic, assign) BOOL hasStartedSyncingDownUserSets;
@property (nonatomic, assign) BOOL hasStartedSyncingDownImages;

@property (nonatomic, assign) BOOL isDoneSyncingUpImages;
@property (nonatomic, assign) BOOL isDoneSyncingUpAllSets;

@property (nonatomic, strong) Reachability *internetReach;

@property (nonatomic, assign) BOOL didSync;

@end


/* The delegate provides allows the user to get the result of the calls made on the DBRestClient.
 Right now, the error parameter of failed calls may be nil and [error localizedDescription] does
 not contain an error message appropriate to show to the user. */
@protocol QuizletSyncDelegate <NSObject>

@optional

- (void)quizletSyncDidFinish:(QuizletSync*)client;
- (void)quizletSyncDidFinish:(QuizletSync*)client withError:(NSError*)error;
- (void)updateHUDLabel:(NSString*)labelText;

@end

