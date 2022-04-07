//
//  RelatedCardsViewController.h
//  FlashCards
//
//  Created by Jason Lustig on 8/11/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import <UIKit/UIKit.h>

@class FCCard;
@class FCCollection;

@interface RelatedCardsViewController : UITableViewController <NSFetchedResultsControllerDelegate, UISearchDisplayDelegate, UISearchBarDelegate>

- (void)cancelEvent;
- (void)saveEvent;

- (FCCard *)cardForIndexPath:(NSIndexPath *)indexPath;
- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath;

@property (nonatomic, strong) FCCard *card;
@property (nonatomic, strong) FCCollection *collection;
@property (nonatomic, assign) BOOL editInPlace;

@property (nonatomic, strong) NSMutableSet *relatedCardsTempStore;
@property (nonatomic, strong) NSMutableArray *relatedCards;
@property (nonatomic, strong) NSMutableArray *cardsInCardSet;

@property (nonatomic, strong) NSMutableArray *filteredListContent;

@property (nonatomic, strong) NSFetchedResultsController *fetchedResultsController;

@property (nonatomic, assign) BOOL displayAllCollections;


@end
