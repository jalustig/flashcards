//
//  CollectionScoreChartViewController.h
//  FlashCards
//
//  Created by Jason Lustig on 7/22/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import <UIKit/UIKit.h>

@class FCCollection;
@class FCCardSet;

@interface CollectionScoreChartViewController : UIViewController

- (void) helpEvent;
- (void) loadScoreChart;

@property (nonatomic, strong) FCCollection *collection;
@property (nonatomic, strong) FCCardSet *cardSet;
@property (nonatomic, weak) IBOutlet UIWebView *textView;

@end
