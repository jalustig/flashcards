//
//  BackupRestoreListFilesViewController.m
//  FlashCards
//
//  Created by Jason Lustig on 8/25/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import "FlashCardsAppDelegate.h"
#import "FlashCardsCore.h"

#import "BackupRestoreListFilesViewController.h"
#import "BackupRestoreSettingsViewController.h"
#import "BackupRestoreFileViewController.h"

#import "UIAlertView+Blocks.h"

#import "MBProgressHUD.h"

@implementation BackupRestoreListFilesViewController

@synthesize myTableView;
@synthesize loadingCell, loadingCellActivityIndicator, helpCell;
@synthesize uploadProgressCell, uploadProgressView;
@synthesize bottomToolbar, backUpNowButton, refreshFileListButton, settingsButton, backupFiles;
@synthesize dateFormatter, backupFilePath, loadingAllFiles, uploadFileName, isUploadingBackup, isOverwritingFile, isCheckingOverwrite, isLoadingBackupFileList, settingsUpdated;
@synthesize currentlyDeletingFileInfo, currentlyDeletingIndexPath;
@synthesize isConnectedToInternet;
@synthesize restClient;
@synthesize taskIdentifier;
@synthesize hasCheckedInternetConnection;
@synthesize HUD;

@synthesize uploadingBackupLabel, loadingBackupFilesLabel, uploadProgressCancelButton, loadingCancelButton;

/*
 // The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        // Custom initialization
    }
    return self;
}
*/

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
        
    [super viewDidLoad];
    
    settingsUpdated = NO;
    
    if ([[FlashCardsCore appDelegate] coredataIsCorrupted]) {
        backUpNowButton.enabled = NO;
    }
    
    [backUpNowButton setTitle:NSLocalizedStringFromTable(@"Backup Now", @"Backup", @"UIBarButtonItem")];
    [settingsButton setTitle:NSLocalizedStringFromTable(@"Settings", @"Settings", @"UIBarButtonItem")];
    
    uploadingBackupLabel.text = NSLocalizedStringFromTable(@"Uploading...", @"FlashCards", @"UILabel");
    loadingBackupFilesLabel.text = NSLocalizedStringFromTable(@"Loading...", @"FlashCards", @"UILabel");
    
    [loadingCancelButton setTitle:NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"UILabel") forState:UIControlStateNormal]; 
    [loadingCancelButton setTitle:NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"UILabel") forState:UIControlStateSelected];

    [uploadProgressCancelButton setTitle:NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"UILabel") forState:UIControlStateNormal]; 
    [uploadProgressCancelButton setTitle:NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"UILabel") forState:UIControlStateSelected];    
    
    hasCheckedInternetConnection = NO;
    loadingAllFiles = YES;
    isConnectedToInternet = YES;
    isLoadingBackupFileList = NO;
    isUploadingBackup = NO;
    
    [self reloadTableData];
    
    self.title = NSLocalizedStringFromTable(@"Backup & Restore", @"Backup", @"UIView title");
    
    UIBarButtonItem *refreshButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                                   target:self
                                                                                   action:@selector(loadBackupFiles:)];
    
    UIBarButtonItem *editButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(editEvent)];
    editButton.enabled = YES;
    [self.navigationItem setRightBarButtonItems:@[editButton, refreshButton]];

    backupFiles = [[NSMutableArray alloc] initWithCapacity:0];
    
    dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateStyle:NSDateFormatterShortStyle];
    [dateFormatter setTimeStyle:NSDateFormatterNoStyle];
    
    hasCheckedInternetConnection = YES;
    BOOL isError = [self checkInternet];
    if (isError) {
        [self.navigationController popViewControllerAnimated:YES];
        return;
    }
    
    backupFilePath = (NSString*)[FlashCardsCore getSetting:@"dropboxBackupFilePath"];
    
    [self loadBackupFiles:nil];

}

- (void)viewDidAppear:(BOOL)animated {

    [super viewDidAppear:animated];

    if (hasCheckedInternetConnection && !isConnectedToInternet) {
        return;
    }
    BOOL isError = [self checkInternet];
    if (isError) {
        [self.navigationController popViewControllerAnimated:YES];
        return;
    }
        
    NSIndexPath* selection = [self.myTableView indexPathForSelectedRow];
    if (selection) {
        [self.myTableView deselectRowAtIndexPath:selection animated:YES];
    }
    
    backupFilePath = (NSString*)[FlashCardsCore getSetting:@"dropboxBackupFilePath"];
    
    if (([backupFiles count] == 0 || settingsUpdated) && !isLoadingBackupFileList) {
        [self loadBackupFiles:nil];
        settingsUpdated = NO;
    }
}

- (BOOL)checkInternet {
    if (![FlashCardsCore isConnectedToInternet]) {
        isConnectedToInternet = NO;
        FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"No Internet Connection", @"Error", @"UIAlert title"),
                                   [NSString stringWithFormat:@"%@ %@",
                                        NSLocalizedStringFromTable(@"You are not connected to the internet.", @"Error", @""),
                                        NSLocalizedStringFromTable(@"This feature will only work with an active internet connection.", @"Error", @"message")]);
        return YES;
    }    
    return NO;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[self restClient] cancelAllRequests];
    isUploadingBackup = NO;
    isOverwritingFile = NO;
    isLoadingBackupFileList = NO;
    isCheckingOverwrite = NO;
}

- (DBRestClient*)restClient {
    if (!restClient) {
        restClient = [[DBRestClient alloc] initWithSession:[DBSession sharedSession]];
        restClient.delegate = self;
    }
    return restClient;
}

- (BOOL)shouldAutorotate {
    UIInterfaceOrientation interfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    return [FlashCardsAppDelegate shouldAutorotate:interfaceOrientation];
}


# pragma mark -
# pragma mark File Chooser View Functions

- (IBAction) loadBackupFiles:(id)sender {
    if (self.myTableView.editing) {
        [self.myTableView setEditing:NO animated:YES]; // get out of editing mode if we are already there
    }
    
    self.navigationItem.rightBarButtonItem.enabled = NO;
    
    // just in case we are doing anything else, cancel the request.
    // if we don't cancel it, then life will get screwy.
    [[self restClient] cancelAllRequests];
    
    isCheckingOverwrite = NO;
    isLoadingBackupFileList = YES;
    [self.loadingCellActivityIndicator startAnimating];
    [[self restClient] loadMetadata:backupFilePath];
    [self reloadTableData];
}

- (IBAction) cancelLoadBackupFiles:(id)sender {
    
    self.navigationItem.rightBarButtonItem.enabled = YES;
    
    isLoadingBackupFileList = NO;
    [self.loadingCellActivityIndicator stopAnimating];
    [[self restClient] cancelAllRequests];
    [self reloadTableData];
}

- (IBAction) backupNow:(id)sender {
    if (self.myTableView.editing) {
        [self.myTableView setEditing:NO animated:YES]; // get out of editing mode if we are already there
    }
    
    // just in case we are still loading the metadata, cancel the request.
    // if we don't cancel it, then the isCheckingOverwrite = YES will make the app
    // pop up the overwriting alert from the main metadata download - not the overwrite check.
    [[self restClient] cancelAllRequests];
    
    uploadProgressView.progress = 0.0;
    isUploadingBackup = YES;
    [self enableToolbarButtons:NO];
    isOverwritingFile = NO;
    [dateFormatter setDateFormat:@"yyyy-MM-dd 'at' HH:mm"];
    uploadFileName = [NSString stringWithFormat:@"%@.sqlite", [dateFormatter stringFromDate:[NSDate date]]];
    [dateFormatter setDateStyle:NSDateFormatterShortStyle];
    NSString *fullFilePath = [NSString stringWithFormat:@"%@/%@", backupFilePath, uploadFileName];
    isCheckingOverwrite = YES; // so the rest client knows, we aren't looking up the directory:
    [[self restClient] loadMetadata:fullFilePath];
    [self reloadTableData];
}

- (void) backupNowAction {
    RIButtonItem *optimizeItem = [RIButtonItem item];
    optimizeItem.label = NSLocalizedStringFromTable(@"Optimize Database", @"Settings", @"otherButtonTitles");
    optimizeItem.action = ^{
        HUD = [[MBProgressHUD alloc] initWithView:self.view];
        // Add HUD to screen
        [self.view addSubview:HUD];
        // Regisete for HUD callbacks so we can remove it from the window at the right time
        HUD.delegate = self;
        HUD.minShowTime = 1.0;
        HUD.labelText = NSLocalizedStringFromTable(@"Optimizing Database", @"Settings", @"HUD");
        HUD.detailsLabelText = NSLocalizedStringFromTable(@"May take a minute on large databases.", @"FlashCards", @"HUD");
        [HUD show:YES];
        dispatch_async(dispatch_get_main_queue(), ^{
            [[FlashCardsCore appDelegate] compressImagesAndPerformSelector:@selector(backupWorker)
                                                                onDelegate:self
                                                                withObject:nil
                                                        inBackgroundThread:NO];
        });
    };

    RIButtonItem *backupItem = [RIButtonItem item];
    backupItem.label = NSLocalizedStringFromTable(@"Upload Database Now", @"Backup", @"otherButtonTitles");
    backupItem.action = ^{
        [self backupWorker];
    };

    RIButtonItem *cancelItem = [RIButtonItem item];
    cancelItem.label = NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"cancelButtonTitle");
    cancelItem.action = ^{
        [self cancelBackup:nil];
    };
    
    NSString *message = NSLocalizedStringFromTable(@"Do you want to optimize your FlashCards++ database before uploading it?", @"Backup", @"message");
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@""
                                                    message:message
                                           cancelButtonItem:cancelItem
                                           otherButtonItems:optimizeItem, backupItem, nil];
    [alert show];
}

- (void)backupWorker {
    if (HUD) {
        [HUD hide:YES];
    }
    FlashCardsAppDelegate *appDelegate = (FlashCardsAppDelegate *)[[UIApplication sharedApplication] delegate];
    appDelegate.showAlertWhenBackupIsSuccessful = YES;
    [appDelegate backupWithFileName:uploadFileName withDelegate:self andHUD:nil andProgressView:uploadProgressView];
    [Flurry logEvent:@"Backup/BackupFile"];
}

- (IBAction) cancelBackup:(id)sender {
    isUploadingBackup = NO;
    [self enableToolbarButtons:YES];
    FlashCardsAppDelegate *appDelegate = (FlashCardsAppDelegate *)[[UIApplication sharedApplication] delegate];
    [[appDelegate restClient] cancelAllRequests];
    [self reloadTableData];
}


- (IBAction) viewSettings:(id)sender {
    BackupRestoreSettingsViewController *vc = [[BackupRestoreSettingsViewController alloc] initWithNibName:@"BackupRestoreSettingsViewController" bundle:nil];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void) editEvent {
    if (self.myTableView.editing) {
        [self.myTableView setEditing:NO animated:YES];
        UIBarButtonItem *editButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(editEvent)];
        editButton.enabled = YES;
        self.navigationItem.rightBarButtonItem = editButton;
        [self enableToolbarButtons:YES];
    } else {
        if ([backupFiles count] == 0) {
            return;
        }
        [self.myTableView setEditing:YES animated:YES];
        UIBarButtonItem *editButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(editEvent)];
        editButton.enabled = YES;
        self.navigationItem.rightBarButtonItem = editButton;
        [self enableToolbarButtons:NO];
        self.navigationItem.rightBarButtonItem.enabled = YES;
    }
}

- (void) enableToolbarButtons:(BOOL)enabled {
    self.navigationItem.rightBarButtonItem.enabled = enabled;
    backUpNowButton.enabled = enabled;
    refreshFileListButton.enabled = enabled;
    settingsButton.enabled = enabled;
    if ([[FlashCardsCore appDelegate] coredataIsCorrupted]) {
        backUpNowButton.enabled = NO;
    }
}

- (void) reloadTableData {
    if (isLoadingBackupFileList || isUploadingBackup || [backupFiles count] > 0) {
        self.myTableView.scrollEnabled = YES;
        self.myTableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    } else {
        self.myTableView.scrollEnabled = NO;
        self.myTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    }
    [self.myTableView reloadData];
}

# pragma mark -
# pragma mark Alert view functions

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (!isConnectedToInternet) {
        [self.navigationController popViewControllerAnimated:YES];
        return;
    }
    if (buttonIndex == 1) {
        isOverwritingFile = YES;
        // back up the file:
        [self backupNowAction];
    } else {
        isUploadingBackup = NO;
        [self enableToolbarButtons:YES];
        [self loadBackupFiles:nil];
    }
}

#pragma mark -
#pragma mark MBProgressHUDDelegate methods

- (void)hudWasHidden:(MBProgressHUD *)hud {
    // Remove HUD from screen when the HUD was hidded
    [hud removeFromSuperview];
    hud = nil;
}

# pragma mark -
# pragma mark DBRestClientDelegate functions - uploading

- (void)backupFinishedSuccessfully {
    // add the new item:
    loadingAllFiles = NO;
    isCheckingOverwrite = NO;
    isLoadingBackupFileList = YES;
    isUploadingBackup = NO;
    [self enableToolbarButtons:YES];
    [self loadBackupFiles:nil];
}

- (void)backupFailed {
    
    isUploadingBackup = NO;
    [self enableToolbarButtons:YES];
    [self reloadTableData];

}

# pragma mark -
# pragma mark DBRestClientDelegate functions - deleting

// Folder is the metadata for the newly created folder
- (void)restClient:(DBRestClient*)client deletedPath:(NSString *)path {
}

// [error userInfo] contains the root and path
- (void)restClient:(DBRestClient*)client deletePathFailedWithError:(NSError*)error {
    // Re-insert the deleted file which we couldn't delete:
    [backupFiles insertObject:currentlyDeletingFileInfo atIndex:currentlyDeletingIndexPath.row];
    [self.myTableView insertRowsAtIndexPaths:[NSArray arrayWithObject:currentlyDeletingIndexPath] withRowAnimation:UITableViewRowAnimationRight];
    
    if (error.code == -1009 && error.domain == NSURLErrorDomain) {
        FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"Error", @"Error", @"UIAlert title"),
                                   NSLocalizedStringFromTable(@"You are not connected to the internet.", @"Error", @"message"));
        return;
    }
    
    if (error.code == 404) {
        FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"Error: File Not Found", @"Error", @"UIAlert title"),
                                   [NSString stringWithFormat:NSLocalizedStringFromTable(@"The file \"%@\" could not be found.\n\nError info: %@ %@", @"Error", @"message"), [[error userInfo] valueForKey:@"path"], error, [error userInfo]]);
        return;
    }
    
    FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"Error", @"Error", @"UIAlert title"),
                               [NSString stringWithFormat:NSLocalizedStringFromTable(@"Error: %@ (%@)", @"Error", @"message"), error, [error userInfo]]);
}


# pragma mark -
# pragma mark DBRestClientDelegate functions - metadata

- (void)restClient:(DBRestClient*)client loadedMetadata:(DBMetadata*)metadata {
    
    isLoadingBackupFileList = NO;
    [self.loadingCellActivityIndicator stopAnimating];
    
    if (isCheckingOverwrite) {
        isCheckingOverwrite = NO;
        
        if (metadata.isDeleted) {
            // path doesn't exist
            isOverwritingFile = NO;
            // this is good! -- we now know that the file does not exist, and can begin uploading the backup:
            // we don't set isOverwritingFile to no now, b/c when we finish loading the metadata we have lost whether
            // we are overwriting or not!
            [self backupNowAction];
            return; // we don't want to ALSO show the duplicate file alert!
        }
        
        // it looks like we will be overwriting a file. Check to see if the user wants to overwrite the file:
        [[[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Duplicate File", @"Backup", @"UIAlert title")
                                     message:[NSString stringWithFormat:NSLocalizedStringFromTable(@"It appears that a backup file already exists in this location with the name \"%@\". Continuing with your backup will overwrite this file. Would you like to overwrite this file?", @"Backup", @"message"), uploadFileName]
                                    delegate:self
                           cancelButtonTitle:NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"cancelButtonTitle")
                           otherButtonTitles:NSLocalizedStringFromTable(@"Overwrite File", @"Backup", @"otherButtonTitles"), nil]
                        show];
            
        return;
    }
    
    // we are not working on a backup:
    [self enableToolbarButtons:YES];
    
    if (!metadata.isDirectory) {
        // throw error - it is not a directory
        
        [[[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Error", @"Error", @"UIAlert title")
                                     message:[NSString stringWithFormat:NSLocalizedStringFromTable(@"It appears that your backup location (\"%@\") is not a directory. Please select a new location for backups.", @"Error", @"message"), metadata.path]
                                    delegate:nil 
                           cancelButtonTitle:NSLocalizedStringFromTable(@"OK", @"FlashCards", @"cancelButtonTitle")
                           otherButtonTitles:nil]
         show];        
        
        backUpNowButton.enabled = NO; // don't let people upload 
        [backupFiles removeAllObjects];
        [self reloadTableData];
        
        return;
    }
    
    [backupFiles removeAllObjects];
    [backupFiles addObjectsFromArray:metadata.contents];
    
    // sort it by date:
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"path" ascending:NO];
    [backupFiles sortUsingDescriptors:[NSArray arrayWithObject:sortDescriptor]];
    
    // filter out all directories && files which don't end with ".sqlite":
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"self.isDirectory = NO and self.path endswith[c] \".sqlite\""];
    [backupFiles filterUsingPredicate:predicate];
    
    [self reloadTableData];
    loadingAllFiles = YES;
    isOverwritingFile = NO;
}

- (void)restClient:(DBRestClient*)client metadataUnchangedAtPath:(NSString*)path {
    
    // NSLog(@"Metadata unchanged!");
}

- (void)restClient:(DBRestClient*)client loadMetadataFailedWithError:(NSError*)error {
    
    [self.loadingCellActivityIndicator stopAnimating];
    isLoadingBackupFileList = NO;
    [self cancelLoadBackupFiles:nil];
    
    // the case where the error is 404 and we are checking overwrite - this means we are doing a backup!
    // Then, don't enable the buttons:
    if (!(error.code == 404) && (isCheckingOverwrite)) {
        [self enableToolbarButtons:YES];
        [self reloadTableData];
    }
    
    // NSLog(@"Error loading metadata: %@", error);
    
    NSString *errorAction;
    if (isCheckingOverwrite) {
        errorAction = NSLocalizedStringFromTable(@"Error checking the file path:", @"Error", @"");
    } else {
        errorAction = NSLocalizedStringFromTable(@"Error loading the list of backup files:", @"Error", @"");
    }
    
    if (error.code == -1009 && error.domain == NSURLErrorDomain) {
        FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"Error", @"Error", @"UIAlert title"),
                                   [NSString stringWithFormat:@"%@ %@\n\n%@ %@ %@", errorAction, NSLocalizedStringFromTable(@"You are not connected to the internet.", @"Error", @""), NSLocalizedStringFromTable(@"Error info:", @"Error", @""), error, [error userInfo]]);
        return;
    }
    
    if (error.code == 404) {
        if (isCheckingOverwrite) {
            // this is good! -- we now know that the file does not exist, and can begin uploading the backup:
            // we don't set isOverwritingFile to no now, b/c when we finish loading the metadata we have lost whether
            // we are overwriting or not!
            [self enableToolbarButtons:NO];
            [self backupNowAction];
            return;
        }
        
        return;
    }
    
    FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"Error", @"Error", @"UIAlert title"),
                               [NSString stringWithFormat:@"%@ %@ %@", errorAction, error, [error userInfo]]);
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    if (isLoadingBackupFileList || isUploadingBackup) {
        return 1;
    }
    if ([backupFiles count] == 0) {
        return 2;
    }
    return [backupFiles count];
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (isUploadingBackup) {
        return uploadProgressCell;
    }
    if (isLoadingBackupFileList) {
        return loadingCell;
    }
    
    static NSString *CellIdentifier;
    int style;
    if ([backupFiles count] == 0) {
        if (indexPath.row == 1) {
            UITableViewCell *help = [myTableView dequeueReusableCellWithIdentifier:@"HelpCell"];
            if (help == nil) {
                help = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"HelpCell"];
            }
            [help.contentView setFrame:CGRectMake(0, 0, myTableView.frame.size.width, 322)];
            help.selectionStyle = UITableViewCellSelectionStyleNone;
            help.editingAccessoryView = UITableViewCellEditingStyleNone;
            help.editingAccessoryType = UITableViewCellEditingStyleNone;
            help.shouldIndentWhileEditing = NO;
            
            UIImageView *helpImage = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 320, 322)];
            NSString *helpImagePath = [[NSBundle mainBundle] pathForResource:@"Arrow-Down" ofType:@"png"];
            helpImage.image = [UIImage imageWithContentsOfFile:helpImagePath];
        //    helpImage.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
            [help.contentView addSubview:helpImage];
            
            UITextView *helpText = [[UITextView alloc] initWithFrame:CGRectMake(90, 0, 230, 322)];
            helpText.textColor = [UIColor blackColor];
            helpText.backgroundColor = [UIColor whiteColor];
            helpText.font = [UIFont systemFontOfSize:15];
            helpText.editable = NO;
            helpText.text = NSLocalizedStringWithDefaultValue(@"BackupRestoreListFilesVCHelp", @"Help", [NSBundle mainBundle], @""
                                                       "To back up your flash cards, simply tap \"Backup Now\" below.\n\n"
                                                       "At any time, you can restore your backup by returning to this screen and selecting the backup to restore.\n\n"
                                                       "By default, backups are stored in a folder called \"FlashCards++ Backups.\" You can change this location below in the Backup Settings.", @"");
        //    helpText.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin;
            [help.contentView addSubview:helpText];
            
            return help;
            
        }
        CellIdentifier = @"CenterCell";
        style = UITableViewCellStyleDefault;
    } else {
        CellIdentifier = @"Cell";
        style = UITableViewCellStyleSubtitle;
    }
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:style reuseIdentifier:CellIdentifier];
    }
    
    // Configure the cell...
    [self configureCell:cell atIndexPath:indexPath];
    
    return cell;
}

- (UITableViewCellEditingStyle)tableView:(UITableView  *)tableView editingStyleForRowAtIndexPath:(NSIndexPath  *)indexPath {
    // Detemine if it's in editing mode
    if (self.editing || self.navigationItem.rightBarButtonItem.enabled) {
        return UITableViewCellEditingStyleDelete;
    }
    return UITableViewCellEditingStyleNone;    
}


- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    if ([backupFiles count] == 0) {
        if (indexPath.row == 0) {
            cell.textLabel.text = NSLocalizedStringFromTable(@"No Backups Found", @"Backup", @"");
            cell.textLabel.textAlignment = NSTextAlignmentCenter;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        } else {
            
        }
        return;
    }
    
    DBMetadata *fileInfo = [backupFiles objectAtIndex:indexPath.row];
    cell.textLabel.text = [fileInfo.path stringByReplacingCharactersInRange:NSMakeRange(0, [backupFilePath length]+1) withString:@""];
    int length = [cell.textLabel.text length];
    cell.textLabel.text = [cell.textLabel.text stringByReplacingCharactersInRange:NSMakeRange(length-[@".sqlite" length], [@".sqlite" length]) withString:@""];
    cell.detailTextLabel.text = fileInfo.humanReadableSize;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
}

#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    [self tableView:tableView didSelectRowAtIndexPath:indexPath];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (isLoadingBackupFileList || isUploadingBackup) {
        return;
    }
    if ([[tableView cellForRowAtIndexPath:indexPath] isEqual:helpCell]) {
        return;
    }
    if ([backupFiles count] == 0) {
        return;
    }
    
    DBMetadata *fileInfo = [backupFiles objectAtIndex:indexPath.row];
    
    BackupRestoreFileViewController *vc = [[BackupRestoreFileViewController alloc] initWithNibName:@"BackupRestoreFileViewController" bundle:nil];
    vc.fileInfo = fileInfo;
    [self.navigationController pushViewController:vc animated:YES];
    
}


// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        
        DBMetadata *fileInfo = [backupFiles objectAtIndex:indexPath.row];
        currentlyDeletingFileInfo = fileInfo;
        currentlyDeletingIndexPath = indexPath;
        [[self restClient] deletePath:fileInfo.path];
        [backupFiles removeObjectAtIndex:indexPath.row];
        
        if ([backupFiles count] == 0) {
            [self editEvent];
            [self reloadTableData];
        } else {
            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
        }
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}


# pragma mark -
# pragma mark Memory functions

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}




@end
