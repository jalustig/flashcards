//
//  CardEditCardSetsViewController.h
//  FlashCards
//
//  Created by Jason Lustig on 10/7/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "MBProgressHUD.h"
#import "QuizletSync.h"

@class FCCard;
@protocol MBProgressHUDDelegate;
@class MBProgressHUD;

@interface CardEditCardSetsViewController : UITableViewController <MBProgressHUDDelegate, SyncControllerDelegate>

- (void)saveEvent;
- (void)isDoneSaving;
- (void)cancelEvent;


@property (nonatomic, strong) FCCard *card;
@property (nonatomic, strong) NSMutableArray *allCardSets;
@property (nonatomic, strong) NSMutableSet *currentCardSets;

@property (nonatomic, strong) MBProgressHUD *HUD;

@end
