//
//  BackupRestoreFileViewController.h
//  FlashCards
//
//  Created by Jason Lustig on 7/30/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "MBProgressHUD.h"

@class DBMetadata;

@interface BackupRestoreFileViewController : UIViewController <UITableViewDelegate, UIAlertViewDelegate, DBRestClientDelegate, MBProgressHUDDelegate>

- (IBAction) confirmRestore:(id)sender;
- (IBAction) beginRestore:(id)sender;
- (IBAction) cancelRestore:(id)sender;
- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath;

@property (nonatomic, strong) DBRestClient *restClient;
@property (nonatomic, strong) DBMetadata *fileInfo;
@property (nonatomic, weak) IBOutlet UILabel *restoreProgressLabel;
@property (nonatomic, weak) IBOutlet UIProgressView *restoreProgress;
@property (nonatomic, weak) IBOutlet UIToolbar *restoreToolbar;

@property (nonatomic, weak) IBOutlet UITableView *myTableView;

@property (nonatomic, assign) bool hasRestoredData;

@property (nonatomic, strong) MBProgressHUD *HUD;


@end
