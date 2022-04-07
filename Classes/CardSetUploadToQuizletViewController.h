//
//  CardSetUploadToQuizletViewController.h
//  FlashCards
//
//  Created by Jason Lustig on 9/12/11.
//  Copyright 2011-2014 Jason Lustig Lustig. All rights reserved.
//

#import "QuizletLoginController.h"
#import "QuizletRestClient.h"

#import "MBProgressHUD.h"
#import <MessageUI/MessageUI.h>

#import "QuizletRestClient.h"

@class MBProgressHUD;
@class FCCollection;
@class FCCardSet;
@protocol QuizletLoginControllerDelegate;
@protocol  MBProgressHUDDelegate;
@class QuizletRestClient;

@interface CardSetUploadToQuizletViewController : UIViewController <UITableViewDelegate, MBProgressHUDDelegate, MFMailComposeViewControllerDelegate, QuizletLoginControllerDelegate, UIAlertViewDelegate>

- (void)cancelEvent;
- (IBAction)uploadToQuizlet:(id)sender;

- (IBAction)doneEditing:(id)sender;
- (IBAction)backgroundTap:(id)sender;
- (IBAction)addToGroupSwitchDidChange:(id)sender;

@property (nonatomic, weak) IBOutlet UILabel *cardSetNameLabel;
@property (nonatomic, weak) IBOutlet UITextField *cardSetNameField;
@property (nonatomic, weak) IBOutlet UILabel *allowDiscussionLabel;
@property (nonatomic, weak) IBOutlet UISwitch *allowDiscussionSwitch;
@property (nonatomic, weak) IBOutlet UILabel *privateSetLabel;
@property (nonatomic, weak) IBOutlet UISwitch *privateSetSwitch;
@property (nonatomic, weak) IBOutlet UIButton *uploadToQuizletButton;
@property (nonatomic, weak) IBOutlet UILabel *noteLabel;

@property (nonatomic, weak) IBOutlet UILabel *syncLabel;
@property (nonatomic, weak) IBOutlet UISwitch *syncSwitch;

@property (nonatomic, strong) QuizletRestClient *restClient;
@property (nonatomic, strong) MBProgressHUD *HUD;

@property (nonatomic, strong) FCCollection *collection;
@property (nonatomic, strong) FCCardSet *cardSet;

@property (nonatomic, strong) NSMutableArray *cardsToUpload;

@property (nonatomic, weak) IBOutlet UILabel  *addSetToGroupLabel;
@property (nonatomic, weak) IBOutlet UISwitch *addSetToGroupSwitch;

@property (nonatomic, weak) IBOutlet UITableView *myTableView;


@property (nonatomic, strong) NSString *quizletSetURL;
@property (nonatomic, strong) NSString *quizletSetName;
@property (nonatomic, assign) int quizletSetId;

@property (nonatomic, strong) NSIndexPath *selectedGroup;

@property (nonatomic, strong) NSMutableArray *myGroups;


@end
