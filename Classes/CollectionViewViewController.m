//
//  CollectionViewViewController.m
//  FlashCards
//
//  Created by Jason Lustig on 5/27/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import "CollectionViewViewController.h"
#import "CollectionCreateViewController.h"
#import "CardSetListViewController.h"
#import "CardSetImportChoicesViewController.h"
#import "CardListViewController.h"
#import "StudySettingsViewController.h"
#import "StudyViewController.h"
#import "CollectionStatisticsViewController.h"
#import "CardSetShareViewController.h"
#import "CardEditViewController.h"
#import "CardEditMultipleViewController.h"
#import "CardSetUploadToQuizletViewController.h"
#import "FlashCardsAppDelegate.h"

#import "FCCard.h"
#import "FCCardSet.h"
#import "FCCollection.h"

#import "FCMatrix.h"

#import "UIActionSheet+Blocks.h"

@implementation CollectionViewViewController


#pragma mark -
#pragma mark View lifecycle

@synthesize tableListGroups, myTableView;
@synthesize collection, cardsDue, cardsLapsed;
@synthesize fetchedResultsController;
@synthesize HUD, savedFileName;
@synthesize isBuildingExportFile;
@synthesize createCardsButton, createCardsButton2;
@synthesize statisticsButton, shareButton;
@synthesize tableFooterUpload;
@synthesize syncsWithLabel, viewOnWebsiteButton, tableFooterSync;
@synthesize quizletImage;
@synthesize shouldSync;
@synthesize bottomBar;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [createCardsButton setTitle:NSLocalizedStringFromTable(@"Create Cards", @"CardManagement", @"UIBarButtonTitle") forState:UIControlStateNormal];
    [createCardsButton setTitle:NSLocalizedStringFromTable(@"Create Cards", @"CardManagement", @"UIBarButtonTitle") forState:UIControlStateSelected];
    
    [createCardsButton2 setTitle:NSLocalizedStringFromTable(@"Create Cards", @"CardManagement", @"UIBarButtonTitle") forState:UIControlStateNormal];
    [createCardsButton2 setTitle:NSLocalizedStringFromTable(@"Create Cards", @"CardManagement", @"UIBarButtonTitle") forState:UIControlStateSelected];
    
    statisticsButton.title = NSLocalizedStringFromTable(@"Statistics", @"CardManagement", @"UIBarButtonTitle");
    shareButton.title = NSLocalizedStringFromTable(@"Export", @"CardManagement", @"UIBarButtonTitle");
    
    UIDevice* device = [UIDevice currentDevice];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateCardsDueCount) name:UIApplicationWillEnterForegroundNotification object:NULL];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateCardsDueCount) name:UIApplicationDidBecomeActiveNotification  object:NULL];

    NSMutableArray *rightBarButtonItems = [[NSMutableArray alloc] initWithCapacity:0];
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
    
    tableListGroups = [[NSMutableArray alloc] initWithCapacity:0];

    NSMutableArray *tableListOptions;
    
    // Group 1: Learn Cards
    // Group 2: Card sets
    
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
    [tableListOptions addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                 NSLocalizedStringFromTable(@"Study Lapsed Cards", @"CardManagement", @""), @"text",
                                 @"Lapsed.png", @"image",
                                 nil]];
    [tableListGroups addObject:tableListOptions];
    
    tableListOptions = [[NSMutableArray alloc] initWithCapacity:0];
    [tableListOptions addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                 NSLocalizedStringFromTable(@"View All Cards", @"CardManagement", @""), @"text",
                                 @"AllCards.png", @"image",
                                 nil]];
    [tableListOptions addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                 NSLocalizedStringFromTable(@"View Card Sets", @"CardManagement", @""), @"text",
                                 @"Cardset.png", @"image",
                                 nil]];
    [tableListOptions addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                 NSLocalizedStringFromTable(@"Import Cards", @"CardManagement", @""), @"text",
                                 @"Import.png", @"image",
                                 nil]];
    [tableListGroups addObject:tableListOptions];

    isBuildingExportFile = NO;
    
    [self.myTableView reloadData];
}

-(void) editEvent {
    CollectionCreateViewController *collectionEdit = [[CollectionCreateViewController alloc] initWithNibName:@"CollectionCreateViewController" bundle:nil];
    collectionEdit.collection = self.collection;
    collectionEdit.editMode = modeEdit;
    
    // Pass the selected object to the new view controller.
    [self.navigationController pushViewController:collectionEdit animated:YES];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    self.title = collection.name;
    
    [self updateCardsDueCount];
    [self updateTableFooter];
    
}

- (void) updateTableFooter {
    BOOL _shouldSync = NO;
    BOOL isFCE = NO;
    quizletImage.hidden = YES;
    
    if ([collection.masterCardSet isQuizletSet]) {
        [viewOnWebsiteButton setTitle:NSLocalizedStringFromTable(@"Open on Quizlet", @"CardManagement", @"UILabel") forState:UIControlStateNormal];
        [viewOnWebsiteButton setTitle:NSLocalizedStringFromTable(@"Open on Quizlet", @"CardManagement", @"UILabel") forState:UIControlStateSelected];
    }

    if ([collection shouldSync]) {
        if ([collection.masterCardSet isFlashcardExchangeSet]) {
            isFCE = YES;
        } else if ([collection.masterCardSet isQuizletSet]) {
            if ([QuizletRestClient isLoggedIn]) {
                _shouldSync = YES;
            }
            quizletImage.hidden = NO;
        }
    }
    if (_shouldSync) {
        self.myTableView.tableFooterView = tableFooterSync;
        [syncsWithLabel setText:NSLocalizedStringFromTable(@"Syncs With:", @"CardManagement", @"")];
        
    } else {
        self.myTableView.tableFooterView = tableFooterUpload;
        [tableFooterUpload setHidden:NO];
    }
    if ([self.myTableView.tableFooterView isEqual:tableFooterSync]) {
        [tableFooterSync setHidden:NO];
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
    
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"isDeletedObject = NO and collection = %@ and isSpacedRepetition = YES and nextRepetitionDate <= %@", collection, [NSDate date]]];
    // TODO: Handle the error
    cardsDue = [[FlashCardsCore mainMOC] countForFetchRequest:fetchRequest error:&error];

    
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"isDeletedObject = NO and collection = %@ and isLapsed = YES", collection]];
    // TODO: Handle the error
    cardsLapsed = [[FlashCardsCore mainMOC] countForFetchRequest:fetchRequest error:&error];
    
    // [entity release];

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

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *cellOptions = [[tableListGroups objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
    cell.textLabel.text = [cellOptions valueForKey:@"text"];
    cell.textLabel.adjustsFontSizeToFitWidth = YES;
    [cell.imageView setImage:[UIImage imageNamed:[cellOptions valueForKey:@"image"]]];
    
    if ([cell.textLabel.text isEqual:NSLocalizedStringFromTable(@"Review", @"CardManagement", @"")]) {
        if (cardsDue > 0) {
            cell.detailTextLabel.text = [NSString stringWithFormat:FCPluralLocalizedStringFromTable(@"%d cards due", @"Plural", @"", [NSNumber numberWithInt:cardsDue]), cardsDue];
        } else {
            cell.detailTextLabel.text = NSLocalizedStringFromTable(@"(Spaced Repetition)", @"CardManagement", @"");
        }
    } else if ([cell.textLabel.text isEqual:NSLocalizedStringFromTable(@"Study Lapsed Cards", @"CardManagement", @"")] && cardsLapsed > 0) {
        cell.detailTextLabel.text = [NSString stringWithFormat:FCPluralLocalizedStringFromTable(@"%d cards lapsed", @"Plural", @"", [NSNumber numberWithInt:cardsLapsed]), cardsLapsed];
    } else {
        cell.detailTextLabel.text = @"";
        [cell setBackgroundColor:[UIColor whiteColor]];
    }
}

- (IBAction)viewOnWebsite:(id)sender {
    [collection.masterCardSet openWebsite];
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
        isBuildingExportFile = NO;
        CardSetShareViewController *statsVC = [[CardSetShareViewController alloc] initWithNibName:@"CardSetShareViewController" bundle:nil];
        statsVC.collection = self.collection;
        statsVC.fileName = savedFileName;
        
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

#pragma mark - TICoreDataSync methods

- (void)syncDidFinish:(SyncController *)sync {
    [self persistentStoresDidChange];
}
- (void)syncDidFinish:(SyncController *)sync withError:(NSError *)error {
    [self persistentStoresDidChange];
}

- (void)persistentStoresDidChange {
    self.title = self.collection.name;
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
    if (cell.detailTextLabel.text.length > 0 && ![cell.detailTextLabel.text isEqualToString:NSLocalizedStringFromTable(@"(Spaced Repetition)", @"CardManagement", @"")]) {
        [cell setBackgroundColor:[UIColor yellowColor]];
    } else {
        [cell setBackgroundColor:[UIColor whiteColor]];
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
    
    [self configureCell:cell atIndexPath:indexPath];
    
    return cell;
}


// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return NO;
}


#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

    NSString *currentText = [[[tableListGroups objectAtIndex:indexPath.section] objectAtIndex:indexPath.row] valueForKey:@"text"];
    
    NSIndexPath *selection = [self.myTableView indexPathForSelectedRow];
    if (selection) {
        [self.myTableView deselectRowAtIndexPath:selection animated:YES];
    }
    
    if ([currentText isEqualToString:NSLocalizedStringFromTable(@"View Card Sets", @"CardManagement", @"")]) {

        CardSetListViewController *cardSetList = [[CardSetListViewController alloc] initWithNibName:@"CardSetListViewController" bundle:nil];
        cardSetList.collection = self.collection;
        cardSetList.collectionCardsDueCount = self.cardsDue;
        
        // Pass the selected object to the new view controller.
        [self.navigationController pushViewController:cardSetList animated:YES];

        
    } else if ([currentText isEqualToString:NSLocalizedStringFromTable(@"View All Cards", @"CardManagement", @"")]) {
        CardListViewController *listVC = [[CardListViewController alloc] initWithNibName:@"CardListViewController" bundle:nil];
        listVC.collection = self.collection;
        // Pass the selected object to the new view controller.
        [self.navigationController pushViewController:listVC animated:YES];
        
    } else if ([currentText isEqualToString:NSLocalizedStringFromTable(@"Learn Cards", @"CardManagement", @"")] ||
               [currentText isEqualToString:NSLocalizedStringFromTable(@"Study Lapsed Cards", @"CardManagement", @"")]) {
        
        if (![FlashCardsCore canStudyCardsWithUnlimitedCards]) {
            return;
        }
        
        StudySettingsViewController *studyVC = [[StudySettingsViewController alloc] initWithNibName:@"StudySettingsViewController" bundle:nil];
        studyVC.collection = collection;
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
        // pass the managed object context to the view controller.
        studyVC.collection = self.collection;
        studyVC.cardSet = nil;
        studyVC.studyingImportedSet = NO;
        
        studyVC.popToViewControllerIndex = (int)[[self.navigationController viewControllers] count]-1; // pop to this view controller
        
        // study options:
        if ([currentText isEqualToString:NSLocalizedStringFromTable(@"Test Cards", @"CardManagement", @"")]) {
            studyVC.studyController.studyAlgorithm = studyAlgorithmTest;
        } else {
            studyVC.studyController.studyAlgorithm = studyAlgorithmRepetition;
        }
        studyVC.studyController.studyOrder = studyOrderRandom;
        studyVC.studyController.showFirstSide = [[collection defaultFirstSide] intValue]; // get the default from the collection settings.
        
        // Pass the selected object to the new view controller.
        [self.navigationController pushViewController:studyVC animated:YES];
    } else if ([currentText isEqualToString:NSLocalizedStringFromTable(@"Import Cards", @"CardManagement", @"")]) {
        
        CardSetImportChoicesViewController *importVC = [[CardSetImportChoicesViewController alloc] initWithNibName:@"CardSetImportChoicesViewController" bundle:nil];
        importVC.cardSetCreateMode = modeCreate;
        importVC.collection = collection;
        
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
    vc.cardSet = nil;
    vc.collection = self.collection;
    if ([self.collection cardSetsCount] == 1) {
        FCCardSet *cardSetToAdd = [[[collection allCardSets] allObjects] objectAtIndex:0];
        vc.cardSet = cardSetToAdd;
    }
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)createSingleCard {
    CardEditViewController *vc = [[CardEditViewController alloc] initWithNibName:@"CardEditViewController" bundle:nil];
    vc.cardSet = nil;
    vc.collection = self.collection;
    vc.editMode = modeCreate;
    vc.popToViewControllerIndex = (int)[[self.navigationController viewControllers] count]-1;
    // Pass the selected object to the new view controller.
    [self.navigationController pushViewController:vc animated:YES];

}

- (IBAction)statistics:(id)sender {
    CollectionStatisticsViewController *statsVC = [[CollectionStatisticsViewController alloc] initWithNibName:@"CollectionStatisticsViewController" bundle:nil];
    statsVC.collection = self.collection;
    
    // Pass the selected object to the new view controller.
    [self.navigationController pushViewController:statsVC animated:YES];
    
}

# pragma mark -
# pragma mark UIActionSheet methods

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
        
        // Regisete for HUD callbacks so we can remove it from the window at the right time
        HUD.delegate = self;
        HUD.minShowTime = 2.0;
        HUD.labelText = NSLocalizedStringFromTable(@"Building Export File", @"CardManagement", @"HUD");
        CardSetShareViewController *statsVC = [[CardSetShareViewController alloc] initWithNibName:@"CardSetShareViewController" bundle:nil];
        statsVC.collection = self.collection;
        
        NSString *path;
        isBuildingExportFile = YES;
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
        vc.collection = collection;
        vc.cardsToUpload = [NSMutableArray arrayWithArray:[collection.masterCardSet allCardsInOrder]];
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

