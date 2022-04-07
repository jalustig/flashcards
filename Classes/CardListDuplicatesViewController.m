//
//  CardListDuplicatesViewController.m
//  FlashCards
//
//  Created by Jason Lustig on 7/2/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import "FlashCardsAppDelegate.h"
#import "CardListDuplicatesViewController.h"
#import "CardListViewController.h"
#import "CardEditViewController.h"
#import "HelpViewController.h"

#import "FCCollection.h"
#import "FCCardSet.h"
#import "FCCard.h"
#import "FCFlashcardExchangeCardId.h"

#import "MBProgressHUD.h"
#import "DTVersion.h"

@implementation CardListDuplicatesViewController

@synthesize cardList, cardSet, collection;
@synthesize buttonEdit, buttonDone;
@synthesize fetchedResultsController;
@synthesize duplicatesToolbar, tableView;
@synthesize displayAllCardsButton;
@synthesize cardToDeleteIndexPath;
@synthesize HUD;
@synthesize cardsDeleted;

#pragma mark -
#pragma mark View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if (![DTVersion osVersionIsLessThen:@"7.0"]) {
        self.edgesForExtendedLayout= UIRectEdgeNone;
    }
    
    displayAllCardsButton.title = NSLocalizedStringFromTable(@"Display All Cards", @"CardManagement", @"UIBarButtonItem");
    
    buttonEdit = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(editTable)];
    buttonDone = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneEditingTable)];
    
    self.navigationItem.rightBarButtonItem = buttonEdit;
    
    NSError *error = nil;
    if (![[self fetchedResultsController] performFetch:&error]) {
        FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"Error", @"Error", @"UIAlert title"),
                                   [NSString stringWithFormat:NSLocalizedStringFromTable(@"Error: %@ (%@)", @"Error", @"message"), error, [error userInfo] ]);
        return;
    }    
    
    [self setCardCountTitle];
    
    tableView.dataSource = self;
    tableView.delegate = self;

    cardsDeleted = [[NSMutableArray alloc] initWithCapacity:0];
}


- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self.tableView reloadData];
    [self setCardCountTitle];
    
    duplicatesToolbar.hidden = NO;
}

- (void) setCardCountTitle {
    int count = [self.tableView    numberOfRowsInSection:0];
    self.title = [NSString stringWithFormat:FCPluralLocalizedStringFromTable(@"%d Duplicates", @"Plural", @"", [NSNumber numberWithInt:count]), count];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    duplicatesToolbar.hidden = YES;
    [self checkDeletedCardsForSync];
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

- (void)editTable { 
    self.navigationItem.rightBarButtonItem = buttonDone;
    [self.tableView setEditing:YES animated:YES]; 
    [cardsDeleted removeAllObjects];
}
- (void)doneEditingTable { 
    self.navigationItem.rightBarButtonItem = buttonEdit; 
    [self.tableView setEditing:NO animated:YES];
    [self checkDeletedCardsForSync];
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    
    NSManagedObject *entity = nil;
    entity = [fetchedResultsController objectAtIndexPath:indexPath];

    cell.textLabel.text = [[entity valueForKey:@"frontValue"] description];
    cell.detailTextLabel.text = [[entity valueForKey:@"backValue"] description];

    if ([cell.textLabel.text length] == 0) {
        cell.textLabel.text = NSLocalizedStringFromTable(@"(blank)", @"CardManagement", @"");
    }
    if ([cell.detailTextLabel.text length] == 0) {
        cell.detailTextLabel.text = NSLocalizedStringFromTable(@"(blank)", @"CardManagement", @"");
    }

    if ([[entity valueForKey:@"hasImages"] boolValue]) {
        [cell.imageView setImage:[UIImage imageNamed:@"icon-camera.png"]];
    } else {
        [cell.imageView setImage:nil];
    }
    
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    NSManagedObject *entity = [fetchedResultsController objectAtIndexPath:indexPath];
    if ([[entity valueForKey:@"isSpacedRepetition"] boolValue]) {
        [cell setBackgroundColor:[UIColor yellowColor]];
    }
}


- (IBAction) displayAllCards:(id)sender {
    [self.navigationController popViewControllerAnimated:YES];
}
- (IBAction) helpEvent:(id)sender {
    HelpViewController *helpVC = [[HelpViewController alloc] initWithNibName:@"HelpViewController" bundle:nil];
    
    helpVC.title = self.title;
    helpVC.helpText = NSLocalizedStringWithDefaultValue(@"CardListDuplicatesVCHelp", @"Help", [NSBundle mainBundle], @""
    "<p>This screen displays a list of duplicate cards based on the front value.</p>"
    "<p>Yellow cards have been entered into the Spaced Repetition System; clear ones have not.</p>", @"");
    // Pass the selected object to the new view controller.
    [self.navigationController pushViewController:helpVC animated:YES];
    
}


# pragma mark -
# pragma mark Alert functions & error reporting

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (cardToDeleteIndexPath) {
        if (buttonIndex == 0) {
            // Cancel - unmark the item for deletion
            [[tableView cellForRowAtIndexPath:cardToDeleteIndexPath] setEditing:NO animated:NO];
            [[tableView cellForRowAtIndexPath:cardToDeleteIndexPath] setEditing:YES animated:NO];
            return;
        }
        
        if (buttonIndex == 1) {
            // Delete
            [self deleteCard:cardToDeleteIndexPath];
        } else {
            // Remove from card set
            [self removeCardFromCardSet:cardToDeleteIndexPath];
        }
        return;
    }
}

#pragma mark -
#pragma mark MBProgressHUDDelegate methods

- (void)hudWasHidden:(MBProgressHUD *)hud {
    // Remove HUD from screen when the HUD was hidded
    [hud removeFromSuperview];
    hud = nil;
}

- (void)hudWasTapped:(MBProgressHUD *)hud {
    [hud hide:YES];
    [FlashCardsCore syncCancel];
}

#pragma mark - Sync methods

- (void)updateHUDLabel:(NSString*)labelText {
    HUD.labelText = labelText;
}

- (void)checkDeletedCardsForSync {
    BOOL shouldSync = NO;
    for (FCCard *card in cardsDeleted) {
        if ([[card shouldSync] boolValue]) {
            shouldSync = YES;
        }
    }
    if (shouldSync) {
        UIViewController *parentVC  = [FlashCardsCore parentViewController];
        if ([parentVC respondsToSelector:@selector(setShouldSyncN:)]) {
            [parentVC performSelector:@selector(setShouldSyncN:) withObject:[NSNumber numberWithBool:shouldSync]];
        }
    }
}

- (void)isDoneSaving {
    [cardsDeleted removeAllObjects];
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    id <NSFetchedResultsSectionInfo> sectionInfo = [[fetchedResultsController sections] objectAtIndex:section];
    NSUInteger count = [sectionInfo numberOfObjects];
    return count;
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
    
    [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
    
    [self configureCell:cell atIndexPath:indexPath];
    
    return cell;
}


/*
 // Override to support conditional editing of the table view.
 - (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
 // Return NO if you do not want the specified item to be editable.
 return YES;
 }
 */

- (void)deleteCard:(NSIndexPath*)indexPath {
    // Delete the row from the data source
    // [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:YES];
    FCCard *_card = [fetchedResultsController objectAtIndexPath:indexPath];
    NSManagedObjectID *objectID = _card.objectID;
    
    NSManagedObjectContext *tempMOC = [FlashCardsCore tempMOC];
    [tempMOC performBlock:^{
        FCCard *card = (FCCard*)[tempMOC objectWithID:objectID];
        [card setIsDeletedObject:[NSNumber numberWithBool:YES]];
        for (FCCardSet *set in card.cardSet) {
            [set addCardsDeletedObject:card];
        }
        [cardsDeleted addObject:card];
        
        [tempMOC save:nil];
        [FlashCardsCore saveMainMOC];
    }];
}

- (void) removeCardFromCardSet:(NSIndexPath *)indexPath {
    FCCard *card = [fetchedResultsController objectAtIndexPath:indexPath];
    // If it is in more than one card set...
    // Also, if we are looking at the whole collection, then we should just delete it entirely:
    [cardSet removeCard:card];
    [cardsDeleted addObject:card];
    [FlashCardsCore saveMainMOC];
}

// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        
        
        if (cardSet) {
            cardToDeleteIndexPath = indexPath;
            // as per: http://stackoverflow.com/questions/360013/uitableview-intercepting-edit-mode/1249754#1249754
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Are You Sure?", @"FlashCards", @"UIAlert title") 
                                                             message:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Do you want to delete this card, or remove it from the card set \"%@\"?", @"CardManagement", @"message"), cardSet.name]
                                                            delegate:self
                                                   cancelButtonTitle:NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"cancelButtonTitle")
                                                   otherButtonTitles:NSLocalizedStringFromTable(@"Delete Card", @"CardManagement", @"otherButtonTitles"), NSLocalizedStringFromTable(@"Remove from Card Set", @"CardManagement", @"otherButtonTitles"), nil];
            [alert show];
        } else {
            [self deleteCard:indexPath];
        }
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}


/*
 // Override to support rearranging the table view.
 - (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
 }
 */


/*
 // Override to support conditional rearranging of the table view.
 - (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
 // Return NO if you do not want the item to be re-orderable.
 return YES;
 }
 */


#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)theTableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    [self tableView:theTableView didSelectRowAtIndexPath:indexPath];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    FCCard *entity = nil;
    entity = [fetchedResultsController objectAtIndexPath:indexPath];
    
    CardEditViewController *vc = [[CardEditViewController alloc] initWithNibName:@"CardEditViewController" bundle:nil];
    vc.card = entity;
    vc.editMode = modeEdit;
    vc.editInPlace = NO;
    vc.popToViewControllerIndex = [[self.navigationController viewControllers] count]-1;
    
    [self.navigationController pushViewController:vc animated:YES];
    
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
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Card" inManagedObjectContext:[FlashCardsCore mainMOC]];
    if (collection) {
        [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"isDeletedObject = NO and collection = %@ and (self in %@)", collection, cardList]];
    } else {
        [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"isDeletedObject = NO and ANY cardSet = %@ and (self in %@)", cardSet, cardList]];
    }
    [fetchRequest setEntity:entity];
    
    // Edit the sort key as appropriate.
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"frontValue" ascending:YES selector:@selector(caseInsensitiveCompare:)];
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
    [self.tableView beginUpdates];
}


- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type {
    
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}


- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath {
    
   // UITableView *tableView = self.tableView;
    
    switch(type) {
            
        case NSFetchedResultsChangeInsert:
            [self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeUpdate:
            [self configureCell:[self.tableView cellForRowAtIndexPath:indexPath] atIndexPath:indexPath];
            break;
            
        case NSFetchedResultsChangeMove:
            [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
            [self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath]withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}


- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    [self.tableView reloadData];
    [self.tableView endUpdates];
    [self setCardCountTitle];
}


#pragma mark -
#pragma mark Memory management

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Relinquish ownership any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
    
    [[NSNotificationCenter defaultCenter]
     removeObserver:self
     name:NSPersistentStoreCoordinatorStoresDidChangeNotification
     object:[[FlashCardsCore mainMOC] persistentStoreCoordinator]];
    

    [super viewDidUnload];
    
}




@end

