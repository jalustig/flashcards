//
//  BackupRestoreCreateFolderViewController.m
//  FlashCards
//
//  Created by Jason Lustig on 7/30/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import "FlashCardsAppDelegate.h"
#import "FlashCardsCore.h"

#import "BackupRestoreCreateFolderViewController.h"

@implementation BackupRestoreCreateFolderViewController

@synthesize folderNameLabel;
@synthesize folderNameField;
@synthesize folderExplanationLabel;
@synthesize activityIndicator, currentDirectoryPath;
@synthesize popToViewControllerIndex;
@synthesize restClient;

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
    
    self.title = NSLocalizedStringFromTable(@"Create Folder", @"Backup", @"UIView title");
    
    folderNameLabel.text = NSLocalizedStringFromTable(@"Name of New Folder:", @"Backup", @"UILabel");
    folderExplanationLabel.text = NSLocalizedStringFromTable(@"Create a new folder and use it to store your FlashCards++ backup files:", @"Backup", @"UITextField");
    
    UIBarButtonItem *saveButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector(saveEvent:)];
    saveButton.enabled = YES;
    self.navigationItem.rightBarButtonItem = saveButton;
    
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
# pragma mark Event functions

- (IBAction) saveEvent:(id)sender {
    [folderNameField resignFirstResponder];
    
    NSString *folderName = [folderNameField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([folderName length] == 0) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Error", @"Error", @"UIAlert title")
                                                         message:NSLocalizedStringFromTable(@"You did not enter a name for your new folder.", @"Backup", @"message")
                                                        delegate:self
                                               cancelButtonTitle:NSLocalizedStringFromTable(@"OK", @"FlashCards", @"cancelButtonTitle")
                                               otherButtonTitles:nil];
        [alert show];
        return;
    }
    
    // As per http://stackoverflow.com/questions/938095/nsstring-number-of-occurrences-of-a-character
    NSArray *badCharacters = [NSArray arrayWithObjects:@".", @"/", @"\\", nil];
    NSScanner *scanner = [NSScanner scannerWithString:folderName];
    int numberOfChar = 0;
    NSString *temp;
    NSString *myChar;
    for (int i = 0; i < [badCharacters count]; i++) {
        myChar = [badCharacters objectAtIndex:i];
        [scanner setScanLocation:0];
        while(![scanner isAtEnd]) {
            [scanner scanUpToString:myChar intoString:&temp];
            if (![scanner isAtEnd]) {
                numberOfChar++;
            }
            [scanner scanString:myChar intoString:nil];
        }
    }    
    // TODO: Make sure that the folder name does not include a "." or "/" character
    if (numberOfChar > 0) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Invalid Folder Name", @"Backup", @"UIAlert title")
                                                         message:NSLocalizedStringFromTable(@"Please enter a valid name for your new folder; it may not contain forward-slashes, back-slashes, or periods.", @"Backup", @"message")
                                                        delegate:self
                                               cancelButtonTitle:NSLocalizedStringFromTable(@"OK", @"FlashCards", @"cancelButtonTitle")
                                            otherButtonTitles:nil];
        [alert show];
        return;
    }

    [[self restClient] createFolder:[NSString stringWithFormat:@"%@/%@", currentDirectoryPath, folderName]];
    [activityIndicator startAnimating];
}

# pragma mark -
# pragma mark DBRestClientDelegate functions - create folder

// Folder is the metadata for the newly created folder
- (void)restClient:(DBRestClient*)client createdFolder:(DBMetadata*)folder {
    [activityIndicator stopAnimating];
    
    [FlashCardsCore setSetting:@"dropboxBackupFilePath" value:folder.path];
    
    
    /*
     
     View controller stack:
     
     0) Collections
     1) BackupRestore
     2) BackupRestoreSettings
     
     */
    
    [self.navigationController popToViewController:[[self.navigationController viewControllers] objectAtIndex:popToViewControllerIndex] animated:YES];
    
    
}

// [error userInfo] contains the root and path
- (void)restClient:(DBRestClient*)client createFolderFailedWithError:(NSError*)error {

    [activityIndicator stopAnimating];
    
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
    
    if (error.code == 403) {
        FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"Error", @"Error", @"UIAlert title"),
                                   [NSString stringWithFormat:NSLocalizedStringFromTable(@"A file or directory named \"%@\" already exists in this location in your Dropbox.\n\nError info: %@ %@", @"Error", @"message"), [[error userInfo] valueForKey:@"path"], error, [error userInfo]]);
        return;
    }
    
    FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"Error", @"Error", @"UIAlert title"),
                               [NSString stringWithFormat:NSLocalizedStringFromTable(@"Error: %@ (%@)", @"Error", @"message"), error, [error userInfo]]);

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
    folderNameField = nil;
    restClient = nil;
    activityIndicator = nil;
}




@end
