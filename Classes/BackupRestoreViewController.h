//
//  BackupRestoreViewController.h
//  FlashCards
//
//  Created by Jason Lustig on 7/29/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface BackupRestoreViewController : UIViewController

// Link Dropbox View:
- (IBAction) didPressLink:(id)sender;
- (void)goToBackupRestoreChooseFile;
- (void)checkDropboxStatus;

@property (nonatomic, weak) IBOutlet UITextView *backupExplanationLabel;
@property (nonatomic, weak) IBOutlet UIButton *linkDropboxButton;


@end
