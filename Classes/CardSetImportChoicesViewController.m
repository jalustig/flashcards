//
//  CardSetImportChoicesViewController.m
//  FlashCards
//
//  Created by Jason Lustig on 6/3/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import "FlashCardsAppDelegate.h"
#import "FlashCardsCore.h"

#import "RootViewController.h"
#import "CardSetImportChoicesViewController.h"
#import "CardSetImportViewController.h"
#import "QuizletBrowseViewController.h"
#import "QuizletSearchSetsViewController.h"
#import "QuizletMySetsViewController.h"
#import "QuizletMyGroupsViewController.h"
#import "QuizletSearchGroupsViewController.h"
#import "QuizletLoginController.h"
#import "DropboxCSVFilePicker.h"
#import "FCSetsTableViewController.h"

#import "MergeCollectionsViewController.h"

#import "FCCardSet.h"
#import "FCCollection.h"

@implementation CardSetImportChoicesViewController

@synthesize cardSet, collection, cardSetCreateMode, quizletLoginControllerChoice;
@synthesize tableListOptions;

#pragma mark -
#pragma mark View lifecycle


- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = NSLocalizedStringFromTable(@"Import", @"Import", @"UIView Title");
    
    [Flurry logEvent:@"Import/Choices"];
    
    tableListOptions = [[NSMutableArray alloc] initWithCapacity:1];
    [tableListOptions addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
                                 @"Quizlet", @"title",
                                 [NSArray arrayWithObjects:
                                  NSLocalizedStringFromTable(@"My Quizlet Sets", @"Import", @""),
                                  NSLocalizedStringFromTable(@"My Quizlet Groups", @"Import", @""),
                                  NSLocalizedStringFromTable(@"Browse Quizlet Sets", @"Import", @""),
                                  NSLocalizedStringFromTable(@"Search Quizlet Sets", @"Import", @""), 
                                  NSLocalizedStringFromTable(@"Search Quizlet Groups", @"Import", @""), 
                                  nil], @"cells", nil
                                 ]];
    [tableListOptions addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
                                 NSLocalizedStringFromTable(@"Excel or CSV (Spreadsheet) Files", @"Import", @""), @"title",
                                 [NSArray arrayWithObjects:NSLocalizedStringFromTable(@"Hosted on Dropbox", @"Import", @""), nil], @"cells", nil
                                 ]];
    
    // we will show this as an option whether or not we are in a set or collection.
    // if we are in the first level (List all Collections screen), should pop up a message
    // to say that they need to import somewhere.
    // if we are in the third level (View Card Set screen), will import the cards to the collection
    // and also mark them as part of the set. Will also give the option, then, to import from other sets - to merge them!
    NSMutableArray *mergeArray = [NSMutableArray arrayWithCapacity:0];
    [mergeArray addObject:NSLocalizedStringFromTable(@"FlashCards++ Sets", @"Import", @"")];
    if (!self.cardSet) {
        // thus this will be shown in both the case when we are telling them how to do it,
        // and when merging into a collection - but not when merging into a set.
        [mergeArray addObject:NSLocalizedStringFromTable(@"FlashCards++ Collections", @"Import", @"")];
    }
    [tableListOptions addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
                                 NSLocalizedStringFromTable(@"FlashCards++ (Merge Sets)", @"FlashCards", @""), @"title",
                                 mergeArray, @"cells", nil
                                 ]];
}


- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    if (![FlashCardsCore hasFeature:@"UnlimitedCards"]) {
        [FlashCardsCore checkUnlimitedCards];
    }
}

- (BOOL)shouldAutorotate {
    UIInterfaceOrientation interfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    return [FlashCardsAppDelegate shouldAutorotate:interfaceOrientation];
}

#pragma mark -
#pragma mark Table view data source


- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSMutableDictionary *sectionInfo = [tableListOptions objectAtIndex:section];
    return [sectionInfo valueForKey:@"title"];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return [tableListOptions count];
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    return [[[tableListOptions objectAtIndex:section] valueForKey:@"cells"] count];
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    
    // Configure the cell...
    [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
    cell.textLabel.text = [[[tableListOptions objectAtIndex:indexPath.section] valueForKey:@"cells"] objectAtIndex:indexPath.row];
    return cell;
}


/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/


/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:YES];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/


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


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    /*
     
     View controller stack:
     
     0) Collections
     1) CollectionsView
     2) CardSetList
     3) CardSetView
     4) CardSetImportChoice
     5) CardSetImport
     
     */
    
    // When done with the import process, always pop back to one view above the import choice controller:
    int pop = [[self.navigationController viewControllers] count] - 2;
    
    // we will let them pass if they are trying to merge FlashCards++ sets
    // (this is available offline!)
    if (indexPath.section != 3) {
        if (![FlashCardsCore isConnectedToInternet]) {
            [tableView deselectRowAtIndexPath:indexPath animated:YES];
            FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"No internet connection", @"Error", @""),
                                       NSLocalizedStringFromTable(@"Try again once you have an internet connection.", @"Error", @""));
            return;
        }
    }
    
    
    NSString *currentText = [[[tableListOptions objectAtIndex:indexPath.section] valueForKey:@"cells"] objectAtIndex:indexPath.row];
    
    if ([currentText isEqual:NSLocalizedStringFromTable(@"Hosted on Dropbox", @"Import", @"")]) {
        [Flurry logEvent:@"Import"
          withParameters:@{@"method" : @"Dropbox", @"view" : @"FilePicker"}];
        
        DropboxCSVFilePicker *importVC = [[DropboxCSVFilePicker alloc] initWithNibName:@"DropboxCSVFilePicker" bundle:nil];
        importVC.cardSet = self.cardSet;
        importVC.popToViewControllerIndex = pop;
        importVC.cardSetCreateMode = cardSetCreateMode;
        importVC.collection = collection;
        
        // Pass the selected object to the new view controller.
        [self.navigationController pushViewController:importVC animated:YES];
        
    } else if (indexPath.section == 2) {
        if (!self.collection && !self.cardSet) {
            [tableView deselectRowAtIndexPath:indexPath animated:YES];
            FCDisplayBasicErrorMessage(@"",
                                       NSLocalizedStringFromTable(@"To merge card sets or collections, first go to that card set or collection, and then return to the import screen. Otherwise, Flashcards++ will not know where you want the cards to be moved to.", @"CardManagement", @""));
            return;
        }
        // we are merging the FlashCards++ cards
        if (indexPath.row == 0) {
            // sets
            MergeCollectionsViewController *vc = [[MergeCollectionsViewController alloc] initWithNibName:@"MergeCollectionsViewController" bundle:nil];
            if (self.cardSet) {
                vc.destinationCollection = self.cardSet.collection;
            } else {
                vc.destinationCollection = self.collection;
            }
            vc.destinationCardSet = self.cardSet;
            vc.isMergingCollections = NO;
            [self.navigationController pushViewController:vc animated:YES];
        } else {
            // collections
            MergeCollectionsViewController *vc = [[MergeCollectionsViewController alloc] initWithNibName:@"MergeCollectionsViewController" bundle:nil];
            vc.destinationCollection = self.collection;
            vc.isMergingCollections = YES;
            [self.navigationController pushViewController:vc animated:YES];
        }
    } else {
        FCSetsTableViewController *vc;
        switch (indexPath.section) {
            default:
            case 0:
                switch (indexPath.row) {
                    default:
                    case 0: // my sets
                        [Flurry logEvent:@"Import"
                          withParameters:@{@"method" : @"quizlet", @"view" : @"MySets"}];
                        
                        if ([(NSNumber*)[FlashCardsCore getSetting:@"quizletIsLoggedIn"] boolValue]) {
                            vc = [[QuizletMySetsViewController alloc] initWithNibName:@"QuizletMySetsViewController" bundle:nil];
                        } else {
                            quizletLoginControllerChoice = 0;
                            [FlashCardsCore saveImportProcessRestoreDataWithVCChoice:@"QuizletMySetsViewController" andCollection:self.collection andCardSet:self.cardSet];
                            // show the quizlet login controller:
                            QuizletLoginController *loginController = [QuizletLoginController new];
                            loginController.delegate = self;
                            [loginController presentFromController:self];
                            return;
                        }
                        break;
                    case 1: // my groups
                        [Flurry logEvent:@"Import"
                          withParameters:@{@"method" : @"quizlet", @"view" : @"MyGroups"}];

                        if ([(NSNumber*)[FlashCardsCore getSetting:@"quizletIsLoggedIn"] boolValue]) {
                            vc = [[QuizletMyGroupsViewController alloc] initWithNibName:@"QuizletMyGroupsViewController" bundle:nil];
                        } else {
                            quizletLoginControllerChoice = 1;
                            [FlashCardsCore saveImportProcessRestoreDataWithVCChoice:@"QuizletMyGroupsViewController" andCollection:self.collection andCardSet:self.cardSet];
                            // show the Quizlet login controller:
                            QuizletLoginController *loginController = [QuizletLoginController new];
                            loginController.delegate = self;
                            [loginController presentFromController:self];
                            return;
                        }
                        break;
                    case 2: // browse
                        [Flurry logEvent:@"Import"
                          withParameters:@{@"method" : @"quizlet", @"view" : @"Browse"}];
                        vc = [[QuizletBrowseViewController alloc] initWithNibName:@"QuizletBrowseViewController" bundle:nil];
                        break;
                    case 3: // search
                        [Flurry logEvent:@"Import"
                          withParameters:@{@"method" : @"quizlet", @"view" : @"SearchSets"}];
                        vc = [[QuizletSearchSetsViewController alloc] initWithNibName:@"QuizletSearchSetsViewController" bundle:nil];
                        break;
                    case 4: // search groups
                        [Flurry logEvent:@"Import"
                          withParameters:@{@"method" : @"quizlet", @"view" : @"SearchGroups"}];
                        vc = [[QuizletSearchGroupsViewController alloc] initWithNibName:@"QuizletSearchGroupsViewController" bundle:nil];
                        break;
                }

                break;
        }
        [vc setHasDownloadedFirstTime:NO];
        [vc setImportFromWebsite:@"quizlet"];
        [vc setPopToViewControllerIndex:pop];
        [vc setCardSetCreateMode:cardSetCreateMode];
        [vc setCollection:collection];
        [vc setCardSet:self.cardSet];
        
        // Pass the selected object to the new view controller.
        [self.navigationController pushViewController:vc animated:YES];
        
    }
    
    return;
    
}

# pragma mark -
# pragma mark QuizletLoginControllerDelegate functions

- (void)loginControllerDidLogin:(QuizletLoginController *)controller {
    int pop = [[self.navigationController viewControllers] count] - 2;
    FCSetsTableViewController *vc;
    switch (quizletLoginControllerChoice) {
        default:
        case 0: // my sets
            vc = [[QuizletMySetsViewController alloc] initWithNibName:@"QuizletMySetsViewController" bundle:nil];
            break;
        case 1: // my groups
            vc = [[QuizletMyGroupsViewController alloc] initWithNibName:@"QuizletMyGroupsViewController" bundle:nil];
            break;
    }
    [vc setImportFromWebsite:@"quizlet"];
    [vc setPopToViewControllerIndex:pop];
    [vc setCardSetCreateMode:cardSetCreateMode];
    [vc setCollection:collection];
    [vc setCardSet:self.cardSet];

    // [FlashCardsCore setSetting:@"quizletUsername" value:controller.usernameField.text];
    
    // Pass the selected object to the new view controller.
    [self.navigationController pushViewController:vc animated:YES];
    
}
- (void)loginControllerDidCancel:(QuizletLoginController*)controller {
    [self dismissViewControllerAnimated:YES completion:nil];
    [self loginControllerDidLogin:controller];
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

