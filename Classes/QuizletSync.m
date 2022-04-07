//
//  QuizletSync.m
//  APlusFlashCards
//
//  Created by Jason Lustig on 11/9/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "FlashCardsAppDelegate.h"
#import "QuizletSync.h"
#import "QuizletRestClient.h"
#import "QuizletLoginController.h"
#import "SyncController.h"

#import "AFNetworking.h"

#import "ASIHTTPRequest.h"
#import "ASINetworkQueue.h"
#import "ASIFormDataRequest.h"

#import "JSONKit.h"
#import "NSString+URLEncoding.h"
#import "NSData+MD5.h"
#import "UIImage+ProportionalFill.h"
#import "NSArray+SplitArray.h"

#import "FCCardSet.h"
#import "FCCard.h"
#import "FCQuizletCardId.h"

#import "Reachability.h"

#import "FCRequest.h"

#import "UIAlertView+Blocks.h"
#import "QuizletLoginController.h"

// TODO:
// Support uploading images
// Support password-protected sets [can be saved in cardset.password]
// ----> DECISION: Password-protected sets cannot sync. Will need to tell user
// that syncing is not an option when they try to turn it on.

@interface ASIHTTPRequest (QuizletSyncExtension)

- (void)prepareSyncRequestQ:(QuizletSync*)sync;
- (void)authenticate;

@end

@implementation ASIHTTPRequest (QuizletSyncExtension)

- (void)prepareSyncRequestQ:(QuizletSync*)sync {
    [self setShouldContinueWhenAppEntersBackground:YES];
    [self setShouldAttemptPersistentConnection:YES];
    [self setDelegate:sync];
    [self setDidFailSelector:@selector(connectionFailed:)];
    [sync.currentHTTPRequests addObject:self];
}
- (void)authenticate {
    [self addRequestHeader:@"Authorization"
                     value:[NSString stringWithFormat:@"Bearer %@", [FlashCardsCore getSetting:@"quizletAPI2AccessToken"]]];
}

@end

@implementation QuizletSync

@synthesize userGroups;
@synthesize cardSets, cards;
@synthesize delegate;
@synthesize isSyncing;
@synthesize isSaving;
@synthesize isSyncingAllData, isSyncingUpAllSets, isCanceled;
@synthesize isDoneSyncingDownQuizletPlusStatus;
@synthesize isDoneSyncingDownGroups;
@synthesize isDoneSyncingDownUserData, isDoneSyncingDownSubscribedSets, isDoneSyncingDownImages;
@synthesize hasStartedSyncingDownUserSets, hasStartedSyncingDownImages;
@synthesize isDoneSyncingUpAllSets, isDoneSyncingUpImages;
@synthesize internetReach;
@synthesize dateStringFormatter;
@synthesize currentHTTPRequests;
@synthesize didSync;

@synthesize username, password;
@synthesize encryptedUsername, encryptedPassword;

+ (id) alloc {
    return [super alloc];
}
- (id) init {
    if ((self = [super init])) {
        [self resetStateValues];
        
        websiteName = @"quizlet";
        
        internetReach = [Reachability reachabilityForInternetConnection];
        [internetReach startNotifier];
        
        cards = [[NSMutableDictionary alloc] initWithCapacity:0];
        cardSets = [[NSMutableDictionary alloc] initWithCapacity:0];
        userGroups = [[NSMutableArray alloc] initWithCapacity:0];
                
        currentHTTPRequests = [[NSMutableSet alloc] initWithCapacity:0];
        
        dateStringFormatter = [[NSDateFormatter alloc] init];
        dateStringFormatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
        
        isSyncing = NO;
        isSaving = NO;
        requests = [[NSMutableSet alloc] initWithCapacity:0];
        didSync = NO;
    }
    return self;
}

- (void)dealloc {
    for (FCRequest* request in requests) {
        [request cancel];
    }
}

# pragma mark -
# pragma mark Helper Functions

- (void)encryptCredentials {
    
    if ([(NSNumber*)[FlashCardsCore getSetting:@"quizletIsLoggedIn"] boolValue]) {
        [Flurry setUserID:[NSString stringWithFormat:@"Quizlet/%@", username]];
    }
    
    // as per: http://stackoverflow.com/questions/4260108/encrypt-in-objective-c-decrypt-in-ruby-using-anything/4322453#4322453
    NSData     *usernameData    = [username dataUsingEncoding: NSUTF8StringEncoding];
    NSData     *keyUsername     = [NSData dataWithBytes: [[@"api.iphoneflashcards.com/username" sha256] bytes] length: kCCKeySizeAES128];
    self.encryptedUsername      = [usernameData aesEncryptedDataWithKey: keyUsername];
    
    NSData     *passwordData    = [password dataUsingEncoding: NSUTF8StringEncoding];
    NSData     *keyPassword     = [NSData dataWithBytes: [[@"com.iphoneflashcards.api/access_token" sha256] bytes] length: kCCKeySizeAES128];
    self.encryptedPassword      = [passwordData aesEncryptedDataWithKey: keyPassword];
    
}

- (NSManagedObjectContext *)context {
    NSManagedObjectContext *theContext = [FlashCardsCore mainMOC];
    return theContext;
}

+ (NSString*) username {
    return (NSString*)[FlashCardsCore getSetting:@"quizletUsername"];
}

+ (BOOL)needsToSyncInMOC:(NSManagedObjectContext*)managedObjectContext {
    NSManagedObjectContext *context = [FlashCardsCore mainMOC];
    if (!context) {
        return NO;
    }
    
    NSFetchRequest *fetchRequest;
    fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:[NSEntityDescription entityForName:@"CardSet"
                                        inManagedObjectContext:context]];
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"(quizletSetId > 0 and (isSubscribed = YES or shouldSync = YES)) and (isDeletedObject = NO or syncStatus = %d)", syncChanged]];
    int count = [context countForFetchRequest:fetchRequest error:nil];
    if (count > 0) {
        return YES;
    }
    return NO;
}

- (BOOL)hasDataToSyncInCollection:(FCCollection *)collection {
    NSManagedObjectContext *context = [FlashCardsCore mainMOC];
    if (!context) {
        return NO;
    }

    NSFetchRequest *fetchRequest;
    fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:[NSEntityDescription entityForName:@"CardSet"
                                        inManagedObjectContext:context]];
    if (collection) {
        [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"collection = %@ and (quizletSetId > 0 and (isSubscribed = YES or shouldSync = YES)) and (isDeletedObject = NO or syncStatus = %d)", collection, syncChanged]];
    } else {
        [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"(quizletSetId > 0 and (isSubscribed = YES or shouldSync = YES)) and (isDeletedObject = NO or syncStatus = %d)", syncChanged]];
    }
    int count = [context countForFetchRequest:fetchRequest error:nil];
    if (count > 0) {
        return YES;
    }
    return NO;
}
- (BOOL)hasDataToSync {
    return [self hasDataToSyncInCollection:nil];
}

- (void) resetStateValues {
    isSyncingAllData = NO;
    isSyncingUpAllSets = NO;
    isCanceled = NO;
    
    isDoneSyncingDownQuizletPlusStatus = NO;
    isDoneSyncingDownGroups = NO;
    isDoneSyncingDownUserData = NO;
    isDoneSyncingDownSubscribedSets = NO;
    isDoneSyncingDownImages = NO;
    
    isDoneSyncingUpImages = NO;
    isDoneSyncingUpAllSets = NO;
    
    hasStartedSyncingDownUserSets = NO;
    hasStartedSyncingDownImages = NO;
    didSync = NO;
}

- (BOOL)isOnline {
    NetworkStatus netStatus = [internetReach currentReachabilityStatus];
    if (netStatus == NotReachable) {
        return NO;
    }
    return YES;
}

- (void) displayOfflineMessage:(BOOL)isUploadingData {
    NSDate *lastDisplayedOfflineMessage = [FlashCardsCore getSettingDate:@"lastDisplayedOfflineMessage"];
    if (!lastDisplayedOfflineMessage) {
        lastDisplayedOfflineMessage = [NSDate dateWithTimeIntervalSince1970:0];
    }
    int interval = [[NSDate date] timeIntervalSinceDate:lastDisplayedOfflineMessage];
    if (interval > 60 * 60 * 1.5) {
        FCDisplayBasicErrorMessage(@"",
                                   NSLocalizedStringFromTable(@"You are not currently online. Sync will complete when your internet connection is available.", @"FlashCards", @""));
        [FlashCardsCore setSetting:@"lastDisplayedOfflineMessage" value:[NSDate date]];
    }
    if (isUploadingData) {
        [FlashCardsCore setSetting:@"shouldSyncWhenComesOnline" value:[NSNumber numberWithBool:YES]];
    }
    isSyncing = NO;
    if (delegate && [delegate respondsToSelector:@selector(quizletSyncDidFinish:)]) {
        [delegate quizletSyncDidFinish:self];
    }
}

# pragma mark - Helper functions

- (void)handleErrorWithRequest:(ASIHTTPRequest*)theRequest fromFunction:(NSString*)functionName {
    FCLog(@"Error: %@", [theRequest responseString]);
    NSMutableDictionary* errorUserInfo = [[NSMutableDictionary alloc] initWithCapacity:0];
    // To get error userInfo, first try and make sense of the response as JSON, if that
    // fails then send back the string as an error message
    if ([[theRequest responseString] length] > 0) {
        @try {
            NSObject* resultJSON = [[theRequest responseData] objectFromJSONData];
            NSMutableString *errorDescription = [NSMutableString stringWithString:[resultJSON valueForKey:@"error_description"]];
            NSString *alreadyDeleted = @"This flashcard set has been deleted.";
            if ([errorDescription hasPrefix:alreadyDeleted]) {
                FCCardSet *cardSet = [theRequest.userInfo objectForKey:@"cardSet"];
                [errorDescription replaceCharactersInRange:NSMakeRange(0, [alreadyDeleted length])
                                                withString:[NSString stringWithFormat:@"The card set \"%@\" has been deleted from Quizlet.", cardSet.name]];
                [cardSet setShouldSync:@NO];
                [cardSet setIsSubscribed:@NO];
                [cardSet.managedObjectContext save:nil];
                [FlashCardsCore saveMainMOC];
            }
            FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"Quizlet Error", @"Error", @""),
                                       [NSString stringWithFormat:@"%@ (%@)", errorDescription, functionName]);
            [self.currentHTTPRequests removeObject:theRequest];
            return;
        } @catch (NSException* e) {
            [errorUserInfo setObject:[theRequest responseString] forKey:@"errorMessage"];
            [self.currentHTTPRequests removeObject:theRequest];
        }
    }
    /*
     NSError *error = [[[NSError alloc] initWithDomain:@"iphoneflashcards.com" code:[theRequest responseStatusCode] userInfo:errorUserInfo] autorelease];
     if (delegate && [delegate respondsToSelector:@selector(quizletSyncDidFinish:withError:)]) {
     [delegate quizletSyncDidFinish:self withError:error];
     }
     */
    isSyncingAllData = NO;
}

- (void)handleHTTPError:(NSError*)error {
    if (error.code == ASIRequestCancelledErrorType) {
        return; // don't show an error if we cancelled the request!
    } else if (error.code == ASIRequestTimedOutErrorType) {
        FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"Connection Error", @"Error", @""),
                                   NSLocalizedStringFromTable(@"The connection to Quizlet timed out.", @"Error", @""));
    } else {
        FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"Connection Error", @"Error", @""),
                                   [NSString stringWithFormat:NSLocalizedStringFromTable(@"Error downloading data: %@ %@", @"Error", @""),
                                    error, [error userInfo]]);
    }
}


- (void)connectionFailed:(ASIFormDataRequest *)theRequest {
    NSError *error = [[NSError alloc] initWithDomain:theRequest.error.domain code:theRequest.error.code userInfo:nil];
    if (delegate && [delegate respondsToSelector:@selector(quizletSyncDidFinish:withError:)]) {
        [delegate quizletSyncDidFinish:self withError:error];
    }
    isSyncingAllData = NO;
}

/**
 *
 * SO....... How does it all work????
 * ==================================
 * The following methods (checkIfSyncIsFinished) are the core which
 * pushes everything forward. We need to make sure that each of the different operations
 * is finished before the next one goes forward.
 *
 * Each operation is encapsulated in a method (e.g. downloadAllImages). The methods
 * batch together the operations and when the ASIHTTPRequestQueue is finished,
 * it calls a method to set a flag (e.g. isDoneSyncingDownImages) and then
 * call checkIfSyncIsFinished. Then it knows to go on to the next operation in the
 * list of things that need to happen.
 *
 * In addition, there is a flag "isCanceled." When the user taps on the HUD control,
 * it sets this flag to "YES" and then whatever operation is going on will stop shortly
 * thereafter.
 *
 **/

- (void)checkIfSyncIsFinished {
    [self checkIfSyncIsFinishedWithSelector:nil];
}
- (void)checkIfSyncIsFinishedWithSelector:(SEL)selector {
    if (isCanceled) {
        return;
    }
    
    // when it goes to sync data, here is the order of operations:
    // DOWNLOAD DATA
    // 1. Download all sets (with cards) that have been updated since the lastModified date of the sets [using download-multiple]
    //      !!!! NB: Check remoteSet.dateModified of set against localCard.dateModified.
    //      !!!! If localCard.dateModified is more recent than remoteSet.dateModified, we shouldn't update the card's information.
    // 2. Download all subscribed sets
    // 3. Download all images that need to be downloaded [save the sets]
    // UPLOAD DATA
    // 4. Upload all images that need to be uploaded
    // 5. Upload all sets (i.e. titles) that need to be updated
    // 6. Upload all cards that need to be updated
    
    BOOL isFinished = NO;
    if (selector) {
        [self performSelector:selector];
        return;
    } else if (isSyncingAllData) {
        // here is where we will continue to the next steps if we are syncing EVERYTHING.
        // DOWNLOAD DATA
        // 1. Download all sets (with cards) and pick out the ones that need to be imported.
        if (isDoneSyncingDownQuizletPlusStatus) {
            if (isDoneSyncingDownUserData) {
                // 2. Download all subscribed sets
                if (isDoneSyncingDownSubscribedSets) {
                    // 3. Download all images
                    if (isDoneSyncingDownImages) {
                        // UPLOAD DATA
                        // 4. Upload all images that need to be uploaded
                        if (isDoneSyncingUpImages) {
                            // 5. Upload all sets (i.e. titles and cards) that need to be updated:
                            if (isDoneSyncingUpAllSets) {
                                // WE ARE DONE!!
                                [FlashCardsCore setSetting:@"shouldSyncWhenComesOnline" value:[NSNumber numberWithBool:NO]];
                                isFinished = YES;
                            } else {
                                FCLog(@"Quizlet/uploadAllCardSets");
                                [self uploadAllCardSets];
                            }
                        } else {
                            FCLog(@"Quizlet/uploadImages");
                            [self uploadImages];
                        }
                    } else {
                        FCLog(@"Quizlet/downloadAllImages");
                        [self downloadAllImages];
                    }
                } else {
                    FCLog(@"Quizlet/downloadSubscribedSets");
                    [self downloadSubscribedSets];
                }
            } else {
                FCLog(@"Quizlet/downloadUserData");
                [self downloadUserData];
            }
        } else {
            FCLog(@"Quizlet/downloadQuizletPlusStatus");
            [self downloadQuizletPlusStatus];
        }
    } else if (isSyncingUpAllSets) {
        if (isDoneSyncingDownQuizletPlusStatus) {
            if (isDoneSyncingDownUserData) {
                if (isDoneSyncingUpImages) {
                    if (isDoneSyncingUpAllSets) {
                        isFinished = YES;
                        [FlashCardsCore setSetting:@"shouldSyncWhenComesOnline" value:[NSNumber numberWithBool:NO]];
                    } else {
                        FCLog(@"Quizlet/uploadAllCardSets");
                        [self uploadAllCardSets];
                    }
                } else {
                    FCLog(@"Quizlet/uploadImages");
                    [self uploadImages];
                }
            } else {
                FCLog(@"Quizlet/downloadUserData");
                [self downloadUserData];
            }
        } else {
            FCLog(@"Quizlet/downloadQuizletPlusStatus");
            [self downloadQuizletPlusStatus];
        }
    } else {
        isFinished = YES;
    }
    if (isFinished) {
        if (isSyncingAllData) {
            [FlashCardsCore setSetting:@"quizletLastSyncAllData" value:[NSDate date]];
            if ([FlashCardsCore appIsSyncing]) {
                NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/updatesyncdates", flashcardsServer]];
                ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
                __block ASIFormDataRequest *requestBlock = request;
                [request prepareCoreDataSyncRequest];
                NSDate *lastSyncDate = [FlashCardsCore getSettingDate:@"quizletLastSyncAllData"];
                [request addPostValue:[NSNumber numberWithInt:[lastSyncDate timeIntervalSince1970]]
                               forKey:@"quizlet"];
                [request setCompletionBlock:^{
                    NSLog(@"Response: %@", requestBlock.responseString);
                }];
                [request setFailedBlock:^{}];
                [request startAsynchronous];
            }
        }
        if (delegate && [delegate respondsToSelector:@selector(quizletSyncDidFinish:)]) {
            [self purgeDeletedObjects];
            [delegate quizletSyncDidFinish:self];
            isSyncingAllData = NO;
            isSyncingUpAllSets = NO;
        }
    }
}

// since cards can be part of multiple card sets, when we are updating cards
// we will need to make sure that we get the proper card ID# for the proper set.
- (int)cardIdForCard:(FCCard *)card inCardSet:(FCCardSet *)cardSet {
    for (FCQuizletCardId *cId in card.quizletCardIds) {
        if ([[cId cardSet] isEqual:cardSet]) {
            return [[cId quizletCardId] intValue];
        }
    }
    return 0;
}

- (void)showLogin {
    UIApplicationState state = [[UIApplication sharedApplication] applicationState];
    if (state != UIApplicationStateActive) {
        return;
    }
    RIButtonItem *ok = [RIButtonItem item];
    ok.label = NSLocalizedStringFromTable(@"OK", @"FlashCards", @"");
    ok.action = ^{
    };
    
    
    RIButtonItem *login = [RIButtonItem item];
    login.label = NSLocalizedStringFromTable(@"Log In Now", @"FlashCards", @"");
    login.action = ^{
        UIViewController <QuizletLoginControllerDelegate> *vc =
        (UIViewController <QuizletLoginControllerDelegate> * ) [FlashCardsCore currentViewController];
        QuizletLoginController *loginController = [QuizletLoginController new];
        loginController.delegate = vc;
        [loginController presentFromController:vc];
    };
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@""
                                                    message:NSLocalizedStringFromTable(@"You are not currently logged in to Quizlet. Any sets you have synced with Quizlet will not sync until you log in to Quizlet on this device.", @"Error", @"")
                                           cancelButtonItem:ok
                                           otherButtonItems:login, nil];
   [alert show];
}

# pragma mark -
# pragma mark Download methods

// when it goes to sync data, here is the order of operations:
// DOWNLOAD DATA
// 1. Download all sets (with cards) that have been updated since the lastModified date of the sets [using download-multiple]
// 2. Download all images that need to be downloaded [save the sets]
// 3. Save changes for the sets that need to be downloaded.
//      !!!! NB: Check remoteSet.dateModified of set against localCard.dateModified.
//      !!!! If localCard.dateModified is more recent than remoteSet.dateModified, we shouldn't update the card's information.
// UPLOAD DATA
// 4. Upload all images that need to be uploaded
// 5. Upload all sets (i.e. titles) that need to be updated
// 6. Upload all cards that need to be updated

- (void) syncAllData {
    
    if (![QuizletSync needsToSyncInMOC:[FlashCardsCore tempMOC]]) {
        if (delegate && [delegate respondsToSelector:@selector(quizletSyncDidFinish:)]) {
            [delegate quizletSyncDidFinish:self];
        }
        return;
    }
    
    [QuizletRestClient pingApiLogWithMethod:@"syncAllData" andSearchTerm:@""];
    [self resetStateValues];
    
    isSyncing = YES;
    isSyncingAllData = YES;
    didSync = NO;
    
    SyncController *controller = [[FlashCardsCore appDelegate] syncController];
    if (controller) {
        [controller updateHUDLabel:NSLocalizedStringFromTable(@"Syncing: Quizlet", @"Sync", @"")];
    }

    [self purgeDeletedObjects];
    
    // 0. Get the user's data
    FCLog(@"Quizlet/downloadQuizletPlusStatus");
    [self downloadQuizletPlusStatus]; // and the rest will go from here.
}

- (void)syncUpData {
    if (![QuizletSync needsToSyncInMOC:[FlashCardsCore tempMOC]]) {
        return;
    }
    
    [QuizletRestClient pingApiLogWithMethod:@"syncUpData" andSearchTerm:@""];
    [self resetStateValues];
    
    isSyncing = YES;
    isSyncingAllData = NO;
    isSyncingUpAllSets = YES;
    isDoneSyncingDownUserData = YES;
    didSync = NO;
    
    SyncController *controller = [[FlashCardsCore appDelegate] syncController];
    if (controller) {
        [controller updateHUDLabel:NSLocalizedStringFromTable(@"Syncing: Quizlet", @"Sync", @"")];
    }

    [self purgeDeletedObjects];
    
    // get started by running the central loop!
    [self checkIfSyncIsFinished];
}

- (void) cancel {
    for (ASIHTTPRequest *request in [self.currentHTTPRequests allObjects]) {
        [request cancel];
    }
    [self.currentHTTPRequests removeAllObjects];
    self.isCanceled = YES;
    self.isSyncing = NO;
    self.isSaving = NO;
}

- (void)setIsCanceled:(BOOL)_isCanceled {
    if (_isCanceled) {
        isSyncing = NO;
        isSaving = NO;
    }
    isCanceled = _isCanceled;
}

# pragma mark - Download methods: Quizlet Plus status
- (void)downloadQuizletPlusStatus {
    if (![QuizletRestClient isLoggedIn]) {
        isDoneSyncingDownQuizletPlusStatus = YES;
        [self checkIfSyncIsFinished];
        return;
    }
    NSString *fullPath = [NSString stringWithFormat:
                @"https://api.quizlet.com/2.0/users/%@",
                [QuizletSync username]];
    
    ASIHTTPRequest *request = [[ASIHTTPRequest alloc] initWithURL:[NSURL URLWithString:fullPath]];
    [request authenticate];

    [request setRequestMethod:@"GET"];
    [request setDelegate:self];
    [request setDidFinishSelector:@selector(downloadQuizletPlusStatusConnectionFinished:)];
    [request startAsynchronous];
}

- (void)downloadQuizletPlusStatusConnectionFinished:(ASIHTTPRequest *)theRequest {

    NSMutableDictionary *parsedJson = [theRequest.responseString objectFromJSONString];

    if ([[parsedJson valueForKey:@"account_type"] isEqualToString:@"plus"] ||
        [[parsedJson valueForKey:@"account_type"] isEqualToString:@"teacher"]) {
        [FlashCardsCore setSetting:@"quizletPlus" value:@YES];
    } else {
        [FlashCardsCore setSetting:@"quizletPlus" value:@NO];
    }
    
    [userGroups removeAllObjects];
    for (NSDictionary *group in [parsedJson objectForKey:@"groups"]) {
        int groupId = [(NSNumber*)[group objectForKey:@"id"] intValue];
        [userGroups addObject:[NSNumber numberWithInt:groupId]];
    }

    isDoneSyncingDownQuizletPlusStatus = YES;
    [self checkIfSyncIsFinished];
}

# pragma mark - Download methods: User Data

- (void)downloadUserData {
    [self downloadUserDataAndRunSelector:nil];
}

- (void)downloadUserDataAndRunSelector:(SEL)selector {
    if (![self isOnline]) {
        [self displayOfflineMessage:NO];
        return;
    }
    if (![QuizletRestClient isLoggedIn]) {
        // there is an edge case where sync will be called when a person isn't logged in:
        // if they set up a set to subscribe.
        // so, if the user isn't logged in then we won't do this:
        isDoneSyncingDownUserData = YES;
        [self checkIfSyncIsFinishedWithSelector:selector];
        return;
    }
    
    // get all of the user's sets that need to be synced
    NSFetchRequest *fetchRequest;
    fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:[NSEntityDescription entityForName:@"CardSet"
                                        inManagedObjectContext:[FlashCardsCore mainMOC]]];
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"isDeletedObject = NO and shouldSync = YES and quizletSetId > 0"]];
    NSArray *setsToSync = [[FlashCardsCore mainMOC] executeFetchRequest:fetchRequest error:nil];
    
    // if there is nothing to sync, keep calm & carry on:
    if ([setsToSync count] == 0) {
        isDoneSyncingDownUserData = YES;
        [self checkIfSyncIsFinishedWithSelector:selector];
        return;
    }
    
    if ([setsToSync count] > 0 && ![QuizletRestClient isLoggedIn]) {
        // user isn't logged in -- let them know.
        
        [self showLogin];
        
        isDoneSyncingDownUserData = YES;
        [self checkIfSyncIsFinished];
        return;
    }

    
    // pull out the quizlet ID into the set ID:
    NSString *fullPath = [NSString stringWithFormat:
                          @"http://%@/%@/multiplecardsets/",
                          flashcardsServer,
                          flashcardsQuizletAction];
    
    ASIFormDataRequest *urlRequest = [[ASIFormDataRequest alloc] initWithURL:[NSURL URLWithString:fullPath]];
    [urlRequest setupFlashCardsAuthentication:@"multiplecardsets"];
    // if the user is logged in, then we will encrypt the data:
    if ([(NSNumber*)[FlashCardsCore getSetting:@"quizletIsLoggedIn"] boolValue]) {
        self.username = (NSString*)[FlashCardsCore getSetting:@"quizletLoginUsername"];
        self.password = (NSString*)[FlashCardsCore getSetting:@"quizletAPI2AccessToken"];
        [self encryptCredentials];
        [urlRequest addPostValue:[self.encryptedUsername base64Encoding] forKey:@"username"];
        [urlRequest addPostValue:[self.encryptedPassword base64Encoding] forKey:@"access_token"];
    }
    
    NSMutableSet *setsAdded = [NSMutableSet setWithCapacity:0];
    NSMutableDictionary *setsSubscribed = [NSMutableDictionary dictionaryWithCapacity:0];
    for (FCCardSet *set in setsToSync) {
        if (![setsSubscribed objectForKey:[NSNumber numberWithInt:[set.quizletSetId intValue]]]) {
            [setsSubscribed setObject:[NSMutableArray arrayWithCapacity:0]
                               forKey:[NSNumber numberWithInt:[set.quizletSetId intValue]]];
        }
        [(NSMutableArray*)[setsSubscribed objectForKey:[NSNumber numberWithInt:[set.quizletSetId intValue]]]
         addObject:set];
        
        // don't list a set multiple times if it has already been added to the querystring:
        if ([setsAdded containsObject:[NSNumber numberWithInt:[set.quizletSetId intValue]]]) {
            continue;
        }
        [setsAdded addObject:[NSNumber numberWithInt:[set.quizletSetId intValue]]];
        [urlRequest addPostValue:[NSNumber numberWithInt:[set.quizletSetId intValue]] forKey:@"cardSetIdList[]"];
    }
    int modified_since = 0;
    modified_since = [[FlashCardsCore getSettingDate:@"quizletLastSyncAllData"] timeIntervalSince1970];
    [urlRequest addPostValue:[NSNumber numberWithInt:modified_since] forKey:@"lastModified"];
    [urlRequest setUserInfo:[NSDictionary dictionaryWithObject:[NSValue valueWithPointer:selector] forKey:@"selector"]];
    
    FCRequest* request =  [[FCRequest alloc] initWithURLRequest:urlRequest
                                                andInformTarget:self
                                                       selector:@selector(downloadUserDataConnectionFinished:)];
    [requests addObject:request];
}

- (void)syncLocalSets:(NSArray*)setsToSync withRemoteSets:(NSArray*)cardSetsResponse finishedSelector:(SEL)finishedSelector {
    // make a list of the sets, bucketed by ID# (there may be more than one cardset set to sync with the same ID#)
    NSMutableDictionary *setsToSyncById = [[NSMutableDictionary alloc] initWithCapacity:0];
    NSNumber *setId;
    for (FCCardSet *set in setsToSync) {
        setId = [NSNumber numberWithInt:[set.quizletSetId intValue]];
        if (![setsToSyncById objectForKey:setId]) {
            [setsToSyncById setObject:[NSMutableArray arrayWithCapacity:0]
                               forKey:setId];
        }
        [(NSMutableArray*)[setsToSyncById objectForKey:setId] addObject:[set objectID]];
    }
    
    NSManagedObjectContext *tempMOC = [FlashCardsCore tempMOC];
    [tempMOC performBlock:^{
        // deal with the data:
        for (NSDictionary *sData in cardSetsResponse) {
            ImportSet *remoteSet = [[ImportSet alloc] initWithQuizletData:sData];
            
            NSNumber *setId = [NSNumber numberWithInt:remoteSet.cardSetId];
            // if we don't have any sets to sync with this ID, continue
            if (![setsToSyncById objectForKey:setId]) {
                continue;
            }
            // there may be multiple cardsets that are set to be synced to a specific Quizlet ID# - so we need to update them all.
            for (NSManagedObjectID *cardSetObjectId in [setsToSyncById objectForKey:setId]) {
                FCCardSet *localSet = (FCCardSet*)[tempMOC objectWithID:cardSetObjectId];
                [localSet syncWithRemoteData:remoteSet withSyncController:self];
            } // for: each corresponding local set
        } // for: each card set in the response
        [FlashCardsCore saveMainMOC:YES andRunSelector:finishedSelector onDelegate:self onMainThread:YES];
    }];
}

- (void)downloadUserDataConnectionFinished:(FCRequest*)request {
    FCLog(@"Response: %d", request.statusCode);
    FCLog(@"%@", request.resultString);
    if (request.error) {
        [requests removeObject:request];
        [self downloadUserDataFinished];
    } else {
        
        // get all of the user's sets that need to be synced
        NSFetchRequest *fetchRequest;
        fetchRequest = [[NSFetchRequest alloc] init];
        [fetchRequest setEntity:[NSEntityDescription entityForName:@"CardSet"
                                            inManagedObjectContext:[FlashCardsCore mainMOC]]];
        [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"isDeletedObject = NO and shouldSync = YES and quizletSetId > 0"]];
        NSArray *setsToSync = [[FlashCardsCore mainMOC] executeFetchRequest:fetchRequest error:nil];
        
        // if there is nothing to sync, keep calm & carry on:
        if ([setsToSync count] == 0) {
            isDoneSyncingDownUserData = YES;
            SEL selector = [[request.request.userInfo objectForKey:@"selector"] pointerValue];
            [self checkIfSyncIsFinishedWithSelector:selector];
            return;
        }
        
        NSArray *cardSetsResponse = [(NSDictionary*)request.resultJSON objectForKey:@"sets"];
        [self syncLocalSets:setsToSync withRemoteSets:cardSetsResponse finishedSelector:@selector(downloadUserDataFinished)];
        [requests removeObject:request];
    }
}
- (void)downloadUserDataFinished {
    isDoneSyncingDownUserData = YES;
    [self checkIfSyncIsFinished];
}

# pragma mark - Download Methods: Subscribed Sets

- (void) downloadSubscribedSets {
    if (![self isOnline]) {
        [self displayOfflineMessage:NO];
        return;
    }
    // get the list of subscribed sets.
    // download them and update them, including adding images to the list of images to download.
    NSFetchRequest *fetchRequest;
    fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:[NSEntityDescription entityForName:@"CardSet"
                                        inManagedObjectContext:[FlashCardsCore mainMOC]]];
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"isDeletedObject = NO and isSubscribed = YES and quizletSetId > 0"]];
    NSMutableArray *subscribedSets = [NSMutableArray arrayWithArray:[[FlashCardsCore mainMOC] executeFetchRequest:fetchRequest error:nil]];
    
    if ([subscribedSets count] == 0) {
        isDoneSyncingDownSubscribedSets = YES;
        [self checkIfSyncIsFinished];
        return;
    }
    
    // pull out the quizlet ID into the set ID:
    NSString *fullPath = [NSString stringWithFormat:
                          @"http://%@/%@/multiplecardsets/",
                          flashcardsServer,
                          flashcardsQuizletAction];
    
    ASIFormDataRequest *urlRequest = [[ASIFormDataRequest alloc] initWithURL:[NSURL URLWithString:fullPath]];
    [urlRequest setupFlashCardsAuthentication:@"multiplecardsets"];
    // if the user is logged in, then we will encrypt the data:
    if ([(NSNumber*)[FlashCardsCore getSetting:@"quizletIsLoggedIn"] boolValue]) {
        self.username = (NSString*)[FlashCardsCore getSetting:@"quizletLoginUsername"];
        self.password = (NSString*)[FlashCardsCore getSetting:@"quizletAPI2AccessToken"];
        [self encryptCredentials];
        [urlRequest addPostValue:[self.encryptedUsername base64Encoding] forKey:@"username"];
        [urlRequest addPostValue:[self.encryptedPassword base64Encoding] forKey:@"access_token"];
    }

    NSMutableSet *setsAdded = [NSMutableSet setWithCapacity:0];
    NSMutableDictionary *setsSubscribed = [NSMutableDictionary dictionaryWithCapacity:0];
    for (FCCardSet *set in subscribedSets) {
        if (![setsSubscribed objectForKey:[NSNumber numberWithInt:[set.quizletSetId intValue]]]) {
            [setsSubscribed setObject:[NSMutableArray arrayWithCapacity:0]
                               forKey:[NSNumber numberWithInt:[set.quizletSetId intValue]]];
        }
        [(NSMutableArray*)[setsSubscribed objectForKey:[NSNumber numberWithInt:[set.quizletSetId intValue]]]
         addObject:set];
        
        // don't list a set multiple times if it has already been added to the querystring:
        if ([setsAdded containsObject:[NSNumber numberWithInt:[set.quizletSetId intValue]]]) {
            continue;
        }
        [setsAdded addObject:[NSNumber numberWithInt:[set.quizletSetId intValue]]];
        [urlRequest addPostValue:[NSNumber numberWithInt:[set.quizletSetId intValue]] forKey:@"cardSetIdList[]"];
    }
    int modified_since = 0;
    modified_since = [[FlashCardsCore getSettingDate:@"quizletLastSyncAllData"] timeIntervalSince1970];
    [urlRequest addPostValue:[NSNumber numberWithInt:modified_since] forKey:@"lastModified"];
    [urlRequest setUserInfo:setsSubscribed];

    FCRequest* request = [[FCRequest alloc] initWithURLRequest:urlRequest
                                               andInformTarget:self
                                                      selector:@selector(downloadSubscribedSetsConnectionFinished:)];
    [requests addObject:request];

}

- (void) downloadSubscribedSetsConnectionFinished:(FCRequest *)request {
    FCLog(@"Response: %d", request.statusCode);
    FCLog(@"%@", request.resultString);
    if (request.error) {
        [requests removeObject:request];
        [self downloadSubscribedSetsFinished];
    } else {
        NSFetchRequest *fetchRequest;
        fetchRequest = [[NSFetchRequest alloc] init];
        [fetchRequest setEntity:[NSEntityDescription entityForName:@"CardSet"
                                            inManagedObjectContext:[FlashCardsCore mainMOC]]];
        [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"isDeletedObject = NO and isSubscribed = YES and quizletSetId > 0"]];
        NSMutableArray *subscribedSets = [NSMutableArray arrayWithArray:[[FlashCardsCore mainMOC] executeFetchRequest:fetchRequest error:nil]];

        NSArray *cardSetsChanged = [(NSDictionary*)request.resultJSON objectForKey:@"sets"];
        [self syncLocalSets:subscribedSets withRemoteSets:cardSetsChanged finishedSelector:@selector(downloadSubscribedSetsFinished)];
        [requests removeObject:request];
    }
}

- (void)downloadSubscribedSetsFinished {
    isDoneSyncingDownSubscribedSets = YES;
    [self checkIfSyncIsFinished];
}
# pragma mark - Download Methods: Images

- (void) downloadAllImages {
    if (isCanceled) {
        return;
    }
    hasStartedSyncingDownImages = YES;
    if (![self isOnline]) {
        [self displayOfflineMessage:NO];
        return;
    }
    
    if ([imagesToDownload count] == 0) {
        [self setDoneDownloadingImages];
        return;
    }
    
    if (delegate && [delegate respondsToSelector:@selector(updateHUDLabel:)]) {
        [delegate updateHUDLabel:NSLocalizedStringFromTable(@"Downloading Images", @"FlashCards", @"")];
    }
    
    ASINetworkQueue *requestQueue = [ASINetworkQueue queue];
    [requestQueue setDelegate:self];
    [requestQueue setRequestDidFinishSelector:@selector(downloadAllImagesConnectionFinished:)];
    [requestQueue setRequestDidFailSelector:@selector(connectionFailed:)];
    [requestQueue setQueueDidFinishSelector:@selector(setDoneDownloadingImages)];
    ASIHTTPRequest *request;
    NSString *imageUrl;
    for (NSDictionary *image in self.imagesToDownload) {
        imageUrl = [image valueForKey:@"url"];
        FCLog(@"%@", imageUrl);
        request = [[ASIHTTPRequest alloc] initWithURL:[NSURL URLWithString:imageUrl]];
        [request setUserInfo:image];
        [request prepareSyncRequestQ:self];
        [requestQueue addOperation:request];
    }
    if (requestQueue.requestsCount == 0) {
        [self performSelector:@selector(setDoneDownloadingImages)];
        return;
    }
    [requestQueue go];
}

- (void) downloadAllImagesConnectionFinished:(ASIHTTPRequest*)theRequest {
    FCLog(@"length: %d", [theRequest.responseData length]);
    FCCard *card = (FCCard*)[[FlashCardsCore mainMOC] objectWithID:[theRequest.userInfo objectForKey:@"cardObjectId"]];
    FCCardSet *cardSet = (FCCardSet*)[[FlashCardsCore mainMOC] objectWithID:[theRequest.userInfo objectForKey:@"cardSetObjectId"]];
    NSString *imageSide = [theRequest.userInfo objectForKey:@"imageSide"];
    if ([imageSide isEqualToString:@"front"]) {
        [card setFrontImageData:[NSData dataWithData:theRequest.responseData]];
    } else {
        [card setBackImageData:[NSData dataWithData:theRequest.responseData]];
    }
    // remove the image from self.imagesToDownload. When we're done it should be empty.
    NSString *imageUrl;
    for (NSDictionary *image in self.imagesToDownload) {
        imageUrl = [image valueForKey:@"url"];
        if ([[theRequest.url absoluteString] isEqualToString:imageUrl]) {
            [self.imagesToDownload removeObject:image];
            break;
        }
    }
}

- (void)setDoneDownloadingImages {
    [FlashCardsCore saveMainMOC];
    isDoneSyncingDownImages = YES;
    [self checkIfSyncIsFinished];
}

# pragma mark - Upload Methods: Card Sets

- (void) uploadAllCardSets {
    if (isCanceled) {
        return;
    }
    if (![self isOnline]) {
        [self displayOfflineMessage:YES];
        return;
    }
    // first check to find if any groups need to be uploaded.
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:[NSEntityDescription entityForName:@"CardSet"
                                        inManagedObjectContext:[FlashCardsCore mainMOC]]];
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"shouldSync = YES and syncStatus = %d and quizletSetId > 0", syncChanged]];
    NSArray *objects = [[FlashCardsCore mainMOC] executeFetchRequest:fetchRequest error:nil];
    
    if ([objects count] > 0 && ![QuizletRestClient isLoggedIn]) {
        // user isn't logged in -- let them know.
        
        [self showLogin];
        
        isDoneSyncingUpAllSets = YES;
        [self checkIfSyncIsFinished];
        return;
    }
    
    ASINetworkQueue *requestQueue = [ASINetworkQueue queue];
    [requestQueue setDelegate:self];
    [requestQueue setQueueDidFinishSelector:@selector(uploadAllCardSetsQueueDidFinish)];
    
    // then do stuff with each of them
    NSMutableString *fullPath;
    ASIFormDataRequest *request;
    for (FCCardSet *cardSet in objects) {
        if (isCanceled) {
            return;
        }
        if ([cardSet.quizletSetId intValue] == 0) {
            // there is no Quizlet ID# set - don't change this one.
            continue;
        }
        
        didSync = YES;
        
        // set up the HTTP request:
        fullPath = [NSString stringWithFormat:
                    @"https://api.quizlet.com/2.0/sets/%d",
                    [cardSet.quizletSetId intValue]];
        
        request = [[ASIFormDataRequest alloc] initWithURL:[NSURL URLWithString:fullPath]];
        [request authenticate];
        
        // there are three options for what to do with the group.
        // 1. It is a *deleted* group (isDeletedObject = 1) and needs to be deleted.
        if ([cardSet.isDeletedObject boolValue]) {
            continue;
            [request setRequestMethod:@"DELETE"];
        } else {
            // 2. It is an *existing* set (i.e., no Quizlet ID#) and needs to be uploaded.
            // if we have changed the properties then we won't even try to upload the individual cards -- since
            // we will need to upload the cards directly with everything else.
            [request setRequestMethod:@"PUT"];
            [request addPostValue:cardSet.name forKey:@"title"];
            NSMutableArray *cardsInOrder = [cardSet allCardsInOrder];
            int count = 0;
            for (FCCard *_card in cardsInOrder) {
                // cardId returns 0 if it does not exist -- as required by Quizlet API.
                int cardId = [_card cardIdForWebsite:@"quizlet" forCardSet:cardSet];
                [request addPostValue:[NSNumber numberWithInt:cardId]
                               forKey:[NSString stringWithFormat:@"term_ids[%d]", count]];
                if ([cardSet.didReverseFrontAndBack boolValue]) {
                    [request addPostValue:_card.frontValue
                                   forKey:[NSString stringWithFormat:@"definitions[%d]", count]];
                    [request addPostValue:_card.backValue
                                   forKey:[NSString stringWithFormat:@"terms[%d]", count]];
                    if ([QuizletRestClient isQuizletPlus]) {
                        [request addPostValue:_card.frontImageId
                                       forKey:[NSString stringWithFormat:@"images[%d]", count]];
                    } else {
                        // [request addPostValue:@""
                        //               forKey:[NSString stringWithFormat:@"images[%d]", count]];
                    }
                } else {
                    [request addPostValue:_card.frontValue
                                   forKey:[NSString stringWithFormat:@"terms[%d]", count]];
                    [request addPostValue:_card.backValue
                                   forKey:[NSString stringWithFormat:@"definitions[%d]", count]];
                    if ([QuizletRestClient isQuizletPlus]) {
                        [request addPostValue:_card.backImageId
                                       forKey:[NSString stringWithFormat:@"images[%d]", count]];
                    } else {
                        // [request addPostValue:@""
                        //               forKey:[NSString stringWithFormat:@"images[%d]", count]];
                    }
                }
                count++;
            }
        }
        // TODO: 3. It is a NEW set (i.e., no Quizlet ID#) and needs to be uploaded.
        
        [request setUserInfo:[NSMutableDictionary dictionaryWithObjectsAndKeys:
                              cardSet, @"cardSet",
                              nil]];
        [request setDidFinishSelector:@selector(uploadAllCardSetsConnectionDidFinish:)];
        [request prepareSyncRequestQ:self];
        [requestQueue addOperation:request];
    }
    if (requestQueue.requestsCount == 0) {
        [self uploadAllCardSetsQueueDidFinish];
        return;
    }
    [requestQueue go];
}

- (void) uploadAllCardSetsConnectionDidFinish:(ASIHTTPRequest*)theRequest {
    FCLog(@"uploadAllCardSetsConnectionDidFinish");
    FCLog(@"Response: %d", [theRequest responseStatusCode]);
    // FCLog(@"%@", [theRequest responseString]);
    bool isError = NO;
    FCCardSet *cardSet = (FCCardSet*)[theRequest.userInfo objectForKey:@"cardSet"];
    if ((int)floor(((double)[theRequest responseStatusCode])/100) != 2) {
        NSObject* resultJSON = [[theRequest responseData] objectFromJSONData];
        NSString *errorDescription = [resultJSON valueForKey:@"error_description"];
        NSString *alreadyDeleted = @"This flashcard set has been deleted.";
        if (!([errorDescription hasPrefix:alreadyDeleted] && [cardSet.isDeletedObject boolValue])) {
            [self handleErrorWithRequest:theRequest fromFunction:@"uploadAllCardSetsConnectionDidFinish"];
            isError = YES;
        }
    }
    
    if (!isError) {
        [self.currentHTTPRequests removeObject:theRequest];
        // TODO: Allow upload of new sets via sync api
        [cardSet setSyncStatus:[NSNumber numberWithInt:syncNoChange]];

        [FlashCardsCore saveMainMOC];
    }
}

- (void)uploadAllCardSetsQueueDidFinish {
    isDoneSyncingUpAllSets = YES;
    [self checkIfSyncIsFinished];
}

# pragma mark - Upload Methods: Images

- (void) uploadImages {
    if (isCanceled) {
        return;
    }
    if (![self isOnline]) {
        [self displayOfflineMessage:YES];
        return;
    }
    
    if (![QuizletRestClient isQuizletPlus]) {
        [self uploadAllImagesQueueDidFinish];
        return;
    }
    
    // first check to find if any cards need to be uploaded
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:[NSEntityDescription entityForName:@"Card"
                                        inManagedObjectContext:[FlashCardsCore mainMOC]]];
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"shouldSync = YES and syncStatus = %d and isDeletedObject = NO", syncChanged]];
    NSArray *objects = [[FlashCardsCore mainMOC] executeFetchRequest:fetchRequest error:nil];
    
    NSMutableArray *cardsWithImagesToUpload = [[NSMutableArray alloc] initWithCapacity:0];
    
    // go through each card, and if it needs to upload an image - then we will upload that image.
    for (FCCard *card in objects) {
        if ([card.backImageData length] > 0) {
            if ([card.backImageId length] == 0) {
                // only upload image if the image ID is empty.
                [cardsWithImagesToUpload addObject:card];
            }
        }
        if ([card.frontImageData length] > 0) {
            if ([card.frontImageId length] == 0) {
                // only upload image if the image ID is empty.
                [cardsWithImagesToUpload addObject:card];
            }
        }
    }
    
    if ([cardsWithImagesToUpload count] == 0) {
        [self uploadAllImagesQueueDidFinish];
        return;
    }
    
    [self uploadImagesFromCards:cardsWithImagesToUpload completionSelector:@selector(uploadAllImagesQueueDidFinish)];
}

- (void)uploadAllImagesQueueDidFinish {
    isDoneSyncingUpImages = YES;
    [self checkIfSyncIsFinished];
}

- (void) getImageIds {
    @autoreleasepool {
        if (![FlashCardsCore isConnectedToWifi]) {
            return;
        }
        if (![QuizletRestClient isLoggedIn]) {
            return;
        }
        
        NSManagedObjectContext *threadMOC = [[NSManagedObjectContext alloc] init];
        [threadMOC setPersistentStoreCoordinator:[[FlashCardsCore mainMOC] persistentStoreCoordinator]];
        
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        // Edit the entity name as appropriate.
        [fetchRequest setEntity:[NSEntityDescription entityForName:@"Card"
                                            inManagedObjectContext:threadMOC]];
        [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"isDeletedObject = NO and shouldSync = YES and ((backImageData.length > 0 and backImageId = %@) or (frontImageData.length > 0 and frontImageId = %@))", @"", @""]];
        NSArray *cardsWithImages = [threadMOC executeFetchRequest:fetchRequest error:nil];
        [self uploadImagesFromCards:cardsWithImages completionSelector:nil];
    }
}

- (void)uploadImagesFromCards:(NSArray*)cardsWithImages completionSelector:(SEL)completionSelector {
    NSMutableArray *imagesToUpload = [NSMutableArray arrayWithCapacity:0];
    for (FCCard *card in cardsWithImages) {
        if ([card.frontImageData length] > 0 && [card.frontImageId length] == 0) {
            [imagesToUpload addObject:@{@"cardId" : [card objectID],
             @"side" : @"front",
             @"imageData" : [NSData dataWithData:card.frontImageData]}];
        }
        if ([card.backImageData length] > 0 && [card.backImageId length] == 0) {
            [imagesToUpload addObject:@{@"cardId" : [card objectID],
             @"side" : @"back",
             @"imageData" : [NSData dataWithData:card.backImageData]}];
        }
    }
    
    AFHTTPClient *client= [AFHTTPClient clientWithBaseURL:[NSURL URLWithString:@"https://api.quizlet.com"]];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    while ([imagesToUpload count] > 0) {
        NSMutableArray *imagesUploadedThisBatch = [NSMutableArray arrayWithCapacity:0];
        NSMutableURLRequest *myRequest = [client multipartFormRequestWithMethod:@"POST"
                                                                           path:@"/2.0/images"
                                                                     parameters:nil
                                                      constructingBodyWithBlock: ^(id <AFMultipartFormData>formData) {
                                                          int postSize = 0;
                                                          int totalImagesUploaded = 0;
                                                          NSData *imageData;
                                                          for (int i = [imagesToUpload count]-1; i >= 0; i--) {
                                                              NSDictionary *image = [imagesToUpload objectAtIndex:i];
                                                              imageData = (NSData*)[image objectForKey:@"imageData"];
                                                              
                                                              UIImage *imageContainer = [UIImage imageWithData:imageData];
                                                              if (imageContainer.size.width > 1000 || imageContainer.size.height > 1000) {
                                                                  imageContainer = [imageContainer imageToFitSize:CGSizeMake(1000, 1000) method:MGImageResizeScale];
                                                                  imageData = UIImageJPEGRepresentation(imageContainer, 0.8);
                                                              }
                                                              
                                                              postSize += [imageData length];
                                                              totalImagesUploaded++;
                                                              // the FCE documentation says that there is 20MB max for each request.
                                                              // we will cap it at 19MB.
                                                              if (postSize > 19000000 || totalImagesUploaded > 15) {
                                                                  break;
                                                              }
                                                              // we are under the cap - add the image.
                                                              [formData appendPartWithFileData:imageData name:@"imageData[]" fileName:@"image.jpg" mimeType:@"image/jpeg"];
                                                              [imagesUploadedThisBatch addObject:image];
                                                              [imagesToUpload removeLastObject];
                                                          }
                                                      }];
        [myRequest setValue:[NSString stringWithFormat:@"Bearer %@", [FlashCardsCore getSetting:@"quizletAPI2AccessToken"]]
         forHTTPHeaderField:@"Authorization"];
        AFJSONRequestOperation *operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:myRequest
                                                                                            success:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
                                                                                                FCLog(@"RESPONSE: %@", JSON);
                                                                                                if (![JSON isKindOfClass:[NSArray class]]) {
                                                                                                    if ([JSON objectForKey:@"error"]) {
                                                                                                        return;
                                                                                                    }
                                                                                                }
                                                                                                int i = 0;
                                                                                                for (NSDictionary *image in imagesUploadedThisBatch) {
                                                                                                    NSManagedObjectID *cardId = (NSManagedObjectID*)[image objectForKey:@"cardId"];
                                                                                                    if (i >= [JSON count]) {
                                                                                                        continue;
                                                                                                    }
                                                                                                    NSDictionary *info = [JSON objectAtIndex:i];
                                                                                                    [self updateImageIdForCard:cardId
                                                                                                                          side:[image objectForKey:@"side"]
                                                                                                                          JSON:info
                                                                                                                  onMainThread:(completionSelector ? YES : NO)];
                                                                                                    i++;
                                                                                                }
                                                                                                if (queue.operationCount == 0 && completionSelector) {
                                                                                                    [self performSelector:completionSelector];
                                                                                                }
                                                                                            }
                                                                                            failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON) {
                                                                                                NSLog(@"FAILED");
                                                                                                
                                                                                            }];
        [queue addOperation:operation];
    }
}

- (void)updateImageIdForCard:(NSManagedObjectID*)cardId side:(NSString*)side JSON:(id)JSON onMainThread:(BOOL)onMainThread {
    NSManagedObjectContext *threadMOC = [FlashCardsCore mainMOC];

    FCCard *tCard = (FCCard*)[threadMOC objectWithID:cardId];
    if ([side isEqualToString:@"front"]) {
        FCLog(@"Old: %@", tCard.frontImageURL);
        [tCard setFrontImageId:[JSON valueForKey:@"id"]];
        if ([tCard.frontImageURL length] == 0) {
            // set the image URL
            FCLog(@"Set front image URL: %@", [JSON valueForKey:@"url"]);
            [tCard setFrontImageURL:[JSON valueForKey:@"url"]];
        }
    } else {
        FCLog(@"Old: %@", tCard.backImageURL);
        [tCard setBackImageId:[JSON valueForKey:@"id"]];
        if ([tCard.backImageURL length] == 0) {
            // set the image URL
            FCLog(@"Set back image URL: %@", [JSON valueForKey:@"url"]);
            [tCard setBackImageURL:[JSON valueForKey:@"url"]];
        }
    }
    FCLog(@"New: %@", [JSON objectForKey:@"url"]);
    FCLog(@"----");
    [threadMOC save:nil];
    
}

# pragma mark -
# pragma mark Purge Deleted Objects

- (void)purgeDeletedObjects {
    NSManagedObjectContext *tempMOC = [FlashCardsCore tempMOC];
    [tempMOC performBlock:^{
        // purge deleted cards:
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        [fetchRequest setEntity:[NSEntityDescription entityForName:@"Card"
                                            inManagedObjectContext:tempMOC]];
        [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"isDeletedObject = YES and syncStatus = %d", syncNoChange]];
        NSArray *cardsList = [tempMOC executeFetchRequest:fetchRequest error:nil];
        
        for (FCCard *card in cardsList) {
            FCLog(@"Purging card: %@", card.frontValue);
            [card removeFromMOC];
        }
        
        // purge deleted sets:
        [fetchRequest setEntity:[NSEntityDescription entityForName:@"CardSet"
                                            inManagedObjectContext:tempMOC]];
        NSArray *cardsSetsList = [tempMOC executeFetchRequest:fetchRequest error:nil];
        
        for (FCCardSet *cardSet in cardsSetsList) {
            FCLog(@"Purging set: %@", cardSet.name);
            [cardSet removeFromMOC];
        }
        
        [tempMOC save:nil];
        [FlashCardsCore saveMainMOC];
    }];
}


@end
