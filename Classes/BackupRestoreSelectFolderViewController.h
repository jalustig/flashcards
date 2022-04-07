//
//  BackupRestoreSelectFolderViewController.h
//  FlashCards
//
//  Created by Jason Lustig on 7/31/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import <UIKit/UIKit.h>

@class DBMetadata;
@class DBRestClient;

@interface BackupRestoreSelectFolderViewController : UIViewController <UITableViewDelegate, DBRestClientDelegate>

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath;
- (IBAction) backupToCurrentFolder:(id)sender;
- (IBAction) loadDirectoryList:(id)sender;
- (IBAction) cancelLoadDirectoryList:(id)sender;
- (void) createFolder;

@property (nonatomic, weak) IBOutlet UITableView *myTableView;

@property (nonatomic, strong) IBOutlet UITableViewCell *loadingCell;
@property (nonatomic, weak) IBOutlet UIActivityIndicatorView *loadingCellActivityIndicator;

@property (nonatomic, weak) IBOutlet UIBarButtonItem *setCurrentFolder;

@property (nonatomic, weak) IBOutlet UILabel *loadingFolderListLabel;
@property (nonatomic, weak) IBOutlet UIButton *loadingFolderListCancelButton;

@property (nonatomic, strong) NSString *currentDirectoryPath;
@property (nonatomic, strong) DBMetadata *currentDirectory;
@property (nonatomic, strong) NSMutableArray *directoryList;
@property (nonatomic, strong) NSString *currentBackupPath;

@property (nonatomic, assign) int popToViewControllerIndex;
@property (nonatomic, assign) bool isLoadingDirectoryList;

@property (nonatomic, strong) DBRestClient *restClient;




@end
