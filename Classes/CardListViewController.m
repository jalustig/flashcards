//
//  CardListViewController.m
//  FlashCards
//
//  Created by Jason Lustig on 5/28/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import "FlashCardsAppDelegate.h"
#import "CardListViewController.h"
#import "CardEditViewController.h"
#import "CardEditMultipleViewController.h"
#import "CardListDuplicatesViewController.h"

#import "FCCollection.h"
#import "FCCardSet.h"
#import "FCCard.h"
#import "FCCardSetCard.h"
#import "FCFlashcardExchangeCardId.h"

#import "UIView+Layout.h"
#import "UIAlertView+Blocks.h"
#import "UIActionSheet+Blocks.h"

#import "MBProgressHUD.h"

#import "DTVersion.h"

// SOLUTION TO THE MAJOR PROBLEM: https://devforums.apple.com/message/310101#310101

@implementation CardListViewController

@synthesize cardSet, collection;
@synthesize fetchedResultsController, searchResultsController;
@synthesize savedSearchTerm, searchIsActive, myTableView;
@synthesize duplicatesListContent;
@synthesize displayOptions;
@synthesize cardToDeleteIndexPath;
@synthesize HUD;
@synthesize cardsDeleted;
@synthesize shouldSync = _shouldSync;
@synthesize viewAlphabetical;
@synthesize cardsOrdered;
@synthesize displayOptionSelected;

#pragma mark -
#pragma mark View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    if (![DTVersion osVersionIsLessThen:@"7.0"]) {
        self.edgesForExtendedLayout= UIRectEdgeNone;
    }

    viewAlphabetical = YES;
    displayOptionSelected = 0;
    BOOL defaultDisplayCardsCustomOrder = [FlashCardsCore getSettingBool:@"displayCardsCustomOrder"];
    if (defaultDisplayCardsCustomOrder) {
        if (self.cardSet) {
            if ([self.cardSet.hasCardOrder boolValue]) {
                displayOptionSelected = 1;
                viewAlphabetical = NO;
            }
        }
    }
    [displayOptions setSelectedSegmentIndex:displayOptionSelected];
    [displayOptions setTitle:NSLocalizedStringFromTable(@"A-Z", @"CardManagement", @"") forSegmentAtIndex:0];
    [displayOptions setTitle:NSLocalizedStringFromTable(@"Ordered", @"CardManagement", @"") forSegmentAtIndex:1];
    [displayOptions setTitle:NSLocalizedStringFromTable(@"Duplicates", @"CardManagement", @"") forSegmentAtIndex:2];

    [self showEditDoneButton:NO];
    
    if (viewAlphabetical) {
        NSError *error = nil;
        if (![[self activeResultsControllerForTableView:self.myTableView] performFetch:&error]) {
            FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"Error", @"Error", @"UIAlert title"),
                                       [NSString stringWithFormat:NSLocalizedStringFromTable(@"Error: %@ (%@)", @"Error", @"message"), error, [error userInfo] ]);
            return;
        }    
    }
    
    [self setCardCountTitle];
    
    if (self.savedSearchTerm && viewAlphabetical) {
        [self.searchDisplayController setActive:self.searchIsActive];
        [self.searchDisplayController.searchBar setText:savedSearchTerm];
        self.savedSearchTerm = nil;
    } else {
        self.searchDisplayController.searchBar.showsCancelButton = NO;
    }
    
    if (self.cardSet) {
        NSSet *_cards = [self.cardSet allCards];
        for (FCCard *_card in _cards) {
            [_card setCurrentCardSet:self.cardSet];
            FCLog(@"Order: %@", [_card valueForKey:@"cardOrder"]);
        }
    }
    
    cardsOrdered = [NSMutableArray arrayWithCapacity:0];
    cardsDeleted = [NSMutableArray arrayWithCapacity:0];

    [self setShouldSync:NO];
    
    [self.myTableView reloadData];
}

- (void) showEditDoneButton:(BOOL)yesno {

    NSMutableArray *rightBarButtonItems = [[NSMutableArray alloc] initWithCapacity:0];
    
    // create a standard "add" button
    UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                               target:self
                                                                               action:@selector(addEvent)];
    addButton.style = UIBarButtonItemStyleBordered;
    
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                target:self
                                                                                action:@selector(editDoneEvent)];
    
    UIBarButtonItem *editButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit
                                                                                target:self
                                                                                action:@selector(editEvent)];
    editButton.enabled = YES;

    UIBarButtonItem *syncButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                                target:self
                                                                                action:@selector(syncEvent)];
    syncButton.enabled = YES;    

    if (yesno) {
        // show the DONE button:
        [rightBarButtonItems addObject:doneButton];
        [cardsDeleted removeAllObjects];
    } else {
        [rightBarButtonItems addObject:addButton];
        [rightBarButtonItems addObject:editButton];
    }
    
    if ((self.cardSet && [self.cardSet.shouldSync boolValue]) ||
        [FlashCardsCore appIsSyncing]) {
        [rightBarButtonItems addObject:syncButton];
    }
    [self.navigationItem setRightBarButtonItems:rightBarButtonItems];


}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if (!viewAlphabetical) {
        [self showCustomOrder];
        [self setCardCountTitle];
    }
}

- (void) setCardCountTitle {
    int count;
    if (viewAlphabetical) {
        count = (int)[[[self activeResultsControllerForTableView:self.myTableView] fetchedObjects] count];
    } else {
        count = (int)[cardsOrdered count];
    }
    if (self.searchDisplayController.isActive) {
        self.title = [NSString stringWithFormat:FCPluralLocalizedStringFromTable(@"%d Matches", @"Plural", @"", [NSNumber numberWithInt:count]), count];
    } else {
        self.title = [NSString stringWithFormat:FCPluralLocalizedStringFromTable(@"%d Cards", @"Plural", @"", [NSNumber numberWithInt:count]), count];
    }
}

- (IBAction) displayDuplicates:(id)sender {
    
    CardListDuplicatesViewController *dupesVC = [[CardListDuplicatesViewController alloc] initWithNibName:@"CardListDuplicatesViewController" bundle:nil];
    [self findDuplicateCards];
    dupesVC.cardList = duplicatesListContent;
    dupesVC.collection = self.collection;
    dupesVC.cardSet = self.cardSet;
    
    [self.navigationController pushViewController:dupesVC animated:YES];
    return;
}

- (void) findDuplicateCards {
    // find all the duplicates:
    duplicatesListContent = [[NSMutableArray alloc] initWithCapacity:0];
    NSArray *listContent = [[self activeResultsControllerForTableView:self.myTableView] fetchedObjects];
    if ([listContent count] == 0) {
        return;
    }
    FCCard *currentCard;
    FCCard *nextCard;
    for (int i = 0; i < ([listContent count]-1); i++) {
        currentCard =    [listContent objectAtIndex:i];
        // resolves: http://www.bugsense.com/dashboard/project/1777ceac/error/4624105
        nextCard = nil;
        if ((i+1) < [listContent count]) {
            nextCard = [listContent objectAtIndex:(i+1)];
        }
        if (!nextCard) {
            break;
        }
        if ([currentCard.frontValue isEqual:nextCard.frontValue]) {
            [duplicatesListContent insertObject:currentCard atIndex:[duplicatesListContent count]];
            [duplicatesListContent insertObject:nextCard atIndex:[duplicatesListContent count]];
            i++;
        }
    }    
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (HUD) {
        HUD.delegate = nil;
    }
    [[[FlashCardsCore appDelegate] syncController] setDelegate:nil];
}

- (void)viewDidDisappear:(BOOL)animated {

    self.searchIsActive = self.searchDisplayController.isActive;
    self.savedSearchTerm = [self.searchDisplayController.searchBar text];

    [super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotate {
    UIInterfaceOrientation interfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    return [FlashCardsAppDelegate shouldAutorotate:interfaceOrientation];
}

- (void)tableView:(UITableView*)tableView configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    FCCard *card;
    if (viewAlphabetical) {
        NSFetchedResultsController *controller = [self activeResultsControllerForTableView:tableView];
        card = [controller objectAtIndexPath:indexPath];
    } else {
        card = [cardsOrdered objectAtIndex:indexPath.row];
    }
    cell.textLabel.text = card.frontValue;
    cell.detailTextLabel.text = card.backValue;
    
    if ([cell.textLabel.text length] == 0) {
        cell.textLabel.text = NSLocalizedStringFromTable(@"(blank)", @"CardManagement", @"");
    }
    if ([cell.detailTextLabel.text length] == 0) {
        cell.detailTextLabel.text = NSLocalizedStringFromTable(@"(blank)", @"CardManagement", @"");
    }
    
    if ([card.hasImages boolValue]) {
        [cell.imageView setImage:[UIImage imageNamed:@"icon-camera.png"]];
    } else {
        [cell.imageView setImage:nil];
    }
    
}

# pragma mark -
# pragma mark Alert functions & error reporting

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (cardToDeleteIndexPath) {
        if (buttonIndex == 0) {
            // Cancel - unmark the item for deletion
            [[myTableView cellForRowAtIndexPath:cardToDeleteIndexPath] setEditing:NO animated:NO];
            [[myTableView cellForRowAtIndexPath:cardToDeleteIndexPath] setEditing:YES animated:NO];
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
    if (viewAlphabetical) {
        BOOL success = [[self fetchedResultsController] performFetch:&anyError];
        if( !success ) {
            NSLog(@"Error fetching: %@", anyError);
        }
        [self.myTableView reloadData];
    } else {
        [self showCustomOrder];
    }
}

#pragma mark - Sync methods

- (void)setShouldSyncN:(NSNumber*)shouldSync {
    [self setShouldSync:[shouldSync boolValue]];
}

-(void)setShouldSync:(BOOL)__shouldSync {
    UIViewController *parentVC  = [FlashCardsCore parentViewController];
    if ([parentVC isEqual:self]) {
        parentVC = [FlashCardsCore parentViewController:1];
        if ([parentVC isEqual:self]) {
            return;
        }
    }
    if ([parentVC respondsToSelector:@selector(setShouldSyncN:)]) {
        [parentVC performSelector:@selector(setShouldSyncN:) withObject:[NSNumber numberWithBool:__shouldSync]];
    }
    _shouldSync = __shouldSync;
}

- (void)updateHUDLabel:(NSString*)labelText {
    HUD.labelText = labelText;
}

- (void)checkDeletedCardsForSync {
    BOOL __shouldSync = NO;
    for (NSManagedObjectID *cardId in cardsDeleted) {
        FCCard *card = (FCCard*)[[FlashCardsCore mainMOC] objectWithID:cardId];
        if ([[card shouldSync] boolValue]) {
            __shouldSync = YES;
            SyncController *controller = [[FlashCardsCore appDelegate] syncController];
            if (controller && [card.shouldSync boolValue]) {
                for (FCCardSet *_cardSet in [card allCardSets]) {
                    if ([_cardSet isQuizletSet]) {
                        [controller setQuizletDidChange:YES];
                    }
                }
            }
        }
    }

    [self setShouldSync:([self shouldSync] || __shouldSync)];
}

- (void)sync {
    [FlashCardsCore showSyncHUD];
    [FlashCardsCore sync];
}

- (void)isDoneSaving {
    [cardsDeleted removeAllObjects];
}

#pragma mark -
#pragma mark Events functions

- (void)addEvent {
    if ([FlashCardsAppDelegate isIpad]) {
        
        RIButtonItem *cancelItem = [RIButtonItem item];
        cancelItem.label = NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"");
        cancelItem.action = ^{};
        
        RIButtonItem *multipleCards = [RIButtonItem item];
        multipleCards.label = NSLocalizedStringFromTable(@"Create Multiple Cards", @"CardManagement", @"");
        multipleCards.action = ^{
            [self createMultipleCards];
        };
        
        RIButtonItem *singleCard = [RIButtonItem item];
        singleCard.label = NSLocalizedStringFromTable(@"Create One Card", @"CardManagement", @"");
        singleCard.action = ^{
            [self createSingleCard];
        };
        
        UIActionSheet *action = [[UIActionSheet alloc] initWithTitle:@""
                                                    cancelButtonItem:cancelItem
                                               destructiveButtonItem:nil
                                                    otherButtonItems:multipleCards, singleCard, nil];
        action.actionSheetStyle = UIActionSheetStyleBlackOpaque;
        [action showFromBarButtonItem:(UIBarButtonItem*)(self.navigationItem.rightBarButtonItems[0])
                             animated:YES];
        
    } else {
        [self createSingleCard];
    }
}

- (void)createMultipleCards {
    CardEditMultipleViewController *vc = [[CardEditMultipleViewController alloc] initWithNibName:@"CardEditMultipleViewController" bundle:nil];
    vc.collection = self.collection;
    vc.cardSet = self.cardSet;
    if (!self.cardSet) {
        if ([self.collection cardSetsCount] == 1) {
            FCCardSet *cardSetToAdd = [[[collection allCardSets] allObjects] objectAtIndex:0];
            vc.cardSet = cardSetToAdd;
        }
    }
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)createSingleCard {
    CardEditViewController *vc = [[CardEditViewController alloc] initWithNibName:@"CardEditViewController" bundle:nil];
    vc.cardSet = self.cardSet;
    vc.collection = self.collection;
    vc.editMode = modeCreate;
    vc.popToViewControllerIndex = [[self.navigationController viewControllers] count]-1;
    
    // Pass the selected object to the new view controller.
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)editEvent {
    [self showEditDoneButton:YES];
    [self.myTableView setEditing:YES animated:YES];
}

- (void)editDoneEvent {
    self.searchDisplayController.searchBar.hidden = NO;
    [self showEditDoneButton:NO];
    [self.myTableView setEditing:NO animated:YES];
    [self setCardCountTitle];
}

- (IBAction)displayOptionsDidTouchUpInside:(id)sender {
    if ([sender selectedSegmentIndex] == 2) {
        [sender setSelectedSegmentIndex:displayOptionSelected];
        [self displayDuplicates:nil];
        return;
    }
    if ([sender selectedSegmentIndex] == 0) {
        [self setupDisplayOrder:YES]; // set display: alphabetical
        [FlashCardsCore setSetting:@"displayCardsCustomOrder" value:@NO];
    } else {
        [self setupDisplayOrder:NO];  // set display: custom order
    }
    displayOptionSelected = [sender selectedSegmentIndex];
}

- (void)showCustomOrder {
    if (HUD) {
        [HUD hide:YES];
    }
    
    [FlashCardsCore setSetting:@"displayCardsCustomOrder" value:@YES];

    for (FCCard *card in [self.cardSet allCards]) {
        [card setCardOrder:@-2];
        [card setCurrentCardSet:self.cardSet];
    }
    
    viewAlphabetical = NO;
    // reload fetch controller
    NSSet *cardsList = [self.cardSet allCards];
    for (FCCard *card in cardsList) {
        FCLog(@"Order: %d", [[card cardOrder] intValue]);
    }
    [cardsOrdered removeAllObjects];
    [cardsOrdered addObjectsFromArray:[cardsList allObjects]];
    [cardsOrdered sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"cardOrder" ascending:YES]]];
    // as per: http://stackoverflow.com/a/4153015/353137
    [self.myTableView setTableHeaderView:nil];
    
    [self.myTableView reloadData];
}

- (void)setupDisplayOrder:(BOOL)alphabetical {
    BOOL mustSwitch = NO;
    if (alphabetical) {
        // display the cards alphabetically:
        if (!viewAlphabetical) {
            mustSwitch = YES;
        }
        viewAlphabetical = YES;
        if (mustSwitch) {
            // reload fetch controller
            fetchedResultsController = nil;
            [self.myTableView reloadData];
        }
        // as per: http://stackoverflow.com/a/4153015/353137
        [self.myTableView setTableHeaderView:[[self searchDisplayController] searchBar]];
    } else {
        if (!self.cardSet) {
            NSString *message = NSLocalizedStringFromTable(@"You can only set a custom card order within a Card Set, not a Collection (top level group).", @"CardManagement", @"");
            FCDisplayBasicErrorMessage(@"", message);
            viewAlphabetical = YES;
            [displayOptions setSelectedSegmentIndex:0];
            displayOptionSelected = 0;
            return;
        } else if (![[self.cardSet hasCardOrder] boolValue]) {
            // doesn't have custom card order set up yet. Ask the user what to do
            RIButtonItem *cancelItem = [RIButtonItem item];
            cancelItem.label = NSLocalizedStringFromTable(@"Not Now", @"Feedback", @"");
            cancelItem.action = ^{
                [displayOptions setSelectedSegmentIndex:0];
                displayOptionSelected = 0;
                viewAlphabetical = YES;
            };
            
            RIButtonItem *setupItem = [RIButtonItem item];
            setupItem.label = NSLocalizedStringFromTable(@"Set Custom Order", @"CardManagement", @"");
            setupItem.action = ^{
                // show HUD:
                HUD = [[MBProgressHUD alloc] initWithView:self.view];
                // Add HUD to screen
                [self.view addSubview:HUD];
                // Regisete for HUD callbacks so we can remove it from the window at the right time
                HUD.delegate = self;
                HUD.minShowTime = 1.0;
                [HUD show:YES];
                
                NSManagedObjectContext *tempMOC = [FlashCardsCore tempMOC];
                [tempMOC performBlock:^{
                    
                    FCCardSet *tempCardSet = (FCCardSet*)[tempMOC objectWithID:[cardSet objectID]];
                    [tempCardSet setupInitialCardOrder];
                    
                    [tempMOC save:nil];
                    [FlashCardsCore saveMainMOC];
                    
                    // set display order to nonalphabetical:
                    [displayOptions setSelectedSegmentIndex:1];
                    displayOptionSelected = 1;
                    [self performSelectorOnMainThread:@selector(showCustomOrder) withObject:nil waitUntilDone:NO];
                }];
            };
            
            NSString *message = NSLocalizedStringFromTable(@"This Card Set does not yet have a custom card order. Would you like to set up one now?", @"CardManagement", @"");
        
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@""
                                                            message:message
                                                   cancelButtonItem:cancelItem
                                                   otherButtonItems:setupItem, nil];
            [alert show];
        } else {
            // display the cards in the proper order now:
            [self showCustomOrder];
        }
    }
}

#pragma mark -
#pragma mark Table view data source


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (viewAlphabetical) {
        return [[[self activeResultsControllerForTableView:tableView] sections] count];
    } else {
        return 1;
    }
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView {
    NSMutableArray *titles = [[NSMutableArray alloc] initWithCapacity:0];
    if (!viewAlphabetical) {
        return titles;
    }
    id <NSFetchedResultsSectionInfo> sectionInfo;
    for (int i = 0; i < [[[self activeResultsControllerForTableView:tableView] sections] count]; i++) {
        sectionInfo = [[[self activeResultsControllerForTableView:tableView] sections] objectAtIndex:i];
        [titles addObject:sectionInfo.name];
    }
    return titles;
    
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index {
    return index;
}

- (NSString *)sectionIndexTitleForSectionName:(NSString *)sectionName {
    return sectionName;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (viewAlphabetical) {
        id <NSFetchedResultsSectionInfo> sectionInfo = [[[self activeResultsControllerForTableView:tableView] sections] objectAtIndex:section];
        return [sectionInfo numberOfObjects];
    } else {
        return [cardsOrdered count];
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (viewAlphabetical) {
        id <NSFetchedResultsSectionInfo> sectionInfo = [[[self activeResultsControllerForTableView:tableView] sections] objectAtIndex:section];
        return [sectionInfo name];
    } else {
        return nil;
    }
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
    
    [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
    
    [self tableView:tableView configureCell:cell atIndexPath:indexPath];
    
    return cell;
}


- (void)deleteCard:(NSIndexPath*)indexPath {
    // Delete the row from the data source
    // [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:YES];
    FCCard *_card;
    if (viewAlphabetical) {
        UITableView *tv;
        if (self.searchDisplayController.isActive) {
            tv = self.searchDisplayController.searchResultsTableView;
        } else {
            tv = self.myTableView;
        }
        _card = [[self activeResultsControllerForTableView:tv] objectAtIndexPath:indexPath];
    } else {
        _card = [cardsOrdered objectAtIndex:indexPath.row];
    }
    NSManagedObjectID *objectID = _card.objectID;
    
    NSManagedObjectContext *tempMOC = [FlashCardsCore tempMOC];
    [tempMOC performBlock:^{
        FCCard *card = (FCCard*)[tempMOC objectWithID:objectID];

        // Important to do this first so it can propagate to the card set too
        if ([card.shouldSync boolValue]) {
            [card setSyncStatus:[NSNumber numberWithInt:syncChanged]];
        }
        
        [card setIsDeletedObject:[NSNumber numberWithBool:YES]];
        NSSet *cardSets = [NSSet setWithSet:[card allCardSets]];
        for (FCCardSet *set in cardSets) {
            [set removeCard:card];
        }
        [cardsDeleted addObject:card.objectID];

        [tempMOC save:nil];
        [FlashCardsCore saveMainMOC];
        if (!viewAlphabetical) {
            [self performSelectorOnMainThread:@selector(showCustomOrder) withObject:nil waitUntilDone:NO];
        }
    }];

    if (!self.myTableView.isEditing && [_card.shouldSync boolValue]) {
        [self setShouldSync:YES];
    }
}

- (void) removeCardFromCardSet:(NSIndexPath *)indexPath {
    UITableView *tv;
    if (self.searchDisplayController.isActive) {
        tv = self.searchDisplayController.searchResultsTableView;
    } else {
        tv = self.myTableView;
    }
    FCCard *_card;
    if (viewAlphabetical) {
        _card = [[self activeResultsControllerForTableView:tv] objectAtIndexPath:indexPath];
    } else {
        _card = [cardsOrdered objectAtIndex:indexPath.row];
    }
    NSManagedObjectID *objectID = _card.objectID;
    NSManagedObjectID *cardSetID = cardSet.objectID;

    NSManagedObjectContext *tempMOC = [FlashCardsCore tempMOC];
    [tempMOC performBlock:^{
        FCCard *card = (FCCard*)[tempMOC objectWithID:objectID];
        FCCardSet *tCardSet = (FCCardSet*)[tempMOC objectWithID:cardSetID];
        
        // Important to do this **before** removing the card from the set, so it
        // propagates to the whole set to upload.
        if ([card.shouldSync boolValue]) {
            [card setSyncStatus:[NSNumber numberWithInt:syncChanged]];
        }
        
        // If it is in more than one card set...
        // Also, if we are looking at the whole collection, then we should just delete it entirely:
        [tCardSet removeCard:card fromThisSetOnly:YES];
        [card addCardSetsDeletedFromObject:tCardSet];
        [cardsDeleted addObject:card.objectID];

        [tempMOC save:nil];
        [FlashCardsCore saveMainMOC];
        if (!viewAlphabetical) {
            [self performSelectorOnMainThread:@selector(showCustomOrder) withObject:nil waitUntilDone:NO];
        }
    }];
}

// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        
        
        if (cardSet) {
            // [retain] the indexPath so that it is still around even after the user makes his/her choice with the UIAlertView
            cardToDeleteIndexPath = indexPath;
            // as per: http://stackoverflow.com/questions/360013/uitableview-intercepting-edit-mode/1249754#1249754
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Are You Sure?", @"FlashCards", @"UIAlert title") 
                                                             message:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Do you want to delete this card, or remove it from the card set \"%@\"?", @"CardManagement", @"message"), cardSet.name]
                                                           delegate:self
                                                  cancelButtonTitle:NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"cancelButtonTitle")
                                                  otherButtonTitles:NSLocalizedStringFromTable(@"Delete Card", @"CardManagement", @"otherButtonTitles"), NSLocalizedStringFromTable(@"Remove from Card Set", @"CardManagement", @"otherButtonTitles"), nil];
            [alert show];
        } else {
            // this is already working;
            [self deleteCard:indexPath];
        }
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }
}


// Override to support rearranging the table view.
- (void) tableView:(UITableView *)tableView
moveRowAtIndexPath:(NSIndexPath *)fromIndexPath
       toIndexPath:(NSIndexPath *)toIndexPath {

    // To limit the number of sync changes for the custom order, each custom
    // order is 10000 higher than the next. With Int32, that gives the possibility
    // of 430,000 cards in a set before exhausting the number system.

    // If a card is moved up one spot, then the two cards switch numbers.
    
    // If a card is moved to the front or back of the list, then we just add
    // or remove 10000 from the item, so that the order numbers don't get too close.
    
    // When a card is moved to spot [n], new card order number = avg(card[n-1][number],
    // card[n+1][number) -- thus we can have 13 moves. If cards get too close
    // then we can reallocate them.

    
    int oldLocation = fromIndexPath.row;
    int newLocation = toIndexPath.row;

    FCCard *currentCard = [cardsOrdered objectAtIndex:oldLocation];
    FCCardSetCard *currentCardOrder = [currentCard cardSetOrderObjectForSet:self.cardSet];

    if (abs(newLocation-oldLocation) == 1) {
        // the two objects are just switching location
        FCCard *card1 = [cardsOrdered objectAtIndex:oldLocation];
        FCCard *card2 = [cardsOrdered objectAtIndex:newLocation];
        FCCardSetCard *obj1 = [card1 cardSetOrderObjectForSet:self.cardSet];
        FCCardSetCard *obj2 = [card2 cardSetOrderObjectForSet:self.cardSet];
        NSNumber *temp = [obj1 cardOrder];
        [obj1 setCardOrder:[obj2 cardOrder]];
        [card1 setCardOrder:[obj1 cardOrder]];
        [obj2 setCardOrder:temp];
        [card2 setCardOrder:[obj2 cardOrder]];
    } else if (newLocation >= ([cardsOrdered count]-1)) {
        // we're moving the card to the last location in the set:
        int max = [self.cardSet maxCardOrder];
        [currentCardOrder setCardOrder:[NSNumber numberWithInt:(max + 10000)]];
        [currentCard setCardOrder:[currentCardOrder cardOrder]];
    } else if (newLocation == 0) {
        // we're moving the card to the first location in the set:
        int min = [self.cardSet minCardOrder];
        [currentCardOrder setCardOrder:[NSNumber numberWithInt:(min - 10000)]];
        [currentCard setCardOrder:[currentCardOrder cardOrder]];
    } else {
        // we're moving the card somehwere **else** in the set (in the middle)
        // so there are two spots, one above the new location and one below it.
        FCCard *cardBelow = [cardsOrdered objectAtIndex:(newLocation-1)];
        FCCard *cardAbove = [cardsOrdered objectAtIndex:(newLocation)];
        int orderBelow = [cardBelow cardSetOrderInSet:self.cardSet];
        int orderAbove = [cardAbove cardSetOrderInSet:self.cardSet];
        
        if (abs(orderAbove-orderBelow) < 30) {
            // the cards are too close. it's time to reallocate the numbers!
            int i = 0;
            for (FCCard *card in cardsOrdered) {
                FCCardSetCard *order = [card cardSetOrderObjectForSet:self.cardSet];
                [order setCardOrder:[NSNumber numberWithInt:i]];
                [card setCardOrder:[order cardOrder]];
                i += 10000;
            }
            
            int orderBelow = [cardBelow cardSetOrderInSet:self.cardSet];
            int orderAbove = [cardAbove cardSetOrderInSet:self.cardSet];
            int newOrder = ((orderBelow + orderAbove) / 2);
            [currentCardOrder setCardOrder:[NSNumber numberWithInt:newOrder]];
            [currentCard setCardOrder:[currentCardOrder cardOrder]];

        } else {
            int newOrder = ((orderBelow + orderAbove) / 2);
            [currentCardOrder setCardOrder:[NSNumber numberWithInt:newOrder]];
            [currentCard setCardOrder:[currentCardOrder cardOrder]];
        }
    }
    
    [cardsOrdered sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"cardOrder" ascending:YES]]];
    
    [cardSet setSyncStatus:[NSNumber numberWithInt:syncChanged]];
    
    [FlashCardsCore saveMainMOC];
}


// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    if (viewAlphabetical) {
        return NO;
    } else {
        if (cardSet) {
            if ([cardSet.isSubscribed boolValue]) {
                return NO;
            }
        }
        return YES;
    }
}


#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    [self tableView:tableView didSelectRowAtIndexPath:indexPath];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    FCCard *entity;
    if (viewAlphabetical) {
        entity = (FCCard*)[[self activeResultsControllerForTableView:tableView] objectAtIndexPath:indexPath];
    } else {
        entity = [cardsOrdered objectAtIndex:indexPath.row];
    }
    
    CardEditViewController *cardEditVC = [[CardEditViewController alloc] initWithNibName:@"CardEditViewController" bundle:nil];
    cardEditVC.card = entity;
    cardEditVC.editMode = modeEdit;
    cardEditVC.editInPlace = NO;
    cardEditVC.collection = self.collection;
    cardEditVC.popToViewControllerIndex = [[self.navigationController viewControllers] count]-1;

    
    [self.navigationController pushViewController:cardEditVC animated:YES];

}

#pragma mark -
#pragma mark Content Filtering

- (void)filterContentForSearchText:(NSString*)searchText scope:(NSString*)scope {
    NSMutableArray *predicates = [[NSMutableArray alloc] initWithCapacity:0];
    [predicates addObject:[NSPredicate predicateWithFormat:@"isDeletedObject = NO"]];
    if (collection) {
        [predicates addObject:[NSPredicate predicateWithFormat:@"collection = %@", collection]];
    } else {
        [predicates addObject:[NSPredicate predicateWithFormat:@"ANY cardSet = %@", cardSet]];
    }
    if ([self.searchDisplayController.searchBar.text length] > 0) {
        [predicates addObject: [NSPredicate predicateWithFormat:@"frontValue CONTAINS[cd] %@ or backValue CONTAINS[cd] %@", self.searchDisplayController.searchBar.text, self.searchDisplayController.searchBar.text]];
    }
    [self.searchResultsController.fetchRequest setPredicate:[NSCompoundPredicate andPredicateWithSubpredicates:predicates]];
    NSError *error = nil;
    if (![self.searchResultsController performFetch:&error]) {
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
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
    NSMutableArray *predicates = [[NSMutableArray alloc] initWithCapacity:0];
    [predicates addObject:[NSPredicate predicateWithFormat:@"isDeletedObject = NO"]];
    if (collection) {
        [predicates addObject:[NSPredicate predicateWithFormat:@"collection = %@", collection]];
    } else {
        [predicates addObject:[NSPredicate predicateWithFormat:@"ANY cardSet = %@", cardSet]];
    }
    [self.searchResultsController.fetchRequest setPredicate:[NSCompoundPredicate andPredicateWithSubpredicates:predicates]];
    
    [self showEditDoneButton:NO];
}

- (void)searchDisplayControllerDidEndSearch:(UISearchDisplayController *)controller {
    [self setCardCountTitle];
}

#pragma mark -
#pragma mark Fetched results controller

// This FRC is used for the full table, and has it's own cache
- (NSFetchedResultsController *) fetchedResultsController {
    if (fetchedResultsController == nil) {
        self.fetchedResultsController = [self buildFetchedResultsController:@"Root"];
        [NSFetchedResultsController deleteCacheWithName:@"Root"];
    }
    return fetchedResultsController;
}    

// This FRC is used for the search table, and it's cache is disabled
- (NSFetchedResultsController *) searchResultsController {
    if (searchResultsController == nil) {
        self.searchResultsController = [self buildFetchedResultsController:nil];
        [NSFetchedResultsController deleteCacheWithName:nil];
    }
    return searchResultsController;
}

// Select one FRC or the other based on the specified tableView
- (NSFetchedResultsController *) activeResultsControllerForTableView: (UITableView *)tableView {
    if (tableView == self.searchDisplayController.searchResultsTableView) {
        return self.searchResultsController;
    } else {
        return self.fetchedResultsController;
    }
}

// Both FRC's use the same table ordering and section headers
- (NSFetchedResultsController *) buildFetchedResultsController: (NSString *)cacheName {
    
    // Create the fetch request for the entity.
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    
    // Edit the entity name as appropriate.
    [fetchRequest setEntity:[NSEntityDescription entityForName:@"Card" inManagedObjectContext:[FlashCardsCore mainMOC]]];
    [fetchRequest setReturnsObjectsAsFaults:NO];
    
    // resolves: https://rink.hockeyapp.net/manage/apps/20975/crash_reasons/8573313
    // Always sort A-Z because the NSFetchedResultsController* needs a sort descriptor.
    // We will custom sort if necessary, later
    // A-Z
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"frontValue" ascending:YES selector:@selector(caseInsensitiveCompare:)];
    [fetchRequest setSortDescriptors:@[sortDescriptor]];
    
    NSMutableArray *predicates = [NSMutableArray arrayWithCapacity:0];
    [predicates addObject:[NSPredicate predicateWithFormat:@"isDeletedObject = NO"]];
    if (collection) {
        [predicates addObject:[NSPredicate predicateWithFormat:@"collection = %@", collection]];
    } else {
        [predicates addObject:[NSPredicate predicateWithFormat:@"ANY cardSet = %@", cardSet]];
    }
    [fetchRequest setPredicate:[NSCompoundPredicate andPredicateWithSubpredicates:predicates]];
    
    // Edit the section name key path and cache name if appropriate.
    // nil for section name key path means "no sections".
    NSFetchedResultsController *aFetchedResultsController = 
    [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                        managedObjectContext:[FlashCardsCore mainMOC]
                                          sectionNameKeyPath:@"frontValueFirstChar"
                                                   cacheName:nil];
    aFetchedResultsController.delegate = self;
    
    
    NSError *error = nil;
    if (![aFetchedResultsController performFetch:&error]) {
        FCDisplayBasicErrorMessage(@"Error",
                                   [NSString stringWithFormat:@"Unresolved error %@, %@", error, [error userInfo]]);
    }
    
    return aFetchedResultsController;
}    

#pragma mark -
#pragma mark Fetched results controller delegate


- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
    if ([controller isEqual:searchResultsController]) {
        [self.searchDisplayController.searchResultsTableView beginUpdates];
    } else if ([controller isEqual:fetchedResultsController]) {
        [self.myTableView beginUpdates];
    }
}


- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type {
    UITableView *tableView;
    if ([controller isEqual:searchResultsController]) {
        tableView = self.searchDisplayController.searchResultsTableView;
    } else if ([controller isEqual:fetchedResultsController]) {
        tableView = self.myTableView;
    } else {
        return;
    }

    switch(type) {
        case NSFetchedResultsChangeInsert:
            [tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}


- (void)controller:(NSFetchedResultsController *)controller
   didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath
     forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath {
    UITableView *tableView;
    if ([controller isEqual:searchResultsController]) {
        tableView = self.searchDisplayController.searchResultsTableView;
    } else if ([controller isEqual:fetchedResultsController]) {
        tableView = self.myTableView;
    } else {
        return;
    }
    
    switch(type) {
            
        case NSFetchedResultsChangeInsert:
            [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            
            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeUpdate:
            // [self tableView:tableView configureCell:[tableView cellForRowAtIndexPath:indexPath] atIndexPath:[NSArray arrayWithObject:indexPath]];
            [tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeMove:
            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                             withRowAnimation:UITableViewRowAnimationFade];
            [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath]
                             withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    if ([controller isEqual:searchResultsController]) {
    //    [self.searchDisplayController.searchResultsTableView reloadData];
        [self.searchDisplayController.searchResultsTableView endUpdates];
    } else if ([controller isEqual:fetchedResultsController]) {
    //    [self.myTableView reloadData];
        [self.myTableView endUpdates];
    } else {
        [self setCardCountTitle];
        return;
    }
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
    
    // self.fetchedResultsController = nil;
    // self.searchResultsController = nil;
    
    [[NSNotificationCenter defaultCenter]
     removeObserver:self
     name:NSPersistentStoreCoordinatorStoresDidChangeNotification
     object:[[FlashCardsCore mainMOC] persistentStoreCoordinator]];
    
    [super viewDidUnload];
    
}


- (void)dealloc {
    // as per http://stackoverflow.com/questions/2758575/how-can-uisearchdisplaycontroller-autorelease-cause-crash-in-a-different-view-con
    self.searchDisplayController.delegate = nil;
    self.searchDisplayController.searchResultsDelegate = nil;
    self.searchDisplayController.searchResultsDataSource = nil;
    
}


@end

