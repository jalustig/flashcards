//
//  BackupRestoreSelectFolderViewController.m
//  FlashCards
//
//  Created by Jason Lustig on 7/31/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import "FlashCardsAppDelegate.h"
#import "FlashCardsCore.h"

#import "BackupRestoreSelectFolderViewController.h"
#import "BackupRestoreCreateFolderViewController.h"
#import "BackupRestoreListFilesViewController.h"

@implementation BackupRestoreSelectFolderViewController

@synthesize myTableView, loadingCell, loadingCellActivityIndicator, setCurrentFolder;
@synthesize currentDirectoryPath, currentDirectory, directoryList, currentBackupPath;
@synthesize popToViewControllerIndex, isLoadingDirectoryList;
@synthesize restClient;
@synthesize loadingFolderListLabel, loadingFolderListCancelButton;

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
    
    isLoadingDirectoryList = NO;
    
    // set title:
    if ([currentDirectoryPath isEqual:@"/"]) {
        self.title = NSLocalizedStringFromTable(@"Backup Location", @"Backup", @"UIView title");
    }
    
    setCurrentFolder.title = NSLocalizedStringFromTable(@"Backup to Current Folder", @"Backup", @"UIBarButtonItem");
    loadingFolderListLabel.text = NSLocalizedStringFromTable(@"Loading...", @"FlashCards", @"UILabel");
    
    [loadingFolderListCancelButton setTitle:NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"UILabel") forState:UIControlStateNormal]; 
    [loadingFolderListCancelButton setTitle:NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"UILabel") forState:UIControlStateSelected];
    
    // set up top right item:
    UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(createFolder)];
    self.navigationItem.rightBarButtonItem = addButton;
    
    // set up array of objects:
    directoryList = [[NSMutableArray alloc] initWithCapacity:0];
    
    [self loadDirectoryList:nil];
}

- (void)viewDidAppear:(BOOL)animated {
    NSIndexPath* selection = [self.myTableView indexPathForSelectedRow];
    if (selection) {
        [self.myTableView deselectRowAtIndexPath:selection animated:YES];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[self restClient] cancelAllRequests];
    isLoadingDirectoryList = NO;
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
# pragma mark Event functions

- (IBAction) backupToCurrentFolder:(id)sender {
    [FlashCardsCore setSetting:@"dropboxBackupFilePath" value:currentDirectoryPath];
    

    /*
     
     View controller stack:
     
     0) Collections
     1) BackupRestore
     2) BackupRestoreSettings
     
     */

    [self.navigationController popToViewController:[[self.navigationController viewControllers] objectAtIndex:popToViewControllerIndex] animated:YES];
    
}
- (IBAction) loadDirectoryList:(id)sender {
    [self.loadingCellActivityIndicator startAnimating];
    isLoadingDirectoryList = YES;
    [[self restClient] loadMetadata:currentDirectoryPath];
    [self.myTableView reloadData];
}
- (IBAction) cancelLoadDirectoryList:(id)sender {
    [self.loadingCellActivityIndicator stopAnimating];
    isLoadingDirectoryList = NO;
    [[self restClient] cancelAllRequests];
    [self.myTableView reloadData];
}
- (void) createFolder {
    BackupRestoreCreateFolderViewController *vc = [[BackupRestoreCreateFolderViewController alloc] initWithNibName:@"BackupRestoreCreateFolderViewController" bundle:nil];
    vc.currentDirectoryPath = currentDirectoryPath;
    vc.popToViewControllerIndex = popToViewControllerIndex;
    [self.navigationController pushViewController:vc animated:YES];
}

# pragma mark -
# pragma mark DBRestClientDelegate functions - metadata

- (void)restClient:(DBRestClient*)client 
    loadedMetadata:(DBMetadata*)metadata {
    
    [self.loadingCellActivityIndicator stopAnimating];
    isLoadingDirectoryList = NO;
    
    if (!metadata.isDirectory) {
        // throw error - it is not a directory
        
        [[[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Error", @"Error", @"UIAlert title")
                                     message:[NSString stringWithFormat:NSLocalizedStringFromTable(@"It appears that your backup location (\"%@\") is not a directory. Please select a new location for backups.", @"Error", @"message"), metadata.path]
                                    delegate:nil
                           cancelButtonTitle:NSLocalizedStringFromTable(@"OK", @"FlashCards", @"cancelButtonTitle")
                        otherButtonTitles:nil]
         show];        
        
        setCurrentFolder.enabled = NO;
        [directoryList removeAllObjects];
        [self.myTableView reloadData];
        
        return;
    }
    
    currentDirectory = metadata;
    setCurrentFolder.enabled = YES;
    [directoryList removeAllObjects];
    [directoryList addObjectsFromArray:metadata.contents];
    
    // sort it by name:
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"path" ascending:YES];
    [directoryList sortUsingDescriptors:[NSArray arrayWithObject:sortDescriptor]];
    
    // filter only directories:
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"self.isDirectory = YES"];
    [directoryList filterUsingPredicate:predicate];
    
    [self.myTableView reloadData];
    
}

- (void)restClient:(DBRestClient*)client 
metadataUnchangedAtPath:(NSString*)path {
    
    NSLog(@"Metadata unchanged!");
}

- (void)restClient:(DBRestClient*)client 
loadMetadataFailedWithError:(NSError*)error {
    
    [self.loadingCellActivityIndicator stopAnimating];
    isLoadingDirectoryList = NO;
    [self.myTableView reloadData];
    
    NSLog(@"Error loading metadata: %@", error);
    
    if (error.code == -1009 && error.domain == NSURLErrorDomain) {
        FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"Error", @"Error", @"UIAlert title"),
                                   NSLocalizedStringFromTable(@"You are not connected to the internet.", @"Error", @"message"));
        return;
    }
    
    if (error.code == 404) {
        
        FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"Error: Directory Not Found", @"Error", @"UIAlert title"),
                                   [NSString stringWithFormat:NSLocalizedStringFromTable(@"The directory \"%@\" could not be found in your Dropbox.\n\nError info: %@ %@", @"Error", @"message"), [[error userInfo] valueForKey:@"path"], error, [error userInfo]]);
        return;
    }
    
    FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"Error", @"Error", @"UIAlert title"),
                               [NSString stringWithFormat:NSLocalizedStringFromTable(@"Error: %@ (%@)", @"Error", @"message"), error, [error userInfo]]);
}


#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    if (isLoadingDirectoryList) {
        return 1;
    }
    if ([directoryList count] == 0) {
        return 1;
    }
    return [directoryList count];
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (isLoadingDirectoryList) {
        return loadingCell;
    }
    static NSString *CellIdentifier;
    int style;
    if ([directoryList count] == 0) {
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


- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    if ([directoryList count] == 0) {
        cell.textLabel.text = NSLocalizedStringFromTable(@"No Sub-Folders Found", @"Backup", @"");
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        return;
    }
    
    DBMetadata *fileInfo = [directoryList objectAtIndex:indexPath.row];
    int i;
    if ([currentDirectoryPath isEqual:@"/"]) {
        i = 0;
    } else {
        i = 1;
    }
    cell.textLabel.text = [fileInfo.path stringByReplacingCharactersInRange:NSMakeRange(0, [currentDirectoryPath length]+i) withString:@""];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (isLoadingDirectoryList) {
        return;
    }
    if ([directoryList count] == 0) {
        return;
    }
    DBMetadata *fileInfo = [directoryList objectAtIndex:indexPath.row];
    NSString *path = fileInfo.path;
    if ([currentBackupPath isEqual:path]) {
        [cell setBackgroundColor:[UIColor yellowColor]];
        cell.detailTextLabel.text = NSLocalizedStringFromTable(@"Current Backup Location", @"Backup", @"");
    } else {
        if ([[currentBackupPath stringByAppendingString:@"/"] compare:[path stringByAppendingString:@"/"] options:NSCaseInsensitiveSearch range:NSMakeRange(0, [path length]+1)] == NSOrderedSame) {
            [cell setBackgroundColor:[UIColor yellowColor]];
        }
        cell.detailTextLabel.text = @"";
    }
}


#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([directoryList count] == 0) {
        return;
    }
    DBMetadata *fileInfo = [directoryList objectAtIndex:indexPath.row];
    
    BackupRestoreSelectFolderViewController *vc = [[BackupRestoreSelectFolderViewController alloc] initWithNibName:@"BackupRestoreSelectFolderViewController" bundle:nil];
    vc.currentDirectory = fileInfo;
    vc.currentDirectoryPath = fileInfo.path;
    vc.popToViewControllerIndex = popToViewControllerIndex;
    vc.currentBackupPath = currentBackupPath;

    // set the title:
    int i;
    if ([currentDirectoryPath isEqual:@"/"]) {
        i = 0;
    } else {
        i = 1;
    }
    vc.title = [vc.currentDirectoryPath stringByReplacingCharactersInRange:NSMakeRange(0, [currentDirectoryPath length]+i) withString:@""];
    [self.navigationController pushViewController:vc animated:YES];
    
}

# pragma mark -
# pragma mark Memory Functions

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
