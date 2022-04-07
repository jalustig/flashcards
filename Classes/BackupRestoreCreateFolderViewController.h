//
//  BackupRestoreCreateFolderViewController.h
//  FlashCards
//
//  Created by Jason Lustig on 7/30/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import <UIKit/UIKit.h>

@class DBRestClient;

@interface BackupRestoreCreateFolderViewController : UIViewController <DBRestClientDelegate>

- (IBAction) saveEvent:(id)sender;

@property (nonatomic, weak) IBOutlet UILabel *folderNameLabel;
@property (nonatomic, weak) IBOutlet UITextField *folderNameField;

@property (nonatomic, weak) IBOutlet UILabel *folderExplanationLabel;

@property (nonatomic, weak) IBOutlet UIActivityIndicatorView *activityIndicator;


@property (nonatomic, strong) NSString *currentDirectoryPath;
@property (nonatomic, assign) int popToViewControllerIndex;
@property (nonatomic, strong) DBRestClient *restClient;


@end
