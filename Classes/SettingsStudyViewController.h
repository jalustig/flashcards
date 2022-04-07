//
//  SettingsStudyViewController.h
//  FlashCards
//
//  Created by Jason Lustig on 10/4/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "MBProgressHUD.h"
#import "FCSyncViewController.h"

@interface SettingsStudyViewController : FCSyncViewController <MBProgressHUDDelegate, UIAlertViewDelegate, UITableViewDataSource, UITableViewDelegate>

-(IBAction)advancedSettings:(id)option;

-(IBAction)cacheOfflineTTSSwitchChangeEvent:(id)sender;
-(IBAction)ignoreParenthesesSwitchChangeEvent:(id)sender;
-(IBAction)proceedNextCardSwitchChangeEvent:(id)sender;
-(IBAction)autoMergeIdenticalCardsSwitchChangeEvent:(id)sender;
-(IBAction)swipeToProceedCardSwitchChangeEvent:(id)sender;
-(IBAction)displayBadgeSwitchChangeEvent:(id)sender;
-(IBAction)displayNotificationSwitchChangeEvent:(id)sender;
-(IBAction)autocorrectTextSwitchChangeEvent:(id)sender;
-(IBAction)autocapitalizeTextSwitchChangeEvent:(id)sender;
-(IBAction)syncSwitchChangeEvent:(id)sender;
-(IBAction)useMarkdownChangeEvent:(id)sender;

- (void) displayUseMarkdown;
- (void) displayAutoMergeIdenticalCards;
- (void) displayProceedNextCard;
- (void) displayAutoBrowseSpeed;
- (void) displayStudyDisplayLikeIndexCard;
- (void) displaySwipeToProceedCard;
- (void) displayDisplayBadge;
- (void) displayAutocorrectText;
- (void) displayAutocapitalizeText;;
- (void) displayIgnoreParentheses;
- (void) displaySync;

- (void) helpEvent;

@property (nonatomic) BOOL goToStudySettings;

@property (nonatomic, weak) IBOutlet UITableView *myTableView;
@property (nonatomic, strong) IBOutlet UIView *tableFooter;
@property (nonatomic, weak) IBOutlet UIButton *advancedSettingsButton;

@property (nonatomic, weak) IBOutlet UILabel *syncLabel;
@property (nonatomic, strong) IBOutlet UITableViewCell *syncCell;
@property (nonatomic, weak) IBOutlet UISwitch *syncSwitch;

@property (nonatomic, weak) IBOutlet UILabel *ignoreParenthesesLabel;
@property (nonatomic, strong) IBOutlet UITableViewCell *ignoreParenthesesCell;
@property (nonatomic, weak) IBOutlet UISwitch *ignoreParenthesesSwitch;

@property (nonatomic, weak) IBOutlet UILabel *textJustificationLabel;
@property (nonatomic, strong) IBOutlet UITableViewCell *textJustificationCell;
@property (nonatomic, weak) IBOutlet UILabel *textJustificationDescriptionLabel;

@property (nonatomic, weak) IBOutlet UILabel *swipeToProceedCardLabel;
@property (nonatomic, strong) IBOutlet UITableViewCell *swipeToProceedCardCell;
@property (nonatomic, weak) IBOutlet UISwitch *swipeToProceedCardSwitch;

@property (nonatomic, weak) IBOutlet UILabel *displayBadgeLabel;
@property (nonatomic, strong) IBOutlet UITableViewCell *displayBadgeCell;
@property (nonatomic, weak) IBOutlet UISwitch *displayBadgeSwitch;

@property (nonatomic, weak) IBOutlet UILabel *displayNotificationLabel;
@property (nonatomic, strong) IBOutlet UITableViewCell *displayNotificationCell;
@property (nonatomic, weak) IBOutlet UISwitch *displayNotificationSwitch;

@property (nonatomic, weak) IBOutlet UILabel *proceedNextCardLabel;
@property (nonatomic, strong) IBOutlet UITableViewCell *proceedNextCardCell;
@property (nonatomic, weak) IBOutlet UISwitch *proceedNextCardSwitch;

@property (nonatomic, weak) IBOutlet UILabel *useMarkdownLabel;
@property (nonatomic, strong) IBOutlet UITableViewCell *useMarkdownCell;
@property (nonatomic, weak) IBOutlet UISwitch *useMarkdownSwitch;

@property (nonatomic, weak) IBOutlet UILabel *autoMergeIdenticalCardsLabel;
@property (nonatomic, strong) IBOutlet UITableViewCell *autoMergeIdenticalCardsCell;
@property (nonatomic, weak) IBOutlet UISwitch *autoMergeIdenticalCardsSwitch;

@property (nonatomic, weak) IBOutlet UILabel *studyDisplayLikeIndexCardLabel;
@property (nonatomic, strong) IBOutlet UITableViewCell *studyDisplayLikeIndexCardCell;
@property (nonatomic, weak) IBOutlet UISwitch *studyDisplayLikeIndexCardSwitch;

@property (nonatomic, weak) IBOutlet UILabel *autocorrectTextLabel;
@property (nonatomic, strong) IBOutlet UITableViewCell *autocorrectTextCell;
@property (nonatomic, weak) IBOutlet UISwitch *autocorrectTextSwitch;

@property (nonatomic, weak) IBOutlet UILabel *autocapitalizeTextLabel;
@property (nonatomic, strong) IBOutlet UITableViewCell *autocapitalizeTextCell;
@property (nonatomic, weak) IBOutlet UISwitch *autocapitalizeTextSwitch;

@property (nonatomic, strong) NSMutableArray *textSizeOptions;
@property (nonatomic, strong) NSMutableArray *fontOptions;
@property (nonatomic, strong) NSMutableArray *textJustificationOptions;
@property (nonatomic, strong) NSMutableArray *autoBrowseSpeedOptions;

@property (nonatomic) UIBackgroundTaskIdentifier backgroundTask;
@property (nonatomic, strong) MBProgressHUD *HUD;

@end