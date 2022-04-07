//
//  QuizletMyGroupsViewController.m
//  FlashCards
//
//  Created by Jason Lustig on 4/13/11.
//  Copyright 2011-2014 Jason Lustig Lustig. All rights reserved.
//

#import "FlashCardsAppDelegate.h"
#import "FlashCardsCore.h"

#import "QuizletMyGroupsViewController.h"
#import "QuizletGroupSetsViewController.h"
#import "CardSetImportViewController.h"

#import "MBProgressHUD.h"
#import "QuizletRestClient+ErrorMessages.h"

#import "QuizletLoginController.h"
#import "FCSetsTableViewController.h"

#import "FCCollection.h"
#import "FCCardSet.h"

@implementation QuizletMyGroupsViewController

@synthesize quizletUsernameField, myCardSets;
@synthesize loadingCell, loadingCellActivityIndicator, loginToAccessPrivateCardSetsButton;
@synthesize dateFormatter;
@synthesize connectionIsLoading;
@synthesize numberSetsTotal, numberSetsLoaded;
@synthesize hasStartedSearch;
@synthesize loadingLabel, loadingCancelButton;
@synthesize dateStringFormatter;
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
    
    restClient = [[QuizletRestClient alloc] init];
    [restClient setDelegate:self];
    
    self.title = NSLocalizedStringFromTable(@"My Groups", @"Import", @"UIView title");
    
    
    quizletUsernameField.placeholder = NSLocalizedStringFromTable(@"Your Quizlet Username", @"Import", @"quizlet username field placeholder");
    
    loadingLabel.text = NSLocalizedStringFromTable(@"Loading...", @"FlashCards", @"UILabel");
    [loadingCancelButton setTitle:NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"UILabel") forState:UIControlStateNormal]; 
    [loadingCancelButton setTitle:NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"UILabel") forState:UIControlStateSelected];
    
    hasStartedSearch = NO;
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
    
    
    quizletUsernameField.text = (NSString*)[FlashCardsCore getSetting:@"quizletUsername"];
    if ([quizletUsernameField.text length] == 0) {
        [quizletUsernameField becomeFirstResponder];
    }    
    
    
}

- (void)viewDidAppear:(BOOL)animated {
    [self setLoginButtonText];

    // reload the sets each time we return to the list:
    if ([quizletUsernameField.text length] > 0 && !self.hasDownloadedFirstTime) {
        [self setHasDownloadedFirstTime:YES];
        [myCardSets removeAllObjects];
        [self loadCardSets];
    }
    
    NSIndexPath* selection = [self.myTableView indexPathForSelectedRow];
    if (selection) {
        [self.myTableView deselectRowAtIndexPath:selection animated:YES];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    // clear out all of the connection variables:
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
        loginToAccessPrivateCardSetsButton.title = [NSString stringWithFormat:NSLocalizedStringFromTable(@"Logout (%@)", @"Import", @"UIBarButtonItem"), username];
    } else {
        loginToAccessPrivateCardSetsButton.title = NSLocalizedStringFromTable(@"Login to Access Private Groups", @"Import", @"UIBarButtonItem");
    }
}

- (IBAction)loginButtonPressed:(id)sender {
    if ([(NSNumber*)[FlashCardsCore getSetting:@"quizletIsLoggedIn"] boolValue]) { 
        [FlashCardsCore setSetting:@"quizletIsLoggedIn" value:@NO];
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
        [FlashCardsCore setSetting:@"importProcessRestoreChoiceViewController" value:@"QuizletMyGroupsViewController"];
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
    
    [myCardSets removeAllObjects];
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
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Error", @"Error", @"UIAlert title")
                                                         message:NSLocalizedStringFromTable(@"Your username must be at least two characters in length.", @"Import", @"message")
                                                        delegate:nil
                                               cancelButtonTitle:NSLocalizedStringFromTable(@"OK", @"FlashCards", @"cancelButtonTitle")
                                               otherButtonTitles:nil];
        [alert show];
        return;
    }
    
    [restClient loadUserGroupsList:searchText];
    
    [self.myTableView reloadData];
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    if (connectionIsLoading) {
        return 1;
    }
    if ([myCardSets count] == 0) {
        if (connectionIsLoading || hasStartedSearch) {
            return 1;
        }
        return 0;
    }
    if (connectionIsLoading) {
        return [myCardSets count]+1;
    }
    return [myCardSets count];
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (connectionIsLoading && indexPath.row >= [myCardSets count]) {
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
    ImportGroup *set = (ImportGroup*)[myCardSets objectAtIndex:indexPath.row];
    
    // title is the same for Quizlet & FCE APIs.
    cell.textLabel.text = set.name;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@   %@",
                                 [NSString stringWithFormat:FCPluralLocalizedStringFromTable(@"%d sets", @"Plural", @"", [NSNumber numberWithInt:[set numberCardSets]]), [set numberCardSets]],
                                 [NSString stringWithFormat:FCPluralLocalizedStringFromTable(@"%d users", @"Plural", @"", [NSNumber numberWithInt:[set numberUsers]]), [set numberUsers]]
                                 ];
    [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
    
    if (set.isPrivateGroup) {
        [cell.imageView setImage:[UIImage imageNamed:@"54-lock.png"]];
    } else {
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
    if (indexPath.row >= [myCardSets count]) {
        return;
    }
    
    self.selectedIndexPath = indexPath;
    
    HUD = [[MBProgressHUD alloc] initWithView:self.view];
    [self.view addSubview:HUD];
    
    // Regisete for HUD callbacks so we can remove it from the window at the right time
    HUD.delegate = self;
    HUD.minShowTime = 0.0;
    HUD.labelText = NSLocalizedStringFromTable(@"Downloading Groups", @"Import", @"HUD");
    [HUD show:YES];

    ImportGroup *cardSetData = [myCardSets objectAtIndex:indexPath.row];
    [restClient loadGroupCardSetsList:cardSetData];
    
}

# pragma mark -
# pragma mark FCRestClientDelegate functions

- (void)restClient:(FCRestClient *)client loadUserGroupsListFailedWithError:(NSError *)error {
    connectionIsLoading = NO;
    
    // hide the progress bars:
    if (self.loadingCellActivityIndicator && self.myTableView) {
        [self.loadingCellActivityIndicator stopAnimating];
        [self.myTableView reloadData];
    }
    
    NSString *message;
    if (error.code == kFCErrorObjectDoesNotExist) {
        FCDisplayBasicErrorMessage(@"", NSLocalizedStringFromTable(@"This user does not exist; make sure you did not misspell the name.", @"Import", @"message"));
        return;
    } else {
        message = [NSString stringWithFormat:NSLocalizedStringFromTable(@"Error: %@ (%d)", @"Error", @"message"),
                   [[error userInfo] objectForKey:@"errorMessage"],
                   [error code]];
    }
    // inform the user
    FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"Error", @"Error", @"UIAlert title"), message);
}

- (void)restClient:(FCRestClient *)client loadedUserGroupsList:(NSMutableArray *)groups {
    connectionIsLoading = NO;

    [self.loadingCellActivityIndicator stopAnimating];
    
    // clear out the current list of sets:
    [myCardSets removeAllObjects];
    
    // filter out any sets that contain images:
    [myCardSets addObjectsFromArray:groups];
    
    [self.myTableView reloadData];
    
    NSIndexPath *topIndexPath = [NSIndexPath indexPathForRow:0 inSection:0];
    [self.myTableView scrollToRowAtIndexPath:topIndexPath atScrollPosition:UITableViewScrollPositionTop animated:YES];
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
    // only show this message once while you are doing this:
    if (!alertedUserFlashcardsServerAPINotAvailable) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@""
                                                         message:NSLocalizedStringFromTable(@"Due to technical difficulties or site maintenance, access to private Quizlet sets and groups is not currently available. It will be available again shortly.", @"Import", @"error message")
                                                        delegate:nil
                                               cancelButtonTitle:NSLocalizedStringFromTable(@"OK", @"FlashCards", @"cancelButtonTitle")
                                               otherButtonTitles:nil];
        [alert show];
    }
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
        // quizletUsernameField.text = controller.usernameField.text;
        [myCardSets removeAllObjects];
        [self loadCardSets];
        [self.myTableView reloadData];
    }
}
- (void)loginControllerDidCancel:(QuizletLoginController*)controller {}

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
