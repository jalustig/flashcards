//
//  CollectionCardsStudiedTimeFrameChooserViewController.h
//  FlashCards
//
//  Created by Jason Lustig on 7/18/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import <UIKit/UIKit.h>


@class FCCollection;
@class FCCardSet;

@interface CollectionCardsStudiedTimeFrameChooserViewController : UITableViewController

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath;

@property (nonatomic, strong) FCCollection *collection;
@property (nonatomic, strong) FCCardSet *cardSet;
@property (nonatomic, assign) BOOL isLapsed;


@property (nonatomic, strong) NSMutableArray *tableListOptions;

@end
