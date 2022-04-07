//
//  CardEditViewController.m
//  FlashCards
//
//  Created by Jason Lustig on 5/28/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//


#import <QuartzCore/QuartzCore.h>

#import "FlashCardsAppDelegate.h"
#import "CardEditViewController.h"
#import "StudyViewController.h"
#import "CardStatisticsViewController.h"
#import "DictionaryLookupViewController.h"
#import "RelatedCardsViewController.h"
#import "CardEditCardSetsViewController.h"
#import "CardSelectImageViewController.h"

#import "StudyViewController.h"

#import "SubscriptionViewController.h"

#import "Swipeable.h"
#import "FCCard.h"
#import "FCCardSetCard.h"
#import "FCCardSet.h"
#import "FCCollection.h"
#import "CardTest.h"
#import "FlashCardsCore.h"
#import "UIView+Layout.h"
#import "UIAlertView+Blocks.h"
#import "NSString+Languages.h"

#import "GrowableTextView.h"

#import "MBProgressHUD.h"

#import <AddressBook/AddressBook.h>
#import <AVFoundation/AVAudioPlayer.h>
#import <AVFoundation/AVAudioSession.h>
#import <UIKit/UIKit.h>

#import "QuizletSync.h"
#import "QuizletRestClient.h"

#import "FCCardSet.h"

#import "DTVersion.h"

@implementation CardEditViewController

@synthesize myTableView, myTableViewFooter, deleteCardButton;
@synthesize frontTextTableCell, frontTextView, backTextTableCell, backTextView;
@synthesize backImageTableCell, backImageView, frontImageTableCell, frontImageView, frontNoImageLabel, backNoImageLabel;
@synthesize wordTypeOptions, accessoryView;
@synthesize accessoryViewLatex;
@synthesize frontAudioTableCell, frontAudioLabel, frontAudioDescriptionLabel;
@synthesize backAudioTableCell, backAudioLabel, backAudioDescriptionLabel;
@synthesize audioRecordingKey;
@synthesize audioRecorder, audioPlayer;

@synthesize editMode;
@synthesize card, cardData, cardSet, collection, cardList, cardIndex, cardListEdited;
@synthesize saveButton, prevNextSegmentedControl, prevNextToolbar, mainCardToolbar;
@synthesize editInPlace, hasAdjustedFrontFieldWidth, isAttemptingDelete, canResignTextView, hasFirstLoaded, popToViewControllerIndex;
@synthesize currentlySelectedTextViewIndexPath;
/*
#if TARGET_IPHONE_SIMULATOR
#else
@synthesize textExpander;
#endif
*/
@synthesize backImageLabel;
@synthesize frontImageLabel;
@synthesize backTextLabel;
@synthesize frontTextLabel;
@synthesize cardSetsButton;
@synthesize cardStatisticsButton;
@synthesize relatedCardsButton;
@synthesize hasAlreadyLoaded;
@synthesize HUD;
@synthesize quizletSync;

@synthesize hasDisplayedUnlimitedCardsMessage;

/*
 // The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        // Custom initialization
    }
    return self;
}
*/

- (void)hideMyTableViewFooter {
    CGRect frame = myTableViewFooter.frame;
    frame.size.height = 0.0;
    [myTableViewFooter setFrame:frame];
    myTableViewFooter.hidden = YES;
    deleteCardButton.hidden = YES;
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    if (![DTVersion osVersionIsLessThen:@"7.0"]) {
        self.edgesForExtendedLayout= UIRectEdgeNone;
    }
    
    hasDisplayedUnlimitedCardsMessage = NO;
    
    [backImageLabel setAccessibilityLabel:NSLocalizedStringFromTable(@"Image", @"CardManagement", @"UILabel")];
    [frontImageLabel setAccessibilityLabel:NSLocalizedStringFromTable(@"Image", @"CardManagement", @"UILabel")];
    [backTextLabel setAccessibilityLabel:NSLocalizedStringFromTable(@"Text", @"CardManagement", @"UILabel")];
    [frontTextLabel setAccessibilityLabel:NSLocalizedStringFromTable(@"Text", @"CardManagement", @"UILabel")];

    if ([FlashCardsAppDelegate isIpad]) {
        [cardSetsButton setImage:nil];
        [cardStatisticsButton setImage:nil];
        [relatedCardsButton setImage:nil];
        cardSetsButton.title = NSLocalizedStringFromTable(@"Card Sets", @"CardManagement", @"UILabel");
        cardStatisticsButton.title = NSLocalizedStringFromTable(@"Card Statistics", @"CardManagement", @"UILabel");
        relatedCardsButton.title = NSLocalizedStringFromTable(@"Related Cards", @"CardManagement", @"UIBarButtonItem");
    } else {
        [cardSetsButton setAccessibilityLabel:NSLocalizedStringFromTable(@"Card Sets", @"CardManagement", @"UILabel")];
        [cardStatisticsButton setAccessibilityLabel:NSLocalizedStringFromTable(@"Card Statistics", @"CardManagement", @"UILabel")];
        [relatedCardsButton setAccessibilityLabel:NSLocalizedStringFromTable(@"Related Cards", @"CardManagement", @"UIBarButtonItem")];
    }
    
    [prevNextSegmentedControl setTitle:NSLocalizedStringFromTable(@"< Prev", @"Study", @"") forSegmentAtIndex:0];
    [prevNextSegmentedControl setTitle:NSLocalizedStringFromTable(@"Next >", @"Study", @"") forSegmentAtIndex:1];
    frontNoImageLabel.text = NSLocalizedStringFromTable(@"(no image, tap to add)", @"CardManagement", @"UILabel");
    backNoImageLabel.text = NSLocalizedStringFromTable(@"(no image, tap to add)", @"CardManagement", @"UILabel");
    
    [frontAudioLabel setAccessibilityLabel:NSLocalizedStringFromTable(@"Audio", @"CardManagement", @"UILabel")];
    [backAudioLabel setAccessibilityLabel:NSLocalizedStringFromTable(@"Audio", @"CardManagement", @"UILabel")];
    
    [deleteCardButton setTitle:NSLocalizedStringFromTable(@"Delete Card", @"CardManagement", @"UIButton") forState:UIControlStateNormal]; 
    [deleteCardButton setTitle:NSLocalizedStringFromTable(@"Delete Card", @"CardManagement", @"UIButton") forState:UIControlStateSelected];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receivedRotate:) name:UIDeviceOrientationDidChangeNotification object:NULL];
    
    bool autocorrectText = [(NSNumber*)[FlashCardsCore getSetting:@"shouldUseAutoCorrect"] boolValue];
    if (autocorrectText) {
        frontTextView.autocorrectionType = UITextAutocorrectionTypeYes;
        backTextView.autocorrectionType  = UITextAutocorrectionTypeYes;
    } else {
        frontTextView.autocorrectionType = UITextAutocorrectionTypeNo;
        backTextView.autocorrectionType  = UITextAutocorrectionTypeNo;
    }
    
    bool autocapitalizeText = [(NSNumber*)[FlashCardsCore getSetting:@"shouldUseAutoCapitalizeText"] boolValue];
    if (autocapitalizeText) {
        frontTextView.autocapitalizationType = UITextAutocapitalizationTypeSentences;
        backTextView.autocapitalizationType  = UITextAutocapitalizationTypeSentences;
    } else {
        frontTextView.autocapitalizationType = UITextAutocapitalizationTypeNone;
        backTextView.autocapitalizationType  = UITextAutocapitalizationTypeNone;
    }
/*
#if TARGET_IPHONE_SIMULATOR
#else
    textExpander = [[SMTEDelegateController alloc] init];
    
    [textExpander setNextDelegate:self];
    [frontTextView setDelegate:textExpander];
    [backTextView setDelegate:textExpander];
#endif
*/
    myTableView.resignObjectsOnTouchesEnded = [NSArray arrayWithObjects:frontTextView, backTextView, nil];
    myTableView.superviewController = self;
    
    self.canResignTextView = NO;
    backTextView.indexPath = [NSIndexPath indexPathForRow:0 inSection:1];
    frontTextView.indexPath = [NSIndexPath indexPathForRow:0 inSection:0];
    
    // set proper font sizes based on device:
    NSArray *allTextViews = [NSArray arrayWithObjects:
                             frontTextView, backTextView,
                             nil];
    NSArray *allLabels = [NSArray arrayWithObjects:
                          frontNoImageLabel, backNoImageLabel,
                          nil];
    int fontSize;
    if ([FlashCardsAppDelegate isIpad]) {
        fontSize = 17;
    } else {
        fontSize = 14;
    }
    for (UITextView *textView in allTextViews) {
        textView.font = [UIFont systemFontOfSize:fontSize];
    }
    for (UILabel *label in allLabels) {
        label.font = [UIFont systemFontOfSize:fontSize];
    }
    
    wordTypeOptions = [[NSArray alloc] initWithObjects:
                       NSLocalizedStringFromTable(@"Normal", @"CardManagement", @"word type"),
                       NSLocalizedStringFromTable(@"Cognate", @"CardManagement", @"word type"),
                       NSLocalizedStringFromTable(@"False Friend", @"CardManagement", @"word type"),
                       nil];

    if (self.editMode == modeEdit) {
        self.title = NSLocalizedStringFromTable(@"Edit Card", @"CardManagement", @"UIView title");
    } else {
        self.title = NSLocalizedStringFromTable(@"Create Card", @"CardManagement", @"UIView title");
    }
    
    if (editMode == modeCreate && !hasAlreadyLoaded) {
        [frontTextView becomeFirstResponder];
    }

    hasAdjustedFrontFieldWidth = NO;
    isAttemptingDelete = NO;
    
    UIBarButtonItem *button;

    if (editMode == modeCreate) {
        // when creating cards, have "Done" & "Next" buttons
        UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(saveEvent)];
        UIBarButtonItem *nextButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedStringFromTable(@"Next", @"Study", @"") style:UIBarButtonItemStyleBordered target:self action:@selector(nextEvent)];
        
        [self.navigationItem setRightBarButtonItems:@[doneButton, nextButton]];
        
    } else {
        button = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector(saveEvent)];
        button.enabled = YES;
        self.navigationItem.rightBarButtonItem = button;
    }
    
    button = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelEvent)];
    button.enabled = YES;
    self.navigationItem.leftBarButtonItem = button;
    
    if (!hasAlreadyLoaded || !cardData) {
        cardData = [[NSMutableDictionary alloc] initWithCapacity:0];
    }
    
    if (editMode == modeEdit) {
        if (cardList) {
            [cardList filterUsingPredicate:[NSPredicate predicateWithFormat:@"isDeletedObject = NO"]];
            mainCardToolbar.hidden = YES;
            prevNextToolbar.hidden = NO;
            [prevNextSegmentedControl addTarget:self action:@selector(prevNextCardAction) forControlEvents:UIControlEventValueChanged];
            cardListEdited = [[NSMutableArray alloc] initWithCapacity:0];
            // build array of yes/no - did we edit the cards?
            for (int i = 0; i < [cardList count]; i++) {
                [cardListEdited insertObject:[NSNumber numberWithBool:NO] atIndex:[cardListEdited count]];
            }
        } else {
            mainCardToolbar.hidden = NO;
            prevNextToolbar.hidden = YES;
            myTableViewFooter.hidden = NO;
            if (!hasAlreadyLoaded) {
                [self loadCardData:card];
            }
        }
    } else {
        // the user is creating a card, so:
        // (1) remove the "Card Stast" & "Card Sets" buttons:
        NSMutableArray *toolbarItems = [[NSMutableArray alloc] initWithCapacity:self.mainCardToolbar.items.count];
        [toolbarItems addObjectsFromArray:self.mainCardToolbar.items];
        [toolbarItems removeObjectAtIndex:3];
        [toolbarItems removeObjectAtIndex:2];
        [self.mainCardToolbar setItems:toolbarItems animated:NO];
        // (2) hide and show the proper items:
        mainCardToolbar.hidden = NO;
        prevNextToolbar.hidden = YES;
        [self hideMyTableViewFooter];
        if (!hasAlreadyLoaded) {
            [self loadCardData:nil];
        }
    }
    
    self.quizletSync = [[QuizletSync alloc] init];
    self.quizletSync.delegate = self;

}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    UIDeviceOrientation interfaceOrientation = [[UIDevice currentDevice] orientation];
    if (UIInterfaceOrientationIsLandscape(interfaceOrientation)) {
        accessoryView.hidden = YES;
        accessoryViewLatex.hidden = YES;
    } else {
        accessoryView.hidden = NO;
        accessoryViewLatex.hidden = NO;
    }

}

- (void)viewDidAppear:(BOOL)animated {
    [self configureCard:NO];
    [super viewDidAppear:animated];
    
    quizletSync.delegate = self;

    self.cardIndex = 0;
    [self configureCard:YES];
    
    hasAlreadyLoaded = YES;
    
    if ([card.isSubscribed boolValue]) {
        // display a message:
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@""
                                                        message:NSLocalizedStringFromTable(@"This card set is configured to subscribe to online changes. For this reason, you cannot edit the card locally as your changes may be overwritten by changes to the online set. If you would like, you can turn off the subscription but it will disable future online updates.", @"CardManagement", @"")
                                                       delegate:self
                                              cancelButtonTitle:NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"cancelButtonTitle")
                                              otherButtonTitles:NSLocalizedStringFromTable(@"Stop Subscription", @"CardManagement", @"otherButtonTitles"), nil];
        [alert show];
    }

}

- (void)viewWillDisappear:(BOOL)animated {
    // We must set self.canResignTextView to YES, so that if the user hits "Save" or "Cancel"
    // while a text view is firstResponder, then it will be able to give up its firstResponder
    // status. Otherwise, any other attempts to give a widget firstResponder status will fail
    // following this strange, strange situation!
    self.canResignTextView = YES;

    if (HUD) {
        HUD.delegate = nil;
    }
    quizletSync.delegate = nil;

    [super viewWillDisappear:animated];
}

- (IBAction)doneEditingKeyboard:(id)sender {
    canResignTextView = YES;
    UITextView *textView = nil;
    if (self.currentlySelectedTextViewIndexPath) {
        if (self.currentlySelectedTextViewIndexPath.section == 0) {
            textView = frontTextView;
        } else {
            textView = backTextView;
        }
    }
    if (textView) {
        [textView resignFirstResponder];
    } else {
        // should do something here
    }
}

- (IBAction)textViewTypeContents:(id)sender {
    UIBarButtonItem *item = (UIBarButtonItem*)sender;
    [self addCharacterToTextView:item.title];
}

- (void)addCharacterToTextView:(NSString*)character {
    UITextView *textView = nil;
    if (self.currentlySelectedTextViewIndexPath) {
        if (self.currentlySelectedTextViewIndexPath.section == 0) {
            textView = frontTextView;
        } else {
            textView = backTextView;
        }
    }
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
        if (textView == frontTextView) {
            [cardData setValue:textView.text forKey:@"frontValue"];
        } else {
            [cardData setValue:textView.text forKey:@"backValue"];
        }
    }
}


- (void)loadCardData:(FCCard*)_card {
    [cardData removeAllObjects];
    if (card) {
        [cardData setObject:_card.frontValue forKey:@"frontValue"];
        [cardData setObject:_card.backValue  forKey:@"backValue"];
        [cardData setObject:[NSMutableSet setWithSet:_card.relatedCards] forKey:@"relatedCards"];
        [cardData setValue: _card.frontImageData forKey:@"frontImageData"];
        [cardData setValue: _card.backImageData  forKey:@"backImageData"];
        [cardData setValue: _card.frontAudioData forKey:@"frontAudioData"];
        [cardData setValue: _card.backAudioData  forKey:@"backAudioData"];
        [cardData setObject:_card.wordType forKey:@"wordType"];
    } else {
        [cardData setObject:@"" forKey:@"frontValue"];
        [cardData setObject:@""  forKey:@"backValue"];
        [cardData setObject:[NSMutableSet setWithCapacity:0] forKey:@"relatedCards"];
        [cardData setObject:[NSMutableData dataWithLength:0] forKey:@"frontImageData"];
        [cardData setObject:[NSMutableData dataWithLength:0]  forKey:@"backImageData"];
        [cardData setObject:[NSMutableData dataWithLength:0] forKey:@"frontAudioData"];
        [cardData setObject:[NSMutableData dataWithLength:0]  forKey:@"backAudioData"];
        [cardData setObject:[NSNumber numberWithInt:wordTypeNormal] forKey:@"wordType"];
    }
}

#pragma mark -
#pragma mark Rotation functions

-(void) receivedRotate: (NSNotification*) notification {
    UIDeviceOrientation interfaceOrientation = [[UIDevice currentDevice] orientation];
    
    if (!(UIInterfaceOrientationIsPortrait(interfaceOrientation) || UIInterfaceOrientationIsLandscape(interfaceOrientation))) {
        return;
    }
    [self setTableCellImageView:frontImageView withImage:nil];
    [self setTableCellImageView:backImageView withImage:nil];
    
    [self.myTableView reloadData];
    
    if (![FlashCardsAppDelegate isIpad]) {
        if (UIInterfaceOrientationIsLandscape(interfaceOrientation)) {
            accessoryView.hidden = YES;
            accessoryViewLatex.hidden = YES;
        } else {
            accessoryView.hidden = NO;
            accessoryViewLatex.hidden = NO;
        }
    }
}

# pragma mark -
# pragma mark Alert functions

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (isAttemptingDelete) {
        if (buttonIndex == 1) {
            // Delete card

            // if we are editing the card in place, remove it from the study set:
            if (editMode == modeEdit && editInPlace) {
                StudyViewController *studyVC = (StudyViewController*)[FlashCardsCore parentViewController];
                [studyVC.studyController removeCardFromStudy:card];
            }
            
            SyncController *controller = [[FlashCardsCore appDelegate] syncController];
            if (controller && [card.shouldSync boolValue]) {
                for (FCCardSet *_cardSet in [card allCardSets]) {
                    if ([_cardSet isQuizletSet]) {
                        [controller setQuizletDidChange:YES];
                    }
                }
            }

            [card setIsDeletedObject:[NSNumber numberWithBool:YES]];
            NSSet *cardSets = [NSSet setWithSet:[card allCardSets]];
            for (FCCardSet *set in cardSets) {
                [set removeCard:card];
            }
            
            [FlashCardsCore saveMainMOC:NO];
            
            [card setSyncStatus:[NSNumber numberWithInt:syncChanged]];
            if ([card.shouldSync boolValue]) {
                for (FCCardSet *_cardSet in [card allCardSets]) {
                    if ([_cardSet isQuizletSet]) {
                        [_cardSet setSyncStatus:card.syncStatus];
                    }
                }
                [self tellParentToSync];
            }
            [self isDoneSaving:NO];
        } else {
            // Don't delete card
            isAttemptingDelete = NO;
        }
    } else {
        NSString *buttonTitle = [alertView buttonTitleAtIndex:buttonIndex];
        if ([buttonTitle isEqualToString:NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"cancelButtonTitle")]) {
            [self cancelEvent];
            return;
        }
        if ([buttonTitle isEqualToString:NSLocalizedStringFromTable(@"Stop Subscription", @"CardManagement", @"otherButtonTitles")]) {
            NSManagedObjectID *objectId = self.card.objectID;
            NSManagedObjectContext *tempMOC = [FlashCardsCore tempMOC];
            [tempMOC performBlock:^{
                FCCard *_card = (FCCard*)[tempMOC objectWithID:objectId];
                for (FCCardSet *set in _card.cardSet) {
                    [set setIsSubscribed:[NSNumber numberWithBool:NO]];
                }
                [tempMOC save:nil];
                [FlashCardsCore saveMainMOC:NO];
            }];
            return;
        }
        if (buttonIndex == 1) {
            [self saveCard:NO];
            [self cancelEvent];
        }
    }
}

- (void)tellParentToSync {
    UIViewController *parentVC = [FlashCardsCore parentViewController];
    if ([parentVC respondsToSelector:@selector(setShouldSyncN:)]) {
        [parentVC performSelector:@selector(setShouldSyncN:) withObject:[NSNumber numberWithBool:YES]];
    }
}

# pragma mark -
# pragma mark Event functions

- (void)configureCard:(bool)initialLoad {
    if (cardList && initialLoad && [cardList count] > 0) {
        self.title = [NSString stringWithFormat:NSLocalizedStringFromTable(@"Edit Card %d of %d", @"CardManagement", @"UIView title"), (cardIndex+1), [cardList count]];
        card = [cardList objectAtIndex:cardIndex];
        [self loadCardData:card];
    }

    NSString *noAudioString = NSLocalizedStringFromTable(@"(no audio, tap to record)", @"CardManagement", @"UILabel");
    NSData *audioData;
    audioData = (NSData*)[cardData objectForKey:@"frontAudioData"];
    if ([audioData length] == 0) {
        frontAudioDescriptionLabel.text = noAudioString;
    } else {
        audioPlayer = nil;
        audioPlayer = [[AVAudioPlayer alloc] initWithData:audioData error:nil];
        float length = (float)audioPlayer.duration;
        frontAudioDescriptionLabel.text = [NSString stringWithFormat:FCPluralLocalizedStringFromTable(@"%1.1f Secs", @"Plural", @"", [NSNumber numberWithFloat:length]), length];
    }
    
    audioData = (NSData*)[cardData objectForKey:@"backAudioData"];
    if ([audioData length] == 0) {
        backAudioDescriptionLabel.text = noAudioString;
    } else {
        audioPlayer = nil;
        audioPlayer = [[AVAudioPlayer alloc] initWithData:audioData error:nil];
        float length = (float)audioPlayer.duration;
        backAudioDescriptionLabel.text = [NSString stringWithFormat:FCPluralLocalizedStringFromTable(@"%1.1f Secs", @"Plural", @"", [NSNumber numberWithFloat:length]), length];
    }
    
    frontTextView.text = [cardData valueForKey:@"frontValue"];
    backTextView.text = [cardData valueForKey:@"backValue"];

    frontImageView.hidden = YES;
    backImageView.hidden = YES;
    frontNoImageLabel.hidden = NO;
    backNoImageLabel.hidden = NO;
    [frontImageView setFrame:CGRectMake(frontImageView.frame.origin.x,
                                        frontImageView.frame.origin.y,
                                        frontImageView.frame.size.width,
                                        32)];
    [backImageView setFrame:CGRectMake(backImageView.frame.origin.x,
                                       backImageView.frame.origin.y,
                                       backImageView.frame.size.width,
                                       32)];


    UIImage *image;
    if ([(NSMutableData*)[cardData objectForKey:@"frontImageData"] length] > 0) {
        image = [[UIImage alloc] initWithData:[cardData objectForKey:@"frontImageData"]];
        frontNoImageLabel.hidden = YES;
        frontImageView.hidden = NO;
        [self setTableCellImageView:frontImageView withImage:image];
    } else {
        [(NSMutableData*)[cardData objectForKey:@"frontImageData"] setLength:0];
    }
    if ([(NSMutableData*)[cardData objectForKey:@"backImageData"] length] > 0) {
        image = [[UIImage alloc] initWithData:[cardData objectForKey:@"backImageData"]];
        backNoImageLabel.hidden = YES;
        backImageView.hidden = NO;
        [self setTableCellImageView:backImageView withImage:image];
    } else {
        [(NSMutableData*)[cardData objectForKey:@"backImageData"] setLength:0];
    }
    
    [myTableView reloadData];
    
    if (![FlashCardsCore hasFeature:@"UnlimitedCards"] && editMode == modeCreate && !hasDisplayedUnlimitedCardsMessage) {
        int initialNumCards = [FlashCardsCore numTotalCards];
        if (initialNumCards >= maxCardsLite) {
            if (!hasDisplayedUnlimitedCardsMessage) {
                [FlashCardsCore showPurchasePopup:@"UnlimitedCards"];
            }
            
            hasDisplayedUnlimitedCardsMessage = YES;
            
            return;

        }
    }
    
}

- (void)setTableCellImageView:(UIImageView*)imageView withImage:(UIImage*)image {
    if (image) {
        [imageView setImage:image];
    } else {
        image = imageView.image;
    }
    if (!image) {
        return;
    }
    CGFloat maxWidth = ((self.view.frame.size.width * 164) / 320);
    CGFloat maxHeight = ((self.view.frame.size.height * 200) / 480);
    int originX;
    
    if ([FlashCardsAppDelegate isIpad] && UIInterfaceOrientationIsLandscape([[UIDevice currentDevice] orientation])) {
        originX = 263;
    } else {
        originX = 83;
    }

    // Set the proper image size depending on the size of the image relative to the scroll view:
    CGFloat height, width;
    width = image.size.width;
    height = image.size.height;
    if (!(image.size.width <= maxWidth && image.size.height <= maxHeight)) {
        if (width >= maxWidth) {
            height *= (maxWidth / width);
            width *= (maxWidth / width);
        }
        if (height >= maxHeight) {
            width *= (maxHeight / height);
            height *= (maxHeight / height);
        }
    }
    int x = ((maxWidth - width) / 2);
    [imageView setFrame:CGRectMake(x + originX,
                                   imageView.frame.origin.y,
                                   width,
                                   height)];
}

- (void)saveCard:(BOOL)didPressNextButton {
    
    if ([(NSString*)[cardData objectForKey:@"frontValue"] length] == 0 &&
        [(NSString*)[cardData objectForKey:@"backValue" ] length] == 0 &&
        [(NSData*)[cardData objectForKey:@"frontImageData"] length] == 0 &&
        [(NSData*)[cardData objectForKey:@"backImageData" ] length] == 0 &&
        [(NSData*)[cardData objectForKey:@"frontAudioData" ] length] == 0 &&
        [(NSData*)[cardData objectForKey:@"backAudioData" ] length] == 0 &&
        !editInPlace) {
        return;
    }
    if (editMode == modeCreate) {
        card = (FCCard *)[NSEntityDescription insertNewObjectForEntityForName:@"Card"
                                                       inManagedObjectContext:[FlashCardsCore mainMOC]];
    
        // set card's initial values:
        if (cardSet) {
            [cardSet addCard:card];
            [card setCollection:cardSet.collection];
            if (cardSet.shouldSync) {
                [card setShouldSync:cardSet.shouldSync];
            }
        } else {
            [card setCollection:collection];
            // if the collection only has one set, then add the card to the one set:
            if ([collection cardSetsCount] == 1) {
                FCCardSet *cardSetToAdd = [[[collection allCardSets] allObjects] objectAtIndex:0];
                [cardSetToAdd addCard:card];
                if (cardSetToAdd.shouldSync) {
                    [card setShouldSync:cardSetToAdd.shouldSync];
                }
            }
        }
        
        // Adjust the e-factor based on the word type: (cognate, normal, or false cognate)
        double eFactor = defaultEFactor;
        if ([[cardData valueForKey:@"wordType"] intValue] == wordTypeCognate) {
            eFactor = [SMCore adjustEFactor:eFactor add:0.2];
        } else if ([[cardData valueForKey:@"wordType"] intValue] == wordTypeFalseCognate) {
            eFactor = [SMCore adjustEFactor:eFactor add:-0.2];
        }
        [card setEFactor:[NSNumber numberWithDouble:eFactor]];        
        
    }
        
    [card setFrontValue:[cardData valueForKey:@"frontValue"]];
    [card setBackValue:[cardData valueForKey:@"backValue"]];
    if ([cardData objectForKey:@"frontImageData"]) {
        NSData *data = (NSData*)[cardData objectForKey:@"frontImageData"];
        if (![card.frontImageData isEqualToData:data]) {
            [card setFrontImageId:@""];
            [card setFrontImageURL:@""];
        }
    }
    [card setFrontImageData:[cardData objectForKey:@"frontImageData"]];
    if ([cardData objectForKey:@"backImageData"]) {
        NSData *data = (NSData*)[cardData objectForKey:@"backImageData"];
        if (![card.backImageData isEqualToData:data]) {
            [card setBackImageId:@""];
            [card setBackImageURL:@""];
        }
    }
    [card setBackImageData:[cardData objectForKey:@"backImageData"]];

    [card setFrontAudioData:[cardData objectForKey:@"frontAudioData"]];
    [card setBackAudioData: [cardData objectForKey:@"backAudioData"]];

    [card setWordType:[cardData valueForKey:@"wordType"]];
    
    // update the related cards to the new set:
    [card setRelatedCards:[cardData objectForKey:@"relatedCards"]];
    
    [FlashCardsCore saveMainMOC:NO];

    SyncController *controller = [[FlashCardsCore appDelegate] syncController];
    if (controller && [card.shouldSync boolValue]) {
        for (FCCardSet *_cardSet in [card allCardSets]) {
            if ([_cardSet isQuizletSet]) {
                [controller setQuizletDidChange:YES];
            }
        }
    }

    if ([card.shouldSync boolValue] && [card.syncStatus intValue] == syncChanged) {
        [self tellParentToSync];
    }
    [self isDoneSaving:didPressNextButton];
}

- (void)isDoneSaving:(BOOL)didPressNextButton {
    if (isAttemptingDelete) {
        [self cancelEvent];
    } else {
        if (cardList) {
            [cardListEdited replaceObjectAtIndex:cardIndex withObject:[NSNumber numberWithBool:YES]];
        } else if (editInPlace && [cardList count] == 1) {
            StudyViewController *vc = (StudyViewController*)[FlashCardsCore parentViewController];
            [[vc.studyController currentCard] setCard:card];
            [vc configureCard];
        }
        if ([cardList count] <= 1 && !didPressNextButton) {
            [self cancelEvent];
        }
    }
}

- (void) prevNextCardAction {
    [self saveCard:YES];

    // Move to the next card:
    // index 0 = "< Prev"
    int transition;
    if ([prevNextSegmentedControl selectedSegmentIndex] == 0) {
        cardIndex--;
        if (cardIndex < 0) {
            cardIndex = [cardList count] - 1;
        }
        transition = UIViewAnimationTransitionCurlDown;
    } else {
        // index 1 = "Next >"
        cardIndex += 1;
        if (cardIndex >= [cardList count]) {
            cardIndex = 0;
        }
        transition = UIViewAnimationTransitionCurlUp;
    }
    // Set up the view with the new data:
    [self.myTableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:NO];
    [self configureCard:YES];
    
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationDuration:0.60];
    [UIView setAnimationTransition:transition forView:[self view] cache:YES];
    [UIView commitAnimations];
    
}

- (bool)allCardsEdited {
    if (!cardList) {
        return YES;
    }
    for (int i = 0; i < [cardListEdited count]; i++) {
        if ([[cardListEdited objectAtIndex:i] boolValue] == NO) {
            return NO;
        }
    }
    return YES;
}

- (void)cancelEvent {
    [self.navigationController popToViewController:[[self.navigationController viewControllers] objectAtIndex:self.popToViewControllerIndex] animated:YES];
}

- (void)saveEvent {
    
    [self saveCard:NO];
    
    if (cardList && ![self allCardsEdited]) {
        // alert that we haven't yet edited all of the cards, ask them if they are sure they want to exit the editing screen
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Are you done editing?", @"CardManagement", @"UIAlert title")
                                                         message:[NSString stringWithFormat:NSLocalizedStringFromTable(@"It looks like you haven't edited all %d cards. Are you sure you want to exit the editing screen?", @"CardManagement", @"message"), [cardList count] ]
                                                        delegate:self
                                               cancelButtonTitle:NSLocalizedStringFromTable(@"I'm Not Done", @"CardManagement", @"cancelButtonTitle")
                                               otherButtonTitles:NSLocalizedStringFromTable(@"I'm Done", @"CardManagement", @"otherButtonTitles"), nil];
        [alert show];
        return;
    }
    
    [self cancelEvent];
}

- (void)nextEvent {
    [self saveCard:YES];
    
    [self doneEditingKeyboard:nil]; // get rid of the keyboard if necessary
    card = nil; // clear out the card which we saved before
    [self loadCardData:nil]; // clear out the card data so when we configure the card, it will be blank
    
    // Set up the view with the new data:
    [self.myTableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:NO];
    [self configureCard:YES];
    
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationDuration:0.60];
    [UIView setAnimationTransition:UIViewAnimationTransitionCurlUp forView:[self view] cache:YES];
    [UIView commitAnimations];
    
}

- (IBAction)cardSets:(id)sender {
    CardEditCardSetsViewController *vc = [[CardEditCardSetsViewController alloc] initWithNibName:@"CardEditCardSetsViewController" bundle:nil];
    vc.card = self.card;
    
    // Pass the selected object to the new view controller.
    [self.navigationController pushViewController:vc animated:YES];
    
}

- (IBAction)relatedCards:(id)sender {

    RelatedCardsViewController *vc = [[RelatedCardsViewController alloc] initWithNibName:@"RelatedCardsViewController" bundle:nil];
    vc.card = self.card;
    vc.relatedCardsTempStore = [cardData objectForKey:@"relatedCards"];
    if (editMode == modeCreate) {
        vc.collection = self.collection;
    }
    vc.editInPlace = NO;
    
    // Pass the selected object to the new view controller.
    [self.navigationController pushViewController:vc animated:YES];
    
    
}

- (IBAction)cardStatistics:(id)sender {
    CardStatisticsViewController *statsVC = [[CardStatisticsViewController alloc] initWithNibName:@"CardStatisticsViewController" bundle:nil];
    statsVC.card = self.card;
    
    // Pass the selected object to the new view controller.
    [self.navigationController pushViewController:statsVC animated:YES];
    
    
}

- (IBAction)launchDictionary:(id)sender {
    
    if ([frontTextView.text length] == 0) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@""
                                                         message:NSLocalizedStringFromTable(@"Please enter text for the front value. You cannot perform a dictionary lookup on blank text.", @"CardManagement", @"message")
                                                        delegate:nil
                                               cancelButtonTitle:NSLocalizedStringFromTable(@"OK", @"FlashCards", @"cancelButtonTitle")
                                               otherButtonTitles:nil];
        [alert show];
        return;        
    }
    if (cardList) {
        card = [cardList objectAtIndex:cardIndex];
    }
    
    FCCollection *coll = card.collection;
    DictionaryLookupViewController *vc = [[DictionaryLookupViewController alloc] initWithNibName:@"DictionaryLookupViewController" bundle:nil];
    vc.sourceLanguage = coll.frontValueLanguage;
    vc.targetLanguage = coll.backValueLanguage;
    vc.term = frontTextView.text;
    vc.isAddingMode = NO;
    
    // Pass the selected object to the new view controller.
    [self.navigationController pushViewController:vc animated:YES];
    
    
}

- (IBAction)confirmDeleteCard:(id)sender {
    isAttemptingDelete = YES;
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Are You Sure?", @"FlashCards", @"UIAlert title")
                                                     message:NSLocalizedStringFromTable(@"Are you sure you want to delete this card? Deleting it will remove it from all Card Sets in this Collection, and cannot be undone.", @"CardManagement", @"message")
                                                    delegate:self
                                           cancelButtonTitle:NSLocalizedStringFromTable(@"Don't Delete", @"CardManagement", @"cancelButtonTitle")
                                           otherButtonTitles:NSLocalizedStringFromTable(@"Yes, Delete", @"CardManagement", @"otherButtonTitles"), nil];
    [alert show];
}

- (void)previewCard {
    StudyViewController *studyVC = [[StudyViewController alloc] initWithNibName:@"StudyViewController" bundle:nil];
    studyVC.previewMode = YES;
    studyVC.previewCard = cardData;
    studyVC.studyingImportedSet = NO;
    
    studyVC.studyController.studyAlgorithm = studyAlgorithmLearn;
    studyVC.studyController.studyOrder = studyOrderRandom;
    int showFirstSide;
    if (cardSet) {
        showFirstSide = [cardSet.collection.defaultFirstSide intValue];
    } else {
        showFirstSide = [collection.defaultFirstSide intValue];
    }
    studyVC.studyController.showFirstSide = showFirstSide; // get the default from the collection settings.
    FCCollection *coll;
    if (self.collection) {
        coll = self.collection;
    } else if (self.cardSet) {
        coll = self.cardSet.collection;
    } else if (self.card) {
        coll = self.card.collection;
    }
    studyVC.collection = coll;
    
    // Pass the selected object to the new view controller.
    [self.navigationController pushViewController:studyVC animated:YES];

}

- (void)loadImageSelector:(NSMutableData*)imageData dataKey:(NSString*)dataKey {
    BOOL isQuizlet = NO;
    if (card) {
        for (FCCardSet *set in [card allCardSets]) {
            if ([set isQuizletSet] && [set.shouldSync boolValue]) {
                isQuizlet = YES;
            }
        }
    } else if (self.cardSet) {
        if ([self.cardSet isQuizletSet] && [self.cardSet.shouldSync boolValue]) {
            isQuizlet = YES;
        }
    } else if (self.collection) {
        if ([self.collection.masterCardSet isQuizletSet] && [self.collection.masterCardSet.shouldSync boolValue]) {
            isQuizlet = YES;
        }
    }
    if (isQuizlet && ![QuizletRestClient isQuizletPlus]) {
        RIButtonItem *cancelItem = [RIButtonItem item];
        cancelItem.label = NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"");
        cancelItem.action = ^{};
        
        RIButtonItem *selectImageItem = [RIButtonItem item];
        selectImageItem.label = NSLocalizedStringFromTable(@"Select Image", @"CardManagement", @"");
        selectImageItem.action = ^{
            [self showCardSelectImageViewController:imageData dataKey:dataKey];
        };
        
        RIButtonItem *checkQuizletItem = [RIButtonItem item];
        checkQuizletItem.label = NSLocalizedStringFromTable(@"Check Quizlet Status", @"CardManagement", @"otherButtonTitles");
        checkQuizletItem.action = ^{
            // Check quizlet+ status
            HUD = [[MBProgressHUD alloc] initWithView:self.view];
            // Add HUD to screen
            [self.view addSubview:HUD];
            // Regisete for HUD callbacks so we can remove it from the window at the right time
            HUD.delegate = self;
            HUD.minShowTime = 1.0;
            HUD.labelText = NSLocalizedStringFromTable(@"Checking Quizlet Plus", @"Import", @"HUD");
            [HUD show:YES];
            
            [self.quizletSync resetStateValues];
            self.quizletSync.isSaving = NO;
            [self.quizletSync syncAllData];
        };
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@""
                                                        message:NSLocalizedStringFromTable(@"You are not currently subscribed to Quizlet Plus, Quizlet's premium service. You can add images to flash cards, but they will not be uploaded to Quizlet.", @"FlashCards", @"")
                                               cancelButtonItem:cancelItem
                                               otherButtonItems:selectImageItem, checkQuizletItem, nil];
        [alert show];
        return;
    }
    
    [self showCardSelectImageViewController:imageData dataKey:dataKey];
}

- (void)showCardSelectImageViewController:(NSMutableData*)imageData dataKey:(NSString*)dataKey {
    
    if (![FlashCardsCore hasFeature:@"Photos"]) {
        [FlashCardsCore showPurchasePopup:@"Photos"];
        return;
    }
    
    CardSelectImageViewController *vc = [[CardSelectImageViewController alloc] initWithNibName:@"CardSelectImageViewController" bundle:nil];
    vc.imageData = [NSMutableData dataWithData:imageData];
    vc.dataKey = dataKey;
    
    
    [self.navigationController pushViewController:vc animated:YES];

}

- (void) swapFrontBackValues {
    
    NSString *temp = [NSString stringWithString:[cardData objectForKey:@"frontValue"]];
    [cardData setValue:[cardData valueForKey:@"backValue"] forKey:@"frontValue"];
    [cardData setValue:temp forKey:@"backValue"];
    
    NSMutableData *tempData = [NSMutableData dataWithData:[cardData objectForKey:@"frontImageData"]];
    [cardData setValue:[cardData objectForKey:@"backImageData"] forKey:@"frontImageData"];
    [cardData setValue:tempData forKey:@"backImageData"];
    
    tempData = [NSMutableData dataWithData:[cardData objectForKey:@"frontAudioData"]];
    [cardData setValue:[cardData objectForKey:@"backAudioData"] forKey:@"frontAudioData"];
    [cardData setValue:tempData forKey:@"backAudioData"];
    
    [self configureCard:NO];
    
}

#pragma mark-
#pragma mark Audio methods

- (void)startRecording {
    FCLog(@"startRecording");
    
    audioRecorder = nil;
    
    // Init audio with record capability
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    NSError *err = nil;
    [audioSession setCategory :AVAudioSessionCategoryPlayAndRecord error:&err];
    if(err) {
        NSLog(@"audioSession: %@ %d %@", [err domain], (int)[err code], [[err userInfo] description]);
        return;
    }
    [audioSession setActive:YES error:&err];
    err = nil;
    if(err) {
        NSLog(@"audioSession: %@ %d %@", [err domain], (int)[err code], [[err userInfo] description]);
        return;
    }
    
    NSMutableDictionary *recordSetting = [NSMutableDictionary dictionaryWithCapacity:0];
    // We can use kAudioFormatAppleIMA4 (4:1 compression) or kAudioFormatLinearPCM for nocompression
    [recordSetting setValue :[NSNumber numberWithInt:kAudioFormatAppleIMA4] forKey:AVFormatIDKey];
    // We can use 44100, 32000, 24000, 16000 or 12000 depending on sound quality
    [recordSetting setValue:[NSNumber numberWithFloat:16000.0] forKey:AVSampleRateKey];
    // We can use 2(if using additional h/w) or 1 (iPhone only has one microphone)
    [recordSetting setValue:[NSNumber numberWithInt: 1] forKey:AVNumberOfChannelsKey];

    NSString *filePath = [NSString stringWithFormat:@"%@/recordTest.caf",
                          [FlashCardsCore documentsDirectory]];
    
    NSURL *url = [NSURL fileURLWithPath:filePath];
    
    err = nil;
    
    NSData *audioData = [NSData dataWithContentsOfFile:filePath options: 0 error:&err];
    if (audioData) {
        NSFileManager *fm = [NSFileManager defaultManager];
        [fm removeItemAtPath:filePath error:&err];
    }

    err = nil;
    audioRecorder = nil;
    audioRecorder = [[AVAudioRecorder alloc] initWithURL:url settings:recordSetting error:&err];
    if (!audioRecorder) {
        NSLog(@"recorder: %@ %d %@", [err domain], (int)[err code], [[err userInfo] description]);
        UIAlertView *alert =
        [[UIAlertView alloc] initWithTitle: @"Warning"
                                   message: [err localizedDescription]
                                  delegate: nil
                         cancelButtonTitle:@"OK"
                         otherButtonTitles:nil];
        [alert show];
        return;
    }
    
    //prepare to record
    [audioRecorder prepareToRecord];
    audioRecorder.meteringEnabled = YES;
    
    BOOL audioHWAvailable = audioSession.inputAvailable;
    if (!audioHWAvailable) {
        UIAlertView *cantRecordAlert =
        [[UIAlertView alloc] initWithTitle: @"Warning"
                                   message: @"Audio input hardware not available"
                                  delegate: nil
                         cancelButtonTitle:@"OK"
                         otherButtonTitles:nil];
        [cantRecordAlert show];
        return;
    }
    
    // start recording
    [audioRecorder record];
    
    UIActionSheet *popupQuery;
    popupQuery = [[UIActionSheet alloc] initWithTitle:@""
                                             delegate:self
                                    cancelButtonTitle:NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"")
                               destructiveButtonTitle:nil
                                    otherButtonTitles:
                  NSLocalizedStringFromTable(@"Save Recording", @"CardManagement", @""),
                  nil];
    popupQuery.actionSheetStyle = UIActionSheetStyleBlackOpaque;
    [popupQuery showInView:self.view];

}
- (void)endRecording {
    [audioRecorder stop];
    // now save it:
    NSString *filePath = [NSString stringWithFormat:@"%@/recordTest.caf",
                          [FlashCardsCore documentsDirectory]];
    NSURL *url = [NSURL fileURLWithPath:filePath];
    NSData *audioData = [NSData dataWithContentsOfURL:url];
    [cardData setObject:audioData forKey:audioRecordingKey];
    [self configureCard:NO]; // not initial load
}
- (void)cancelRecording {
    [audioRecorder stop];
}
- (void)playRecording {
    // as per: http://stackoverflow.com/a/12868879/353137
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
    
    NSData *audioData = [cardData objectForKey:audioRecordingKey];
    
    NSError *err;
    audioPlayer = nil;
    audioPlayer = [[AVAudioPlayer alloc] initWithData:audioData error:&err];
    audioPlayer.volume = 0.4f;
    [audioPlayer prepareToPlay];
    [audioPlayer setNumberOfLoops:0];
    [audioPlayer play];
}
- (void)clearRecording {
    [cardData setObject:[NSMutableData dataWithCapacity:0] forKey:audioRecordingKey];
    [self configureCard:NO]; // not initial load
}

# pragma mark -
# pragma mark UIActionSheet methods

- (void)showAudioActionSheet {
    NSData *audioData = [cardData objectForKey:audioRecordingKey];
    UIActionSheet *popupQuery;
    if ([audioData length] == 0) {
        popupQuery = [[UIActionSheet alloc] initWithTitle:@""
                                                 delegate:self
                                        cancelButtonTitle:NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"")
                                   destructiveButtonTitle:nil
                                        otherButtonTitles:
                      NSLocalizedStringFromTable(@"Record", @"CardManagement", @""),
                      nil];
    } else {
        popupQuery = [[UIActionSheet alloc] initWithTitle:@""
                                                 delegate:self
                                        cancelButtonTitle:NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"")
                                   destructiveButtonTitle:nil
                                        otherButtonTitles:
                      NSLocalizedStringFromTable(@"Play", @"CardManagement", @""),
                      NSLocalizedStringFromTable(@"Record", @"CardManagement", @""),
                      NSLocalizedStringFromTable(@"Clear Recording", @"CardManagement", @""),
                      nil];
    }
    popupQuery.actionSheetStyle = UIActionSheetStyleBlackOpaque;
    [popupQuery showInView:self.view];
}

- (void)actionSheet:(UIActionSheet*)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    NSString *buttonTitle = [actionSheet buttonTitleAtIndex:buttonIndex];
    if ([buttonTitle isEqualToString:NSLocalizedStringFromTable(@"Play", @"CardManagement", @"")]) {
        [self playRecording];
    } else if ([buttonTitle isEqualToString:NSLocalizedStringFromTable(@"Record", @"CardManagement", @"")]) {
        [self startRecording];
    } else if ([buttonTitle isEqualToString:NSLocalizedStringFromTable(@"Clear Recording", @"CardManagement", @"")]) {
        [self clearRecording];
    } else if ([buttonTitle isEqualToString:NSLocalizedStringFromTable(@"Save Recording", @"CardManagement", @"")]) {
        [self endRecording];
    } else if ([buttonTitle isEqualToString:NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"")]) {
        [self cancelRecording];
    }
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
    [quizletSync cancel];
}

#pragma mark - TICoreDataSync methods

- (void)quizletSyncDidFinish:(QuizletSync *)client {
    if (HUD) {
        [HUD hide:YES];
    }
}

- (void)quizletSyncDidFinish:(QuizletSync*)client withError:(NSError*)error {
    if (HUD) {
        [HUD hide:YES];
    }
    [quizletSync handleHTTPError:error];
}

- (void)updateHUDLabel:(NSString*)labelText {
    HUD.labelText = labelText;
}

# pragma mark -
# pragma mark Text View Functions

- (CGSize)textViewSize:(UITextView*)textView {
    float fudgeFactor = 16.0;
    CGSize tallerSize = CGSizeMake(textView.frame.size.width-fudgeFactor, CGFLOAT_MAX);
    NSString *testString = @" ";
    if ([textView.text length] > 0) {
        testString = textView.text;
    }
    
    UILabel *gettingSizeLabel = [[UILabel alloc] init];
    gettingSizeLabel.font = textView.font;
    gettingSizeLabel.text = testString;
    gettingSizeLabel.numberOfLines = 0;
    gettingSizeLabel.lineBreakMode = NSLineBreakByWordWrapping;
    [gettingSizeLabel setPositionWidth:tallerSize.width];
    
    CGSize expectSize = [gettingSizeLabel sizeThatFits:tallerSize];

    /*
    CGSize stringSize;
    CGRect boundingRect = [testString boundingRectWithSize:tallerSize
                                                   options:NSStringDrawingUsesLineFragmentOrigin
                                                attributes:@{NSFontAttributeName:textView.font}
                                                   context:nil];
    stringSize = boundingRect.size;
    */
    return expectSize;
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
    if (textView == frontTextView) {
        [cardData setValue:textView.text forKey:@"frontValue"];
    } else {
        [cardData setValue:textView.text forKey:@"backValue"];
    }
}

-(BOOL) textViewShouldBeginEditing:(UITextView *)textView {
    NSString *language;
    if ([textView isEqual:frontTextView]) {
        language = collection.frontValueLanguage;
    } else {
        language = collection.backValueLanguage;
    }
    if ([language usesLatex]) {
        textView.inputAccessoryView = accessoryViewLatex;
    } else {
        if (![FlashCardsAppDelegate isIpad]) {
            textView.inputAccessoryView = accessoryView;
        }
    }
    
    if (self.currentlySelectedTextViewIndexPath) {
        self.canResignTextView = YES;
    }
    return YES;
}

-(BOOL) textViewShouldEndEditing:(UITextView *)textView {
    return self.canResignTextView;
}

#pragma mark -
#pragma mark Table view data source


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        // front side
        return 3;
    } else if (section == 1) {
        // back side
        return 3;
    } else if (section == 2) {
        // word type:
        return 3;
    }
    return 0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 40;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    
    UIView* customView = [[UIView alloc] initWithFrame:CGRectMake(10.0, 0.0, 300.0, 44.0)];
    
    // create the button object
    UILabel * headerLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    headerLabel.backgroundColor = [UIColor clearColor];
    headerLabel.opaque = NO;
    headerLabel.textColor = [UIColor blackColor];
    headerLabel.highlightedTextColor = [UIColor whiteColor];
    headerLabel.font = [UIFont boldSystemFontOfSize:19];
    if ([FlashCardsAppDelegate isIpad]) {
        headerLabel.frame = CGRectMake(60.0, 0.0, 300.0, 44.0);
    } else {
        headerLabel.frame = CGRectMake(10.0, 0.0, 300.0, 44.0);
    }
    
    if (section == 0) {
        headerLabel.text = NSLocalizedStringFromTable(@"Front Side of Card", @"CardManagement", @"headerLabel");
    } else if (section == 1) {
        headerLabel.text = NSLocalizedStringFromTable(@"Back Side of Card", @"CardManagement", @"headerLabel");
    } else if (section == 2) {
        headerLabel.text = NSLocalizedStringFromTable(@"Word Type", @"CardManagement", @"headerLabel");
    }
    [customView addSubview:headerLabel];
    
    return customView;
}



- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    if (section == 1) {
        if (editInPlace) {
            return 60.0;
        } else {
            return 100.0;
        }
    } else {
        return 0.0;
    }
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    
    if (section == 1) {
        UIView *customView = [[UIView alloc] init];
        [customView setFrame:CGRectMake(0.0, 0.0, tableView.frame.size.width, [self tableView:tableView heightForFooterInSection:1])];
        [customView setAutoresizingMask:(UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleLeftMargin)];
         
        UIButton *swapButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        [swapButton setFrame:CGRectMake(10.0, 10.0, 300, 37.0)];
        [swapButton setCenter:CGPointMake(customView.center.x, swapButton.center.y)];
        [swapButton setAutoresizingMask:UIViewAutoresizingFlexibleTopMargin];
        [swapButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [swapButton setTitleColor:[UIColor whiteColor] forState:UIControlStateSelected];
        [swapButton setBackgroundImage:[UIImage imageNamed:@"button_gray.png"] forState:UIControlStateNormal];
        [swapButton setBackgroundImage:[UIImage imageNamed:@"button_gray_selected.png"] forState:UIControlStateSelected];
        [swapButton setBackgroundImage:[UIImage imageNamed:@"button_gray_selected.png"] forState:UIControlStateHighlighted];
        [swapButton setTitle:NSLocalizedStringFromTable(@"Swap Front & Back", @"CardManagement", @"UIButton") forState:UIControlStateNormal];
        [swapButton addTarget:self action:@selector(swapFrontBackValues) forControlEvents:UIControlEventTouchUpInside];
        
        [customView addSubview:swapButton];
        
        if (!editInPlace) {
            // don't show the preview button when we are editing the card from the studying. Otherwise it's just taking us back to studying!!
            UIButton *previewButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
            [previewButton setFrame:CGRectMake(10.0, 57.0, 300, 37.0)];
            [previewButton setCenter:CGPointMake(customView.center.x, previewButton.center.y)];
            [previewButton setAutoresizingMask:UIViewAutoresizingFlexibleTopMargin];
            [previewButton setBackgroundImage:[UIImage imageNamed:@"button_green.png"] forState:UIControlStateNormal];
            [previewButton setBackgroundImage:[UIImage imageNamed:@"button_green_selected.png"] forState:UIControlStateSelected];
            [previewButton setTitle:NSLocalizedStringFromTable(@"Preview Card", @"CardManagement", @"UIButton") forState:UIControlStateNormal];
            [previewButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            [previewButton setTitleColor:[UIColor whiteColor] forState:UIControlStateSelected];
            [previewButton addTarget:self action:@selector(previewCard) forControlEvents:UIControlEventTouchUpInside];
            
            [customView addSubview:previewButton];
        }
        
        return customView;
    }
    
    return nil;
    // UIView *emptyView = [[[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, 0.0, 0.0)];
    // return emptyView;
    
}

- (CGFloat)tableView:(UITableView  *)tableView heightForRowAtIndexPath:(NSIndexPath  *)indexPath {
    if (indexPath.section == 2) {
        // always show the proper row height for word type rows:
        return 44;
    }
    int height;
    if (indexPath.row == 0) {
        UITextView *textView;
        if (indexPath.section == 0) {
            textView = frontTextView;
        } else {
            textView = backTextView;
        }
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
    }
    if (indexPath.row == 1) {
        UIImageView *imageView;
        if (indexPath.section == 0) {
            imageView = frontImageView;
        } else {
            imageView = backImageView;
        }
        height = imageView.frame.size.height + 12;
        if (height < 44) {
            height = 44;
            [imageView setFrame:CGRectMake(imageView.frame.origin.x,
                                           imageView.frame.origin.y,
                                           imageView.frame.size.width,
                                           44-12)];
        }
        return (CGFloat)height;
    }
    return 44;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            return frontTextTableCell;
        } else if (indexPath.row == 1) {
            return frontImageTableCell;
        } else {
            return frontAudioTableCell;
        }
    } else if (indexPath.section == 1) {
        if (indexPath.row == 0) {
            return backTextTableCell;
        } else if (indexPath.row == 1) {
            return backImageTableCell;
        } else {
            return backAudioTableCell;
        }
    } else {
        static NSString *CellIdentifier = @"Cell";
        
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
        }
        
        [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
        
        cell.textLabel.text = [wordTypeOptions objectAtIndex:indexPath.row];
        if ([[cardData objectForKey:@"wordType"] intValue] == indexPath.row) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        } else {
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
        
        return cell;
    }
}


#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section < 2) {
        if (indexPath.row == 0) {
            self.canResignTextView = YES;
        //    [tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionTop animated:YES];
        } else if (indexPath.row == 1) {
            NSString *key;
            if (indexPath.section == 0) {
                // front side
                key = @"frontImageData";
            } else {
                // back side
                key = @"backImageData";
            }
            [self loadImageSelector:[cardData objectForKey:key] dataKey:key];
        } else {
            if ([FlashCardsCore hasFeature:@"Audio"]) {
                NSString *key;
                if (indexPath.section == 0) {
                    // front side
                    key = @"frontAudioData";
                } else {
                    // back side
                    key = @"backAudioData";
                }
                self.audioRecordingKey = key;
                
                [self showAudioActionSheet];
                return;
            } else {
                [FlashCardsCore showPurchasePopup:@"Audio"];
                return;
            }
        }
    }
    if (indexPath.section == 2) {
        if (indexPath.row == [[cardData valueForKey:@"wordType"] intValue]) {
            [tableView deselectRowAtIndexPath:indexPath animated:YES];
            return;
        }
        
        UITableViewCell *oldSelectedOption = [tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:[[cardData objectForKey:@"wordType"] intValue] inSection:2]];
        oldSelectedOption.accessoryType = UITableViewCellAccessoryNone;
        
        [cardData setObject:[NSNumber numberWithInt:indexPath.row] forKey:@"wordType"];
        UITableViewCell *newCell = [tableView cellForRowAtIndexPath:indexPath];
        newCell.accessoryType = UITableViewCellAccessoryCheckmark;

        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
}



# pragma mark -
# pragma mark Memory functions

// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotate {
    return YES;
}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
    
    prevNextToolbar = nil;
    prevNextSegmentedControl = nil;
    
    frontTextView = nil;
    backTextView = nil;
    
    [[NSNotificationCenter defaultCenter]
     removeObserver:self
     name:NSPersistentStoreCoordinatorStoresDidChangeNotification
     object:[[FlashCardsCore mainMOC] persistentStoreCoordinator]];
    
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}




@end
