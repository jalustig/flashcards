//
//  RelatedCardsViewController.m
//  FlashCards
//
//  Created by Jason Lustig on 8/11/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import "FlashCardsAppDelegate.h"
#import "RelatedCardsViewController.h"

#import "CardEditViewController.h"
#import "StudyViewController.h"

#import "CardTest.h"
#import "FCCardSet.h"
#import "FCCollection.h"
#import "FCCard.h"
#import "FlashCardsCore.h"

@implementation RelatedCardsViewController

@synthesize card, collection, cardsInCardSet, editInPlace;
@synthesize relatedCardsTempStore, relatedCards, filteredListContent;
@synthesize fetchedResultsController;
@synthesize displayAllCollections;

#pragma mark -
#pragma mark View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = NSLocalizedStringFromTable(@"Related Cards", @"CardManagement", @"UIView title");
    
    UIBarButtonItem *saveButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave
                                                                                target:self
                                                                                action:@selector(saveEvent)];
    saveButton.enabled = YES;
    self.navigationItem.rightBarButtonItem = saveButton;
    

    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                target:self
                                                                                action:@selector(cancelEvent)];
    cancelButton.enabled = YES;
    self.navigationItem.leftBarButtonItem = cancelButton;
    
    
    // get the number of collections. If there are more than one, than display the
    if ([FlashCardsCore numberCollectionsInManagedContext:[FlashCardsCore mainMOC]] > 1) {
        displayAllCollections = YES;
        [self.searchDisplayController.searchBar setShowsScopeBar:YES];
        [self.searchDisplayController.searchBar setScopeButtonTitles:[NSArray arrayWithObjects:
                                                                      NSLocalizedStringFromTable(@"All Collections", @"CardManagement", @""),
                                                                      card.collection.name,
                                                                      nil]];
    } else {
        displayAllCollections = NO;
        [self.searchDisplayController.searchBar setShowsScopeBar:NO];
    }
    
    NSError *error = nil;
    if (![[self fetchedResultsController] performFetch:&error]) {
        FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"Error", @"Error", @"UIAlert title"),
                                   [NSString stringWithFormat:NSLocalizedStringFromTable(@"Error: %@ (%@)", @"Error", @"message"), error, [error userInfo] ]);
        return;
    }
    
    // we'll load all of the related cards into a side array so that it doesn't update the display
    // as we add & remove them:
    if (card) {
        if (!relatedCardsTempStore) {
            relatedCardsTempStore = [[NSMutableSet alloc] initWithSet:[[card relatedCards] filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"isDeletedObject = NO"]]];
        }
        NSMutableSet *NSSetOfCardsInCardSet = [[NSMutableSet alloc] initWithCapacity:0];
        FCCardSet *cardSet;
        for (int i = 0; i < [card cardSetsCount]; i++) {
            cardSet = (FCCardSet*)[[[card allCardSets] allObjects] objectAtIndex:i];
            [NSSetOfCardsInCardSet unionSet:cardSet.cards];
            if ([cardSet.isDeletedObject boolValue]) {
                continue;
            }
        }
        [NSSetOfCardsInCardSet removeObject:card];
        cardsInCardSet = [[NSMutableArray alloc] initWithArray:[NSSetOfCardsInCardSet allObjects]];
    } else {
        // the previous view controller (CardCreate) should have passed it up!
        if (!relatedCardsTempStore) {
            // if for some reason it's not here, just create it empty:
            relatedCardsTempStore = [[NSMutableSet alloc] initWithCapacity:0];
        }
        cardsInCardSet = [[NSMutableArray alloc] initWithCapacity:0];
    }
         
    relatedCards = [[NSMutableArray alloc] initWithArray:[relatedCardsTempStore allObjects]];
    // sort them by name:
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"frontValue" ascending:YES  selector:@selector(caseInsensitiveCompare:)];
    [relatedCards sortUsingDescriptors:[NSArray arrayWithObject:sortDescriptor]];
    [cardsInCardSet sortUsingDescriptors:[NSArray arrayWithObject:sortDescriptor]];
    
    [self.tableView reloadData];
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

/*
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}
*/
/*
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}
*/

/*
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
        
}
*/

/*
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}
*/

- (BOOL)shouldAutorotate {
    UIInterfaceOrientation interfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    return [FlashCardsAppDelegate shouldAutorotate:interfaceOrientation];
}

- (void)cancelEvent {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void) saveEvent {
    
    if (card && editInPlace) {
        // update the related cards to the new set:
        [card setRelatedCards:relatedCardsTempStore];

        // save!!
        [FlashCardsCore saveMainMOC];
        StudyViewController *vc = (StudyViewController *)[self.navigationController.viewControllers objectAtIndex:([self.navigationController.viewControllers count]-2)];
        [[vc.studyController currentCard] setCard:card];
        [vc configureCard];
    } else {
        CardEditViewController* vc = (CardEditViewController*)[self.navigationController.viewControllers objectAtIndex:([self.navigationController.viewControllers count]-2)];
        [vc.cardData setObject:relatedCardsTempStore forKey:@"relatedCards"];
    }
    
    [self.navigationController popViewControllerAnimated:YES];

}

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (self.searchDisplayController.active) {
        return 1;
    }
    int count = [[fetchedResultsController sections] count];
    if ([relatedCards count] > 0) {
        count++;
    }
    if ([cardsInCardSet count] > 0) {
        count++;
    }
    // Return the number of sections.
    // NSLog(@"num sections: %d", count);
    return count;
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView {
    NSMutableArray *titles = [[NSMutableArray alloc] initWithCapacity:0];
    if (self.searchDisplayController.active) {
        return titles;
    }
    id <NSFetchedResultsSectionInfo> sectionInfo;
    if ([relatedCards count] > 0) {
        [titles addObject:@"="];
    }
    if ([cardsInCardSet count] > 0) {
        [titles addObject:@"@"];
    }
    for (int i = 0; i < [[fetchedResultsController sections] count]; i++) {
        sectionInfo = [[fetchedResultsController sections] objectAtIndex:i];
        [titles addObject:sectionInfo.name];
    }
    return titles;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index {
    return index;
    return [fetchedResultsController sectionForSectionIndexTitle:title atIndex:index];
}

- (NSString *)sectionIndexTitleForSectionName:(NSString *)sectionName {
    if (self.searchDisplayController.active) {
        return @"";
    }
    return sectionName;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.searchDisplayController.active) {
        return [self.filteredListContent count];
    }
    if ([relatedCards count] > 0) {
        if (section == 0) {
            return [relatedCards count];
        }
        section--; // reduce the section # so that the rest of the function accurately gets the proper section:
    }
    if ([cardsInCardSet count] > 0) {
        if (section == 0) {
            return [cardsInCardSet count];
        }
        section--;
    }
    id <NSFetchedResultsSectionInfo> sectionInfo = [[fetchedResultsController sections] objectAtIndex:section];
    return [sectionInfo numberOfObjects];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (self.searchDisplayController.active) {
        return NSLocalizedStringFromTable(@"Search Results", @"FlashCards", @"");
    }
    if ([relatedCards count] > 0) {
        if (section == 0) {
            return NSLocalizedStringFromTable(@"Related Cards", @"CardManagement", @"");
        }
        section--; // reduce the section # so that the rest of the function accurately gets the proper section:
    }
    if ([cardsInCardSet count] > 0) {
        if (section == 0) {
            return NSLocalizedStringFromTable(@"Other Cards in Same Card Set", @"CardManagement", @"");
        }
        section--;
    }
    id <NSFetchedResultsSectionInfo> sectionInfo = [[fetchedResultsController sections] objectAtIndex:section];
    return [sectionInfo name];
}




// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
    
    [self configureCell:cell atIndexPath:indexPath];
    
    return cell;
}

// !!!!!!!!!!!
// the app was crashing in this function: when you tap on the second scope selector
// and then tap the gray area, it tries to create a cell with an indexPath past the limit
// of what's in the NSFetchedResultsController
// !!!!!!!!!!!
- (FCCard *)cardForIndexPath:(NSIndexPath *)indexPath {
    FCCard *entity = nil;
    if (self.searchDisplayController.active && [[self filteredListContent] count] > 0) {
        entity = [[self filteredListContent] objectAtIndex:[indexPath row]];
    } else {
        if ([relatedCards count] > 0) {
            if ([indexPath section] == 0) {
                entity = [relatedCards objectAtIndex:[indexPath row]];
            } else if ([cardsInCardSet count] > 0) {
                if ([indexPath section] == 1) {
                    entity = [cardsInCardSet objectAtIndex:[indexPath row]];
                } else {
                    entity = [fetchedResultsController objectAtIndexPath:[NSIndexPath indexPathForRow:[indexPath row] inSection:([indexPath section]-2)]];
                }
            } else {
                entity = [fetchedResultsController objectAtIndexPath:[NSIndexPath indexPathForRow:[indexPath row] inSection:([indexPath section]-1)]];
            }
        } else if ([cardsInCardSet count] > 0) {
            if ([indexPath section] == 0) {
                entity = [cardsInCardSet objectAtIndex:[indexPath row]];
            } else {
                entity = [fetchedResultsController objectAtIndexPath:[NSIndexPath indexPathForRow:[indexPath row] inSection:([indexPath section]-1)]];
            }
        } else {
            // no related cards - just display the item
            entity = [fetchedResultsController objectAtIndexPath:indexPath];
        }
    }
    return entity;
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    FCCard *entity = [self cardForIndexPath:indexPath];

    cell.textLabel.text = [[entity valueForKey:@"frontValue"] description];
    cell.detailTextLabel.text = [[entity valueForKey:@"backValue"] description];

    if ([cell.textLabel.text length] == 0) {
        cell.textLabel.text = NSLocalizedStringFromTable(@"(blank)", @"CardManagement", @"");
    }
    if ([cell.detailTextLabel.text length] == 0) {
        cell.detailTextLabel.text = NSLocalizedStringFromTable(@"(blank)", @"CardManagement", @"");
    }
    
    if ([relatedCardsTempStore containsObject:entity]) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    if ([[entity valueForKey:@"hasImages"] boolValue]) {
        [cell.imageView setImage:[UIImage imageNamed:@"icon-camera.png"]];
    } else {
        [cell.imageView setImage:nil];
    }
    
}

#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    FCCard *currentCard = [self cardForIndexPath:indexPath];
    
    if (currentCard == card) {
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil
                                                         message:NSLocalizedStringFromTable(@"You cannot mark a card as \"related\" to itself.", @"CardManagement", @"message")
                                                        delegate:nil
                                               cancelButtonTitle:NSLocalizedStringFromTable(@"OK", @"FlashCards", @"cancelButtonTitle")
                                               otherButtonTitles:nil];
        [alert show];
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        return;
    }
    
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    
    if ([relatedCardsTempStore containsObject:currentCard]) {
        
        [relatedCardsTempStore removeObject:currentCard];
        cell.accessoryType = UITableViewCellAccessoryNone;
    } else {
        [relatedCardsTempStore addObject:currentCard];
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    }

    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    [tableView performSelector:@selector(reloadData) withObject:nil afterDelay:0.5];
    // [tableView reloadData];
    
}


#pragma mark -
#pragma mark Content Filtering

- (void)filterContentForSearchText:(NSString*)searchText scope:(NSString*)scope {
    NSPredicate * predicate = [NSPredicate predicateWithFormat:@"(frontValue CONTAINS[cd] %@ or backValue CONTAINS[cd] %@) and self != %@", searchText, searchText, card];
    self.filteredListContent = [NSMutableArray arrayWithArray:[[[self fetchedResultsController] fetchedObjects] filteredArrayUsingPredicate:predicate]];
}


#pragma mark -
#pragma mark UISearchDisplayController Delegate Methods

- (BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)searchString {
    [self filterContentForSearchText:searchString scope:@""];
    return YES;
}


- (BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchScope:(NSInteger)searchOption {
    [self filterContentForSearchText:[self.searchDisplayController.searchBar text] scope:@""];
    return YES;
}

- (void)searchDisplayControllerWillBeginSearch:(UISearchDisplayController *)controller {
    // self.searchIsActive = YES;
}

- (void)searchDisplayControllerDidEndSearch:(UISearchDisplayController *)controller {
    // self.searchIsActive = NO;
    [self.tableView reloadData];
}


- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar {
    [self.tableView reloadData];
}

#pragma mark -
#pragma mark UISearchBarDelegate methods

- (void)searchBar:(UISearchBar *)searchBar selectedScopeButtonIndexDidChange:(NSInteger)selectedScope {
    if (selectedScope == 0) {
        // all collections
        displayAllCollections = YES;
    } else {
        displayAllCollections = NO;
    }
    self.fetchedResultsController = nil;
    [self.fetchedResultsController performFetch:nil];
    // NSLog(@"Number results: %d", [self.fetchedResultsController.fetchedObjects count]);
    self.filteredListContent = [NSMutableArray arrayWithCapacity:0];
    [self filterContentForSearchText:[self.searchDisplayController.searchBar text] scope:@""];
    [self.searchDisplayController.searchResultsTableView reloadData];
    [self.tableView reloadData];
}

#pragma mark -
#pragma mark Fetched results controller

- (NSFetchedResultsController *)fetchedResultsController {
    
    if (fetchedResultsController != nil) {
        return fetchedResultsController;
    }
    
    /*
     Set up the fetched results controller.
     */
    // Create the fetch request for the entity.
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    // Edit the entity name as appropriate.
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Card"
                                              inManagedObjectContext:[FlashCardsCore mainMOC]];
    if (!displayAllCollections) {
        [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"isDeletedObject = NO and collection = %@", (card ? card.collection : collection)]];
    } else {
        [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"isDeletedObject = NO"]];
    }
    [fetchRequest setEntity:entity];
    // [fetchRequest setFetchBatchSize:100];
    
    // Edit the sort key as appropriate.
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"frontValue" ascending:YES  selector:@selector(caseInsensitiveCompare:)];
    NSArray *sortDescriptors = [[NSArray alloc] initWithObjects:sortDescriptor, nil];
    
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    // Edit the section name key path and cache name if appropriate.
    // nil for section name key path means "no sections".
    NSString *cacheName;
    if (displayAllCollections) {
        cacheName = @"all";
    } else {
        cacheName = [NSString stringWithFormat:@"%@", [(card ? card.collection : collection) objectID]];
    }
    NSFetchedResultsController *aFetchedResultsController = 
        [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                            managedObjectContext:[FlashCardsCore mainMOC]
                                              sectionNameKeyPath:@"frontValueFirstChar"
                                                       cacheName:nil
         ];
    aFetchedResultsController.delegate = self;
    self.fetchedResultsController = aFetchedResultsController;
    
    
    return fetchedResultsController;
}    


#pragma mark -
#pragma mark Memory management

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Relinquish ownership any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
    // Relinquish ownership of anything that can be recreated in viewDidLoad or on demand.
    // For example: self.myOutlet = nil;
}




@end

