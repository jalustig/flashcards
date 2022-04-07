//
//  CollectionCardsStudiedByDayViewController.h
//  FlashCards
//
//  Created by Jason Lustig on 7/16/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import <UIKit/UIKit.h>

@class CPTXYGraph;
@class FCCollection;
@class FCCardSet;


@interface CollectionCardsStudiedByDayViewController : UIViewController <CPTPlotDataSource>

- (void) helpEvent;

@property (nonatomic, strong) FCCollection *collection;
@property (nonatomic, strong) FCCardSet *cardSet;

@property (nonatomic, strong) NSMutableArray *dateCounts;

@property (nonatomic, strong) CPTXYGraph *graph;

@property (nonatomic, assign) int mode;
@property (nonatomic, assign) BOOL launchedFromChoices;
@property (nonatomic, assign) BOOL isLapsed;

@end
