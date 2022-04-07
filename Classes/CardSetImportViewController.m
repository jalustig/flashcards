//
//  CardSetImportViewController.m
//  FlashCards
//
//  Created by Jason Lustig on 6/2/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import "FlashCardsAppDelegate.h"
#import "FlashCardsCore.h"

#import "RootViewController.h"
#import "CardSetImportViewController.h"
#import "CardEditViewController.h"
#import "StudyViewController.h"
#import "StudySettingsViewController.h"
#import "DuplicateCardViewController.h"
#import "SelectCollectionViewController.h"
#import "MatchLocalCardsWithRemoteCardsViewController.h"

#import "FCSetsTableViewController.h"
#import "FCCollection.h"
#import "FCCardSet.h"
#import "FCCard.h"

#import "ImportTerm.h"

#import "ImportSDK.h"
#import "QuizletRestClient.h"
#import "QuizletSync.h"

#import "MBProgressHUD.h"

#import "UIAlertView+Blocks.h"

#import "TICDSDocumentSyncManager.h"

@implementation CardSetImportViewController

@synthesize cardSet, cardSetId;
@synthesize collection, collectionId;
@synthesize matchCardSetImportSet;
@synthesize matchCardSetId;
// Quizlet Set View

@synthesize csvFilePath, importMethod, importFunction;
@synthesize quizletSetTableView;
@synthesize reverseCardsOptionTableViewCell, reverseCardsOptionLabel, reverseCardsOptionSwitch;
@synthesize checkDuplicatesOptionTableViewCell, checkDuplicatesOptionLabel, checkDuplicatesOptionSwitch;
@synthesize importAsSeparateSetsOptionTableViewCell, importAsSeparateSetsOptionLabel, importAsSeparateSetsOptionSwitch;
@synthesize mergeExactDuplicatesOptionTableViewCell, mergeExactDuplicatesOptionLabel, mergeExactDuplicatesOptionSwitch;
@synthesize resetStatisticsOfExactDuplicatesOptionTableViewCell, resetStatisticsOfExactDuplicatesOptionLabel, resetStatisticsOfExactDuplicatesOptionSwitch;
@synthesize keepSetInSyncOptionTableViewCell, keepSetInSyncOptionLabel, keepSetInSyncOptionSwitch;
@synthesize syncOrderTableViewCell, syncOrderLabel, syncOrderSwitch;
@synthesize subscribeOptionTableViewCell, subscribeOptionLabel, subscribeOptionSwitch;
@synthesize initialNumCards;
@synthesize totalCardsSaved;
@synthesize hasCheckedIfCardSetWithIdExistsOnDevice;
@synthesize matchCardSetDecisionGoesDirectlyToImport;

@synthesize allCardSets, currentlyImportingSet;

// Other variables

@synthesize popToViewControllerIndexSave, popToViewControllerIndexCancel;
@synthesize cardSetCreateMode;
@synthesize duplicateCards;
@synthesize autoMergeIdenticalCards;
@synthesize isConnectedToInternet;
@synthesize reverseFrontAndBackOfCards;
@synthesize shouldImmediatelyImportTerms, shouldImmediatelyPressImportButton;
@synthesize HUD;

/*
 // The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        // Custom initialization
    }
    return self;
}
*/

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    // make sure all the card set objects know how we want to import the sets:
    for (ImportSet *cardSetData in allCardSets) {
        cardSetData.cardSetCreateMode = cardSetCreateMode;
    }
    
    reverseCardsOptionLabel.text = NSLocalizedStringFromTable(@"Reverse Front & Back", @"Import", @"UILabel");
    [reverseCardsOptionSwitch setOn:NO];
    
    checkDuplicatesOptionLabel.text = NSLocalizedStringFromTable(@"Check for Duplicates", @"Import", @"UILabel");
    [checkDuplicatesOptionSwitch setOn:YES];
    
    importAsSeparateSetsOptionLabel.text = NSLocalizedStringFromTable(@"Import as Separate Sets", @"Import", @"UILabel");
    [importAsSeparateSetsOptionSwitch setOn:YES];
    
    mergeExactDuplicatesOptionLabel.text = NSLocalizedStringFromTable(@"Merge Exact Matches", @"Settings", @"UILabel");
    autoMergeIdenticalCards = [(NSNumber*)[FlashCardsCore getSetting:@"importSettingsAutoMergeIdenticalCards"] boolValue];
    [mergeExactDuplicatesOptionSwitch setOn:autoMergeIdenticalCards];
    
    resetStatisticsOfExactDuplicatesOptionLabel.text = NSLocalizedStringFromTable(@"Reset Exact Match Statistics", @"Settings", @"UILabel");
    [resetStatisticsOfExactDuplicatesOptionSwitch setOn:NO];
    
    syncOrderLabel.text = NSLocalizedStringFromTable(@"Sync Card Order", @"Import", @"UILabel");
    [syncOrderSwitch setOn:NO];
    
    keepSetInSyncOptionLabel.text = NSLocalizedStringFromTable(@"Sync with Quizlet", @"CardManagement", @"");
    if ([FlashCardsCore hasFeature:@"WebsiteSync"]) {
        [keepSetInSyncOptionSwitch setOn:YES];
    } else {
        [keepSetInSyncOptionSwitch setOn:NO];
    }
    
    subscribeOptionLabel.text = NSLocalizedStringFromTable(@"Subscribe to Online Changes", @"Import", @"");
    if ([FlashCardsCore hasFeature:@"WebsiteSync"]) {
        [subscribeOptionSwitch setOn:YES];
    } else {
        [subscribeOptionSwitch setOn:NO];
    }
    
    if ([importMethod isEqualToString:@"quizlet"]) {
        if ([self setsArePasswordProtected]) {
            [keepSetInSyncOptionSwitch setOn:NO];
            [subscribeOptionSwitch setOn:NO];
        }
    }

    reverseFrontAndBackOfCards = NO;
    isConnectedToInternet = YES;
    
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelEvent)];
    self.navigationItem.leftBarButtonItem = cancelButton;
    
    self.title = NSLocalizedStringFromTable(@"Import Cards", @"CardManagement", @"UIView title");
    
    [self showImportButton];
    [self.quizletSetTableView reloadData];

    // ifdef LITE
    if (![FlashCardsCore hasFeature:@"UnlimitedCards"]) {
        [FlashCardsCore checkUnlimitedCards];
    }
    
    initialNumCards = [FlashCardsCore numTotalCards];
    totalCardsSaved = 0;
    
    matchCardSetDecisionGoesDirectlyToImport = NO;
    
    if (!hasCheckedIfCardSetWithIdExistsOnDevice) {
        if ([self canShowSyncOptions] && [allCardSets count] == 1) {
            // if there is only one card set we can very easily check to see how it should be handeled
            // in the case that it's already downloaded to the device.
            BOOL hasFoundMatch = NO;
            NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
            [fetchRequest setEntity:[NSEntityDescription entityForName:@"CardSet" inManagedObjectContext:[FlashCardsCore mainMOC]]];
            NSArray *results;
            ImportSet *remoteSet = [allCardSets objectAtIndex:0];
            FCCardSet *localSet;
            [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"isDeletedObject = NO and quizletSetId = %d", remoteSet.cardSetId]];
            results = [[FlashCardsCore mainMOC] executeFetchRequest:fetchRequest error:nil];
            if ([results count] > 0) {
                hasFoundMatch = YES;
                localSet = [results objectAtIndex:0];
                remoteSet.matchCardSetChecked = YES;
                [remoteSet setMatchCardSet:[results objectAtIndex:0]];
                self.matchCardSetId = [localSet objectID];
                matchCardSetImportSet = remoteSet;
            }
            
            if (hasFoundMatch) {
                // ask the user what to do:
                // At this point, if they decide that they want to import to the existing sets, it should go **automatically**
                
                NSString *previouslyImported = [NSString stringWithFormat:NSLocalizedStringFromTable(@"You have previously imported the card set \"%@\".", @"Import", @"message"), remoteSet.name];
                NSString *whatToDo;
                NSString *syncOrSubscribe;
                
                BOOL showAlert = YES;
                // first, is the set already synced or subscribed??
                if ([localSet.isSubscribed boolValue]) {
                    // it's subscribed - we can't actually import cards to this set. Ask them what to do.
                    whatToDo = NSLocalizedStringFromTable(@"This set is Subscribed to online changes. For this reason, you cannot import cards to this card set. You can choose to create a new set and import the cards a second time, or not import this set. What would you like to do?", @"Import", "");
                } else if ([localSet.shouldSync boolValue]) {
                    // it's synced. they can choose to create a new set, or do nothing - b/c that will essentially just keep it synced
                    whatToDo = NSLocalizedStringFromTable(@"This set Syncs with online changes. You can choose to create a new set and import the cards a second time, or not import this set. What would you like to do?", @"Import", "");
                } else {
                    // they aren't synced or subscribed. we will actually wait until they choose what to do.
                    showAlert = NO;
                    
                    // undo all of the work from before - clear out the match settings:
                    remoteSet.matchCardSetChecked = NO;
                    [remoteSet setMatchCardSetId:nil];
                    self.matchCardSetId = nil;
                    matchCardSetImportSet = nil;

                }
                if (showAlert) {
                    syncOrSubscribe = NSLocalizedStringFromTable(@"Don't Import This Set", @"Import", @"");
                    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Set Previously Imported", @"Import", @"UIAlert title")
                                                                     message:[NSString stringWithFormat:@"%@ %@", previouslyImported, whatToDo]
                                                                    delegate:self
                                                           cancelButtonTitle:NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"cancelButtonTitle")
                                                           otherButtonTitles:
                                           NSLocalizedStringFromTable(@"Create New Set", @"Import", @"cancelButtonTitle"),
                                           syncOrSubscribe,
                                           nil];
                    [alert show];
                }
            }
        }
    }
    // #ifdef LITE
    if (![FlashCardsCore hasFeature:@"UnlimitedCards"]) {
        int _totalCardsSaved = 0;
        for (ImportSet *data in allCardSets) {
            _totalCardsSaved += [data.flashCards count];
        }
        if ((initialNumCards + _totalCardsSaved) > maxCardsLite) {
            _totalCardsSaved = maxCardsLite - initialNumCards;
            // we need to show them the popup to decide what to do:
            RIButtonItem *cancelItem = [RIButtonItem item];
            cancelItem.label = NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"cancelButtonTitle");
            cancelItem.action = ^{
                [self cancelEvent];
            };
            
            RIButtonItem *continueItem = [RIButtonItem item];
            continueItem.label =
            [NSString stringWithFormat:FCPluralLocalizedStringFromTable(@"Import First %d Cards", @"Plural", @"", [NSNumber numberWithInt:_totalCardsSaved]), _totalCardsSaved];
            continueItem.action = ^{
                [self checkPhotos];
            };

            RIButtonItem *subscribeItem = [RIButtonItem item];
            subscribeItem.label = NSLocalizedStringFromTable(@"Learn More About Subscriptions", @"Subscription", @"");
            subscribeItem.action = ^{
                [FlashCardsCore showPurchasePopup:@"UnlimitedCards"];
            };

            NSString *message =
            [NSString stringWithFormat:FCPluralLocalizedStringFromTable(@"The free version of FlashCards++ has a limit of 100 cards. You can become a Subscriber for unlimited cards, or you can import the first %d cards in this set.", @"Plural", @"", [NSNumber numberWithInt:_totalCardsSaved]), _totalCardsSaved];
            
            UIAlertView *alert;
            alert = [[UIAlertView alloc] initWithTitle:@""
                                               message:message
                                      cancelButtonItem:cancelItem
                                      otherButtonItems:continueItem, subscribeItem, nil];
            [alert show];
            return;
        } else {
            [self checkPhotos];
        }
    }
}

- (void)checkPhotos {
    BOOL oneSetHasImages = NO;
    for (ImportSet *cardSetData in allCardSets) {
        if (cardSetData.hasImages) {
            oneSetHasImages = YES;
        }
    }
    if (![FlashCardsCore hasFeature:@"Photos"] && oneSetHasImages) {
        RIButtonItem *cancelItem = [RIButtonItem item];
        cancelItem.label = NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"cancelButtonTitle");
        cancelItem.action = ^{
            [self cancelEvent];
        };
        
        RIButtonItem *continueItem = [RIButtonItem item];
        continueItem.label = NSLocalizedStringFromTable(@"Import Without Images", @"Import", @"");
        continueItem.action = ^{
        };
        
        RIButtonItem *subscribeItem = [RIButtonItem item];
        subscribeItem.label = NSLocalizedStringFromTable(@"Learn More About Subscriptions", @"Subscription", @"");
        subscribeItem.action = ^{
            [FlashCardsCore showPurchasePopup:@"UnlimitedCards"];
        };
        
        NSString *message = NSLocalizedStringFromTable(@"The sets you are importing contain images. Attaching photos to flash cards is only available to FlashCards++ subscribers. You can become a Subscriber to download these images, or you can continue and just import the text.", @"Subscription", @"");
        
        UIAlertView *alert;
        alert = [[UIAlertView alloc] initWithTitle:@""
                                           message:message
                                  cancelButtonItem:cancelItem
                                  otherButtonItems:continueItem, subscribeItem, nil];
        [alert show];
        return;
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if (shouldImmediatelyImportTerms) {
        // will save the set which we dealt with in the duplicates screen.
        [self performSelectorInBackground:@selector(saveCards:) withObject:currentlyImportingSet];
    } else if (shouldImmediatelyPressImportButton) {
        [self performSelectorInBackground:@selector(importCardSet) withObject:nil]; // like pressing the button!
    }
    
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    HUD.delegate = nil;
    [[[FlashCardsCore appDelegate] syncController] setDelegate:nil];
}


- (BOOL)shouldAutorotate {
    UIInterfaceOrientation interfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    return [FlashCardsAppDelegate shouldAutorotate:interfaceOrientation];
}

- (BOOL)isLoggedIn {
    if ([importMethod isEqualToString:@"quizlet"] && [QuizletRestClient isLoggedIn]) {
        return YES;
    }
    return NO;
}

- (NSString*)username {
    if ([importMethod isEqualToString:@"quizlet"]) {
        return [QuizletSync username];
    }
    return nil;
}

#pragma mark -
#pragma mark Setter/Getter functions

- (void)setCollection:(FCCollection *)_collection {
    collection = _collection;
    if (_collection) {
        collectionId = [_collection objectID];
    } else {
        collectionId = nil;
    }
}
- (void)setCardSet:(FCCardSet *)_cardSet {
    cardSet = _cardSet;
    if (_cardSet) {
        cardSetId = [_cardSet objectID];
    } else {
        cardSetId = nil;
    }
}

- (FCCollection*)collectionInMOC:(NSManagedObjectContext*)moc {
    if (self.collectionId) {
        return (FCCollection*)[moc objectWithID:self.collectionId];
    }
    return nil;
}
- (FCCardSet*)cardSetInMOC:(NSManagedObjectContext*)moc {
    if (self.cardSetId) {
        return (FCCardSet*)[moc objectWithID:self.cardSetId];
    }
    return nil;
}

#pragma mark -
#pragma mark Sync methods

- (void)syncDidFinish:(SyncController *)sync {
    [self cleanup];
}
- (void)syncDidFinish:(SyncController *)sync withError:(NSError *)error {
    [self cleanup];
}

- (void)updateHUDLabel:(NSString*)labelText {
    HUD.labelText = labelText;
}



#pragma mark -
#pragma mark MBProgressHUDDelegate methods

- (void)hudWasHidden:(MBProgressHUD *)hud {
    // Remove HUD from screen when the HUD was hidded
    [hud removeFromSuperview];
    hud = nil;

    if (self.navigationItem.rightBarButtonItem) {
        self.navigationItem.leftBarButtonItem.enabled = YES;
        self.navigationItem.rightBarButtonItem.enabled = YES;
    }
}

# pragma mark -
# pragma mark Alert functions
/**** MAIN THREAD ****/
- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (!isConnectedToInternet) {
        [self clearCardSetActionData];
        [self.navigationController popToViewController:[[self.navigationController viewControllers] objectAtIndex:popToViewControllerIndexCancel] animated:YES];
        return;
    }
    NSString *buttonTitle = [alertView buttonTitleAtIndex:buttonIndex];
    if (self.matchCardSetId) {
        
        if ([buttonTitle isEqualToString:NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"cancelButtonTitle")]) {
            self.matchCardSetId = nil;
            [self cancelEvent];
            return;
        } else if ([buttonTitle isEqualToString:NSLocalizedStringFromTable(@"Create New Set", @"Import", @"cancelButtonTitle")]) {
            // don't do much of anything. everything is taken care of below (sending the user back to the importCardSet method)
        } else if ([buttonTitle isEqualToString:NSLocalizedStringFromTable(@"Don't Import This Set", @"Import", @"")]) {
            // remove the set from the list of sets to import.
            [allCardSets removeObjectIdenticalTo:matchCardSetImportSet];
            if ([allCardSets count] == 0) {
                // go back!
                self.matchCardSetId = nil;
                [self cancelEvent];
            }
        } else {
            // we are matching the sets, but we will do different things
            if ([buttonTitle isEqualToString:NSLocalizedStringFromTable(@"Sync With Existing Set", @"Import", @"")]) {
                matchCardSetImportSet.willSync = YES;
                [keepSetInSyncOptionSwitch setOn:YES];
            } else if ([buttonTitle isEqualToString:NSLocalizedStringFromTable(@"Subscribe to Online Changes", @"Import", @"")]) {
                matchCardSetImportSet.willSubscribe = YES;
                [subscribeOptionSwitch setOn:YES];
            }

            // cardSetCreateMode = modeEdit;
            // cardSet = matchCardSet;
            
            [matchCardSetImportSet setMatchCardSetId:self.matchCardSetId];
        }

        self.matchCardSetId = nil;
        if (matchCardSetDecisionGoesDirectlyToImport) {
            [self performSelectorInBackground:@selector(importCardSet) withObject:nil]; // go back and check any additional duplicate sets
        }
        return;
    }
    HUD.delegate = nil;
    
    if ([buttonTitle isEqualToString:NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"cancelButtonTitle")]) {
        /*
         
         View controller stack:
         
         0) Collections
         1) CollectionsView
         2) CardSetList
         3) CardSetView
         4) CardSetImportChoice
         5) CardSetImport
         
         */
        [self clearCardSetActionData];
        [self.navigationController popToViewController:[[self.navigationController viewControllers] objectAtIndex:popToViewControllerIndexSave] animated:YES];
    }
}

# pragma mark -
# pragma mark Download functions:

- (void)checkInternetStatus {
    if (![FlashCardsCore isConnectedToInternet]) {
        isConnectedToInternet = NO;
        FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"No Internet Connection", @"Error", @"UIAlert title"),
                                   [NSString stringWithFormat:@"%@ %@",
                                    NSLocalizedStringFromTable(@"You are not connected to the internet.", @"Error", @""),
                                    NSLocalizedStringFromTable(@"This feature will only work with an active internet connection.", @"Error", @"message")]);
        [self.navigationController popToViewController:[[self.navigationController viewControllers] objectAtIndex:popToViewControllerIndexCancel] animated:YES];
        return;
    }
}

# pragma mark -
# pragma mark Quizlet functions

- (void)showImportButton {
    UIBarButtonItem *importButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedStringFromTable(@"Import Now", @"Import", @"UIBarButtonItem") style:UIBarButtonItemStyleDone target:self action:@selector(importCardSet)];
    self.navigationItem.rightBarButtonItem = importButton;
    if (HUD) {
        self.navigationItem.leftBarButtonItem.enabled = NO;
        self.navigationItem.rightBarButtonItem.enabled = NO;
    }
}

- (NSMutableArray*)cardSetCharacteristicsList:(ImportSet*)cardSetData {
    NSMutableArray* characteristicsList = [[NSMutableArray alloc] initWithCapacity:0];
    
    if ([(NSString*)[cardSetData valueForKey:@"description"] length] > 0) {
        [characteristicsList addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                        NSLocalizedStringFromTable(@"Description", @"Import", @""), @"textLabel",
                                        [cardSetData valueForKey:@"description"], @"detailTextLabel",
                                        nil
                                        ]];
    }
    if ([cardSetData.tags count] > 0) {
        [characteristicsList addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                               NSLocalizedStringFromTable(@"Topics", @"Import", @""), @"textLabel",
                                               [cardSetData.tags componentsJoinedByString:@"; "], @"detailTextLabel",
                                               nil
                                               ]];
    }
    if ([cardSetData numberCards] > 0) {
        [characteristicsList addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                               NSLocalizedStringFromTable(@"# Cards", @"Import", @""), @"textLabel",
                                               [NSString stringWithFormat:@"%d", [cardSetData numberCards]], @"detailTextLabel",
                                               nil
                                               ]];
    }
    if ([[cardSetData creator] length] > 0) {
        [characteristicsList addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                               NSLocalizedStringFromTable(@"Creator", @"Import", @""), @"textLabel",
                                               [cardSetData valueForKey:@"creator"], @"detailTextLabel",
                                               nil
                                               ]];
    }
    if (cardSetData.creationDate) {
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateStyle:NSDateFormatterShortStyle];
        [dateFormatter setTimeStyle:NSDateFormatterNoStyle];
        
        [characteristicsList addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                               NSLocalizedStringFromTable(@"Created On", @"Import", @""), @"textLabel",
                                               [dateFormatter stringFromDate:cardSetData.creationDate], @"detailTextLabel",
                                               nil
                                               ]];
    }
    return characteristicsList;
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    int row, section;
    row = indexPath.row;
    section = indexPath.section;

    int reduceSection = 1;
    if ([self canShowSyncOptions]) {
        // we **can** show the "subscribe" or "sync" options and need to reduce the section again
        reduceSection++;
    }
    section -= reduceSection;

    int cardSetIndex = (section - (section % 2)) / 2;
    ImportSet *cardSetData = [allCardSets objectAtIndex:cardSetIndex];
    if (section % 2 == 0) {
        NSDictionary *item = [[self cardSetCharacteristicsList:cardSetData] objectAtIndex:row];
        cell.textLabel.text = [item objectForKey:@"textLabel"];
        cell.detailTextLabel.text = [item objectForKey:@"detailTextLabel"];
        [cell.imageView setImage:nil];
    } else {
        ImportTerm *card = [cardSetData.flashCards objectAtIndex:row];
        cell.textLabel.text = (reverseFrontAndBackOfCards ? card.importTermBackValue : card.importTermFrontValue);
        cell.detailTextLabel.text = (reverseFrontAndBackOfCards ? card.importTermFrontValue : card.importTermBackValue);
        if (card.shouldImportTerm) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        } else {
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
        if ([card hasImages]) {
            [cell.imageView setImage:[UIImage imageNamed:@"icon-camera.png"]];
        } else {
            [cell.imageView setImage:nil];
        }
    }
    if (section % 2 == 0) {
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.detailTextLabel.font = [UIFont systemFontOfSize:14];
        [cell.imageView setImage:nil];
    }
}

- (BOOL)setsArePasswordProtected {
    BOOL isPasswordProtected = NO;
    for (ImportSet *set in self.allCardSets) {
        if (set.password && ![[set creator] isEqualToString:[QuizletSync username]]) {
            isPasswordProtected = YES;
        }
    }
    return isPasswordProtected;
}

# pragma mark -
# pragma mark Settings functions

/**** BACKGROUND THREAD ****/
- (void)filterTermsListByOptions {
    // filter out the ones the person didn't choose to import:
    int count;
    ImportTerm *term;
    NSString *temp;
    NSMutableData *tempData;
    for (ImportSet *cardSetData in allCardSets) {
        if (cardSetData.isFiltered) {
            continue;
        }
        count = [cardSetData.flashCards count];
        for (int i = count-1; i >= 0; i--) {
            term = [cardSetData.flashCards objectAtIndex:i];
            if (!term.shouldImportTerm) {
                [cardSetData.flashCards removeObjectAtIndex:i];
                continue;
            }
            // if the user requested it, reverse the back & front of the cards:
            if (reverseFrontAndBackOfCards) {
                // flip the back & front sides:
                temp = [NSString stringWithString:term.importTermFrontValue];
                term.importTermFrontValue = term.importTermBackValue;
                term.importTermBackValue = temp;
                
                // flip back & front images:
                tempData = [NSMutableData dataWithData:term.frontImageData];
                term.frontImageData = term.backImageData;
                term.backImageData = tempData;

                // flip back & front audio:
                tempData = [NSMutableData dataWithData:term.frontAudioData];
                term.frontAudioData = term.backAudioData;
                term.frontAudioData = tempData;
            }
        }
        cardSetData.isFiltered = YES;
    }
}

- (IBAction)reverseCardsOptionSegmentedControlChanged:(id)sender {
    reverseFrontAndBackOfCards = [self.reverseCardsOptionSwitch isOn];
    for (ImportSet *set in allCardSets) {
        set.reverseFrontAndBackOfCards = self.reverseFrontAndBackOfCards;
    }
    [self.quizletSetTableView reloadData];
}

- (IBAction)mergeExactDuplicatesOptionSwitchChanged:(id)sender {
    [self.quizletSetTableView reloadData];
}

- (IBAction)syncOptionSwitchChanged:(id)sender {
    if ([importMethod isEqualToString:@"quizlet"]) {
        if ([self setsArePasswordProtected]) {
            // don't let them do it:
            [sender setOn:NO];
            FCDisplayBasicErrorMessage(@"",
                                       NSLocalizedStringFromTable(@"At this time, password-protected card sets cannot be synced with Quizlet.", @"Import", @""));
        }
    }
    if (![FlashCardsCore hasFeature:@"WebsiteSync"]) {
        [FlashCardsCore showPurchasePopup:@"WebsiteSync"];
        [sender setOn:NO];
    }
    [self.quizletSetTableView reloadData];
}

- (IBAction)syncOrderSwitchChanged:(id)sender {
}

# pragma mark -
# pragma mark Event functions

- (void)cancelEvent {
    [self clearCardSetActionData];
    [self.navigationController popToViewController:[[self.navigationController viewControllers] objectAtIndex:popToViewControllerIndexCancel] animated:YES];
}

// clear out all of the state data for each of the card sets, so if we return, 
// the app will not be confused about what we did and what we didn't do in the import process.
- (void)clearCardSetActionData {
    for (ImportSet *set in allCardSets) {
        set.cardSetCreateMode = self.cardSetCreateMode;
        set.matchCardSetChecked = NO;
        set.matchCardSetId = nil;
        set.imagesDownloaded = NO;
        set.duplicatesChecked = NO;
        set.isSaved = NO;
        set.isFiltered = NO;
        set.reverseFrontAndBackOfCards = NO;
    }
}

# pragma mark -
# pragma mark Import functions
- (void)setHUDLabel:(NSString*)labelText {
    [HUD setLabelText:labelText];
}

- (void)setupHUD:(NSString*)labelText {
    if (!HUD) {
        HUD = [[MBProgressHUD alloc] initWithView:self.view];
        
        // Add HUD to screen
        [self.view addSubview:HUD];
        
        // Regisete for HUD callbacks so we can remove it from the window at the right time
        HUD.delegate = self;
    }
    HUD.minShowTime = 2.0;
    HUD.labelText = labelText;
    [HUD show:YES];
}

// returns YES to continue, NO means that it should stop what it's doing.
/**** BACKGROUND THREAD ****/
- (bool)importCardSet {
    @autoreleasepool {
        NSManagedObjectContext *tempMOC = [FlashCardsCore tempMOC];
        
        BOOL hasSelectedSync = NO;
        BOOL hasSelectedSubscribe = NO;
        if ([self canShowSyncOptions]) {
            if (![self canSyncSets] && [subscribeOptionSwitch isOn]) {
                hasSelectedSubscribe = YES;
                for (ImportSet *cardSetData in allCardSets) {
                    [cardSetData setWillSubscribe:YES];
                }
            }
            if ([self canSyncSets] && [keepSetInSyncOptionSwitch isOn]) {
                hasSelectedSync = YES;
                for (ImportSet *cardSetData in allCardSets) {
                    [cardSetData setWillSync:YES];
                }
            }
        }
        
        // if the user is subscribing, there is no merge exact duplicates; there is no merge **anything**!
        if (!hasSelectedSubscribe) {
            BOOL mergeExactDuplicates = [mergeExactDuplicatesOptionSwitch isOn];
            [FlashCardsCore setSetting:@"importSettingsAutoMergeIdenticalCards" value:[NSNumber numberWithBool:mergeExactDuplicates]];
            if (mergeExactDuplicates) {
                [FlashCardsCore setSetting:@"importSettingsAutoMergeIdenticalCardsAndResetStatistics" value:[NSNumber numberWithBool:[resetStatisticsOfExactDuplicatesOptionSwitch isOn]]];
            } else {
                [FlashCardsCore setSetting:@"importSettingsAutoMergeIdenticalCardsAndResetStatistics" value:[NSNumber numberWithBool:NO]];
                
            }
        }
        
        if (self.collectionId || self.cardSetId) {
            // if we are editing a set, then we don't need to check if the sets have duplicate names -- we are just importing the cards
            // directly into the set!
            if ([importAsSeparateSetsOptionSwitch isOn]) {
                // check for duplicates. If the app finds that there are sets with the same name,
                // it will ask the user if she wants to save to the same set or create a new one.
                // if it is saved to the same set, it will overwrite the options for subscribing or being in sync.
                
                // first, if we are importing directly to a collection, we should check to see
                // if there is already a card set with the same name in this collection:
                if (self.cardSetId) {
                    // we don't do anything because it doesn't really quite matter
                    // if we are importing the sets
                } else {
                    NSString *name;
                    FCCollection *theCollection = (FCCollection*)[tempMOC objectWithID:self.collectionId];
                    for (FCCardSet* set in [theCollection allCardSets]) {
                        if ([set.isDeletedObject boolValue]) {
                            continue;
                        }
                        for (ImportSet *cardSetData in allCardSets) {
                            if (cardSetData.matchCardSetChecked) {
                                continue;
                            }
                            name = [set name];
                            if (!name) {
                                continue;
                            }
                            if (([importMethod isEqualToString:@"quizlet"] && cardSetData.cardSetId == [set.quizletSetId intValue])) {
                                // we have an **exact match** for the set.
                                [self performSelectorOnMainThread:@selector(showExactSetMatchFoundWithSets:)
                                                       withObject:@{@"remoteSet" : cardSetData, @"localSetId" : [set objectID] }
                                                    waitUntilDone:NO];
                                return NO; // exit the function. we will come back once the user makes his decision.
                            }
                            if ([[name lowercaseString] isEqualToString:[cardSetData.name lowercaseString]]) {
                                // we have a match! Alert the user and ask if they want to import the cards into the already-existing card set:
                                self.matchCardSetId = [set objectID];
                                matchCardSetImportSet = cardSetData;
                                cardSetData.matchCardSetChecked = YES;
                                [self performSelectorOnMainThread:@selector(showDuplicateSetMatchFound:) withObject:cardSetData waitUntilDone:NO];
                                return NO; // exit the function. we will come back once the user makes his decision.
                            }
                        }
                    }
                }
            }
            
            // set the top buttons:
            self.navigationItem.rightBarButtonItem = nil;
            
            [self performSelectorOnMainThread:@selector(setupHUD:)
                                   withObject:NSLocalizedStringFromTable(@"Importing Cards", @"Import", @"HUD")
                                waitUntilDone:NO];
            
            for (ImportSet *cardSetData in allCardSets) {
                if (cardSetData.imagesDownloaded) {
                    continue;
                }
                if (cardSetData.hasImages && [FlashCardsCore hasFeature:@"Photos"]) {
                    [self performSelectorOnMainThread:@selector(setHUDLabel:)
                                           withObject:NSLocalizedStringFromTable(@"Downloading Images", @"Import", @"HUD")
                                        waitUntilDone:NO];
                    [cardSetData setDelegate:self];
                    [cardSetData downloadImages];
                }
                cardSetData.imagesDownloaded = YES;
            }
            
            // we should filter terms *after* downloading images, otherwise the images don't flip
            // since the data is simply not there to download:
            [self filterTermsListByOptions];
            
            if (hasSelectedSubscribe || hasSelectedSync) {
                for (ImportSet *set in allCardSets) {
                    if (set.matchCardSetId) {
                        // the set is going to sync/subscribe, and has a match. What to do???
                        if (![[set matchCardSetInMOC:tempMOC] allCardsHaveIdsForWebsite:importMethod]) {
                            // not all cards have IDs. What to do???
                            [self performSelectorOnMainThread:@selector(showMatchLocalCardsWithRemoteCardsViewController:)
                                                   withObject:set
                                                waitUntilDone:NO];
                            return NO;
                        }
                    }
                }
            }
            
            BOOL appChecksDuplicates = NO;
            if (!hasSelectedSubscribe) {
                [self performSelectorOnMainThread:@selector(setHUDLabel:)
                                       withObject:NSLocalizedStringFromTable(@"Processing Duplicates", @"Import", @"HUD")
                                    waitUntilDone:NO];
                
                // Check for duplicates that might want to be merged:
                if ([checkDuplicatesOptionSwitch isOn] || hasSelectedSubscribe || hasSelectedSync) {
                    appChecksDuplicates = YES;
                    int error;
                    FCCollection *checkForDuplicatesInCollection;
                    FCCardSet *importingIntoSet;
                    for (ImportSet *cardSetData in allCardSets) {
                        if (cardSetData.duplicatesChecked) {
                            continue;
                        }
                        
                        if (cardSetCreateMode == modeCreate) {
                            checkForDuplicatesInCollection = [self collectionInMOC:tempMOC];
                        } else {
                            checkForDuplicatesInCollection = [[self cardSetInMOC:tempMOC] collection];
                        }
                        if (hasSelectedSync || hasSelectedSubscribe) {
                            if (cardSetData.matchCardSetId && (cardSetData.willSubscribe || cardSetData.willSync)) {
                                checkForDuplicatesInCollection = [[cardSetData matchCardSetInMOC:tempMOC] collection];
                            }
                        }
                        error = [cardSetData.flashCards findDuplicatesInCollection:checkForDuplicatesInCollection
                                                                  withImportMethod:importMethod];
                        cardSetData.duplicatesChecked = YES;
                        if (error < 0) {
                            return NO;
                        }
                        // Find all of the duplicates:
                        importingIntoSet = self.cardSet;
                        if (hasSelectedSync || hasSelectedSubscribe) {
                            if (cardSetData.matchCardSetId && (cardSetData.willSubscribe || cardSetData.willSync)) {
                                importingIntoSet = [cardSetData matchCardSetInMOC:tempMOC];
                            }
                        }
                        duplicateCards = [cardSetData.flashCards duplicateCards:(cardSetData.willSync || cardSetData.willSubscribe)
                                                                    withWebsite:importMethod
                                                               importingIntoSet:importingIntoSet];
                        if ([duplicateCards count] > 0) {
                            [self performSelectorOnMainThread:@selector(finishDuplicates:) withObject:cardSetData waitUntilDone:NO];
                            return NO; // we will come back to this if the user returns!
                        }
                        // save the cards and exit. we will return if there are more sets to check.
                        [self performSelectorInBackground:@selector(saveCards:) withObject:cardSetData];
                        return NO;
                    }
                }
            }
            if (!appChecksDuplicates) {
                for (ImportSet *cardSetData in allCardSets) {
                    // mark it off that we have checked all the duplicates:
                    cardSetData.duplicatesChecked = YES;
                }
                // we get here immediatley if there are no duplicates, or if the user has turned off duplicate checking:
                self.navigationItem.rightBarButtonItem.enabled = YES;
                [self performSelectorInBackground:@selector(saveCards:)
                                       withObject:nil];
                return NO;
                // [self performSelectorOnMainThread:@selector(saveCards:) withObject:nil waitUntilDone:YES];
            }
            
            //[HUD showWhileExecuting:@selector(importCardSetWorker) onTarget:self withObject:nil animated:YES];
        } else {
            // we don't know where we are going to import these; ask the user!
            [self performSelectorOnMainThread:@selector(showSelectCollectionViewController)
                                   withObject:nil
                                waitUntilDone:NO];
            return NO;
        }    
        return NO;
    }
}

/**** MAIN THREAD ****/
- (void)showDuplicateSetMatchFound:(ImportSet*)cardSetData {
    matchCardSetDecisionGoesDirectlyToImport = YES;
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Duplicate Set Found", @"Import", @"UIAlert title")
                                                    message:[NSString stringWithFormat:NSLocalizedStringFromTable(@"You already have a card set entitled \"%@\". Would you like to import these cards into this already-existing set, or would you like to create a new card set?", @"Import", @"message"), cardSetData.name]
                                                   delegate:self
                                          cancelButtonTitle:NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"cancelButtonTitle")
                                          otherButtonTitles:
                          NSLocalizedStringFromTable(@"Create New Set", @"Import", @"cancelButtonTitle"),
                          NSLocalizedStringFromTable(@"Import to Existing Set", @"Import", @"otherButtonTitles"), nil];
    [alert show];
}

/**** MAIN THREAD ****/
- (void)showExactSetMatchFoundWithSets:(NSDictionary*)sets {
    ImportSet *cardSetData = [sets objectForKey:@"remoteSet"];
    NSManagedObjectID *localSetId = [sets objectForKey:@"localSetId"];
    // we need to ask them if they want to sync it
    FCCardSet *set = (FCCardSet*)[[FlashCardsCore mainMOC] objectWithID:localSetId];
    self.matchCardSetId = localSetId;
    self.matchCardSetImportSet = cardSetData;
    cardSetData.matchCardSetChecked = YES;
    matchCardSetDecisionGoesDirectlyToImport = YES;
    
    NSString *previouslyImported = [NSString stringWithFormat:NSLocalizedStringFromTable(@"You have previously imported the card set \"%@\".", @"Import", @"message"), cardSetData.name];
    NSString *whatToDo;
    NSString *syncOrSubscribe;
    
    UIAlertView *alert;
    
    // first, is the set already synced or subscribed??
    if ([set.isSubscribed boolValue] || [set.shouldSync boolValue]) {
        if ([set.isSubscribed boolValue]) {
            // it's subscribed - we can't actually import cards to this set. Ask them what to do.
            whatToDo = NSLocalizedStringFromTable(@"This set is Subscribed to online changes. For this reason, you cannot import cards to this card set. You can choose to create a new set and import the cards a second time, or not import this set. What would you like to do?", @"Import", "");
        } else if ([set.shouldSync boolValue]) {
            whatToDo = NSLocalizedStringFromTable(@"This set Syncs with online changes. You can choose to create a new set and import the cards a second time, or not import this set. What would you like to do?", @"Import", "");
        }
        syncOrSubscribe = NSLocalizedStringFromTable(@"Don't Import This Set", @"Import", @"");
        alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Set Previously Imported", @"Import", @"UIAlert title")
                                           message:[NSString stringWithFormat:@"%@ %@", previouslyImported, whatToDo]
                                          delegate:self
                                 cancelButtonTitle:NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"cancelButtonTitle")
                                 otherButtonTitles:
                 NSLocalizedStringFromTable(@"Create New Set", @"Import", @"cancelButtonTitle"),
                 syncOrSubscribe,
                 nil];
        [alert show];
        return;
    }
    
    if ([self canSyncSets]) {
        // they can sync
        whatToDo = NSLocalizedStringFromTable(@"Would you like to turn Sync on for this already-existing set, import these cards into this already-existing set without turning on Sync, or would you like to create a new card set?", @"Import", @"");
        syncOrSubscribe = NSLocalizedStringFromTable(@"Sync With Existing Set", @"Import", @"");
    } else {
        // they can subscribe
        whatToDo = NSLocalizedStringFromTable(@"Would you like to Subscribe to online changes for this already-existing set, import these cards into this already-existing set without Subscribing to online changes, or would you like to create a new card set? NOTE: If you subscribe to online changes, any changes you have made locally will be erased.", @"Import", @"");
        syncOrSubscribe = NSLocalizedStringFromTable(@"Subscribe to Online Changes", @"Import", @"");
    }
    alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Set Previously Imported", @"Import", @"UIAlert title")
                                       message:[NSString stringWithFormat:@"%@ %@", previouslyImported, whatToDo]
                                      delegate:self
                             cancelButtonTitle:NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"cancelButtonTitle")
                             otherButtonTitles:
             NSLocalizedStringFromTable(@"Create New Set", @"Import", @"cancelButtonTitle"),
             NSLocalizedStringFromTable(@"Import to Existing Set", @"Import", @"otherButtonTitles"),
             syncOrSubscribe,
             nil];
    [alert show];
}

/**** MAIN THREAD ****/
- (void)showMatchLocalCardsWithRemoteCardsViewController:(ImportSet*)set {
    MatchLocalCardsWithRemoteCardsViewController *vc = [[MatchLocalCardsWithRemoteCardsViewController alloc] initWithNibName:@"MatchLocalCardsWithRemoteCardsViewController" bundle:nil];
    vc.localSet = [set matchCardSetInMOC:[FlashCardsCore mainMOC]];
    vc.remoteSet = set;
    vc.importMethod = self.importMethod;
    vc.popToViewControllerIndex = self.popToViewControllerIndexCancel;
    [vc findExactMatches];
    if ([vc.localCardsWithoutWebIds count] == 0) {
        // we found exact matches for **all** cards!
        [self importCardSet];
    } else {
        [self.navigationController pushViewController:vc animated:YES];
    }
}

/**** MAIN THREAD ****/
- (void)showSelectCollectionViewController {
    SelectCollectionViewController *vc = [[SelectCollectionViewController alloc] initWithNibName:@"SelectCollectionViewController" bundle:nil];
    NSMutableSet *topicsOptions = [[NSMutableSet alloc] initWithCapacity:0];
    for (ImportSet *cardSetData in allCardSets) {
        for (NSString *tag in cardSetData.tags) {
            if ([topicsOptions containsObject:tag]) {
                continue;
            }
            [topicsOptions addObject:tag];
        }
    }
    if ([allCardSets count] == 1) {
        vc.importSet = [allCardSets objectAtIndex:0];
    }
    vc.topicsOptions = [NSMutableArray arrayWithArray:[topicsOptions allObjects]];
    [self.navigationController pushViewController:vc animated:YES];
}


/**** MAIN THREAD ****/
- (void)finishDuplicates:(ImportSet*)cardSetData {
    
    BOOL hasSelectedSync = NO;
    BOOL hasSelectedSubscribe = NO;
    if ([self canShowSyncOptions]) {
        if (![self canSyncSets] && [subscribeOptionSwitch isOn]) {
            hasSelectedSubscribe = YES;
            for (ImportSet *cardSetData in allCardSets) {
                [cardSetData setWillSubscribe:YES];
            }
        }
        if ([self canSyncSets] && [keepSetInSyncOptionSwitch isOn]) {
            hasSelectedSync = YES;
            for (ImportSet *cardSetData in allCardSets) {
                [cardSetData setWillSync:YES];
            }
        }
    }

    // this is the real test -- not if we have a duplicateCount > 0, but
    // if we ultimately have some cards to check with duplicates.
    if ([duplicateCards count] > 0 && ([checkDuplicatesOptionSwitch isOn] || hasSelectedSubscribe || hasSelectedSync)) {
        
        NSString *message =[NSString stringWithFormat:FCPluralLocalizedStringFromTable(@"%d duplicate cards found in \"%@.\" You can now merge them with already existing cards in this collection.", @"Plural", @"message", [NSNumber numberWithInt:(int)[duplicateCards count]]),
                            [duplicateCards count], cardSetData.name ];
        FCDisplayBasicErrorMessage(@"", message);
        
        DuplicateCardViewController *vc = [[DuplicateCardViewController alloc] initWithNibName:@"DuplicateCardViewController" bundle:nil];
        vc.duplicateCards = duplicateCards;
        vc.termsList = cardSetData.flashCards;
        self.currentlyImportingSet = cardSetData;
        vc.popToViewControllerIndex = self.popToViewControllerIndexCancel;
        
        [self.navigationController pushViewController:vc animated:YES];
        
        return;
        
    }
}

// returns whether or not the calling function should display the popup:
// i.e. return YES means that this function already called the popup, return NO means that it did not.
/**** BACKGROUND THREAD ****/
- (bool)saveCards:(ImportSet*)cardSetData {
    @autoreleasepool {
        [self performSelectorOnMainThread:@selector(setupHUD:)
                               withObject:NSLocalizedStringFromTable(@"Saving", @"Import", @"HUD")
                            waitUntilDone:NO];
        
        bool shouldCallPopup = YES;
        if (cardSetData) {
            FCCardSet *destinationCardSet = self.cardSet;
            if (cardSetData.cardSetCreateMode == modeCreate && !cardSetData.matchCardSetId) {
                
                // if we already have a card set and we want to import as a single set, then don't create a new set.
                if (!(self.cardSet && ![importAsSeparateSetsOptionSwitch isOn])) {
                    // create the new card set:
                    
                    FCCardSet *newCardSet = (FCCardSet *)[NSEntityDescription insertNewObjectForEntityForName:@"CardSet"
                                                                                       inManagedObjectContext:[FlashCardsCore mainMOC]];
                    [newCardSet setName:cardSetData.name];
                    [newCardSet setCollection:[self collectionInMOC:[FlashCardsCore mainMOC]]];
                    [newCardSet setImportSource:importMethod];
                    [newCardSet setDidReverseFrontAndBack:[NSNumber numberWithBool:[reverseCardsOptionSwitch isOn]]];
                    destinationCardSet = newCardSet;
                }
            }
            if (!destinationCardSet) {
                if (cardSetData.matchCardSetId) {
                    destinationCardSet = [cardSetData matchCardSetInMOC:[FlashCardsCore mainMOC]];
                }
            }
            if ([importMethod isEqualToString:@"quizlet"]) {
                [destinationCardSet setCreatorUsername:[cardSetData creator]];
            }
            if (cardSetData.cardSetId > 0) {
                if ([importMethod isEqual:@"quizlet"]) {
                    [destinationCardSet setQuizletSetId:[NSNumber numberWithInt:cardSetData.cardSetId]];
                }
                if ([self isLoggedIn] && [self canSyncSets]) {
                    [destinationCardSet setShouldSync:[NSNumber numberWithBool:[keepSetInSyncOptionSwitch isOn]]];
                    if ([[destinationCardSet shouldSync] boolValue]) {
                        [destinationCardSet setLastSyncDate:[NSDate date]];
                    }
                } else {
                    [destinationCardSet setIsSubscribed:[NSNumber numberWithBool:[subscribeOptionSwitch isOn]]];
                    if ([[destinationCardSet isSubscribed] boolValue]) {
                        [destinationCardSet setLastSyncDate:[NSDate date]];
                    }
                }
            }
            
            [destinationCardSet setDidReverseFrontAndBack:[NSNumber numberWithBool:[reverseCardsOptionSwitch isOn]]];
            
            [destinationCardSet importCards:cardSetData.flashCards withImportMethod:importMethod];
            
            if ([[destinationCardSet isSubscribed] boolValue] || [[destinationCardSet shouldSync] boolValue]) {
                [destinationCardSet setLastSyncDate:[NSDate date]];
            }

            // update the language information.
            // if the collection does not have a front language, but the set does, then set it to the set value.
            if (cardSetData.frontLanguage &&
                ![[self collectionInMOC:[FlashCardsCore mainMOC]] frontValueLanguage]) {
                [collection setFrontValueLanguage:cardSetData.frontLanguage];
            }
            // and the same with the back:
            if (cardSetData.backLanguage &&
                ![[self collectionInMOC:[FlashCardsCore mainMOC]] backValueLanguage]) {
                [collection setBackValueLanguage:cardSetData.backLanguage];
            }
            [FlashCardsCore saveMainMOC];
            
            cardSetData.isSaved = YES;
            
            // check the other sets and see if we will need to do the work on the other sets. By the time we have
            // saved ONE set, then all the steps should have been finished EXCEPT duplicates. So we can check if
            // the duplicates have been checked on all the sets; if they have then we can continue; otherwise we should
            // send the user back to the import function.
            
            bool shouldContinue = YES;
            for (ImportSet *data in allCardSets) {
                if (!data.duplicatesChecked) {
                    // already running on the background thread - thus don't need to
                    // make a new thread.
                    shouldContinue = [self importCardSet];
                    if (!shouldContinue) {
                        return NO;
                    }
                }
            }
        } else {
            bool popupCalled = NO;
            for (ImportSet *data in allCardSets) {
                if (data.isSaved) {
                    continue;
                }
                popupCalled = [self saveCards:data];
                if (popupCalled) {
                    shouldCallPopup = NO;
                }
            }
        }
        bool allDataIsSaved = YES;
        totalCardsSaved = 0;
        for (ImportSet *data in allCardSets) {
            if (!data.isSaved) {
                allDataIsSaved = NO;
            }
            totalCardsSaved += [data.flashCards count];
        }
        
        // ifdef LITE
        if (![FlashCardsCore hasFeature:@"UnlimitedCards"]) {
            if ((initialNumCards + totalCardsSaved) > maxCardsLite) {
                totalCardsSaved = maxCardsLite - initialNumCards;
            }
        }

        if (allDataIsSaved && shouldCallPopup) {
            // we're done saving the import.
            // If we are syncing the sets, then do a full sync.
            if ([FlashCardsCore appIsSyncing] || ([self canSyncSets] && [keepSetInSyncOptionSwitch isOn])) {
                // do a full sync.
                [[[FlashCardsCore appDelegate] syncController] setDelegate:self];
                [FlashCardsCore showSyncHUD];
                [FlashCardsCore sync];
            } else {
                // if not, then show the popup:
                [self cleanup];
            }
            return YES; // the calling function should NOT call the popup - it was already called.
        }
        return NO;
    }
}

- (void)cleanup {
    [FlashCardsCore setSetting:@"hasImportedCardsRecently" value:@YES];
    
    [self performSelectorOnMainThread:@selector(displayDidFinishImport:)
                           withObject:[NSNumber numberWithInt:totalCardsSaved]
                        waitUntilDone:NO];
    if ([importMethod isEqualToString:@"quizlet"]) {
        [[[FlashCardsCore appDelegate] syncController] getImageIds];
    }
}

- (void)displayDidFinishImport:(NSNumber*)_totalCardsSaved {
    totalCardsSaved = [_totalCardsSaved intValue];
    
    NSString *message = [NSString stringWithFormat:FCPluralLocalizedStringFromTable(@"Successfully imported %d cards.", @"Plural", @"UIAlert title", [NSNumber numberWithInt:totalCardsSaved]), totalCardsSaved];
    NSString *cancelButtonTitle = (cardSetCreateMode == modeCreate ?
                                   NSLocalizedStringFromTable(@"Return to Collection", @"Import", @"cancelButtonTitle") :
                                   NSLocalizedStringFromTable(@"Return to Card Set", @"Import", @"cancelButtonTitle")
                                   );
    NSString *returnToImportButtonTitle;
    if ([self.importFunction isEqual:@"Dropbox"]) {
        returnToImportButtonTitle = NSLocalizedStringFromTable(@"Return to Dropbox", @"Import", @"cancelButtonTitle");
    } else if ([self.importFunction isEqual:@"MySets"]) {
        returnToImportButtonTitle = NSLocalizedStringFromTable(@"Return to My Sets", @"Import", @"cancelButtonTitle");
    } else if ([self.importFunction isEqual:@"Group"]) {
        returnToImportButtonTitle = NSLocalizedStringFromTable(@"Return to Group", @"Import", @"cancelButtonTitle");
    } else { // if ([self.importFunction isEqual:@"SearchSets"]) {
        returnToImportButtonTitle = NSLocalizedStringFromTable(@"Return to Search", @"Import", @"cancelButtonTitle");
    }
    
    RIButtonItem *cancelItem = [RIButtonItem item];
    cancelItem.label = cancelButtonTitle;
    cancelItem.action = ^{
        /*
         
         View controller stack:
         
         0) Collections
         1) CollectionsView
         2) CardSetList
         3) CardSetView
         4) CardSetImportChoice
         5) CardSetImport
         
         */
        [self clearCardSetActionData];
        [self.navigationController popToViewController:[[self.navigationController viewControllers] objectAtIndex:popToViewControllerIndexSave] animated:YES];
    };
    
    RIButtonItem *returnItem = [RIButtonItem item];
    returnItem.label = returnToImportButtonTitle;
    returnItem.action = ^{
        // return to whatever the user wanted to return to:
        
        // clear out the multiple listing:
        FCSetsTableViewController *vc = (FCSetsTableViewController*)[self.navigationController.viewControllers objectAtIndex:([self.navigationController.viewControllers count]-2)];
        // [vc.selectedIndexPathsSet removeAllObjects];
        if ([vc respondsToSelector:@selector(myTableView)]) {
            [(UITableView*)[vc performSelector:@selector(myTableView)] reloadData];
        } else if ([vc respondsToSelector:@selector(tableView)]) {
            [(UITableView*)[vc performSelector:@selector(tableView)] reloadData];
        }
        [self clearCardSetActionData];
        [self.navigationController popViewControllerAnimated:YES];
    };

    RIButtonItem *studyItem = [RIButtonItem item];
    studyItem.label = NSLocalizedStringFromTable(@"Study Now", @"Import", @"otherButtonTitles");
    studyItem.action = ^{
        // study cards now:
        
        // create a study VC:
        
        StudySettingsViewController *studyVC = [[StudySettingsViewController alloc] initWithNibName:@"StudySettingsViewController" bundle:nil];
        studyVC.collection = self.collection;
        if ([allCardSets count] == 1) {
            studyVC.cardSet = self.cardSet;
        } else {
            studyVC.cardSet = nil;
        }
        studyVC.studyingImportedSet = YES;
        studyVC.studyAlgorithm = studyAlgorithmLearn;
        
        // Pass the selected object to the new view controller.
        NSMutableArray *viewControllers = [[NSMutableArray alloc] initWithArray:[self.navigationController viewControllers]];
        while ([viewControllers count] > popToViewControllerIndexSave+1) {
            [viewControllers removeLastObject];
        }
        [viewControllers addObject:studyVC];
        
        [self.navigationController setViewControllers:viewControllers animated:YES];
    };

    RIButtonItem *editItem = [RIButtonItem item];
    editItem.label = NSLocalizedStringFromTable(@"Edit Cards", @"Import", @"otherButtonTitles");
    editItem.action = ^{
        // edit cards
        NSMutableArray *cardList = [[NSMutableArray alloc] initWithCapacity:0];
        for (ImportSet *cardSetData in allCardSets) {
            for (ImportTerm *term in cardSetData.flashCards) {
                // in lite version not all cards have necessarily been imported... so just check that it exists.
                if (!term.finalCardId) {
                    continue;
                }
                [cardList addObject:[term finalCardInMOC:[FlashCardsCore mainMOC]]];
            }
        }
        
        CardEditViewController *cardEditVC = [[CardEditViewController alloc] initWithNibName:@"CardEditViewController" bundle:nil];
        cardEditVC.cardList = cardList;
        cardEditVC.editInPlace = NO;
        cardEditVC.popToViewControllerIndex = popToViewControllerIndexSave;
        
        [self clearCardSetActionData];
        
        [self.navigationController pushViewController:cardEditVC animated:YES];
    };
    
    

    UIAlertView *alert;
    if ([self canShowSyncOptions] && !([self isLoggedIn] && [self canSyncSets]) && [subscribeOptionSwitch isOn]) {
        alert = [[UIAlertView alloc] initWithTitle:@""
                                           message:message
                                  cancelButtonItem:cancelItem
                                  otherButtonItems:studyItem,
                                                  returnItem,
                                                  nil];
    } else {
        alert = [[UIAlertView alloc] initWithTitle:@""
                                           message:message
                                  cancelButtonItem:cancelItem
                                  otherButtonItems:studyItem,
                                                   editItem,
                                                   returnItem,
                                                   nil];
    }
    [alert show];

}

// ifdef LITE
- (void)checkNumberCardsToAdd {
    // this function just sees if the user will add more cards than the number
    // allowed. If so, then prompt the user that they won't be able to add every card in their
    // import set.
    
    if (![FlashCardsCore hasFeature:@"UnlimitedCards"]) {
        int numCards = [FlashCardsCore numTotalCards];
        int numNewCards = 0;
        for (ImportSet *cardSetData in self.allCardSets) {
            numNewCards += [cardSetData.flashCards count];
        }
        if ((numCards + numNewCards) >= maxCardsLite) {
            NSString *alertMsg = [NSString stringWithFormat:
                                  NSLocalizedStringFromTable(@"You are using the free version of FlashCards++, which has a limit of %d cards. Importing these cards will put you over the limit, so FlashCards++ will only import the first %d cards. If you subscribe to FlashCards++, you can have an infinite number of collections & cards.", @"FlashCardsLite", @"lite message"),
                                  maxCardsLite,
                                  (maxCardsLite - numCards)
                                  ];
            
            [FlashCardsCore showPurchasePopup:@"UnlimitedCards" withMessage:alertMsg];
        }
    }

    
}

# pragma mark -
# pragma mark Helper functions

// if the user is importing multiple sets we want to make sure that they
// can sync all of them
- (BOOL)canSyncSets {
    BOOL canSyncSets = YES;
    for (ImportSet *set in allCardSets) {
        if (!([self isLoggedIn] && set.userCanEditOnline)) {
            canSyncSets = NO;
        }
    }
    return canSyncSets;
}

- (BOOL)canShowSyncOptions {
    // we will abstract the logic for whether the user can see the sync options, in case
    // we want to add more sync capabilities (i.e. quizlet sync)
    BOOL _canShowSyncOptions = ([importMethod isEqualToString:@"quizlet"]);
    return _canShowSyncOptions;
}

- (NSString*)syncExplanationString {
    
    NSString *deviceName = [FlashCardsCore deviceName];
    NSString *explanation = @"";
    NSString *service = @"";
    service = @"Quizlet";
    if ([self isLoggedIn] && [self canSyncSets]) {
        // keep in sync
        if ([keepSetInSyncOptionSwitch isOn]) {
            explanation = NSLocalizedStringFromTable(@"This set will automatically be synced with %@, as long as you are logged in. Any changes you make on your %@ will be uploaded to %@, and any changes you make on %@ will be downloaded to your %@.", @"CardManagement", @"");
            explanation = [NSString stringWithFormat:explanation, service, deviceName, service, service, deviceName];
        }
    } else {
        // will subscribe
        if ([subscribeOptionSwitch isOn]) {
            explanation = NSLocalizedStringFromTable(@"This set will automatically download changes from %@. Because it is a subscribed set, you will not be able to edit the cards on your %@. Any changes made on %@ will automatically download to your %@.", @"CardManagement", @"");
            explanation = [NSString stringWithFormat:explanation, service, deviceName, service, deviceName];
        }
    }
    return explanation;
    
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    int numberOfSections = 1 + ([allCardSets count] * 2);
    if ([self canShowSyncOptions]) {
        numberOfSections++; // show the "subscribe" or "sync" option at the very top.
    }
    return numberOfSections;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // the number of sections in front of the sections that show the actual cards
    int reduceSection = 2;
    if (![self canShowSyncOptions]) {
        // don't show the "subscribe" or "sync" option unless we are importing from FCE.
        section++;
    } else {
        // we **can** show the "subscribe" or "sync" options and need to reduce again
        if (section == 0) {
            return 1; // subscribe or sync option
        }
        // if the user has selected to subscribe, then we might think that we are supposed to
        // not show them any options. But this isn't true! There is always the option to reverse
        // the front & the back
    }
    if (section == 1) {
        // import options:
        int numRows;
        BOOL hasSelectedSync = NO;
        BOOL hasSelectedSubscribe = NO;
        BOOL isShowingMergeExactDuplicatesOption = NO;
        if ([self canShowSyncOptions]) {
            // If the user has selected to subscribe, only show:
            // 1) Reverse front & back
            if (![self canSyncSets] && [subscribeOptionSwitch isOn]) {
                return 1;
            }
            
            // If the user has selected to sync, show:
            // 1) Reverse front & back
            // 2) Check for duplicates
            // 3) merge exact matches
            // 4) [potentially] reset stats for exact matches
            // 5) [NOT] import as separate sets - they are syncing them as SETS
            if ([self canSyncSets] && [keepSetInSyncOptionSwitch isOn]) {
                numRows = 3; // [reset stats for exact matches determined later]
                hasSelectedSync = YES;
                isShowingMergeExactDuplicatesOption = YES;
            }
        }
        // If the user hasn't selected any of these options, or doesn't have this option, then show:
        // 1) Reverse front & back
        // 2) Check for duplicates
        // 3) Merge exact matches
        // 4) [potentially] reset stats for exact matches
        if (!hasSelectedSync && !hasSelectedSubscribe) {
            // don't display import as separate card set if we are importing to a specific set
            if ([allCardSets count] > 1 && !self.cardSet) {
                // if there is more than one card set to import:
                numRows = 4; // reverse cards, check duplicates, AND import as separate sets, AND merge exact matches
            } else {
                numRows = 3; // JUST reverse cards, check duplicates, AND merge exact matches
            }
            isShowingMergeExactDuplicatesOption = YES;
        }
        if (isShowingMergeExactDuplicatesOption && [mergeExactDuplicatesOptionSwitch isOn]) {
            numRows++; // ALSO reset statistics for exact matches
        }
        return numRows;
    } else {
        section -= reduceSection; // bring the set down to 0
        int intSection = (int)section;
        int cardSetIndex = (intSection - (intSection % 2)) / 2;
        if (section % 2 == 0) {
            // it is an even section -- show the set information
            return [[self cardSetCharacteristicsList:[allCardSets objectAtIndex:cardSetIndex]] count];
        } else {
            // it is an odd section -- show the set's ards
            return [[[allCardSets objectAtIndex:cardSetIndex] flashCards] count];
        }
        
    }
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    int section = (int)indexPath.section;
    int row = (int)indexPath.row;
    int reduceSection = 2;
    if (![self canShowSyncOptions]) {
        // don't show the "subscribe" or "sync" option unless we are importing from FCE.
        section++;
    }
    
    if (section == 0) {
        // display the sync option if the user owns it; display the subscribe option
        // if they don't. If the user chooses to do this option it will display a short
        // text explaining what'll happen.
        if (row == 0) {
            if ([self isLoggedIn] && [self canSyncSets]) {
                return keepSetInSyncOptionTableViewCell;
            } else {
                return subscribeOptionTableViewCell;
            }
        } else {
            return syncOrderTableViewCell;
        }
        return nil;
    }
    if (section == 1) {
        if (row == 0) {
            return reverseCardsOptionTableViewCell;
        } else if (row == 1) {
            return checkDuplicatesOptionTableViewCell;
        } else {
            if (!([allCardSets count] > 1 && !self.cardSet)) {
                // we should not be showing the import as separate sets button.
                row++;
            }
            if (row == 2) {
                return importAsSeparateSetsOptionTableViewCell;
            }
            if (row == 3) {
                return mergeExactDuplicatesOptionTableViewCell;
            }
            if (row == 4) {
                if ([mergeExactDuplicatesOptionSwitch isOn]) {
                    return resetStatisticsOfExactDuplicatesOptionTableViewCell;
                }
            }
        }
        return nil;
    }
    
    section -= reduceSection;
    
    int style;
    NSString *CellIdentifier;
    if ((section % 2) == 1) { // this is for listing cards:
        style = UITableViewCellStyleSubtitle;
        CellIdentifier = @"subtitle";
    } else {
        style = UITableViewCellStyleValue2;
        CellIdentifier = @"value2";
    }
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:style reuseIdentifier:CellIdentifier];
    }
    
    // Configure the cell...
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    // we have a header for section 0 ("Options") and the even sections (before each card set)
    if (section > 0) {
        if (![self canShowSyncOptions]) {
            // if we can't show the sync options, then there is only one options section.
            // so we pretend that we **can** show the sync options!
            section++;
        }
    }
    if ((section == 0) || (section % 2) == 0) {
        return 40;
    }
    return 0;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    
    if (section > 0) {
        if (![self canShowSyncOptions]) {
            // if we can't show the sync options, then there is only one options section.
            // so we pretend that we **can** show the sync options!
            section++;
        }
    }

    if (!((section == 0) || (section % 2) == 0)) {
        return nil;
    }
    
    UIView* customView = [[UIView alloc] initWithFrame:CGRectMake(10.0, 0.0, 300.0, 44.0)];
    
    // create the button object
    UILabel * headerLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    headerLabel.backgroundColor = [UIColor clearColor];
    headerLabel.opaque = NO;
    headerLabel.textColor = [UIColor blackColor];
    headerLabel.highlightedTextColor = [UIColor whiteColor];
    headerLabel.font = [UIFont boldSystemFontOfSize:19];
    if ([FlashCardsAppDelegate isIpad]) {
        headerLabel.frame = CGRectMake(60.0, 0.0, 300.0, 44.0);
    } else {
        headerLabel.frame = CGRectMake(10.0, 0.0, 300.0, 44.0);
    }
    
    if (section == 0) {
        headerLabel.text = NSLocalizedStringFromTable(@"Options", @"FlashCards", @"headerLabel");
    } else {
        section -= 2; // bring the set down to 0
        int cardSetIndex = (section - (section % 2)) / 2;
        ImportSet *cardSetData = [allCardSets objectAtIndex:cardSetIndex];
        headerLabel.text = cardSetData.name;
        // headerLabel.text = [NSString stringWithFormat:FCPluralLocalizedStringFromTable(@"%d Cards", @"Plural", @"", [NSNumber numberWithInt:[cardSetData numberCards]]), [cardSetData numberCards]];
    }
    [customView addSubview:headerLabel];
    
    return customView;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    if (section != 0 || ![self canShowSyncOptions]) {
        return 0.0;
    }
    NSString *explanation = [self syncExplanationString];
    if ([explanation length] == 0) {
        return 0.0;
    }
    
    // create the button object
    UITextView * footerLabel = [[UITextView alloc] initWithFrame:CGRectMake(0.0f,
                                                                            0.0f,
                                                                            self.view.frame.size.width-16.0,
                                                                            0.0f)];
    footerLabel.backgroundColor = [UIColor clearColor];
    footerLabel.opaque = NO;
    footerLabel.textColor = [UIColor blackColor];
    footerLabel.text = explanation;
    [footerLabel setFont:[UIFont systemFontOfSize:12.0f]];
    [footerLabel setTextAlignment:NSTextAlignmentCenter];
    
    CGSize tallerSize, stringSize;
    tallerSize = CGSizeMake(self.view.frame.size.width-16.0, kMaxFieldHeight);
    CGRect boundingRect = [footerLabel.text boundingRectWithSize:tallerSize
                                                         options:NSStringDrawingUsesLineFragmentOrigin
                                                      attributes:@{NSFontAttributeName:footerLabel.font}
                                                         context:nil];
    stringSize = boundingRect.size;
    return stringSize.height+10.0f;

}
- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    
    if (section != 0 || ![self canShowSyncOptions]) {
        return nil;
    }
    
    NSString *explanation = [self syncExplanationString];
    if ([explanation length] == 0) {
        return nil;
    }

    // create the button object
    UITextView * footerLabel = [[UITextView alloc] initWithFrame:CGRectMake(0.0f,
                                                                            0.0f,
                                                                            self.view.frame.size.width-16.0,
                                                                            0.0f)];
    footerLabel.backgroundColor = [UIColor clearColor];
    footerLabel.opaque = NO;
    footerLabel.textColor = [UIColor blackColor];
    footerLabel.text = explanation;
    [footerLabel setFont:[UIFont systemFontOfSize:12.0f]];
    [footerLabel setTextAlignment:NSTextAlignmentCenter];
    footerLabel.userInteractionEnabled = NO;
    
    CGSize tallerSize, stringSize;
    tallerSize = CGSizeMake(self.view.frame.size.width-16.0, kMaxFieldHeight);
    CGRect boundingRect = [footerLabel.text boundingRectWithSize:tallerSize
                                                         options:NSStringDrawingUsesLineFragmentOrigin
                                                      attributes:@{NSFontAttributeName:footerLabel.font}
                                                         context:nil];
    stringSize = boundingRect.size;
    [footerLabel setFrame:CGRectMake(footerLabel.frame.origin.x,
                                     footerLabel.frame.origin.y,
                                     footerLabel.frame.size.width,
                                     stringSize.height+10.0f)];

    return footerLabel;
}

#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    int section = indexPath.section;
    if (section == 0) {
        return;
        // don't do anything if we are tapping the options section.
    }
    
    // for dropbox -- there is only ONE options section (just regular options)
    // for quizlet, fce -- there are TWO options sections (sync options & regular options)
    int optionsSections;
    if ([self.importFunction isEqualToString:@"Dropbox"]) {
        optionsSections = 1;
    } else {
        optionsSections = 2;
    }
    // don't do anything if we are tapping the import options
    if (section < optionsSections) {
        return;
    }
    
    // if we ignore the top options sections, what section are we in?
    int cardSetSection = section - optionsSections;
    // don't do anything if we are tapping the information about the card sets
    if ((cardSetSection % 2) == 0) {
        // if we are tapping an **even** section here then we know that we are tapping
        // the card set information section. so do nothing.
        return;
    }
    
    // determine the index in the allCardSets list for the current set
    int cardSetIndex = (cardSetSection - (cardSetSection % 2)) / 2;
    ImportSet *cardSetData = [allCardSets objectAtIndex:cardSetIndex];
    ImportTerm *term = [cardSetData.flashCards objectAtIndex:indexPath.row];
    term.shouldImportTerm = !term.shouldImportTerm;

    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    [self configureCell:cell atIndexPath:indexPath];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}


# pragma mark -
# pragma mark Memory functions

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
        
    // Quizlet Set View
    quizletSetTableView = nil;
    
}


- (void)dealloc {


    
    // Quizlet Set View
    
    
    
    
    

    ;
    
    
    

    
}

@end
