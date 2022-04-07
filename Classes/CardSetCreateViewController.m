//
//  CardSetCreateViewController.m
//  FlashCards
//
//  Created by Jason Lustig on 5/27/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import "FlashCardsAppDelegate.h"
#import "CardSetCreateViewController.h"
#import "CardSetViewViewController.h"

#import "FCCollection.h"
#import "FCCardSet.h"

#import "QuizletSync.h"
#import "QuizletRestClient.h"

#import <AddressBook/AddressBook.h>

#import "DTVersion.h"

@implementation CardSetCreateViewController

@synthesize collection, cardSet;
@synthesize saveButton, cancelButton, editMode;
@synthesize quizletImage;
@synthesize syncWithWebsiteLabel, syncWithWebsiteOption;
@synthesize viewOnWebsiteButton;
@synthesize cardSetNameField;
@synthesize HUD;

/*
#if TARGET_IPHONE_SIMULATOR
#else
@synthesize textExpander;
#endif
*/

@synthesize cardSetNameLabel;

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
    
    if (editMode == modeCreate) {
        self.title = NSLocalizedStringFromTable(@"New Card Set", @"CardManagement", @"UIView title");
    } else {
        self.title = NSLocalizedStringFromTable(@"Edit Card Set", @"CardManagement", @"UIView title");
    }
    
    cardSetNameLabel.text = NSLocalizedStringFromTable(@"Card Set Name:", @"CardManagement", @"UILabel");

    if ([cardSet.shouldSync boolValue] && [cardSet canSync]) {
        syncWithWebsiteLabel.text = NSLocalizedStringFromTable(@"Sync with Quizlet", @"CardManagement", @"");
    } else {
        syncWithWebsiteLabel.text = NSLocalizedStringFromTable(@"Subscribe to Online Changes", @"CardManagement", @"");
    }

    if ([cardSet isQuizletSet]) {
        [viewOnWebsiteButton setTitle:NSLocalizedStringFromTable(@"Open on Quizlet", @"CardManagement", @"UILabel") forState:UIControlStateNormal];
        [viewOnWebsiteButton setTitle:NSLocalizedStringFromTable(@"Open on Quizlet", @"CardManagement", @"UILabel") forState:UIControlStateSelected];
    }
    
    saveButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector(doneEditing:)];
    saveButton.enabled = YES;
    self.navigationItem.rightBarButtonItem = saveButton;
    
    cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelEvent)];
    cancelButton.enabled = YES;
    self.navigationItem.leftBarButtonItem = cancelButton;
        
    if (editMode == modeEdit && cardSet != nil) {
        cardSetNameField.text = cardSet.name;
    }
    BOOL showLogo = NO;
    if (editMode == modeEdit && cardSet != nil &&
        ([QuizletRestClient isLoggedIn] && [cardSet isQuizletSet])
        ) {
        showLogo = YES;
        syncWithWebsiteLabel.hidden = NO;
        syncWithWebsiteOption.hidden = NO;
        viewOnWebsiteButton.hidden = NO;
        [syncWithWebsiteOption setOn:[cardSet.shouldSync boolValue]];
    } else {
        showLogo = NO;
        syncWithWebsiteLabel.hidden = YES;
        syncWithWebsiteOption.hidden = YES;
        viewOnWebsiteButton.hidden = YES;
    }
    if (showLogo) {
        if ([cardSet isQuizletSet]) {
            quizletImage.hidden = NO;
            [self.view setBackgroundColor:[UIColor whiteColor]];
        } else {
            quizletImage.hidden = YES;
        }
    } else {
        quizletImage.hidden = YES;
    }
    [self.cardSetNameField becomeFirstResponder];
    
    /*
#if TARGET_IPHONE_SIMULATOR
#else
    textExpander = [[SMTEDelegateController alloc] init];
    
    [textExpander setNextDelegate:self];
    [cardSetNameField setDelegate:textExpander];
#endif
    */
    
    if (cardSet && [cardSet.isSubscribed boolValue]) {
        // display a message:
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@""
                                                         message:NSLocalizedStringFromTable(@"This card set is configured to subscribe to online changes. For this reason, you cannot edit the card locally as your changes may be overwritten by changes to the online set. If you would like, you can turn off the subscription but it will disable future online updates.", @"CardManagement", @"")
                                                        delegate:self
                                               cancelButtonTitle:NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"cancelButtonTitle")
                                               otherButtonTitles:NSLocalizedStringFromTable(@"Stop Subscription", @"CardManagement", @"otherButtonTitles"), nil];
        [alert show];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (BOOL)shouldAutorotate {
    UIInterfaceOrientation interfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    return [FlashCardsAppDelegate shouldAutorotate:interfaceOrientation];
}

# pragma mark -
# pragma mark Alert functions

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    NSString *buttonTitle = [alertView buttonTitleAtIndex:buttonIndex];
    if ([buttonTitle isEqualToString:NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"cancelButtonTitle")]) {
        [self cancelEvent];
        return;
    }
    if ([buttonTitle isEqualToString:NSLocalizedStringFromTable(@"Stop Subscription", @"CardManagement", @"otherButtonTitles")]) {
        NSManagedObjectID *objectID = self.cardSet.objectID;
        NSManagedObjectContext *tempMOC = [FlashCardsCore tempMOC];
        [tempMOC performBlock:^{
            FCCardSet *tCardSet = (FCCardSet*)[tempMOC objectWithID:objectID];
            [tCardSet setIsSubscribed:@NO];
            [tempMOC save:nil];
            [FlashCardsCore saveMainMOC];
        }];
        return;
    }
}

# pragma mark - Event functions

- (void)cancelEvent {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)saveEvent {
    
    if ([cardSetNameField.text length] == 0) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Error", @"Error", @"UIAlert title")
                                                         message:NSLocalizedStringFromTable(@"You did not enter a name for your Card Set.", @"CardManagement", @"message")
                                                        delegate:self
                                               cancelButtonTitle:NSLocalizedStringFromTable(@"OK", @"FlashCards", @"cancelButtonTitle")
                                               otherButtonTitles:nil];
        [alert show];
        return;
    }
    
    FCCardSet *newCardSet;
    
    NSString *oldName = @"";
    
    if (editMode == modeEdit && cardSet != nil) {
        // save your changes
        
        oldName = [NSString stringWithString:cardSet.name];
        cardSet.name = cardSetNameField.text;
        if (!syncWithWebsiteOption.hidden) {
            if ([cardSet canSync]) {
                // the set can sync:
                [cardSet   setShouldSync:[NSNumber numberWithBool:[syncWithWebsiteOption isOn]]];
            } else {
                [cardSet setIsSubscribed:[NSNumber numberWithBool:[syncWithWebsiteOption isOn]]];
            }
            if ([cardSet.shouldSync boolValue] && [cardSet.quizletSetId intValue] == 0) {
                // the set should sync, but it isn't yet on the Cram.com site. We'll have to upload it:
                // FCDisplayBasicErrorMessage(@"", @"Need to implement");
            }
        }
        SyncController *controller = [[FlashCardsCore appDelegate] syncController];
        if (controller && [cardSet.shouldSync boolValue]) {
            if ([cardSet isQuizletSet]) {
                [controller setQuizletDidChange:YES];
            }
        }
    } else {
    
        // create and configure a new instance of the Collection entity:

        newCardSet = (FCCardSet *)[NSEntityDescription insertNewObjectForEntityForName:@"CardSet"
                                                                inManagedObjectContext:[FlashCardsCore mainMOC]];

        [newCardSet setName:cardSetNameField.text];
        [newCardSet setCollection:collection];
        // [newCardSet setDateCreated:[NSDate date]];
        
        cardSet = newCardSet;
    }
    
    if (![oldName isEqual:cardSetNameField.text] || editMode == modeCreate) {
        [cardSet setSyncStatus:[NSNumber numberWithInt:syncChanged]];
    }

    [FlashCardsCore saveMainMOC];

    if ([cardSet.shouldSync boolValue]) {
        UIViewController *parentVC  = [FlashCardsCore parentViewController];
        if ([parentVC respondsToSelector:@selector(setShouldSyncN:)]) {
            [parentVC performSelector:@selector(setShouldSyncN:) withObject:@YES];
        }
    }
}

- (void)isDoneSaving {
    if (editMode == modeCreate) {
        CardSetViewViewController *vc = [[CardSetViewViewController alloc] initWithNibName:@"CardSetViewViewController" bundle:nil];
        vc.cardSet = self.cardSet;
        vc.cardsDue = 0;
        
        // Pass the selected object to the new view controller.
        NSMutableArray *viewControllers = [[NSMutableArray alloc] initWithArray:[self.navigationController viewControllers]];
        [viewControllers removeLastObject];
        [viewControllers addObject:vc];
        [self.navigationController setViewControllers:viewControllers animated:YES];
        
    } else {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

- (IBAction)doneEditing:(id)sender {
    [cardSetNameField resignFirstResponder];
    [self saveEvent];
    [self isDoneSaving];
}

- (IBAction)syncWithWebsiteOptionDidChange:(id)sender {
    if ([syncWithWebsiteOption isOn]) {
        // if the set is either not yet created, or doesn't have a FCE ID#,
        // then we will need to check to see if they want to upload the set
    }
}

- (IBAction)viewOnWebsite:(id)sender {
    [cardSet openWebsite];
}


#pragma mark -
#pragma mark MBProgressHUDDelegate methods

- (void)hudWasHidden:(MBProgressHUD *)hud {
    // Remove HUD from screen when the HUD was hidded
    [hud removeFromSuperview];
    hud = nil;
}

- (void)hudWasTapped:(MBProgressHUD *)hud {
    [hud hide:YES];
}

#pragma mark - Sync methods

- (void)updateHUDLabel:(NSString*)labelText {
    HUD.labelText = labelText;
}

# pragma mark -
# pragma mark Memory functions

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
    
    cardSetNameField = nil;
    
    [super viewDidUnload];
    
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}


- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (HUD) {
        HUD.delegate = nil;
    }
}




@end
