//
//  CardSetListViewController.m
//  FlashCards
//
//  Created by Jason Lustig on 5/28/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import "FlashCardsAppDelegate.h"
#import "CardSetListViewController.h"
#import "CardSetCreateViewController.h"
#import "CardSetViewViewController.h"

#import "FCCardSet.h"
#import "FCCard.h"
#import "FCCollection.h"
#import "FlashCardsCore.h"

#import "UIView+Layout.h"

#import "MBProgressHUD.h"

#import "DTVersion.h"

@implementation CardSetListViewController

@synthesize collection, collectionCardsDueCount, cardsDueCountDict;
@synthesize displayCardSetsOrder;
@synthesize fetchedResultsController;
@synthesize myTableView;
@synthesize displayCardSetsOrderSegmentedControl;
@synthesize deletedCardSet;
@synthesize shouldSync = _shouldSync;
@synthesize HUD;

#pragma mark -
#pragma mark View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    if (![DTVersion osVersionIsLessThen:@"7.0"]) {
        self.edgesForExtendedLayout= UIRectEdgeNone;
    }
    
    cardsDueCountDict = [[NSMutableDictionary alloc] initWithCapacity:0];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateCardsDueCount) name:UIApplicationWillEnterForegroundNotification object:NULL];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateCardsDueCount) name:UIApplicationDidBecomeActiveNotification  object:NULL];

    displayCardSetsOrder = [(NSNumber*)[FlashCardsCore getSetting:@"displayCardSetsOrder"] intValue];
    [displayCardSetsOrderSegmentedControl setSelectedSegmentIndex:displayCardSetsOrder];
    [displayCardSetsOrderSegmentedControl setTitle:NSLocalizedStringFromTable(@"A-Z", @"CardManagement", @"") forSegmentAtIndex:0];
    [displayCardSetsOrderSegmentedControl setTitle:NSLocalizedStringFromTable(@"Newest", @"CardManagement", @"") forSegmentAtIndex:1];

    self.title = NSLocalizedStringFromTable(@"Card Sets", @"CardManagement", @"UIView title");
    
    NSMutableArray *rightBarButtonItems = [[NSMutableArray alloc] initWithCapacity:0];
    
    // create a standard "add" button
    UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                               target:self
                                                                               action:@selector(addEvent)];
    addButton.style = UIBarButtonItemStyleBordered;
    [rightBarButtonItems addObject:addButton];
    UIBarButtonItem *editButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit
                                                                                target:self
                                                                                action:@selector(editEvent)];
    editButton.enabled = YES;
    [rightBarButtonItems addObject:editButton];
    if ([[[FlashCardsCore appDelegate] syncController] canPotentiallySync]) {
        UIBarButtonItem *syncButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                                    target:self
                                                                                    action:@selector(syncEvent)];
        syncButton.enabled = YES;
        [rightBarButtonItems addObject:syncButton];
    }
    [self.navigationItem setRightBarButtonItems:rightBarButtonItems];

    
    NSError *error = nil;
    if (![[self fetchedResultsController] performFetch:&error]) {
        FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"Error", @"Error", @"UIAlert title"),
                                   [NSString stringWithFormat:NSLocalizedStringFromTable(@"Error: %@ (%@)", @"Error", @"message"), error, [error userInfo] ]);
        return;
    }
    
    [self.myTableView reloadData];
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (deletedCardSet) {
        deletedCardSet = nil;
    }
}


- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self updateCardsDueCount];
    [self.myTableView reloadData];
    
}

- (void) updateCardsDueCount {

    // 1. Get all the cards that are due
    // 2. Create a dictionary with key as each card set, and increment each one for each due card.
    
    [cardsDueCountDict removeAllObjects];
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:[NSEntityDescription entityForName:@"Card"
                                        inManagedObjectContext:[FlashCardsCore mainMOC]]];
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"isDeletedObject = NO and collection = %@ and isSpacedRepetition = YES and nextRepetitionDate <= %@", collection, [NSDate date]]];
    NSArray *cards = [[FlashCardsCore mainMOC] executeFetchRequest:fetchRequest error:nil];
    NSSet *cardSetList;
    int mycount;
    for (int i = 0; i < [cards count]; i++) {
        cardSetList = [((FCCard*)[cards objectAtIndex:i]) allCardSets];
        for (FCCardSet *cardSet in cardSetList) {
            if (![cardsDueCountDict objectForKey:[cardSet objectID]]) {
                [cardsDueCountDict setObject:[NSNumber numberWithInt:0] forKey:[cardSet objectID]];
            }
            mycount = [[cardsDueCountDict objectForKey:[cardSet objectID]] intValue];
            [cardsDueCountDict setObject:[NSNumber numberWithInt:(mycount+1)] forKey:[cardSet objectID]];
        }
    }

    [self.myTableView reloadData];

}

- (IBAction)displayCardSetsOrderSegmentedControlDidTouchUpInside:(id)sender {
    int newDisplayOrder = (int)[sender selectedSegmentIndex];
    NSLog(@"new order: %d", newDisplayOrder);
    if (newDisplayOrder != displayCardSetsOrder) {
        displayCardSetsOrder = newDisplayOrder;
        [FlashCardsCore setSetting:@"displayCardSetsOrder" value:[NSNumber numberWithInt:displayCardSetsOrder]];
        // Edit the sort key as appropriate.
        NSSortDescriptor *sortDescriptor;
        if (displayCardSetsOrder == 0) {
            sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)];
        } else {
            sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"dateCreated" ascending:NO];
        }
        NSArray *sortDescriptors = [[NSArray alloc] initWithObjects:sortDescriptor, nil];
        [self.fetchedResultsController.fetchRequest setSortDescriptors:sortDescriptors];
        [self.fetchedResultsController performFetch:nil];
        [self.myTableView reloadData];
    }
}

/*
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}
*/

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (HUD) {
        HUD.delegate = nil;
    }
    [[[FlashCardsCore appDelegate] syncController] setDelegate:nil];
}
/*
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}
*/

- (BOOL)shouldAutorotate {
    UIInterfaceOrientation interfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    return [FlashCardsAppDelegate shouldAutorotate:interfaceOrientation];
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    NSManagedObject *managedObject = [fetchedResultsController objectAtIndexPath:indexPath];
    cell.textLabel.text = [[managedObject valueForKey:@"name"] description];

    if ([cardsDueCountDict objectForKey:[managedObject objectID]]) {
        NSUInteger count = [[cardsDueCountDict objectForKey:[managedObject objectID]] intValue];
        if (count > 0) {
            cell.detailTextLabel.text = [NSString stringWithFormat:FCPluralLocalizedStringFromTable(@"%d cards due", @"Plural", @"", [NSNumber numberWithInt:(int)count]), count];
        } else {
            cell.detailTextLabel.text = @"";
        }
    } else {
        cell.detailTextLabel.text = @"";
    }

    if ([[managedObject valueForKey:@"hasImages"] boolValue]) {
        [cell.imageView setImage:[UIImage imageNamed:@"icon-camera.png"]];
    } else {
        [cell.imageView setImage:nil];
    }
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([cell.detailTextLabel.text length] > 0) {
        [cell setBackgroundColor:[UIColor yellowColor]];
    }
}


#pragma mark -
#pragma mark Events functions


- (void)addEvent {
    CardSetCreateViewController *cardSetCreate = [[CardSetCreateViewController alloc] initWithNibName:@"CardSetCreateViewController" bundle:nil];
    cardSetCreate.collection = self.collection;
    cardSetCreate.editMode = modeCreate;
    
    // Pass the selected object to the new view controller.
    [self.navigationController pushViewController:cardSetCreate animated:YES];
    
}

- (void)editEvent {
    [self.myTableView setEditing:YES animated:YES];
    UIBarButtonItem *editButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                target:self
                                                                                action:@selector(editDoneEvent)];
    NSMutableArray *buttons = [[NSMutableArray alloc] initWithArray:self.navigationItem.rightBarButtonItems];
    [buttons replaceObjectAtIndex:1 withObject:editButton];
    [self.navigationItem setRightBarButtonItems:buttons];
}

- (void)editDoneEvent {
    [self.myTableView setEditing:NO animated:YES];
    UIBarButtonItem *editButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit
                                                                                target:self
                                                                                action:@selector(editEvent)];
    NSMutableArray *buttons = [[NSMutableArray alloc] initWithArray:self.navigationItem.rightBarButtonItems];
    [buttons replaceObjectAtIndex:1 withObject:editButton];
    [self.navigationItem setRightBarButtonItems:buttons];
}



#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    id <NSFetchedResultsSectionInfo> sectionInfo = [[fetchedResultsController sections] objectAtIndex:section];
    return [sectionInfo numberOfObjects];
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        // cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
    
    [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
    
    [self configureCell:cell atIndexPath:indexPath];
    
    return cell;
}


// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}



 // Override to support editing the table view.
 - (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
 
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        FCCardSet *cardSet = [fetchedResultsController objectAtIndexPath:indexPath];
        [cardSet makeDeletedObject];
        [FlashCardsCore saveMainMOC];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }
}

#pragma mark -
#pragma mark MBProgressHUDDelegate methods

- (void)hudWasHidden:(MBProgressHUD *)hud {
    // Remove HUD from screen when the HUD was hidded
    [hud removeFromSuperview];
    if ([hud isEqual:syncHUD]) {
        syncHUD = nil;
    }
    if ([hud isEqual:HUD]) {
        HUD = nil;
    }
    hud = nil;
}

- (void)hudWasTapped:(MBProgressHUD *)hud {
    if ([hud isEqual:syncHUD]) {
        if (![SyncController hudCanCancel:hud]) {
            return;
        }
        [FlashCardsCore syncCancel];
    } else {
        [hud hide:YES];
    }
}

#pragma mark - TICoreDataSync methods

- (void)syncDidFinish:(SyncController *)sync {
    [self persistentStoresDidChange];
}
- (void)syncDidFinish:(SyncController *)sync withError:(NSError *)error {
    [self persistentStoresDidChange];
}

- (void)persistentStoresDidChange {
    NSError *anyError = nil;
    fetchedResultsController = nil;
    BOOL success = [[self fetchedResultsController] performFetch:&anyError];
    if( !success ) {
        NSLog(@"Error fetching: %@", anyError);
    }
    [self updateCardsDueCount];
    [self.myTableView reloadData];

}

#pragma mark - Sync Methods

- (void)setShouldSyncN:(NSNumber*)__shouldSync {
    [self setShouldSync:[__shouldSync boolValue]];
}

-(void)setShouldSync:(BOOL)__shouldSync {
    UIViewController *parentVC  = [FlashCardsCore parentViewController];
    if ([parentVC respondsToSelector:@selector(setShouldSyncN:)]) {
        [parentVC performSelector:@selector(setShouldSyncN:) withObject:[NSNumber numberWithBool:__shouldSync]];
    }
    _shouldSync = __shouldSync;
}

- (void)updateHUDLabel:(NSString*)labelText {
    HUD.labelText = labelText;
}

#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    CardSetViewViewController *cardSetViewVC = [[CardSetViewViewController alloc] initWithNibName:@"CardSetViewViewController" bundle:nil];
    cardSetViewVC.cardSet = [fetchedResultsController objectAtIndexPath:indexPath];
    
    cardSetViewVC.cardsDue = 0;
    if ([cardsDueCountDict objectForKey:[cardSetViewVC.cardSet objectID]]) {
        cardSetViewVC.cardsDue = [[cardsDueCountDict objectForKey:[cardSetViewVC.cardSet objectID]] intValue];
    }
    
    [self.navigationController pushViewController:cardSetViewVC animated:YES];

}

#pragma mark -
#pragma mark Fetched results controller

- (NSFetchedResultsController *)fetchedResultsController {
    
    if (fetchedResultsController != nil) {
        return fetchedResultsController;
    }
    
    // Create the fetch request for the entity.
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    // Edit the entity name as appropriate.
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"CardSet"
                                              inManagedObjectContext:[FlashCardsCore mainMOC]];
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"isDeletedObject = NO and collection = %@ and isMasterCardSet = NO", collection]];
    
    [fetchRequest setEntity:entity];
    
    // Edit the sort key as appropriate.
    NSSortDescriptor *sortDescriptor;
    if (displayCardSetsOrder == 0) {
        sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)];
    } else {
        sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"dateCreated" ascending:NO];
    }
    NSArray *sortDescriptors = [[NSArray alloc] initWithObjects:sortDescriptor, nil];
    
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    // Edit the section name key path and cache name if appropriate.
    // nil for section name key path means "no sections".
    NSFetchedResultsController *aFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                                                                                managedObjectContext:[FlashCardsCore mainMOC]
                                                                                                  sectionNameKeyPath:nil
                                                                                                           cacheName:nil];
    aFetchedResultsController.delegate = self;
    self.fetchedResultsController = aFetchedResultsController;
    
    
    return fetchedResultsController;
}    


#pragma mark -
#pragma mark Fetched results controller delegate


- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
    [self.myTableView beginUpdates];
}


- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type {
    
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [self updateCardsDueCount];
            [self.myTableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [self updateCardsDueCount];
            [self.myTableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}





// TODO: Make sure that the cardsDueCount counts are kept up-to-date when we add new card sets in the middle of the list.
- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath {
    
    UITableView *tableView = self.myTableView;
    
    switch(type) {
            
        case NSFetchedResultsChangeInsert:

            [self updateCardsDueCount];
            [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [self updateCardsDueCount];

            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeUpdate:
            [self configureCell:[tableView cellForRowAtIndexPath:indexPath] atIndexPath:indexPath];
            break;
            
        case NSFetchedResultsChangeMove:
            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
            [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath]withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}


- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    [self.myTableView endUpdates];
}

@end

