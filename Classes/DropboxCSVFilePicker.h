//
//  DropboxCSVFilePicker.h
//  FlashCards
//
//  Created by Jason Lustig on 10/14/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "MBProgressHUD.h"

@class DBMetadata;
@class DBRestClient;
@class FCCardSet;
@class FCCollection;

@interface DropboxCSVFilePicker : UIViewController <DBRestClientDelegate, UITableViewDelegate, ImportCSVDelegate, MBProgressHUDDelegate>

- (void) cancelEvent;
- (IBAction) loadDirectoryList:(id)sender;
- (IBAction) cancelLoadDirectoryList:(id)sender;
- (IBAction) unlinkDropbox:(id)sender;
- (IBAction) returnToHomeFolder:(id)sender;

@property (nonatomic, weak) IBOutlet UITableView *myTableView;

@property (nonatomic, strong) IBOutlet UITableViewCell *loadingCell;
@property (nonatomic, weak) IBOutlet UIActivityIndicatorView *loadingCellActivityIndicator;

@property (nonatomic, weak) IBOutlet UIBarButtonItem *returnToHomeFolderButton;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *unlinkDropboxButton;

@property (nonatomic, weak) IBOutlet UILabel *loadingFileListLabel;
@property (nonatomic, weak) IBOutlet UIButton *loadingFileListCancelButton;

@property (nonatomic, strong) DBMetadata *currentDirectoryInfo;
@property (nonatomic, strong) DBMetadata *selectedFile;
@property (nonatomic, strong) NSString *currentDirectoryPath;
@property (nonatomic, strong) NSMutableArray *fileList;
@property (nonatomic, strong) NSMutableArray *directoryList;
@property (nonatomic, strong) NSString *currentBackupPath;

@property (nonatomic, strong) ImportCSV *csv;

@property (nonatomic, strong) FCCardSet *cardSet;
@property (nonatomic, strong) FCCollection *collection;
@property (nonatomic, assign) int cardSetCreateMode;

@property (nonatomic, assign) int popToViewControllerIndex;
@property (nonatomic, assign) bool isLoadingDirectoryList;
@property (nonatomic, assign) bool hasAlreadyTriedToLinkDropbox;

@property (nonatomic, strong) DBRestClient *restClient;

@property (nonatomic, strong) NSDateFormatter *dateFormatter;

@property (nonatomic, strong) MBProgressHUD *HUD;

@property (nonatomic, strong) NSMutableSet *selectedIndexPathsSet;

@end
