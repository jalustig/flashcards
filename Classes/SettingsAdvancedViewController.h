//
//  SettingsAdvancedViewController.h
//  FlashCards
//
//  Created by Jason Lustig on 2/2/13.
//  Copyright (c) 2013 Jason Lustig. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "MBProgressHUD.h"

@interface SettingsAdvancedViewController : UIViewController <MBProgressHUDDelegate>

-(IBAction)resetAllSettings:(id)sender;
-(IBAction)optimizeDatabase:(id)sender;
-(IBAction)completelyDisableSync:(id)sender;
-(IBAction)enterCode:(id)sender;
-(IBAction)validateReceipts:(id)sender;

- (void)checkDisplayButtons;

@property (nonatomic, strong) MBProgressHUD *HUD;
@property (nonatomic, strong) MBProgressHUD *syncHUD;

@property (nonatomic, weak) IBOutlet UIButton *resetAllSettingsButton;
@property (nonatomic, weak) IBOutlet UIButton *optimizeDatabaseButton;
@property (nonatomic, weak) IBOutlet UIButton *enterCodeButton;
@property (nonatomic, weak) IBOutlet UIButton *validateReceiptsButton;

@property (nonatomic, weak) IBOutlet UIButton *completelyDisableSyncButton;


@end
