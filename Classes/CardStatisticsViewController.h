//
//  CardStatisticsViewController.h
//  FlashCards
//
//  Created by Jason Lustig on 6/24/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import <UIKit/UIKit.h>


@class FCCard;

@interface CardStatisticsViewController : UITableViewController

-(void)addStatistic:(NSString *)displayString value:(NSObject *)value;

@property (nonatomic, strong) FCCard *card;
@property (nonatomic, strong) NSMutableArray *cardRepetitions;
@property (nonatomic, strong) NSMutableArray *statistics;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;

@end
