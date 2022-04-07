//
//  QuizletMySetsViewController.m
//  FlashCards
//
//  Created by Jason Lustig on 7/27/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import "FlashCardsAppDelegate.h"
#import "FlashCardsCore.h"

#import "QuizletMySetsViewController.h"
#import "CardSetImportViewController.h"

#import "MBProgressHUD.h"
#import "UIView+Layout.h"

#import "QuizletLoginController.h"
#import "QuizletRestClient+ErrorMessages.h"
#import "FCSetsTableViewController.h"
#import "UIColor-Expanded.h"

#import "FCCollection.h"
#import "FCCardSet.h"

#import "DTVersion.h"

@implementation QuizletMySetsViewController

@synthesize quizletUsernameField, myCardSets;
@synthesize loadingCell, loadingCellActivityIndicator, loginToAccessPrivateCardSetsButton, loginNavigationBar;
@synthesize dateFormatter;
@synthesize connectionIsLoading;
@synthesize currentPageNumber, numberSetsTotal, numberSetsLoaded, isLoadingNextPage;
@synthesize hasStartedSearch;
@synthesize loadingLabel, loadingCancelButton;
@synthesize dateStringFormatter;
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

    restClient = [[QuizletRestClient alloc] init];
    [restClient setDelegate:self];
    
    self.title = NSLocalizedStringFromTable(@"My Sets", @"Import", @"UIView title");

    quizletUsernameField.placeholder = NSLocalizedStringFromTable(@"Your Quizlet Username", @"Import", @"quizlet username field placeholder");
    
    [self setLoginButtonText];
    
    loadingLabel.text = NSLocalizedStringFromTable(@"Loading...", @"FlashCards", @"UILabel");
    [loadingCancelButton setTitle:NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"UILabel") forState:UIControlStateNormal]; 
    [loadingCancelButton setTitle:NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"UILabel") forState:UIControlStateSelected];
    
    hasStartedSearch = NO;
    isLoadingNextPage = NO;
    connectionIsLoading = NO;
    
    // as per: http://stackoverflow.com/questions/4425692/nsdate-may-not-respond-to-datewithstring/4425715#4425715
    dateStringFormatter = [[NSDateFormatter alloc] init];
    dateStringFormatter.dateFormat = @"yyyy-MM-dd";
    
    myCardSets = [[NSMutableArray alloc] initWithCapacity:0];
    
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
    
    quizletUsernameField.text = (NSString*)[FlashCardsCore getSetting:@"quizletUsername"];
    if ([quizletUsernameField.text length] == 0) {
        [quizletUsernameField becomeFirstResponder];
    } else if (![self hasDownloadedFirstTime]) {
        [self setHasDownloadedFirstTime:YES];
        [self loadCardSets];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    NSIndexPath* selection = [self.myTableView indexPathForSelectedRow];
    if (selection) {
        [self.myTableView deselectRowAtIndexPath:selection animated:YES];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    // clear out all of the connection variables:
    isLoadingNextPage = NO;
    connectionIsLoading = NO;
    [restClient cancelAllRequests];
    [super viewWillDisappear:animated];
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
        loginToAccessPrivateCardSetsButton.title = [NSString stringWithFormat:NSLocalizedStringFromTable(@"Logout (%@)", @"Import", @"UIBarButtonItem"), username];
    } else {
        loginToAccessPrivateCardSetsButton.title = NSLocalizedStringFromTable(@"Login to Access Private Card Sets", @"Import", @"UIBarButtonItem");
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
        [self loadCardSets];
        [self.myTableView reloadData];
    } else {
        [FlashCardsCore resetAllRestoreProcessSettings];
        [FlashCardsCore setSetting:@"importProcessRestore" value:@YES];
        if (self.collection != nil) {
            [FlashCardsCore setSetting:@"importProcessRestoreCollectionId" value:[[[self.collection objectID] URIRepresentation] absoluteString]];
        }
        if (self.cardSet != nil) {
            [FlashCardsCore setSetting:@"importProcessRestoreCardsetId" value:[[[self.cardSet objectID] URIRepresentation] absoluteString]];
        }
        [FlashCardsCore setSetting:@"importProcessRestoreChoiceViewController" value:@"QuizletMySetsViewController"];
        QuizletLoginController *loginController = [QuizletLoginController new];
        loginController.delegate = self;
        [loginController presentFromController:self];
    }
}

- (IBAction)refreshDataAndSaveUsername:(id)sender {
    // NSLog(@"REFRESH");
    [quizletUsernameField resignFirstResponder];
    if (quizletUsernameField.text.length > 0) {
        [FlashCardsCore setSetting:@"quizletUsername" value:quizletUsernameField.text];
    }
    
    [self loadCardSets];
}

- (IBAction)cancelRefreshData:(id)sender {
    connectionIsLoading = NO;
    [loadingCellActivityIndicator stopAnimating];
    [restClient cancelLastRequest];
    
    [self.myTableView reloadData];
}

- (IBAction)didEndEditingQuizletUsernameField:(id)sender {
    // NSLog(@"didEndEditingQuizletUsernameField");
    if ([quizletUsernameField.text length] == 0) {
        return;
    }
    [self refreshDataAndSaveUsername:nil];
}

- (void) loadCardSets {
    [self loadCardSetsWithPageNumber:1];
}

- (void) loadCardSetsWithPageNumber:(int)pageNumber {
    
    connectionIsLoading = YES;
    hasStartedSearch = YES;
    
    NSString *searchText = quizletUsernameField.text;
    
    if ([searchText length] < 2) {
        FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"Error", @"Error", @"UIAlert title"),
                                   NSLocalizedStringFromTable(@"Your username must be at least two characters in length.", @"Import", @"message"));
        return;
    }
    
    [restClient loadUserCardSetsList:searchText withPage:pageNumber];

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
        //[myTableView setPositionHeight:(myTableView.frame.size.height+44)];
    } else { // if it is shown, then decrase the height of the table view
        // we are importing multiple sets
        self.navigationItem.rightBarButtonItem.style = UIBarButtonItemStyleDone;
        self.navigationItem.rightBarButtonItem.title = NSLocalizedStringFromTable(@"Import One", @"Import", @"UIBarButtonItem");
        //[myTableView setPositionHeight:(myTableView.frame.size.height-44)];
    }
    
    [self.myTableView reloadData];
    
}

-(IBAction)importAllSets:(id)sender {
    [self.selectedIndexPathsSet removeAllObjects];
    for (int i = 0; i < [myCardSets count]; i++) {
        [self.selectedIndexPathsSet addObject:[NSIndexPath indexPathForRow:i inSection:0]];
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
        if ([self.selectedIndexPathsSet containsObject:indexPath]) {
            cardSetData = [myCardSets objectAtIndex:indexPath.row];
            [cardSetIdArray addObject:[NSNumber numberWithInt:cardSetData.cardSetId]];
        }
    }
    
    if ([cardSetIdArray count] == 0) {
        FCDisplayBasicErrorMessage(@"",
                                   NSLocalizedStringFromTable(@"Please select at least one set to import", @"Import", @""));
        return;
    }
    
    /*    for (NSIndexPath *indexPath in [selectedIndexPathsSet allObjects]) {
     cardSetData = [myCardSets objectAtIndex:indexPath.row];
     [cardSetIdArray addObject:[NSNumber numberWithInt:cardSetData.cardSetId]];
     }
     */
    
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
    } else if (numberSetsLoaded < numberSetsTotal) {
        int returnVal = (int)[myCardSets count];
        if (!self.inPseudoEditMode) {
            // don't display the "Get the next set of cards" button if in pseudo edit mode
            returnVal++;
            return returnVal;
        }
    }
    if (connectionIsLoading) {
        int returnVal = (int)[myCardSets count];
        if (!self.inPseudoEditMode) {
            // don't display the "Get the next set of cards" button if in pseudo edit mode
            returnVal++;
            return returnVal;
        }
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
    } else if (indexPath.row < [myCardSets count]) {
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
    
    BOOL selected = [self.selectedIndexPathsSet containsObject:indexPath];
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
            
            BOOL selected = [self.selectedIndexPathsSet containsObject:indexPath];
            if (selected) {
                [cell.imageView setImage:self.selectedImage];
            } else {
                [cell.imageView setImage:self.unselectedImage];
            }
        } else {
            [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
            
            if (set.isPrivateSet) {
                [cell.imageView setImage:[UIImage imageNamed:@"54-lock.png"]];
            } else if (set.hasImages) {
                [cell.imageView setImage:[UIImage imageNamed:@"icon-camera.png"]];
            } else {
                [cell.imageView setImage:nil];
            }
        }
    } else {
        int numNewSets = 30;
        if ((numberSetsTotal - numberSetsLoaded) < 30) {
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

    [quizletUsernameField resignFirstResponder];

    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    if ([cell isEqual:loadingCell]) {
        return;
    }
    
    // If it's the "Download More..." button, then just download it:
    if (indexPath.row == [myCardSets count]) {
        // Unhighlight the load more button after it has been tapped.
        NSIndexPath *selection = [self.myTableView indexPathForSelectedRow];
        if (selection) {
            [self.myTableView deselectRowAtIndexPath:selection animated:YES];
        }

        // Also, make sure that it isn't the "No Sets Found" cell:
        if ([myCardSets count] == 0) {
            return;
        }
        
        // make it impossible to hit this cell multiple times.
        [[self.myTableView cellForRowAtIndexPath:indexPath] setSelectionStyle:UITableViewCellSelectionStyleNone];
        
        isLoadingNextPage = YES;
        [self loadCardSetsWithPageNumber:(currentPageNumber+1)];
        return;
    }

    // Unhighlight the load more button after it has been tapped.
    NSIndexPath *selection = [self.myTableView indexPathForSelectedRow];
    if (selection) {
        [self.myTableView deselectRowAtIndexPath:selection animated:YES];
    }
    if (self.inPseudoEditMode)
    {
        BOOL selected = [self.selectedIndexPathsSet containsObject:indexPath];
        if (selected) {
            // it is already in the selected set - remove it
            [self.selectedIndexPathsSet removeObject:indexPath];
        } else {
            // it is not yet in the selected set - add it
            [self.selectedIndexPathsSet addObject:indexPath];
        }
        [self.myTableView reloadData];
        return;
    }

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

    [self.loadingCellActivityIndicator stopAnimating];

    currentPageNumber = pageNumber;
    
    // clear out the current list of sets:
    if (!wasLoadingNextPage) {
        // clear out the current sets:
        [myCardSets removeAllObjects];
        [self.selectedIndexPathsSet removeAllObjects];
        // set up the # of sets for paging:
        numberSetsLoaded = (int)[cardSets count];
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
    [restClient genericCardSetAccessFailedWithError:error withDelegateView:self withCardSet:nil];
}

- (void)restClient:(FCRestClient *)client loadedCardSetCards:(NSArray *)cards withImages:(BOOL)withImages frontLanguage:(NSString*)frontLanguage backLanguage:(NSString*)backLanguage {
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
    vc.importFunction = @"MySets";
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

# pragma mark -
# pragma mark QuizletLoginControllerDelegate functions

- (void)loginControllerDidLogin:(QuizletLoginController *)controller {
    // quizletUsernameField.text = controller.usernameField.text;
    [myCardSets removeAllObjects];
    [self loadCardSets];
    [self.myTableView reloadData];
    [self setLoginButtonText];
}
- (void)loginControllerDidCancel:(QuizletLoginController*)controller {}

#pragma mark -
#pragma mark UIAlertView functions

-(void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex 
{
    if(buttonIndex == 1)
    {
        /*  get the user iputted text  */
        NSString *inputValue = [[alertView textFieldAtIndex:0] text];
        NSLog(@"User Input: %@",inputValue);
        
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

#pragma mark -
#pragma mark MBProgressHUDDelegate methods

- (void)hudWasHidden:(MBProgressHUD *)hud {
    // Remove HUD from screen when the HUD was hidded
    [hud removeFromSuperview];
    hud = nil;
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
    
    
    
    
    // [dateStringFormatter release];
    
    
    
}


@end
