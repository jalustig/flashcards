//
//  BackupRestoreFileViewController.m
//  FlashCards
//
//  Created by Jason Lustig on 7/30/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import "BackupRestoreFileViewController.h"

#import "FlashCardsAppDelegate.h"
#import "RootViewController.h"

#import "UIAlertView+Blocks.h"
#import "MBProgressHUD.h"

@implementation BackupRestoreFileViewController

@synthesize fileInfo, restoreProgressLabel, restoreProgress, restoreToolbar, hasRestoredData;
@synthesize myTableView;
@synthesize restClient, HUD;

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
    
    self.title = NSLocalizedStringFromTable(@"Backup Information", @"Backup", @"UIView title");
    
    hasRestoredData = NO;
    
    // set up the restore toolbar:
    
    CGRect labelFrame;
    CGRect progressFrame;
    
    if ([FlashCardsAppDelegate isIpad]) {
        labelFrame = CGRectMake((768-100-230)/2, 3, 230, 20);
        progressFrame = CGRectMake(12, 25, 768-100 , 10);
    } else {
        labelFrame = CGRectMake(12, 3, 230, 20);
        progressFrame = CGRectMake(12, 25, 230 , 10);
    }
    
    restoreProgressLabel.text = NSLocalizedStringFromTable(@"Downloading Restore File", @"Backup", @"uploadingLabel");
    restoreProgressLabel.superview.backgroundColor = [UIColor clearColor];
    restoreProgressLabel.superview.opaque = NO;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[self restClient] cancelAllRequests];
}


- (BOOL)shouldAutorotate {
    UIInterfaceOrientation interfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    return [FlashCardsAppDelegate shouldAutorotate:interfaceOrientation];
}

- (DBRestClient*)restClient {
    if (!restClient) {
        restClient = [[DBRestClient alloc] initWithSession:[DBSession sharedSession]];
        restClient.delegate = self;
    }
    return restClient;
}

# pragma mark -
# pragma mark Alert view functions

#pragma mark -
#pragma mark MBProgressHUDDelegate methods

- (void)hudWasHidden:(MBProgressHUD *)hud {
    // Remove HUD from screen when the HUD was hidded
    [hud removeFromSuperview];
    hud = nil;
}


# pragma mark -
# pragma mark Event functions

- (IBAction) confirmRestore:(id)sender {
    // ifdef LITE
    if (![FlashCardsCore hasFeature:@"Backup"]) {
        [FlashCardsCore showPurchasePopup:@"Backup"];
        return;
    }
    
    RIButtonItem *restoreItem = [RIButtonItem item];
    restoreItem.label = NSLocalizedStringFromTable(@"Restore Now", @"Backup", @"otherButtonTitles");
    restoreItem.action = ^{
        [FlashCardsCore setSetting:@"appIsSyncing" value:@NO];
        [self beginRestore:nil];
    };

    RIButtonItem *cancelItem = [RIButtonItem item];
    cancelItem.label = NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"cancelButtonTitle");
    cancelItem.action = ^{
    };

    NSString *message;
    if ([FlashCardsCore appIsSyncing]) {
        message = NSLocalizedStringFromTable(@"Are you sure you want to restore this database file? It will turn off automatic sync and replace your current data with this backup version.", @"Backup", @"message");
    } else {
        message = NSLocalizedStringFromTable(@"Are you sure you want to restore this database file? Please make sure that your current database is backed up before restoring to a previous version.", @"Backup", @"message");
    }
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@""
                                                    message:message
                                           cancelButtonItem:cancelItem
                                           otherButtonItems:restoreItem, nil];
    [alert show];
}
- (IBAction) beginRestore:(id)sender {
    restoreToolbar.hidden = NO;
    restoreProgress.progress = 0.0;
    NSString *tempStorePath = [[FlashCardsCore documentsDirectory] stringByAppendingPathComponent: @"FlashCards-Temp.sqlite"];
    /* Loads the file contents at the given root/path and stores the result into destinationPath */
    [[self restClient] loadFile:fileInfo.path intoPath:tempStorePath];
    [Flurry logEvent:@"Backup/RestoreFile"];
    [[FlashCardsCore appDelegate] setShouldCancelTICoreDataSyncIdCreation:YES];
}
- (IBAction) cancelRestore:(id)sender {
    [[self restClient] cancelAllRequests];
    restoreToolbar.hidden = YES;
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 2;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    if (section == 0) {
        return 2;
    } else {
        return 1;
    }
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier];
    }
    
    // Configure the cell...
    [self configureCell:cell atIndexPath:indexPath];
    
    return cell;
}


- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            cell.textLabel.text = NSLocalizedStringFromTable(@"Backup Date", @"Backup", @"");
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            [dateFormatter setDateStyle:NSDateFormatterShortStyle];
            [dateFormatter setTimeStyle:NSDateFormatterShortStyle];
            cell.detailTextLabel.text = [dateFormatter stringFromDate:fileInfo.lastModifiedDate];
        } else {
            cell.textLabel.text = NSLocalizedStringFromTable(@"Size", @"Backup", @"file size");
            cell.detailTextLabel.text = fileInfo.humanReadableSize;
        }
        cell.userInteractionEnabled = NO;
        cell.accessoryType = UITableViewCellAccessoryNone;
    } else {
        cell.textLabel.text = NSLocalizedStringFromTable(@"Restore Backup Now", @"Backup", @"");
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        cell.userInteractionEnabled = YES;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
}

#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    [self tableView:tableView didSelectRowAtIndexPath:indexPath];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        return;
    }
    
    [self confirmRestore:nil];
    
    [self.myTableView deselectRowAtIndexPath:indexPath animated:YES];
    
    
}


# pragma mark -
# pragma mark DBRestClientDelegate functions - load file

- (void)restClient:(DBRestClient*)client loadedFile:(NSString*)destPath {

    restoreToolbar.hidden = YES;
    @autoreleasepool {
        [FlashCardsCore setSetting:@"appIsSyncing" value:@NO];
        [[FlashCardsCore appDelegate]
         performSelectorInBackground:@selector(loadRestoreFile) withObject:nil];
    }

}
- (void)restClient:(DBRestClient*)client loadProgress:(CGFloat)progress forFile:(NSString*)destPath {
    restoreProgress.progress = progress;
}
- (void)restClient:(DBRestClient*)client loadFileFailedWithError:(NSError*)error {
    restoreToolbar.hidden = YES;
    if (error.code == -1009 && error.domain == NSURLErrorDomain) {
        FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"Error", @"Error", @"UIAlert title"),
                                   NSLocalizedStringFromTable(@"You are not connected to the internet.", @"Error", @"message"));
        return;
    }
    if (error.code == 404) {
        FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"Error", @"Error", @"UIAlert title"),
                                   [NSString stringWithFormat:NSLocalizedStringFromTable(@"Error: file not found.\n\nError info: %@ %@", @"Error", @"message"), error, [error userInfo]]);
        return;
    }
    FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"Error", @"Error", @"UIAlert title"),
                               [NSString stringWithFormat:NSLocalizedStringFromTable(@"Error downloading data: %@, %@", @"Error", @"message"), error, [error userInfo]]);
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
