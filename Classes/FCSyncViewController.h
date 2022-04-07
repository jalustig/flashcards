//
//  FCSyncViewController.h
//  FlashCards
//
//  Created by Jason Lustig on 1/28/13.
//  Copyright (c) 2013 Jason Lustig. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "MBProgressHUD.h"

@interface FCSyncViewController : UIViewController <MBProgressHUDDelegate> {
    MBProgressHUD *syncHUD;
}

- (void)createSyncHUD;
- (void)syncEvent;
- (void)syncEvent:(BOOL)userDidInitiate;

@property (nonatomic, strong) MBProgressHUD *syncHUD;

@end
