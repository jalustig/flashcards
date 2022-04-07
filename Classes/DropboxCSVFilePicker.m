//
//  DropboxCSVFilePicker.m
//  FlashCards
//
//  Created by Jason Lustig on 10/14/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import "FlashCardsAppDelegate.h"
#import "FlashCardsCore.h"

#import "DropboxCSVFilePicker.h"
#import "CardSetImportViewController.h"

#import "MBProgressHUD.h"

#import "RootViewController.h"

#import "FCCardSet.h"
#import "FCCollection.h"

@implementation DropboxCSVFilePicker

@synthesize myTableView;
@synthesize loadingCell, loadingCellActivityIndicator;
@synthesize currentDirectoryInfo, currentDirectoryPath, fileList, directoryList, currentBackupPath;
@synthesize selectedFile;

@synthesize cardSet, collection, cardSetCreateMode, popToViewControllerIndex, isLoadingDirectoryList;
@synthesize restClient, dateFormatter;
@synthesize HUD;
@synthesize selectedIndexPathsSet;
@synthesize hasAlreadyTriedToLinkDropbox;

@synthesize csv;

@synthesize returnToHomeFolderButton, unlinkDropboxButton, loadingFileListLabel, loadingFileListCancelButton;

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
    
    self.title = NSLocalizedStringFromTable(@"Choose Spreadsheet", @"Import", @"UIView title");
    
    returnToHomeFolderButton.title = NSLocalizedStringFromTable(@"Return to Home Folder", @"Import", @"UIBarButtonItem");
    unlinkDropboxButton.title = NSLocalizedStringFromTable(@"Unlink Dropbox", @"Dropbox", @"UIBarButtonItem");
    
    loadingFileListLabel.text = NSLocalizedStringFromTable(@"Loading...", @"FlashCards", @"UILabel");
    [loadingFileListCancelButton setTitle:NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"UILabel") forState:UIControlStateNormal]; 
    [loadingFileListCancelButton setTitle:NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"UILabel") forState:UIControlStateSelected];
        
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelEvent)];
    self.navigationItem.leftBarButtonItem = cancelButton;
    
    UIBarButtonItem *reloadButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(loadDirectoryList:)];
    self.navigationItem.rightBarButtonItem = reloadButton;
    
    dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateStyle:NSDateFormatterShortStyle];
    [dateFormatter setTimeStyle:NSDateFormatterNoStyle];
    
    fileList = [[NSMutableArray alloc] initWithCapacity:0];
    directoryList = [[NSMutableArray alloc] initWithCapacity:0];
    
    self.selectedIndexPathsSet = [[NSMutableSet alloc] initWithCapacity:0];
    
    currentDirectoryPath = [NSString stringWithString:(NSString*)[FlashCardsCore getSetting:@"dropboxCsvFilePath"]];
    if (![[DBSession sharedSession] isLinked]) {
        hasAlreadyTriedToLinkDropbox = YES;
        
        [FlashCardsCore setSetting:@"dropboxCsvFilePath" value:@"/"];
        currentDirectoryPath = [NSString stringWithString:(NSString*)[FlashCardsCore getSetting:@"dropboxCsvFilePath"]];
        
        RootViewController *rootVC = (RootViewController*)[self.navigationController.viewControllers objectAtIndex:0];

        [[DBSession sharedSession] linkFromController:rootVC];
    } else {
        hasAlreadyTriedToLinkDropbox = NO;
        [self loadDirectoryList:nil];
    }
    
}

- (void)viewDidAppear:(BOOL)animated {
    // we already tried to link, but the user has canceled. send them back:
    if (hasAlreadyTriedToLinkDropbox && ![[DBSession sharedSession] isLinked]) {
        [self.navigationController popViewControllerAnimated:NO];
    } else if ([[DBSession sharedSession] isLinked]) {
        [self loadDirectoryList:nil];
    }
    [super viewDidAppear:animated];
}

// Override to allow orientations other than the default portrait orientation.
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


#pragma mark -
#pragma mark MBProgressHUDDelegate methods

- (void)hudWasHidden:(MBProgressHUD *)hud {
    // Remove HUD from screen when the HUD was hidded
    [hud removeFromSuperview];
    hud = nil;

    if (self.navigationItem.rightBarButtonItem) {
        self.navigationItem.leftBarButtonItem.enabled = YES;
        self.navigationItem.rightBarButtonItem.enabled = YES;
    }
}

# pragma mark -
# pragma mark Event functions

- (void) cancelEvent {
    [self.navigationController popViewControllerAnimated:YES];
}

- (IBAction) unlinkDropbox:(id)sender {
    [[DBSession sharedSession] unlinkAll];
    // NSLog(@"Is Linked? %@", [[DBSession sharedSession] isLinked] ? @"YES" : @"NO");
    [[[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Account Unlinked!", @"Dropbox", @"")
                                 message:NSLocalizedStringFromTable(@"Your dropbox account has been unlinked", @"Dropbox", @"") 
                                delegate:nil
                       cancelButtonTitle:NSLocalizedStringFromTable(@"OK", @"FlashCards", @"")
                       otherButtonTitles:nil]
     show];
    
    [self.navigationController popViewControllerAnimated:YES];
}
- (IBAction) returnToHomeFolder:(id)sender {
    currentDirectoryPath = [NSString stringWithFormat:@"/"];
    [self loadDirectoryList:nil];
}


- (IBAction) loadDirectoryList:(id)sender {
    
    // save the default:
    [FlashCardsCore setSetting:@"dropboxCsvFilePath" value:currentDirectoryPath];
    
    [self.loadingCellActivityIndicator startAnimating];
    isLoadingDirectoryList = YES;
    self.navigationItem.rightBarButtonItem.enabled = NO;
    [[self restClient] loadMetadata:currentDirectoryPath];
    [self.myTableView reloadData];
}
- (IBAction) cancelLoadDirectoryList:(id)sender {
    [self.loadingCellActivityIndicator stopAnimating];
    isLoadingDirectoryList = NO;
    self.navigationItem.rightBarButtonItem.enabled = YES;
    [[self restClient] cancelAllRequests];
    [self.myTableView reloadData];
}


# pragma mark -
# pragma mark DBLoginControllerDelegate methods

/*
- (void)loginControllerDidLogin:(DBLoginController*)controller {
    
    // save the user's e-mail info:
    [FlashCardsCore setSetting:@"dropboxEmailAddress" value:loginController.emailField.text];
    
    // update the view:
    [self loadDirectoryList:nil];
}

- (void)loginControllerDidCancel:(DBLoginController*)controller {
    [self.navigationController popViewControllerAnimated:YES];
}
*/

# pragma mark -
# pragma mark DBRestClientDelegate functions - metadata

- (void)restClient:(DBRestClient*)client 
    loadedMetadata:(DBMetadata*)metadata {
    
    [self.loadingCellActivityIndicator stopAnimating];
    self.navigationItem.rightBarButtonItem.enabled = YES;
    isLoadingDirectoryList = NO;

    if (!metadata.isDirectory) {
        // throw error - it is not a directory
        
        [[[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Error", @"Error", @"UIAlert title")
                                     message:[NSString stringWithFormat:NSLocalizedStringFromTable(@"It appears that your backup location (\"%@\") is not a directory. Please select a new location for backups.", @"Error", @"message"), metadata.path]
                                    delegate:nil
                           cancelButtonTitle:NSLocalizedStringFromTable(@"OK", @"FlashCards", @"cancelButtonTitle")
                           otherButtonTitles:nil]
         show];        
        
        // setCurrentFolder.enabled = NO;
        [directoryList removeAllObjects];
        [fileList removeAllObjects];
        [self.myTableView reloadData];
        
        return;
    }
    
    currentDirectoryInfo = metadata;
    
    [directoryList removeAllObjects];
    [directoryList addObjectsFromArray:metadata.contents];
    [fileList removeAllObjects];
    [fileList addObjectsFromArray:metadata.contents];
    
    // sort it by name:
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"path" ascending:YES];
    [directoryList sortUsingDescriptors:[NSArray arrayWithObject:sortDescriptor]];
    [fileList sortUsingDescriptors:[NSArray arrayWithObject:sortDescriptor]];

    // filter only directories:
    NSPredicate *predicate;
    predicate = [NSPredicate predicateWithFormat:@"self.isDirectory = YES"];
    [directoryList filterUsingPredicate:predicate];
    predicate = [NSPredicate predicateWithFormat:@"self.isDirectory = NO and (self.path endswith[c] \".csv\" or self.path endswith[c] \".txt\" or self.path endswith[c] \".xls\" or self.path endswith[c] \".xlsx\")"];
    [fileList filterUsingPredicate:predicate];
    
    [self.myTableView reloadData];
    
}

- (void)restClient:(DBRestClient*)client 
metadataUnchangedAtPath:(NSString*)path {
    
    // NSLog(@"Metadata unchanged!");
}

- (void)restClient:(DBRestClient*)client 
loadMetadataFailedWithError:(NSError*)error {
    
    [self.loadingCellActivityIndicator stopAnimating];
    isLoadingDirectoryList = NO;
    self.navigationItem.rightBarButtonItem.enabled = YES;
    [self.myTableView reloadData];
    
    [fileList removeAllObjects];
    [directoryList removeAllObjects];
    
    NSLog(@"Error loading metadata: %@", error);
    
    if (error.code == -1009 && error.domain == NSURLErrorDomain) {
        FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"Error", @"Error", @"UIAlert title"),
                                   NSLocalizedStringFromTable(@"You are not connected to the internet.", @"Error", @"message"));
        return;
    }
    
    if (error.code == 404) {
        
        FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"Error: Directory Not Found", @"Error", @"UIAlert title"),
                                   [NSString stringWithFormat:NSLocalizedStringFromTable(@"The directory \"%@\" could not be found in your Dropbox.\n\nError info: %@ %@", @"Error", @"message"), [[error userInfo] valueForKey:@"path"], error, [error userInfo]]);

        // save the default:
        currentDirectoryPath = [NSString stringWithFormat:@"/"];

        [self loadDirectoryList:nil];

        return;
    }
    
    FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"Error", @"Error", @"UIAlert title"),
                               [NSString stringWithFormat:NSLocalizedStringFromTable(@"Error: %@ (%@)", @"Error", @"message"), error, [error userInfo]]);
    
    // save the default:
    currentDirectoryPath = [NSString stringWithFormat:@"/"];

    [self loadDirectoryList:nil];
    
}

# pragma mark -
# pragma mark DBRestClientDelegate functions - load file

- (void)restClient:(DBRestClient*)client loadedFile:(NSString*)destPath {
    
    if (HUD) {
        [HUD hide:YES];
    }

    csv = [[ImportCSV alloc] init];
    csv.cardSet.creationDate = selectedFile.lastModifiedDate; // creation date from Dropbox!
    [csv setDelegate:self];
    [csv setLocalFilePath:destPath];
    [csv setDropboxFilePath:selectedFile.path];
    [csv processLocalFile];
}
- (void)restClient:(DBRestClient*)client loadProgress:(CGFloat)progress forFile:(NSString*)destPath {
    FCLog(@"%1.2f", progress);
}
- (void)restClient:(DBRestClient*)client loadFileFailedWithError:(NSError*)error {
    
    if (HUD) {
        [HUD hide:YES];
    }
    
    // hide the progress bars:
    
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
                               [NSString stringWithFormat:NSLocalizedStringFromTable(@"Error downloading data: %@ %@", @"Error", @"message"), error, [error userInfo]]);
}


#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    if (isLoadingDirectoryList) {
        return 1;
    }
    int numSections = 1;
    if ([directoryList count] > 0) {
        numSections++;
    }
    if (![currentDirectoryPath isEqual:@"/"]) {
        numSections++;
    }
    return numSections;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    if (isLoadingDirectoryList) {
        return 1;
    }
    if (section == 0) {
        // Files
        if ([fileList count] > 0) {
            return [fileList count];
        } else {
            return 1;
        }
    } else if (section == 1) {
        if ([directoryList count] > 0) {
            return [directoryList count];
        } else {
            // we'll be showing the prev directory item
            return 1;
        }
    } else {
        // section == 3 --> return to prev directory
        return 1;
    }
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (isLoadingDirectoryList) {
        return loadingCell;
    }
    static NSString *CellIdentifier;
    UIImage *image = [UIImage imageNamed:@"icon-undo.png"];
    DBMetadata *fileInfo;
    if (indexPath.section == 0) {
        // Files
        CellIdentifier = @"FileCell";
        if ([fileList count] > 0) {
            fileInfo = [fileList objectAtIndex:indexPath.row];
            if ([fileInfo.icon isEqual:@"page_white_excel"]) {
                image = [UIImage imageNamed:@"excel32.png"];
            } else {
                image = [UIImage imageNamed:@"page_white_text32.png"];
            }
        }
        // return [fileList count];
    } else if (indexPath.section == 1) {
        if ([directoryList count] > 0) {
            CellIdentifier = @"DirectoryCell";
            image = [UIImage imageNamed:@"folder32.png"];  
            fileInfo = [directoryList objectAtIndex:indexPath.row];
            // return [directoryList count];
        } else {
            // we'll be showing the prev directory item
            CellIdentifier = @"PrevDirectoryCell";
            image = [UIImage imageNamed:@"icon-undo.png"];  
            // return 1;
        }
    } else {
        // section == 3 --> return to prev directory
        CellIdentifier = @"PrevDirectoryCell";
        image = [UIImage imageNamed:@"icon-undo.png"];  
        // return 1;
    }

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
    
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

    if ([CellIdentifier isEqual:@"PrevDirectoryCell"]) {
        cell.accessoryType = UITableViewCellAccessoryNone;
        [cell.imageView setImage:image];
        NSMutableArray *prevDirs = [NSMutableArray arrayWithArray:[currentDirectoryInfo.path componentsSeparatedByString:@"/"]];
        if ([prevDirs count] > 1) {
            [prevDirs removeLastObject];
        }
        cell.textLabel.text = [prevDirs lastObject];
        if ([cell.textLabel.text length] == 0) {
            cell.textLabel.text = NSLocalizedStringFromTable(@"Home Folder", @"Import", @"");
        }
        cell.userInteractionEnabled = YES;
    } else {
        if (!(indexPath.section == 0 && [fileList count] == 0)) {
            [cell.imageView setImage:image];
            int i;
            if ([currentDirectoryPath isEqual:@"/"]) {
                i = 0;
            } else {
                i = 1;
            }
            cell.textLabel.text = [fileInfo.path stringByReplacingCharactersInRange:NSMakeRange(0, [currentDirectoryPath length]+i) withString:@""];
            // int length = [cell.textLabel.text length];
            // cell.textLabel.text = [cell.textLabel.text stringByReplacingCharactersInRange:NSMakeRange(length-[@".sqlite" length], [@".sqlite" length]) withString:@""];
            if (!fileInfo.isDirectory) {
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ - %@", [dateFormatter stringFromDate:fileInfo.lastModifiedDate], fileInfo.humanReadableSize, nil];
            }
            cell.userInteractionEnabled = YES;
        } else {
            [cell.imageView setImage:nil];
            cell.textLabel.text = NSLocalizedStringFromTable(@"No .XSL or .CSV Files Found", @"Import", @"");
            cell.detailTextLabel.text = @"";
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.userInteractionEnabled = NO;
        }
    }
    
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (isLoadingDirectoryList) {
        return @"";
    }
    if (section == 0) {
        // Files
        return NSLocalizedStringFromTable(@"Excel or CSV (Spreadsheet) Files", @"Import", @"");
    } else if (section == 1) {
        if ([directoryList count] > 0) {
            return NSLocalizedStringFromTable(@"Folders", @"Import", @"");
        } else {
            // we'll be showing the prev directory item
            return NSLocalizedStringFromTable(@"Go To Parent Folder", @"Import", @"");
        }
    } else {
        // section == 3 --> return to prev directory
        return NSLocalizedStringFromTable(@"Go To Parent Folder", @"Import", @"");
    }
}

#pragma mark -
#pragma mark ImportCSVDelegate Functions

- (void)importClient:(ImportCSV *)importCSV csvFileLoadFailedWithError:(NSError *)error {
    [HUD hide:YES];
    
    if (error.code == kCSVErrorFileSizeExceeded) {
        FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"Error", @"Error", @"UIAlert title"),
                                   NSLocalizedStringFromTable(@"This file exceeds the maximum file size for processing (8 megabytes). Please select a smaller file.", @"Import", @"message"));
        return;
    }
    FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"Error", @"Error", @"UIAlert title"),
                               [NSString stringWithFormat:NSLocalizedStringFromTable(@"There was an error reading your data file, please ensure that it has not been corrupted: %@ (%d)", @"Error", @"message"), 
                                [[error userInfo] valueForKey:@"errorMessage"],
                                error.code]);
}

- (void)csvFileDidLoad:(ImportCSV *)importCSV {
    
    [HUD hide:YES];
    CardSetImportViewController *vc = [[CardSetImportViewController alloc] initWithNibName:@"CardSetImportViewController" bundle:nil];
    
    vc.shouldImmediatelyImportTerms = NO;
    vc.shouldImmediatelyPressImportButton = NO;
    vc.hasCheckedIfCardSetWithIdExistsOnDevice = NO;
    vc.importMethod = @"DropboxCSV";
    vc.importFunction = @"Dropbox";
    vc.cardSet = self.cardSet;
    vc.collection = self.collection;
    
    vc.allCardSets = [NSMutableArray arrayWithObjects:importCSV.cardSet, nil];
    vc.popToViewControllerIndexSave = self.popToViewControllerIndex;
    vc.popToViewControllerIndexCancel = [self.navigationController.viewControllers count]-1;
    vc.cardSetCreateMode = self.cardSetCreateMode;
    
    [self.navigationController pushViewController:vc animated:YES];

}

#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.myTableView deselectRowAtIndexPath:indexPath animated:YES];
    if (isLoadingDirectoryList) {
        return;
    }
    DBMetadata *fileInfo;
    if (indexPath.section == 0) {

        HUD = [[MBProgressHUD alloc] initWithView:self.view];
        
        // Add HUD to screen
        [self.view addSubview:HUD];
        
        
        // Files
        fileInfo = (DBMetadata*)[fileList objectAtIndex:indexPath.row];

        NSArray *fileParts = [fileInfo.path componentsSeparatedByString:@"/"];
        NSString *fileName = [fileParts lastObject];
        fileParts = [fileName componentsSeparatedByString:@"."];
        NSString *extension = [[fileParts lastObject] lowercaseString];
        if (!([extension isEqualToString:@"csv"] || [extension isEqualToString:@"txt"])) {
            if (fileInfo.totalBytes > kMaxFileSize) {
                FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"Error", @"Error", @"UIAlert title"),
                                           NSLocalizedStringFromTable(@"This file exceeds the maximum file size for processing (8 megabytes). Please select a smaller file.", @"Import", @"message"));
                return;
            }
        }
        // Regisete for HUD callbacks so we can remove it from the window at the right time
        HUD.delegate = self;
        HUD.minShowTime = 2.0;
        HUD.labelText = NSLocalizedStringFromTable(@"Downloading Cards", @"Import", @"HUD");
        [HUD show:YES];
        
        self.selectedFile = fileInfo;
        NSString *localFilePath = [[FlashCardsCore documentsDirectory] stringByAppendingPathComponent: @"CSVFile-Temp.csv"];
        [[self restClient] loadFile:fileInfo.path intoPath:localFilePath];
            
        return;
    } else if (indexPath.section == 1) {
        if ([directoryList count] > 0) {
            fileInfo = [directoryList objectAtIndex:indexPath.row];
            // return [directoryList count];
            
            currentDirectoryPath = fileInfo.path;
            
            // load the files:
            [self loadDirectoryList:nil];
            
            return;
        }
    }
    
    // section == 3 --> return to prev directory

    NSMutableArray *prevDirs = [NSMutableArray arrayWithArray:[currentDirectoryInfo.path componentsSeparatedByString:@"/"]];
    [prevDirs removeLastObject];
    currentDirectoryPath = [NSString stringWithString:[prevDirs componentsJoinedByString:@"/"]];
    if ([currentDirectoryPath length] == 0) {
        currentDirectoryPath = [NSString stringWithFormat:@"/"];
    }

    // load the files:
    [self loadDirectoryList:nil];

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
