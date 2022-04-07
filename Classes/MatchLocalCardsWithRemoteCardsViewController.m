//
//  MatchLocalCardsWithRemoteCardsViewController.m
//  FlashCards
//
//  Created by Jason Lustig on 11/2/12.
//  Copyright (c) 2012 Jason Lustig. All rights reserved.
//

#import "MatchLocalCardsWithRemoteCardsViewController.h"
#import "CardSetImportViewController.h"

#import "FCCardSet.h"
#import "FCCard.h"
#import "FCFlashcardExchangeCardId.h"

#import "ImportSet.h"
#import "ImportTerm.h"

#import "FlashCardsAppDelegate.h"
#import "Constants.h"

@interface MatchLocalCardsWithRemoteCardsViewController ()

@end

@implementation MatchLocalCardsWithRemoteCardsViewController

@synthesize remoteSet, localSet;
@synthesize localCardsWithoutWebIds;
@synthesize remoteTermsThatHaveNotYetBeenMatched;
@synthesize bestPotentialMatches;
@synthesize otherPotentialMatches;
@synthesize selectedImportTerm;
@synthesize myTableView;
@synthesize proceedToNextCardButton;
@synthesize importMethod;
@synthesize popToViewControllerIndex;

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
    
    self.title = NSLocalizedStringFromTable(@"Find Online Card Matches", @"Import", @"");
    
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelEvent)];
    self.navigationItem.leftBarButtonItem = cancelButton;

    proceedToNextCardButton.title = NSLocalizedStringFromTable(@"Save and Proceed to Next Card", @"Import", @"");

    bestPotentialMatches = [[NSMutableArray alloc] initWithCapacity:0];
    self.currentCardIndex = 0;
    
    int count = [[self.navigationController viewControllers] count];
    CardSetImportViewController *vc = (CardSetImportViewController*)[[self.navigationController viewControllers] objectAtIndex:(count-2)];
    NSString *service = @"";
    if ([vc.importMethod isEqualToString:@"quizlet"]) {
        service = @"Quizlet";
    }
    
    FCDisplayBasicErrorMessage(@"",
                               [NSString stringWithFormat:NSLocalizedStringFromTable(@"Some of the cards in the set \"%@\" aren't matched up with cards saved on %@. Please match your local cards with the cards on the internet, so that they can be kept in sync.", @"Import", @""),
                                localSet.name,
                                service
                                ]);
    if ([self.localCardsWithoutWebIds count] == 0) {
        [self returnToImportView:YES];
    }
    [self configureCard:self.currentCardIndex];
    [self.myTableView reloadData];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


# pragma mark -
# pragma mark Events

- (void)findExactMatches {
    remoteTermsThatHaveNotYetBeenMatched = [[NSMutableArray alloc] initWithCapacity:0];
    otherPotentialMatches = [[NSMutableArray alloc] initWithCapacity:0];
    localCardsWithoutWebIds = [[NSMutableArray alloc] initWithArray:[[localSet cardsWithoutIdsForWebsite:importMethod] allObjects]];

    // make list of all remote terms that haven't yet been matched:
    FCFlashcardExchangeCardId *cardId;
    BOOL isFound = NO;
    for (ImportTerm *remoteTerm in remoteSet.flashCards) {
        isFound = NO;
        for (FCCard *card in localSet.cards) {
            cardId = [card flashcardExchangeCardIdForCardSet:localSet];
            if ([cardId.flashcardExchangeCardId intValue] == remoteTerm.cardId) {
                isFound = YES;
                break;
            }
        }
        if (!isFound) {
            [remoteTermsThatHaveNotYetBeenMatched addObject:remoteTerm];
        }
    }
    
    BOOL shouldSave = NO;
    // match up all of the exact cards:
    ImportTerm *remoteTerm;
    for (int i = (int)[remoteTermsThatHaveNotYetBeenMatched count]-1; i >= 0; i--) {
        remoteTerm = [remoteTermsThatHaveNotYetBeenMatched objectAtIndex:i];
        for (FCCard *card in localCardsWithoutWebIds) {
            if ([[remoteTerm.importTermFrontValue lowercaseString] isEqualToString:[card.frontValue lowercaseString]]) {
                if ([[remoteTerm.importTermBackValue lowercaseString] isEqualToString:[card.backValue lowercaseString]]) {
                    // we found an EXACT MATCH!!
                    // save the information:
                    // NSLog(@"Exact Match Front: %@", remoteTerm.importTermFrontValue);
                    // NSLog(@"Exact Match Back: %@", remoteTerm.importTermBackValue);
                    // NSLog(@"----------");
                    
                    [card setWebsiteCardId:remoteTerm.cardId forCardSet:localSet withWebsite:importMethod];
                    
                    [remoteTermsThatHaveNotYetBeenMatched removeObjectAtIndex:i];
                    [localCardsWithoutWebIds removeObject:card];
                    // NSLog(@"%d remoteTermsThatHaveNotYetBeenMatched", [remoteTermsThatHaveNotYetBeenMatched count]);
                    shouldSave = YES;
                    break;
                }
            }
        }
    }
    if (shouldSave) {
        [FlashCardsCore saveMainMOC];
    }
    /*
    NSLog(@"remoteTermsThatHaveNotYetBeenMatched:");
    for (ImportTerm *term in remoteTermsThatHaveNotYetBeenMatched) {
        NSLog(@"%@", term.importTermFrontValue);
    }
    */

}

- (void)cancelEvent {
    int count = [[self.navigationController viewControllers] count];
    // CardSetImportViewController *vc = (CardSetImportViewController*)self.navigationController.parentViewController;
    CardSetImportViewController *vc = (CardSetImportViewController*)[[self.navigationController viewControllers] objectAtIndex:(count-2)];
    [vc clearCardSetActionData];
    [self.navigationController popToViewController:[[self.navigationController viewControllers] objectAtIndex:popToViewControllerIndex] animated:YES];
}

- (void)saveEvent {
    [FlashCardsCore saveMainMOC];
    [self returnToImportView:YES];
}

- (void)returnToImportView:(BOOL)animated {
    // TODO: Go back to the main import view
    /*
     // Flip back to the front view:
     [UIView beginAnimations:nil context:nil];
     [UIView setAnimationDuration:1.0];
     [UIView setAnimationTransition:UIViewAnimationTransitionFlipFromLeft
     forView:[self view] cache:YES];
     
     [mergeView removeFromSuperview];
     [UIView commitAnimations];
     */
    
    // self.title = importFromWebsite;
    
    // [self saveCards:termsList];
    
    NSArray *viewControllers = self.navigationController.viewControllers;
    CardSetImportViewController *vc = [viewControllers objectAtIndex:([viewControllers count]-2)];
    vc.shouldImmediatelyImportTerms = NO;
    vc.shouldImmediatelyPressImportButton = YES; // there may be more sets to link together
    
    [self.navigationController popViewControllerAnimated:animated];
}

- (IBAction)proceedToNextCard:(id)sender {
    FCCard *currentCard = [localCardsWithoutWebIds objectAtIndex:self.currentCardIndex];
    if (selectedImportTerm) {
        [currentCard setWebsiteCardId:selectedImportTerm.cardId forCardSet:localSet withWebsite:importMethod];
        
        [remoteTermsThatHaveNotYetBeenMatched removeObject:selectedImportTerm];
        selectedImportTerm = nil;
    }
    
    self.currentCardIndex++;
    
    if (self.currentCardIndex >= [localCardsWithoutWebIds count]) {
        [self saveEvent];
        return;
    }
    
    // it's the last card: change the button on the bottom
    if (self.currentCardIndex == ([localCardsWithoutWebIds count]-1)) {
        proceedToNextCardButton.title = NSLocalizedStringFromTable(@"Save and Import Cards", @"Import", @"");
        proceedToNextCardButton.style = UIBarButtonItemStyleDone;
    }
    
    [self configureCard:self.currentCardIndex];
}

- (void)configureCard:(int)index {
    /*
    NSLog(@"remoteTermsThatHaveNotYetBeenMatched:");
    for (ImportTerm *term in remoteTermsThatHaveNotYetBeenMatched) {
        NSLog(@"%@", term.importTermFrontValue);
    }
    */
    
    [bestPotentialMatches removeAllObjects];
    [otherPotentialMatches removeAllObjects];
    [otherPotentialMatches addObjectsFromArray:remoteTermsThatHaveNotYetBeenMatched];
    
    // match up all of the exact cards:
    
    FCCard *card = [localCardsWithoutWebIds objectAtIndex:index];
    for (ImportTerm *remoteTerm in remoteTermsThatHaveNotYetBeenMatched) {
        if ([[remoteTerm.importTermFrontValue lowercaseString] isEqualToString:[card.frontValue lowercaseString]] ||
            [[remoteTerm.importTermBackValue lowercaseString] isEqualToString:[card.backValue lowercaseString]]) {
            // we have found a POTENTIAL MATCH!
            [bestPotentialMatches addObject:remoteTerm];
            [otherPotentialMatches removeObject:remoteTerm];
        }
    }
    
    [self.myTableView reloadData];
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    int numberOfSections = 3;
    if ([self.bestPotentialMatches count] > 0) {
        numberOfSections++;
    }
    if ([otherPotentialMatches count] == 0) {
        numberOfSections--;
    }
    return numberOfSections;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // the number of sections in front of the sections that show the actual cards
    if (section == 0) {
        // local card
        return 1; // just the local card
    } else if (section == 1) {
        return 1; // Doesn't exist on the web
    } else {
        if ([bestPotentialMatches count] == 0) {
            section++;
        }
        if (section == 2) {
            return 1; // best match
        } else {
            return [otherPotentialMatches count];
        }
    }
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    int section = indexPath.section;
    int style;
    NSString *CellIdentifier;
    if (section == 0) {
        // local card
        style = UITableViewCellStyleSubtitle;
        CellIdentifier = @"subtitle";
    } else if (section == 1) {
        style = UITableViewCellStyleValue1;
        CellIdentifier = @"value1";
    } else {
        style = UITableViewCellStyleSubtitle;
        CellIdentifier = @"subtitle";
    }

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:style reuseIdentifier:CellIdentifier];
    }
    
    // Configure the cell...
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (void)configureCell:(UITableViewCell*)cell atIndexPath:(NSIndexPath*)indexPath {
    int section = indexPath.section;
    int row = indexPath.row;
    if (section == 0) {
        // local card
        FCCard *localCard = [localCardsWithoutWebIds objectAtIndex:self.currentCardIndex];
        cell.textLabel.text = localCard.frontValue;
        cell.detailTextLabel.text = localCard.backValue;
        if ([localCard.hasImages boolValue]) {
            [cell.imageView setImage:[UIImage imageNamed:@"icon-camera.png"]];
        } else {
            [cell.imageView setImage:nil];
        }
        [cell setAccessoryType:UITableViewCellAccessoryNone];
        [cell setUserInteractionEnabled:NO];
    } else if (section == 1) {
        cell.textLabel.text = NSLocalizedStringFromTable(@"Card Doesn't Exist On Web", @"Import", @"");
        [cell.imageView setImage:nil];
        if (!selectedImportTerm) {
            [cell setAccessoryType:UITableViewCellAccessoryCheckmark];
        } else {
            [cell setAccessoryType:UITableViewCellAccessoryNone];
        }
        [cell setUserInteractionEnabled:YES];
    } else {
        if ([bestPotentialMatches count] == 0) {
            section++;
        }
        ImportTerm *remoteTerm;
        if (section == 2) {
            // best match
            remoteTerm = [bestPotentialMatches objectAtIndex:row];
        } else {
            remoteTerm = [otherPotentialMatches objectAtIndex:row];
        }
        cell.textLabel.text = remoteTerm.importTermFrontValue;
        cell.detailTextLabel.text = remoteTerm.importTermBackValue;
        if (remoteTerm.frontImageUrl || remoteTerm.backImageUrl) {
            [cell.imageView setImage:[UIImage imageNamed:@"icon-camera.png"]];
        } else {
            [cell.imageView setImage:nil];
        }
        if ([selectedImportTerm isEqual:remoteTerm]) {
            [cell setAccessoryType:UITableViewCellAccessoryCheckmark];
        } else {
            [cell setAccessoryType:UITableViewCellAccessoryNone];
        }
        [cell setUserInteractionEnabled:YES];
    }

}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    // we have a header for section 0 ("Options") and the even sections (before each card set)
    if (section == 0 || section == 1) {
        return 40;
    } else if (section == 2 || section == 3) {
        if (section == 2 && [bestPotentialMatches count] == 0) {
            return 0;
        }
        return 30;
    }
    return 0;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    
    if (section > 3) {
        return nil;
    }
    
    UIView* customView = [[UIView alloc] initWithFrame:CGRectMake(10.0, 0.0, 300.0, 44.0)];
    
    // create the button object
    UILabel * headerLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    headerLabel.backgroundColor = [UIColor clearColor];
    headerLabel.opaque = NO;
    headerLabel.textColor = [UIColor blackColor];
    headerLabel.highlightedTextColor = [UIColor whiteColor];
    if (section == 0 || section == 1) {
        headerLabel.font = [UIFont boldSystemFontOfSize:19];
    } else if (section == 2 || section == 3) {
        headerLabel.font = [UIFont systemFontOfSize:14];
    }
    if ([FlashCardsAppDelegate isIpad]) {
        headerLabel.frame = CGRectMake(60.0, 0.0, 300.0, 44.0);
    } else {
        headerLabel.frame = CGRectMake(10.0, 0.0, 300.0, 44.0);
    }
    
    if (section == 0) {
        // local card
        headerLabel.text = [NSString stringWithFormat:NSLocalizedStringFromTable(@"Local Card: %d of %d", @"Import", @""), (self.currentCardIndex+1), [localCardsWithoutWebIds count]];
    } else if (section == 1) {
        headerLabel.text = NSLocalizedStringFromTable(@"Match with Card on the Web", @"Import", @"");
    } else {
        if ([bestPotentialMatches count] > 0) {
            if (section == 2) {
                headerLabel.text = NSLocalizedStringFromTable(@"Best Matches:", @"Import", @"");
            } else {
                headerLabel.text = NSLocalizedStringFromTable(@"Other Potential Matches:", @"Import", @"");
            }
        } else {
            // don't display ANYTHING
            return nil;
        }
    }
    [customView addSubview:headerLabel];
    
    return customView;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    int section = indexPath.section;
    int row = indexPath.row;
    if (section == 0) {
        return;
        // don't do anything if we are tapping the local card.
    }
    
    if (section == 1) {
        // doesn't exist on the website
        selectedImportTerm = nil;
    } else {
        if ([bestPotentialMatches count] == 0) {
            section++;
        }
        ImportTerm *remoteTerm;
        if (section == 2) {
            // best match
            remoteTerm = [bestPotentialMatches objectAtIndex:row];
        } else {
            remoteTerm = [otherPotentialMatches objectAtIndex:row];
        }
        selectedImportTerm = remoteTerm;
    }
    
    [myTableView reloadData];

    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    [self configureCell:cell atIndexPath:indexPath];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}


@end
