//
//  QuizletGroupSetsViewController.m
//  FlashCards
//
//  Created by Jason Lustig on 4/13/11.
//  Copyright 2011-2014 Jason Lustig Lustig. All rights reserved.
//

#import "FlashCardsAppDelegate.h"
#import "FlashCardsCore.h"

#import "QuizletGroupSetsViewController.h"
#import "CardSetImportViewController.h"

#import "MBProgressHUD.h"

#import "QuizletLoginController.h"
#import "QuizletMyGroupsViewController.h" 
#import "QuizletRestClient+ErrorMessages.h"
#import "UIView+Layout.h"
#import "FCSetsTableViewController.h"
#import "UIColor-Expanded.h"

#import "FCCollection.h"
#import "FCCardSet.h"

@implementation QuizletGroupSetsViewController

@synthesize group;
@synthesize joinGroupButton, joinGroupToolbar;
@synthesize dateFormatter;
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
    
    alertedUserFlashcardsServerAPINotAvailable = NO;
    
    restClient = [[QuizletRestClient alloc] init];
    [restClient setDelegate:self];
    
    self.title = group.name;
    
    [self setJoinButtonText];
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(reloadCardSets)];
    
    // as per: http://stackoverflow.com/questions/4425692/nsdate-may-not-respond-to-datewithstring/4425715#4425715
    dateStringFormatter = [[NSDateFormatter alloc] init];
    dateStringFormatter.dateFormat = @"yyyy-MM-dd";
    
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
    // self.navigationItem.rightBarButtonItem.enabled = NO;
    
    [self.myTableView reloadData];
    
    if (!self.hasDownloadedFirstTime) {
        self.hasDownloadedFirstTime = YES;
        [self reloadCardSets];
    }

    
}

- (void)viewDidAppear:(BOOL)animated {
    NSIndexPath* selection = [self.myTableView indexPathForSelectedRow];
    if (selection) {
        [self.myTableView deselectRowAtIndexPath:selection animated:YES];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    // clear out all of the connection variables:
    [restClient cancelAllRequests];
}

- (BOOL)shouldAutorotate {
    UIInterfaceOrientation interfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    return [FlashCardsAppDelegate shouldAutorotate:interfaceOrientation];
}

# pragma mark -
# pragma mark Event functions

- (void)reloadCardSets {
    HUD = [[MBProgressHUD alloc] initWithView:self.view];
    [self.view addSubview:HUD];
    
    // Regisete for HUD callbacks so we can remove it from the window at the right time
    HUD.delegate = self;
    HUD.minShowTime = 0.0;
    HUD.labelText = NSLocalizedStringFromTable(@"Downloading Sets", @"Import", @"HUD");
    [HUD show:YES];
    
    [restClient loadGroupCardSetsList:group];
}

- (void)setJoinButtonText {
    if (group.isMemberOfGroup) {
        joinGroupButton.title = NSLocalizedStringFromTable(@"Leave Group", @"Import", @"UIButton");
    } else {
        joinGroupButton.title = NSLocalizedStringFromTable(@"Join Group", @"Import", @"UIButton");
    }
}

- (IBAction)joinButtonPressed:(id)sender {
    // check to see if the user has access to the Quizlet groups scope.
    bool hasGroupScope = [(NSNumber*)[FlashCardsCore getSetting:@"quizletWriteGroupScope"] boolValue];
    bool quizletIsLoggedIn = [(NSNumber*)[FlashCardsCore getSetting:@"quizletIsLoggedIn"] boolValue];
    if (!hasGroupScope || !quizletIsLoggedIn) {

        // the user is not logged in - we must ask the user to log in before joining a group.
        NSString *message = NSLocalizedStringFromTable(@"Please log in to Quizlet to access or join this group.", @"Import", @"message");
        FCDisplayBasicErrorMessage(@"", message);

        [FlashCardsCore resetAllRestoreProcessSettings];
        [FlashCardsCore setSetting:@"importProcessRestore" value:@YES];
        if (self.collection != nil) {
            [FlashCardsCore setSetting:@"importProcessRestoreCollectionId" value:[[[self.collection objectID] URIRepresentation] absoluteString]];
        }
        if (self.cardSet != nil) {
            [FlashCardsCore setSetting:@"importProcessRestoreCardsetId" value:[[[self.cardSet objectID] URIRepresentation] absoluteString]];
        }
        [FlashCardsCore setSetting:@"importProcessRestoreGroupId" value:[NSNumber numberWithInt:self.group.groupId]];
        FCSetsTableViewController *parentVC = [self.navigationController.viewControllers objectAtIndex:([self.navigationController.viewControllers count]-2)];
        // as per: http://stackoverflow.com/questions/2055940/how-to-get-class-name-of-object-in-objective-c
        if ([parentVC isKindOfClass:[QuizletMyGroupsViewController class]]) {
            [FlashCardsCore setSetting:@"importProcessRestoreChoiceViewController" value:@"QuizletMyGroupsViewController"];
        } else {
            [FlashCardsCore setSetting:@"importProcessRestoreChoiceViewController" value:@"QuizletSearchGroupsViewController"];
            [FlashCardsCore setSetting:@"importProcessRestoreSearchTerm" value:[[parentVC valueForKey:@"theSearchBar"] text]];
        }
        QuizletLoginController *loginController = [QuizletLoginController new];
        loginController.delegate = self;
        [loginController presentFromController:self];
        return;
    }

    
    if (group.isMemberOfGroup) {
        HUD = [[MBProgressHUD alloc] initWithView:self.view];
        [self.view addSubview:HUD];
        
        // Regisete for HUD callbacks so we can remove it from the window at the right time
        HUD.delegate = self;
        HUD.minShowTime = 0.0;
        HUD.labelText = NSLocalizedStringFromTable(@"Leaving Group", @"Import", @"HUD");
        [HUD show:YES];
        
        [restClient leaveGroup:group];
    } else {
        HUD = [[MBProgressHUD alloc] initWithView:self.view];
        [self.view addSubview:HUD];
        
        // Regisete for HUD callbacks so we can remove it from the window at the right time
        HUD.delegate = self;
        HUD.minShowTime = 0.0;
        HUD.labelText = NSLocalizedStringFromTable(@"Joining Group", @"Import", @"HUD");
        [HUD show:YES];

        [restClient joinGroup:group withInput:@""];
    }
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
        [self.myTableView setPositionHeight:(self.myTableView.frame.size.height+44)];
    } else { // if it is shown, then decrase the height of the table view
        // we are importing multiple sets
        self.navigationItem.rightBarButtonItem.style = UIBarButtonItemStyleDone;
        self.navigationItem.rightBarButtonItem.title = NSLocalizedStringFromTable(@"Import One", @"Import", @"UIBarButtonItem");
        [self.myTableView setPositionHeight:(self.myTableView.frame.size.height-44)];
    }
    
    [self.myTableView reloadData];
    
}

-(IBAction)importAllSets:(id)sender {
    [self.selectedIndexPathsSet removeAllObjects];
    for (int i = 0; i < [group.cardSets count]; i++) {
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
    for (int i = 0; i < [group.cardSets count]; i++) {
        indexPath = [NSIndexPath indexPathForRow:i inSection:0];
        if ([self.selectedIndexPathsSet containsObject:indexPath]) {
            cardSetData = [group.cardSets objectAtIndex:indexPath.row];
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
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if ([group.cardSets count] == 0) {
        return 1;
    }
    return [group.cardSets count];
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    static NSString *CellIdentifier;
    int style;
    if ([group.cardSets count] == 0) {
        style = UITableViewCellStyleDefault;
        CellIdentifier = @"CenterCell";
    } else if (indexPath.row < [group.cardSets count]) {
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
    if ([group.cardSets count] == 0) {
        cell.textLabel.text = NSLocalizedStringFromTable(@"No Sets In Group", @"Import", @"");
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        return;
    }

    ImportSet *set = (ImportSet*)[group.cardSets objectAtIndex:indexPath.row];
    
    // title is the same for Quizlet & FCE APIs.
    cell.textLabel.text = set.name;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@   %@",
                                 [NSString stringWithFormat:NSLocalizedStringFromTable(@"Added to group %@", @"Import", @""), [dateFormatter stringFromDate:set.creationDate]],
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
}

#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    [self tableView:tableView didSelectRowAtIndexPath:indexPath];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
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
    
    ImportSet *cardSetData = [group.cardSets objectAtIndex:indexPath.row];
    [restClient loadCardSetCards:cardSetData.cardSetId];
}

# pragma mark -
# pragma mark QuizletLoginControllerDelegate functions

- (void)loginControllerDidLogin:(QuizletLoginController *)controller {
    // if we are trying to access a private set, try to log in again, so 
    // we know whether or not it requires a password or just to ask to join:
    HUD = [[MBProgressHUD alloc] initWithView:self.view];
    [self.view addSubview:HUD];
    
    // Regisete for HUD callbacks so we can remove it from the window at the right time
    HUD.delegate = self;
    HUD.minShowTime = 0.0;
    HUD.labelText = NSLocalizedStringFromTable(@"Joining Group", @"Import", @"HUD");
    [HUD show:YES];
    
    [restClient joinGroup:group withInput:@""];
}
- (void)loginControllerDidCancel:(QuizletLoginController*)controller {}

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
    ImportSet *cardSetData = [group.cardSets objectAtIndex:self.selectedIndexPath.row];
    [cardSetData setFlashCards:[[NSMutableArray alloc] initWithArray:cards]];
    [cardSetData setFrontLanguage:[FlashCardsCore getLanguageAcronymFor:frontLanguage fromKey:@"quizletAcronym" toKey:@"googleAcronym"]];
    [cardSetData setBackLanguage: [FlashCardsCore getLanguageAcronymFor:backLanguage  fromKey:@"quizletAcronym" toKey:@"googleAcronym"]];
    if ([cardSetData.editable isEqualToString:@"groups"]) {
        cardSetData.userCanEditOnline = YES;
    }
    
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
    vc.importFunction = @"Group";
    [vc setCardSet:self.cardSet];
    [vc setCollection:self.collection];
    vc.allCardSets = [NSMutableArray arrayWithArray:cardSets];
    for (ImportSet *set in vc.allCardSets) {
        if ([set.editable isEqualToString:@"groups"]) {
            set.userCanEditOnline = YES;
        }
    }
    vc.popToViewControllerIndexSave = self.popToViewControllerIndex;
    vc.popToViewControllerIndexCancel = (int)[self.navigationController.viewControllers count]-1;
    vc.cardSetCreateMode = self.cardSetCreateMode;
    [self.navigationController pushViewController:vc animated:YES];
    
}

# pragma mark -
# pragma mark FCRestClientDelegate functions


- (void)restClient:(FCRestClient *)client loadGroupCardSetsListFailedWithError:(NSError *)error {
    
    NSIndexPath* selection = [self.myTableView indexPathForSelectedRow];
    if (selection) {
        [self.myTableView deselectRowAtIndexPath:selection animated:YES];
    }
    
    [HUD hide:YES];
    self.navigationItem.rightBarButtonItem.enabled = YES;
    [restClient genericGroupAccessFailedWithError:error withDelegateView:self withGroup:group];
}

- (void)restClient:(FCRestClient *)client loadedGroupCardSetsList:(NSMutableArray *)cardSets {
    [HUD hide:YES];
    self.navigationItem.rightBarButtonItem.enabled = YES;
    
    self.title = group.name;
    
    [self setJoinButtonText];

    group.cardSets = [[NSMutableArray alloc] initWithArray:cardSets];
    [self.myTableView reloadData];
}


# pragma mark -
# pragma mark FCRestClientDelegate functions - joining & leaving group

- (void)restClient:(FCRestClient *)client joinGroupFailedWithError:(NSError *)error {
    [HUD hide:YES];
    [restClient genericGroupAccessFailedWithError:error withDelegateView:self withGroup:group];
}

- (void)restClient:(FCRestClient *)client joinedGroup:(ImportGroup *)group withCardSets:(NSMutableArray *)cardSets {
    [HUD hide:YES];
    FCDisplayBasicErrorMessage(@"", NSLocalizedStringFromTable(@"You have joined this group successfully.", @"Import", @"message"));
    [self setJoinButtonText];
}

- (void)restClient:(FCRestClient *)client leaveGroupFailedWithError:(NSError *)error {
    [HUD hide:YES];
    NSString *message = [NSString stringWithFormat:NSLocalizedStringFromTable(@"Error: %@ (%d)", @"Error", @"message"),
                         [[error userInfo] objectForKey:@"errorMessage"],
                         [error code]];
    FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"Error", @"Error", @"UIAlert title"),
                               message);
}

- (void)restClient:(FCRestClient *)client leftGroup:(ImportGroup *)group {
    [HUD hide:YES];
    FCDisplayBasicErrorMessage(@"", NSLocalizedStringFromTable(@"You have left this group successfully.", @"Import", @"message"));
    if (self.group.isPrivateGroup) {
        // leave the section
        [self.navigationController popViewControllerAnimated:YES];
    } else {
        [self setJoinButtonText];
    }
}

# pragma mark -

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
