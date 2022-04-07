//
//  BackupRestoreViewController.m
//  FlashCards
//
//  Created by Jason Lustig on 7/29/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import "FlashCardsAppDelegate.h"
#import "FlashCardsCore.h"

#import "RootViewController.h"
#import "BackupRestoreViewController.h"
#import "BackupRestoreListFilesViewController.h"

@implementation BackupRestoreViewController

@synthesize backupExplanationLabel, linkDropboxButton;

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
    
    self.title = NSLocalizedStringFromTable(@"Backup & Restore", @"Backup", @"UIView title");
    
    backupExplanationLabel.text = NSLocalizedStringFromTable(@"FlashCards++ uses the free Dropbox service to store backups in the cloud. Please sign in or create a free Dropbox account below to set up backups:", @"Backup", @"");

    [linkDropboxButton setTitle:NSLocalizedStringFromTable(@"Link Dropbox", @"Dropbox", @"") forState:UIControlStateNormal]; 
    [linkDropboxButton setTitle:NSLocalizedStringFromTable(@"Link Dropbox", @"Dropbox", @"") forState:UIControlStateSelected];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(checkDropboxStatus)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    
    // On iOS 4.0+ only, listen for foreground notification
    if(&UIApplicationWillEnterForegroundNotification != nil)
    {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(checkDropboxStatus)
                                                     name:UIApplicationWillEnterForegroundNotification
                                                   object:nil];
    }

    if ([[DBSession sharedSession] isLinked]) {
        [self goToBackupRestoreChooseFile];
    }

    
}

- (void)checkDropboxStatus {
    if ([[DBSession sharedSession] isLinked]) {
        [self goToBackupRestoreChooseFile];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [self checkDropboxStatus];
    [super viewDidAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
    [self checkDropboxStatus];
    [super viewDidAppear:animated];
}

- (BOOL)shouldAutorotate {
    UIInterfaceOrientation interfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    return [FlashCardsAppDelegate shouldAutorotate:interfaceOrientation];
}

# pragma mark -
# pragma mark Link Dropbox View functions

- (IBAction) didPressLink:(id)sender {
    if ([[DBSession sharedSession] isLinked]) {
        [self goToBackupRestoreChooseFile];
        return;
    }
    RootViewController *rootVC = (RootViewController*)[self.navigationController.viewControllers objectAtIndex:0];
    [[DBSession sharedSession] linkFromController:rootVC];
}

- (void) goToBackupRestoreChooseFile {
    
    NSMutableArray *viewControllers = [[NSMutableArray alloc] initWithArray:[self.navigationController viewControllers]];
    while ([viewControllers count] > 1) {
        [viewControllers removeLastObject];
    }
    
    BackupRestoreListFilesViewController *vc = [[BackupRestoreListFilesViewController alloc] initWithNibName:@"BackupRestoreListFilesViewController" bundle:nil];
    [viewControllers addObject:vc];

    [self.navigationController setViewControllers:viewControllers animated:YES];
    
}



# pragma mark -
# pragma mark DBLoginControllerDelegate methods

/*
- (void)loginControllerDidLogin:(DBLoginController*)controller {
    
    // save the user's e-mail info:
    [FlashCardsCore setSetting:@"dropboxEmailAddress" value:loginController.emailField.text];
    
    // update the view:
    [self goToBackupRestoreChooseFile];
}

- (void)loginControllerDidCancel:(DBLoginController*)controller {
    
}
 */

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
