//
//  QuizletSearchSetsViewController.m
//  FlashCards
//
//  Created by Jason Lustig on 7/27/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import "FlashCardsAppDelegate.h"
#import "FlashCardsCore.h"

#import "QuizletSearchSetsViewController.h"
#import "CardSetImportViewController.h"

#import "NSString+XMLEntities.h"
#import "MBProgressHUD.h"
#import "QuizletRestClient+ErrorMessages.h"
#import "UIView+Layout.h"
#import "UIColor-Expanded.h"

#import "FCSetsTableViewController.h"

#import "DTVersion.h"

@implementation QuizletSearchSetsViewController

@synthesize dateFormatter, dateStringFormatter;
@synthesize myCardSets, savedSearchTerm, savedScopeButtonIndex, searchIsActive;
@synthesize theSearchBar, loadingCell, loadingCellActivityIndicator;
@synthesize currentPageNumber, numberSetsTotal, numberSetsLoaded, isLoadingNextPage, connectionIsLoading, hasStartedSearch;
@synthesize loadingLabel, loadingCancelButton;
@synthesize restClient, HUD, selectedIndexPath;
@synthesize alertedUserFlashcardsServerAPINotAvailable;
@synthesize pseudoEditToolbar, importAllSetsButton, importSelectedSetsButton;


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
    
    if (![DTVersion osVersionIsLessThen:@"7.0"]) {
        self.edgesForExtendedLayout= UIRectEdgeNone;
    }
    
    alertedUserFlashcardsServerAPINotAvailable = NO;
    
    if ([[self importFromWebsite] isEqual:@"quizlet"]) {
        restClient = [[QuizletRestClient alloc] init];
    }
    [restClient setDelegate:self];

    self.title = NSLocalizedStringFromTable(@"Search", @"FlashCards", @"UIView title");
    
    loadingLabel.text = NSLocalizedStringFromTable(@"Loading...", @"FlashCards", @"UILabel");
    [loadingCancelButton setTitle:NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"UILabel") forState:UIControlStateNormal]; 
    [loadingCancelButton setTitle:NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"UILabel") forState:UIControlStateSelected];
    
    
    NSMutableArray *scopeButtons;
    if ([[self importFromWebsite] isEqualToString:@"quizlet"]) {
        scopeButtons = [NSMutableArray arrayWithObjects:
                                    NSLocalizedStringFromTable(@"Studied", @"Import", @"search bar"),
                                    NSLocalizedStringFromTable(@"Recent",  @"Import", @"search bar"),
                                    NSLocalizedStringFromTable(@"A-Z", @"CardManagement", @"search bar"),
                                    NSLocalizedStringFromTable(@"User", @"Import", @"search bar"),
                                    nil];
    } else {
        scopeButtons = [NSMutableArray arrayWithObjects:
                        NSLocalizedStringFromTable(@"Most Studied", @"Import", @"search bar"),
                        NSLocalizedStringFromTable(@"Highest Rated", @"Import", @"search bar"),
                        NSLocalizedStringFromTable(@"Most Recent",  @"Import", @"search bar"),
                        nil];
        // not enough space on the iPhone's screen. But iPad does!
        if ([FlashCardsAppDelegate isIpad]) {
            [scopeButtons addObject:NSLocalizedStringFromTable(@"Best Match", @"Import", @"search bar")];
        }
    }
    [theSearchBar setScopeButtonTitles:scopeButtons];
    
    
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
    
    
    self.pseudoEditToolbar.hidden = YES;
    self.importAllSetsButton.title = NSLocalizedStringFromTable(@"Import All", @"Import", @"");
    self.importSelectedSetsButton.title = NSLocalizedStringFromTable(@"Import Selected", @"Import", @"");

    UIBarButtonItem *pseudoEditModeButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedStringFromTable(@"Import Multiple", @"Import", @"UIBarButtonItem")
                                                                             style:UIBarButtonItemStyleBordered
                                                                            target:self
                                                                            action:@selector(togglePseudoEditMode:)];
    self.navigationItem.rightBarButtonItem = pseudoEditModeButton;
    self.navigationItem.rightBarButtonItem.enabled = NO;
    
    if (self.savedSearchTerm) {
        [self.theSearchBar setSelectedScopeButtonIndex:savedScopeButtonIndex];
        [self.theSearchBar setText:savedSearchTerm];
        self.savedSearchTerm = nil;
        [self updateSearch];
    }
    
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
    
    if ([searchText length] == 0) {
        return;
    }
    if ([searchText length] < 2) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Error", @"Error", @"UIAlert title")
                                                         message:NSLocalizedStringFromTable(@"Your search term must be at least two characters in length.", @"Import", @"message")
                                                        delegate:nil
                                               cancelButtonTitle:NSLocalizedStringFromTable(@"OK", @"FlashCards", @"cancelButtonTitle")
                                               otherButtonTitles:nil];
        [alert show];
        return;
    }
    
    int scope = (int)self.theSearchBar.selectedScopeButtonIndex;
    self.navigationItem.rightBarButtonItem.enabled = NO;
    if (scope < 3) {
        [restClient loadSearchCardSetsList:searchText withPage:pageNumber withScope:scope];
    } else {
        [restClient loadUserCardSetsList:searchText withPage:pageNumber];
    }

    [self.myTableView reloadData];
}

# pragma mark -
# pragma mark PseudoEditMode Methods

-(IBAction)togglePseudoEditMode:(id)sender
{
    self.inPseudoEditMode = !self.inPseudoEditMode;
    pseudoEditToolbar.hidden = !self.inPseudoEditMode;
    if (pseudoEditToolbar.hidden) { // if we hid the toolbar, then incraese the size of the table view
        // we are importing a single set
        self.navigationItem.rightBarButtonItem.style = UIBarButtonItemStyleBordered;
        self.navigationItem.rightBarButtonItem.title = NSLocalizedStringFromTable(@"Import Multiple", @"Import", @"UIBarButtonItem");
        [[self myTableView] setPositionHeight:([self myTableView].frame.size.height+44)];
    } else { // if it is shown, then decrase the height of the table view
        // we are importing multiple sets
        self.navigationItem.rightBarButtonItem.style = UIBarButtonItemStyleDone;
        self.navigationItem.rightBarButtonItem.title = NSLocalizedStringFromTable(@"Import One", @"Import", @"UIBarButtonItem");
        [[self myTableView] setPositionHeight:([self myTableView].frame.size.height-44)];
    }
    
    [self.myTableView reloadData];
    
}

-(IBAction)importAllSets:(id)sender {
    [[self selectedIndexPathsSet] removeAllObjects];
    for (int i = 0; i < [myCardSets count]; i++) {
        [[self selectedIndexPathsSet] addObject:[NSIndexPath indexPathForRow:i inSection:0]];
    }
    [self importSelectedSets:nil];
}
-(IBAction)importSelectedSets:(id)sender {
    NSMutableArray *cardSetIdArray = [NSMutableArray arrayWithCapacity:0];
    ImportSet *cardSetData;
    // if we just go through the selectedIndexPathsSet, it downloads them in the order the user SELECTED THEM.
    // we want to download them in the order they are DISPLAYED:
    NSIndexPath *indexPath;
    for (int i = 0; i < [myCardSets count]; i++) {
        indexPath = [NSIndexPath indexPathForRow:i inSection:0];
        if ([[self selectedIndexPathsSet] containsObject:indexPath]) {
            cardSetData = [myCardSets objectAtIndex:indexPath.row];
            [cardSetIdArray addObject:[NSNumber numberWithInt:cardSetData.cardSetId]];
        }
    }
/*    for (NSIndexPath *indexPath in [selectedIndexPathsSet allObjects]) {
        cardSetData = [myCardSets objectAtIndex:indexPath.row];
        [cardSetIdArray addObject:[NSNumber numberWithInt:cardSetData.cardSetId]];
    }
*/
    
    if ([cardSetIdArray count] == 0) {
        FCDisplayBasicErrorMessage(@"",
                                   NSLocalizedStringFromTable(@"Please select at least one set to import", @"Import", @""));
        return;
    }
    
    HUD = [[MBProgressHUD alloc] initWithView:self.view];
    [self.view addSubview:HUD];
    
    // Regisete for HUD callbacks so we can remove it from the window at the right time
    HUD.delegate = self;
    HUD.minShowTime = 0.0;
    HUD.labelText = NSLocalizedStringFromTable(@"Downloading Cards", @"Import", @"HUD");
    [HUD show:YES];
    self.navigationItem.leftBarButtonItem.enabled = NO;
    self.navigationItem.rightBarButtonItem.enabled = NO;

    [restClient loadMultipleCardSetCards:cardSetIdArray];
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
    searchBar.showsScopeBar = YES;
}
- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar {
    searchBar.showsCancelButton = NO;
    searchBar.showsScopeBar = YES;
}
- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    [theSearchBar resignFirstResponder];
    searchBar.showsCancelButton = NO;
    searchBar.showsScopeBar = YES;
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    // You'll probably want to do this on another thread
    // SomeService is just a dummy class representing some 
    // api that you are using to do the search
    
    [theSearchBar resignFirstResponder];
    theSearchBar.showsScopeBar = YES;
    theSearchBar.showsCancelButton = NO;
    [self updateSearch];
    
}

- (void)searchBar:(UISearchBar *)searchBar selectedScopeButtonIndexDidChange:(NSInteger)selectedScope {
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
    } else if ([[self importFromWebsite] isEqual:@"quizlet"]) {
        // determine if we need to show the "Download Next X Sets" button for Quizlet
        if (numberSetsLoaded < numberSetsTotal) {
            int returnVal = [myCardSets count];
            if (!self.inPseudoEditMode) {
                 // don't display the "Get the next set of cards" button if in pseudo edit mode
                returnVal++;
                return returnVal;
            }
        }
    }
    if (connectionIsLoading) {
        return [myCardSets count]+1;
    }
    return [myCardSets count];
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
        if (self.inPseudoEditMode) {
            CellIdentifier = @"PseudoEditCell";
        } else {
            CellIdentifier = @"Cell";
        }
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


- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (!self.inPseudoEditMode) {
        return;
    }
        
    BOOL selected = [[self selectedIndexPathsSet] containsObject:indexPath];
    if (selected) {
        [cell setBackgroundColor:[FCColor colorWithRGBHex:(0xe6e6e6)]];
    } else {
        [cell setBackgroundColor:[FCColor colorWithRGBHex:(0xffffff)]];
    }
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
        ImportSet *set = (ImportSet*)[myCardSets objectAtIndex:indexPath.row];
        
        // title is the same for Quizlet & FCE APIs.
        cell.textLabel.text = set.name;
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@   %@",
                                     [dateFormatter stringFromDate:set.creationDate],
                                     [NSString stringWithFormat:FCPluralLocalizedStringFromTable(@"%d terms", @"Plural", @"", [NSNumber numberWithInt:[set numberCards]]), [set numberCards]]
                                     ];
        
        if (self.inPseudoEditMode) {
            [cell setAccessoryType:UITableViewCellAccessoryNone];
            
            BOOL selected = [[self selectedIndexPathsSet] containsObject:indexPath];
            if (selected) {
                [cell.imageView setImage:[self selectedImage]];
            } else {
                [cell.imageView setImage:[self unselectedImage]];
            }
        } else {
            [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
            
            UIImageView *imageView = (UIImageView *)[cell.contentView viewWithTag:kCellImageViewTag];
            imageView.image = nil;
            imageView.hidden = YES;
            
            if (set.hasImages) {
                [cell.imageView setImage:[UIImage imageNamed:@"icon-camera.png"]];
            } else {
                [cell.imageView setImage:nil];
            }
        }
    } else {
        int numNewSets = ([[self importFromWebsite] isEqual:@"quizlet"] ? 50 : 20);
        // Quizlet & FCE give us an *exact* number of sets, so we know how many are left to download.
        if ((numberSetsTotal - numberSetsLoaded) < numNewSets) {
            numNewSets = numberSetsTotal - numberSetsLoaded;
        }
        cell.textLabel.text = [NSString stringWithFormat:FCPluralLocalizedStringFromTable(@"Download Next %d Sets", @"Plural", @"", [NSNumber numberWithInt:numNewSets]), numNewSets];
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
    
    // Unhighlight the load more button after it has been tapped.
    NSIndexPath *selection = [self.myTableView indexPathForSelectedRow];
    if (selection) {
        [self.myTableView deselectRowAtIndexPath:selection animated:YES];
    }
    if ([self inPseudoEditMode])
    {
        BOOL selected = [[self selectedIndexPathsSet] containsObject:indexPath];
        if (selected) {
            // it is already in the selected set - remove it
            [[self selectedIndexPathsSet] removeObject:indexPath];
        } else {
            // it is not yet in the selected set - add it
            [[self selectedIndexPathsSet] addObject:indexPath];
        }
        [self.myTableView reloadData];
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
        return;
    }
    
    // download a single set:
    self.selectedIndexPath = indexPath;
    
    HUD = [[MBProgressHUD alloc] initWithView:self.view];
    [self.view addSubview:HUD];
    
    // Regisete for HUD callbacks so we can remove it from the window at the right time
    HUD.delegate = self;
    HUD.minShowTime = 0.0;
    HUD.labelText = NSLocalizedStringFromTable(@"Downloading Cards", @"Import", @"HUD");
    [HUD show:YES];
    self.navigationItem.leftBarButtonItem.enabled = NO;
    self.navigationItem.rightBarButtonItem.enabled = NO;
    
    ImportSet *cardSetData = [myCardSets objectAtIndex:indexPath.row];
    [restClient loadCardSetCards:cardSetData.cardSetId];
    

}

# pragma mark -
# pragma mark FCRestClientDelegate functions

- (void)restClient:(FCRestClient *)client loadUserCardSetsListFailedWithError:(NSError *)error {
    
    connectionIsLoading = NO;
    self.navigationItem.rightBarButtonItem.enabled = YES;
    
    // hide the progress bars:
    if (self.loadingCellActivityIndicator && self.myTableView) {
        [self.loadingCellActivityIndicator stopAnimating];
        [self.myTableView reloadData];
    }
    
    if (error.code == kFCErrorObjectDoesNotExist) {
        FCDisplayBasicErrorMessage(@"", NSLocalizedStringFromTable(@"This user does not exist; make sure you did not misspell the name.", @"Import", @"message"));
    } else {
        NSString *message = [NSString stringWithFormat:NSLocalizedStringFromTable(@"Error: %@ (%d)", @"Error", @"message"),
                             [[error userInfo] objectForKey:@"errorMessage"],
                             [error code]];
        FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"Error", @"Error", @"UIAlert title"),
                                   message);
    }
}

- (void)restClient:(FCRestClient *)client loadedUserCardSetsList:(NSMutableArray *)cardSets pageNumber:(int)pageNumber numberTotalSets:(int)numberTotalSets {
    
    bool wasLoadingNextPage = isLoadingNextPage;
    isLoadingNextPage = NO;
    connectionIsLoading = NO;
    self.navigationItem.rightBarButtonItem.enabled = YES;
    
    // hide the progress bars:
    if (self.loadingCellActivityIndicator && self.myTableView) {
        [self.loadingCellActivityIndicator stopAnimating];
        [self.myTableView reloadData];
    }
    
    currentPageNumber = pageNumber;
    
    // clear out the current list of sets:
    if (!wasLoadingNextPage) {
        // clear out the current sets:
        [myCardSets removeAllObjects];
        [self.selectedIndexPathsSet removeAllObjects];
        // set up the # of sets for paging:
        numberSetsLoaded = [cardSets count];
        numberSetsTotal  = numberTotalSets;
    } else {
        numberSetsLoaded += [cardSets count];
    }
    
    // filter out any sets that contain images:
    [myCardSets addObjectsFromArray:cardSets];
    
    [self.myTableView reloadData];
    
    if (!wasLoadingNextPage) {
        NSIndexPath *topIndexPath = [NSIndexPath indexPathForRow:0 inSection:0];
        [self.myTableView scrollToRowAtIndexPath:topIndexPath atScrollPosition:UITableViewScrollPositionTop animated:YES];
    }
    
}

# pragma mark -
# pragma mark FCRestClientDelegate functions


- (void)restClient:(FCRestClient *)client loadSearchCardSetsListFailedWithError:(NSError *)error {
    
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
    self.navigationItem.rightBarButtonItem.enabled = YES;
    return;
}

- (void)restClient:(FCRestClient *)client loadedSearchCardSetsList:(NSMutableArray *)cardSets pageNumber:(int)pageNumber numberTotalSets:(int)numberTotalSets {

    self.navigationItem.rightBarButtonItem.enabled = YES;
    
    bool wasLoadingNextPage = isLoadingNextPage;
    isLoadingNextPage = NO;
    connectionIsLoading = NO;
    [self.loadingCellActivityIndicator stopAnimating];
    
    currentPageNumber = pageNumber;

    // clear out the current list of sets:
    if (!wasLoadingNextPage) {
        // clear out the current sets:
        [myCardSets removeAllObjects];
        // clear out the list of selected sets
        [[self selectedIndexPathsSet] removeAllObjects];
        // set up the # of sets for paging:
        numberSetsLoaded = [cardSets count];
        numberSetsTotal  = numberTotalSets;
    } else {
        numberSetsLoaded += [cardSets count];
    }
    // filter out any sets that contain images:

    [myCardSets addObjectsFromArray:cardSets];

    [self.myTableView reloadData];

    if (!wasLoadingNextPage) {
        NSIndexPath *topIndexPath = [NSIndexPath indexPathForRow:0 inSection:0];
        [self.myTableView scrollToRowAtIndexPath:topIndexPath atScrollPosition:UITableViewScrollPositionTop animated:YES];
    }
    
}



# pragma mark -
# pragma mark FCRestClientDelegate functions

- (void)restClient:(FCRestClient *)client loadCardSetCardsFailedWithError:(NSError *)error {
    
    NSIndexPath* selection = [self.myTableView indexPathForSelectedRow];
    if (selection) {
        [self.myTableView deselectRowAtIndexPath:selection animated:YES];
    }
    
    [HUD hide:YES];
    if ([restClient respondsToSelector:@selector(genericCardSetAccessFailedWithError:withDelegateView:withCardSet:)]) {
        [(QuizletRestClient*)restClient genericCardSetAccessFailedWithError:error withDelegateView:self withCardSet:nil];
    } else {
        // inform the user
        NSString *message = [NSString stringWithFormat:NSLocalizedStringFromTable(@"Error: %@ (%d)", @"Error", @"message"),
                             [[error userInfo] objectForKey:@"errorMessage"],
                             [error code]];
        FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"Error", @"Error", @"UIAlert title"), message);
    }
    return;
}

- (void)restClient:(FCRestClient *)client loadedCardSetCards:(NSArray *)cards withImages:(BOOL)withImages frontLanguage:(NSString *)frontLanguage backLanguage:(NSString *)backLanguage {
    [HUD hide:YES];
    self.navigationItem.rightBarButtonItem.enabled = YES;

    
    // pass the managed object context to the view controller.
    ImportSet *cardSetData = [myCardSets objectAtIndex:self.selectedIndexPath.row];
    [cardSetData setFlashCards:[[NSMutableArray alloc] initWithArray:cards]];
    cardSetData.hasImages = withImages;
    [cardSetData setFrontLanguage:[FlashCardsCore getLanguageAcronymFor:frontLanguage fromKey:@"quizletAcronym" toKey:@"googleAcronym"]];
    [cardSetData setBackLanguage: [FlashCardsCore getLanguageAcronymFor:backLanguage  fromKey:@"quizletAcronym" toKey:@"googleAcronym"]];

    [self restClient:restClient loadedMultipleCardSetCards:[NSArray arrayWithObjects:cardSetData, nil]];
    
}

- (void)restClient:(FCRestClient*)client loadedMultipleCardSetCards:(NSArray*)cardSets {
    [HUD hide:YES];
    self.navigationItem.rightBarButtonItem.enabled = YES;

    // Navigation logic may go here. Create and push another view controller.
    CardSetImportViewController *vc = [[CardSetImportViewController alloc] initWithNibName:@"CardSetImportViewController" bundle:nil];
    
    vc.shouldImmediatelyImportTerms = NO;
    vc.shouldImmediatelyPressImportButton = NO;
    vc.hasCheckedIfCardSetWithIdExistsOnDevice = NO;
    
    vc.importMethod = self.importFromWebsite;
    vc.importFunction = @"SearchSets";
    [vc setCardSet:self.cardSet];
    [vc setCollection:self.collection];
    vc.allCardSets = [NSMutableArray arrayWithArray:cardSets];
    vc.popToViewControllerIndexSave = self.popToViewControllerIndex;
    vc.popToViewControllerIndexCancel = [self.navigationController.viewControllers count]-1;
    vc.cardSetCreateMode = self.cardSetCreateMode;
    [self.navigationController pushViewController:vc animated:YES];

}
- (void)flashcardsServerAPINotAvailable:(FCRestClient *)client {
    // only show this message once while you are doing this:
    alertedUserFlashcardsServerAPINotAvailable = YES;
}

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
        /*  get the user iputted text  */
        NSString *inputValue = [[alertView textFieldAtIndex:0] text];
        
        HUD = [[MBProgressHUD alloc] initWithView:self.view];
        [self.view addSubview:HUD];
        
        // Regisete for HUD callbacks so we can remove it from the window at the right time
        HUD.delegate = self;
        HUD.minShowTime = 0.0;
        HUD.labelText = NSLocalizedStringFromTable(@"Downloading Cards", @"Import", @"HUD");
        [HUD show:YES];
        self.navigationItem.leftBarButtonItem.enabled = NO;
        self.navigationItem.rightBarButtonItem.enabled = NO;
                
        ImportSet *cardSetData = [myCardSets objectAtIndex:self.selectedIndexPath.row];
        cardSetData.password = inputValue;
        [restClient loadCardSetCards:cardSetData.cardSetId withPassword:inputValue];
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
