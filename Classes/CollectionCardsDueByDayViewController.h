//
//  CollectionCardsDueByDayViewController.h
//  FlashCards
//
//  Created by Jason Lustig on 7/9/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import <UIKit/UIKit.h>

@class FCCollection;
@class FCCardSet;

@interface CollectionCardsDueByDayViewController : UITableViewController

- (void) helpEvent;

@property (nonatomic, strong) FCCollection *collection;
@property (nonatomic, strong) FCCardSet *cardSet;

@property (nonatomic, strong) NSMutableArray* days;

@property (nonatomic, strong) NSFetchedResultsController *fetchedResultsController;

@end
