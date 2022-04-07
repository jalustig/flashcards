//
//  BackupRestoreSettingsViewController.h
//  FlashCards
//
//  Created by Jason Lustig on 7/29/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface BackupRestoreSettingsViewController : UITableViewController

- (IBAction) unlinkDropbox:(id)sender;

@property (nonatomic, weak) IBOutlet UIButton *unlinkDropboxButton;

@end
