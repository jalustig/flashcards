//
//  DuplicateCardViewController.m
//  FlashCards
//
//  Created by Jason Lustig on 8/28/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import "FlashCardsAppDelegate.h"
#import "FlashCardsCore.h"

#import "DuplicateCardViewController.h"
#import "CardSetImportViewController.h"

#import "ImportTerm.h"
#import "ImportSet.h"
#import "FCCard.h"

#import "GrowableTextView.h"

@implementation DuplicateCardViewController

@synthesize mergePrevNextSegmentedControl, prevNextToolbar;
@synthesize mergeCell, mergeLabel, mergeSwitch;
@synthesize markRelatedCell, markRelatedLabel, markRelatedSwitch;
@synthesize resetStatisticsCell, resetStatisticsLabel, resetStatisticsSwitch;
@synthesize mergeFrontCell, mergeFrontLabel, mergeFrontSwitch;
@synthesize mergeBackCell, mergeBackLabel, mergeBackSwitch;
@synthesize remoteCardFrontValueCell, remoteCardFrontValueLabel, remoteCardFrontValueTextView;
@synthesize oldCardFrontValueCell, oldCardFrontValueLabel, oldCardFrontValueTextView;
@synthesize remoteCardBackValueCell, remoteCardBackValueLabel, remoteCardBackValueTextView;
@synthesize oldCardBackValueCell, oldCardBackValueLabel, oldCardBackValueTextView;
@synthesize mergedCardFrontValueCell, mergedCardFrontValueLabel, mergedCardFrontValueTextView;
@synthesize mergedCardBackValueCell, mergedCardBackValueLabel, mergedCardBackValueTextView;

@synthesize myTableView, accessoryView;

// Merge & Edit View
@synthesize termsList;
@synthesize mergeCardFront, mergeCardBack;
@synthesize duplicateCardsIndex, duplicateCards, autoMergeIdenticalCards;
@synthesize canResignTextView;
@synthesize popToViewControllerIndex;
@synthesize currentlySelectedTextViewIndexPath;


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

    self.canResignTextView = NO;

    mergeLabel.text = NSLocalizedStringFromTable(@"Merge Card?", @"Import", @"");
    mergeFrontLabel.text = NSLocalizedStringFromTable(@"Merge + Edit", @"Import", @"UISegmentedControl");
    mergeBackLabel.text = NSLocalizedStringFromTable(@"Merge + Edit", @"Import", @"UISegmentedControl");
    
    markRelatedLabel.text = NSLocalizedStringFromTable(@"Mark Cards Related?", @"Import", @"UILabel");
    resetStatisticsLabel.text = NSLocalizedStringFromTable(@"Reset Statistics?", @"Statistics", @"UILabel");
    
    [mergePrevNextSegmentedControl setTitle:NSLocalizedStringFromTable(@"< Prev", @"Study", @"UISegmentedControl") forSegmentAtIndex:0];
    [mergePrevNextSegmentedControl setTitle:NSLocalizedStringFromTable(@"Next >", @"Study", @"UISegmentedControl") forSegmentAtIndex:1];
    
    autoMergeIdenticalCards = [(NSNumber*)[FlashCardsCore getSetting:@"importSettingsAutoMergeIdenticalCards"] boolValue];
    
    NSArray *allTextViews = [NSArray arrayWithObjects:
                             remoteCardFrontValueTextView,
                             remoteCardBackValueTextView,
                             oldCardFrontValueTextView,
                             oldCardBackValueTextView,
                             mergedCardFrontValueTextView,
                             mergedCardBackValueTextView,
                             nil];
    int fontSize;
    if ([FlashCardsAppDelegate isIpad]) {
        fontSize = 17;
    } else {
        fontSize = 14;
    }
    for (UITextView *textView in allTextViews) {
        textView.font = [UIFont systemFontOfSize:fontSize];
        [textView setDelegate:self];
    }
    
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelEvent)];
    self.navigationItem.leftBarButtonItem = cancelButton;
    
    UIBarButtonItem *saveButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector(saveEvent)];
    self.navigationItem.rightBarButtonItem = saveButton;
    
    [mergePrevNextSegmentedControl addTarget:self action:@selector(mergeNextPrevCardAction) forControlEvents:UIControlEventValueChanged];

    // make sure they always know what indexPath they are:
    mergedCardFrontValueTextView.indexPath = [NSIndexPath indexPathForRow:1 inSection:1];
    mergedCardBackValueTextView.indexPath = [NSIndexPath indexPathForRow:1 inSection:2];

    bool autocorrectText = [(NSNumber*)[FlashCardsCore getSetting:@"shouldUseAutoCorrect"] boolValue];
    if (autocorrectText) {
        mergedCardFrontValueTextView.autocorrectionType = UITextAutocorrectionTypeYes;
        mergedCardBackValueTextView.autocorrectionType  = UITextAutocorrectionTypeYes;
    } else {
        mergedCardFrontValueTextView.autocorrectionType = UITextAutocorrectionTypeNo;
        mergedCardBackValueTextView.autocorrectionType  = UITextAutocorrectionTypeNo;
    }
    
    bool autocapitalizeText = [(NSNumber*)[FlashCardsCore getSetting:@"shouldUseAutoCapitalizeText"] boolValue];
    if (autocapitalizeText) {
        mergedCardFrontValueTextView.autocapitalizationType = UITextAutocapitalizationTypeSentences;
        mergedCardBackValueTextView.autocapitalizationType  = UITextAutocapitalizationTypeSentences;
    } else {
        mergedCardFrontValueTextView.autocapitalizationType = UITextAutocapitalizationTypeNone;
        mergedCardBackValueTextView.autocapitalizationType  = UITextAutocapitalizationTypeNone;
    }
    

    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardHidden) name:UIKeyboardDidHideNotification object:NULL];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardShown) name:UIKeyboardWillShowNotification object:NULL];
    
    duplicateCardsIndex = 0;
    mergeCardFront = mergeCardCurrent;
    mergeCardBack = mergeCardCurrent;
    [self configureMergeLabels];
    
    
}

- (BOOL)shouldAutorotate {
    UIInterfaceOrientation interfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    return [FlashCardsAppDelegate shouldAutorotate:interfaceOrientation];
}

- (void)viewWillDisappear:(BOOL)animated {
    // We must set self.canResignTextView to YES, so that if the user hits "Save" or "Cancel"
    // while a text view is firstResponder, then it will be able to give up its firstResponder
    // status. Otherwise, any other attempts to give a widget firstResponder status will fail
    // following this strange, strange situation!
    self.canResignTextView = YES;
    [super viewWillDisappear:animated];
}

- (NSString*)mergeString:(NSString*)oldCardString withString:(NSString*)newCardString {
    // 1. make a list of all of the 'parts' of each string:
    NSCharacterSet *separators = [NSCharacterSet characterSetWithCharactersInString:@";,\n"];
    NSMutableArray *oldParts = [NSMutableArray arrayWithArray:[oldCardString componentsSeparatedByCharactersInSet:separators]];
    NSMutableArray *newParts = [NSMutableArray arrayWithArray:[newCardString componentsSeparatedByCharactersInSet:separators]];
    
    for (int i = 0; i < [oldParts count]; i++) {
        [oldParts replaceObjectAtIndex:i
                            withObject:[[oldParts objectAtIndex:i]
                                        stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
    }
    for (int i = 0; i < [newParts count]; i++) {
        [newParts replaceObjectAtIndex:i
                            withObject:[[newParts objectAtIndex:i]
                                        stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
    }
    
    // 2. Anything in the new that is not in the old, add it:
    NSMutableArray *finalParts = [NSMutableArray arrayWithArray:oldParts];
    bool found = NO;
    NSString *oldPart;
    for (NSString *newPart in newParts) {
        if (![oldParts containsObject:[newPart lowercaseString]]) {
            found = NO;
            for (int i = 0; i < [finalParts count]; i++) {
                oldPart = [finalParts objectAtIndex:i];
                if ([[oldPart lowercaseString] caseInsensitiveCompare:newPart] == NSOrderedSame) {
                    // the oldPart and newPart are identical
                    continue;
                } else if (([oldPart rangeOfString:[newPart lowercaseString]]).location != NSNotFound) {
                    // as per: http://objcolumnist.com/2009/04/12/does-a-nsstring-contain-a-substring/
                    // the oldPart *contains* the new part, therefore we we will continue to use the old part.
                    // BUT we found it, so we know not to re-add it.
                    found = YES;
                    break;
                } else if (([[newPart lowercaseString] rangeOfString:oldPart]).location != NSNotFound) {
                    // the new part contains the old part! Replace the oldPart with newPart:
                    [finalParts replaceObjectAtIndex:i withObject:newPart];
                    found = YES;
                    break;
                }
            }
            if (!found) {
                // if we didn't find it in our search, we will simply add it:
                [finalParts addObject:newPart];
            }
        }
    }
    
    return [finalParts componentsJoinedByString:@", "];
}

- (UITextView*) textViewAtIndex:(NSIndexPath *)indexPath {
    UITextView *textView;

    switch (indexPath.section) {
        default:
        case 1: // new card OR front of card
            if (![mergeSwitch isOn]) {
                // we are displaying the new card, so two items:
                if (indexPath.row == 0) {
                    textView = remoteCardFrontValueTextView;
                } else {
                    textView = remoteCardBackValueTextView;
                }
            } else if (indexPath.row == 0) {
                return nil;
            } else if (![mergeFrontSwitch isOn]) {
                // we are not merging the front, so we should display 
                if (indexPath.row == 1) {
                    // this is the "Merge Front"?
                    textView = remoteCardFrontValueTextView;
                } else {
                    textView = oldCardFrontValueTextView;
                }
            } else {
                // we are merging the front, so display two options, the merge switch & edit:
                textView = mergedCardFrontValueTextView;
            }
            break;
        case 2:
            if (![mergeSwitch isOn]) {
                // we are displaying the new card, so two items:
                if (indexPath.row == 0) {
                    textView = oldCardFrontValueTextView;
                } else {
                    textView = oldCardBackValueTextView;
                }
            } else if (indexPath.row == 0) {
                return nil;
            } else if (![mergeBackSwitch isOn]) {
                // we are not merging the front, so we should display 
                if (indexPath.row == 1) {
                    // this is the "Merge Back"?
                    textView = remoteCardBackValueTextView;
                } else {
                    textView = oldCardBackValueTextView;
                }
            } else {
                // we are merging the front, so display two options, the merge switch & edit:
                textView = mergedCardBackValueTextView;
            }
            break;
    }
    return textView;
}

- (IBAction)doneEditingKeyboard:(id)sender {
    canResignTextView = YES;
    UITextView *textView = [self textViewAtIndex:self.currentlySelectedTextViewIndexPath];
    if (textView) {
        [textView resignFirstResponder];
    } else {
        // should do something here
    }
}

- (IBAction)textViewTypeLeftParens:(id)sender {
    [self addCharacterToTextView:@"("];
}
- (IBAction)textViewTypeRightParens:(id)sender {
    [self addCharacterToTextView:@")"];
}
- (IBAction)textViewTypeComma:(id)sender {
    [self addCharacterToTextView:@","];
}
- (IBAction)textViewTypeSemicolon:(id)sender {
    [self addCharacterToTextView:@";"];
}
- (IBAction)textViewTypePeriod:(id)sender {
    [self addCharacterToTextView:@"."];
}
- (IBAction)textViewTypeAsterix:(id)sender {
    [self addCharacterToTextView:@"*"];
}
- (IBAction)textViewTypeApostrophe:(id)sender {
    [self addCharacterToTextView:@"'"];
}

- (void)addCharacterToTextView:(NSString*)character {
    UITextView *textView = [self textViewAtIndex:self.currentlySelectedTextViewIndexPath];
    // as per: http://stackoverflow.com/questions/618759/getting-cursor-position-in-a-uitextview-on-the-iphone/619187#619187
    if (textView) {
        NSRange cursorPosition = [textView selectedRange];
        if (cursorPosition.location == NSNotFound) {
            textView.text = [textView.text stringByAppendingString:character]; 
        } else {
            NSMutableString *tfContent = [[NSMutableString alloc] initWithString:[textView text]];
            if (cursorPosition.length > 0) {
                [tfContent replaceCharactersInRange:cursorPosition withString:character];
            } else {
                [tfContent insertString:character atIndex:cursorPosition.location];
            }
            [textView setText:tfContent];
            [textView setSelectedRange:NSMakeRange(cursorPosition.location+1, 0)];
        }
    }
}

# pragma mark -
# pragma mark Alert functions

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 1) {
        [self returnToImportView];
        return;
        
    }
}


# pragma mark -
# pragma mark Event functions

- (void)cancelEvent {
    CardSetImportViewController *vc = (CardSetImportViewController*)[FlashCardsCore parentViewController];
    [vc clearCardSetActionData];
    [self.navigationController popToViewController:[[self.navigationController viewControllers] objectAtIndex:popToViewControllerIndex] animated:YES];
}

- (void)saveEvent {
    [self resignAllTextViews];
    
    [self saveMergeChoices];
    
    if ([self numDuplicateCards] > 0 && ![self allDuplicateCardsChecked]) {
        // alert message that they haven't finished!
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Are you done merging?", @"CardManagement", @"UIAlert title")
                                                         message:[NSString stringWithFormat:NSLocalizedStringFromTable(@"It looks like you haven't checked all %d duplicate cards. Are you sure you want to exit the merging screen?", @"CardManagement", @"message"), [self numDuplicateCards] ]
                                                        delegate:self
                                               cancelButtonTitle:NSLocalizedStringFromTable(@"I'm Not Done", @"CardManagement", @"cancelButtonTitle")
                                               otherButtonTitles:NSLocalizedStringFromTable(@"I'm Done", @"CardManagement", @"otherButtonTitles"), nil];
        [alert show];
        return;
    }
    
    [self returnToImportView];
    return;
}

- (void)returnToImportView {
    // TODO: Go back to the main import view
    /*
     // Flip back to the front view:
     [UIView beginAnimations:nil context:nil];
     [UIView setAnimationDuration:1.0];
     [UIView setAnimationTransition:UIViewAnimationTransitionFlipFromLeft
     forView:[self view] cache:YES];
     
     [mergeView removeFromSuperview];
     [UIView commitAnimations];
     */
    
    // self.title = importFromWebsite;
    
    // [self saveCards:termsList];

    NSArray *viewControllers = self.navigationController.viewControllers;
    CardSetImportViewController *vc = [viewControllers objectAtIndex:([viewControllers count]-2)];
    [vc.currentlyImportingSet setFlashCards:self.termsList];
    vc.shouldImmediatelyImportTerms = YES;
    vc.shouldImmediatelyPressImportButton = NO;
    
    [self.navigationController popViewControllerAnimated:YES];
}

- (IBAction)switchDidChange:(id)sender {
    ImportTerm *term = [self currentTerm];
    [self resignAllTextViews];
    if ([sender isEqual:mergeSwitch]) {
        if ([sender isOn]) {
            // if we are turning on merging, and the values match *exactly*,
            // then by default we should merge that side of the card:
            if ([[[[term currentCardInMOC:[FlashCardsCore mainMOC]] frontValue] lowercaseString] isEqual:[term.importTermFrontValue lowercaseString]]) {
                [mergeFrontSwitch setOn:YES];
                term.mergeCardFront = mergeCardEdit;
            }
            if ([[[[term currentCardInMOC:[FlashCardsCore mainMOC]] backValue] lowercaseString] isEqual:[term.importTermBackValue lowercaseString]]) {
                [mergeBackSwitch setOn:YES];
                term.mergeCardBack = mergeCardEdit;
            }
        }
        [self.myTableView reloadData];
    }
    if ([sender isEqual:mergeFrontSwitch]) {
        if ([sender isOn]) {
            term.mergeCardFront = mergeCardEdit;
        } else {
            term.mergeCardFront = mergeCardNew;
        }
        [mergedCardFrontValueTextView resignFirstResponder];
        [self.myTableView reloadSections:[NSIndexSet indexSetWithIndex:1]
                    withRowAnimation:UITableViewRowAnimationNone];
        // [mergedCardFrontValueTextView becomeFirstResponder];
    }
    if ([sender isEqual:mergeBackSwitch]) {
        if ([sender isOn]) {
            term.mergeCardBack = mergeCardEdit;
        } else {
            term.mergeCardBack = mergeCardNew;
        }
        [mergedCardBackValueTextView resignFirstResponder];
        [self.myTableView reloadSections:[NSIndexSet indexSetWithIndex:2]
                        withRowAnimation:UITableViewRowAnimationNone];
        // [mergedCardBackValueTextView becomeFirstResponder];
    }
}

- (void)resignAllTextViews {
    self.canResignTextView = YES;
    [remoteCardFrontValueTextView resignFirstResponder];
    [remoteCardBackValueTextView resignFirstResponder];
    [oldCardFrontValueTextView resignFirstResponder];
    [oldCardBackValueTextView resignFirstResponder];
    [mergedCardFrontValueTextView resignFirstResponder];
    [mergedCardBackValueTextView resignFirstResponder];
}

- (NSString*)syncExplanationString {
    BOOL remoteCardWillSync = NO;
    BOOL localCardWillSync = NO;
    ImportTerm *term = [self currentTerm];
    if ([term.importSet willSync]) {
        remoteCardWillSync = YES;
    }
    if ([[[term currentCardInMOC:[FlashCardsCore mainMOC]] shouldSync] boolValue]) {
        localCardWillSync = YES;
    }
    if (!remoteCardWillSync && !localCardWillSync) {
        return @"";
    }
/*
    
    You have chosen to keep the current card in sync with Quizlet.
*/
    NSMutableString *explanation = [NSMutableString stringWithString:@""];

    int count = (int)[[self.navigationController viewControllers] count];
    CardSetImportViewController *vc = (CardSetImportViewController*)[[self.navigationController viewControllers] objectAtIndex:(count-2)];
    NSString *service = @"";
    if ([vc.importMethod isEqualToString:@"quizlet"]) {
        service = @"Quizlet";
    }
    
    if (localCardWillSync && remoteCardWillSync) {
        [explanation appendString:[NSString stringWithFormat:NSLocalizedStringFromTable(@"You have chosen to sync the current card and the new card set with %@. By merging these cards, any changes you make to either card will be uploaded automatically to both of the original card sets on %@.", @"Import", @""), service, service]];
    } else {
        if (localCardWillSync) {
            [explanation appendString:[NSString stringWithFormat:NSLocalizedStringFromTable(@"You have chosen to sync the new card set with %@.", @"Import", @""), service]];
        } else if (remoteCardWillSync) {
            [explanation appendString:[NSString stringWithFormat:NSLocalizedStringFromTable(@"You have chosen to sync the current card with %@.", @"Import", @""), service]];
        }
        [explanation appendFormat:@" %@", NSLocalizedStringFromTable(@"By merging these cards, any changes you make will be uploaded automatically to the internet.", @"Import", @"")];
    }
    return [NSString stringWithString:explanation];
}

# pragma mark -
# pragma mark Merge functions

- (BOOL)mergingWillUpdateTheWeb {
    ImportTerm *term = [self currentTerm];
    if ([term.importSet willSync]) {
        return YES;
    }
    if ([[[term currentCardInMOC:[FlashCardsCore mainMOC]] shouldSync] boolValue]) {
        return YES;
    }
    return NO;
}

- (void) mergeNextPrevCardAction {
    // Save the merge choices FIRST, before we move the index field away from the current card:
    [self saveMergeChoices];
    // Move to the next card:
    // index 0 = "< Prev"
    int transition;
    if ([mergePrevNextSegmentedControl selectedSegmentIndex] == 0) {
        duplicateCardsIndex--;
        if (duplicateCardsIndex < 0) {
            duplicateCardsIndex = [duplicateCards count] - 1;
        }
        transition = UIViewAnimationTransitionCurlDown;
    } else {
        // index 1 = "Next >"
        duplicateCardsIndex += 1;
        if (duplicateCardsIndex >= [duplicateCards count]) {
            duplicateCardsIndex = 0;
        }
        transition = UIViewAnimationTransitionCurlUp;
    }
    // Set up the view with the new data:
    [self configureMergeLabels];
    
    [self resignAllTextViews];
    
    NSIndexPath *topIndexPath = [NSIndexPath indexPathForRow:0 inSection:0];
    [self.myTableView scrollToRowAtIndexPath:topIndexPath atScrollPosition:UITableViewScrollPositionTop animated:YES];
    
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationDuration:0.60];
    [UIView setAnimationTransition:transition forView:[self view] cache:YES];
    [UIView commitAnimations];
    
}

- (void)saveMergeChoices {
    ImportTerm *term = [self currentTerm];
    if ([mergeSwitch isOn]) {
        term.mergeChoice = mergeCardsChoice;
    } else {
        term.mergeChoice = dontMergeCardsChoice;
    }
    term.isDuplicateChecked = YES;
    
    if (term.mergeChoice == dontMergeCardsChoice) {
        term.markRelated = [markRelatedSwitch isOn];
    } else {
        term.markRelated = NO;
        if ([resetStatisticsSwitch isOn]) {
            term.resetStatistics = YES;
        } else {
            term.resetStatistics = NO;
        }
        if ([mergeFrontSwitch isOn]) {
            term.mergeCardFront = mergeCardEdit;
        }
        if ([mergeBackSwitch isOn]) {
            term.mergeCardBack = mergeCardEdit;
        }
    }
    
    // If we are editing the text, save the edits in the object:
    if (term.mergeChoice == mergeCardsChoice) {
        if (term.mergeCardFront == mergeCardEdit) {
            term.editedTermFrontValue = mergedCardFrontValueTextView.text;
        } else {
            term.editedTermFrontValue = @"";
        }
        if (term.mergeCardBack == mergeCardEdit) {
            term.editedTermBackValue = mergedCardBackValueTextView.text;
        } else {
            term.editedTermBackValue = @"";
        }
    } else {
        term.editedTermFrontValue = @"";
        term.editedTermBackValue = @"";
    }
}

- (void) configureMergeLabels {
    
    self.title = [NSString stringWithFormat:NSLocalizedStringFromTable(@"Merge %d of %d", @"CardManagement", @"UIView title"), (duplicateCardsIndex+1), [duplicateCards count]];
    
    ImportTerm* term = [self currentTerm];
    
    // set the merge choice based on what the user entered:
    // TODO:
    // [mergeOptions setSelectedSegmentIndex:term.mergeChoice];
    // [self mergeOptionsAction];
    
    
    [markRelatedSwitch setOn:term.markRelated];
    [mergeSwitch setOn:(term.mergeChoice == mergeCardsChoice)];
    [resetStatisticsSwitch setOn:term.resetStatistics];

    [mergeFrontSwitch setOn:(term.mergeCardFront == mergeCardEdit)];
    [mergeBackSwitch  setOn:(term.mergeCardBack == mergeCardEdit)];
    
    // set the labels for the Merge view:
    [oldCardFrontValueTextView setText:[[term currentCardInMOC:[FlashCardsCore mainMOC]] frontValue]];
    [oldCardBackValueTextView  setText:[[term currentCardInMOC:[FlashCardsCore mainMOC]] backValue]];

    [remoteCardFrontValueTextView setText:term.importTermFrontValue];
    [remoteCardBackValueTextView  setText:term.importTermBackValue];
    
    [mergedCardFrontValueTextView setText:([term.editedTermBackValue length] > 0 ?
                                           term.editedTermBackValue :
                                           [self mergeString:[[term currentCardInMOC:[FlashCardsCore mainMOC]] frontValue]
                                                  withString:term.importTermFrontValue])];
    [mergedCardBackValueTextView  setText:([term.editedTermBackValue length]  > 0 ? 
                                           term.editedTermBackValue  :
                                           [self mergeString:[[term currentCardInMOC:[FlashCardsCore mainMOC]] backValue]
                                                  withString:term.importTermBackValue])];
    
    [self setTextViewSize:mergedCardFrontValueTextView];
    [self setTextViewSize:mergedCardBackValueTextView];
    
    [self.myTableView reloadData];
}

# pragma mark -
# pragma mark Duplicate cards functions

- (int)numDuplicateCards {
    int count = 0;
    ImportTerm *term;
    for (int i = 0; i < [termsList count]; i++) {
        term = [termsList objectAtIndex:i];
        if (term.matchesOnlineCardId) {
            continue;
        }
        if (term.isDuplicate && !(autoMergeIdenticalCards && term.isExactDuplicate)) {
            count++;
        }
    }
    return count;
}

- (BOOL)allDuplicateCardsChecked {
    ImportTerm *term;
    for (int i = 0; i < [termsList count]; i++) {
        term = [termsList objectAtIndex:i];
        if (term.matchesOnlineCardId) {
            continue;
        }
        if (term.isDuplicate && !term.isDuplicateChecked && !(autoMergeIdenticalCards && term.isExactDuplicate)) {
            return NO;
        }
    }
    return YES;
}

- (ImportTerm*)currentTerm {
    ImportTerm* term = (ImportTerm*)[termsList objectAtIndex:[[duplicateCards objectAtIndex:duplicateCardsIndex] intValue]];
    return term;
}

# pragma mark -
# pragma mark Background tap functions

- (IBAction)doneEditing:(id)sender {
    [sender resignFirstResponder];
}

- (IBAction)mergeViewBackgroundTap:(id)sender {
    [self resignAllTextViews];
}

#pragma mark -
#pragma mark Table view data source


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        default:
        case 0: // primary merge options 
            if ([mergeSwitch isOn]) { // you are merging
                return 2; // merge switch & reset stats switch
            } else { // you are not merging
                return 2; // merge switch & mark cards switch
            }
            break;
        case 1: // new card OR front of card
            if (![mergeSwitch isOn]) {
                // we are displaying the new card, so two items:
                return 2;
            } else if (![mergeFrontSwitch isOn]) {
                // we are not merging the front, so we should display three options,
                // the merge switch, and the new and old values:
                return 3;
            } else {
                // we are merging the front, so display two options, the merge switch & edit:
                return 2;
            }
            break;
        case 2:
            if (![mergeSwitch isOn]) {
                // we are displaying the old card, so two items:
                return 2;
            } else if (![mergeBackSwitch isOn]) {
                // we are not merging the front, so we should display three options,
                // the merge switch, and the new and old values:
                return 3;
            } else {
                // we are merging the front, so display two options, the merge switch & edit:
                return 2;
            }
            break;
    }
    return 0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return 0;
    }
    return 30;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return nil;
    }
    UIView* customView = [[UIView alloc] initWithFrame:CGRectMake(10.0, 0.0, 300.0, 30.0)];
    
    // create the button object
    UILabel * headerLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    headerLabel.backgroundColor = [UIColor clearColor];
    headerLabel.opaque = NO;
    headerLabel.textColor = [UIColor blackColor];
    headerLabel.highlightedTextColor = [UIColor whiteColor];
    headerLabel.font = [UIFont boldSystemFontOfSize:19];
    if ([FlashCardsAppDelegate isIpad]) {
        headerLabel.frame = CGRectMake(60.0, 0.0, 300.0, 30.0);
    } else {
        headerLabel.frame = CGRectMake(10.0, 0.0, 300.0, 30.0);
    }
    switch (section) {
        default:
        case 1: // new card OR front of card
            if (![mergeSwitch isOn]) {
                // we are merging the cards, so the two sections are 'new card' and 'old card':
                headerLabel.text = NSLocalizedStringFromTable(@"New Card", @"Import", @"");
            } else {
                // we are not merging the cards, so the two sections are 'front' and ;back'
                headerLabel.text = NSLocalizedStringFromTable(@"Front Side of Card", @"CardManagement", @"headerLabel");
            }
            break;
        case 2:
            if (![mergeSwitch isOn]) {
                // we are merging the cards, so the two sections are 'new card' and 'old card':
                headerLabel.text = NSLocalizedStringFromTable(@"Current Card", @"Import", @"");
            } else {
                // we are not merging the cards, so the two sections are 'front' and ;back'
                headerLabel.text = NSLocalizedStringFromTable(@"Back Side of Card", @"CardManagement", @"headerLabel");
            }
            break;
    }
    [customView addSubview:headerLabel];
    
    return customView;
}

- (CGFloat)tableView:(UITableView  *)tableView heightForRowAtIndexPath:(NSIndexPath  *)indexPath {
    if (indexPath.section == 0) {
        // always show the proper row height for merge option rows:
        return 44;
    }
    if (![mergeSwitch isOn] && indexPath.row == 0) {
        // it's not merging the whole card, so we are first displaying the "Merge Front/Back?" item:
        return 44;
    }
    UITextView *textView = [self textViewAtIndex:indexPath];
    if (!textView) {
        return 44;
    }
    int height;
    [self setTextViewSize:textView];
    height = textView.frame.size.height + 12;
    if (height < 44) {
        height = 44;
        [textView setFrame:CGRectMake(textView.frame.origin.x,
                                      textView.frame.origin.y,
                                      textView.frame.size.width,
                                      44-12)];
    }
    return (CGFloat)height;
    return 44;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    if (section == 0) {
        // if the card is set to merge, and EITHER the new card set is set to sync, or the old card set
        // is set to sync, it will alert you that any changes you make will upload to the web.
        if ([self mergingWillUpdateTheWeb] && [mergeSwitch isOn]) {
            NSString *explanation = [self syncExplanationString];
            if ([explanation length] == 0) {
                return 0.0;
            }
            
            // create the button object
            UITextView * footerLabel = [[UITextView alloc] initWithFrame:CGRectMake(0.0f,
                                                                                    0.0f,
                                                                                    self.view.frame.size.width-16.0,
                                                                                    0.0f)];
            footerLabel.backgroundColor = [UIColor clearColor];
            footerLabel.opaque = NO;
            footerLabel.textColor = [UIColor blackColor];
            footerLabel.text = explanation;
            [footerLabel setFont:[UIFont systemFontOfSize:12.0f]];
            [footerLabel setTextAlignment:NSTextAlignmentCenter];
            
            CGSize tallerSize, stringSize;
            tallerSize = CGSizeMake(self.view.frame.size.width-16.0, kMaxFieldHeight);
            CGRect boundingRect = [footerLabel.text boundingRectWithSize:tallerSize
                                                                 options:NSStringDrawingUsesLineFragmentOrigin
                                                              attributes:@{NSFontAttributeName:footerLabel.font}
                                                                 context:nil];
            stringSize = boundingRect.size;
            return stringSize.height+10.0f;
        }
    }
    return 0;
}

- (UIView*)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    if (section == 0) {
        // if the card is set to merge, and EITHER the new card set is set to sync, or the old card set
        // is set to sync, it will alert you that any changes you make will upload to the web.
        if ([self mergingWillUpdateTheWeb] && [mergeSwitch isOn]) {
            NSString *explanation = [self syncExplanationString];
            if ([explanation length] == 0) {
                return nil;
            }
            
            // create the button object
            UITextView * footerLabel = [[UITextView alloc] initWithFrame:CGRectMake(0.0f,
                                                                                    0.0f,
                                                                                    self.view.frame.size.width-16.0,
                                                                                    0.0f)];
            footerLabel.backgroundColor = [UIColor clearColor];
            footerLabel.opaque = NO;
            footerLabel.textColor = [UIColor blackColor];
            footerLabel.text = explanation;
            [footerLabel setFont:[UIFont systemFontOfSize:12.0f]];
            [footerLabel setTextAlignment:NSTextAlignmentCenter];
            footerLabel.userInteractionEnabled = NO;
            
            CGSize tallerSize, stringSize;
            tallerSize = CGSizeMake(self.view.frame.size.width-16.0, kMaxFieldHeight);
            CGRect boundingRect = [footerLabel.text boundingRectWithSize:tallerSize
                                                                 options:NSStringDrawingUsesLineFragmentOrigin
                                                              attributes:@{NSFontAttributeName:footerLabel.font}
                                                                 context:nil];
            stringSize = boundingRect.size;
            [footerLabel setFrame:CGRectMake(footerLabel.frame.origin.x,
                                             footerLabel.frame.origin.y,
                                             footerLabel.frame.size.width,
                                             stringSize.height+10.0f)];
            
            return footerLabel;
        }
    }
    return nil;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        // always show the proper row height for merge option rows:
        if (indexPath.row == 0) {
            return mergeCell;
        } else {
            if ([mergeSwitch isOn]) { // you are merging, show the "Reset Stat" cell
                return resetStatisticsCell;
            } else { // you are not merging, show the "Mark Related" cell
                return markRelatedCell;
            }
        }
    }
    ImportTerm *term = [self currentTerm];
    switch (indexPath.section) {
        default:
        case 1: // new card, OR front of card
            if (![mergeSwitch isOn]) {
                // we are displaying the new card, so two items:
                if (indexPath.row == 0) {
                    remoteCardFrontValueLabel.text = NSLocalizedStringFromTable(@"Front", @"Study", @"");
                    remoteCardFrontValueTextView.indexPath = indexPath;
                    remoteCardFrontValueTextView.userInteractionEnabled = NO;
                    [self tableViewCell:remoteCardFrontValueCell setSelected:NO];
                    return remoteCardFrontValueCell;
                } else {
                    remoteCardBackValueLabel.text = NSLocalizedStringFromTable(@"Back", @"Study", @"");
                    remoteCardBackValueTextView.indexPath = indexPath;
                    remoteCardBackValueTextView.userInteractionEnabled = NO;
                    [self tableViewCell:remoteCardBackValueCell setSelected:NO];
                    return remoteCardBackValueCell;
                }
            } else if (indexPath.row == 0) {
                // it's not merging the whole card, so we are first displaying the "Merge Front?" item:
                return mergeFrontCell;
            } else if (![mergeFrontSwitch isOn]) {
                // we are not merging the front, so we should display 
                if (indexPath.row == 1) {
                    // this is the "Merge Front"?
                    remoteCardFrontValueLabel.text = NSLocalizedStringFromTable(@"New", @"Import", @"");
                    remoteCardFrontValueTextView.indexPath = indexPath;
                    remoteCardFrontValueTextView.userInteractionEnabled = NO;
                    [self tableViewCell:remoteCardFrontValueCell setSelected:(term.mergeCardFront == mergeCardNew)];
                    return remoteCardFrontValueCell;
                } else {
                    oldCardFrontValueLabel.text = NSLocalizedStringFromTable(@"Current", @"Import", @"");
                    oldCardFrontValueTextView.indexPath = indexPath;
                    oldCardFrontValueTextView.userInteractionEnabled = NO;
                    [self tableViewCell:oldCardFrontValueCell setSelected:(!(term.mergeCardFront == mergeCardNew))];
                    return oldCardFrontValueCell;
                }
            } else {
                // we are merging the front, so display two options, the merge switch & edit:
                mergedCardFrontValueLabel.text = NSLocalizedStringFromTable(@"Text", @"CardManagement", @"");
                mergedCardFrontValueTextView.indexPath = indexPath;
                mergedCardFrontValueTextView.userInteractionEnabled = YES;
                return mergedCardFrontValueCell;
            }
            break;
        case 2: // current card, OR back of card:
            if (![mergeSwitch isOn]) {
                // we are displaying the new card, so two items:
                if (indexPath.row == 0) {
                    oldCardFrontValueLabel.text = NSLocalizedStringFromTable(@"Front", @"Study", @"");
                    oldCardFrontValueTextView.indexPath = indexPath;
                    oldCardFrontValueTextView.userInteractionEnabled = NO;
                    [self tableViewCell:oldCardFrontValueCell setSelected:NO];
                    return oldCardFrontValueCell;
                } else {
                    oldCardBackValueLabel.text = NSLocalizedStringFromTable(@"Back", @"Study", @"");
                    oldCardBackValueTextView.indexPath = indexPath;
                    oldCardBackValueTextView.userInteractionEnabled = NO;
                    [self tableViewCell:oldCardBackValueCell setSelected:NO];
                    return oldCardBackValueCell;
                }
            } else if (indexPath.row == 0) {
                // it's not merging the whole card, so we are first displaying the "Merge Front?" item:
                return mergeBackCell;
            } else if (![mergeBackSwitch isOn]) {
                // we are not merging the front, so we should display 
                if (indexPath.row == 1) {
                    // this is the "Merge Back"?
                    remoteCardBackValueLabel.text = NSLocalizedStringFromTable(@"New", @"Import", @"");
                    remoteCardBackValueTextView.indexPath = indexPath;
                    remoteCardBackValueTextView.userInteractionEnabled = NO;
                    [self tableViewCell:remoteCardBackValueCell setSelected:(term.mergeCardBack == mergeCardNew)];
                    return remoteCardBackValueCell;
                } else {
                    oldCardBackValueLabel.text = NSLocalizedStringFromTable(@"Current", @"Import", @"");
                    oldCardBackValueTextView.indexPath = indexPath;
                    oldCardBackValueTextView.userInteractionEnabled = NO;
                    [self tableViewCell:oldCardBackValueCell setSelected:(!(term.mergeCardBack == mergeCardNew))];
                    return oldCardBackValueCell;
                }
            } else {
                // we are merging the front, so display two options, the merge switch & edit:
                mergedCardBackValueLabel.text = NSLocalizedStringFromTable(@"Text", @"CardManagement", @"");
                mergedCardBackValueTextView.userInteractionEnabled = YES;
                mergedCardBackValueTextView.indexPath = indexPath;
                return mergedCardBackValueCell;
            }
            break;
    }
    return nil;
}


- (void)tableViewCell:(UITableViewCell*)cell setSelected:(bool)isSelected {
    UIColor *textColor, *backgroundColor;
    if (isSelected) {
        textColor = [UIColor whiteColor];
        backgroundColor = [UIColor blueColor];
    } else {
        textColor = [UIColor blackColor];
        backgroundColor = [UIColor whiteColor];
    }

    UITextView *textView;
    UILabel *label;
    if ([cell isEqual:remoteCardFrontValueCell]) {
        textView = remoteCardFrontValueTextView;
        label = remoteCardFrontValueLabel;
    } else if ([cell isEqual:remoteCardBackValueCell]) {
        textView = remoteCardBackValueTextView;
        label = remoteCardBackValueLabel;
    } else if ([cell isEqual:oldCardFrontValueCell]) {
        textView = oldCardFrontValueTextView;
        label = oldCardFrontValueLabel;
    } else if ([cell isEqual:oldCardBackValueCell]) {
        textView = oldCardBackValueTextView;
        label = oldCardBackValueLabel;
    }
    cell.backgroundColor = backgroundColor;
    if (textView) {
        textView.backgroundColor = backgroundColor;
        textView.textColor = textColor;
    }
    if (label) {
        label.backgroundColor = backgroundColor;
        label.textColor = textColor;
    }
    /*
    if (isSelected) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
        cell.backgroundColor = [UIColor blueColor];
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.backgroundColor = [UIColor whiteColor];
    }
     */
}


#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

    if (![mergeSwitch isOn]) {
        return;
    }
    ImportTerm *term = [self currentTerm];
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    if ([cell isEqual:remoteCardFrontValueCell]) {
        if ([mergeFrontSwitch isOn]) {
            return;
        }
        [self tableViewCell:oldCardFrontValueCell setSelected:NO];
        [self tableViewCell:remoteCardFrontValueCell setSelected:YES];
        term.mergeCardFront = mergeCardNew;
    } else if ([cell isEqual:remoteCardBackValueCell]) {
        if ([mergeBackSwitch isOn]) {
            return;
        }
        [self tableViewCell:oldCardBackValueCell setSelected:NO];
        [self tableViewCell:remoteCardBackValueCell setSelected:YES];
        term.mergeCardBack = mergeCardNew;
    } else if ([cell isEqual:oldCardFrontValueCell]) {
        [self tableViewCell:oldCardFrontValueCell setSelected:YES];
        [self tableViewCell:remoteCardFrontValueCell setSelected:NO];
        term.mergeCardFront = mergeCardCurrent;
    } else if ([cell isEqual:oldCardBackValueCell]) {
        [self tableViewCell:oldCardBackValueCell setSelected:YES];
        [self tableViewCell:remoteCardBackValueCell setSelected:NO];
        term.mergeCardBack = mergeCardCurrent;
    }
}


# pragma mark -
# pragma mark Text View Functions

- (CGSize)textViewSize:(UITextView*)textView {
    float fudgeFactor = 16.0;
    CGSize tallerSize = CGSizeMake(textView.frame.size.width-fudgeFactor, kMaxFieldHeight);
    NSString *testString = @" ";
    if ([textView.text length] > 0) {
        testString = textView.text;
    }
    CGSize stringSize;
    
    CGRect boundingRect = [testString boundingRectWithSize:tallerSize
                                                         options:NSStringDrawingUsesLineFragmentOrigin
                                                      attributes:@{NSFontAttributeName:textView.font}
                                                         context:nil];
    stringSize = boundingRect.size;
    return stringSize;
}

- (void) setTextViewSize:(UITextView*)textView {
    CGSize stringSize = [self textViewSize:textView];
    if (stringSize.height != textView.frame.size.height) {
        [textView setFrame:CGRectMake(textView.frame.origin.x,
                                      textView.frame.origin.y,
                                      textView.frame.size.width,
                                      stringSize.height+10)];        
    }
}

# pragma mark -
# pragma mark Text view delegate

- (void)keyboardShown {
    myTableView.frame = CGRectMake(myTableView.frame.origin.x,
                                   myTableView.frame.origin.y, 
                                   myTableView.frame.size.width,
                                   myTableView.frame.size.height - 215 - 44 + 50); //resize
}

- (void)keyboardHidden {
    myTableView.frame = CGRectMake(myTableView.frame.origin.x,
                                   myTableView.frame.origin.y, 
                                   myTableView.frame.size.width,
                                   myTableView.frame.size.height + 215 + 44 - 50); //resize
}

- (void)textViewDidBeginEditing:(UITextView *)textView {
    if (((GrowableTextView*)textView).indexPath) {
        [myTableView scrollToRowAtIndexPath:((GrowableTextView*)textView).indexPath atScrollPosition:UITableViewScrollPositionTop animated:YES];
        self.currentlySelectedTextViewIndexPath = ((GrowableTextView*)textView).indexPath;
    }
    self.canResignTextView = NO;
}

- (void)textViewDidEndEditing:(UITextView *)textView {
    self.currentlySelectedTextViewIndexPath = nil;
}

// as per: http://stackoverflow.com/questions/3749746/uitextview-in-a-uitableviewcell-smooth-auto-resize
- (void)textViewDidChange:(UITextView *)textView {
    
    [self setTextViewSize:textView];
    UIView *contentView = textView.superview;
    if ((textView.frame.size.height + 12.0f) != contentView.frame.size.height) {
        
        [myTableView beginUpdates];
        [myTableView endUpdates];
        
        [contentView setFrame:CGRectMake(0,
                                         0,
                                         contentView.frame.size.width,
                                         (textView.frame.size.height+12.0f))];
        
    }
    // TODO
    /*
    if (textView == frontTextView) {
        [cardData setValue:textView.text forKey:@"frontValue"];
    } else {
        [cardData setValue:textView.text forKey:@"backValue"];
    }*/
}

-(BOOL) textViewShouldBeginEditing:(UITextView *)textView {
    
    textView.inputAccessoryView = accessoryView;    
    
    if (self.currentlySelectedTextViewIndexPath) {
        self.canResignTextView = YES;
    }
    return YES;
}

-(BOOL) textViewShouldEndEditing:(UITextView *)textView {
    return self.canResignTextView;
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




@end
