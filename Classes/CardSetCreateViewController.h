//
//  CardSetCreateViewController.h
//  FlashCards
//
//  Created by Jason Lustig on 5/27/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "MBProgressHUD.h"

@class FCCollection;
@class FCCardSet;
#if TARGET_IPHONE_SIMULATOR
#else
@class SMTEDelegateController;
#endif
@class MBProgressHUD;
@protocol MBProgressHUDDelegate;

@interface CardSetCreateViewController : UIViewController <MBProgressHUDDelegate>

- (void)isDoneSaving;
- (void)saveEvent;
- (void)cancelEvent;

- (IBAction)doneEditing:(id)sender;
- (IBAction)viewOnWebsite:(id)sender;
- (IBAction)syncWithWebsiteOptionDidChange:(id)sender;

@property (nonatomic, assign) int editMode;
@property (nonatomic, strong) FCCardSet *cardSet;

@property (nonatomic, weak) IBOutlet UITextField *cardSetNameField;

@property (nonatomic, weak) IBOutlet UIImageView *quizletImage;

@property (nonatomic, weak) IBOutlet UILabel *syncWithWebsiteLabel;
@property (nonatomic, weak) IBOutlet UISwitch *syncWithWebsiteOption;

@property (nonatomic, weak) IBOutlet UIButton *viewOnWebsiteButton;

@property (nonatomic, strong) UIBarButtonItem *saveButton;
@property (nonatomic, strong) UIBarButtonItem *cancelButton;
@property (nonatomic, strong) FCCollection *collection;

/*
#if TARGET_IPHONE_SIMULATOR
#else
@property (nonatomic, retain) SMTEDelegateController *textExpander;
#endif
*/

@property (nonatomic, strong) MBProgressHUD *HUD;

@property (nonatomic, weak) IBOutlet UILabel *cardSetNameLabel;


@end
