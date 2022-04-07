//
//  CardEditCardSetsViewController.m
//  FlashCards
//
//  Created by Jason Lustig on 10/7/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import "FlashCardsAppDelegate.h"
#import "CardEditCardSetsViewController.h"

#import "FCCard.h"
#import "FCCardSet.h"

#import "MBProgressHUD.h"

@implementation CardEditCardSetsViewController

@synthesize card, allCardSets, currentCardSets;
@synthesize HUD;

#pragma mark -
#pragma mark View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    self.title = NSLocalizedStringFromTable(@"Card Sets", @"CardManagement", @"View Title");


    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:[NSEntityDescription entityForName:@"CardSet"
                                        inManagedObjectContext:[FlashCardsCore mainMOC]]];
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"isDeletedObject = NO and collection = %@ and isMasterCardSet = NO", card.collection]];
    [fetchRequest setSortDescriptors:[NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]]];
    allCardSets = [[NSMutableArray alloc] initWithArray:[[FlashCardsCore mainMOC] executeFetchRequest:fetchRequest error:nil]];
    
    currentCardSets = [[NSMutableSet alloc] initWithSet:card.cardSet];
    
    UIBarButtonItem *button;
    button = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector(saveEvent)];
    button.enabled = YES;
    self.navigationItem.rightBarButtonItem = button;
    
    button = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelEvent)];
    button.enabled = YES;
    self.navigationItem.leftBarButtonItem = button;
}

/*
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}
*/
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [[[FlashCardsCore appDelegate] syncController] setDelegate:self];
}

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

- (void)syncDidFinish:(SyncController *)sync {
    if (HUD) {
        [HUD hide:YES];
    }
    [self isDoneSaving];
}
- (void)syncDidFinish:(SyncController *)sync withError:(NSError *)error {
    if (HUD) {
        [HUD hide:YES];
    }
    [self isDoneSaving];
}

- (void)updateHUDLabel:(NSString*)labelText {
    HUD.labelText = labelText;
}

# pragma mark -
# pragma mark Event functions

- (void)saveEvent {
    BOOL shouldSync = NO;
    
    // remove card from all its card sets
    NSSet *cardSetsEnum = [NSSet setWithSet:[card allCardSets]];
    for (FCCardSet *set in cardSetsEnum) {
        if (![currentCardSets containsObject:set]) {
            [set removeCard:card];
            if ([[set shouldSync] boolValue]) {
                shouldSync = YES;
            }
        }
    }
    
    // add the card back to all of the new card sets, selected on this screen
    for (FCCardSet *set in currentCardSets) {
        [set addCard:card];
        if ([[set shouldSync] boolValue]) {
            shouldSync = YES;
        }
    }
    
    [FlashCardsCore saveMainMOC];

    if (shouldSync) {
        [[[FlashCardsCore appDelegate] syncController] setDelegate:self];
        [FlashCardsCore sync];
    } else {
        [self isDoneSaving];
    }
}

- (void)isDoneSaving {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)cancelEvent {
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    return [allCardSets count];
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    
    FCCardSet *set = [allCardSets objectAtIndex:indexPath.row];
    cell.textLabel.text = set.name;
    if ([currentCardSets member:set]) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    }
    
    // Configure the cell...
    
    return cell;
}

#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    FCCardSet *set = [allCardSets objectAtIndex:indexPath.row];
    if ([currentCardSets member:set]) {
        cell.accessoryType = UITableViewCellAccessoryNone;
        [currentCardSets removeObject:set];
    } else {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
        [currentCardSets addObject:set];
    }

    [tableView deselectRowAtIndexPath:indexPath animated:YES];

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

