//
//  FlashCardsCore.m
//  FlashCards
//
//  Created by Jason Lustig on 5/18/11.
//  Copyright 2011-2014 Jason Lustig Lustig. All rights reserved.
//

#import "FlashCardsCore.h"

#import "FCCardSet.h"
#import "FCCollection.h"

#import "SettingsStudyViewController.h"

#import <StoreKit/StoreKit.h>
#import <Security/Security.h>

#import "RMStore.h"

#import "sys/sysctl.h"
#import "FCCollection.h"
#import "UIColor-Expanded.h"
#import "Reachability.h"
#import "FlashCardsAppDelegate.h"
#import "JSONKit.h"

#import "UIDevice+IdentifierAddition.h"
#import "NSData+MD5.h"
#import "NSData+Compression.h"
#import "NSDate+Compare.h"

#import "STKeychain.h"

#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
#import <MessageUI/MessageUI.h>
#import "Appirater.h"
#endif

#import <sys/xattr.h>
#import <Social/Social.h>
#import <Accounts/Accounts.h>

#import "ActionSheetStringPicker.h"
#import "UIAlertView+Blocks.h"
#import "ASIFormDataRequest.h"
#import "ASIDataCompressor.h"
#import "TICoreDataSync.h"

#import "HelpViewController.h"
#import "SubscriptionViewController.h"
#import "AppLoginViewController.h"
#import "RootViewController.h"

#import "DTVersion.h"
#import "DTASN1Parser.h"

#define INAPP_ATTR_START        1700
#define INAPP_QUANTIT           1701
#define INAPP_PRODID            1702
#define INAPP_TRANSID           1703
#define INAPP_PURCHDATE         1704
#define INAPP_ORIGTRANSID       1705
#define INAPP_ORIGPURCHDATE     1706
#define INAPP_ATTR_END          1707

#define ATTR_START              1
#define BUNDLE_ID               2
#define APP_VERSION             3
#define OPAQUE_VALUE            4
#define HASH                    5
#define ATTR_END                6
#define INAPP_PURCHASE          17
#define ORIGINAL_APP_VERSION    19

@implementation FlashCardsCore

#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED

+ (BOOL)iOSisGreaterThan:(float)versionNumber {
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= versionNumber) {
        return YES;
    }
    return NO;
}

+ (BOOL)appIsActive {
    return ([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive);
}

+ (void) writeAppReview {
    // send the user to the review:
    int appId = AppStoreId;
    
    // Save that we rated the app, so AppIRater does not ask them to rate it again. 
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setBool:YES forKey:kAppiraterRatedCurrentVersion];
    [userDefaults synchronize];

    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"itms-apps://ax.itunes.apple.com/WebObjects/MZStore.woa/wa/viewContentsUserReviews?type=Purple+Software&id=%d", appId]];
    [[UIApplication sharedApplication] openURL:url];
}

+ (void) shareWithEmail:(UIViewController<MFMailComposeViewControllerDelegate>*)delegate {
    MFMailComposeViewController* controller = [[MFMailComposeViewController alloc] init];
    controller.mailComposeDelegate = delegate;
    [controller setSubject:NSLocalizedStringFromTable(@"Try FlashCards++ for iPhone and iPod Touch!", @"Help", @"email subject")];
    [controller setMessageBody:NSLocalizedStringFromTable(@""
                                                          "<p>Hey there!</p>"
                                                          "<p>"
                                                          "I thought you might like to try <a href=\"http://bit.ly/iphoneflashcards\">FlashCards++ for iPhone and iPod Touch</a>, "
                                                          "the best way to study on the go. Import flash cards from Quizlet and FlashcardExchange, or create them on your phone."
                                                          "</p>"
                                                          "<p>To learn more about FlashCards++, visit <a href=\"http://www.iphoneflashcards.com/\">www.iphoneflashcards.com</a>."
                                                          "<p>Also, there is a free demo available if you want to try the app before you buy it.</p>", @"Help", @"email message")
                        isHTML:YES];
    [delegate presentViewController:controller animated:YES completion:nil];
    
    // Select the "To" recipients:
    // From http://www.iphonedevsdk.com/forum/iphone-sdk-development-advanced-discussion/32854-mfmailcomposeviewcontroller-setting-firstresponder-messagebody.html
    // and also from http://stackoverflow.com/questions/1690279/set-first-responder-in-mfmailcomposeviewcontroller
    [FlashCardsCore setMFMailFieldAsFirstResponder:controller.view mfMailField:@"MFMailRecipientTextField"];
}

+ (BOOL) setMFMailFieldAsFirstResponder:(UIView*)view mfMailField:(NSString*)field{
    for (UIView *subview in view.subviews) {
        
        NSString *className = [NSString stringWithFormat:@"%@", [subview class]];
        if ([className isEqualToString:field])
        {
            //Found the sub view we need to set as first responder
            [subview becomeFirstResponder];
            return YES;
        }
        
        if ([subview.subviews count] > 0) {
            if ([FlashCardsCore setMFMailFieldAsFirstResponder:subview mfMailField:field]){
                //Field was found and made first responder in a subview
                return YES;
            }
        }
    }
    
    //field not found in this view.
    return NO;
}


#endif

// as per: http://stackoverflow.com/questions/3862933/check-ios-version-at-runtime
+ (NSString *) osVersionNumber {
#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
    return [[UIDevice currentDevice] systemVersion];
#else
    // TODO MAC: Add support for feature
    return @"NOT SUPPORTED";
#endif
    /*
     int index = 0;
     NSInteger version = 0;
     
     NSArray* digits = [[UIDevice currentDevice].systemVersion componentsSeparatedByString:@"."];
     NSEnumerator* enumer = [digits objectEnumerator];
     NSString* number;
     while ((number = [enumer nextObject])) {
     if (index>2) {
     break;
     }
     NSInteger multipler = powf(100, 2-index);
     version += [number intValue]*multipler;
     index++;
     }
     return version;
     */
}

// as per: http://stackoverflow.com/questions/4857195/how-to-get-programmatically-ioss-alphanumeric-version-string
+ (NSString *)osVersionBuild {
    int mib[2] = {CTL_KERN, KERN_OSVERSION};
    u_int namelen = sizeof(mib) / sizeof(mib[0]);
    size_t bufferSize = 0;
    
    NSString *osBuildVersion = nil;
    
    // Get the size for the buffer
    sysctl(mib, namelen, NULL, &bufferSize, NULL, 0);
    
    u_char buildBuffer[bufferSize];
    int result = sysctl(mib, namelen, buildBuffer, &bufferSize, NULL, 0);
    
    if (result >= 0) {
        osBuildVersion = [[NSString alloc] initWithBytes:buildBuffer length:6 encoding:NSUTF8StringEncoding]; 
    }
    
    return osBuildVersion;   
}

+ (NSString*) appVersion {
    return [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
}

+ (NSString*) buildNumber {
    return [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString*)kCFBundleVersionKey];
}

+ (NSString*) deviceName {
    NSString *deviceName;
    // find out if they have an iPhone, IPod touch, or iPad
    if([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        deviceName = @"iPad";
    } else {
        deviceName = @"iPhone";
    }
    return deviceName;
}

+ (UIViewController*)currentViewController {
    NSArray *vcs = [[[FlashCardsCore appDelegate] navigationController] viewControllers];
    UIViewController *vc = [vcs lastObject];
    return vc;
}

+ (UIViewController*)parentViewController {
    return [FlashCardsCore parentViewController:0];
}
+ (UIViewController*)parentViewController:(int)extraDown {
    FlashCardsAppDelegate *delegate = [FlashCardsCore appDelegate];
    UINavigationController *controller = [delegate navigationController];
    NSArray *vcs = [controller viewControllers];
    if ([vcs count] > (1 + extraDown)) {
        return [vcs objectAtIndex:([vcs count]-2-extraDown)];
    }
    return nil;
}

+ (MBProgressHUD*)currentHUD {
    return [FlashCardsCore currentHUD:@"HUD"];
}

+ (MBProgressHUD*)currentHUD:(NSString*)HUDname {
    UIViewController *vc = [FlashCardsCore currentViewController];
    MBProgressHUD *HUD;
    // as per: http://stackoverflow.com/a/112668/353137
    if ([vc respondsToSelector:NSSelectorFromString(HUDname)]) {
        HUD = [vc valueForKey:HUDname];
    }
    return HUD;
}

#pragma mark - Core Data
+ (NSString*)managedObjectModelHash {
    NSManagedObjectContext *context = [FlashCardsCore mainMOC];
    NSManagedObjectModel *model = [[context persistentStoreCoordinator] managedObjectModel];
    NSDictionary *entities = [model entityVersionHashesByName];
    NSMutableArray *entityNames = [NSMutableArray arrayWithArray:[entities allKeys]];
    [entityNames sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    NSMutableData *hash = [[NSMutableData alloc] initWithLength:0];
    for (NSString *name in entityNames) {
        FCLog(@"entity name: %@", name);
        NSData *entityHash = [entities objectForKey:name];
        [hash appendData:entityHash];
    }
    NSString *hashString = [hash base64Encoding];
    NSString *hashMd5 = [hashString md5];
    FCLog(@"MOM: %@", hashMd5);
    return hashMd5;
}

#pragma mark - TICoreDataSync

+ (void)sync {
    [[[FlashCardsCore appDelegate] syncController] sync];
}

+ (void)sync:(UIViewController <SyncControllerDelegate> *)syncDelegate {
    [[[FlashCardsCore appDelegate] syncController] setDelegate:syncDelegate];
    [FlashCardsCore sync];
}

+ (BOOL)canShowSyncHUD:(UIViewController*)vc {
    if (!vc) {
        return NO;
    }
    if (![vc respondsToSelector:@selector(syncHUD)]) {
        return NO;
    }
    return YES;
}

+ (void)showSyncHUD {
    if (![FlashCardsCore isConnectedToInternet]) {
        return;
    }
    UIViewController *vc = [FlashCardsCore currentViewController];
    if (!vc) {
        return;
    }
    if ([vc respondsToSelector:@selector(syncHUD)]) {
        MBProgressHUD *HUD = [vc valueForKey:@"syncHUD"];
        if (!HUD && [vc respondsToSelector:@selector(createSyncHUD)]) {
            [vc performSelectorOnMainThread:@selector(createSyncHUD) withObject:nil waitUntilDone:YES];
            HUD = [vc valueForKey:@"syncHUD"];
        }
        HUD.labelText = NSLocalizedStringFromTable(@"Syncing Data", @"Import", @"HUD");
        HUD.detailsLabelText = NSLocalizedStringFromTable(@"Tap to Cancel", @"Import", @"HUD");
        [HUD show:YES];
    }
}

+ (void)syncSetup {
    if (![FlashCardsCore isConnectedToInternet]) {
        return;
    }

    [FlashCardsCore showSyncHUD];
    
    [[FlashCardsCore appDelegate] registerSyncManager];
}

+ (void)syncCancel {
    [[[FlashCardsCore appDelegate] syncController] cancel];
}

+ (void)presentSyncOptions:(BOOL)hasCreatedSync {
    RIButtonItem *dontSync = [RIButtonItem item];
    dontSync.label = NSLocalizedStringFromTable(@"Do Not Sync", @"Sync", @"");
    dontSync.action = ^{
        [FlashCardsCore setSetting:@"appIsSyncing" value:@NO];
        UIViewController *vc = [FlashCardsCore currentViewController];
        if ([vc respondsToSelector:@selector(displaySync)]) {
            [vc performSelector:@selector(displaySync)];
        }
    };
    
    RIButtonItem *cancel = [RIButtonItem item];
    cancel.label = NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"");
    cancel.action = ^{
        [FlashCardsCore setSetting:@"appIsSyncing" value:@NO];
    };
    
    RIButtonItem *downloadData = [RIButtonItem item];
    downloadData.label = NSLocalizedStringFromTable(@"Download and Sync", @"Sync", @"");
    downloadData.action = ^{
        SyncController *controller = [[FlashCardsCore appDelegate] syncController];
        [controller setUploadStoreAfterRegistering:NO];
        [controller setDownloadStoreAfterRegistering:YES];
        [controller setDocumentSyncManager:nil];
        [controller setQuizletDidChange:NO];
        [controller setIsCurrentlyDownloading:YES];
        [controller setIsCurrentlyUploading:NO];
        [controller setIsCurrentlyUploadingForFirstTime:NO];
        [FlashCardsCore showSyncHUD];
        [FlashCardsCore syncSetup];
    };
    
    
    RIButtonItem *optimizeItem = [RIButtonItem item];
    optimizeItem.label = NSLocalizedStringFromTable(@"Optimize Database", @"Settings", @"otherButtonTitles");
    optimizeItem.action = ^{
        [[[FlashCardsCore appDelegate] syncController] cancel];
        [[FlashCardsCore appDelegate] setShouldCancelTICoreDataSyncIdCreation:YES];
        
        UIViewController <MBProgressHUDDelegate> *vc = (UIViewController <MBProgressHUDDelegate> *)[FlashCardsCore currentViewController];
        if ([vc respondsToSelector:@selector(HUD)]) {
            MBProgressHUD *HUD = [[MBProgressHUD alloc] initWithView:vc.view];
            [vc setValue:HUD forKey:@"HUD"];
            // Add HUD to screen
            [vc.view addSubview:HUD];
            // Regisete for HUD callbacks so we can remove it from the window at the right time
            HUD.delegate = vc;
            HUD.minShowTime = 1.0;
            HUD.labelText = NSLocalizedStringFromTable(@"Optimizing Database", @"Settings", @"HUD");
            HUD.detailsLabelText = NSLocalizedStringFromTable(@"May take a minute on large databases.", @"FlashCards", @"HUD");
            [HUD show:YES];
        }
        [[FlashCardsCore appDelegate] performSelectorInBackground:@selector(compressAndSync) withObject:nil];
    };
    
    RIButtonItem *uploadData = [RIButtonItem item];
    uploadData.label = NSLocalizedStringFromTable(@"Upload Database Now", @"Backup", @"otherButtonTitles");
    uploadData.action = ^{
        SyncController *controller = [[FlashCardsCore appDelegate] syncController];
        [controller setQuizletDidChange:NO];
        [[FlashCardsCore appDelegate] performSelectorInBackground:@selector(setupSyncWorker) withObject:nil];
    };
    
    RIButtonItem *replaceData = [RIButtonItem item];
    replaceData.label = NSLocalizedStringFromTable(@"Upload New Master Database", @"Sync", @"");
    replaceData.action = ^{
        
        NSString *message = NSLocalizedStringFromTable(@"Do you want to optimize your FlashCards++ database before uploading it?", @"Backup", @"message");
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@""
                                                        message:message
                                               cancelButtonItem:cancel
                                               otherButtonItems:optimizeItem, uploadData, nil];
        [alert show];
        
    };
    
    // time to set up sync. ask if they want to:
    // (a) don't sync
    // (b) sync
    RIButtonItem *sync = [RIButtonItem item];
    sync.label = NSLocalizedStringFromTable(@"Turn On Sync", @"Sync", @"");
    sync.action = ^{
        if (hasCreatedSync) {
            // sync has already been uploaded from elsewhere. ask if they want to:
            // (a) don't sync
            // (b) sync with uploaded data from other devices
            // (c) replace with data on current device
            
            NSString *deviceName = [FlashCardsCore deviceName];
            
            NSString *message = [NSString stringWithFormat:NSLocalizedStringFromTable(@"You already uploaded flash cards for automatic sync. If you sync your %@ with this previously uploaded master database, ALL flash cards on your %@ will be replaced with this data. If you want, you can upload your %@'s flash cards as a new master sync database instead.", @"Sync", @""),
                                 deviceName, deviceName, deviceName, nil];
            
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@""
                                                            message:message
                                                   cancelButtonItem:cancel
                                                   otherButtonItems:downloadData, replaceData, nil];
            [alert show];
        } else {
            [[[FlashCardsCore appDelegate] syncController] setUploadStoreAfterRegistering:YES];
            [[[FlashCardsCore appDelegate] syncController] setDownloadStoreAfterRegistering:NO];
            [[[FlashCardsCore appDelegate] syncController] setIsCurrentlyUploading:YES];
            [[[FlashCardsCore appDelegate] syncController] setIsCurrentlyUploadingForFirstTime:YES];
            [[[FlashCardsCore appDelegate] syncController] setIsCurrentlyDownloading:NO];
            [FlashCardsCore syncSetup];
        }
    };
    
    NSString *message = NSLocalizedStringFromTable(@"As a FlashCards++ Subscriber, you can automatically sync all your data between your devices, e.g. iPhone and iPad. Would you like to turn on automatic sync? After the initial sync is complete, you can log in on your other devices to sync them with your FlashCards++ data.", @"Sync", @"");
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Sync FlashCards++ Data", @"Sync", @"")
                                                    message:message
                                           cancelButtonItem:dontSync
                                           otherButtonItems:sync, nil];
    [alert show];
}

#pragma mark -
#pragma mark Chunked Upload

+ (NSString*)createChunkOfFile:(NSString*)filePath atOffset:(UInt32)offset withLength:(UInt32)chunkLength {
    // as per: http://stackoverflow.com/a/7489752/353137
    NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:filePath];
    [handle seekToFileOffset:offset];

    NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath
                                                                                    error:nil];
    UInt32 fileSize = [[fileAttributes objectForKey:NSFileSize] intValue];

    if (offset + chunkLength > fileSize) {
        NSLog(@"last chunk");
        // chunkLength = fileSize - offset;
    }
    
    NSData *chunk = [handle readDataOfLength:chunkLength];
    NSData *chunkSmall = [chunk gzipDeflate];
    
    NSString *tempChunkPath = [[FlashCardsCore documentsDirectory] stringByAppendingPathComponent: @"temp.chunk"];
    [chunkSmall writeToFile:tempChunkPath atomically:YES];

    NSString *tempChunkBigPath = [[FlashCardsCore documentsDirectory] stringByAppendingPathComponent: @"temp-big.chunk"];
    [chunk writeToFile:tempChunkBigPath atomically:YES];
    
    return tempChunkPath;
}

+ (void)uploadFileChunk:(NSString *)localFilePath
        toFinalLocation:(NSString *)finalLocation
      withFinalFileName:(NSString *)finalFileName
             uploadUUID:(NSString *)uploadUUID
                 offset:(int)newOffset
             errorCount:(int)errorCount
    withCompletionBlock:(ASIBasicBlock) completionBlock
        withFailedBlock:(ASIBasicBlock) failedBlock
     showUploadProgress:(BOOL)showUploadProgress
{
    MBProgressHUD *HUD;
    UIViewController *vc = [FlashCardsCore currentViewController];
    if ([vc respondsToSelector:@selector(syncHUD)]) {
        HUD = [vc valueForKey:@"syncHUD"];
    }
    if (HUD && showUploadProgress) {
        [HUD setMode:MBProgressHUDModeDeterminate];
    }
    
    if (newOffset == 0) {
        [FlashCardsCore setSetting:@"uploadIsCanceled" value:@NO];
    } else {
        BOOL uploadIsCanceled = [FlashCardsCore getSettingBool:@"uploadIsCanceled"];
        if (uploadIsCanceled) {
            return;
        }
    }

    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/uploadchunk", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request prepareCoreDataSyncRequest];
    NSString *chunkPath = [FlashCardsCore createChunkOfFile:localFilePath
                                                   atOffset:newOffset
                                                 withLength:chunkUploadSize];

    [request addFile:chunkPath
        withFileName:finalFileName
      andContentType:@"application/octet-stream"
              forKey:@"chunkData"];
    
    NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:localFilePath
                                                                                    error:nil];
    NSNumber *fileSize = [fileAttributes objectForKey:NSFileSize];
    [request addPostValue:fileSize
                   forKey:@"totalFilesizeExpected"];
    if ([uploadUUID length] > 0) {
        [request addPostValue:uploadUUID
                       forKey:@"uploadUUID"];
    }
    [request setCompletionBlock:^{
        NSLog(@"%@", requestBlock.responseString);
        
        NSDictionary *response = [requestBlock.responseString objectFromJSONString];
        
        NSString *localFilePath = [requestBlock.userInfo valueForKey:@"localFilePath"];
        NSString *finalLocation = [requestBlock.userInfo valueForKey:@"finalLocation"];
        NSString *finalFileName = [requestBlock.userInfo valueForKey:@"finalFileName"];
        NSNumber *errorCountN   = [requestBlock.userInfo valueForKey:@"errorCount"];
        int errorCount = [errorCountN intValue];
        NSString *uploadUUID = [response valueForKey:@"upload_uuid"];
        int newOffset = [(NSNumber*)[response objectForKey:@"offset"] intValue];
        int totalFileSize = [(NSNumber*)[response objectForKey:@"total_filesize_expected"] intValue];
        
        if (newOffset >= totalFileSize) {
            //Upload complete, commit the file.
            
            if (HUD) {
                [HUD setMode:MBProgressHUDModeIndeterminate];
            }
            [FlashCardsCore finishChunkedUpload:localFilePath
                                toFinalLocation:finalLocation
                              withFinalFileName:finalFileName
                                     uploadUUID:uploadUUID
                            withCompletionBlock:completionBlock
                                withFailedBlock:failedBlock];
        } else {
            //Send the next chunk and update the progress HUD.
            float progress = (float)((float)newOffset / (float)totalFileSize);
            if (HUD) {
                if (HUD.mode == MBProgressHUDModeDeterminate) {
                    NSString *labelText = [NSString stringWithFormat:NSLocalizedStringFromTable(@"Uploaded: %1.2f%%", @"Backup", @""), (progress*100.0)];
                    [HUD performSelector:@selector(setDetailsLabelText:) withObject:labelText];
                    [HUD setProgress:progress];
                }
            }
            
            [FlashCardsCore uploadFileChunk:localFilePath
                            toFinalLocation:finalLocation
                          withFinalFileName:finalFileName
                                 uploadUUID:uploadUUID
                                     offset:newOffset
                                 errorCount:errorCount
                               withCompletionBlock:completionBlock
                            withFailedBlock:failedBlock
                         showUploadProgress:showUploadProgress];
        }
    }];
    [request setFailedBlock:^{
        NSLog(@"FAILED: %@", requestBlock.responseString);
        
        NSString *localFilePath = [requestBlock.userInfo valueForKey:@"localFilePath"];
        NSString *finalLocation = [requestBlock.userInfo valueForKey:@"finalLocation"];
        NSString *finalFileName = [requestBlock.userInfo valueForKey:@"finalFileName"];
        NSString *uploadUUID    = [requestBlock.userInfo valueForKey:@"uploadUUID"];
        NSNumber *offsetN       = [requestBlock.userInfo objectForKey:@"offset"];
        NSNumber *errorCountN   = [requestBlock.userInfo objectForKey:@"errorCount"];
        int errorCount = [errorCountN intValue];
        int newOffset = [offsetN intValue];
        errorCount++;
        
        if (errorCount < 10) {
            [FlashCardsCore uploadFileChunk:localFilePath
                            toFinalLocation:finalLocation
                          withFinalFileName:finalFileName
                                 uploadUUID:uploadUUID
                                     offset:newOffset
                                 errorCount:errorCount
                        withCompletionBlock:completionBlock
                            withFailedBlock:failedBlock
                         showUploadProgress:showUploadProgress];
        } else {
            if (failedBlock) {
                failedBlock();
            }
        }
    }];
    [request setUserInfo:@{
     @"errorCount" : [NSNumber numberWithInt:errorCount],
     @"offset" : [NSNumber numberWithInt:newOffset],
     @"localFilePath" : localFilePath,
     @"uploadUUID" : uploadUUID,
     @"finalLocation" : finalLocation,
     @"finalFileName" : finalFileName,
     }];
    [request startAsynchronous];
}

+ (void)finishChunkedUpload:(NSString *)localFilePath
            toFinalLocation:(NSString *)finalLocation
          withFinalFileName:(NSString *)finalFileName
                 uploadUUID:(NSString *)uploadUUID
        withCompletionBlock:(ASIBasicBlock) completionBlock
            withFailedBlock:(ASIBasicBlock) failedBlock
{
    MBProgressHUD *HUD;
    UIViewController *vc = [FlashCardsCore currentViewController];
    if ([vc respondsToSelector:@selector(syncHUD)]) {
        HUD = [vc valueForKey:@"syncHUD"];
    }
    if (HUD) {
        if (HUD.mode == MBProgressHUDModeDeterminate) {
            float progress = 1.0f;
            NSString *labelText = [NSString stringWithFormat:NSLocalizedStringFromTable(@"Uploaded: %1.2f%%", @"Backup", @""), (progress*100.0)];
            [HUD performSelector:@selector(setDetailsLabelText:) withObject:labelText];
            [HUD setProgress:progress];
        }
    }

    BOOL uploadIsCanceled = [FlashCardsCore getSettingBool:@"uploadIsCanceled"];
    if (uploadIsCanceled) {
        return;
    }
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/finishupload", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    [request prepareCoreDataSyncRequest];
    [request addPostValue:uploadUUID
                   forKey:@"uploadUUID"];
    [request addPostValue:finalLocation
                   forKey:@"finalLocation"];
    [request addPostValue:finalFileName
                   forKey:@"finalFileName"];
    [request setCompletionBlock:completionBlock];
    [request setFailedBlock:failedBlock];
    [request startAsynchronous];
}


#pragma mark -
#pragma mark Google language functions

// loads all of the languages, with the Google codes, with the ones that have been used on top.
+ (NSMutableArray*)loadGoogleLanguageFromManagedObjectContext:(NSManagedObjectContext*)managedObjectContext {
    NSString *path = [[NSBundle mainBundle] pathForResource:@"GoogleLanguages" ofType:@"plist"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:path]) {
        NSLog(@"File does not exist.");
        return [NSMutableArray arrayWithCapacity:0];
    }
    
    // as per: http://stackoverflow.com/questions/5120641/how-to-get-localized-list-of-available-iphone-language-names-in-objective-c
    /*
    NSArray *test = [NSLocale availableLocaleIdentifiers];
    NSLog(@"%@", test);
    for (int i = 0; i < [test count]; i++) {
        NSLog(@"%@", [[NSLocale currentLocale] displayNameForKey:NSLocaleIdentifier value:[test objectAtIndex:i]]);
    }
    
    NSArray* languages = [[NSUserDefaults standardUserDefaults] objectForKey:@"AppleLanguages"];
    for (int i = 0; i < [languages count]; i++) {
        NSLog(@"%@ - %@", [languages objectAtIndex:i], [[NSLocale currentLocale] displayNameForKey:NSLocaleIdentifier value:[languages objectAtIndex:i]]);
    }
     */
    // 1. Load the langauges from te file
    NSMutableArray *googleLanguages = [[NSMutableArray alloc] initWithContentsOfFile:path];
    // 2. Look up the language names from the locale
    NSDictionary *language;
    NSDictionary *math = nil;
    NSDictionary *chemistry = nil;
    int i, j;
    for (i = [googleLanguages count]-1; i >= 0; i--) {
        language = [googleLanguages objectAtIndex:i];
        // localize the language name if possible
        if ([language valueForKey:@"appleAcronym"]) {
            [language setValue:[[NSLocale currentLocale] displayNameForKey:NSLocaleIdentifier value:[language valueForKey:@"appleAcronym"]] forKey:@"languageName"];
        } else {
            if ([[language valueForKey:@"languageName"] isEqualToString:@"Math"]) {
                math = language;
            }
            if ([[language valueForKey:@"languageName"] isEqualToString:@"Chemistry"]) {
                chemistry = language;
            }
            // remove any objects which don't have a local apple equivalent.
            [googleLanguages removeObjectAtIndex:i];
            continue;
        }
        [googleLanguages replaceObjectAtIndex:i withObject:language];
    }
    
    // 3. Sort the array by the new language name:
    [googleLanguages sortUsingDescriptors:[NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"languageName" ascending:YES]]];
    // 4. Add the "other" language option.
    [googleLanguages insertObject:[NSDictionary dictionaryWithObjectsAndKeys:@"-----", @"languageName", @"", @"googleAcronym", @"", @"appleAcronym", nil] atIndex:0];
    [googleLanguages insertObject:math atIndex:1];
    [googleLanguages insertObject:chemistry atIndex:2];
    [googleLanguages insertObject:[NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedStringFromTable(@"Other", @"FlashCards", @""), @"languageName", @"", @"googleAcronym", @"", @"appleAcronym", nil] atIndex:0];
    
    NSFetchRequest *fetchRequest;
    
    fetchRequest = [[NSFetchRequest alloc] init];
    // Edit the entity name as appropriate.
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Collection" inManagedObjectContext:managedObjectContext];
    [fetchRequest setEntity:entity];
    [fetchRequest setPropertiesToFetch:[NSArray arrayWithObjects:@"frontValueLanguage", @"backValueLanguage", nil]];
    [fetchRequest setResultType:NSDictionaryResultType];
    NSError *error;
    NSArray *tempLanguages = [managedObjectContext executeFetchRequest:fetchRequest error:&error];
    // to do: handle error
    
    // create a set of all the unique languages:
    NSMutableSet *myLanguages = [[NSMutableSet alloc] initWithCapacity:0];
    NSDictionary *temp;
    for (i = 0; i < [tempLanguages count]; i++) {
        temp = [tempLanguages objectAtIndex:i];
        if ([temp valueForKey:@"frontValueLanguage"]) {
            [myLanguages addObject:(NSString*)[temp valueForKey:@"frontValueLanguage"]];
        }
        if ([temp valueForKey:@"backValueLanguage"]) {
            [myLanguages addObject:(NSString*)[temp valueForKey:@"backValueLanguage"]];
        }
    }
    
    // make a list of the actual languages:
    NSMutableArray *finalLanguages = [[NSMutableArray alloc] initWithArray:[myLanguages allObjects]];
    NSString *currentLanguage;
    for (i = 0; i < [finalLanguages count]; i++) {
        currentLanguage = [finalLanguages objectAtIndex:i];
        if ([currentLanguage length] == 0) {
            continue;
        }
        for (j = 0; j < [googleLanguages count]; j++) {
            if ([[[googleLanguages objectAtIndex:j] valueForKey:@"googleAcronym"] isEqual:currentLanguage]) {
                [finalLanguages replaceObjectAtIndex:i withObject:[googleLanguages objectAtIndex:j]];
                continue;
            }
        }
    }
    for (i = (int)[finalLanguages count]-1; i >= 0; i--) {
        if ([[finalLanguages objectAtIndex:i] isKindOfClass:[NSString class]]) {
            [finalLanguages removeObjectAtIndex:i];
        }
    }
    
    // sort them by name:
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"languageName" ascending:YES];
    NSArray *sortDescriptors = [NSArray arrayWithObject:sortDescriptor];
    [finalLanguages sortUsingDescriptors:sortDescriptors];
    
    // add them to the list of languages, but backwards:
    for (i = (int)[finalLanguages count] - 1; i >= 0; i--) {
        [googleLanguages insertObject:[finalLanguages objectAtIndex:i] atIndex:1];
    }
    
    
    // release variables:
    
    return googleLanguages;
    
}

// does what it says it does: Translates a language acronym from one type to another.
// E.g., from Google to FCE, or FCE to Google
+ (NSString*)getLanguageAcronymFor:(NSString*)acronym fromKey:(NSString*)fromKey toKey:(NSString*)toKey {
    NSString *path = [[NSBundle mainBundle] pathForResource:@"GoogleLanguages" ofType:@"plist"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:path]) {
        NSLog(@"File does not exist.");
        return [NSMutableArray arrayWithCapacity:0];
    }
    
    // 1. Load the langauges from te file
    NSMutableArray *allLanguages = [[NSMutableArray alloc] initWithContentsOfFile:path];
    // 2. Look up the language names from the locale
    for (NSDictionary *language in allLanguages) {
        if ([[language valueForKey:fromKey] isEqual:acronym]) {
            return [language valueForKey:toKey];
        }
    }
    return nil;
}

# pragma mark - App Settings

// LOAD SETTINGS FROM USER FILE
+ (void)loadSettingsFile {
    NSString *path = [[NSBundle mainBundle] pathForResource:@"UserSettings" ofType:@"txt"];
    NSString *settingsToLoad;
    NSData *settingsData = [NSData dataWithContentsOfFile:path];
    settingsToLoad = [[NSString alloc] initWithData:settingsData encoding:NSUTF8StringEncoding];
    NSArray *settingsArray = [settingsToLoad componentsSeparatedByString:@"\n"];
    NSArray *settingsNotToLoad = @[@"fcppTransactionReceiptsToBeUploaded", @"UniqueDeviceIdentifier"];
    for (int i = 0; i < [settingsArray count] && i+1 < [settingsArray count]; i+=2) {
        NSString *settingName = [settingsArray objectAtIndex:i];
        NSString *settingValue = [settingsArray objectAtIndex:i+1];
        if ([settingsNotToLoad containsObject:settingName]) {
            continue;
        }
        FCLog(@"%@ = %@", settingName, settingValue);
        NSObject *defaultValue = [FlashCardsCore getSetting:settingName];
        FCLog(@"%@", [defaultValue class]);
        if ([[defaultValue class] isSubclassOfClass:[NSNumber class]]) {
            // convert to NSNumber
            // as per: http://stackoverflow.com/a/1448875/353137
            NSNumberFormatter * f = [[NSNumberFormatter alloc] init];
            [f setNumberStyle:NSNumberFormatterDecimalStyle];
            NSNumber * myNumber = [f numberFromString:settingValue];
            [FlashCardsCore setSetting:settingName value:myNumber];
        } else if ([[defaultValue class] isSubclassOfClass:[NSString class]]) {
            // it's expecting a string - nothing fancy here
            [FlashCardsCore setSetting:settingName value:settingValue];
        } else if ([[defaultValue class] isSubclassOfClass:[NSDate class]]) {
            // it's expecting a date - convert to a date
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss zzz"];
            NSDate *dateValue = [[NSDate alloc] init];
            dateValue = [dateFormatter dateFromString:settingValue];
            [FlashCardsCore setSetting:settingName value:dateValue];
        }
    }
}

+ (void) setSetting:(NSString*)settingName value:(NSObject*)userSetting {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([userSetting isKindOfClass:[FCColor class]]) {
        [defaults setValue:[(FCColor*)userSetting stringFromColor] forKey:settingName];
    } else {
        // TODO MAC: ADD SUPPORT FOR FEATURE
        [defaults setValue:userSetting forKey:settingName];
    }
    if ([settingName isEqualToString:@"quizletIsLoggedIn"]) {
        if (![((NSNumber*)userSetting) boolValue]) {
            [FlashCardsCore setSetting:@"quizletReadScope" value:[NSNumber numberWithBool:NO]];
            [FlashCardsCore setSetting:@"quizletWriteSetScope" value:[NSNumber numberWithBool:NO]];
            [FlashCardsCore setSetting:@"quizletWriteGroupScope" value:[NSNumber numberWithBool:NO]];
        }
    }
    FCLog(@"Saved Setting: %@ New Value: %@", settingName, userSetting);
    [defaults synchronize];
    
    if ([settingName isEqualToString:@"appIsSyncing"]) {
        UIViewController *vc = [FlashCardsCore currentViewController];
        if ([vc respondsToSelector:@selector(displayAll)]) {
            [vc performSelector:@selector(displayAll)];
        }
    }
}

+ (NSMutableDictionary*)defaultSettingsDictionary {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    NSMutableDictionary *defaultSettings = [NSMutableDictionary dictionaryWithCapacity:0];
    [defaultSettings setObject:@NO forKey:@"hasBeenAskedToViewGettingStartedTour"];
    [defaultSettings setObject:@NO forKey:@"hasBeenAskedToBecomeBetaTester"];
    [defaultSettings setObject:@NO forKey:@"hasBeenAskedToPostToSocialNetwork"];
    [defaultSettings setObject:@YES forKey:@"proceedToNextCardOnScore"];
    [defaultSettings setObject:@NO forKey:@"studySettingsLargeTextMode"];
    [defaultSettings setObject:[NSNumber numberWithBool:( [defaults valueForKey:@"studySettingsBackgroundColor"] ? NO : YES )]
                        forKey:@"studyDisplayLikeIndexCard"];
    [defaultSettings setObject:[NSNumber numberWithFloat:3.5f]
                        forKey:@"studySettingsAutoBrowseSpeed"];
    [defaultSettings setObject:[[FCColor blackColor] stringFromColor]
                        forKey:@"studySettingsBackgroundColor"];
    [defaultSettings setObject:[[FCColor whiteColor] stringFromColor]
                        forKey:@"studySettingsBackgroundTextColor"];
    [defaultSettings setObject:@YES forKey:@"studySettingsUseMarkdown"];
    
    [defaultSettings setObject:@"" forKey:@"quizletUsername"];
    [defaultSettings setObject:@"" forKey:@"flashcardExchangeUsername"];
    
    [defaultSettings setObject:@"/" forKey:@"dropboxCsvFilePath"];
    [defaultSettings setObject:@"/" forKey:@"dropboxEmailAddress"];
    [defaultSettings setObject:@"/FlashCards++ Backups" forKey:@"dropboxBackupFilePath"];
    [defaultSettings setObject:@"" forKey:@"dropboxEmailAddress"];
    
    [defaultSettings setObject:[NSNumber numberWithBool:YES] forKey:@"showSocialNetworkFooterVideoTutorials"];
    
    [defaultSettings setObject:@0 forKey:@"studySettingOrder"];
    [defaultSettings setObject:@0 forKey:@"studySettingSelectCards"];
    [defaultSettings setObject:@0 forKey:@"studySettingBrowseMode"];
    [defaultSettings setObject:[NSNumber numberWithInt:justifyCardCenter] forKey:@"studyCardJustification"];
    
    [defaultSettings setObject:[NSNumber numberWithInt:( [(NSNumber*)[defaults valueForKey:@"studySettingsLargeTextMode"] boolValue] ? sizeLarge : sizeNormal )]
                        forKey:@"studyTextSize"];
    [defaultSettings setObject:[NSNumber numberWithBool:YES] forKey:@"studySwipeToProceedCard"];
    
    [defaultSettings setObject:[NSNumber numberWithBool:NO] forKey:@"fceIsLoggedIn"];
    [defaultSettings setObject:@"" forKey:@"fceLoginUsername"];
    [defaultSettings setObject:@0 forKey:@"fceUserId"];
    [defaultSettings setObject:@"" forKey:@"fceAPIAccessToken"];
    [defaultSettings setObject:@"" forKey:@"fceAPIAccessTokenType"];
    [defaultSettings setObject:[NSDate date] forKey:@"fceAPIAccessTokenExpires"];
    [defaultSettings setObject:@"" forKey:@"fceRefreshToken"];
    [defaultSettings setObject:[NSDate date] forKey:@"fceRefreshTokenExpires"];
    [defaultSettings setObject:@NO forKey:@"fceReadScope"];
    [defaultSettings setObject:@NO forKey:@"fceWriteScope"];
    [defaultSettings setObject:@NO forKey:@"fceDeleteScope"];
    
    /*
     [defaultSettings setObject:nil forKey:@"quizletLastSyncAllData"];
     [defaultSettings setObject:nil forKey:@"quizletLastSyncUserSets"];
     [defaultSettings setObject:nil forKey:@"quizletLastSyncFavoriteSets"];
     [defaultSettings setObject:nil forKey:@"quizletLastSyncStudiedSets"];
     [defaultSettings setObject:nil forKey:@"quizletLastSyncGroups"];
     
     [defaultSettings setObject:nil forKey:@"flashcardExchangeLastSyncAllData"];
     [defaultSettings setObject:nil forKey:@"flashcardExchangeLastSyncUserSets"];
     */
    
    [defaultSettings setObject:[NSDate dateWithTimeIntervalSince1970:0] forKey:@"lastDisplayedOfflineMessage"];
    
    [defaultSettings setObject:@NO forKey:@"shouldSyncWhenComesOnline"];
    
    [defaultSettings setObject:@NO forKey:@"quizletIsLoggedIn"];
    [defaultSettings setObject:@"" forKey:@"quizletLoginUsername"];
    [defaultSettings setObject:@NO forKey:@"quizletPlus"];
    [defaultSettings setObject:@"" forKey:@"quizletAPI2AccessToken"];
    [defaultSettings setObject:@"" forKey:@"quizletAPI2AccessTokenType"];
    [defaultSettings setObject:@"" forKey:@"quizletLoginPassword"];
    
    [defaultSettings setObject:[NSNumber numberWithBool:( [(NSNumber*)[defaults valueForKey:@"quizletIsLoggedIn"] boolValue] )]
                        forKey:@"quizletReadScope"];
    [defaultSettings setObject:[NSNumber numberWithBool:( [(NSNumber*)[defaults valueForKey:@"quizletIsLoggedIn"] boolValue] )]
                        forKey:@"quizletWriteSetScope"];
    [defaultSettings setObject:@NO forKey:@"quizletWriteGroupScope"];
    [defaultSettings setObject:@NO forKey:@"noteAboutQuizletSetsForcedRemovalDisplayed"];
    [defaultSettings setObject:@YES forKey:@"settingDisplayBadge"];
    [defaultSettings setObject:@YES forKey:@"settingDisplayNotification"];
    [defaultSettings setObject:[NSNumber numberWithInt:9] forKey:@"settingDisplayNotificationTime"];
    [defaultSettings setObject:@NO forKey:@"hasUpdatedBadgeOnTerminate"];
    
    [defaultSettings setObject:@NO forKey:@"shouldUseAutoCorrect"];
    [defaultSettings setObject:@NO forKey:@"shouldUseAutoCapitalizeText"];
    [defaultSettings setObject:([(NSNumber*)[defaults valueForKey:@"studyDisplayLikeIndexCard"] boolValue] ? @"Marker Felt" :  @"Helvetica" ) forKey:@"studyCardFont"];
    
    [defaultSettings setObject:@NO forKey:@"importProcessRestore"];
    [defaultSettings setObject:@NO forKey:@"uploadProcessRestore"];
    
    [defaultSettings setObject:@"" forKey:@"importProcessRestoreCollectionId"];
    [defaultSettings setObject:@"" forKey:@"importProcessRestoreCardsetId"];
    [defaultSettings setObject:@"" forKey:@"importProcessRestoreSearchTerm"];
    [defaultSettings setObject:@"" forKey:@"importProcessRestoreChoiceViewController"];
    [defaultSettings setObject:@"" forKey:@"importProcessRestoreGroupId"];
    
    [defaultSettings setObject:@YES forKey:@"importSettingsAutoMergeIdenticalCards"];
    [defaultSettings setObject:@NO forKey:@"importSettingsAutoMergeIdenticalCardsAndResetStatistics"];
    
    [defaultSettings setObject:@NO forKey:@"displayCardsCustomOrder"];
    
    [defaultSettings setObject:@YES forKey:@"studyOnlyNewCards"];
    
    NSDate *dateOfFirstLaunch = [NSDate dateWithTimeIntervalSince1970:[defaults doubleForKey:@"kAppiraterFirstUseDate"]];
    // if (dateOfFirstLaunch < 5/15/2013 -- then we should note that they had an older version)
    if ([dateOfFirstLaunch isEarlierThan:[NSDate dateWithTimeIntervalSince1970:1368576000]]) {
        [defaultSettings setObject:@"5.3" forKey:@"firstVersionInstalled"];
    } else {
        [defaultSettings setObject:[FlashCardsCore appVersion] forKey:@"firstVersionInstalled"];
    }
    
    [defaultSettings setObject:[FlashCardsCore buildNumber] forKey:@"firstBuildInstalled"];
    [defaultSettings setObject:@0 forKey:@"displayCardSetsOrder"];
    
    /** Offline TTS **/
    [defaultSettings setObject:@YES forKey:@"cacheOfflineTTS"];
    [defaultSettings setObject:@NO forKey:@"offlineTTSUsesCellularData"];
    [defaultSettings setObject:@YES forKey:@"TTSIgnoresParentheses"];
    [defaultSettings setObject:@NO forKey:@"hasShownTTS100CharacterLimitWarning"];
    [defaultSettings setObject:[NSNumber numberWithInt:-1] forKey:@"offlineTTSCacheRemainingOnQuit"];
    
    [defaultSettings setObject:[NSDate date] forKey:@"lastUploadedCardsForOfflineTTSPrepare"];
    [defaultSettings setObject:@YES forKey:@"hasImportedCardsRecently"];
    
    /** SUBSCRIPTION **/
    [defaultSettings setObject:@NO forKey:@"hasFeatureWebsiteSync"];
    [defaultSettings setObject:@NO forKey:@"hasFeatureBackup"];
    [defaultSettings setObject:@NO forKey:@"hasFeatureHideAds"];
    [defaultSettings setObject:@NO forKey:@"hasFeatureFullscreenStudy"];
    [defaultSettings setObject:@NO forKey:@"hasFeatureUnlimitedCards"];
    [defaultSettings setObject:@NO forKey:@"hasFeatureAudio"];
    [defaultSettings setObject:@NO forKey:@"hasFeaturePhotos"];
    [defaultSettings setObject:@NO forKey:@"hasFeatureTTS"];
    [defaultSettings setObject:@NO forKey:@"hasSubscription"];
    [defaultSettings setObject:@NO forKey:@"hasEverHadASubscription"];
    [defaultSettings setObject:@NO forKey:@"hasSubscriptionLifetime"];
    [defaultSettings setObject:@NO forKey:@"hasPurchasedSubscription"];
    [defaultSettings setObject:@"" forKey:@"subscriptionProductId"];
    [defaultSettings setObject:[NSDate date] forKey:@"subscriptionEndDate"];
    [defaultSettings setObject:[NSDate date] forKey:@"subscriptionBeginDate"];
    [defaultSettings setObject:[NSDate date] forKey:@"promptCreateAccount"];
    [defaultSettings setObject:[NSDate date] forKey:@"promptRenewSubscription"];
    [defaultSettings setObject:[NSDate dateWithTimeIntervalSince1970:0] forKey:@"lastPromptRenewSubscriptionForSync"];
    [defaultSettings setObject:[NSNumber numberWithInt:0] forKey:@"promptRenewSubscriptionCount"];
    
    [defaultSettings setObject:@NO forKey:@"isTeacher"];
    [defaultSettings setObject:@0  forKey:@"studentSubscriptionsTotal"];
    [defaultSettings setObject:@0  forKey:@"studentSubscriptionsAllocated"];
    
    NSData *transactionsAsData = [NSKeyedArchiver archivedDataWithRootObject:[NSMutableArray arrayWithCapacity:0]];
    [defaultSettings setObject:transactionsAsData
                        forKey:@"fcppTransactionReceiptsToBeUploaded"];
    
    [defaultSettings setObject:@NO forKey:@"hasUsedOneTimeOfflineTTSTrial"];
    [defaultSettings setObject:@NO forKey:@"currentlyUsingOneTimeOfflineTTSTrial"];
    
    [defaultSettings setObject:@NO forKey:@"appIsSyncing"];
    [defaultSettings setObject:@NO forKey:@"uploadIsCanceled"];
    [defaultSettings setObject:@NO forKey:@"fixSyncIdsDidFinish"];
    [defaultSettings setObject:@YES forKey:@"shouldShowSyncButton"];
    [defaultSettings setObject:@NO forKey:@"hasExecutedFirstSync"];
    
    [defaultSettings setObject:@YES forKey:@"showForTeachersButton"];
    
    [defaultSettings setObject:[NSNumber numberWithInt:(60 * 60 * 24 * 3)]
                        forKey:@"lastUploadedWholeStoreRemindWait"];
    
    [defaultSettings setObject:@NO forKey:@"fcppIsLoggedIn"];
    [defaultSettings setObject:@"" forKey:@"fcppUsername"];
    [defaultSettings setObject:@"" forKey:@"fcppLoginKey"];
    
    [defaultSettings setObject:@NO forKey:@"hasFollowedOnTwitter"];
    
    [defaultSettings setObject:[NSDate dateWithTimeIntervalSince1970:0] forKey:@"lastDateStudied"];
    
    
    // If the user has seen what's new:
    [defaultSettings setObject:@NO forKey:[NSString stringWithFormat:@"whatsNew-%@", [FlashCardsCore appVersion]]];
    
    return defaultSettings;
}

+ (NSObject*) getSetting:(NSString*)settingName {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    id userSetting;
    if (![defaults objectForKey:settingName]) {
        NSMutableDictionary *defaultSettings = [FlashCardsCore defaultSettingsDictionary];
        
        userSetting = [defaultSettings valueForKey:settingName];
        [FlashCardsCore setSetting:settingName value:userSetting];
    } else {
        userSetting = [defaults valueForKey:settingName];
        if ([settingName isEqualToString:@"dropboxBackupFilePath"]) {
            if (![userSetting isKindOfClass:[NSString class]]) {
                NSLog(@"Resetting dropboxBackupFilePath...");
                userSetting = @"/FlashCards++ Backups";
                [FlashCardsCore setSetting:settingName value:userSetting];
            } else if (![(NSString*)userSetting hasPrefix:@"/"]) {
                NSLog(@"Resetting dropboxBackupFilePath...");
                userSetting = @"/FlashCards++ Backups";
                [FlashCardsCore setSetting:settingName value:userSetting];
            }
        }
    }
    return userSetting;
}

+ (BOOL)getSettingBool:(NSString*)settingName {
    return [(NSNumber*)[FlashCardsCore getSetting:settingName] boolValue];
}
+ (int)getSettingInt:(NSString*)settingName {
    return [(NSNumber*)[FlashCardsCore getSetting:settingName] intValue];
}
+ (NSDate*)getSettingDate:(NSString *)settingName {
    return (NSDate*)[FlashCardsCore getSetting:settingName];
}

# pragma mark - Subscriptions

+ (void)uploadLastSyncDates {
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/sync/updatesyncdates", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    [request prepareCoreDataSyncRequest];
    NSDate *lastSyncAllData = [FlashCardsCore getSettingDate:@"lastSyncAllData"];
    if (lastSyncAllData) {
        [request addPostValue:[NSNumber numberWithInt:[lastSyncAllData timeIntervalSince1970]]
                       forKey:@"fcpp"];
    }
    NSNumber *lastUploadedWholeStoreRemindWait = (NSNumber*)[FlashCardsCore getSetting:@"lastUploadedWholeStoreRemindWait"];
    if (lastUploadedWholeStoreRemindWait) {
        [request addPostValue:lastUploadedWholeStoreRemindWait
                       forKey:@"sync_last_upload_database_wait"];
    }
    NSDate *lastUploadedWholeStoreRemindDate = [FlashCardsCore getSettingDate:@"lastUploadedWholeStoreRemindDate"];
    if (lastUploadedWholeStoreRemindDate) {
        [request addPostValue:[NSNumber numberWithInt:[lastUploadedWholeStoreRemindDate timeIntervalSince1970]]
                       forKey:@"sync_last_upload_database_prompt"];
    }
    NSDate *lastUploadedWholeStore = [FlashCardsCore getSettingDate:@"lastUploadedWholeStore"];
    if (lastUploadedWholeStore) {
        [request addPostValue:[NSNumber numberWithInt:[lastUploadedWholeStore timeIntervalSince1970]]
                       forKey:@"sync_last_upload_database"];
    }
    
    [request setCompletionBlock:^{}];
    [request setFailedBlock:^{}];
    [request startAsynchronous];
}

+ (BOOL)appIsSyncing {
    BOOL isLoggedIn = [FlashCardsCore isLoggedIn];
    BOOL subscription = [FlashCardsCore hasSubscription];
    BOOL isSyncing = [FlashCardsCore getSettingBool:@"appIsSyncing"];
    return (isLoggedIn && subscription && isSyncing);
}

// checks if the app is syncing, without seeing if they have a current subscription
+ (BOOL)appIsSyncingNoSubscription {
    BOOL isLoggedIn = [FlashCardsCore isLoggedIn];
    BOOL isSyncing = [FlashCardsCore getSettingBool:@"appIsSyncing"];
    return (isLoggedIn && isSyncing);
}

+ (BOOL)hasGrandfatherClause {
    NSString *firstVersionInstalled = (NSString*)[FlashCardsCore getSetting:@"firstVersionInstalled"];
    float version = [firstVersionInstalled floatValue];
    if (version < firstVersionWithFreeDownload) {
        return YES;
    }
    return NO;
}

+ (BOOL)hasFeature:(NSString*)featureName {
    if ([FlashCardsCore hasSubscription]) {
        return YES;
    }
    
    // if the first version they installed was prior to when I instituted the new business model,
    // then they paid for the app. then give them access to everything!
    NSString *firstVersionInstalled = (NSString*)[FlashCardsCore getSetting:@"firstVersionInstalled"];
    float version = [firstVersionInstalled floatValue];
    if (version < firstVersionWithFreeDownload) {
        if ([featureName isEqualToString:@"HideAds"]) {
            return YES;
        }
        if ([featureName isEqualToString:@"FullscreenStudy"]) {
            return YES;
        }
        if ([featureName isEqualToString:@"WebsiteSync"]) {
            return YES;
        }
        if ([featureName isEqualToString:@"Backup"]) {
            return YES;
        }
        if ([featureName isEqualToString:@"UnlimitedCards"]) {
            return YES;
        }
        if ([featureName isEqualToString:@"Photos"]) {
            return YES;
        }
        if ([featureName isEqualToString:@"Audio"]) {
            return [FlashCardsCore hasSubscription];
        }
        if ([featureName isEqualToString:@"TTS"]) {
            if ([FlashCardsCore isConnectedToInternet]) {
                return YES;
            } else {
                return [FlashCardsCore hasSubscription];
            }
        }
    }
    if ([featureName isEqualToString:@"HideAds"]) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSDate *dateOfFirstLaunch = [NSDate dateWithTimeIntervalSince1970:[defaults doubleForKey:@"kAppiraterFirstUseDate"]];
        NSInteger daysSinceInstall = [[NSDate date] timeIntervalSinceDate:dateOfFirstLaunch] / 86400;
        if (daysSinceInstall < 3) {
            return YES;
        }
    }

    
    // features that are paid:
    // - Backup/restore
    // - Unlimited cards (> 100)
    // - Text-to-speech ("TTS")
    // - Photos ("Photos")
    // - Recorded audio ("Audio")
    // - Hide ads ("HideAds")
    // - Full screen studying ("FullscreenStudy")
    return [FlashCardsCore getSettingBool:[NSString stringWithFormat:@"hasFeature%@", featureName]];

}

+ (int)numCardsToStudy {
    return [FlashCardsCore numCardsToStudy:[FlashCardsCore mainMOC]];
}
+ (int)numCardsToStudy:(NSManagedObjectContext*)context {
    if (!context) {
        return -1;
    }
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:[NSEntityDescription entityForName:@"Card"
                                        inManagedObjectContext:context]];
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"isDeletedObject = NO and isSpacedRepetition = YES and isLapsed = NO and nextRepetitionDate <= %@", [NSDate date]]];
    int totalCount = [context countForFetchRequest:fetchRequest error:nil];
    return totalCount;
}

+ (int)numTotalCards {
    return [FlashCardsCore numTotalCards:[FlashCardsCore mainMOC]];
}
+ (int)numTotalCards:(NSManagedObjectContext*)context {
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    // Edit the entity name as appropriate.
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Card"
                                              inManagedObjectContext:context];
    [fetchRequest setEntity:entity];
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"isDeletedObject = NO"]];
    int total = [context countForFetchRequest:fetchRequest error:nil];
    return total;
}

+ (void)checkUnlimitedCards {
    int numTotalCards = [FlashCardsCore numTotalCards];

    if (numTotalCards >= maxCardsLite) {
        // then show a purchase popup:
        [FlashCardsCore showPurchasePopup:@"UnlimitedCards"];
    }
}

+ (void)showSubscriptionEndedPopup:(BOOL)force {
    // alert the user that sync won't work without a subscription.
    // options: subscribe; turn off sync
    RIButtonItem *dontSync = [RIButtonItem item];
    dontSync.label = NSLocalizedStringFromTable(@"Turn Off Sync", @"Sync", @"");
    dontSync.action = ^{
        [FlashCardsCore setSetting:@"appIsSyncing" value:@NO];
        UIViewController *vc = [FlashCardsCore currentViewController];
        if ([vc respondsToSelector:@selector(displaySync)]) {
            [vc performSelector:@selector(displaySync)];
        }
    };
    
    RIButtonItem *subscribe = [RIButtonItem item];
    subscribe.label = NSLocalizedStringFromTable(@"Renew Subscription", @"Settings", @"UIView title");
    subscribe.action = ^{
        SubscriptionViewController *vc = [[SubscriptionViewController alloc] initWithNibName:@"SubscriptionViewController" bundle:nil];
        vc.giveTrialOption = NO;
        vc.showTrialEndedPopup = NO;
        vc.explainSync = NO;
        UIViewController *current = [FlashCardsCore currentViewController];
        [current.navigationController pushViewController:vc animated:YES];
    };
    
    RIButtonItem *learnMoreItem = [RIButtonItem item];
    learnMoreItem.label = NSLocalizedStringFromTable(@"Learn More About Subscriptions", @"Subscription", @"");
    learnMoreItem.action = ^{
        UIViewController *current = [FlashCardsCore currentViewController];
        NSMutableArray *vcs = [NSMutableArray arrayWithArray:current.navigationController.viewControllers];
        SubscriptionViewController *subscriptionVC = [[SubscriptionViewController alloc] initWithNibName:@"SubscriptionViewController" bundle:nil];
        subscriptionVC.showTrialEndedPopup = NO;
        subscriptionVC.giveTrialOption = NO;
        subscriptionVC.explainSync = NO;
        [vcs addObject:subscriptionVC];
        
        [vcs addObject:[subscriptionVC learnMoreViewController]];
        
        [current.navigationController setViewControllers:vcs animated:YES];
    };
    
    NSString *message = NSLocalizedStringFromTable(@"Your FlashCards++ Subscription has expired. Please renew your Subscription to continue to sync your flash cards with your other iOS devices.", @"Sync", @"");
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@""
                                                    message:message
                                           cancelButtonItem:dontSync
                                           otherButtonItems:subscribe, learnMoreItem, nil];
    
    // only show if the app is in the foreground -- as per http://stackoverflow.com/a/8292048/353137
    // only show once every 24 hours [to stop issue where it pops up **constantly**]
    NSDate *lastPromptRenewSubscriptionForSync = [FlashCardsCore getSettingDate:@"lastPromptRenewSubscriptionForSync"];
    UIApplicationState state = [[UIApplication sharedApplication] applicationState];
    if (state == UIApplicationStateActive && ([lastPromptRenewSubscriptionForSync isEarlierThan:[NSDate dateWithTimeIntervalSinceNow:(60 * 5 * -1)]] || force)) {
        [alert show];
        [FlashCardsCore setSetting:@"lastPromptRenewSubscriptionForSync" value:[NSDate date]];
    }
}

+ (BOOL)canStudyCardsWithUnlimitedCards {
    if (![FlashCardsCore hasFeature:@"UnlimitedCards"]) {
        int numTotalCards = [FlashCardsCore numTotalCards];
        if (numTotalCards > maxCardsLite) {
            // Do something here to alert them that they need to upgrade.
            // Perhaps, won't let them study if they have more than the max number
            // of cards?
            
            RIButtonItem *cancelItem = [RIButtonItem item];
            cancelItem.label = NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"cancelButtonTitle");
            cancelItem.action = ^{
            };
            
            RIButtonItem *loginItem = [RIButtonItem item];
            loginItem.label = NSLocalizedStringFromTable(@"Log In", @"FlashCards", @"");
            loginItem.action = ^{
                AppLoginViewController *vc = [[AppLoginViewController alloc] initWithNibName:@"AppLoginViewController" bundle:nil];
                vc.isCreatingNewAccount = NO;
                UIViewController *currentVC = [FlashCardsCore currentViewController];
                [currentVC.navigationController pushViewController:vc animated:YES];
            };
            
            RIButtonItem *subscribeItem = [RIButtonItem item];
            subscribeItem.label = NSLocalizedStringFromTable(@"Learn About Subscriptions", @"Subscription", @"");
            subscribeItem.action = ^{
                [FlashCardsCore showPurchasePopup:@"UnlimitedCards"];
            };

            RIButtonItem *renewItem = [RIButtonItem item];
            renewItem.label = NSLocalizedStringFromTable(@"Renew Subscription", @"Settings", @"");
            renewItem.action = ^{
                [FlashCardsCore showPurchasePopup:@"UnlimitedCards"];
            };

            NSString *message = [NSString stringWithFormat:NSLocalizedStringFromTable(@"The free version of FlashCards++ has a limit of %d cards. You currently have %d cards total. Because your Subscription has ended and you chose not to renew it, you can view your cards, but at this time you cannot study them. Please delete some cards, renew your Subscription, or Log In to restore your subscription. Thank you for your support. --Jason, Developer of FlashCards++", @"Subscription", @"message"),
                                 maxCardsLite, numTotalCards];
            
            UIAlertView *alert;
            if (![FlashCardsCore isLoggedIn]) {
                alert = [[UIAlertView alloc] initWithTitle:@""
                                                   message:message
                                          cancelButtonItem:cancelItem
                                          otherButtonItems:loginItem, renewItem, subscribeItem, nil];
            } else {
                alert = [[UIAlertView alloc] initWithTitle:@""
                                                   message:message
                                          cancelButtonItem:cancelItem
                                          otherButtonItems:renewItem, subscribeItem, nil];
            }
            [alert show];
            return NO;
        }
    }
    return YES;
}

+ (void)showPurchasePopup:(NSString*)featureName {
    [FlashCardsCore showPurchasePopup:featureName withMessage:@""];
}
+ (void)showPurchasePopup:(NSString *)featureName withMessage:(NSString *)message {
    NSString *myMessage = @"";
    if ([message length] > 0) {
        myMessage = [NSString stringWithString:message];
    } else {
        // Subscribers have access to all of the features of FlashCards++
        if ([featureName isEqualToString:@"TTS"]) {
            myMessage = NSLocalizedStringFromTable(@"The Text-to-Speech function is only available to FlashCards++ Subscribers.", @"Subscription", @"");
        } else if ([featureName isEqualToString:@"UnlimitedCards"]) {
            myMessage = NSLocalizedStringFromTable(@"The free version of FlashCards++ has a limit of 150 cards. You can become a Subscriber for unlimited cards.", @"Subscription", @"");
        } else if ([featureName isEqualToString:@"Photos"]) {
            myMessage = NSLocalizedStringFromTable(@"The free version of FlashCards++ allows you to create cards with text only. To add photos to your cards, you must be a FlashCards++ subscriber.", @"Subscription", @"");
        } else if ([featureName isEqualToString:@"Backup"]) {
            myMessage = NSLocalizedStringFromTable(@"The free version of FlashCards++ allows you to back up your flash card database to Dropbox. However, restoring these backups is a feature reserved for FlashCards++ Subscribers.", @"Subscription", @"");
        } else if ([featureName isEqualToString:@"Audio"]) {
            myMessage = NSLocalizedStringFromTable(@"The free version of FlashCards++ allows you to create cards with text only. To add recorded audio to your cards, you must be a FlashCards++ subscriber.", @"Subscription", @"");
        } else if ([featureName isEqualToString:@"WebsiteSync"]) {
            myMessage = NSLocalizedStringFromTable(@"The free version of FlashCards++ allows you to download cards from Quizlet. FlashCards++ also have the ability to automatically sync your cards with these websites, but this feature is only available to Subscribers.", @"Subscription", @"");
        } else if ([featureName isEqualToString:@"FullscreenStudy"]) {
            myMessage = NSLocalizedStringFromTable(@"Studying in full-screen mode is only available to FlashCards++ Subscribers.", @"Subscription", @"");
        }
    }
    SubscriptionViewController *vc = [[SubscriptionViewController alloc] initWithNibName:@"SubscriptionViewController" bundle:nil];
    vc.giveTrialOption = NO;
    vc.showTrialEndedPopup = NO;
    vc.explainSync = NO;
    if ([myMessage length] > 0) {
        [vc setPopupMessage:[NSString stringWithString:myMessage]];
    }
    if ([featureName isEqualToString:@"UnlimitedCards"]) {
        vc.cancelAlsoCancelsPreviousActivity = YES;
    } else {
        vc.cancelAlsoCancelsPreviousActivity = NO;
    }
    UIViewController *current = [FlashCardsCore currentViewController];
    [current.navigationController pushViewController:vc animated:YES];
}

+ (void)provideComplementarySubscription {
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/user/comp", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    [request prepareCoreDataSyncRequest];
    [request addPostValue:[[UIDevice currentDevice] uniqueDeviceIdentifier] forKey:@"device_id"];
    [request addPostValue:[[UIDevice currentDevice] advertisingIdentifier] forKey:@"device_adid"];
    [request setCompletionBlock:^{
        // NSLog(@"%@", request.responseString);
        [FlashCardsCore checkLoginAndPerformBlock:^{
            if (![FlashCardsCore isLoggedIn]) {
                // prompt them to create an account:
                UIViewController *current = [FlashCardsCore currentViewController];
                AppLoginViewController *vc = [[AppLoginViewController alloc] initWithNibName:@"AppLoginViewController" bundle:nil];
                vc.isCreatingNewAccount = YES;
                [current.navigationController pushViewController:vc animated:YES];
            }
            FCDisplayBasicErrorMessage(@"",
                                       NSLocalizedStringFromTable(@"Thank you! You now have a 1 month complementary Subscription.", @"Flashcards", @""));
        }];
    }];
    [request setFailedBlock:^{}];
    [request startAsynchronous];
}

+ (BOOL)hasSubscription {
    return [FlashCardsCore getSettingBool:@"hasSubscription"];
}

+ (void)updateHasUsedOneTimeOfflineTTSTrial {
    if ([FlashCardsCore getSettingBool:@"currentlyUsingOneTimeOfflineTTSTrial"]) {
        [FlashCardsCore setHasUsedOneTimeOfflineTTSTrial];
        [FlashCardsCore setSetting:@"currentlyUsingOneTimeOfflineTTSTrial" value:@NO];
    }
}

+ (void)setHasUsedOneTimeOfflineTTSTrial {
    [STKeychain storeUsername:@"hasUsedOneTimeOfflineTTSTrial" andPassword:@"YES" forServiceName:@"FlashCardsPlusPlus" updateExisting:YES error:nil];
    [FlashCardsCore setSetting:@"hasUsedOneTimeOfflineTTSTrial" value:@YES];
}

+ (BOOL)hasUsedOneTimeOfflineTTSTrial {
    NSString *hasUsedOneTimeOfflineTTSTrial = [STKeychain getPasswordForUsername:@"hasUsedOneTimeOfflineTTSTrial" andServiceName:@"FlashCardsPlusPlus" error:nil];
    BOOL hasUsedOneTimeOfflineTTSTrialKeychain = NO;
    if (hasUsedOneTimeOfflineTTSTrial) {
        hasUsedOneTimeOfflineTTSTrialKeychain = YES;
    }
    if (![FlashCardsCore getSettingBool:@"hasUsedOneTimeOfflineTTSTrial"] && !hasUsedOneTimeOfflineTTSTrialKeychain) {
        return NO;
    }
    return YES;
}

+ (BOOL)currentlyUsingOneTimeOfflineTTSTrial {
    if (![FlashCardsCore getSettingBool:@"currentlyUsingOneTimeOfflineTTSTrial"]) {
        return NO;
    }
    if (![FlashCardsCore hasUsedOneTimeOfflineTTSTrial]) {
        // only say YES, if the user is currently using it, and has not previously used it
        return YES;
    }
    // if they currently using one time trial, but have used it, then say NO
    return NO;
}

# pragma mark - Random methods

// An easy way to clear out all of the settings related to restoring where we were after authentication left the app:
+ (void) resetAllRestoreProcessSettings {
    [FlashCardsCore setSetting:@"importProcessRestore" value:@NO];
    [FlashCardsCore setSetting:@"uploadProcessRestore" value:@NO];
    [FlashCardsCore setSetting:@"importProcessRestoreCollectionId" value:@""];
    [FlashCardsCore setSetting:@"importProcessRestoreCardsetId" value:@""];
    [FlashCardsCore setSetting:@"importProcessRestoreGroupId" value:[NSNumber numberWithInt:-1]];
    [FlashCardsCore setSetting:@"importProcessRestoreSearchTerm" value:@""];
    [FlashCardsCore setSetting:@"importProcessRestoreChoiceViewController" value:@""];
}

+ (NSString*) randomStringOfLength:(int)length {
    /*
     As per:
     http://iphonedevelopertips.com/general/create-a-universally-unique-identifier-uuid.html
     http://stackoverflow.com/questions/2633801/generate-a-random-alphanumeric-string-in-cocoa
    */
    
    NSString *letters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    NSMutableString *secondaryKey = [NSMutableString stringWithCapacity:length];
    for (int i=0; i<length; i++) {
        [secondaryKey appendFormat: @"%c", [letters characterAtIndex: rand()%[letters length]]];
    }
    return [NSString stringWithString:secondaryKey];
}

+ (BOOL) isConnectedToInternet {
    Reachability *internetReach = ((FlashCardsAppDelegate*)[[UIApplication sharedApplication] delegate]).internetReach;
    NetworkStatus netStatus = [internetReach currentReachabilityStatus];
    if (netStatus == NotReachable) {
        return NO;
    }
    return YES;
}

+ (BOOL) isConnectedToWifi {
    Reachability *internetReach = ((FlashCardsAppDelegate*)[[UIApplication sharedApplication] delegate]).internetReach;
    NetworkStatus netStatus = [internetReach currentReachabilityStatus];
    if (netStatus == ReachableViaWiFi) {
        return YES;
    }
    return NO;
}

// saves the information on how to restore the import process when we return from the web browser:
+ (void)saveImportProcessRestoreDataWithVCChoice:(NSString*)vcChoice andCollection:(FCCollection*)collection andCardSet:(FCCardSet*)cardSet {
    [FlashCardsCore resetAllRestoreProcessSettings];
    [FlashCardsCore setSetting:@"importProcessRestore" value:@YES];
    if (collection != nil) {
        [FlashCardsCore setSetting:@"importProcessRestoreCollectionId" value:[[[collection objectID] URIRepresentation] absoluteString]];
    }
    if (cardSet != nil) {
        [FlashCardsCore setSetting:@"importProcessRestoreCardsetId" value:[[[cardSet objectID] URIRepresentation] absoluteString]];
        [FlashCardsCore setSetting:@"importProcessRestoreCollectionId" value:[[[cardSet.collection objectID] URIRepresentation] absoluteString]];
    }
    [FlashCardsCore setSetting:@"importProcessRestoreChoiceViewController" value:vcChoice];
}

+ (int) numberCollectionsInManagedContext:(NSManagedObjectContext*)managedObjectContext {
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:[NSEntityDescription entityForName:@"Collection" inManagedObjectContext:managedObjectContext]];
    NSArray *collections = [managedObjectContext executeFetchRequest:fetchRequest error:nil];
    return [collections count];
}

+ (NSString*) documentsDirectory {
    NSString *applicationDocumentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    return applicationDocumentsDirectory;
}

+ (FlashCardsAppDelegate*)appDelegate {
   return (FlashCardsAppDelegate *)[[UIApplication sharedApplication] delegate];
}

# pragma mark - Core Data Stack

+ (NSManagedObjectContext*)writerMOC {
    return [[FlashCardsCore appDelegate] writerMOC];
}
+ (NSManagedObjectContext*)mainMOC {
    return [[FlashCardsCore appDelegate] mainMOC];
}
+ (NSManagedObjectContext*)tempMOC {
    NSManagedObjectContext *moc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    [moc setParentContext:[FlashCardsCore mainMOC]];
    [moc setUndoManager:nil];
    return moc;
}

+ (void)saveMainMOC {
    [FlashCardsCore saveMainMOC:NO];
}
+ (void)saveMainMOC:(BOOL)wait {
    [FlashCardsCore saveMainMOC:wait andRunSelector:nil onDelegate:nil onMainThread:YES];
}

+ (void)saveMainMOC:(BOOL)wait andRunSelector:(SEL)selector onDelegate:(NSObject*)delegate onMainThread:(BOOL)onMainThread {
    NSManagedObjectContext *writerMOC = [FlashCardsCore writerMOC];
    NSManagedObjectContext *mainMOC = [FlashCardsCore mainMOC];
    if ([mainMOC hasChanges]) {
        [mainMOC performBlockAndWait:^{
            NSError *error;
            if (![mainMOC save:&error]) {
                FCLog(@"Error saving main MOC: %@", error);
                FCDisplayBasicErrorMessage(@"Error saving",
                                           [NSString stringWithFormat:@"Error saving [main]: %@", error]);
            }
        }];
    }
    
    void (^runSelector) (void) = ^{
        if (!delegate || !selector) {
            return;
        }
        if ([delegate respondsToSelector:selector]) {
            if (onMainThread) {
                [delegate performSelectorOnMainThread:selector withObject:nil waitUntilDone:NO];
            } else {
                [delegate performSelectorInBackground:selector withObject:nil];
            }
        }
    };
    
    
    void (^saveWriter) (void) = ^{
        NSError *error2;
        if (![writerMOC save:&error2]) {
            FCLog(@"Error saving writer MOC: %@", error2);
            FCDisplayBasicErrorMessage(@"Error saving",
                                       [NSString stringWithFormat:@"Error saving [writer]: %@", error2]);
        }
        runSelector();
    };

    if ([writerMOC hasChanges]) {
        if (wait) {
            [writerMOC performBlockAndWait:saveWriter];
        } else {
            [writerMOC performBlock:saveWriter];
        }
    } else {
        runSelector();
    }
}

# pragma mark - Other

+ (BOOL)isLoggedIn {
    BOOL loggedIn = [FlashCardsCore getSettingBool:@"fcppIsLoggedIn"];
    NSString *loginKey = (NSString*)[FlashCardsCore getSetting:@"fcppLoginKey"];
    return (loggedIn && [loginKey length] > 0);
}

+ (void)login:(NSDictionary*)response {
    [FlashCardsCore setSetting:@"fcppIsLoggedIn" value:@YES];
    [FlashCardsCore setSetting:@"fcppUsername" value:[response objectForKey:@"email"]];
    [FlashCardsCore setSetting:@"fcppLoginKey" value:[response objectForKey:@"login_key"]];
    int endDateI = [(NSNumber*)[response objectForKey:@"subscription_ends"] intValue];
    NSDate *endDate = [NSDate dateWithTimeIntervalSince1970:endDateI];
    // if the subscription end date is ealier than now:
    if ([endDate isEarlierThan:[NSDate date]]) {
        [FlashCardsCore setSetting:@"hasSubscription" value:@NO];
        [FlashCardsCore setSetting:@"hasSubscriptionLifetime" value:@NO];
    } else {
        [FlashCardsCore setSetting:@"hasSubscription" value:@YES];
        int hasLifetime = [(NSNumber*)[response objectForKey:@"has_lifetime"] intValue];
        if (hasLifetime == 1) {
            [FlashCardsCore setSetting:@"hasSubscriptionLifetime" value:@YES];
        } else {
            [FlashCardsCore setSetting:@"hasSubscriptionLifetime" value:@NO];
        }
    }
    [FlashCardsCore setSetting:@"subscriptionEndDate" value:endDate];
    [FlashCardsCore setSetting:@"fcppLoginNumberDevices" value:[response objectForKey:@"number_devices"]];
}

+ (void)logout {
    [FlashCardsCore setSetting:@"fcppIsLoggedIn" value:@NO];
    [FlashCardsCore setSetting:@"fcppUsername" value:@""];
    [FlashCardsCore setSetting:@"fcppLoginKey" value:@""];
    [FlashCardsCore setSetting:@"fcppLoginNumberDevices" value:@0];
    [FlashCardsCore setSetting:@"appIsSyncing" value:@NO];
    
    [FlashCardsCore setSetting:@"hasSubscription" value:@NO];
    [FlashCardsCore setSetting:@"hasSubscriptionLifetime" value:@NO];
    
    [FlashCardsCore setSetting:@"subscriptionEndDate" value:[NSDate date]];
}

+ (void)checkLogin {
    [FlashCardsCore checkLoginAndPerformBlock:nil];
}
+ (void)checkLoginAndPerformBlock:(ASIBasicBlock)block {
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/user/check", flashcardsServer]];
    ASIFormDataRequest *request = [[ASIFormDataRequest alloc] initWithURL:url];
    __block ASIFormDataRequest *requestBlock = request;
    [request setupFlashCardsAuthentication:@"user/check"];
    if ([FlashCardsCore isLoggedIn]) {
        [request addPostValue:[FlashCardsCore getSetting:@"fcppUsername"] forKey:@"email"];
        [request addPostValue:[FlashCardsCore getSetting:@"fcppLoginKey"] forKey:@"login_key"];
        [request addPostValue:[[UIDevice currentDevice] uniqueDeviceIdentifier] forKey:@"device_id"];
        [request addPostValue:[[UIDevice currentDevice] advertisingIdentifier] forKey:@"device_adid"];
    } else {
        [request addPostValue:[[UIDevice currentDevice] uniqueDeviceIdentifier] forKey:@"device_id"];
        [request addPostValue:[[UIDevice currentDevice] advertisingIdentifier] forKey:@"device_adid"];
    }
    [request addPostValue:[NSNumber numberWithInt:[FlashCardsCore numTotalCards]] forKey:@"num"];
    NSString *firstVersionInstalled = (NSString*)[FlashCardsCore getSetting:@"firstVersionInstalled"];
    [request addPostValue:firstVersionInstalled forKey:@"version"];

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    double date = [defaults doubleForKey:@"kAppiraterFirstUseDate"];
    NSNumber *dateDouble = [NSNumber numberWithDouble:date];
    [request addPostValue:[NSNumber numberWithInt:[dateDouble intValue]] forKey:@"initial_date"]; // first date app was run
    [request addPostValue:[NSNumber numberWithBool:[QuizletSync needsToSyncInMOC:[FlashCardsCore mainMOC]]]
                   forKey:@"quizlet"];
    [request addPostValue:[NSNumber numberWithBool:FALSE]
                   forKey:@"fce"];
    
    
    NSString *callKey = [FlashCardsCore randomStringOfLength:20];
    FCLog(@"Call Key: %@", callKey);
    
    /*
    NSData *callKeyData = [callKey dataUsingEncoding:NSUTF8StringEncoding];
    NSData *keyCallKey = [NSData dataWithBytes:[[flashcardsServerCallKeyEncryptionKey sha256] bytes] length:kCCKeySizeAES128];
    NSData *encryptedCallKey = [callKeyData aesEncryptedDataWithKey:keyCallKey];
    */
    [request addPostValue:[callKey encryptWithKey:flashcardsServerCallKeyEncryptionKey] forKey:@"call"];
    
    [request setCompletionBlock:^{
        BOOL hasShownPopup = NO;
        FCLog(@"%@", requestBlock.responseString);
        NSDictionary *response = [requestBlock.responseData objectFromJSONData];
        NSString *responseKey = [response objectForKey:@"response"];
        NSString *doubledCallKey = [NSString stringWithFormat:@"%@%@", callKey, callKey];
        // compare the response key to the call key. It should be an MD5 hash of hte call key
        // which was appended to itself. This is how we know that we actually communicated with
        // the proper server.
        if (![responseKey isEqualToString:[doubledCallKey md5]]) {
            return;
        }
        BOOL isHacker = [(NSNumber*)[response objectForKey:@"is_hacker"] boolValue];
        if (isHacker) {
            NSString *email = [NSString stringWithString:[response objectForKey:@"email"]];
            if ([email length] > 0) {
                [FlashCardsCore setSetting:@"hasSubscription" value:@NO];
                [FlashCardsCore setSetting:@"hasSubscriptionLifetime" value:@NO];
                FCDisplayBasicErrorMessage(@"", @"Thank you for your interest in FlashCards++, but it seems that you have submitted an in-app purchase receipt associated with iOS piracy. I hope that you consider actually paying for it. I spend a lot of time making tihs app for paying customers. I'm not a faceless corporation but a real person trying to make a living. --Jason, FlashCards++ developer");
            } else {
                UIViewController *current = [FlashCardsCore currentViewController];
                AppLoginViewController *vc = [[AppLoginViewController alloc] initWithNibName:@"AppLoginViewController" bundle:nil];
                vc.isCreatingNewAccount = YES;
                [current.navigationController pushViewController:vc animated:YES];
            }
            return;
        }
        if ([[response objectForKey:@"is_logged_in"] boolValue]) {
            NSString *email = [NSString stringWithString:[response objectForKey:@"email"]];
            if ([email length] > 0) {
                [FlashCardsCore setSetting:@"fcppIsLoggedIn" value:@YES];
            } else {
                [FlashCardsCore setSetting:@"fcppIsLoggedIn" value:@NO];
            }
            [FlashCardsCore setSetting:@"hasSubscription" value:[response objectForKey:@"has_subscription"]];
            int endDateI = [(NSNumber*)[response objectForKey:@"subscription_ends"] intValue];
            NSDate *endDate = [NSDate dateWithTimeIntervalSince1970:endDateI];
            // if the subscription end date is earlier than now:
            if ([endDate isEarlierThan:[NSDate date]]) {
                [FlashCardsCore setSetting:@"hasSubscription" value:@NO];
                [FlashCardsCore setSetting:@"hasSubscriptionLifetime" value:@NO];
            } else {
                [FlashCardsCore setSetting:@"hasSubscription" value:@YES];
                int hasLifetime = [(NSNumber*)[response objectForKey:@"has_lifetime"] intValue];
                if (hasLifetime == 1) {
                    [FlashCardsCore setSetting:@"hasSubscriptionLifetime" value:@YES];
                } else {
                    [FlashCardsCore setSetting:@"hasSubscriptionLifetime" value:@NO];
                }
            }
            if ([FlashCardsCore getSettingBool:@"hasSubscription"]) {
                [FlashCardsCore setSetting:@"hasEverHadASubscription" value:@YES];
                BOOL isTeacher = [(NSNumber*)[response objectForKey:@"is_teacher"] boolValue];
                if (![FlashCardsCore getSettingBool:@"hasSubscriptionLifetime"]) {
                    isTeacher = NO;
                }
                [FlashCardsCore setSetting:@"isTeacher" value:[NSNumber numberWithBool:isTeacher]];
                if (isTeacher) {
                    [FlashCardsCore setSetting:@"studentSubscriptionsTotal" value:[response objectForKey:@"max_subscriptions"]];
                    [FlashCardsCore setSetting:@"studentSubscriptionsAllocated" value:[response objectForKey:@"allocated_subscriptions"]];;
                } else {
                    [FlashCardsCore setSetting:@"studentSubscriptionsTotal" value:@0];
                    [FlashCardsCore setSetting:@"studentSubscriptionsAllocated" value:@0];
                }
            }
            if ([FlashCardsCore getSettingBool:@"hasEverHadASubscription"] && ![FlashCardsCore hasSubscription]) {
                UIViewController *currentVC = [FlashCardsCore currentViewController];
                if ([currentVC isKindOfClass:[RootViewController class]]) {
                    RootViewController *root = (RootViewController*)currentVC;
                    NSString *message = NSLocalizedStringFromTable(@"Renew Subscription", @"Settings", @"");
                    UIButton *automaticallySyncButton = [root automaticallySyncButton];
                    [automaticallySyncButton setTitle:message forState:UIControlStateNormal];
                    [automaticallySyncButton setTitle:message forState:UIControlStateSelected];
                }
            }

            [FlashCardsCore setSetting:@"subscriptionEndDate" value:endDate];
            [FlashCardsCore setSetting:@"fcppLoginNumberDevices" value:[response objectForKey:@"number_devices"]];
            [FlashCardsCore setSetting:@"fcppUsername" value:[response objectForKey:@"email"]];
            if ([FlashCardsCore appIsSyncing]) {
                if (![[response objectForKey:@"flashcard_exchange_last_sync"] isKindOfClass:[NSNull class]]) {
                    int fceSyncI = [[response objectForKey:@"flashcard_exchange_last_sync"] intValue];
                    if (fceSyncI > 0) {
                        NSDate *fceSync = [NSDate dateWithTimeIntervalSince1970:fceSyncI];
                        [FlashCardsCore setSetting:@"flashcardExchangeLastSyncAllData" value:fceSync];
                    }
                }
                
                if (![[response objectForKey:@"sync_last_upload_database"] isKindOfClass:[NSNull class]]) {
                    int qSyncI   = [[response objectForKey:@"sync_last_upload_database"] intValue];
                    if (qSyncI > 0) {
                        NSDate *qSync = [NSDate dateWithTimeIntervalSince1970:qSyncI];
                        [FlashCardsCore setSetting:@"lastUploadedWholeStore" value:qSync];
                    }
                }
                if (![[response objectForKey:@"sync_last_upload_database_prompt"] isKindOfClass:[NSNull class]]) {
                    int qSyncI   = [[response objectForKey:@"sync_last_upload_database_prompt"] intValue];
                    if (qSyncI > 0) {
                        NSDate *qSync = [NSDate dateWithTimeIntervalSince1970:qSyncI];
                        [FlashCardsCore setSetting:@"lastUploadedWholeStoreRemindDate" value:qSync];
                    }
                }
                if (![[response objectForKey:@"sync_last_upload_database_wait"] isKindOfClass:[NSNull class]]) {
                    int qSyncI   = [[response objectForKey:@"sync_last_upload_database_wait"] intValue];
                    if (qSyncI > 0) {
                        [FlashCardsCore setSetting:@"lastUploadedWholeStoreRemindWait" value:[NSNumber numberWithInt:qSyncI]];
                    }
                }
                if (![[response objectForKey:@"quizlet_last_sync"] isKindOfClass:[NSNull class]]) {
                    int qSyncI   = [[response objectForKey:@"quizlet_last_sync"] intValue];
                    if (qSyncI > 0) {
                        NSDate *qSync = [NSDate dateWithTimeIntervalSince1970:qSyncI];
                        [FlashCardsCore setSetting:@"quizletLastSyncAllData" value:qSync];
                    }
                }
                if (![[response objectForKey:@"sync_last_sync"] isKindOfClass:[NSNull class]]) {
                    int fcppSyncI   = [[response objectForKey:@"sync_last_sync"] intValue];
                    if (fcppSyncI > 0) {
                        NSDate *fcppSync = [NSDate dateWithTimeIntervalSince1970:fcppSyncI];
                        [FlashCardsCore setSetting:@"remoteLastSyncAllData" value:fcppSync];
                    }
                }
            }
        } else {
            [FlashCardsCore setSetting:@"fcppIsLoggedIn" value:@NO];
            [FlashCardsCore setSetting:@"hasSubscription" value:@NO];
        }
        UIViewController *vc = [FlashCardsCore currentViewController];
        if ([vc isKindOfClass:[SettingsStudyViewController class]]) {
            SettingsStudyViewController *studyVC = (SettingsStudyViewController*)vc;
            [studyVC.myTableView reloadData];
        }
        
        if ([FlashCardsCore appIsSyncingNoSubscription] && ![FlashCardsCore hasSubscription]) {
            hasShownPopup = YES;
            [FlashCardsCore showSubscriptionEndedPopup:NO];
        } else {
            // if canStudyCardsWithUnlimitedCards = YES, then hasShownPopup = NO
            // if canStudyCardsWithUnlimitedCards = NO, then hasShownPopup = YES
            hasShownPopup = ![FlashCardsCore canStudyCardsWithUnlimitedCards];
        }
        if ([FlashCardsCore hasSubscription] && [FlashCardsCore appIsSyncing] && !hasShownPopup) {
            BOOL isSyncing = NO;
            // If the app should sync, check if it has ever done a sync. If not, then force it to sync to get everything up to date
            BOOL hasExecutedFirstSync = [FlashCardsCore getSettingBool:@"hasExecutedFirstSync"];
            if (!hasExecutedFirstSync) {
                if ([[[FlashCardsCore appDelegate] syncController] documentSyncManager] &&
                    [[[[FlashCardsCore appDelegate] syncController] documentSyncManager] state] == TICDSDocumentSyncManagerStateAbleToSync &&
                    ![[[FlashCardsCore appDelegate] syncController] isCurrentlySyncing]
                    ) {
                    UIViewController *vc = [FlashCardsCore currentViewController];
                    if ([FlashCardsCore canShowSyncHUD:vc]) {
                        FCLog(@"Beginning INITIAL sync now");
                        isSyncing = YES;
                        hasShownPopup = YES;
                        [FlashCardsCore showSyncHUD];
                        [[[FlashCardsCore appDelegate] syncController] setDelegate:vc];
                        [[[FlashCardsCore appDelegate] syncController] sync];
                    }
                }
            }
            NSDate *lastSyncAllData = [FlashCardsCore getSettingDate:@"lastSyncAllData"];
            NSDate *remoteLastSyncAllData = [FlashCardsCore getSettingDate:@"remoteLastSyncAllData"];
            if (hasExecutedFirstSync && lastSyncAllData && remoteLastSyncAllData) {
                // if (lastSyncAllData < remoteLastSyncAllData)
                if ([lastSyncAllData isEarlierThan:remoteLastSyncAllData] &&
                    [[[FlashCardsCore appDelegate] syncController] documentSyncManager] &&
                    [[[[FlashCardsCore appDelegate] syncController] documentSyncManager] state] == TICDSDocumentSyncManagerStateAbleToSync &&
                    ![[[FlashCardsCore appDelegate] syncController] isCurrentlySyncing]
                    ) {
                    UIViewController *vc = [FlashCardsCore currentViewController];
                    if ([FlashCardsCore canShowSyncHUD:vc]) {
                        FCLog(@"Beginning sync now");
                        isSyncing = YES;
                        [FlashCardsCore showSyncHUD];
                        [[[FlashCardsCore appDelegate] syncController] setDelegate:vc];
                        [[[FlashCardsCore appDelegate] syncController] sync];
                    }
                }
            }
            if (!isSyncing) {
                // if it's been 15 days since the last upload, ask them to upload a data store file:
                NSDate *lastUploadedWholeStore = [FlashCardsCore getSettingDate:@"lastUploadedWholeStore"];
                BOOL shouldPromptToUpload = NO;
                if (!lastUploadedWholeStore) {
                    shouldPromptToUpload = YES;
                } else {
                    int interval = [lastUploadedWholeStore timeIntervalSinceNow];
                    if (interval < 0) {
                        interval *= -1;
                    }

                    // check if the last time a person was reminded to do this was 3 days ago or more
                    int lastUploadedWholeStoreRemindWait = [FlashCardsCore getSettingInt:@"lastUploadedWholeStoreRemindWait"];
                    NSDate *lastUploadedWholeStoreRemindDate = [FlashCardsCore getSettingDate:@"lastUploadedWholeStoreRemindDate"];
                    BOOL needsToRemind = NO;
                    if (!lastUploadedWholeStoreRemindDate) {
                        needsToRemind = YES;
                    } else {
                        int remindInterval = [lastUploadedWholeStoreRemindDate timeIntervalSinceNow];
                        if (remindInterval < 0) {
                            remindInterval *= -1;
                        }
                        if (remindInterval > lastUploadedWholeStoreRemindWait) {
                            needsToRemind = YES;
                        }
                    }
                    
                    if (interval > 60 * 60 * 24 * 15 && needsToRemind) {
                        shouldPromptToUpload = YES;
                    }
                }
                if (shouldPromptToUpload) {
                    [FlashCardsCore setSetting:@"lastUploadedWholeStoreRemindDate" value:[NSDate date]];
                    
                    RIButtonItem *remindLater = [RIButtonItem item];
                    remindLater.label = NSLocalizedStringFromTable(@"Remind me later", @"Apirater", @"");
                    remindLater.action = ^{
                        ActionStringCancelBlock cancel = ^(ActionSheetStringPicker *picker) {
                            [FlashCardsCore setSetting:@"lastUploadedWholeStoreRemindWait"
                                                 value:[NSNumber numberWithInt:(60 * 60 * 24 * 3)]];
                            [FlashCardsCore uploadLastSyncDates];
                        };
                        NSMutableArray *options = [NSMutableArray arrayWithCapacity:0];
                        NSMutableArray *optionsNumbers = [NSMutableArray arrayWithCapacity:0];
                        
                        [options addObject:NSLocalizedStringFromTable(@"3 Days", @"Sync", @"")];
                        [optionsNumbers addObject:[NSNumber numberWithInt:(60 * 60 * 24 * 3)]];
                        
                        [options addObject:NSLocalizedStringFromTable(@"7 Days", @"Sync", @"")];
                        [optionsNumbers addObject:[NSNumber numberWithInt:(60 * 60 * 24 * 7)]];

                        [options addObject:NSLocalizedStringFromTable(@"30 Days", @"Sync", @"")];
                        [optionsNumbers addObject:[NSNumber numberWithInt:(60 * 60 * 24 * 30)]];

                        ActionStringDoneBlock done = ^(ActionSheetStringPicker *picker, NSInteger selectedIndex, id selectedValue) {
                            NSNumber *num = [optionsNumbers objectAtIndex:selectedIndex];
                            [FlashCardsCore setSetting:@"lastUploadedWholeStoreRemindWait"
                                                 value:num];
                            [FlashCardsCore uploadLastSyncDates];
                        };
                        
                        UIViewController *current = [FlashCardsCore currentViewController];
                        [ActionSheetStringPicker showPickerWithTitle:NSLocalizedStringFromTable(@"Remind Me In...", @"Sync", @"")
                                                                rows:options
                                                    initialSelection:0
                                                           doneBlock:done
                                                         cancelBlock:cancel
                                                              origin:current.navigationItem.leftBarButtonItem];
                    };

                    RIButtonItem *learnMoreItem = [RIButtonItem item];
                    learnMoreItem.label = NSLocalizedStringFromTable(@"Learn More", @"Sync", @"");
                    learnMoreItem.action = ^{
                        UIViewController *current = [FlashCardsCore currentViewController];
                        HelpViewController *helpVC = [[HelpViewController alloc] initWithNibName:@"HelpViewController" bundle:nil];
                        
                        helpVC.title = NSLocalizedStringFromTable(@"Learn More", @"Sync", @"");
                        helpVC.helpText = NSLocalizedStringFromTable(@"LearnMoreUploadDatabase", @"Help", @"");
                        
                        // Pass the selected object to the new view controller.
                        [current.navigationController pushViewController:helpVC animated:YES];

                    };

                    RIButtonItem *upload = [RIButtonItem item];
                    upload.label = NSLocalizedStringFromTable(@"Upload Database Now", @"Backup", @"");
                    upload.action = ^{
                        SyncController *controller = [[FlashCardsCore appDelegate] syncController];
                        [controller setQuizletDidChange:NO];
                        [controller setUploadStoreAfterRegistering:YES];
                        [controller setDownloadStoreAfterRegistering:NO];
                        [controller setIsCurrentlyUploading:YES];
                        [controller setIsCurrentlyUploadingForFirstTime:NO];

                        UIViewController *vc = [FlashCardsCore currentViewController];
                        MBProgressHUD *HUD;
                        if ([vc respondsToSelector:@selector(syncHUD)]) {
                            HUD = [vc valueForKey:@"syncHUD"];
                            if (!HUD && [vc respondsToSelector:@selector(createSyncHUD)]) {
                                [vc performSelectorOnMainThread:@selector(createSyncHUD) withObject:nil waitUntilDone:YES];
                                HUD = [vc valueForKey:@"syncHUD"];
                            }
                        }
                        if (!HUD) {
                            HUD = [FlashCardsCore currentHUD:@"syncHUD"];
                        }

                        [controller.documentSyncManager initiateUploadOfWholeStore];
                        
                    };
                    
                    NSString *lastUploadedDatabaseDate;
                    if (lastUploadedWholeStore) {
                        // as per: http://stackoverflow.com/a/5189395/353137
                        NSString *datePart = [NSDateFormatter localizedStringFromDate: lastUploadedWholeStore
                                                                            dateStyle: NSDateFormatterShortStyle
                                                                            timeStyle: NSDateFormatterNoStyle];

                        lastUploadedDatabaseDate = [NSString stringWithFormat:@"You last uploaded your flash card database to the sync server on %@.",
                                                    datePart
                                                    ];
                    } else {
                        lastUploadedDatabaseDate = NSLocalizedStringFromTable(@"You last uploaded your flash card database to the sync server a while ago.", @"Sync", @"");
                    }
                    NSString *message = [NSString stringWithFormat:NSLocalizedStringFromTable(@"%@ Would you like to upload a new copy? It will speed up sync and serve as a backup.", @"Sync", @""),
                                         lastUploadedDatabaseDate
                                         ];
                    
                    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@""
                                                                    message:message
                                                           cancelButtonItem:remindLater
                                                           otherButtonItems:upload, learnMoreItem, nil];
                    [alert show];
                    hasShownPopup = YES;
                }
            }
        }
        if (![FlashCardsCore isLoggedIn] && [FlashCardsCore hasSubscription] && !hasShownPopup) {
            // if it's past the time to prompt to create an account:
            NSDate *promptCreateAccount = [FlashCardsCore getSettingDate:@"promptCreateAccount"];
            // if the current date is later than promptCreateAccount
            if ([promptCreateAccount isEarlierThan:[NSDate date]]) {
                UIViewController *vc = [FlashCardsCore currentViewController];
                if ([vc isKindOfClass:[RootViewController class]]) {
                    RootViewController *rootVC = (RootViewController*)vc;
                    if (!rootVC.hasPromptedCreateAccount) {
                        // if the user has a subscription and is not logged in, and
                        // no popup has yet been shown, and they are in the root VC,
                        // and they haven't been prompted to set up their login, THEN:
                        // prompt the user to set up their login
                        
                        
                        RIButtonItem *remindLater = [RIButtonItem item];
                        remindLater.label = NSLocalizedStringFromTable(@"Remind me later", @"Apirater", @"");
                        remindLater.action = ^{
                            ActionStringCancelBlock cancel = ^(ActionSheetStringPicker *picker) {
                                [FlashCardsCore setSetting:@"promptCreateAccount"
                                                     value:[NSDate dateWithTimeIntervalSinceNow:(60 * 60 * 24 * 3)]];
                            };
                            NSMutableArray *options = [NSMutableArray arrayWithCapacity:0];
                            NSMutableArray *optionsNumbers = [NSMutableArray arrayWithCapacity:0];
                            
                            [options addObject:NSLocalizedStringFromTable(@"3 Days", @"Sync", @"")];
                            [optionsNumbers addObject:[NSNumber numberWithInt:(60 * 60 * 24 * 3)]];
                            
                            [options addObject:NSLocalizedStringFromTable(@"7 Days", @"Sync", @"")];
                            [optionsNumbers addObject:[NSNumber numberWithInt:(60 * 60 * 24 * 7)]];
                            
                            [options addObject:NSLocalizedStringFromTable(@"30 Days", @"Sync", @"")];
                            [optionsNumbers addObject:[NSNumber numberWithInt:(60 * 60 * 24 * 30)]];
                            
                            ActionStringDoneBlock done = ^(ActionSheetStringPicker *picker, NSInteger selectedIndex, id selectedValue) {
                                NSNumber *num = [optionsNumbers objectAtIndex:selectedIndex];
                                [FlashCardsCore setSetting:@"promptCreateAccount"
                                                     value:[NSDate dateWithTimeIntervalSinceNow:[num intValue]]];
                            };
                            
                            UIViewController *current = [FlashCardsCore currentViewController];
                            [ActionSheetStringPicker showPickerWithTitle:NSLocalizedStringFromTable(@"Remind Me In...", @"Sync", @"")
                                                                    rows:options
                                                        initialSelection:0
                                                               doneBlock:done
                                                             cancelBlock:cancel
                                                                  origin:current.navigationItem.leftBarButtonItem];
                        };
                        
                        RIButtonItem *loginItem = [RIButtonItem item];
                        loginItem.label = NSLocalizedStringFromTable(@"Create Account", @"Subscription", @"");
                        loginItem.action = ^{
                            UIViewController *current = [FlashCardsCore currentViewController];
                            AppLoginViewController *vc = [[AppLoginViewController alloc] initWithNibName:@"AppLoginViewController" bundle:nil];
                            vc.isCreatingNewAccount = YES;
                            [current.navigationController pushViewController:vc animated:YES];
                        };
                        
                        RIButtonItem *cancel = [RIButtonItem item];
                        cancel.label = NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"");
                        cancel.action = ^{
                        };
                        
                        NSString *message = NSLocalizedStringFromTable(@"You have a FlashCards++ Subscription but have not yet created an account. By creating an account, you will be able to use your FlashCards++ subscription on your other iOS devices. Even if you only have one iOS device, creating an account will ensure that you can restore your purchase if you ever delete or re-install FlashCards++.", @"Subscription", @"");
                        
                        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@""
                                                                        message:message
                                                               cancelButtonItem:cancel
                                                               otherButtonItems:loginItem, remindLater, nil];
                        [alert show];
                        hasShownPopup = YES;
                        rootVC.hasPromptedCreateAccount = YES;
                    }
                }
            }
        }
        // if they haven't been shown a popup yet, and the subscription will be running out within
        // two weeks, remind them!!
        if ([FlashCardsCore hasSubscription] && !hasShownPopup && [FlashCardsCore isConnectedToInternet]) {
            NSDate *expiration = [FlashCardsCore getSettingDate:@"subscriptionEndDate"];
            // find out if the subscription will run out within two weeks.
            NSDate *dateInTwoWeeks = [NSDate dateWithTimeIntervalSinceNow:(60 * 60 * 24 * 14)];
            // IF the subscription will run out within two weeks, then we should show them a popup:
            if ([expiration isEarlierThan:dateInTwoWeeks]) {
                NSDate *promptRenewSubscription = [FlashCardsCore getSettingDate:@"promptRenewSubscription"];

                // IF the prompt renew date is earlier than the current date, then show them the popup:
                // if the current date is later than the date to prompt renewing subscription:
                if ([promptRenewSubscription isEarlierThan:[NSDate date]]) {
                    // a popup explains that their subscription will run out [and potentially
                    // that the automatic sync will stop working or they won't be able to study their
                    // cards].
                    // Options:
                    // Cancel [shows another popup -- why don't you want to renew? Goal is to get them to say why they aren't renewing]
                    // Remind Me Later [reminds later]
                    // Renew Subscription

                
                    RIButtonItem *remindLater = [RIButtonItem item];
                    remindLater.label = NSLocalizedStringFromTable(@"Remind me later", @"Apirater", @"");
                    remindLater.action = ^{
                        [FlashCardsCore setSetting:@"promptRenewSubscription"
                                             value:[NSDate dateWithTimeIntervalSinceNow:(60 * 60 * 24 * 2)]];
                    };
                    
                    RIButtonItem *renewItem = [RIButtonItem item];
                    renewItem.label = NSLocalizedStringFromTable(@"Renew Subscription", @"Settings", @"");
                    renewItem.action = ^{
                        SubscriptionViewController *vc = [[SubscriptionViewController alloc] initWithNibName:@"SubscriptionViewController" bundle:nil];
                        vc.showTrialEndedPopup = NO;
                        vc.giveTrialOption = NO;
                        vc.explainSync = NO;
                        UIViewController *currentVC = [FlashCardsCore currentViewController];
                        // Pass the selected object to the new view controller.
                        [currentVC.navigationController pushViewController:vc animated:YES];
                    };
                    
                    RIButtonItem *cancel = [RIButtonItem item];
                    cancel.label = NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"");
                    cancel.action = ^{
                        // don't show it to them again for another 90 days [in case they do renew subscription]
                        [FlashCardsCore setSetting:@"promptRenewSubscription"
                                             value:[NSDate dateWithTimeIntervalSinceNow:(60 * 60 * 24 * 90)]];

                        if (![FlashCardsCore deviceCanSendEmail]) {
                            return;
                        }
                        
                        RIButtonItem *cancel2 = [RIButtonItem item];
                        cancel2.label = NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"");
                        cancel2.action = ^{};
                        
                        RIButtonItem *okItem = [RIButtonItem item];
                        okItem.label = NSLocalizedStringFromTable(@"Send Feedback", @"Feedback", @"");
                        okItem.action = ^{
                            
                            // we are sending feedback:
                            UIViewController __block *currentVC = [FlashCardsCore currentViewController];

                            MFMailComposeViewController *feedbackController = [[MFMailComposeViewController alloc] init];
                            feedbackController.mailComposeDelegate = nil;
                            feedbackController.bk_completionBlock = (^(MFMailComposeViewController *controller, MFMailComposeResult result, NSError *error){
                                if (result == MFMailComposeResultSent) {
                                    // thank the user for sending feedback:
                                    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@""
                                                                                    message:NSLocalizedStringFromTable(@"Your message has been sent successfully.", @"FlashCards", @"message")
                                                                                   delegate:nil
                                                                          cancelButtonTitle:NSLocalizedStringFromTable(@"OK", @"FlashCards", @"cancelButtonTitle")
                                                                          otherButtonTitles:nil];
                                    [alert show];
                                    //    NSLog(@"It's away!");
                                } else if (result == MFMailComposeResultFailed) {
                                    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@""
                                                                                    message:[NSString stringWithFormat:NSLocalizedStringFromTable(@"An error occurred sending your message: %@ %@", @"Error", @"message"), error, [error userInfo]]
                                                                                   delegate:nil
                                                                          cancelButtonTitle:NSLocalizedStringFromTable(@"OK", @"FlashCards", @"cancelButtonTitle")
                                                                          otherButtonTitles:nil];
                                    [alert show];
                                }

                                [currentVC dismissModalViewControllerAnimated:NO];
                            });
                            [feedbackController setToRecipients:[NSArray arrayWithObject:contactEmailAddress]];
                            [feedbackController setSubject:NSLocalizedStringFromTable(@"Feedback about FlashCards++ [Renewing Subscription]", @"Feedback", @"")];
                            
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
                            
                            [feedbackController setMessageBody:[NSString stringWithFormat:@"I'm sorry that you won't be renewing your FlashCards++ Subscription. I'm always striving to make this app the best that it can be for my customers. Can you please tell me why you are choosing not to renew your Subscription? I am always happy to receive constructive feedback. Many thanks. Jason, developer of FlashCards++\n\nHere's why: \n\nVersion: %@ (%@) [init: %@]\niOS: %@ (%@)\nDevice: %@ (%@, %@)\n%@\n\n",
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
                            
                            [currentVC presentViewController:feedbackController animated:YES completion:nil];
                        };
                        
                        NSString *cancelMessage = NSLocalizedStringFromTable(@"You just opted not to renew your FlashCards++ Subscription. I'm always striving to make this app the best that it can be for my customers. Can you please tell me why you are choosing not to renew your Subscription? Thanks -- Jason, FlashCards++ Developer", @"Subscription", @"");
                        
                        UIAlertView *alert2 = [[UIAlertView alloc] initWithTitle:@""
                                                                         message:cancelMessage
                                                                cancelButtonItem:cancel2
                                                                otherButtonItems:okItem, nil];
                        [alert2 show];

                        
                    };
                    
                    NSDate *subscriptionEndDate = [FlashCardsCore getSettingDate:@"subscriptionEndDate"];
                    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                    [dateFormatter setDateStyle:NSDateFormatterMediumStyle];
                    NSString *endDateString = [dateFormatter stringFromDate:subscriptionEndDate];
                    
                    NSString *basicMessage = [NSString stringWithFormat:NSLocalizedStringFromTable(@"Your FlashCards++ Subscription will expire on %@.", @"Subscription", @""),
                                              endDateString];
                    NSMutableArray *messages = [NSMutableArray arrayWithObject:basicMessage];
                    if ([FlashCardsCore appIsSyncing] && [FlashCardsCore hasGrandfatherClause]) {
                        [messages addObject:NSLocalizedStringFromTable(@"When your Subscription expires, automatic syncing will no longer work.", @"Subscription", @"")];
                    } else if (![FlashCardsCore hasGrandfatherClause]) {
                        [messages addObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"When your Subscription expires, you will be limited to %d cards. Also, you cannot add images or audio to your cards, or sync with other devices and websites.", @"Subscription", @""),
                                             maxCardsLite]];
                    }
                    
                    NSString *message = [messages componentsJoinedByString:@" "];
                    
                    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@""
                                                                    message:message
                                                           cancelButtonItem:cancel
                                                           otherButtonItems:renewItem, remindLater, nil];
                    [alert show];
                    hasShownPopup = YES;
                }
            }
        }
        // if they haven't been shown a popup yet, and they haven't been prompted to
        // post to a social network, prompt them:
        BOOL hasBeenAskedToPostToSocialNetwork    = [FlashCardsCore getSettingBool:@"hasBeenAskedToPostToSocialNetwork"];
        if (!hasBeenAskedToPostToSocialNetwork && ![FlashCardsCore hasSubscription] && !hasShownPopup) {
            int useCount = [(NSNumber*)[FlashCardsCore getSetting:kAppiraterUseCount] intValue];
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            NSDate *dateOfFirstLaunch = [NSDate dateWithTimeIntervalSince1970:[defaults doubleForKey:@"kAppiraterFirstUseDate"]];
            NSInteger daysSinceInstall = [[NSDate date] timeIntervalSinceDate:dateOfFirstLaunch] / 86400;
            if (useCount > 7 && daysSinceInstall > 7 && [FlashCardsCore isConnectedToInternet] && [FlashCardsCore iOSisGreaterThan:6.0f]) {
                BOOL hasService = NO;
                if ([SLComposeViewController isAvailableForServiceType:SLServiceTypeTwitter]) {
                    hasService = YES;
                } else if ([SLComposeViewController isAvailableForServiceType:SLServiceTypeFacebook]) {
                    hasService = YES;
                }
                if (hasService) {
                    RIButtonItem *cancelItem = [RIButtonItem item];
                    cancelItem.label = NSLocalizedStringFromTable(@"No, Thanks", @"Appirater", @"cancelButtonTitle");
                    cancelItem.action = ^{
                    };
                    
                    RIButtonItem *facebookItem = [RIButtonItem item];
                    facebookItem.label = NSLocalizedStringFromTable(@"Post to Facebook", @"FlashCards", @"cancelButtonTitle");
                    facebookItem.action = ^{
                        [FlashCardsCore postMessageTo:SLServiceTypeFacebook];
                    };
                    
                    RIButtonItem *twitterItem = [RIButtonItem item];
                    twitterItem.label = NSLocalizedStringFromTable(@"Post to Twitter", @"FlashCards", @"cancelButtonTitle");
                    twitterItem.action = ^{
                        [FlashCardsCore postMessageTo:SLServiceTypeTwitter];
                    };
                    
                    NSString *message = NSLocalizedStringFromTable(@"Tell the world why you love FlashCards++, and get a one month free Subscription!", @"Flashcards", @"message");
                    
                    UIAlertView *alert;
                    if ([SLComposeViewController isAvailableForServiceType:SLServiceTypeFacebook] &&
                        [SLComposeViewController isAvailableForServiceType:SLServiceTypeTwitter]) {
                        alert = [[UIAlertView alloc] initWithTitle:@""
                                                           message:message
                                                  cancelButtonItem:cancelItem
                                                  otherButtonItems:facebookItem, twitterItem, nil];
                    } else if ([SLComposeViewController isAvailableForServiceType:SLServiceTypeFacebook]) {
                        alert = [[UIAlertView alloc] initWithTitle:@""
                                                           message:message
                                                  cancelButtonItem:cancelItem
                                                  otherButtonItems:facebookItem, nil];
                    } else if ([SLComposeViewController isAvailableForServiceType:SLServiceTypeTwitter]) {
                        alert = [[UIAlertView alloc] initWithTitle:@""
                                                           message:message
                                                  cancelButtonItem:cancelItem
                                                  otherButtonItems:twitterItem, nil];
                    }
                    if (alert) {
                        hasShownPopup = YES;
                        [alert show];
                    }
                    
                    [FlashCardsCore setSetting:@"hasBeenAskedToPostToSocialNetwork" value:[NSNumber numberWithBool:YES]];
                }
            }
        }
        if (!hasShownPopup && [whatsNewInThisVersion length] > 0) {
            NSString *version = [FlashCardsCore appVersion];
            NSString *settingKey = [NSString stringWithFormat:@"whatsNew-%@", version];
            if (![FlashCardsCore getSettingBool:settingKey]) {
                RIButtonItem *cancelItem = [RIButtonItem item];
                cancelItem.label = NSLocalizedStringFromTable(@"Not Now", @"Feedback", @"");
                cancelItem.action = ^{};
                
                RIButtonItem *viewWhatsNew = [RIButtonItem item];
                viewWhatsNew.label = NSLocalizedStringFromTable(@"OK", @"FlashCards", @"");
                viewWhatsNew.action = ^{
                    HelpViewController *helpVC = [[HelpViewController alloc] initWithNibName:@"HelpViewController" bundle:nil];
                    helpVC.title = [NSString stringWithFormat:NSLocalizedStringFromTable(@"What's New in %@", @"Help", @"UIView title"), version];
                    helpVC.helpText = [NSString stringWithFormat:@"**%@**\n\n%@",
                                       helpVC.title,
                                       whatsNewInThisVersion];
                    helpVC.usesMath = YES;

                    UIViewController *currentVC = [FlashCardsCore currentViewController];
                    // Pass the selected object to the new view controller.
                    [currentVC.navigationController pushViewController:helpVC animated:YES];
                };
                
                NSString *message = [NSString stringWithFormat:NSLocalizedStringFromTable(@"Thanks for updating to the latest version of FlashCards++. Would you like to see what's new in version %@?", @"FlashCards", @""),
                                     version];
                
                
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@""
                                                                message:message
                                                       cancelButtonItem:cancelItem
                                                       otherButtonItems:viewWhatsNew, nil];
                [alert show];
                [FlashCardsCore setSetting:settingKey value:@YES];
                hasShownPopup = YES;
            }
        }

        // set up multitasking to do background fetch, if the user is syncing:
        if (![DTVersion osVersionIsLessThen:@"7.0"]) {
            if ([FlashCardsCore appIsSyncing]) {
                [[UIApplication sharedApplication] setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalMinimum];
            } else {
                [[UIApplication sharedApplication] setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalNever];
            }
        }
        
        if (![AppBundleVersion isEqualToString:[FlashCardsCore buildNumber]]) {
            NSString *message = [NSString stringWithFormat:@"STOP! The app bundle versions are not the same [%@ / %@]", AppBundleVersion, [FlashCardsCore buildNumber]];
            FCDisplayBasicErrorMessage(@"", message);
        }

        // [FlashCardsCore processGrandUnifiedReceipt];
        if (block) {
            block();
        }
    }];
    [request startAsynchronous];
}

+ (void)postMessageTo:(NSString*)service {
    SLComposeViewController *composeController = [SLComposeViewController
                                                  composeViewControllerForServiceType:service];
    
    if ([service isEqualToString:SLServiceTypeFacebook]) {
        [composeController setInitialText:@"I love FlashCards++ because... Try it free: http://bit.ly/flashcardappt"];
    } else {
        [composeController setInitialText:@"I love FlashCards++ because... Try it free: http://bit.ly/flashcardappt @studyflashcards"];
    }
    
    SLComposeViewControllerCompletionHandler completionHandler = ^(SLComposeViewControllerResult result){
        [composeController dismissViewControllerAnimated:YES completion:nil];
        switch(result) {
            case SLComposeViewControllerResultCancelled:
            default:
                FCLog(@"Cancelled.....");
                break;
            case SLComposeViewControllerResultDone:
                FCLog(@"Posted....");
                
                [FlashCardsCore provideComplementarySubscription];
                
                break;
        }
    };
    [composeController setCompletionHandler:completionHandler];
    
    UIViewController *vc = [FlashCardsCore currentViewController];
    if (!vc) {
        return;
    }
    [vc presentViewController:composeController
                     animated:YES
                   completion:nil];
}

+ (UIView*)explanationLabelViewWithString:(NSString*)explanation inView:(UIView*)view {
    UITextView * footerLabel = [[UITextView alloc] initWithFrame:CGRectMake(0.0f,
                                                                            0.0f,
                                                                            view.frame.size.width-16.0,
                                                                            0.0f)];
    footerLabel.backgroundColor = [UIColor clearColor];
    footerLabel.opaque = NO;
    footerLabel.textColor = [UIColor blackColor];
    footerLabel.text = explanation;
    [footerLabel setFont:[UIFont systemFontOfSize:14.0f]];
    [footerLabel setTextAlignment:NSTextAlignmentLeft];
    footerLabel.userInteractionEnabled = NO;
    
    CGSize tallerSize, stringSize;
    tallerSize = CGSizeMake(view.frame.size.width-16.0, kMaxFieldHeight);
    CGRect boundingRect = [footerLabel.text boundingRectWithSize:tallerSize
                                                         options:NSStringDrawingUsesLineFragmentOrigin
                                                      attributes:@{NSFontAttributeName:footerLabel.font}
                                                         context:nil];
    stringSize = boundingRect.size;
    [footerLabel setFrame:CGRectMake(footerLabel.frame.origin.x,
                                     footerLabel.frame.origin.y,
                                     footerLabel.frame.size.width,
                                     stringSize.height+10.0f)];
    
    return footerLabel;
}

+ (CGFloat)explanationLabelHeightWithString:(NSString*)explanation inView:(UIView*)view {
    if ([explanation length] == 0) {
        return 0.0;
    }
    
    // create the button object
    UITextView * footerLabel = [[UITextView alloc] initWithFrame:CGRectMake(0.0f,
                                                                            0.0f,
                                                                            view.frame.size.width-16.0,
                                                                            0.0f)];
    footerLabel.backgroundColor = [UIColor clearColor];
    footerLabel.opaque = NO;
    footerLabel.textColor = [UIColor blackColor];
    footerLabel.text = explanation;
    [footerLabel setFont:[UIFont systemFontOfSize:14.0f]];
    [footerLabel setTextAlignment:NSTextAlignmentLeft];
    
    CGSize tallerSize, stringSize;
    tallerSize = CGSizeMake(view.frame.size.width-16.0, kMaxFieldHeight);
    CGRect boundingRect = [footerLabel.text boundingRectWithSize:tallerSize
                                                         options:NSStringDrawingUsesLineFragmentOrigin
                                                      attributes:@{NSFontAttributeName:footerLabel.font}
                                                         context:nil];
    stringSize = boundingRect.size;
    return stringSize.height+20.0f;
}

+ (NSData*) debuggingData {
    NSMutableDictionary *defaultSettings = [FlashCardsCore defaultSettingsDictionary];
    [defaultSettings setObject:[[UIDevice currentDevice] uniqueDeviceIdentifier] forKey:@"UniqueDeviceIdentifier"];
    NSMutableArray *debuggingSettings = [NSMutableArray arrayWithArray:[defaultSettings allKeys]];
    [debuggingSettings addObject:kAppiraterCurrentVersion];
    [debuggingSettings addObject:kAppiraterDeclinedToRate];
    [debuggingSettings addObject:kAppiraterFirstUseDate];
    [debuggingSettings addObject:kAppiraterRatedCurrentVersion];
    [debuggingSettings addObject:kAppiraterSignificantEventCount];
    [debuggingSettings addObject:kAppiraterUseCount];
    NSMutableString *debug = [[NSMutableString alloc] initWithCapacity:0];
    for (NSString *setting in debuggingSettings) {
        [debug appendFormat:@"%@\n", setting];
        [debug appendFormat:@"%@\n", [FlashCardsCore getSetting:setting]];
    }
    NSData     *debugData    = [debug dataUsingEncoding: NSUTF8StringEncoding];
    NSData     *keyDebug     = [NSData dataWithBytes: [[@"api.iphoneflashcards.com/debug" sha256] bytes] length: kCCKeySizeAES128];
    NSData *encryptedDebug   = [debugData aesEncryptedDataWithKey: keyDebug];
    return encryptedDebug;
}
+ (NSString*) debuggingString {
    return [[FlashCardsCore debuggingData] base64Encoding];
}

// as per: http://stackoverflow.com/a/9620725/353137
+ (BOOL)addSkipBackupAttributeToItemAtURL:(NSURL *)URL
{
    const char* filePath = [[URL path] fileSystemRepresentation];
    const char* attrName = "com.apple.MobileBackup";
    if (&NSURLIsExcludedFromBackupKey == nil) {
        // iOS 5.0.1 and lower
        u_int8_t attrValue = 1;
        int result = setxattr(filePath, attrName, &attrValue, sizeof(attrValue), 0, 0);
        return result == 0;
    } else {
        // First try and remove the extended attribute if it is present
        int result = getxattr(filePath, attrName, NULL, sizeof(u_int8_t), 0, 0);
        if (result != -1) {
            // The attribute exists, we need to remove it
            int removeResult = removexattr(filePath, attrName, 0);
            if (removeResult == 0) {
                NSLog(@"Removed extended attribute on file %@", URL);
            }
        }
        
        // Set the new key
        return [URL setResourceValue:[NSNumber numberWithBool:YES] forKey:NSURLIsExcludedFromBackupKey error:nil];
    }
}

+ (BOOL)deviceCanSendEmail {
    if (![MFMailComposeViewController canSendMail]) {
        FCDisplayBasicErrorMessage(@"",
                                   NSLocalizedStringFromTable(@"Your mobile device is not configured to send email.", @"Error", @""));
        return NO;
    }
    return YES;
}

# pragma mark -
# pragma mark LaTeX!

// based on: http://new2objectivec.blogspot.co.il/2012/03/tutorial-how-to-setup-mathjax-locally.html

+ (NSURL*) urlForLatexMathString:(NSString*)xContent withJustification:(NSString *)justification withSize:(int)size {
    return [FlashCardsCore urlForLatexMathString:xContent withJustification:justification withSize:size withFilename:@"temp.html"];
}
+ (NSURL*) urlForLatexMathString:(NSString*)xContent withJustification:(NSString *)justification withSize:(int)size withFilename:(NSString *)fileName {
    //content copied from http://www.mathjax.org/demos/tex-samples/
    /* NSString *xContent = @"<p>\\["
    "\\left( \\sum_{k=1}^n a_k b_k \\right)^{\\!\\!2} \\leq"
    "\\left( \\sum_{k=1}^n a_k^2 \\right) \\left( \\sum_{k=1}^n b_k^2 \\right)"
    "\\]</p>"
    "<BR/>"
    "<p>\\["
    "\\frac{1}{(\\sqrt{\\phi \\sqrt{5}}-\\phi) e^{\\frac25 \\pi}} ="
    "1+\\frac{e^{-2\\pi}} {1+\\frac{e^{-4\\pi}} {1+\\frac{e^{-6\\pi}}"
    "|{1+\\frac{e^{-8\\pi}} {1+\\ldots} } } }"
    "\\]</p>";
     */
    
    /*
     //2nd example from http://www.mathjax.org/demos/mathml-samples/
     NSString *xContent =@"When <math><mi>a</mi><mo>&#x2260;</mo><mn>0</mn></math>,"
     "there are two solutions to <math>"
     "<mi>a</mi><msup><mi>x</mi><mn>2</mn></msup>"
     "<mo>+</mo> <mi>b</mi><mi>x</mi>"
     "<mo>+</mo> <mi>c</mi> <mo>=</mo> <mn>0</mn>"
     "</math> and they are"
     "<math mode='display'>"
     "<mi>x</mi> <mo>=</mo>"
     "<mrow>"
     "<mfrac>"
     "<mrow>"
     "<mo>&#x2212;</mo>"
     "<mi>b</mi>"
     "<mo>&#x00B1;</mo>"
     "<msqrt>"
     "<msup><mi>b</mi><mn>2</mn></msup>"
     "<mo>&#x2212;</mo>"
     "<mn>4</mn><mi>a</mi><mi>c</mi>"
     "</msqrt>"
     "</mrow>"
     "<mrow> <mn>2</mn><mi>a</mi> </mrow>"
     "</mfrac>"
     "</mrow>"
     "<mtext>.</mtext>"
     "</math>";
     */
    
    //temp file filename
    NSString *tmpFileName = fileName;
    
    //temp dir
    NSString *tempDir = NSTemporaryDirectory();
    // NSLog(@"tempDirectory: %@",tempDir);
    
    //create NSURL
    NSString *path4 = [tempDir stringByAppendingPathComponent:tmpFileName];
    NSURL* url = [NSURL fileURLWithPath:path4];
    // NSLog(@"Path=%@, url=%@",path4,url);
    
    //setup HTML file contents
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"MathJax" ofType:@"js" inDirectory:@"MathJaxLocal"];
    // NSLog(@"filePath = %@",filePath);
    
    //write to temp file "tempDir/tmpFileName", set MathJax JavaScript to use "filePath" as directory, add "xContent" as content of HTML file
    NSString *justifiedContent = [NSString stringWithFormat:@"<table id=\"mathTable\" style=\"width:100%%;\" border=\"0\"><tr><td style=\"vertical-align:middle; height: 100%%; width:100%%; text-align:%@; font-size: %dpt;\">%@</td></tr></table>", justification, size, xContent];
    [FlashCardsCore writeStringToFile:tempDir fileName:tmpFileName pathName:filePath content:justifiedContent];
    
    return url;
    
    /*
    helpTextView.scalesPageToFit = YES;
    helpTextView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
    //this line no longer required
    //myWebView.delegate = self;
    
    
    NSURLRequest* req = [[NSURLRequest alloc] initWithURL:url];
    
    //original request to show MathJax stuffs
    [helpTextView loadRequest:req];
     */
}

+ (void)writeStringToFile:(NSString *)dir
                 fileName:(NSString *)strFileName
                 pathName:(NSString *)strPath
                  content:(NSString *)strContent {
    
    // NSLog(@" inside writeStringToFile, strPath=%@", strPath);
    
    NSString *path = [dir stringByAppendingPathComponent:strFileName];
    
    NSString *foo0 = @"<html><head><meta name='viewport' content='initial-scale=1.0' />"
    "<script type='text/x-mathjax-config'>"
    "MathJax.Hub.Config({"
    "tex2jax: {"
    "inlineMath: [ ['$','$'], [\"\\\\(\",\"\\\\)\"], [\"\\\\[\",\"\\\\]\"] ],"
    "processEscapes: true"
    "},"
    "messageStyle: 'none',"
    "showProcessingMessages:false"
    "});"
    "MathJax.Hub.Queue(function myFunction() {"
    "    window.location='fcppweb://mathjaxdone';"
    "});"
    "</script>"
    "<script type='text/javascript' src='";
    
    NSString *foo1 = @"?config=TeX-AMS-MML_HTMLorMML-full'></script>"
    "</head>"
    "<body>";
    NSString *foo2 = @"</body></html>";
    NSString *fooFinal = [NSString stringWithFormat:@"%@%@%@%@%@",foo0,strPath,foo1,strContent,foo2];
    
    
    // NSLog(@"Final content is %@",fooFinal);
    
    [fooFinal writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    
}

+ (BOOL)canShowInterstitialAds {
    if ([FlashCardsAppDelegate isIpad]) {
        return YES;
    }
    if (![DTVersion osVersionIsLessThen:@"7.0"]) {
        return YES;
    }
    return NO;
}

+ (void)processGrandUnifiedReceipt {
    return;
    
    /*
    
    NSURL *receiptURL = nil;
    NSBundle *bundle = [NSBundle mainBundle];
    if (![bundle respondsToSelector:@selector(appStoreReceiptURL)]) {
        return;
    }
    if ([DTVersion osVersionIsLessThen:@"7.0"]) {
        return;
    }
    receiptURL = [bundle performSelector:@selector(appStoreReceiptURL)];
    NSString *receiptPath = [receiptURL path];
    NSString *certificatePath = [[NSBundle mainBundle] pathForResource:@"AppleIncRootCertificate" ofType:@"cer"];

    NSFileManager *fileManager = [[NSFileManager alloc] init];
    if (![fileManager fileExistsAtPath:receiptPath]) {
        FCLog(@"receipt not found");
        [FlashCardsCore refreshGrandUnifiedReceipt];
        return;
    }
    
    // ******************************************************************************
    // STEP 1: LOAD RECEIPT & VERIFY THAT IT CAME FROM APPLE AND HAS NOT BEEN ALTERED
    // ******************************************************************************

    // as per: http://ataugeron.github.io/blog/blog/2013/09/23/app-store-receipt-validation-on-ios-7/
    NSData *receiptData = [NSData dataWithContentsOfFile:receiptPath];
    const uint8_t *receiptBytes = (uint8_t *)(receiptData.bytes);
    // Convert receipt data to PKCS #7 Representation
    PKCS7 *p7 = d2i_PKCS7(NULL, &receiptBytes, (long)receiptData.length);

    NSData *certData = [NSData dataWithContentsOfFile:certificatePath];
    const uint8_t *certBytes = (uint8_t *)(certData.bytes);
    X509 *appleRootCA = d2i_X509(NULL, &certBytes, (long)certData.length);

    // Create the certificate store
    X509_STORE *store = X509_STORE_new();
    X509_STORE_add_cert(store, appleRootCA);
    
    // Verify the Signature
    BIO *b_receiptPayload = BIO_new(BIO_s_mem());
    OpenSSL_add_all_digests();
    int result = PKCS7_verify(p7, NULL, store, NULL, b_receiptPayload, 0);
    if (result != 1) {
        FCLog(@"Receipt Signature is NOT valid");
        return;
    }
    
    FCLog(@"Receipt Signature is VALID");
    // Receipt Signature is VALID
    // b_receiptPayload contains the payload

    // ******************************************************************************
    // STEP 2: VALIDATE THAT THE RECEIPT IS VALID FOR THIS PARTICULAR iOS DEVICE!!!!!
    // ******************************************************************************

    RMStoreAppReceiptVerificator *verify = [[RMStoreAppReceiptVerificator alloc] init];
    verify.bundleIdentifier = AppBundleIdentifier;
    verify.bundleVersion = AppBundleVersion;
    BOOL isVerified = [verify verifyAppReceipt];
    if (isVerified) {
        FCLog(@"Receipt is verified");
    } else {
        FCLog(@"Receipt is not verified!");
        return;
    }
    
    // ******************************************************************************
    // STEP 3: UPDATE THE FIRST VERSION OF THE APP!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    // ******************************************************************************

    RMAppReceipt *receipt = [RMAppReceipt bundleReceipt];
    FCLog(@"Original version: %@", receipt.originalAppVersion);
    [FlashCardsCore setSetting:@"firstVersionInstalled" value:receipt.originalAppVersion];
     */
}

+ (void)refreshGrandUnifiedReceipt {
    // contacting the server to refresh the receipt requires internet connectivity
    if (![FlashCardsCore isConnectedToInternet]) {
        return;
    }
    
    if ([[FlashCardsCore appDelegate] hasAskedForAppleIdSigninToRefreshAppReceipt]) {
        return;
    }
    
    [[FlashCardsCore appDelegate] setHasAskedForAppleIdSigninToRefreshAppReceipt:YES];
    
    RIButtonItem *cancel = [RIButtonItem item];
    cancel.label = NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"");
    cancel.action = ^{};

    RIButtonItem *ok = [RIButtonItem item];
    ok.label = NSLocalizedStringFromTable(@"OK", @"FlashCards", @"");
    ok.action = ^{
        SKReceiptRefreshRequest *request = [[SKReceiptRefreshRequest alloc] init];
        [request setDelegate:[FlashCardsCore appDelegate]];
        [request start];
    };

    NSString *message = NSLocalizedStringFromTable(@"FlashCards++ would like to check with the App Store to verify your purchase status. You may be prompted to enter your iTunes password. You will not be charged.", @"Subscription", @"");
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@""
                                                    message:message
                                           cancelButtonItem:cancel
                                           otherButtonItems:ok, nil];
    [alert show];
}

@end