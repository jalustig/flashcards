//
//  QuizletSearchGroupsViewController.m
//  FlashCards
//
//  Created by Jason Lustig on 4/14/11.
//  Copyright 2011-2014 Jason Lustig Lustig. All rights reserved.
//

#import "FlashCardsAppDelegate.h"
#import "FlashCardsCore.h"

#import "QuizletSearchGroupsViewController.h"
#import "QuizletGroupSetsViewController.h"
#import "CardSetImportViewController.h"

#import "NSString+XMLEntities.h"
#import "MBProgressHUD.h"
#import "UIView+Layout.h"
#import "QuizletRestClient+ErrorMessages.h"

#import "QuizletLoginController.h"
#import "FCSetsTableViewController.h"

#import "FCCollection.h"
#import "FCCardSet.h"

@implementation QuizletSearchGroupsViewController

@synthesize dateFormatter, dateStringFormatter;
@synthesize myCardSets, savedSearchTerm, searchIsActive;
@synthesize theSearchBar, loadingCell, loadingCellActivityIndicator;
@synthesize loginToAccessPrivateGroupsButton;
@synthesize currentPageNumber, numberSetsTotal, numberSetsLoaded, isLoadingNextPage, connectionIsLoading, hasStartedSearch;
@synthesize loadingLabel, loadingCancelButton;
@synthesize restClient, HUD, selectedIndexPath;
@synthesize alertedUserFlashcardsServerAPINotAvailable;

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
    
    alertedUserFlashcardsServerAPINotAvailable = NO;
    
    if ([self.importFromWebsite isEqual:@"quizlet"]) {
        restClient = [[QuizletRestClient alloc] init];
    }
    [restClient setDelegate:self];
    
    self.title = NSLocalizedStringFromTable(@"Search Groups", @"Import", @"UIView title");
    
    loadingLabel.text = NSLocalizedStringFromTable(@"Loading...", @"FlashCards", @"UILabel");
    [loadingCancelButton setTitle:NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"UILabel") forState:UIControlStateNormal]; 
    [loadingCancelButton setTitle:NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"UILabel") forState:UIControlStateSelected];
    
    // as per: http://stackoverflow.com/questions/4425692/nsdate-may-not-respond-to-datewithstring/4425715#4425715
    dateStringFormatter = [[NSDateFormatter alloc] init];
    dateStringFormatter.dateFormat = @"yyyy-MM-dd";
    
    myCardSets = [[NSMutableArray alloc] initWithCapacity:0];
    
    hasStartedSearch = NO;
    isLoadingNextPage = NO;
    connectionIsLoading = NO;
    
    // create a single date formatter since this is faster than doing it 
    // every single time in configureCell:
    dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateStyle:NSDateFormatterShortStyle];
    [dateFormatter setTimeStyle:NSDateFormatterNoStyle];
    
    if (self.savedSearchTerm && !self.hasDownloadedFirstTime) {
        [self setHasDownloadedFirstTime:YES];
        [self.theSearchBar setText:savedSearchTerm];
        self.savedSearchTerm = nil;
        [self updateSearch];
    }
    [self setLoginButtonText];
    
}

- (void)viewDidAppear:(BOOL)animated {
    NSIndexPath* selection = [self.myTableView indexPathForSelectedRow];
    if (selection) {
        [self.myTableView deselectRowAtIndexPath:selection animated:YES];
    }
    [super viewDidAppear:animated];
}

- (void)viewDidDisappear:(BOOL)animated {
    self.savedSearchTerm = [self.theSearchBar text];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    // clear out all of the connection variables:
    isLoadingNextPage = NO;
    connectionIsLoading = NO;
    [restClient cancelAllRequests];
}

- (BOOL)shouldAutorotate {
    UIInterfaceOrientation interfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    return [FlashCardsAppDelegate shouldAutorotate:interfaceOrientation];
}

# pragma mark -
# pragma mark Event functions

- (void)setLoginButtonText {
    if ([(NSNumber*)[FlashCardsCore getSetting:@"quizletIsLoggedIn"] boolValue]) {
        NSString *username = (NSString*)[FlashCardsCore getSetting:@"quizletLoginUsername"];
        loginToAccessPrivateGroupsButton.title = [NSString stringWithFormat:NSLocalizedStringFromTable(@"Logout (%@)", @"Import", @"UIBarButtonItem"), username];
    } else {
        loginToAccessPrivateGroupsButton.title = NSLocalizedStringFromTable(@"Login to Access Private Groups", @"Import", @"UIBarButtonItem");
    }
}
- (IBAction)loginButtonPressed:(id)sender {
    if ([(NSNumber*)[FlashCardsCore getSetting:@"quizletIsLoggedIn"] boolValue]) { 
        [FlashCardsCore setSetting:@"quizletIsLoggedIn" value:[NSNumber numberWithBool:NO]];
        [FlashCardsCore setSetting:@"quizletLoginUsername" value:@""];
        [FlashCardsCore setSetting:@"quizletLoginPassword" value:@""];
        [FlashCardsCore setSetting:@"quizletAPI2AccessToken" value:@""];
        [FlashCardsCore setSetting:@"quizletAPI2AccessTokenType" value:@""];
        [myCardSets removeAllObjects];
        [self setLoginButtonText];
        [self updateSearch];
        [self.myTableView reloadData];
    } else {
        self.selectedIndexPath = nil; // this way, we KNOW that we are not accessing a group:
        [FlashCardsCore resetAllRestoreProcessSettings];
        [FlashCardsCore setSetting:@"importProcessRestore" value:@YES];
        if (self.collection != nil) {
            [FlashCardsCore setSetting:@"importProcessRestoreCollectionId" value:[[[self.collection objectID] URIRepresentation] absoluteString]];
        }
        if (self.cardSet != nil) {
            [FlashCardsCore setSetting:@"importProcessRestoreCardsetId" value:[[[self.cardSet objectID] URIRepresentation] absoluteString]];
        }
        [FlashCardsCore setSetting:@"importProcessRestoreSearchTerm" value:self.theSearchBar.text];
        [FlashCardsCore setSetting:@"importProcessRestoreChoiceViewController" value:@"QuizletSearchGroupsViewController"];
        QuizletLoginController *loginController = [QuizletLoginController new];
        loginController.delegate = self;
        [loginController presentFromController:self];
    }
}

# pragma mark -
# pragma mark Data fetching functions

- (IBAction)cancelUpdateSearch:(id)sender {
    connectionIsLoading = NO;
    [loadingCellActivityIndicator stopAnimating];
    [restClient cancelLastRequest];
    
    [self.myTableView reloadData];
}

- (void) updateSearch {
    hasStartedSearch = YES;
    [self updateSearchWithPageNumber:1];
}

- (void) updateSearchWithPageNumber:(int)pageNumber {
    
    connectionIsLoading = YES;
    hasStartedSearch = YES;
    
    NSString *searchText = self.theSearchBar.text;
    
    if ([searchText length] < 2) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Error", @"Error", @"UIAlert title")
                                                         message:NSLocalizedStringFromTable(@"Your search term must be at least two characters in length.", @"Import", @"message")
                                                        delegate:nil
                                               cancelButtonTitle:NSLocalizedStringFromTable(@"OK", @"FlashCards", @"cancelButtonTitle")
                                               otherButtonTitles:nil];
        [alert show];
        return;
    }
    
    [restClient loadSearchGroupsList:searchText withPage:pageNumber];
    
    [self.myTableView reloadData];
}

#pragma mark -
#pragma mark UISearchDisplayController Delegate Methods

- (BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)searchString {
    return NO;
}


- (BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchScope:(NSInteger)searchOption {
    // [self filterContentForSearchText:[self.theSearchBar text] scope:@""];
    return NO;
}

- (void)searchDisplayControllerWillBeginSearch:(UISearchDisplayController *)controller {
    self.searchIsActive = YES;
}

- (void)searchDisplayControllerDidEndSearch:(UISearchDisplayController *)controller {
    self.searchIsActive = NO;
    if ([self.theSearchBar.text length] == 0) {
        //    [myCardSets removeAllObjects];
    }
    [self.myTableView reloadData];
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
    searchBar.showsCancelButton = YES;
}
- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar {
    searchBar.showsCancelButton = NO;
}
- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    [theSearchBar resignFirstResponder];
    searchBar.showsCancelButton = NO;
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    // You'll probably want to do this on another thread
    // SomeService is just a dummy class representing some 
    // api that you are using to do the search
    
    [theSearchBar resignFirstResponder];
    theSearchBar.showsCancelButton = NO;
    [self updateSearch];
    
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    if (connectionIsLoading && !isLoadingNextPage) {
        return 1;
    }    
    if ([myCardSets count] == 0) {
        if (connectionIsLoading || hasStartedSearch) {
            return 1;
        }
        return 0;
    } else if ([self.importFromWebsite isEqual:@"quizlet"]) {
        // determine if we need to show the "Download Next X Sets" button for Quizlet
        if (numberSetsLoaded < numberSetsTotal) {
            return [myCardSets count]+1;
        }
    } else {
        // determine if we need to show the "Download Next X Sets" button for FCE API:
        // If there are 200 sets in each page, then X % 200 == 0 means that we got 200 this time.
        // if we got 200 this time, there may be more.
        if (numberSetsLoaded % 50 == 0) {
            return [myCardSets count]+1;
        }
    }
    if (connectionIsLoading) {
        return [myCardSets count]+1;
    }
    return [myCardSets count];
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat baseHeight = 44;
    if ([myCardSets count] == 0) {
        return baseHeight;
    }
    
    if (indexPath.row < [myCardSets count]) {
        ImportGroup *set = (ImportGroup*)[myCardSets objectAtIndex:indexPath.row];
        if ([set.description length] > 0) {
            int maxLength = 230;
            NSString *description = set.description;
            if ([set.description length] > maxLength) {
                description = [NSString stringWithFormat:@"%@...",
                               [set.description substringToIndex:230]];
            }
            CGSize tallerSize, detailLabelSize;
            // tallerSize = CGSizeMake(tableView.frame.size.width-16.0-(set.isPrivateGroup ? 23 : 0)-23, kMaxFieldHeight);
            // tallerSize = CGSizeMake(230-(set.isPrivateGroup ? 23 : 0), kMaxFieldHeight);
            tallerSize = CGSizeMake(tableView.frame.size.width-120-(set.isPrivateGroup ? 0 : 0), kMaxFieldHeight);
            detailLabelSize = [description sizeWithFont:[UIFont systemFontOfSize:15] constrainedToSize:tallerSize lineBreakMode:NSLineBreakByWordWrapping];
            return 44 + detailLabelSize.height;
        } else {
            return baseHeight;
        }
    } else {
        return baseHeight;
    }
}



// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (connectionIsLoading && (!isLoadingNextPage || indexPath.row >= [myCardSets count])) {
        [loadingCellActivityIndicator startAnimating];
        return loadingCell;
    }
    
    static NSString *CellIdentifier;
    int style;
    if ([myCardSets count] == 0 && hasStartedSearch) {
        style = UITableViewCellStyleDefault;
        CellIdentifier = @"CenterCell";
    }  else if (indexPath.row < [myCardSets count]) {
        style = UITableViewCellStyleSubtitle;
        CellIdentifier = @"Cell";
    } else {
        style = UITableViewCellStyleDefault;
        CellIdentifier = @"CenterCell";
    }
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:style reuseIdentifier:CellIdentifier];
    }
    
    // Configure the cell...
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}


- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    if ([myCardSets count] == 0) {
        if (hasStartedSearch) {
            cell.textLabel.text = NSLocalizedStringFromTable(@"No Results Found", @"Import", @"");
            cell.textLabel.textAlignment = NSTextAlignmentCenter;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }
        return;
    }
    if (indexPath.row < [myCardSets count]) {
        ImportGroup *set = (ImportGroup*)[myCardSets objectAtIndex:indexPath.row];

        int maxLength = 230;
        NSString *description = set.description;
        if ([set.description length] > maxLength) {
            description = [NSString stringWithFormat:@"%@...",
                           [set.description substringToIndex:230]];
        }

        // title is the same for Quizlet & FCE APIs.
        cell.textLabel.text = set.name;
        cell.detailTextLabel.numberOfLines = 0;
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@   %@\n%@",
                                     [NSString stringWithFormat:FCPluralLocalizedStringFromTable(@"%d sets", @"Plural", @"", [NSNumber numberWithInt:[set numberCardSets]]), [set numberCardSets]],
                                     [NSString stringWithFormat:FCPluralLocalizedStringFromTable(@"%d users", @"Plural", @"", [NSNumber numberWithInt:[set numberUsers]]), [set numberUsers]],
                                     description
                                     ];
        [cell setAccessoryType:UITableViewCellAccessoryDetailDisclosureButton];
        
        if (set.isPrivateGroup) {
            [cell.imageView setImage:[UIImage imageNamed:@"54-lock.png"]];
        } else {
            [cell.imageView setImage:nil];
        }

    } else {
        int numNewSets = 50;
        // Quizlet gives us an *exact* number of sets, so we know how many are left to download.
        if ((numberSetsTotal - numberSetsLoaded) < 50) {
            numNewSets = numberSetsTotal - numberSetsLoaded;
        }
        cell.textLabel.text = [NSString stringWithFormat:FCPluralLocalizedStringFromTable(@"Download Next %d Groups", @"Plural", @"", [NSNumber numberWithInt:numNewSets]), numNewSets];
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        [cell.imageView setImage:nil];
        
    }
}



#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    [self tableView:tableView didSelectRowAtIndexPath:indexPath];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    if ([cell isEqual:loadingCell]) {
        return;
    }
    
    if ([myCardSets count] == 0) {
        return;
    }
    
    // If it's the "Download More..." button, then just download it:
    if (indexPath.row == [myCardSets count]) {
        
        if (connectionIsLoading) {
            return;
        }
        
        // make it impossible to hit this cell multiple times.
        [[self.myTableView cellForRowAtIndexPath:indexPath] setSelectionStyle:UITableViewCellSelectionStyleNone];
        
        isLoadingNextPage = YES;
        [self updateSearchWithPageNumber:(currentPageNumber+1)];
        // Unhighlight the load more button after it has been tapped.
        NSIndexPath *selection = [self.myTableView indexPathForSelectedRow];
        if (selection) {
            [self.myTableView deselectRowAtIndexPath:selection animated:YES];
        }
        return;
    }
    
    self.selectedIndexPath = indexPath;
    
    HUD = [[MBProgressHUD alloc] initWithView:self.view];
    [self.view addSubview:HUD];
    
    // Regisete for HUD callbacks so we can remove it from the window at the right time
    HUD.delegate = self;
    HUD.minShowTime = 0.0;
    HUD.labelText = NSLocalizedStringFromTable(@"Downloading Sets", @"Import", @"HUD");
    [HUD show:YES];
    self.navigationItem.leftBarButtonItem.enabled = NO;
    self.navigationItem.rightBarButtonItem.enabled = NO;
    
    self.navigationItem.rightBarButtonItem = nil;
    
    ImportGroup *group = (ImportGroup*)[myCardSets objectAtIndex:indexPath.row];
    [restClient loadGroupCardSetsList:group];
    
    
}


# pragma mark -
# pragma mark FCRestClientDelegate functions


- (void)restClient:(FCRestClient *)client loadSearchGroupsListFailedWithError:(NSError *)error {
    connectionIsLoading = NO;
    
    // hide the progress bars:
    if (self.loadingCellActivityIndicator && self.myTableView) {
        [self.loadingCellActivityIndicator stopAnimating];
        [self.myTableView reloadData];
    }
    
    // inform the user
    NSString *message = [NSString stringWithFormat:NSLocalizedStringFromTable(@"Error: %@ (%d)", @"Error", @"message"),
                         [[error userInfo] objectForKey:@"errorMessage"],
                         [error code]];
    FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"Error", @"Error", @"UIAlert title"), message);
    return;
}

- (void)restClient:(FCRestClient *)client loadedSearchGroupsList:(NSMutableArray *)groups pageNumber:(int)pageNumber numberTotalGroups:(int)numberTotalGroups {
    
    bool wasLoadingNextPage = isLoadingNextPage;
    isLoadingNextPage = NO;
    connectionIsLoading = NO;
    [self.loadingCellActivityIndicator stopAnimating];
    
    currentPageNumber = pageNumber;
    
    // clear out the current list of sets:
    if (!wasLoadingNextPage) {
        // clear out the current sets:
        [myCardSets removeAllObjects];
        // set up the # of sets for paging:
        numberSetsLoaded = (int)[groups count];
        numberSetsTotal  = numberTotalGroups;
    } else {
        numberSetsLoaded += [groups count];
    }
    // filter out any sets that contain images:
    
    [myCardSets addObjectsFromArray:groups];
    
    [self.myTableView reloadData];
    
    if (!wasLoadingNextPage) {
        NSIndexPath *topIndexPath = [NSIndexPath indexPathForRow:0 inSection:0];
        [self.myTableView scrollToRowAtIndexPath:topIndexPath atScrollPosition:UITableViewScrollPositionTop animated:YES];
    }
    
}

# pragma mark -
# pragma mark FCRestClientDelegate functions

- (void)restClient:(FCRestClient*)client genericGroupAccessFailedWithError:(NSError *)error {
    NSIndexPath* selection = [self.myTableView indexPathForSelectedRow];
    if (selection) {
        [self.myTableView deselectRowAtIndexPath:selection animated:YES];
    }
    
    [HUD hide:YES];
    ImportGroup *group = [self.myCardSets objectAtIndex:self.selectedIndexPath.row];
    [restClient genericGroupAccessFailedWithError:error withDelegateView:self withGroup:group];
}

- (void)restClient:(FCRestClient *)client loadGroupCardSetsListFailedWithError:(NSError *)error {
    [self restClient:client genericGroupAccessFailedWithError:error];
}

- (void)restClient:(FCRestClient *)client loadedGroupCardSetsList:(NSMutableArray *)cardSets {
    [HUD hide:YES];
    
    // Navigation logic may go here. Create and push another view controller.
    QuizletGroupSetsViewController *vc = [[QuizletGroupSetsViewController alloc] initWithNibName:@"QuizletGroupSetsViewController" bundle:nil];
    
    // pass the managed object context to the view controller.
    ImportGroup *cardSetData = [myCardSets objectAtIndex:self.selectedIndexPath.row];
    cardSetData.cardSets = [[NSMutableArray alloc] initWithArray:cardSets];
    
    self.selectedIndexPath = nil;
    
    vc.hasDownloadedFirstTime = YES;
    vc.importFromWebsite = self.importFromWebsite;
    vc.cardSet = self.cardSet;
    vc.collection = self.collection;
    vc.group = cardSetData;
    vc.popToViewControllerIndex = self.popToViewControllerIndex;
    vc.cardSetCreateMode = self.cardSetCreateMode;
    [self.navigationController pushViewController:vc animated:YES];
    
}

# pragma mark -
# pragma mark FCRestClientDelegate Functions

- (void)restClient:(FCRestClient *)client joinGroupFailedWithError:(NSError *)error {
    [self restClient:client genericGroupAccessFailedWithError:error];
}

- (void)restClient:(FCRestClient *)client joinedGroup:(ImportGroup *)group withCardSets:(NSMutableArray *)cardSets {
    [self restClient:client loadedGroupCardSetsList:cardSets];
}

- (void)flashcardsServerAPINotAvailable:(FCRestClient *)client {
    alertedUserFlashcardsServerAPINotAvailable = YES;
}

# pragma mark -
# pragma mark QuizletLoginControllerDelegate functions

- (void)loginControllerDidLogin:(QuizletLoginController *)controller {
    [self setLoginButtonText];
    if (self.selectedIndexPath) {
        // if we are trying to access a private set, try to log in again, so 
        // we know whether or not it requires a password or just to ask to join:
        HUD = [[MBProgressHUD alloc] initWithView:self.view];
        [self.view addSubview:HUD];
        
        // Regisete for HUD callbacks so we can remove it from the window at the right time
        HUD.delegate = self;
        HUD.minShowTime = 0.0;
        HUD.labelText = NSLocalizedStringFromTable(@"Downloading Sets", @"Import", @"HUD");
        [HUD show:YES];
        
        ImportGroup *cardSetData = [myCardSets objectAtIndex:self.selectedIndexPath.row];
        [restClient loadGroupCardSetsList:cardSetData];
        
    } else {
        [myCardSets removeAllObjects];
        [self updateSearch];
        [self.myTableView reloadData];
    }
}
- (void)loginControllerDidCancel:(QuizletLoginController*)controller {}


#pragma mark -
#pragma mark MBProgressHUDDelegate methods

- (void)hudWasHidden:(MBProgressHUD *)hud {
    // Remove HUD from screen when the HUD was hidded
    [hud removeFromSuperview];
    hud = nil;
}


#pragma mark -
#pragma mark UIAlertView functions

-(void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex 
{
    if(buttonIndex == 1)
    {
        /*  get the user inputted text  */
        NSString *inputValue = [[alertView textFieldAtIndex:0] text];
        
        HUD = [[MBProgressHUD alloc] initWithView:self.view];
        [self.view addSubview:HUD];
        
        // Regisete for HUD callbacks so we can remove it from the window at the right time
        HUD.delegate = self;
        HUD.minShowTime = 0.0;
        HUD.labelText = NSLocalizedStringFromTable(@"Joining Group", @"Import", @"HUD");
        [HUD show:YES];
        
        ImportGroup *group = [myCardSets objectAtIndex:self.selectedIndexPath.row];
        [restClient joinGroup:group withInput:inputValue];
    }
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
}


- (void)dealloc {
    
    restClient.delegate = nil;
    
    
    
    
    
}


@end
