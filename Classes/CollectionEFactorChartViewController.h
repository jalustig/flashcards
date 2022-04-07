//
//  CollectionEFactorChartViewController.h
//  FlashCards
//
//  Created by Jason Lustig on 6/16/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import <UIKit/UIKit.h>

@class CPTXYGraph;
@class FCCollection;
@class FCCardSet;

@interface CollectionEFactorChartViewController : UIViewController <CPTPlotDataSource>

- (void) helpEvent;

@property (nonatomic, strong) FCCollection *collection;
@property (nonatomic, strong) FCCardSet *cardSet;

@property (nonatomic, strong) NSMutableArray *eFactorCounts;
@property (nonatomic, assign) BOOL memorizedOnly;
@property (nonatomic, assign) BOOL lapsedOnly;

@property (nonatomic, strong) CPTXYGraph *graph;

@property (nonatomic, strong) NSFetchedResultsController *fetchedResultsController;

@end