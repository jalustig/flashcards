//
//  CollectionGeneralStatisticsViewController.h
//  FlashCards
//
//  Created by Jason Lustig on 6/20/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "MBProgressHUD.h"

@class FCCollection;
@class FCCardSet;

@interface CollectionGeneralStatisticsViewController : UIViewController <UITableViewDelegate, UIAlertViewDelegate, MBProgressHUDDelegate>

-(void)loadStatistics;
-(void)helpEvent;
-(void)doneEvent;
-(NSString*)formatInterval:(double)avgNextInterval;
-(void)addStatistic:(NSString *)displayString value:(NSObject *)value;
-(IBAction)alertResetStatistics:(id)sender;

@property (nonatomic, strong) FCCollection *collection;
@property (nonatomic, strong) FCCardSet *cardSet;

@property (nonatomic, strong) NSMutableArray *statistics;

@property (nonatomic, weak) IBOutlet UITableView *myTableView;

@property (nonatomic, weak) IBOutlet UIBarButtonItem *resetAllStatisticsButton;

@property (nonatomic, strong) MBProgressHUD *HUD;

@end
