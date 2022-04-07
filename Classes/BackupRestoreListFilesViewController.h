//
//  BackupRestoreListFilesViewController.h
//  FlashCards
//
//  Created by Jason Lustig on 8/25/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "MBProgressHUD.h"

@class DBMetadata;
@class MBProgressHUD;
@protocol MBProgressHUDDelegate;

@interface BackupRestoreListFilesViewController : UIViewController <UIAlertViewDelegate, UITableViewDelegate, DBRestClientDelegate, MBProgressHUDDelegate>

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath;

// File Chooser View:
- (IBAction) loadBackupFiles:(id)sender;
- (IBAction) cancelLoadBackupFiles:(id)sender;
- (IBAction) backupNow:(id)sender;
- (void) backupNowAction;
- (IBAction) cancelBackup:(id)sender;
- (IBAction) viewSettings:(id)sender;
- (void) editEvent;
- (void) enableToolbarButtons:(BOOL)enabled;
- (void) reloadTableData;
- (BOOL)checkInternet;

- (void)backupFinishedSuccessfully;
- (void)backupFailed;

@property (nonatomic, strong) DBRestClient *restClient;

@property (nonatomic, strong) MBProgressHUD *HUD;

// File Chooser View:
@property (nonatomic, weak) IBOutlet UITableView *myTableView;

@property (nonatomic, strong) IBOutlet UITableViewCell *loadingCell;
@property (nonatomic, weak) IBOutlet UIActivityIndicatorView *loadingCellActivityIndicator;
@property (nonatomic, strong) IBOutlet UITableViewCell *helpCell;

@property (nonatomic, strong) IBOutlet UITableViewCell *uploadProgressCell;
@property (nonatomic, weak) IBOutlet UIProgressView *uploadProgressView;

@property (nonatomic, weak) IBOutlet UILabel *uploadingBackupLabel;
@property (nonatomic, weak) IBOutlet UILabel *loadingBackupFilesLabel;

@property (nonatomic, weak) IBOutlet UIButton *uploadProgressCancelButton;
@property (nonatomic, weak) IBOutlet UIButton *loadingCancelButton;


@property (nonatomic, weak) IBOutlet UIToolbar *bottomToolbar;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *backUpNowButton;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *refreshFileListButton;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *settingsButton;


@property (nonatomic, strong) NSMutableArray *backupFiles;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@property (nonatomic, strong) NSString *backupFilePath;

@property (nonatomic, assign) bool isUploadingBackup;
@property (nonatomic, assign) bool isLoadingBackupFileList;
@property (nonatomic, assign) bool loadingAllFiles;
@property (nonatomic, strong) NSString *uploadFileName; // allows us to store the file name over multiple calls
@property (nonatomic, assign) bool isOverwritingFile; // lets us know if the backup is overwriting a file
@property (nonatomic, assign) bool isCheckingOverwrite;

@property (nonatomic, strong) DBMetadata *currentlyDeletingFileInfo;
@property (nonatomic, strong) NSIndexPath *currentlyDeletingIndexPath;

@property (nonatomic, assign) bool isConnectedToInternet;
@property (nonatomic, assign) bool hasCheckedInternetConnection;

@property (nonatomic, assign) BOOL settingsUpdated;

@property (nonatomic) UIBackgroundTaskIdentifier taskIdentifier;

@end
