//
//  CardSetUploadToQuizletViewController.m
//  FlashCards
//
//  Created by Jason Lustig on 9/12/11.
//  Copyright 2011-2014 Jason Lustig Lustig. All rights reserved.
//

#import "CardSetUploadToQuizletViewController.h"

#import "FlashCardsCore.h"
#import "FlashCardsAppDelegate.h"

#import "QuizletLoginController.h"

#import "FCCollection.h"
#import "FCCardSet.h"
#import "FCCard.h"

#import "ImportGroup.h"
#import "QuizletRestClient.h"
#import "QuizletRestClient+ErrorMessages.h"

#import <MessageUI/MessageUI.h>

#import "DTVersion.h"

@implementation CardSetUploadToQuizletViewController

@synthesize collection, cardSet;
@synthesize cardSetNameLabel, cardSetNameField;
@synthesize allowDiscussionLabel, allowDiscussionSwitch;
@synthesize privateSetLabel, privateSetSwitch;
@synthesize addSetToGroupLabel, addSetToGroupSwitch;
@synthesize uploadToQuizletButton;
@synthesize noteLabel;
@synthesize myTableView;
@synthesize cardsToUpload;
@synthesize restClient, HUD;
@synthesize quizletSetURL, quizletSetName, quizletSetId;
@synthesize myGroups;
@synthesize selectedGroup;
@synthesize syncLabel, syncSwitch;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    if (![DTVersion osVersionIsLessThen:@"7.0"]) {
        self.edgesForExtendedLayout= UIRectEdgeNone;
    }
    
    self.title = NSLocalizedStringFromTable(@"Upload Cards", @"CardManagement", @"UIButton");

    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelEvent)];
    self.navigationItem.leftBarButtonItem = cancelButton;

    cardSetNameLabel.text       = NSLocalizedStringFromTable(@"Card Set Name:", @"CardManagement", @"UILabel");
    allowDiscussionLabel.text   = NSLocalizedStringFromTable(@"Allow Discussion?", @"CardManagement", @"UILabel");
    privateSetLabel.text        = NSLocalizedStringFromTable(@"Private Set?", @"CardManagement", @"UILabel");
    noteLabel.text              = NSLocalizedStringFromTable(@"Note: At this time, you cannot upload image flash cards to Quizlet. Only the text will be uploaded.", @"CardManagement", @"UILabel");
    addSetToGroupLabel.text     = NSLocalizedStringFromTable(@"Add Set to Group?", @"CardManagement", @"UIlabel");
    syncLabel.text              = NSLocalizedStringFromTable(@"Sync with Internet", @"CardManagement", @"UILabel");
    
    [uploadToQuizletButton setTitle:NSLocalizedStringFromTable(@"Upload to Quizlet", @"CardManagement", @"UIButton") forState:UIControlStateNormal]; 
    [uploadToQuizletButton setTitle:NSLocalizedStringFromTable(@"Upload to Quizlet", @"CardManagement", @"UIButton") forState:UIControlStateSelected];

    if (cardSet) {
        cardSetNameField.text = cardSet.name;
    } else {
        cardSetNameField.text = collection.name;        
    }

    [allowDiscussionSwitch  setOn:YES];
    [privateSetSwitch       setOn:NO];
    [addSetToGroupSwitch    setOn:NO];
    [syncSwitch             setOn:YES];

    restClient = [[QuizletRestClient alloc] init];
    [restClient setDelegate:self];
    
    myGroups = [[NSMutableArray alloc] initWithCapacity:0];
    
    if ([cardsToUpload count] < 2) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Error", @"Error", @"UIAlert title")
                                                         message:NSLocalizedStringFromTable(@"To upload cards, you need at least two cards in this set.", @"CardManagement", @"")
                                                        delegate:self
                                               cancelButtonTitle:NSLocalizedStringFromTable(@"OK", @"FlashCards", @"cancelButtonTitle")
                                               otherButtonTitles:nil];
        [alert show];
        return;
    }
    
    FCCardSet *cardSetToCheckAgainst = cardSet;
    if (!cardSet) {
        cardSetToCheckAgainst = collection.masterCardSet;
    }
    if (cardSetToCheckAgainst) {
        // check to see if the set is already synced.
        // if it is, then we won't let the user upload it again.
        // but we **will** give the user the option to send a link:
        if ([cardSetToCheckAgainst.shouldSync boolValue] && [cardSetToCheckAgainst.quizletSetId intValue] > 0) {
            // the set is already going to sync:
            
            // make some internal information out of the card set, so we will have it when we try to share the set:
            self.quizletSetURL  = [NSString stringWithFormat:@"http://www.quizlet.com/%d/my-set", [cardSetToCheckAgainst.quizletSetId intValue]];
            self.quizletSetName = cardSetToCheckAgainst.name;
            
            // show the alert
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Set is already uploaded", @"CardManagement", @"")
                                                            message:NSLocalizedStringFromTable(@"This card set is already uploaded to and synced with Quizlet. If you would like, you can share this set by sending an email to a friend with a link to the set on Quizlet.", @"CardManagement", @"")
                                                           delegate:self
                                                  cancelButtonTitle:NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"cancelButtonTitle")
                                                  otherButtonTitles:NSLocalizedStringFromTable(@"Send Email", @"CardManagement", @"cancelButtonTitle"), nil];
            [alert show];
            
        }
    }

    
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if (![FlashCardsCore isConnectedToInternet]) {
        [self.navigationController popViewControllerAnimated:YES];
        FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"No internet connection", @"Error", @""),
                                   NSLocalizedStringFromTable(@"Try again once you have an internet connection.", @"Error", @""));
        return;
    }

    BOOL isLoggedIn = [(NSNumber*)[FlashCardsCore getSetting:@"quizletIsLoggedIn"] boolValue];
    BOOL hasGroupScope = [(NSNumber*)[FlashCardsCore getSetting:@"quizletWriteGroupScope"] boolValue];
    
    if (!isLoggedIn || !hasGroupScope) {
        
        [FlashCardsCore resetAllRestoreProcessSettings];
        [FlashCardsCore setSetting:@"importProcessRestore" value:@NO];
        [FlashCardsCore setSetting:@"uploadProcessRestore" value:@YES];
        [FlashCardsCore setSetting:@"importProcessRestoreCollectionId" value:[[[self.collection objectID] URIRepresentation] absoluteString]];
        if (self.cardSet != nil) {
            [FlashCardsCore setSetting:@"importProcessRestoreCardsetId" value:[[[self.cardSet objectID] URIRepresentation] absoluteString]];
            [FlashCardsCore setSetting:@"importProcessRestoreCollectionId" value:[[[self.cardSet.collection objectID] URIRepresentation] absoluteString]];
        }
        [FlashCardsCore setSetting:@"importProcessRestoreChoiceViewController" value:@"CardSetUploadToQuizletViewController"];
        
        QuizletLoginController *loginController = [QuizletLoginController new];
        loginController.delegate = self;
        [loginController presentFromController:self];
    }


}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotate {
    UIInterfaceOrientation interfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    // Return YES for supported orientations
    return [FlashCardsAppDelegate shouldAutorotate:interfaceOrientation];
}


# pragma mark -
# pragma mark Events

- (IBAction)doneEditing:(id)sender {
    [sender resignFirstResponder];
}
- (IBAction)backgroundTap:(id)sender {
    [cardSetNameField resignFirstResponder];
}
- (IBAction)addToGroupSwitchDidChange:(id)sender {
    if ([sender isOn]) {
        [self loadGroups];
    } else {
        [self.myTableView reloadData];
    }
}


- (void)cancelEvent {
    [self.navigationController popViewControllerAnimated:YES];
}


- (IBAction)uploadToQuizlet:(id)sender {
    
    if ([cardSetNameField.text length] == 0) {
        FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"Error", @"Error", @"UIAlert title"),
                                   NSLocalizedStringFromTable(@"You did not enter a name for your Card Set.", @"CardManagement", @"message"));
        return;
    }
    
    [Flurry logEvent:@"Share"
      withParameters:@{
     @"method" : @"quizlet",
     @"numCards" : [NSNumber numberWithInt:[self.cardsToUpload count]]
     }];

    self.navigationItem.leftBarButtonItem.enabled = NO;
    
    HUD = [[MBProgressHUD alloc] initWithView:self.view];
    
    // Add HUD to screen
    [self.view addSubview:HUD];
    
    // Regisete for HUD callbacks so we can remove it from the window at the right time
    HUD.delegate = self;
    // HUD.minShowTime = 2.0;
    HUD.labelText = NSLocalizedStringFromTable(@"Uploading Cards", @"CardManagement", @"HUD");
    [HUD show:YES];

    int groupId = -1;
    if ([addSetToGroupSwitch isOn]) {
        int selectedGroupRow = (int)selectedGroup.row;
        if (selectedGroupRow < [myGroups count]) {
            ImportGroup *group = [myGroups objectAtIndex:selectedGroupRow];
            groupId = group.groupId;
        }
    }
    
    NSString *frontLanguage = [FlashCardsCore getLanguageAcronymFor:collection.frontValueLanguage fromKey:@"googleAcronym" toKey:@"quizletAcronym"];
    NSString *backLanguage  = [FlashCardsCore getLanguageAcronymFor:collection.backValueLanguage  fromKey:@"googleAcronym" toKey:@"quizletAcronym"];
    
    if (!frontLanguage) {
        frontLanguage = @"en";
    }
    if (!backLanguage) {
        backLanguage = @"en";
    }

    [restClient uploadCardSetWithName:cardSetNameField.text
                            withCards:cardsToUpload
                        fromFCCardSet:self.cardSet
                     fromFCCollection:self.collection
                           shouldSync:[syncSwitch isOn]
                            isPrivate:[privateSetSwitch isOn]
                         isDiscussion:[allowDiscussionSwitch isOn]
                              toGroup:groupId
                    withFrontLanguage:frontLanguage
                     withBackLanguage:backLanguage];

}

- (void)loadGroups {
    NSString *username = (NSString*)[FlashCardsCore getSetting:@"quizletLoginUsername"];

    HUD = [[MBProgressHUD alloc] initWithView:self.view];
    
    // Add HUD to screen
    [self.view addSubview:HUD];
    
    // Regisete for HUD callbacks so we can remove it from the window at the right time
    HUD.delegate = self;
    // HUD.minShowTime = 2.0;
    HUD.labelText = NSLocalizedStringFromTable(@"Downloading Groups", @"Import", @"HUD");
    [HUD show:YES];

    [restClient loadUserGroupsList:username];
}

# pragma mark -
# pragma mark FCRestClientDelegate functions - upload

- (void)restClient:(FCRestClient*)client
uploadedCardSetWithName:(NSString*)setName
   withNumberCards:(int)numberCards
        shouldSync:(BOOL)shouldSync
         isPrivate:(BOOL)isPrivate
      isDiscussion:(BOOL)isDiscussion
       andFinalURL:(NSString*)finalURL {
    self.navigationItem.leftBarButtonItem.enabled = YES;
    [HUD hide:YES];
    
    self.quizletSetURL = [NSString stringWithString:finalURL];
    self.quizletSetName= [NSString stringWithString:setName];
    self.quizletSetId = 0;
    
    NSString *message = [NSString stringWithFormat:FCPluralLocalizedStringFromTable(@"Your set \"%@\" (%d terms) has been uploaded successfully.", @"Plural", @"", [NSNumber numberWithInt:numberCards]), setName, numberCards];
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@""
                                                     message:message
                                                    delegate:self
                                           cancelButtonTitle:NSLocalizedStringFromTable(@"OK", @"FlashCards", @"cancelButtonTitle")
                                           otherButtonTitles:
                           NSLocalizedStringFromTable(@"Open on Quizlet", @"CardManagement", @""),
                           NSLocalizedStringFromTable(@"Send Email", @"CardManagement", @""),
                           nil];
    [alert show];
}
- (void)restClient:(FCRestClient*)client uploadCardSetFailedWithError:(NSError*)error {
    self.navigationItem.leftBarButtonItem.enabled = YES;
    [HUD hide:YES];
    NSString *message = [NSString stringWithFormat:NSLocalizedStringFromTable(@"Error: %@ (%d)", @"Error", @"message"),
               [[error userInfo] objectForKey:@"errorMessage"],
               [error code]];
    // inform the user
    FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"Error", @"Error", @"UIAlert title"), message);
}

# pragma mark -
# pragma mark FCRestClientDelegate functions - groups

- (void)restClient:(FCRestClient *)client loadUserGroupsListFailedWithError:(NSError *)error {
    [HUD hide:YES];
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
    [HUD hide:YES];
    
    // clear out the current list of sets:
    [myGroups removeAllObjects];
    
    if ([groups count] == 0) {
        [addSetToGroupSwitch setOn:NO];
        // show them a message:
        
    }
    // filter out any sets that contain images:
    [myGroups addObjectsFromArray:groups];
    
    selectedGroup = [NSIndexPath indexPathForRow:0 inSection:0];
    
    [self.myTableView reloadData];
}

# pragma mark -
# pragma mark Table View functions

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    if ([addSetToGroupSwitch isOn]) {
        return 1;
    } else {
        return 0;
    }
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    return [myGroups count];
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier;
    int style;
    style = UITableViewCellStyleSubtitle;
    CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:style reuseIdentifier:CellIdentifier];
    }
    
    // Configure the cell...
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}


- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    ImportGroup *set = (ImportGroup*)[myGroups objectAtIndex:indexPath.row];
    
    // title is the same for Quizlet & FCE APIs.
    cell.textLabel.text = set.name;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@   %@",
                                 [NSString stringWithFormat:FCPluralLocalizedStringFromTable(@"%d sets", @"Plural", @"", [NSNumber numberWithInt:[set numberCardSets]]), [set numberCardSets]],
                                 [NSString stringWithFormat:FCPluralLocalizedStringFromTable(@"%d users", @"Plural", @"", [NSNumber numberWithInt:[set numberUsers]]), [set numberUsers]]
                                 ];
    if (indexPath.row == selectedGroup.row) {
        [cell setAccessoryType:UITableViewCellAccessoryCheckmark];
    } else {
        [cell setAccessoryType:UITableViewCellAccessoryNone];
    }
    
    if (set.isPrivateGroup) {
        [cell.imageView setImage:[UIImage imageNamed:@"54-lock.png"]];
    } else {
        [cell.imageView setImage:nil];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    NSIndexPath *selection = [self.myTableView indexPathForSelectedRow];
    if (selection) {
        [self.myTableView deselectRowAtIndexPath:selection animated:YES];
    }

    if (selectedGroup.row == indexPath.row) {
        return;
    }
    
    UITableViewCell *currentCell = [tableView cellForRowAtIndexPath:indexPath];
    UITableViewCell *selectedCell = [tableView cellForRowAtIndexPath:selectedGroup];
    self.selectedGroup = indexPath;
    
    [currentCell setAccessoryType:UITableViewCellAccessoryCheckmark];
    [selectedCell setAccessoryType:UITableViewCellAccessoryNone];
}



# pragma mark -
# pragma mark UIAlertViewDelegate functions


-(void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 0) {
        // done
        [self cancelEvent];
        return;
    } else if (buttonIndex == 1) {
        if ([alertView.title isEqualToString:NSLocalizedStringFromTable(@"Set is already uploaded", @"CardManagement", @"")]) {
            [self shareSetViaEmail];
            return;
        }
        NSURL *url = [NSURL URLWithString:quizletSetURL];
        [[UIApplication sharedApplication] openURL:url];
        // [self.navigationController popViewControllerAnimated:YES];
    } else if (buttonIndex == 2) {
        // we are sending feedback:
        [self shareSetViaEmail];
    } else {
        [self cancelEvent];
    }
}

- (void)shareSetViaEmail {
    MFMailComposeViewController *feedbackController = [[MFMailComposeViewController alloc] init];
    feedbackController.mailComposeDelegate = self;
    [feedbackController setSubject:
     [NSString stringWithFormat:NSLocalizedStringFromTable(@"I am sharing FlashCards++ cards on %@: %@", @"CardManagement", @""),
      @"Quizlet",
      quizletSetName,
      nil]];
    NSString *messageBody = [NSString stringWithFormat:NSLocalizedStringFromTable(@"<p>I just uploaded a set of flash cards called \"%@\" to %@ from FlashCards++ at <a href=\"%@\">%@</a>.</p>"
                                                                                  "<p>If you don't have FlashCards++, you can download it from the App Store to study flash cards on your iPhone or iPad at <a href=\"%@\">%@</a></p>", @"CardManagement", @"share-mail message"),
                             quizletSetName,
                             @"Quizlet",
                             quizletSetURL,
                             quizletSetURL,
                             @"http://bit.ly/flashcardapp",
                             @"http://bit.ly/flashcardapp",
                             nil];
    
    [feedbackController setMessageBody:messageBody
                                isHTML:YES];
    [self presentViewController:feedbackController animated:YES completion:nil];
}


# pragma mark -
# pragma mark QuizletLoginControllerDelegate functions

- (void)loginControllerDidCancel:(QuizletLoginController*)controller {
    [self cancelEvent];
}

# pragma mark -
# pragma mark HUD

- (void)hudWasHidden:(MBProgressHUD *)hud {
    // Remove HUD from screen when the HUD was hidded
    [hud removeFromSuperview];
    hud = nil;
}

# pragma mark -
# pragma mark MFMailComposeViewControllerDelegate functions

- (void)mailComposeController:(MFMailComposeViewController*)controller  
          didFinishWithResult:(MFMailComposeResult)result 
                        error:(NSError*)error;
{
    if (result == MFMailComposeResultSent) {
        // thank the user for sending feedback:
        FCDisplayBasicErrorMessage(@"",
                                   NSLocalizedStringFromTable(@"Your message has been sent successfully.", @"CardManagement", @"message"));
        //    NSLog(@"It's away!");
    } else if (result == MFMailComposeResultFailed) {
        FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"Error", @"Error", @"UIAlert title"),
                                   [NSString stringWithFormat:NSLocalizedStringFromTable(@"An error occurred sending your message: %@ %@", @"Error", @"message"), error, [error userInfo]]);
    }
    [self dismissViewControllerAnimated:YES completion:nil];
    [self.navigationController popViewControllerAnimated:YES];
}

@end
