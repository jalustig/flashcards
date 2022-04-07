//
//  MergeCollectionsViewController.m
//  FlashCards
//
//  Created by Jason Lustig on 9/28/12.
//  Copyright (c) 2012 Jason Lustig. All rights reserved.
//

#import "MergeCollectionsViewController.h"

#import "FCCollection.h"
#import "FCCardSet.h"
#import "FCCard.h"

#import "MBProgressHUD.h"
#import "UIColor-Expanded.h"

@interface MergeCollectionsViewController ()

@end

@implementation MergeCollectionsViewController


@synthesize destinationCollection, destinationCardSet, source;
@synthesize isMergingCollections;
@synthesize tableListOptions;
@synthesize myTableView;
@synthesize HUD;
@synthesize selectedIndexPathsSet, inPseudoEditMode, selectedImage, unselectedImage;
@synthesize pseudoEditToolbar, importAllSetsButton, importSelectedSetsButton;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    self.title = NSLocalizedStringFromTable(@"Merge", @"CardManagement", @"UIView Title");
    
    self.inPseudoEditMode = NO;
    self.selectedIndexPathsSet = [[NSMutableSet alloc] initWithCapacity:0];
    self.selectedImage = [UIImage imageNamed:@"selected.png"];
    self.unselectedImage = [UIImage imageNamed:@"unselected.png"];
    self.pseudoEditToolbar.hidden = YES;
    self.importAllSetsButton.title = NSLocalizedStringFromTable(@"Merge All", @"CardManagement", @"");
    self.importSelectedSetsButton.title = NSLocalizedStringFromTable(@"Merge Selected", @"CardManagement", @"");
    UIBarButtonItem *pseudoEditModeButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedStringFromTable(@"Merge Multiple", @"CardManagement", @"UIBarButtonItem")
                                                                             style:UIBarButtonItemStyleBordered
                                                                            target:self
                                                                            action:@selector(togglePseudoEditMode:)];
    self.navigationItem.rightBarButtonItem = pseudoEditModeButton;

    source = [[NSMutableArray alloc] initWithCapacity:0];
    tableListOptions = [[NSMutableArray alloc] initWithCapacity:0];
    [self loadTableListOptions];
}
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if ([tableListOptions count] == 0) {
        // no other options to merge!
        FCDisplayBasicErrorMessage(@"",
                                   NSLocalizedStringFromTable(@"There are no other collections to import from.", @"CardManagement", @""));
        [self.navigationController popViewControllerAnimated:YES];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


# pragma mark -
# pragma mark Alert functions

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    // NSLog(@"selected: %d", buttonIndex);
    if (buttonIndex == 1) {
        // merge cards
        [self mergeCards];
        
    } else {
        // cancel
    }
}

# pragma mark -
# pragma mark Worker methods

- (void)addSourceAtIndexPath:(NSIndexPath *)indexPath {
    if ([self isMergingCollections]) {
        [source addObject:[tableListOptions objectAtIndex:indexPath.row]];
    } else {
        // more complicated to get the FCCardSet:
        if (indexPath.section+1 > [tableListOptions count]) {
            return;
        }
        NSDictionary *collection = [tableListOptions objectAtIndex:indexPath.section];
        NSArray *sets = [collection objectForKey:@"sets"];
        if (indexPath.row+1 > [sets count]) {
            return;
        }
        FCCardSet *set = [sets objectAtIndex:indexPath.row];
        [source addObject:set];
    }
}

- (void)loadTableListOptions {
    [tableListOptions removeAllObjects];

    NSFetchRequest *fetchRequest;
    if ([self isMergingCollections]) {
        fetchRequest = [[NSFetchRequest alloc] init];
        [fetchRequest setEntity:[NSEntityDescription entityForName:@"Collection"
                                            inManagedObjectContext:[FlashCardsCore mainMOC]]];
        [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"self != %@", self.destinationCollection]];
        [fetchRequest setSortDescriptors:[NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]]];
        
        NSArray *allCollections = [NSArray arrayWithArray:[[FlashCardsCore mainMOC] executeFetchRequest:fetchRequest error:nil]];
        [tableListOptions addObjectsFromArray:allCollections];
    } else {
        fetchRequest = [[NSFetchRequest alloc] init];
        [fetchRequest setEntity:[NSEntityDescription entityForName:@"Collection"
                                            inManagedObjectContext:[FlashCardsCore mainMOC]]];
        if (!self.destinationCardSet) {
            // we are importing directly into a collection. Thus, we don't want to get anything in our current collection:
            [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"self != %@", self.destinationCollection]];
        }
        [fetchRequest setSortDescriptors:[NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]]];
        
        NSArray *allCollections = [NSArray arrayWithArray:[[FlashCardsCore mainMOC] executeFetchRequest:fetchRequest error:nil]];
        NSArray *allCardSets;
        for (FCCollection *theCollection in allCollections) {
            fetchRequest = [[NSFetchRequest alloc] init];
            [fetchRequest setEntity:[NSEntityDescription entityForName:@"CardSet"
                                                inManagedObjectContext:[FlashCardsCore mainMOC]]];
            [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"isDeletedObject = NO and self.collection = %@ and self != %@ and isMasterCardSet = NO", theCollection, self.destinationCardSet]];
            [fetchRequest setSortDescriptors:[NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]]];
            
            allCardSets = [NSArray arrayWithArray:[[FlashCardsCore mainMOC] executeFetchRequest:fetchRequest error:nil]];

            [tableListOptions addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                         theCollection, @"collection",
                                         allCardSets, @"sets", nil]];
        }
        
        NSDictionary *theOption;
        for (int i = [tableListOptions count]-1; i >= 0; i--) {
            theOption = [tableListOptions objectAtIndex:i];
            if ([[theOption objectForKey:@"sets"] count] == 0) {
                [tableListOptions removeObjectAtIndex:i];
            }
        }
    }
}

- (void)checkIfUserReallyWantsToMerge {
    int numCards = 0;
    if ([self isMergingCollections]) {
        for (FCCollection *sourceCollection in source) {
            numCards += [sourceCollection cardsCount];
        }
    } else {
        for (FCCardSet *sourceCardSet in source) {
            numCards += [sourceCardSet cardsCount];
        }

    }
    
    if (numCards == 0) {
        FCDisplayBasicErrorMessage(@"",
                                   NSLocalizedStringFromTable(@"There are no cards to merge.", @"CardManagement", @""));
        return;
    }
    
    NSString *alertMsg =
    [NSString stringWithFormat:
     NSLocalizedStringFromTable(@"Are you sure you want to merge these cards? These %d cards will be added to \"%@\" and the selected Collections will be removed.", @"CardManagement", @""),
     numCards,
     destinationCollection.name,
     nil];
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@""
                                                     message:alertMsg
                                                    delegate:self
                                           cancelButtonTitle:NSLocalizedStringFromTable(@"Don't Merge", @"CardManagement", @"cancelButtonTitle")
                                           otherButtonTitles:NSLocalizedStringFromTable(@"Yes, Merge", @"CardManagement", @"otherButtonTitles"), nil];
    [alert show];
}

- (void)mergeCards {
    HUD = [[MBProgressHUD alloc] initWithView:self.view];
    [self.view addSubview:HUD];
    
    // Regisete for HUD callbacks so we can remove it from the window at the right time
    HUD.delegate = self;
    HUD.minShowTime = 0.0;
    HUD.labelText = NSLocalizedStringFromTable(@"Merging", @"Import", @"HUD");
    [HUD show:YES];
    
    if ([self isMergingCollections]) {
        // we are merging collections:
        
        // things this needs to do:
        // update all of the cards to point to the new collection
        // update all of the card sets to point to the new collection
        FCCardSet *newCardSet;
        NSString *website;
        int cardId;
        for (FCCollection *sourceCollection in source) {
            // NSLog(@"Name: %@; # Cards: %d", sourceCollection.name, [sourceCollection cardsCount]);
            newCardSet = nil;
            website = @"";
            cardId = 0;
            FCLog(@"# cards in source collection: %d", [sourceCollection cardsCount]);
            FCLog(@"# cards in source collection's master card set: %d", [sourceCollection.masterCardSet cardsCount]);
            FCLog(@"# cards in destination collection: %d", [destinationCollection cardsCount]);
            FCLog(@"# cards in destination collection's master card set: %d", [destinationCollection.masterCardSet cardsCount]);
            FCLog(@"----------");
            if ([sourceCollection.masterCardSet.shouldSync boolValue] || ([sourceCollection cardSetsCount] == 0 && [sourceCollection cardsCount] > 0)) {
                // if the source has no card sets, we will first create a card set with all of the cards,
                // with the name of the collection. This way the new cards can be found in their new setting.
                
                newCardSet = (FCCardSet *)[NSEntityDescription insertNewObjectForEntityForName:@"CardSet"
                                                                        inManagedObjectContext:[FlashCardsCore mainMOC]];
                
                [newCardSet setName:sourceCollection.name];
                [newCardSet setCollection:destinationCollection];
                [newCardSet setCardsList:sourceCollection.cards];
                if ([sourceCollection.masterCardSet.shouldSync boolValue]) {
                    [newCardSet setCreatorUsername:sourceCollection.masterCardSet.creatorUsername];
                    [newCardSet setLastSyncDate:sourceCollection.masterCardSet.lastSyncDate];
                    [newCardSet setFlashcardExchangeSetId:sourceCollection.masterCardSet.flashcardExchangeSetId];
                    [newCardSet setQuizletSetId:sourceCollection.masterCardSet.quizletSetId];
                    [newCardSet setSyncStatus:sourceCollection.masterCardSet.syncStatus];
                    [newCardSet setShouldSync:sourceCollection.masterCardSet.shouldSync];
                    [newCardSet setCardsDeleted:sourceCollection.masterCardSet.cardsDeleted];
                    for (FCCard *card in newCardSet.cards) {
                        website = @"quizlet";
                        cardId = [card cardIdForWebsite:website forCardSet:sourceCollection.masterCardSet];
                        [card setWebsiteCardId:cardId forCardSet:newCardSet withWebsite:website];
                    }
                }
            }
            
            // move all cards in the source collection to the destination:
            NSArray *cards = [NSArray arrayWithArray:[[sourceCollection allCardsIncludingDeletedOnes] allObjects]];
            for (FCCard* card in cards) {
                [card setCollection:destinationCollection];
                // no need to set this to the new collection because this is coming from the collection itself.
                // if we were studying the card in the previous collection, it just doesn't matter now.
                [card setCollectionStudyState:nil];
                FCLog(@"# cards in source collection: %d", [sourceCollection cardsCount]);
                FCLog(@"# cards in source collection's master card set: %d", [sourceCollection.masterCardSet cardsCount]);
                FCLog(@"# cards in destination collection: %d", [destinationCollection cardsCount]);
                FCLog(@"# cards in destination collection's master card set: %d", [destinationCollection.masterCardSet cardsCount]);
                FCLog(@"----------");
            }
            
            // move all sets in the source collection to the destination:
            NSArray *sets = [NSArray arrayWithArray:[[sourceCollection allCardSets] allObjects]];
            for (FCCardSet *set in sets) {
                [set setCollection:destinationCollection];
            }
            FCLog(@"# cards in source collection: %d", [sourceCollection cardsCount]);
            FCLog(@"# cards in source collection's master card set: %d", [sourceCollection.masterCardSet cardsCount]);
            FCLog(@"# cards in destination collection: %d", [destinationCollection cardsCount]);
            FCLog(@"# cards in destination collection's master card set: %d", [destinationCollection.masterCardSet cardsCount]);
            FCLog(@"----------");
            // Just to be sure, remove all the necessary data:
            [sourceCollection removeCards:sourceCollection.cards];
            [sourceCollection removeCardSets:[sourceCollection allCardSets]];
            FCLog(@"# cards in source collection: %d", [sourceCollection cardsCount]);
            FCLog(@"# cards in source collection's master card set: %d", [sourceCollection.masterCardSet cardsCount]);
            FCLog(@"# cards in destination collection: %d", [destinationCollection cardsCount]);
            FCLog(@"# cards in destination collection's master card set: %d", [destinationCollection.masterCardSet cardsCount]);
            FCLog(@"----------");
            // save our changes:
            [[FlashCardsCore mainMOC] deleteObject:sourceCollection.masterCardSet];
            [[FlashCardsCore mainMOC] deleteObject:sourceCollection];

            [FlashCardsCore saveMainMOC];
        }
    } else {
        // we are merging card sets:
        
        // What it needs to do:
        // - Add all the cards to the destination set.
        // - if the source set is in a different collection, then we need to remove the cards from any other sets
        //   in the source collection.
        // - Remove the source set.
        // maybe more??
        for (FCCardSet *sourceSet in source) {
            FCLog(@"Name: %@", sourceSet.name);
            FCLog(@"# cards in source collection: %d", [sourceSet.collection cardsCount]);
            FCLog(@"# cards in source collection's master card set: %d", [sourceSet.collection.masterCardSet cardsCount]);
            FCLog(@"# cards in destination collection: %d", [destinationCollection cardsCount]);
            FCLog(@"# cards in destination collection's master card set: %d", [destinationCollection.masterCardSet cardsCount]);
            FCLog(@"----------");
            NSArray *allCards = [NSArray arrayWithArray:[[sourceSet allCardsIncludingDeletedOnes] allObjects]];
            for (FCCard *card in allCards) {
                // if the source is not in the current collection, remove it from the source collection.
                // we will do this even if there is no destination collection. That's because we are going
                // to re-add the source card set afterwards, so that when we finish the import the cards remain
                // part of the original set.
                if (![card.collection isEqual:destinationCollection]) {
                    // now, the cards are all **only** in the original card set:
                    [card removeCardSet:card.cardSet];
                    [sourceSet addCard:card];
                    
                    // and make sure it's not in the study state:
                    [card.collection removeStudyStateCardListObject:card];
                }
                if (destinationCardSet) {
                    // add the cards to the destination set
                    [destinationCardSet addCard:card];
                }
                [card setCollection:destinationCollection];
                FCLog(@"# cards in source collection: %d", [sourceSet.collection cardsCount]);
                FCLog(@"# cards in source collection's master card set: %d", [sourceSet.collection.masterCardSet cardsCount]);
                FCLog(@"# cards in destination collection: %d", [destinationCollection cardsCount]);
                FCLog(@"# cards in destination collection's master card set: %d", [destinationCollection.masterCardSet cardsCount]);
                FCLog(@"----------");
            }
            if ([sourceSet.collection isEqual:destinationCollection]) {
                // if we are importing within the same collection:
                // delete the set b/c it won't have any more cards in it:
                [sourceSet removeCards:sourceSet.cards];
                [[FlashCardsCore mainMOC] deleteObject:sourceSet];
            } else {
                // we are importing from another collection:
                [sourceSet setCollection:destinationCollection];
            }
            NSLog(@"# cards in source collection: %d", [sourceSet.collection cardsCount]);
            NSLog(@"# cards in source collection's master card set: %d", [sourceSet.collection.masterCardSet cardsCount]);
            NSLog(@"# cards in destination collection: %d", [destinationCollection cardsCount]);
            NSLog(@"# cards in destination collection's master card set: %d", [destinationCollection.masterCardSet cardsCount]);
            // save our changes:
            [FlashCardsCore saveMainMOC];
        }
    }
    
    [HUD hide:YES];
    
    FCDisplayBasicErrorMessage(@"", NSLocalizedStringFromTable(@"Merge successful!", @"CardManagement", @""));
    [self.navigationController popToViewController:[[self.navigationController viewControllers] objectAtIndex:([[self.navigationController viewControllers] count]-3)] animated:YES];
    // tell them that everything went ok!
    

}

# pragma mark -
# pragma mark PseudoEditMode Methods

-(IBAction)togglePseudoEditMode:(id)sender
{
    self.inPseudoEditMode = !self.inPseudoEditMode;
    pseudoEditToolbar.hidden = !self.inPseudoEditMode;
    if (pseudoEditToolbar.hidden) { // if we hid the toolbar, then incraese the size of the table view
        // we are importing a single set
        self.navigationItem.rightBarButtonItem.style = UIBarButtonItemStyleBordered;
        self.navigationItem.rightBarButtonItem.title = NSLocalizedStringFromTable(@"Merge Multiple", @"CardManagement", @"UIBarButtonItem");
        //[myTableView setPositionHeight:(myTableView.frame.size.height+44)];
    } else { // if it is shown, then decrase the height of the table view
        // we are importing multiple sets
        self.navigationItem.rightBarButtonItem.style = UIBarButtonItemStyleDone;
        self.navigationItem.rightBarButtonItem.title = NSLocalizedStringFromTable(@"Merge One", @"CardManagement", @"UIBarButtonItem");
        //[myTableView setPositionHeight:(myTableView.frame.size.height-44)];
    }
    
    [self.myTableView reloadData];
    
}

-(IBAction)importAllSets:(id)sender {
    [selectedIndexPathsSet removeAllObjects];
    for (int i = 0; i < [tableListOptions count]; i++) {
        [selectedIndexPathsSet addObject:[NSIndexPath indexPathForRow:i inSection:0]];
    }
    [self importSelectedSets:nil];
}
-(IBAction)importSelectedSets:(id)sender {
    [source removeAllObjects];
    for (NSIndexPath *indexPath in selectedIndexPathsSet) {
        [self addSourceAtIndexPath:indexPath];
    }
    
    if ([source count] == 0) {
        FCDisplayBasicErrorMessage(@"",
                                   NSLocalizedStringFromTable(@"Please select at least one card source.", @"CardManagement", @""));
        return;
    }
    
    [self checkIfUserReallyWantsToMerge];
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    if ([self isMergingCollections]) {
        return 1;
    }
    return [tableListOptions count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if ([self isMergingCollections]) {
        return @"";
    }
    return [[[tableListOptions objectAtIndex:section] objectForKey:@"collection"] valueForKey:@"name"];
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if ([self isMergingCollections]) {
        return [tableListOptions count];
    }
    return [(NSArray*)[[tableListOptions objectAtIndex:section] objectForKey:@"sets"] count];
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier;
    int style = UITableViewCellStyleSubtitle;
    if (self.inPseudoEditMode) {
        CellIdentifier = @"PseudoEditCell";
    } else {
        CellIdentifier = @"Cell";
    }

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:style reuseIdentifier:CellIdentifier];
    }
    
    // Configure the cell...
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    
    int count;
    if ([self isMergingCollections]) {
        FCCollection *theCollection = [tableListOptions objectAtIndex:indexPath.row];
        cell.textLabel.text = theCollection.name;
        count = [theCollection cardsCount];
    } else {
        FCCardSet *theCardSet = [(NSArray*)[[tableListOptions objectAtIndex:indexPath.section] objectForKey:@"sets"] objectAtIndex:indexPath.row];
        cell.textLabel.text = theCardSet.name;
        count = [[[theCardSet cards] allObjects] count];
    }
    cell.detailTextLabel.text = [NSString stringWithFormat:FCPluralLocalizedStringFromTable(@"%d Cards", @"Plural", @"", [NSNumber numberWithInt:count]), count];

    if (self.inPseudoEditMode) {
        [cell setAccessoryType:UITableViewCellAccessoryNone];
        
        BOOL selected = [selectedIndexPathsSet containsObject:indexPath];
        if (selected) {
            [cell.imageView setImage:selectedImage];
        } else {
            [cell.imageView setImage:unselectedImage];
        }
    } else {
        [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
        [cell.imageView setImage:nil];
    }

}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (!self.inPseudoEditMode) {
        return;
    }
    
    BOOL selected = [selectedIndexPathsSet containsObject:indexPath];
    if (selected) {
        [cell setBackgroundColor:[FCColor colorWithRGBHex:(0xe6e6e6)]];
    } else {
        [cell setBackgroundColor:[FCColor colorWithRGBHex:(0xffffff)]];
    }
}


#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    [self tableView:tableView didSelectRowAtIndexPath:indexPath];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    
    if (inPseudoEditMode)
    {
        BOOL selected = [selectedIndexPathsSet containsObject:indexPath];
        if (selected) {
            // it is already in the selected set - remove it
            [selectedIndexPathsSet removeObject:indexPath];
        } else {
            // it is not yet in the selected set - add it
            [selectedIndexPathsSet addObject:indexPath];
        }
        [self.myTableView reloadData];
        return;
    }
    
    [self addSourceAtIndexPath:indexPath];
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    [self checkIfUserReallyWantsToMerge];
}

# pragma mark -
# pragma mark HUD

- (void)hudWasHidden:(MBProgressHUD *)hud {
    // Remove HUD from screen when the HUD was hidded
    [hud removeFromSuperview];
    hud = nil;
}

@end
