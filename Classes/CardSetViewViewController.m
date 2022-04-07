//
//  CardSetViewViewController.m
//  FlashCards
//
//  Created by Jason Lustig on 5/28/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import "CardSetViewViewController.h"
#import "CardListViewController.h"
#import "StudyViewController.h"
#import "StudySettingsViewController.h"
#import "CardSetImportChoicesViewController.h"
#import "CardSetCreateViewController.h"
#import "CollectionStatisticsViewController.h"
#import "CardSetShareViewController.h"
#import "CardEditViewController.h"
#import "CardEditMultipleViewController.h"
#import "CardSetUploadToQuizletViewController.h"
#import "FlashCardsAppDelegate.h"

#import "FCCardSet.h"
#import "FCCollection.h"

#import "FCMatrix.h"

#import "UIActionSheet+Blocks.h"

@implementation CardSetViewViewController

@synthesize cardSet, cardsDue, tableListGroups, myTableView, HUD, savedFileName;
@synthesize createCardsButton, createCardsButton2;
@synthesize statisticsButton, shareButton;
@synthesize isBuildingExportFile;
@synthesize tableFooterUpload;
@synthesize syncsWithLabel, viewOnWebsiteButton, tableFooterSync;
@synthesize quizletImage;
@synthesize shouldSync;

@synthesize bottomBar;

#pragma mark -
#pragma mark View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    shouldSync = NO;
    
    [createCardsButton setTitle:NSLocalizedStringFromTable(@"Create Cards", @"CardManagement", @"UIBarButtonTitle") forState:UIControlStateNormal];
    [createCardsButton setTitle:NSLocalizedStringFromTable(@"Create Cards", @"CardManagement", @"UIBarButtonTitle") forState:UIControlStateSelected];
    
    [createCardsButton2 setTitle:NSLocalizedStringFromTable(@"Create Cards", @"CardManagement", @"UIBarButtonTitle") forState:UIControlStateNormal];
    [createCardsButton2 setTitle:NSLocalizedStringFromTable(@"Create Cards", @"CardManagement", @"UIBarButtonTitle") forState:UIControlStateSelected];

    statisticsButton.title = NSLocalizedStringFromTable(@"Statistics", @"CardManagement", @"UIBarButtonTitle");
    shareButton.title = NSLocalizedStringFromTable(@"Export", @"CardManagement", @"UIBarButtonTitle");
    
    NSMutableArray *tableListOptions;
    
    tableListGroups = [[NSMutableArray alloc] initWithCapacity:0];
    tableListOptions = [[NSMutableArray alloc] initWithCapacity:0];
    [tableListOptions addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                 NSLocalizedStringFromTable(@"Learn Cards", @"CardManagement", @""), @"text",
                                 @"Learn.png", @"image",
                                 nil]];
    [tableListOptions addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                 NSLocalizedStringFromTable(@"Test Cards", @"CardManagement", @""), @"text",
                                 @"Test.png", @"image",
                                 nil]];
    [tableListOptions addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                 NSLocalizedStringFromTable(@"Review", @"CardManagement", @""), @"text",
                                 @"Repetition.png", @"image",
                                 nil]];
    [tableListGroups addObject:tableListOptions];
    
    tableListOptions = [[NSMutableArray alloc] initWithCapacity:0];
    [tableListOptions addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                 NSLocalizedStringFromTable(@"View Cards", @"CardManagement", @""), @"text",
                                 @"AllCards.png", @"image",
                                 nil]];
    [tableListOptions addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                 NSLocalizedStringFromTable(@"Import Cards", @"CardManagement", @""), @"text",
                                 @"Import.png", @"image",
                                 nil]];
    [tableListGroups addObject:tableListOptions];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    isBuildingExportFile = NO;
    
    NSMutableArray *rightBarButtonItems = [[NSMutableArray alloc] initWithCapacity:0];
    
    UIBarButtonItem *editButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit
                                                                                target:self
                                                                                action:@selector(editEvent)];
    editButton.enabled = YES;
    [rightBarButtonItems addObject:editButton];
    if ([self.cardSet.shouldSync boolValue] || [FlashCardsCore appIsSyncing]) {
        UIBarButtonItem *syncButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                                    target:self
                                                                                    action:@selector(syncEvent)];
        syncButton.enabled = YES;
        [rightBarButtonItems addObject:syncButton];
    }
    [self.navigationItem setRightBarButtonItems:rightBarButtonItems];
    
    if ([cardSet isQuizletSet]) {
        [viewOnWebsiteButton setTitle:NSLocalizedStringFromTable(@"Open on Quizlet", @"CardManagement", @"UILabel") forState:UIControlStateNormal];
        [viewOnWebsiteButton setTitle:NSLocalizedStringFromTable(@"Open on Quizlet", @"CardManagement", @"UILabel") forState:UIControlStateSelected];
    }

    [self.myTableView reloadData];
}


- (void)viewWillAppear:(BOOL)animated {

    [super viewWillAppear:animated];

    self.title = cardSet.name;
    
    [self updateCardsDueCount];
    [self updateTableFooter];
    
}

- (void) updateTableFooter {
    BOOL isFCE = NO;
    BOOL hasWebsiteId = NO;
    if ([cardSet isFlashcardExchangeSet]) {
        isFCE = YES;
        hasWebsiteId = YES;
    } else if ([cardSet isQuizletSet]) {
        hasWebsiteId = YES;
    }
    
    if ([cardSet isQuizletSet]) {
        [viewOnWebsiteButton setTitle:NSLocalizedStringFromTable(@"Open on Quizlet", @"CardManagement", @"UILabel") forState:UIControlStateNormal];
        [viewOnWebsiteButton setTitle:NSLocalizedStringFromTable(@"Open on Quizlet", @"CardManagement", @"UILabel") forState:UIControlStateSelected];
    }

    quizletImage.hidden = YES;
    if ([cardSet.isSubscribed boolValue] && hasWebsiteId) {
        self.myTableView.tableFooterView = tableFooterSync;
        [syncsWithLabel setText:NSLocalizedStringFromTable(@"Subscribes to Online Changes from:", @"CardManagement", @"")];
        if (isFCE) {
        } else {
            quizletImage.hidden = NO;
        }
    } else if ([cardSet.shouldSync boolValue] && hasWebsiteId) {
        self.myTableView.tableFooterView = tableFooterSync;
        [syncsWithLabel setText:NSLocalizedStringFromTable(@"Syncs With:", @"CardManagement", @"")];
        if (isFCE) {
        } else {
            quizletImage.hidden = NO;
        }
    } else {
        self.myTableView.tableFooterView = tableFooterUpload;
        [tableFooterUpload setHidden:NO];
    }
}

- (void) updateCardsDueCount {
    
    NSError *error;
    // Create the fetch request for the entity.
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    // Edit the entity name as appropriate.
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Card"
                                              inManagedObjectContext:[FlashCardsCore mainMOC]];
    [fetchRequest setEntity:entity];
    
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"isDeletedObject = NO and any cardSet = %@ and isSpacedRepetition = YES and nextRepetitionDate <= %@", cardSet, [NSDate date]]];
    // TODO: Handle the error
    cardsDue = (int)[[FlashCardsCore mainMOC] countForFetchRequest:fetchRequest error:&error];
    
    
    [self.myTableView reloadData];

    
}


- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    if (self.shouldSync) {
        [self syncEvent:NO];
    }
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
    if ([hud isEqual:syncHUD]) {
        syncHUD = nil;
    }
    if ([hud isEqual:HUD]) {
        HUD = nil;
    }
    hud = nil;

    if (isBuildingExportFile) {
        CardSetShareViewController *statsVC = [[CardSetShareViewController alloc] initWithNibName:@"CardSetShareViewController" bundle:nil];
        statsVC.cardSet = self.cardSet;
        statsVC.fileName = self.savedFileName;
        
        // Pass the selected object to the new view controller.
        [self.navigationController pushViewController:statsVC animated:YES];
        
    }
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

# pragma mark -
# pragma mark Event functions

- (void)editEvent {
    CardSetCreateViewController *cardSetCreate = [[CardSetCreateViewController alloc] initWithNibName:@"CardSetCreateViewController" bundle:nil];
    cardSetCreate.cardSet = self.cardSet;
    cardSetCreate.editMode = modeEdit;
    
    // Pass the selected object to the new view controller.
    [self.navigationController pushViewController:cardSetCreate animated:YES];
    
}

- (IBAction)viewOnWebsite:(id)sender {
    [cardSet openWebsite];
}

#pragma mark - TICoreDataSync methods

- (void)syncDidFinish:(SyncController *)sync {
    [self persistentStoresDidChange];
}
- (void)syncDidFinish:(SyncController *)sync withError:(NSError *)error {
    [self persistentStoresDidChange];
}

- (void)persistentStoresDidChange {
    self.title = self.cardSet.name;
    [self updateCardsDueCount];
    [self updateTableFooter];
}

#pragma mark - Sync Methods

- (void)setShouldSyncN:(NSNumber*)_shouldSync {
    self.shouldSync = [_shouldSync boolValue];
}

- (void)updateHUDLabel:(NSString*)labelText {
    HUD.labelText = labelText;
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return [tableListGroups count];
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    return [[tableListGroups objectAtIndex:section] count];
}


- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (cell.detailTextLabel.text.length > 0) {
    }
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    if (cell == nil) {
        // set the appropriate cell style
        int style;
        if ([[[tableListGroups objectAtIndex:indexPath.section] objectAtIndex:indexPath.row] isEqual:NSLocalizedStringFromTable(@"Review", @"CardManagement", @"")]) {
            style = UITableViewCellStyleSubtitle;
        } else {
            style = UITableViewCellStyleDefault;
        }
        cell = [[UITableViewCell alloc] initWithStyle:style reuseIdentifier:CellIdentifier];
    }
    
    // Configure the cell...
    [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
    
    NSDictionary *cellOptions = [[tableListGroups objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
    cell.textLabel.text = [cellOptions valueForKey:@"text"];
    cell.textLabel.adjustsFontSizeToFitWidth = YES;
    [cell.imageView setImage:[UIImage imageNamed:[cellOptions valueForKey:@"image"]]];
    
    if ([cell.textLabel.text isEqual:NSLocalizedStringFromTable(@"Review", @"CardManagement", @"")]) {
        if (cardsDue > 0) {
            cell.detailTextLabel.text = [NSString stringWithFormat:FCPluralLocalizedStringFromTable(@"%d cards due", @"Plural", @"", [NSNumber numberWithInt:cardsDue]), cardsDue];
            [cell setBackgroundColor:[UIColor yellowColor]];
        } else {
            cell.detailTextLabel.text = NSLocalizedStringFromTable(@"(Spaced Repetition)", @"CardManagement", @"");
            [cell setBackgroundColor:[UIColor whiteColor]];
        }
    }
    
    return cell;
}




#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

    NSString *currentText = [[[tableListGroups objectAtIndex:indexPath.section] objectAtIndex:indexPath.row] valueForKey:@"text"];
    
    NSIndexPath *selection = [self.myTableView indexPathForSelectedRow];
    if (selection) {
        [self.myTableView deselectRowAtIndexPath:selection animated:YES];
    }

    if ([currentText isEqualToString:NSLocalizedStringFromTable(@"Learn Cards", @"CardManagement", @"")] ||
        [currentText isEqualToString:NSLocalizedStringFromTable(@"Study Lapsed Cards", @"CardManagement", @"")]) {
        
        if (![FlashCardsCore canStudyCardsWithUnlimitedCards]) {
            return;
        }

        StudySettingsViewController *studyVC = [[StudySettingsViewController alloc] initWithNibName:@"StudySettingsViewController" bundle:nil];
        studyVC.collection = self.cardSet.collection;
        studyVC.cardSet = self.cardSet;
        studyVC.studyingImportedSet = NO;
        
        if ([currentText isEqualToString:NSLocalizedStringFromTable(@"Learn Cards", @"CardManagement", @"")]) {
            studyVC.studyAlgorithm = studyAlgorithmLearn;
        } else {
            studyVC.studyAlgorithm = studyAlgorithmLapsed;
        }
        // Pass the selected object to the new view controller.
        [self.navigationController pushViewController:studyVC animated:YES];
        
        
    } else if ([currentText isEqualToString:NSLocalizedStringFromTable(@"Review", @"CardManagement", @"")] ||
               [currentText isEqualToString:NSLocalizedStringFromTable(@"Test Cards", @"CardManagement", @"")]) {
        
        if (![FlashCardsCore canStudyCardsWithUnlimitedCards]) {
            return;
        }

        StudyViewController *studyVC = [[StudyViewController alloc] initWithNibName:@"StudyViewController" bundle:nil];
        studyVC.previewMode = NO;
        studyVC.collection = self.cardSet.collection;
        studyVC.cardSet = self.cardSet;
        studyVC.studyingImportedSet = NO;
        
        studyVC.popToViewControllerIndex = [[self.navigationController viewControllers] count]-1; // pop to this view controller
        
        // study options:
        if ([currentText isEqualToString:NSLocalizedStringFromTable(@"Test Cards", @"CardManagement", @"")]) {
            studyVC.studyController.studyAlgorithm = studyAlgorithmTest;
        } else {
            studyVC.studyController.studyAlgorithm = studyAlgorithmRepetition;
        }
        studyVC.studyController.studyOrder = studyOrderRandom;
        studyVC.studyController.showFirstSide = [cardSet.collection.defaultFirstSide intValue]; // get the default from the collection settings.
        
        // Pass the selected object to the new view controller.
        [self.navigationController pushViewController:studyVC animated:YES];
        
    } else if ([currentText isEqualToString:NSLocalizedStringFromTable(@"View Cards", @"CardManagement", @"")]) {
        
        CardListViewController *cardSetViewVC = [[CardListViewController alloc] initWithNibName:@"CardListViewController" bundle:nil];
        cardSetViewVC.cardSet = self.cardSet;
                
        [self.navigationController pushViewController:cardSetViewVC animated:YES];
        
    } else if ([currentText isEqualToString:NSLocalizedStringFromTable(@"Import Cards", @"CardManagement", @"")]) {
        
        if ([cardSet.isSubscribed boolValue]) {
            NSString *service = @"Quizlet";
            FCDisplayBasicErrorMessage(@"",
                                       [NSString stringWithFormat:NSLocalizedStringFromTable(@"You have set this card set to be Subscribed to %@. Any changes made online will be automatically downloaded to your device. Because of this, you cannot edit or import cards to this Card Set.", @"Import", @""), service]);
            return;
        }
        
        CardSetImportChoicesViewController *importVC = [[CardSetImportChoicesViewController alloc] initWithNibName:@"CardSetImportChoicesViewController" bundle:nil];
        importVC.cardSet = self.cardSet;
        importVC.cardSetCreateMode = modeEdit;
        
        // Pass the selected object to the new view controller.
        [self.navigationController pushViewController:importVC animated:YES];
        

    }    
    
}

- (IBAction)createCards:(id)sender {
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
        [action showFromToolbar:bottomBar];
        
    } else {
        [self createSingleCard];
    }
}

- (void)createMultipleCards {
    CardEditMultipleViewController *vc = [[CardEditMultipleViewController alloc] initWithNibName:@"CardEditMultipleViewController" bundle:nil];
    vc.cardSet = self.cardSet;
    vc.collection = nil;
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)createSingleCard {
    CardEditViewController *vc = [[CardEditViewController alloc] initWithNibName:@"CardEditViewController" bundle:nil];
    vc.cardSet = self.cardSet;
    vc.collection = nil;
    vc.editMode = modeCreate;
    vc.popToViewControllerIndex = (int)[[self.navigationController viewControllers] count]-1;
    
    // Pass the selected object to the new view controller.
    [self.navigationController pushViewController:vc animated:YES];
}

- (IBAction)statistics:(id)sender {
    CollectionStatisticsViewController *statsVC = [[CollectionStatisticsViewController alloc] initWithNibName:@"CardSetImportChoicesViewController" bundle:nil];
    statsVC.cardSet = self.cardSet;
    
    // Pass the selected object to the new view controller.
    [self.navigationController pushViewController:statsVC animated:YES];
    
}

# pragma mark -
# pragma mark Sharing functions

- (IBAction)share:(id)sender {
    
    UIActionSheet *popupQuery = [[UIActionSheet alloc] initWithTitle:NSLocalizedStringFromTable(@"Share Cards", @"CardManagement", @"UIAlert title")
                                                            delegate:self
                                                   cancelButtonTitle:NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"")
                                              destructiveButtonTitle:nil
                                                   otherButtonTitles:
                                 NSLocalizedStringFromTable(@"FlashCards++ Format", @"CardManagement", @""),
                                 NSLocalizedStringFromTable(@"CSV File (Excel)", @"CardManagement", @""),
                                 NSLocalizedStringFromTable(@"Upload to Quizlet", @"CardManagement", @""),
                                 nil];
    popupQuery.actionSheetStyle = UIActionSheetStyleBlackOpaque;
    [popupQuery showFromBarButtonItem:sender animated:YES];
}

- (void)actionSheet:(UIActionSheet*)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 0 || buttonIndex == 1) {
        
        if (![FlashCardsCore deviceCanSendEmail]) {
            return;
        }
        
        HUD = [[MBProgressHUD alloc] initWithView:self.view];
        
        // Add HUD to screen
        [self.view addSubview:HUD];
        
        isBuildingExportFile = YES;
        
        // Regisete for HUD callbacks so we can remove it from the window at the right time
        HUD.delegate = self;
        HUD.minShowTime = 2.0;
        HUD.labelText = NSLocalizedStringFromTable(@"Building Export File", @"CardManagement", @"HUD");
        CardSetShareViewController *statsVC = [[CardSetShareViewController alloc] initWithNibName:@"CardSetShareViewController" bundle:nil];
        statsVC.collection = self.cardSet.collection;
        statsVC.cardSet = self.cardSet;
        
        NSString *path;
        if (buttonIndex == 0) {
            // FlashCards++ Format
            savedFileName = @"CardSet.fcpp";
            path = [[FlashCardsCore documentsDirectory] stringByAppendingPathComponent:savedFileName];
            [HUD showWhileExecuting:@selector(buildExportNativeFile:) onTarget:statsVC withObject:path animated:YES];
        } else if (buttonIndex == 1) {
            // CSV Format
            savedFileName = @"CardSet.csv";
            path = [[FlashCardsCore documentsDirectory] stringByAppendingPathComponent:savedFileName];
            [HUD showWhileExecuting:@selector(buildExportCSV:) onTarget:statsVC withObject:path animated:YES];
        }
        
        // [self.navigationController pushViewController:statsVC animated:YES];
    } else if (buttonIndex == 2) {
        if (![FlashCardsCore isConnectedToInternet]) {
            FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"No internet connection", @"Error", @""),
                                       NSLocalizedStringFromTable(@"Try again once you have an internet connection.", @"Error", @""));
            return;
        }
        
        // Quizlet
        CardSetUploadToQuizletViewController *vc = [[CardSetUploadToQuizletViewController alloc] initWithNibName:@"CardSetUploadToQuizletViewController" bundle:nil];
        vc.collection = self.cardSet.collection;
        vc.cardSet = self.cardSet;
        vc.cardsToUpload = [NSMutableArray arrayWithArray:[cardSet allCardsInOrder]];
        [self.navigationController pushViewController:vc animated:YES];
    }
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

    [[NSNotificationCenter defaultCenter]
     removeObserver:self
     name:NSPersistentStoreCoordinatorStoresDidChangeNotification
     object:[[FlashCardsCore mainMOC] persistentStoreCoordinator]];
    
    [super viewDidUnload];
}




@end

