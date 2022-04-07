//
//  SyncController.m
//  FlashCards
//
//  Created by Jason Lustig on 1/17/13.
//  Copyright (c) 2013 Jason Lustig. All rights reserved.
//

#import "SyncController.h"

#import "FlashCardsCore.h"
#import "FlashCardsAppDelegate.h"

#import "UIDevice+IdentifierAddition.h"
#import "UIAlertView+Blocks.h"
#import "MBProgressHUD.h"

#import "QuizletSync.h"

#import "FCSyncViewController.h"

#import "JSONKit.h"

#import "DTVersion.h"

@implementation SyncController

@synthesize taskIdentifier;

@synthesize quizletSync;
@synthesize documentSyncManager;

@synthesize isDoneFcppSyncFirstRun;
@synthesize isDoneFcppSyncFinalRun;
@synthesize isDoneQuizletSync;

@synthesize downloadStoreAfterRegistering;
@synthesize uploadStoreAfterRegistering;
@synthesize isFirstDownload;

@synthesize isCurrentlyRegisteringSyncManagers;
@synthesize documentSyncManagerHasRegistered;

@synthesize quizletDidChange;

@synthesize userInitiatedSync;

@synthesize delegate;

@synthesize isCurrentlySyncing;

@synthesize isCurrentlyUploadingForFirstTime;
@synthesize isCurrentlyDownloading;
@synthesize isCurrentlyUploading;

@synthesize syncWillUploadChanges;
@synthesize syncDidUploadChanges;
@synthesize syncIsRunningFromBackground;
@synthesize completionHandler;

+ (id) alloc {
    return [super alloc];
}
- (id) init {
    if ((self = [super init])) {
        [self resetStateValues];

        syncWillUploadChanges = NO;
        syncDidUploadChanges = NO;
        syncIsRunningFromBackground = NO;
        
        isFirstDownload = NO;
        isCurrentlySyncing = NO;
        
        isCurrentlyUploadingForFirstTime = NO;
        isCurrentlyUploading = NO;
        isCurrentlyDownloading = NO;
        
        quizletDidChange = NO;
        
        userInitiatedSync = NO;
        
        downloadStoreAfterRegistering = NO;
        uploadStoreAfterRegistering = NO;
        documentSyncManagerHasRegistered = NO;
        
        self.quizletSync = [[QuizletSync alloc] init];
        self.quizletSync.delegate = self;
        // self.quizletSync.managedObjectContext = [[FlashCardsCore appDelegate] managedObjectContext];
    }
    return self;
}

# pragma mark - Public Methods

- (void)clearAllLocalAndRemoteData {
    if (![FlashCardsCore isConnectedToInternet]) {
        FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"No Internet Connection", @"Error", @"UIAlert title"),
                                   [NSString stringWithFormat:@"%@ %@",
                                    NSLocalizedStringFromTable(@"You are not connected to the internet.", @"Error", @""),
                                    NSLocalizedStringFromTable(@"This feature will only work with an active internet connection.", @"Error", @"message")]);
        return;
    }

    UIViewController *vc = [FlashCardsCore currentViewController];
    MBProgressHUD *syncHUD = [FlashCardsCore currentHUD:@"syncHUD"];
    if (!syncHUD && [vc respondsToSelector:@selector(createSyncHUD)]) {
        [vc performSelectorOnMainThread:@selector(createSyncHUD) withObject:nil waitUntilDone:YES];
        syncHUD = [FlashCardsCore currentHUD:@"syncHUD"];
    }
    
    if (self.documentSyncManager) {
        [self.documentSyncManager removeHelperFileDirectory:nil];
        [self.documentSyncManager deregisterDocumentSyncManager];
    }
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/clear", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    [request prepareCoreDataSyncRequest];
    [request setShouldContinueWhenAppEntersBackground:YES];
    [request setShouldAttemptPersistentConnection:YES];
    [request setDelegate:nil];
    [request setCompletionBlock:^{
        if (syncHUD) {
            [syncHUD hide:YES];
        }
        [FlashCardsCore setSetting:@"appIsSyncing" value:@NO];
        [FlashCardsCore setSetting:@"hasExecutedFirstSync" value:@NO];
        [self setupBackgroundSyncing];
        FCDisplayBasicErrorMessage(@"",
                                   NSLocalizedStringFromTable(@"Automatic Sync has been disabled for all devices, and sync data has been removed from the FlashCards++ web server.", @"Sync", @""));
        if ([vc respondsToSelector:@selector(checkDisplayButtons)]) {
            [vc performSelector:@selector(checkDisplayButtons)];
        }
    }];
    [request setFailedBlock:^{
        if (syncHUD) {
            [syncHUD hide:YES];
        }
        [FlashCardsCore setSetting:@"appIsSyncing" value:@NO];
        [FlashCardsCore setSetting:@"hasExecutedFirstSync" value:@NO];
        [self setupBackgroundSyncing];
        FCDisplayBasicErrorMessage(@"",
                                   NSLocalizedStringFromTable(@"Automatic Sync has been disabled on this device, but the connection to the web server failed.", @"Sync", @""));
        if ([vc respondsToSelector:@selector(checkDisplayButtons)]) {
            [vc performSelector:@selector(checkDisplayButtons)];
        }
    }];
    [request startAsynchronous];
}

- (void)sync {
    if (isCurrentlySyncing || isCurrentlyUploading || isCurrentlyDownloading) {
        return;
    }
    [self resetStateValues];
    if (![FlashCardsCore isConnectedToInternet]) {
        [self setDelegate:nil];
        return;
    }
    // with no subscription, prompt them to get a subscription
    if ([FlashCardsCore appIsSyncingNoSubscription] && ![FlashCardsCore hasSubscription]) {
        [FlashCardsCore showSubscriptionEndedPopup:YES];
        [self hideSyncHUD];
        return;
    }
    self.taskIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:self.taskIdentifier];
        self.taskIdentifier = UIBackgroundTaskInvalid;
    }];
    isCurrentlySyncing = YES;
    [self checkIfSyncIsFinished];
}

- (void)cancel {
    if (self.documentSyncManager) {
        [self.documentSyncManager cancelSynchronization];
        [self.documentSyncManager setIsCurrentlySyncing:NO];
        [self.documentSyncManager setState:TICDSDocumentSyncManagerStateAbleToSync];
    }
    [self.quizletSync cancel];
    isCurrentlySyncing = NO;
    syncDidUploadChanges = NO;
    syncIsRunningFromBackground = NO;
    [FlashCardsCore setSetting:@"uploadIsCanceled" value:@YES];
    MBProgressHUD *HUD = [FlashCardsCore currentHUD:@"syncHUD"];
    if (HUD) {
        [HUD hide:YES];
    }
    UIViewController *vc = [FlashCardsCore currentViewController];
    if ([vc respondsToSelector:@selector(setShouldSyncN:)]) {
        [vc performSelector:@selector(setShouldSyncN:) withObject:@NO];
    }
}

- (void)getImageIds {
    [quizletSync performSelectorInBackground:@selector(getImageIds) withObject:nil];
}

- (BOOL)canPotentiallySync {
    if ([self.quizletSync hasDataToSync] ||
        [FlashCardsCore appIsSyncing]) {
        return YES;
    }
    return NO;
}

- (void)setDocumentSyncManager:(TICDSDocumentSyncManager *)_documentSyncManager {
    documentSyncManager = _documentSyncManager;
    
    if (documentSyncManager) {
        [[FlashCardsCore mainMOC] setDocumentSyncManager:self.documentSyncManager];
        [self.documentSyncManager addManagedObjectContext:[FlashCardsCore mainMOC]];
        [[FlashCardsCore mainMOC] setSynchronized:YES];
    }
}

+ (BOOL)hudCanCancel:(MBProgressHUD *)hud {
    NSArray *doNotCancel =
    @[NSLocalizedStringFromTable(@"Preparing to Sync", @"Sync", @"HUD"),
    NSLocalizedStringFromTable(@"Updating Database", @"FlashCards", @"HUD"),
    NSLocalizedStringFromTable(@"Downloading Database", @"Sync", @""),
    NSLocalizedStringFromTable(@"Uploading Database", @"Sync", @""),
    NSLocalizedStringFromTable(@"Optimizing Database", @"Settings", @"HUD"),
    NSLocalizedStringFromTable(@"Replacing Sync Data", @"Sync", @"HUD")
    ];
    NSString *savingDataString = NSLocalizedStringFromTable(@"Saving Changes: %1.2f%%", @"Sync", @"");
    NSString *savingDataPrefix = [savingDataString substringToIndex:15];
    NSString *downloadedString = NSLocalizedStringFromTable(@"Downloaded: %1.2f%%", @"Backup", @"");
    NSString *downloadedPrefix = [downloadedString substringToIndex:11];
    for (NSString *string in [NSSet setWithArray:doNotCancel]) {
        if ([hud.labelText isEqualToString:string]) {
            return NO;
        }
        if (hud.detailsLabelText && [hud.detailsLabelText hasPrefix:savingDataPrefix]) {
            return NO;
        }
        if (hud.detailsLabelText && [hud.detailsLabelText hasPrefix:downloadedPrefix]) {
            return NO;
        }
    }
    return YES;
}

# pragma mark - Sync Methods

- (void)resetStateValues {
    isDoneQuizletSync = NO;
    isDoneFcppSyncFinalRun = NO;
    isDoneFcppSyncFirstRun = NO;
    isCurrentlySyncing = NO;
    
    syncDidUploadChanges = NO;
    syncIsRunningFromBackground = NO;
    
    quizletSync.didSync = NO;
}

- (void)checkIfSyncIsFinished {
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
    // here is where we will continue to the next steps if we are syncing EVERYTHING.
    // DOWNLOAD DATA
    // 1. Download all sets (with cards) and pick out the ones that need to be imported.
    if ([FlashCardsCore appIsSyncing] &&
        !isDoneFcppSyncFirstRun &&
        self.documentSyncManager &&
        self.documentSyncManager.state == TICDSDocumentSyncManagerStateAbleToSync) {
        FCLog(@"****** FC++ Sync #1");
        if ([self.documentSyncManager state] == TICDSDocumentSyncManagerStateSynchronizing) {
            // it's currently syncing -- stop the sync so it can begin again
            [self.documentSyncManager cancelSynchronization];
        }
        
        // check if the current version has the latest core data store:
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/checkhash", flashcardsServer]];
        ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
        __block FCSyncViewController* del = self.delegate;
        __block ASIFormDataRequest *requestBlock = request;
        [request prepareCoreDataSyncRequest];
        [request addPostValue:[FlashCardsCore managedObjectModelHash] forKey:@"dataHash"];
        [request addPostValue:[FlashCardsCore appVersion] forKey:@"currentVersion"];
        [request setCompletionBlock:^{
            FCLog(@"Response: %@", requestBlock.responseString);
            NSDictionary *result = [requestBlock.responseString objectFromJSONString];
            
            if ([[result objectForKey:@"OK"] intValue] == 1) {
                [self.documentSyncManager initiateSynchronization];
            } else {
                if ([[result objectForKey:@"is_logged_in"] intValue] == 1) {
                    FCDisplayBasicErrorMessage(@"",
                                               [NSString stringWithFormat:NSLocalizedStringFromTable(@"Please upgrade FlashCards++ to the latest version (%@) to sync your flash cards.", @"Sync", @""),
                                                [result valueForKey:@"latestVersion"]]
                                               );
                } else {
                    FCDisplayBasicErrorMessage(@"",
                                               NSLocalizedStringFromTable(@"Please log in to sync your flash cards.", @"Sync", @""));

                }
                
                // continue the process:
                [[[FlashCardsCore appDelegate] syncController] resetStateValues];
                [[[FlashCardsCore appDelegate] syncController].documentSyncManager setIsCurrentlySyncing:NO];
                SyncController *controller = [[FlashCardsCore appDelegate] syncController];
                if (del && [del respondsToSelector:@selector(syncDidFinish:)]) {
                    if ([del respondsToSelector:@selector(syncHUD)]) {
                        if ([del performSelector:@selector(syncHUD)]) {
                            [[del performSelector:@selector(syncHUD)] hide:YES];
                        }
                    }
                    [del performSelectorOnMainThread:@selector(syncDidFinish:)
                                          withObject:controller
                                       waitUntilDone:NO];
                }
            }
        }];
        [request setFailedBlock:^{
            FCDisplayBasicErrorMessage(@"",
                                       NSLocalizedStringFromTable(@"Could not contact server.", @"Sync", @""));
            
            // continue the process:
            [[[FlashCardsCore appDelegate] syncController] resetStateValues];
            [[[FlashCardsCore appDelegate] syncController].documentSyncManager setIsCurrentlySyncing:NO];
            SyncController *controller = [[FlashCardsCore appDelegate] syncController];
            if (del && [del respondsToSelector:@selector(syncDidFinish:)]) {
                if ([del respondsToSelector:@selector(syncHUD)]) {
                    if ([del performSelector:@selector(syncHUD)]) {
                        [[del performSelector:@selector(syncHUD)] hide:YES];
                    }
                }
                [del performSelectorOnMainThread:@selector(syncDidFinish:)
                                      withObject:controller
                                   waitUntilDone:NO];
            }
        }];
        [request startAsynchronous];
    } else {
            if (!isDoneQuizletSync && (userInitiatedSync || quizletDidChange) && !self.syncIsRunningFromBackground) {
                FCLog(@"****** Quizlet Sync");
                [self.quizletSync syncAllData];
            } else {
                BOOL mustSyncTwice = NO;
                if (self.quizletSync.didSync) {
                    mustSyncTwice = YES;
                }
                if ([FlashCardsCore appIsSyncing] &&
                    mustSyncTwice &&
                    self.documentSyncManager &&
                    self.documentSyncManager.state == TICDSDocumentSyncManagerStateAbleToSync &&
                    !isDoneFcppSyncFinalRun) {
                    FCLog(@"****** FC++ Sync #2");
                    [self.documentSyncManager initiateSynchronization];
                } else {
                    isFinished = YES;
                }
            }
    }
    if (isFinished) {
        FCLog(@"****** SYNC IS FINISHED");
        [FlashCardsCore setSetting:@"lastSyncAllData" value:[NSDate date]];
        [FlashCardsCore uploadLastSyncDates];
        
        // upload number of cards:
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/finish", flashcardsServer]];
        ASIFormDataRequest *requestNum = [[ASIFormDataRequest alloc] initWithURL:url];
        [requestNum prepareCoreDataSyncRequest];
        __block ASIFormDataRequest *requestBlock = requestNum;
        [requestNum setupFlashCardsAuthentication:@"sync/finish"];
        [requestNum addPostValue:[[UIDevice currentDevice] uniqueDeviceIdentifier] forKey:@"device_id"];
        [requestNum addPostValue:[[UIDevice currentDevice] advertisingIdentifier] forKey:@"device_adid"];
        [requestNum addPostValue:[NSNumber numberWithInt:[FlashCardsCore numTotalCards]] forKey:@"number_cards"];
        [requestNum addPostValue:[NSNumber numberWithInt:[FlashCardsCore numCardsToStudy]] forKey:@"number_study"];
        [requestNum addPostValue:[NSNumber numberWithBool:[FlashCardsCore appIsSyncing]] forKey:@"is_syncing"];
        [requestNum addPostValue:[NSNumber numberWithBool:self.syncDidUploadChanges] forKey:@"sync_did_upload_changes"];
        NSString *firstVersionInstalled = (NSString*)[FlashCardsCore getSetting:@"firstVersionInstalled"];
        [requestNum addPostValue:firstVersionInstalled forKey:@"version"];
        NSString *callKey = [FlashCardsCore randomStringOfLength:20];
        FCLog(@"Call Key: %@", callKey);
        [requestNum addPostValue:[callKey encryptWithKey:flashcardsServerCallKeyEncryptionKey] forKey:@"call"];
        [requestNum setCompletionBlock:^{
            FCLog(@"Response: %@", requestBlock.responseString);
        }];
        [requestNum startAsynchronous];
        
        // continue the process:
        [self resetStateValues];
        [self setSyncWillUploadChanges:NO];
        [self.documentSyncManager setIsCurrentlySyncing:NO];
        if (delegate && [delegate respondsToSelector:@selector(syncDidFinish:)]) {
            [delegate syncDidFinish:self];
        }
        
        quizletDidChange = NO;
        userInitiatedSync = NO;
        
        MBProgressHUD *HUD = [FlashCardsCore currentHUD:@"syncHUD"];
        if (HUD) {
            [HUD hide:YES];
        }
        self.delegate = nil;
        isCurrentlySyncing = NO;
        [[UIApplication sharedApplication] endBackgroundTask:self.taskIdentifier];
        self.taskIdentifier = UIBackgroundTaskInvalid;
    }
}

- (void)quitSync {
    isDoneFcppSyncFinalRun = YES;
    isDoneFcppSyncFirstRun = YES;
    isDoneQuizletSync = YES;
    [self checkIfSyncIsFinished];
    isCurrentlySyncing = NO;
}

- (void)hideSyncHUD {
    MBProgressHUD *syncHUD = [FlashCardsCore currentHUD:@"syncHUD"];
    if (syncHUD) {
        [syncHUD setLabelText:NSLocalizedStringFromTable(@"Syncing Data", @"Import", @"")]; // so it can be forced to close
        [syncHUD hide:YES];
    }
}

- (void)displayGenericSyncErrorAndQuit:(NSString*)errorDescription forError:(NSError*)anError {
    FCDisplayBasicErrorMessage(@"Error",
                               [NSString stringWithFormat:@"%@: %@ (%@)", errorDescription, [anError description], [[anError userInfo] valueForKey:kTICDSErrorClassAndMethod]]);
    uploadStoreAfterRegistering = NO;
    downloadStoreAfterRegistering = NO;
    [self quitSync];
    [self hideSyncHUD];

}

- (void)onlineDataRemoved {

    [FlashCardsCore setSetting:@"appIsSyncing" value:@NO];
    [self setupBackgroundSyncing];
    [documentSyncManager performSelector:@selector(removeHelperFileDirectory:) withObject:nil];
    FCDisplayBasicErrorMessage(@"",
                               NSLocalizedStringFromTable(@"It appears that your FlashCards++ sync data has been removed from the server, or your current sync files do not match the server. This may occur when you replace the master database from another device. Automatic Sync has been disabled, to turn it on again, go to the Settings screen.", @"Sync", @""));
}

- (void)updateHUDLabel:(NSString *)labelText {
    dispatch_async(dispatch_get_main_queue(), ^{
        MBProgressHUD *syncHUD = [FlashCardsCore currentHUD:@"syncHUD"];
        if (syncHUD) {
            [syncHUD setLabelText:labelText];
        }
    });
}

# pragma mark - Quizlet

- (void)quizletSyncDidFinish:(QuizletSync *)client {
    isDoneQuizletSync = YES;
    [self checkIfSyncIsFinished];
}

- (void)quizletSyncDidFinish:(QuizletSync*)client withError:(NSError*)error {
    [quizletSync handleHTTPError:error];
    isDoneQuizletSync = YES;
    [self checkIfSyncIsFinished];
}

#pragma mark - TICoreDataSync [did begin or end]

- (void)documentSyncManagerDidBeginSynchronizing:(TICDSDocumentSyncManager *)aSyncManager {
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    [self.documentSyncManager setIsCurrentlySyncing:YES];

    [self updateHUDLabel:NSLocalizedStringFromTable(@"Syncing: FlashCards++", @"Sync", @"")];
}

- (void)documentSyncManagerDidFinishSynchronizing:(TICDSDocumentSyncManager *)aSyncManager {
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    
    [self.documentSyncManager setIsCurrentlySyncing:NO];

    uploadStoreAfterRegistering = NO;
    downloadStoreAfterRegistering = NO;
    
    if (isDoneFcppSyncFirstRun) {
        isDoneFcppSyncFinalRun = YES;
    }
    isDoneFcppSyncFirstRun = YES;
    
    isFirstDownload = NO;
    [FlashCardsCore setSetting:@"hasExecutedFirstSync" value:@YES];
    
    [self checkIfSyncIsFinished];
}

- (void)documentSyncManager:(TICDSDocumentSyncManager*)aSyncManager didFailToSynchronizeWithError:(NSError *)anError {
    [self.documentSyncManager setIsCurrentlySyncing:NO];

    if ([anError code] == TICDSErrorCodeSynchronizationFailedBecauseIntegrityKeyDirectoryIsMissing && !downloadStoreAfterRegistering) {
        [self onlineDataRemoved];
        [self quitSync];
        [self hideSyncHUD];
    } else {
        [self displayGenericSyncErrorAndQuit:@"Error syncing data" forError:anError];
    }
}

- (void)documentSyncManager:(TICDSDocumentSyncManager *)aSyncManager didFailToUploadWholeStoreWithError:(NSError *)anError {
    [self.documentSyncManager setIsCurrentlySyncing:NO];

    [self displayGenericSyncErrorAndQuit:@"Error uploading data store" forError:anError];
    [FlashCardsCore setSetting:@"appIsSyncing" value:@NO];
    [self setupBackgroundSyncing];
}

- (void)documentSyncManager:(TICDSDocumentSyncManager *)aSyncManager didFailToDownloadWholeStoreWithError:(NSError *)anError {
    [self.documentSyncManager setIsCurrentlySyncing:NO];

    [self displayGenericSyncErrorAndQuit:@"Error downloading data store" forError:anError];
    [FlashCardsCore setSetting:@"appIsSyncing" value:@NO];
    [self setupBackgroundSyncing];
}

- (void)documentSyncManager:(TICDSDocumentSyncManager *)aSyncManager didFailToDeleteSynchronizationDataFromDocumentForClientWithIdentifier:(NSString *)anIdentifier withError:(NSError *)anError {
    [self.documentSyncManager setIsCurrentlySyncing:NO];

    [self displayGenericSyncErrorAndQuit:@"Error deleting synchronization data from document" forError:anError];
    FCLog(@"didFailToDeleteSynchronizationDataFromDocumentForClientWithIdentifier:");
}

- (void)documentSyncManager:(TICDSDocumentSyncManager *)aSyncManager didFailToFetchInformationForAllRegisteredDevicesWithError:(NSError *)anError {
    [self.documentSyncManager setIsCurrentlySyncing:NO];

    [self displayGenericSyncErrorAndQuit:@"Error fetching information for all devices" forError:anError];
    FCLog(@"didFailToFetchInformationForAllRegisteredDevicesWithError:");
}

- (void)documentSyncManager:(TICDSDocumentSyncManager *)aSyncManager didFailToProcessSyncChangesAfterManagedObjectContextDidSave:(NSManagedObjectContext *)aMoc withError:(NSError *)anError {
    [self.documentSyncManager setIsCurrentlySyncing:NO];
    
    [self displayGenericSyncErrorAndQuit:@"Error processing sync changes" forError:anError];
    FCLog(@"didFailToProcessSyncChangesAfterManagedObjectContextDidSave:");
}

- (void)documentSyncManager:(TICDSDocumentSyncManager *)aSyncManager didFailToRegisterWithError:(NSError *)anError {
    [self.documentSyncManager setIsCurrentlySyncing:NO];

    [self displayGenericSyncErrorAndQuit:@"Error registering sync manager" forError:anError];
    FCLog(@"didFailToRegisterWithError:");
    isCurrentlyRegisteringSyncManagers = NO;
}

- (void)documentSyncManager:(TICDSDocumentSyncManager *)aSyncManager didFailToVacuumUnneededRemoteFilesWithError:(NSError *)anError {
    [self.documentSyncManager setIsCurrentlySyncing:NO];

    FCLog(@"didFailToVacuumUnneededRemoteFilesWithError:");
}
#pragma mark - TICoreDataSync [other methods]

- (void)documentSyncManager:(TICDSDocumentSyncManager *)aSyncManager didPauseSynchronizationAwaitingResolutionOfSyncConflict:(id)aConflict {
    [aSyncManager continueSynchronizationByResolvingConflictWithResolutionType:TICDSSyncConflictResolutionTypeLocalWins];
}

- (NSURL *)documentSyncManager:(TICDSDocumentSyncManager *)aSyncManager URLForWholeStoreToUploadForDocumentWithIdentifier:(NSString *)anIdentifier
                   description:(NSString *)aDescription
                      userInfo:(NSDictionary *)userInfo
{
    NSString *storePath = [[FlashCardsCore documentsDirectory] stringByAppendingPathComponent: @"FlashCards.sqlite"];
    NSURL *url = [NSURL fileURLWithPath:storePath];
    return url;
}

- (void)documentSyncManager:(TICDSDocumentSyncManager *)aSyncManager didPauseRegistrationAsRemoteFileStructureDoesNotExistForDocumentWithIdentifier:(NSString *)anIdentifier
                description:(NSString *)aDescription
                   userInfo:(NSDictionary *)userInfo
{
    /*
     If this is the very first time the app has been registered by any device, you
     won’t be able to download the store because no previous stores will exist.
     
     As you saw earlier, one of the required delegate methods will be called by
     the document sync manager to find out what to do if no remote file structure
     exists for a document, or if the document has been deleted.
     */
    [self setDownloadStoreAfterRegistering:NO];
    [aSyncManager continueRegistrationByCreatingRemoteFileStructure:YES];
}

- (void)documentSyncManager:(TICDSDocumentSyncManager *)aSyncManager didPauseRegistrationAsRemoteFileStructureWasDeletedForDocumentWithIdentifier:(NSString *)anIdentifier
                description:(NSString *)aDescription
                   userInfo:(NSDictionary *)userInfo
{
    /*
     If this is the very first time the app has been registered by any device, you
     won’t be able to download the store because no previous stores will exist.
     
     As you saw earlier, one of the required delegate methods will be called by
     the document sync manager to find out what to do if no remote file structure
     exists for a document, or if the document has been deleted.
     */
    [self setDownloadStoreAfterRegistering:NO];
    [aSyncManager continueRegistrationByCreatingRemoteFileStructure:YES];
}


- (void)documentSyncManagerDidFinishRegistering:(TICDSDocumentSyncManager *)aSyncManager {
    if ([self downloadStoreAfterRegistering]) {
        [[self documentSyncManager] initiateDownloadOfWholeStore];
    } else if (![self isCurrentlySyncing]) {
        // check the login and potentially run sync:
        UIViewController *vc = [FlashCardsCore currentViewController];
        NSArray *viewControllers = [vc.navigationController viewControllers];
        UIViewController *rootVC = [viewControllers objectAtIndex:0];
        if ([rootVC respondsToSelector:@selector(checkLoginStatus)]) {
            [rootVC performSelectorInBackground:@selector(checkLoginStatus) withObject:nil];
        }
    }
    documentSyncManagerHasRegistered = YES;
    isCurrentlyRegisteringSyncManagers = NO;
}

/*
 If another client has previously deleted this client from synchronizing with the
 document, the underlying helper files will automatically be removed, but you will
 need to initiate a store download to override the whole store document file you
 have locally (as it will be out of date compared to the available sets of sync changes).
 
 In a shipping application, you may want to copy the old store elsewhere in case
 the user wishes to restore it. For now, just implement the client deletion delegate
 warning method to indicate that the store should be downloaded.
 */
- (void)documentSyncManagerDidDetermineThatClientHadPreviouslyBeenDeletedFromSynchronizingWithDocument:(TICDSDocumentSyncManager *)aSyncManager {
    if (!self.isCurrentlyUploading && !downloadStoreAfterRegistering) {
        [self onlineDataRemoved];
    }
}

/*
 In order for other clients to be able to download the whole store, one client will
 obviously need to upload a copy of the store at some point.
 
 The document sync manager will ask whether to upload the store during document
 registration. For the purposes of this tutorial, implement this method to return
 YES, but only if this isn’t the first time this client has been registered:
 */
- (BOOL)documentSyncManagerShouldUploadWholeStoreAfterDocumentRegistration:(TICDSDocumentSyncManager *)aSyncManager {
    return uploadStoreAfterRegistering;
}

/*
 If the store file is downloaded, it will replace any file that has been created on disk.
 
 You’ll need to implement two delegate methods to make sure the persistent store
 coordinator can cope with the file being removed.
 
 First, implement the method called just before the store is replaced:
 */
- (void)documentSyncManager:(TICDSDocumentSyncManager *)aSyncManager willReplaceStoreWithDownloadedStoreAtURL:(NSURL *)aStoreURL {
    NSError *anyError = nil;
    NSPersistentStoreCoordinator *coordinator = [self.documentSyncManager.primaryDocumentMOC persistentStoreCoordinator];
    BOOL success = [coordinator removePersistentStore:[coordinator persistentStoreForURL:aStoreURL]
                                                error:&anyError];
    if(!success) {
        NSLog(@"Failed to remove persistent store at %@: %@",
              aStoreURL, anyError);
    }
}

/* Second, the method called just after the store is replaced: */

- (void)documentSyncManager:(TICDSDocumentSyncManager *)aSyncManager didReplaceStoreWithDownloadedStoreAtURL:(NSURL *)aStoreURL {
    NSError *anyError = nil;
    NSPersistentStoreCoordinator *coordinator = [self.documentSyncManager.primaryDocumentMOC persistentStoreCoordinator];
    id store = [coordinator addPersistentStoreWithType:NSSQLiteStoreType
                                         configuration:nil
                                                   URL:aStoreURL
                                               options:nil
                                                 error:&anyError];
    
    if(!store) {
        NSLog(@"Failed to add persistent store at %@: %@",
              aStoreURL, anyError);
    }
}

- (void)documentSyncManager:(TICDSDocumentSyncManager *)aSyncManager didMakeChangesToObjectsInBackgroundContextAndSaveWithNotification:(NSNotification *)aNotification {
    [self.documentSyncManager.primaryDocumentMOC mergeChangesFromContextDidSaveNotification:aNotification];
}

- (BOOL)documentSyncManagerShouldVacuumUnneededRemoteFilesAfterDocumentRegistration:(TICDSDocumentSyncManager *)aSyncManager {
    return YES;
}

- (void)documentSyncManagerDidBeginDownloadingWholeStore:(TICDSDocumentSyncManager *)aSyncManager {
    [FlashCardsCore showSyncHUD];
    MBProgressHUD *HUD = [FlashCardsCore currentHUD:@"syncHUD"];
    if (HUD) {
        [HUD setLabelText:NSLocalizedStringFromTable(@"Downloading Database", @"Sync", @"")];
        [HUD setMode:MBProgressHUDModeDeterminate];
        [HUD setProgress:0.0f];
    }
    isCurrentlySyncing = YES;
    isCurrentlyDownloading = YES;
    isCurrentlyUploading = NO;
    isCurrentlyUploadingForFirstTime = NO;
    [FlashCardsCore setSetting:@"hasExecutedFirstSync" value:@NO];
    isFirstDownload = YES;
}

- (void)documentSyncManagerDidFinishDownloadingWholeStore:(TICDSDocumentSyncManager *)aSyncManager {
    
    uploadStoreAfterRegistering = NO;
    downloadStoreAfterRegistering = NO;
    
    isCurrentlyDownloading = NO;
    isCurrentlyUploading = NO;
    isCurrentlyUploadingForFirstTime = NO;
    
    isFirstDownload = YES;
    [FlashCardsCore setSetting:@"hasExecutedFirstSync" value:@NO];

    [self restoreHUD];

    [FlashCardsCore setSetting:@"appIsSyncing" value:@YES];
    
    [[FlashCardsCore appDelegate] reloadDatabase:@NO]; // @NO = not reloading restore data
    
    [self setupBackgroundSyncing];

    isCurrentlySyncing = NO;

    UIViewController *vc = [[[[FlashCardsCore appDelegate] navigationController] viewControllers] objectAtIndex:0];
    if ([vc respondsToSelector:@selector(checkAutomaticallySyncButton)]) {
        [vc performSelectorOnMainThread:@selector(checkAutomaticallySyncButton)
                             withObject:nil
                          waitUntilDone:NO];
    }

    [FlashCardsCore setSetting:@"lastUploadedWholeStore" value:[NSDate date]];

}

- (void)documentSyncManagerDidBeginUploadingWholeStore:(TICDSDocumentSyncManager *)aSyncManager {
    isCurrentlyUploading = YES;
    isCurrentlyDownloading = NO;
    isFirstDownload = NO;
    UIViewController *vc = [FlashCardsCore currentViewController];
    if ([vc respondsToSelector:@selector(syncHUD)]) {
        MBProgressHUD *HUD = [vc valueForKey:@"syncHUD"];
        if (HUD) {
            [HUD setLabelText:NSLocalizedStringFromTable(@"Uploading Database", @"Sync", @"")];
            [HUD setMode:MBProgressHUDModeDeterminate];
            [HUD setProgress:0.0f];
        }
    }
    isCurrentlySyncing = YES;
}

- (void)documentSyncManagerDidFinishUploadingWholeStore:(TICDSDocumentSyncManager *)aSyncManager {
    uploadStoreAfterRegistering = NO;
    downloadStoreAfterRegistering = NO;
    isCurrentlyUploading = NO;
    isCurrentlyDownloading = NO;
    isFirstDownload = NO;
    [FlashCardsCore setSetting:@"appIsSyncing" value:@YES];
    [FlashCardsCore setSetting:@"hasExecutedFirstSync" value:@YES];
    [self setupBackgroundSyncing];
    NSString *uploaded = NSLocalizedStringFromTable(@"Your FlashCards++ database has been uploaded.", @"Sync", @"");
    NSString *turnOn = NSLocalizedStringFromTable(@"Turn on automatic sync on your other devices to begin syncing your flash cards.", @"Sync", @"");
    
    if (isCurrentlyUploadingForFirstTime) {
        FCDisplayBasicErrorMessage(@"", [NSString stringWithFormat:@"%@ %@", uploaded, turnOn]);
    } else {
        FCDisplayBasicErrorMessage(@"", uploaded);
    }
    [FlashCardsCore setSetting:@"lastUploadedWholeStore" value:[NSDate date]];
    [FlashCardsCore uploadLastSyncDates];
    
    isCurrentlyUploadingForFirstTime = NO;
    
    isCurrentlySyncing = NO;
    
    [self restoreHUD];
    
    UIViewController *vc = [[[[FlashCardsCore appDelegate] navigationController] viewControllers] objectAtIndex:0];
    if ([vc respondsToSelector:@selector(checkAutomaticallySyncButton)]) {
        [vc performSelectorOnMainThread:@selector(checkAutomaticallySyncButton)
                             withObject:nil
                          waitUntilDone:NO];
    }
}

- (void)documentSyncManager:(TICDSDocumentSyncManager *)aSyncManager didFinishDeletingSynchronizationDataFromDocumentForClientWithIdentifier:(NSString *)anIdentifier {
    MBProgressHUD *HUD = [FlashCardsCore currentHUD:@"syncHUD"];
    if (HUD) {
        [HUD hide:YES];
    }
}

# pragma mark - Other

- (void)setupBackgroundSyncing {
    // set up multitasking to do background fetch, if the user is syncing:
    if ([FlashCardsCore appIsSyncing]) {
        // register for remote notifications of updates
        [[UIApplication sharedApplication] registerUserNotificationSettings:
         [UIUserNotificationSettings settingsForTypes:
          (UIUserNotificationTypeSound | UIUserNotificationTypeAlert | UIUserNotificationTypeBadge) categories:nil]];
        [[UIApplication sharedApplication] registerForRemoteNotifications];
        // register for background fetching
        [[UIApplication sharedApplication] setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalMinimum];
    } else {
        [[UIApplication sharedApplication] setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalNever];
    }
}

- (void)restoreHUD {
    MBProgressHUD *HUD = [FlashCardsCore currentHUD:@"syncHUD"];
    if (HUD) {
        [HUD setDetailsLabelText:NSLocalizedStringFromTable(@"Tap to Cancel", @"Import", @"")];
        [HUD hide:YES];
    }
}




@end
