//
//  BackupRestoreSettingsViewController.m
//  FlashCards
//
//  Created by Jason Lustig on 7/29/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import "FlashCardsAppDelegate.h"
#import "FlashCardsCore.h"

#import "BackupRestoreSettingsViewController.h"
#import "BackupRestoreSelectFolderViewController.h"
#import "BackupRestoreViewController.h"
#import "RootViewController.h"

#import "BackupRestoreListFilesViewController.h"

@implementation BackupRestoreSettingsViewController

@synthesize unlinkDropboxButton;

#pragma mark -
#pragma mark View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = NSLocalizedStringFromTable(@"Backup Settings", @"Backup", @"UIView title");
    
    [unlinkDropboxButton setTitle:NSLocalizedStringFromTable(@"Unlink Dropbox", @"Dropbox", @"") forState:UIControlStateNormal]; 
    [unlinkDropboxButton setTitle:NSLocalizedStringFromTable(@"Unlink Dropbox", @"Dropbox", @"") forState:UIControlStateSelected];
    
    UIViewController* vc = (UIViewController*)[self.navigationController.viewControllers objectAtIndex:([self.navigationController.viewControllers count]-2)];
    if ([vc isKindOfClass:[BackupRestoreListFilesViewController class]] &&
        [vc respondsToSelector:@selector(setSettingsUpdated:)]) {
        // so it will update the list of files when we return to it.
        [(BackupRestoreListFilesViewController*)vc setSettingsUpdated:YES];
    }
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;


}


- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.tableView reloadData];
}

- (IBAction) unlinkDropbox:(id)sender {
    [[DBSession sharedSession] unlinkAll];
    [[[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Account Unlinked!", @"Dropbox", @"UIView title") 
                                 message:NSLocalizedStringFromTable(@"Your dropbox account has been unlinked", @"Dropbox", @"message") 
                                delegate:nil
                       cancelButtonTitle:NSLocalizedStringFromTable(@"OK", @"FlashCards", @"cancelButtonTitle")
                       otherButtonTitles:nil]
         show];
    
    
    [self.navigationController popToViewController:[[self.navigationController viewControllers] objectAtIndex:0] animated:YES];
    
}

/*
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}
*/
/*
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}
*/
/*
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}
*/
/*
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}
*/

- (BOOL)shouldAutorotate {
    UIInterfaceOrientation interfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    return [FlashCardsAppDelegate shouldAutorotate:interfaceOrientation];
}

# pragma mark -
# pragma mark DBLoginControllerDelegate functions
/*
- (void)loginControllerDidLogin:(DBLoginController*)controller {
}
- (void)loginControllerDidCancel:(DBLoginController*)controller {
}
 */

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 2;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    
    if (section == 0) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        if ([defaults valueForKey:@"lastBackupDate"]) {
            return 2;
        }
        return 1;
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

    // users can't select the table cell:
    if (indexPath.section == 0) {
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    
    if (indexPath.section == 1) {
        cell.textLabel.text = NSLocalizedStringFromTable(@"Choose Backup Location", @"Backup", @"");
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return cell;
    }
    
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (indexPath.row == 0) {
        cell.textLabel.text = NSLocalizedStringFromTable(@"Backups", @"Backup", @"");
        cell.detailTextLabel.text = (NSString*)[FlashCardsCore getSetting:@"dropboxBackupFilePath"];
    } else if (indexPath.row == 1) {
        cell.textLabel.text = NSLocalizedStringFromTable(@"Last Backup", @"Backup", @"");
        
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateStyle:NSDateFormatterShortStyle];
        [dateFormatter setTimeStyle:NSDateFormatterNoStyle];
        
        cell.detailTextLabel.text = [dateFormatter stringFromDate:[defaults valueForKey:@"lastBackupDate"]];
    }
    
    // Configure the cell...
    
    return cell;
}


/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/


/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:YES];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/


/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/


/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/


#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    [self tableView:tableView didSelectRowAtIndexPath:indexPath];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        return;
    }
    BackupRestoreSelectFolderViewController *vc = [[BackupRestoreSelectFolderViewController alloc] initWithNibName:@"BackupRestoreSelectFolderViewController" bundle:nil];
    vc.currentDirectoryPath = @"/";
    
    /*
     
     View controller stack:
     
     0) Collections
     1) BackupRestore
     2) BackupRestoreSettings
     
     */
    vc.popToViewControllerIndex = 2;
    
    vc.currentBackupPath = (NSString*)[FlashCardsCore getSetting:@"dropboxBackupFilePath"];
    
    [self.navigationController pushViewController:vc animated:YES];
}

#pragma mark -
#pragma mark Memory management

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Relinquish ownership any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
    // Relinquish ownership of anything that can be recreated in viewDidLoad or on demand.
    // For example: self.myOutlet = nil;
}




@end

