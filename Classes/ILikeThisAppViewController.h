//
//  ILikeThisAppViewController.h
//  FlashCards
//
//  Created by Jason Lustig on 8/22/11.
//  Copyright 2011-2014 Jason Lustig Lustig. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MessageUI/MessageUI.h>
#import "MBProgressHUD.h"

#ifndef TARGET_IPHONE_SIMULATOR
#import "iHasApp.h"
#endif


@interface ILikeThisAppViewController : UITableViewController <MBProgressHUDDelegate, MFMailComposeViewControllerDelegate>

- (BOOL)hasApp:(int)appId;

@property (nonatomic, weak) IBOutlet UILabel *thankYouLabel;
@property (nonatomic, strong) NSMutableArray *appsArray;
#ifndef TARGET_IPHONE_SIMULATOR
@property (nonatomic, retain) iHasApp *appObject;
#endif
@property (nonatomic, assign) SEL appLookupCallbackSelector;
@property (nonatomic, strong) MBProgressHUD *HUD;
@property (nonatomic, assign) BOOL isLoadingApps;

@end
