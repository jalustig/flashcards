//
//  StudyViewController.m
//  FlashCards
//
//  Created by Jason Lustig on 5/28/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#include <stdlib.h>
#include <math.h>

#import "FlashCardsAppDelegate.h"
#import "FlashCardsCore.h"

#import "RootViewController.h"
#import "StudyViewController.h"
#import "StudyController.h"

#import "CardEditViewController.h"
#import "HelpViewController.h"
#import "CardStatisticsViewController.h"
#import "RelatedCardsViewController.h"
#import "StudySettingsViewController.h"
#import "SubscriptionViewController.h"

#import "FCCollection.h"
#import "FCCardSet.h"
#import "FCCard.h"
#import "FCCardRepetition.h"

#import "CardTest.h"
#import    "HelpConstants.h"
#import "FCMatrix.h"
#import "NSString+XMLEntities.h"
#import "UIColor-Expanded.h"

#import "Swipeable.h"

#import "MBProgressHUD.h"

#import "SCRSegmentedControl.h"
#import "UIView+Layout.h"
#import "NSData+MD5.m"

#import <iAd/iAd.h>
#import <MessageUI/MessageUI.h>
#import <AVFoundation/AVAudioPlayer.h>
#import <AVFoundation/AVAudioSession.h>

#import <ActionSheetPicker-3.0/ActionSheetStringPicker.h>

#import "UIAlertView+Blocks.h"

#import "NSString+Markdown.h"
#import "NSString+Languages.h"

#import "DTVersion.h"

#import "ADBannerView+Layout.h"

#import <OHAttributedStringAdditions/OHAttributedStringAdditions.h>

#define HORIZ_SWIPE_DRAG_MIN  12
#define VERT_SWIPE_DRAG_MAX    100

# pragma mark -
# pragma mark StudyViewController


@implementation StudyViewController

@synthesize HUD;

@synthesize frontLabelText;

@synthesize deviceIsPortrait;

@synthesize cardSet, collection;
@synthesize studyBrowseMode, studyBrowseModePaused, studyBrowseModePausedForSpeakText, studyBrowseModeFunctionRunning, popToViewControllerIndex;
@synthesize appLockedTimerBegin, userTouchTimer;
@synthesize previewMode, previewCard;
@synthesize textSize, autoStudySpeed;
@synthesize audioPlayer, TTSButton, TTSActivityIndicator;
@synthesize cardNumberLabel, frontScrollView, frontView, frontLabel, frontCardImageTop, frontCardImageBottom, frontImage, bottomToolbarStudy; // front
@synthesize frontWebview;
@synthesize pausePlayAutoBrowseButton, backScrollView, backView, backLabel, backCardImageTop, backCardImageBottom, backImage, backHelpButton, relatedCardsTableView, passFailSegmentedControl, failPassChanging; // back
@synthesize backWebview;
@synthesize bottomToolbarResults, bottomToolbarTestResults, studyCardsWithScoresLessThan4Button; // results
@synthesize cardTestIsChanged, allowLeavingWithoutResultsPrompt, forceDisplayResultsPrompt;
@synthesize error, errorStr, userInfo, localizedDescription, isReportingError, studyingImportedSet, didBeginStudying;
@synthesize hasAlreadyLoaded;
@synthesize isUsingTTS;
@synthesize ttsStringStartLocation;
@synthesize ttsStudySideIsFrontOfCard;
@synthesize autoAudioShouldPlay;
@synthesize speechSynthesizer;

@synthesize frontDropshadowImage, backDropshadowImage;

@synthesize bottomFrontFlipButton;
@synthesize bottomFrontRelatedButton;
@synthesize bottomFrontStatsButton;
@synthesize editButton;
@synthesize resultsNextRoundButton;
@synthesize resultsRandomOrderButton;
@synthesize resultsBeginTestButton;
@synthesize testResultsStudyLessThan4Button;
@synthesize testResultsFinishTestButton;

@synthesize studyController;

@synthesize cardView;

@synthesize autoBrowsePattern;

@synthesize fullScreenButton;
@synthesize isFullScreen;

// as per: http://weblog.bignerdranch.com/?p=56
- (id)init {
    studyController = [[StudyController alloc] init];
    studyController.delegate = self;
    isFullScreen = NO;
    return [super initWithNibName:@"StudyViewController" bundle:nil];
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    return [self init];
}


// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {    
    
    [super viewDidLoad];
    
    if (![FlashCardsCore hasFeature:@"HideAds"] && [FlashCardsCore canShowInterstitialAds]) {
        // display an ad:
        FCLog(@"requesting interstitial ads");
        ADInterstitialAd *interstitial = [[FlashCardsCore appDelegate] interstitialAd];
        if (interstitial.loaded) {
            [interstitial presentFromViewController:self];
        }
    }
    
    // as per: http://stackoverflow.com/a/8667195/353137
    [frontWebview setBackgroundColor:[UIColor clearColor]];
    [frontWebview setOpaque:NO];
    [backWebview setBackgroundColor:[UIColor clearColor]];
    [backWebview setOpaque:NO];

    
    if (![DTVersion osVersionIsLessThen:@"7.0"]) {
        self.edgesForExtendedLayout= UIRectEdgeNone;
    }
    
    NSString *algorithm;
    if (studyController.studyAlgorithm == studyAlgorithmLapsed) {
        algorithm = @"studyAlgorithmLapsed";
    } else if (studyController.studyAlgorithm == studyAlgorithmLearn) {
        algorithm = @"studyAlgorithmLearn";
    } else if (studyController.studyAlgorithm == studyAlgorithmRepetition) {
        algorithm = @"studyAlgorithmRepetition";
        [FlashCardsCore setSetting:@"lastDateStudied" value:[NSDate date]];
    } else {
        algorithm = @"studyAlgorithmTest";
    }
    NSString *firstSideShown;
    if (studyController.showFirstSide == showFirstSideFront) {
        firstSideShown = @"front";
    } else if (studyController.showFirstSide == showFirstSideBack) {
        firstSideShown = @"back";
    } else {
        firstSideShown = @"random";
    }
    NSString *studyMode;
    if (studyBrowseMode == studyBrowseModeAutoAudio) {
        studyMode = @"auto-audio";
    } else if (studyBrowseMode == studyBrowseModeAutoBrowse) {
        studyMode = @"auto-browse";
    } else {
        studyMode = @"manual";
    }
    [Flurry logEvent:@"Study"
      withParameters:
     @{@"numberCards" : [NSNumber numberWithInt:[studyController.cardList count]],
     @"algorithm" : algorithm,
     @"language_front" : (self.collection.frontValueLanguage ? self.collection.frontValueLanguage : @""),
     @"langauge_back" : (self.collection.backValueLanguage ? self.collection.backValueLanguage : @""),
     @"firstSideShown" : firstSideShown,
     @"studyMode" : studyMode,
     @"inCardSet" : [NSNumber numberWithBool:(self.cardSet != nil)]
     }
               timed:YES];
    
    // we load this up at the beginning, so that we get a good sense of whether or not the user is supposed
    // to have the proper default value, the first time they load up the program.
    BOOL testValue = [(NSNumber*)[FlashCardsCore getSetting:@"studyDisplayLikeIndexCard"] boolValue];
    
    audioPlayer = [[AVAudioPlayer alloc] initWithData:[NSMutableData dataWithLength:0] error:nil];
    autoAudioShouldPlay = YES;
    
    frontLabel.accessibilityLanguage = collection.frontValueLanguage;
    backLabel.accessibilityLanguage  = collection.backValueLanguage;
    
    if (!studyController.ofMatrix) {
        studyController.ofMatrix = [FCMatrix initWithMatrix:collection.ofMatrix];
        studyController.ofMatrixAdjusted = [FCMatrix initWithMatrix:collection.ofMatrixAdjusted];
    }
    if (studyController.numCases < 0) {
        studyController.numCases = [collection.numCases intValue];
    }
    
    isUsingTTS = NO;
    [TTSButton setAccessibilityLabel:NSLocalizedStringFromTable(@"Speak Text", @"Study", @"")]; 
    [TTSButton setAccessibilityHint:NSLocalizedStringFromTable(@"Speak Text", @"Study", @"")];

    [editButton setAccessibilityLabel:NSLocalizedStringFromTable(@"Edit Card", @"CardManagement", @"")];
    [editButton setAccessibilityHint:NSLocalizedStringFromTable(@"Edit Card", @"CardManagement", @"")];
    
    [fullScreenButton setAccessibilityLabel:NSLocalizedStringFromTable(@"Turn On Full Screen", @"Study", @"")];
    [fullScreenButton setAccessibilityHint:NSLocalizedStringFromTable(@"Turn On Full Screen", @"Study", @"")];
    
    passFailSegmentedControl = [[SCRSegmentedControl alloc] init];
    [passFailSegmentedControl setFrame:CGRectMake(10, 290,
                                                  300, 88)];
    [passFailSegmentedControl setRowCount:2];
    [passFailSegmentedControl setColumnCount:3];
    NSArray *segmentTitles = [[NSArray alloc] initWithObjects:
                              NSLocalizedStringFromTable(@"3: Barely", @"Study", @"score"),
                              NSLocalizedStringFromTable(@"4: OK", @"Study", @"score"),
                              NSLocalizedStringFromTable(@"5: Easy!", @"Study", @"score"),
                              NSLocalizedStringFromTable(@"No Score", @"Study", @"score"),
                              NSLocalizedStringFromTable(@"1: Fail", @"Study", @"score"),
                              NSLocalizedStringFromTable(@"2: Almost", @"Study", @"score"),
                              nil];
    [passFailSegmentedControl setSegmentTitles:segmentTitles];
    [passFailSegmentedControl setAutoresizingMask:
     UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin];
    [passFailSegmentedControl layoutIfNeeded];
    UITapGestureRecognizer * passFailTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                          action:@selector(passFailSelectedIndexChanged:)];
    [passFailSegmentedControl addGestureRecognizer:passFailTapGesture];
    [self.view addSubview:passFailSegmentedControl];

    ADBannerView *backBanner = [[FlashCardsCore appDelegate] bannerAd];
    if (![FlashCardsCore hasFeature:@"HideAds"] && backBanner) {
        [self.view addSubview:backBanner];
    }

    // 1. Set the titles for the buttons, so that they will be able to be set up properly for the sizes.
    if (![FlashCardsAppDelegate isIpad]) {
        NSMutableArray *buttons = [NSMutableArray arrayWithArray:[bottomToolbarStudy items]];
        [buttons removeObjectAtIndex:0];
        [buttons removeObjectAtIndex:0];
        [bottomToolbarStudy setItems:buttons];
    }

    [bottomFrontRelatedButton setTitle:NSLocalizedStringFromTable(@"Related Cards", @"Study", @"UIBarButtonItem")];
    if ([FlashCardsCore hasFeature:@"HideAds"]) {
        [bottomFrontStatsButton setTitle:NSLocalizedStringFromTable(@"Card Statistics", @"Study", @"UIBarButtonItem")];
    } else {
        [bottomFrontStatsButton setTitle:NSLocalizedStringFromTable(@"Hide Ads", @"Subscription", @"UIBarButtonItem")];
    }

    resultsNextRoundButton.title =        NSLocalizedStringFromTable(@"Next Round", @"Study", @"UIBarButtonItem");
    resultsRandomOrderButton.title =    NSLocalizedStringFromTable(@"Random Order", @"Study", @"UIBarButtonItem");
    resultsBeginTestButton.title =        NSLocalizedStringFromTable(@"Begin Test", @"Study", @"UIBarButtonItem");

    testResultsFinishTestButton.title =        NSLocalizedStringFromTable(@"Finish Test", @"Study", @"UIBarButtonItem");
    testResultsStudyLessThan4Button.title = NSLocalizedStringFromTable(@"Study Cards With Scores < 4", @"Study", @"UIBarButtonItem");
    
    // hide the whole front view, so that when we are first opening the studying it doesn't flash the unconfigured screen.
    frontCardImageBottom.hidden = YES;
    frontCardImageTop.hidden = YES;
    frontDropshadowImage.hidden = YES;
    frontView.hidden = YES;
    
    [frontCardImageTop setImage:[frontCardImageTop.image stretchableImageWithLeftCapWidth:20 topCapHeight:16]];
    [frontCardImageBottom setImage:[frontCardImageBottom.image stretchableImageWithLeftCapWidth:20 topCapHeight:0]];
    [backCardImageTop setImage:[backCardImageTop.image stretchableImageWithLeftCapWidth:20 topCapHeight:16]];
    [backCardImageBottom setImage:[backCardImageBottom.image stretchableImageWithLeftCapWidth:20 topCapHeight:0]];
    
    studyBrowseModeFunctionRunning = NO;

    // if we're on the ipad, then move the pause/play button a bit so that it is in a better place:
    if ([FlashCardsAppDelegate isIpad]) {
        [self.editButton setFrame:CGRectMake(self.editButton.frame.origin.x-20,
                                             self.editButton.frame.origin.y+20,
                                             self.editButton.frame.size.width,
                                             self.editButton.frame.size.height)];
        [self.pausePlayAutoBrowseButton setFrame:CGRectMake(self.pausePlayAutoBrowseButton.frame.origin.x-20,
                                                            self.pausePlayAutoBrowseButton.frame.origin.y+20,
                                                            self.pausePlayAutoBrowseButton.frame.size.width,
                                                            self.pausePlayAutoBrowseButton.frame.size.height)];
        [self.fullScreenButton setFrame:CGRectMake(self.fullScreenButton.frame.origin.x-20,
                                                   self.fullScreenButton.frame.origin.y+20,
                                                   self.fullScreenButton.frame.size.width,
                                                   self.fullScreenButton.frame.size.height)];
    }
    
    if (studyBrowseMode == studyBrowseModeAutoBrowse || studyBrowseMode == studyBrowseModeAutoAudio) {
        // if the auto-browse is running, then display the "speaker" button to the left of the pause/play button.
        [self.TTSButton setFrame:CGRectMake(self.pausePlayAutoBrowseButton.frame.origin.x-39,
                                            self.pausePlayAutoBrowseButton.frame.origin.y+6,
                                            self.TTSButton.frame.size.width,
                                            self.TTSButton.frame.size.height)];
    } else {
        // otherwise, display the "speaker" button right where the pause/play button is supposed to be:
        [self.TTSButton setFrame:CGRectMake(self.pausePlayAutoBrowseButton.frame.origin.x,
                                            self.pausePlayAutoBrowseButton.frame.origin.y+6,
                                            self.TTSButton.frame.size.width,
                                            self.TTSButton.frame.size.height)];
    }    
    [self.TTSActivityIndicator setCenter:CGPointMake(self.TTSButton.center.x, self.TTSButton.center.y)];
    
    studyBrowseModePaused = NO;
    studyBrowseModePausedForSpeakText = NO;
    didBeginStudying = NO;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResign) name:UIApplicationDidEnterBackgroundNotification object:NULL];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidActivate) name:UIApplicationWillEnterForegroundNotification object:NULL];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResign) name:UIApplicationWillResignActiveNotification object:NULL];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidActivate) name:UIApplicationDidBecomeActiveNotification  object:NULL];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receivedRotate:) name:UIDeviceOrientationDidChangeNotification object:NULL];

    self.title = (studyController.showFirstSide == showFirstSideBack) ? NSLocalizedStringFromTable(@"Back", @"Study", @"Back of card") : NSLocalizedStringFromTable(@"Front", @"Study", @"");
    
    [self showBackView:NO];
    
    cardNumberLabel.text = @"";
    
    cardTestIsChanged = NO;
    allowLeavingWithoutResultsPrompt = YES;
    forceDisplayResultsPrompt = NO;
    
    // if in preview mode, then disable all the potential buttons that the user could press:
    if (previewMode) {
        passFailSegmentedControl.enabled = NO;
        passFailSegmentedControl.userInteractionEnabled = NO;
        
        bottomFrontRelatedButton.enabled = NO;
        if ([FlashCardsCore hasFeature:@"HideAds"]) {
            bottomFrontStatsButton.enabled = NO;
        } else {
            // it's the "hide ads" button - always be on!
            bottomFrontStatsButton.enabled = YES;
        }
        // editButton.enabled = NO;
    }
    
    // Done button
    if (!previewMode) {
        UIBarButtonItem *bi;
        bi = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneEvent)];
        self.navigationItem.leftBarButtonItem = bi;
    }

    UIBarButtonItem *prevButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"button_back.png"]
                                                                   style:UIBarButtonItemStylePlain
                                                                  target:self
                                                                  action:@selector(prevCardAction)];
    [prevButton setAccessibilityLabel:NSLocalizedStringFromTable(@"Previous Card", @"Study", @"previous card")];
    if (previewMode) {
        [prevButton setEnabled:NO];
    }
    
    UIBarButtonItem *nextButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"button_forward.png"]
                                                                   style:UIBarButtonItemStylePlain
                                                                  target:self
                                                                  action:@selector(nextCardAction)];
    [nextButton setAccessibilityLabel:NSLocalizedStringFromTable(@"Next Card", @"Study", @"next card")];
    if (previewMode) {
        [nextButton setEnabled:NO];
    }
    
    self.navigationItem.rightBarButtonItems = @[nextButton, prevButton];

    // set background colors:
    UIColor *backgroundColor;
    UIColor *cardBackgroundColor;
    
    backgroundColor = [UIColor colorWithString:(NSString *)[FlashCardsCore getSetting:@"studySettingsBackgroundColor"]];
    
    // if something strange happens to the colors, set them to be black & white:
    if (!backgroundColor) {
        backgroundColor = [UIColor blackColor];
    }

    UIColor *cardPattern = [UIColor colorWithPatternImage:[UIImage imageNamed:@"FlashCard-background-pattern.png"]];
    UIColor *backgroundPattern = [UIColor colorWithPatternImage:[UIImage imageNamed:@"oak.png"]];
    
    if ([(NSNumber*)[FlashCardsCore getSetting:@"studyDisplayLikeIndexCard"] boolValue]) {
        cardBackgroundColor = [UIColor clearColor];
        if ([FlashCardsAppDelegate isIpad]) {
            [cardNumberLabel setPositionY:cardNumberLabel.frame.origin.y+10];
            [frontCardImageTop setPositionHeight:frontCardImageTop.frame.size.height*2];
            [frontCardImageBottom setPositionHeight:frontCardImageBottom.frame.size.height*2];
            [backCardImageTop setPositionHeight:backCardImageTop.frame.size.height*2];
            [backCardImageBottom setPositionHeight:backCardImageBottom.frame.size.height*2];
        }
        
        backView.backgroundColor = cardPattern;
        frontView.backgroundColor = cardPattern;
        backgroundColor = backgroundPattern;
        
        // you would think that we will show the frontDropshadowImage at this point: BUT NO!
        // If we show it now, then it will be displayed along with NOTHING ELSE in the first seconds of studying.
        // frontDropshadowImage.hidden = NO;
        backDropshadowImage.hidden = NO;
        
        [frontDropshadowImage setImage:[UIImage imageNamed:@"FlashCard-background-side.png"]];
        [backDropshadowImage setImage:[UIImage imageNamed:@"FlashCard-background-side.png"]];
        
        
    } else {
        cardBackgroundColor = backgroundColor;
        frontView.backgroundColor = cardBackgroundColor;
        backView.backgroundColor = cardBackgroundColor;

        frontDropshadowImage.hidden = YES;
        backDropshadowImage.hidden = YES;
    }
    
    self.view.backgroundColor = backgroundColor;
    
    frontLabel.backgroundColor = cardBackgroundColor;
    backLabel.backgroundColor = cardBackgroundColor;
    relatedCardsTableView.backgroundColor = cardBackgroundColor;
    
    cardNumberLabel.backgroundColor = cardBackgroundColor;
    
    // get other settings:
    textSize = [(NSNumber*)[FlashCardsCore getSetting:@"studyTextSize"] intValue];
    
    if (previewMode) {
        // [self configureCard]; 
    } else {
        // build the list of cards:
        [studyController loadCardsFromStore];
        [studyController translateCardsToCardTests];

        // go straight to the studying; skip settings screen:
        if (studyController.studyAlgorithm == studyAlgorithmTest ||
            studyController.studyAlgorithm == studyAlgorithmRepetition) {
            [self beginTest:nil];
        } else {
            [self beginStudying:nil];
        }

        failPassChanging = NO;
        
        if ([studyController numCards] == 0 && !hasAlreadyLoaded) {
            [self showNoCardsAlert];
        }
        hasAlreadyLoaded = YES;
    }
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleDefault;
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

-(void)viewDidAppear:(BOOL)animated {
    if ([studyController.cardList count] > 0 && studyController.currentCardIndex < [studyController.cardList count]) {
        CardTest *testCard = [studyController currentCard];
        if (appLockedTimerBegin) {
            [testCard markStudyPause:appLockedTimerBegin];
            appLockedTimerBegin = nil;
        }
    }
    UIDeviceOrientation interfaceOrientation = [[UIDevice currentDevice] orientation];
    deviceIsPortrait = UIInterfaceOrientationIsPortrait(interfaceOrientation);
    if (self.isFullScreen) {
        [self turnOnFullScreenStudy];
    }
    // should not reset the card score - should show what we had before:
    [self configureCard];
    [self configurePausePlayAutoBrowseButton];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [self turnOffFullScreenStudy];
    self.studyBrowseModePaused = YES;
}

- (void)setStudyBrowseModePausedB:(NSNumber*)_studyBrowseModePaused {
    self.studyBrowseModePaused = [_studyBrowseModePaused boolValue];
}

-(BOOL)resultsDisplayed {
    return [self.title isEqual:NSLocalizedStringFromTable(@"Results", @"Study", @"")];
}

// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotate {
    UIInterfaceOrientation interfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationLandscapeLeft || interfaceOrientation == UIInterfaceOrientationLandscapeRight || interfaceOrientation == UIInterfaceOrientationPortrait || interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown);
}

/*
- (NSUInteger)supportedInterfaceOrientations{
    return UIInterfaceOrientationMaskAll;
}

// Tell the system It should autorotate
- (BOOL) shouldAutorotate {
    return YES;
}
// Tell the system which initial orientation we want to have
- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    return UIInterfaceOrientationPortrait;
}*/

# pragma mark -
# pragma mark MBProgressHUD methods

- (void)hudWasHidden:(MBProgressHUD *)_hud {
    BOOL wasSaving = NO;
    if ([_hud isEqual:HUD]) {
        wasSaving = YES;
    }
    [_hud removeFromSuperview];
    _hud = nil;
    if (wasSaving) {
        [self exitViewController];
    }
}

- (void)exitViewController {
    [self.navigationController popToViewController:[[self.navigationController viewControllers] objectAtIndex:popToViewControllerIndex] animated:YES];
}

# pragma mark -
# pragma mark Configuration Functions

-(IBAction)beginStudying:(id)sender {
    [studyController beginStudying:sender];
}
-(IBAction)beginTest:(id)sender {
    [studyController beginTest:sender];
}
-(IBAction)studyCardsWithScoresLessThan4:(id)sender {
    [studyController studyCardsWithScoresLessThan4:sender];
}
-(IBAction)continueNextRound:(id)sender {
    [studyController nextRound];
}
-(void)configurePausePlayAutoBrowseButton {
    if (studyBrowseMode == studyBrowseModeAutoBrowse || studyBrowseMode == studyBrowseModeAutoAudio) {
        pausePlayAutoBrowseButton.hidden = NO;
        
        // make sure the button is the right color.
        
        BOOL displayAsCard = [(NSNumber*)[FlashCardsCore getSetting:@"studyDisplayLikeIndexCard"] boolValue];
        NSString *imageFileName = (displayAsCard ? @"pauseButton-black.png" : @"pauseButton.png");
        [self.pausePlayAutoBrowseButton setImage:[UIImage imageNamed:imageFileName] forState:UIControlStateNormal];
        float autoBrowseSpeed = [(NSNumber*)[FlashCardsCore getSetting:@"studySettingsAutoBrowseSpeed"] floatValue];
        NSString *pattern = [FlashCardsCore randomStringOfLength:10];
        self.autoBrowsePattern = pattern;
        [self performSelector:@selector(autoBrowse:) withObject:self.autoBrowsePattern afterDelay:autoBrowseSpeed];
    } else {
        pausePlayAutoBrowseButton.hidden = YES;
        self.studyBrowseModeFunctionRunning = NO;
        self.studyBrowseModePaused = YES;
    }
}

# pragma mark -
# pragma mark Card utility functions

-(void)showNoCardsAlert {
    int countNotNew = 0;
    if (studyController.studyAlgorithm == studyAlgorithmTest || studyController.studyAlgorithm == studyAlgorithmRepetition || self.studyController.loadNewCardsOnly) {
        // look up how many cards in this set/collection are NOT NEW (i.e. they are either memorized,
        // or they are lapsed).
        // if there is more than 1 NOT NEW card, then tell the user that they can
        // re-study the cards.
        
        // Create the fetch request for the entity.
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        // Edit the entity name as appropriate.
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"Card" inManagedObjectContext:[FlashCardsCore mainMOC]];
        [fetchRequest setEntity:entity];
        
        NSMutableArray *predicates = [[NSMutableArray alloc] initWithCapacity:0];
        if (cardSet) {
            [predicates addObject:[NSPredicate predicateWithFormat:@"collection = %@ and any cardSet = %@", collection, cardSet]];
        } else {
            [predicates addObject:[NSPredicate predicateWithFormat:@"collection = %@", collection]];
        }
        [predicates addObject:[NSPredicate predicateWithFormat:@"isDeletedObject = NO"]];
        [predicates addObject:[NSPredicate predicateWithFormat:@"isSpacedRepetition = YES || isLapsed = YES"]];
        
        [fetchRequest setPredicate:[NSCompoundPredicate andPredicateWithSubpredicates:predicates]];
        
        countNotNew = [[FlashCardsCore mainMOC] countForFetchRequest:fetchRequest error:nil];
        // TODO: Handle the error
        
    }

    NSMutableString *labelText = [[NSMutableString alloc] initWithCapacity:0];
    if (studyController.studyAlgorithm == studyAlgorithmTest) {
        [labelText appendString:NSLocalizedStringFromTable(@"All cards in this set have already been memorized and entered into Spaced Repetition, so there are no cards in this set which need to be tested at this time.", @"Study", @"")];
    } else if (studyController.studyAlgorithm == studyAlgorithmRepetition) {
        [labelText appendString:NSLocalizedStringFromTable(@"There are no cards which need to be studied with Spaced Repetition at this time.", @"Study", @"")];
    } else if (studyController.studyAlgorithm == studyAlgorithmLapsed) {
        [labelText appendString:NSLocalizedStringFromTable(@"There are no lapsed cards which need to be studied at this time.", @"Study", @"")];
    } else {
        if (self.studyController.loadNewCardsOnly && countNotNew > 0) {
            [labelText appendString:NSLocalizedStringFromTable(@"There are no new cards in this card set, i.e. all cards have been added to Spaced Repetition. Would you like to study old cards?", @"Study", @"")];
        } else {
            [labelText appendString:NSLocalizedStringFromTable(@"There are no cards in this card set, add some cards to begin studying.", @"Study", @"")];
        }
    }
    
    RIButtonItem *okItem = [RIButtonItem item];
    okItem.label = NSLocalizedStringFromTable(@"OK", @"FlashCards", @"cancelButtonTitle");
    okItem.action = ^{
        [self exitViewController];
    };
    
    RIButtonItem *cancelItem = [RIButtonItem item];
    cancelItem.label = NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"cancelButtonTitle");
    cancelItem.action = ^{
        [self exitViewController];
    };
    
    RIButtonItem *studyAgainItem = [RIButtonItem item];
    studyAgainItem.label = NSLocalizedStringFromTable(@"Study Again", @"Study", @"otherButtonTitles");
    studyAgainItem.action = ^{
        StudySettingsViewController *studyVC = [[StudySettingsViewController alloc] initWithNibName:@"StudySettingsViewController" bundle:nil];
        studyVC.collection = self.collection;
        studyVC.cardSet = self.cardSet;
        studyVC.studyingImportedSet = YES;
        
        studyVC.studyAlgorithm = studyAlgorithmLearn;
        
        
        NSMutableArray *viewControllers = [[NSMutableArray alloc] initWithArray:[self.navigationController viewControllers]];
        [viewControllers removeLastObject];
        [viewControllers addObject:studyVC];
        
        [self.navigationController setViewControllers:viewControllers animated:NO];
    };

    RIButtonItem *studyOldCardsItem = [RIButtonItem item];
    studyOldCardsItem.label = NSLocalizedStringFromTable(@"Study Old Cards", @"Study", @"otherButtonTitles");
    studyOldCardsItem.action = ^{
        self.studyController.loadNewCardsOnly = NO;
        
        // build the list of cards:
        [self.studyController loadCardsFromStore];
        [self.studyController translateCardsToCardTests];
        
        // go straight to the studying; skip settings screen:
        if (studyController.studyAlgorithm == studyAlgorithmTest ||
            studyController.studyAlgorithm == studyAlgorithmRepetition) {
            [self beginTest:nil];
        } else {
            [self beginStudying:self];
        }
        
        failPassChanging = NO;
        
        if ([studyController numCards] == 0 && !hasAlreadyLoaded) {
            [self showNoCardsAlert];
        }
        hasAlreadyLoaded = YES;
    };
    
    UIAlertView *alert;
    if ([studyController studyAlgorithmIsTest] && countNotNew > 0) {
        [labelText appendFormat:@"\n\n%@", NSLocalizedStringFromTable(@"You may also choose to re-study your cards again by tapping \"Study Again\" below.", @"Study", @"")];
        alert = [[UIAlertView alloc] initWithTitle:@""
                                           message:labelText
                                  cancelButtonItem:okItem
                                  otherButtonItems:studyAgainItem, nil];
    } else {
        if (studyController.studyAlgorithm == studyAlgorithmLearn && countNotNew > 0 && self.studyController.loadNewCardsOnly) {
            alert = [[UIAlertView alloc] initWithTitle:@""
                                               message:labelText
                                      cancelButtonItem:cancelItem
                                      otherButtonItems:studyOldCardsItem, nil];
        } else {
            alert = [[UIAlertView alloc] initWithTitle:@""
                                               message:labelText
                                      cancelButtonItem:okItem
                                      otherButtonItems:nil];
        }
    }
    [alert show];        
}

#pragma mark -
#pragma mark Card Configuration functions

-(int)bottomOfStudyZoneY {
    int bottomOfStudyZone;
    if (isFullScreen && ![self resultsDisplayed]) {
        bottomOfStudyZone = self.view.frame.size.height;
    } else {
        // if it's not full screen, the bottom of the study zone is the top of the bottomToolbarStudy control:
        bottomOfStudyZone = bottomToolbarStudy.frame.origin.y;
    }
    return bottomOfStudyZone;
}

-(void)layoutPassFailSegmentedController {
    int startPoint = 290; // this will be origin.Y
    int rowHeight; // this is how high each of the rows of the segmented control will be.
    if ([FlashCardsAppDelegate isIpad]) {
        rowHeight = 90;
        if ([self isLandscape]) {
            // it is landscape:
            startPoint = 470;
            startPoint += rowHeight; // there is only one row of buttons.
        } else {
            // it is portrait
            startPoint = 730;
        }
    } else {
        
        if ([self isLandscape]) {
            // it is landscape:
            startPoint = 99+80; // 99 was original start point, plus 60 for first row, plus 20 for the space taken off of row.
            rowHeight = 40;
        } else {
            // it is portrait:
            startPoint = 244;
            rowHeight = 60;
        }
    }
    
    int passFailSegmentedControlHeight = rowHeight*2;
    if ([FlashCardsAppDelegate isIpad]) {
        rowHeight = 90;
        if ([self isLandscape]) {
            passFailSegmentedControlHeight = 90;
        }
    } else {
        if ([self isLandscape]) {
            rowHeight = 40;
            passFailSegmentedControlHeight = rowHeight;
        } else {
            rowHeight = 60;
            passFailSegmentedControlHeight = rowHeight*2;
        }
    }
    int bottomOfStudyZone = [self bottomOfStudyZoneY];
    int passFailSegmentedControlY = bottomOfStudyZone-10-passFailSegmentedControlHeight;
    if (([self interfaceOrientation] == UIInterfaceOrientationLandscapeLeft ||
         [self interfaceOrientation] == UIInterfaceOrientationLandscapeRight)
        && ![FlashCardsAppDelegate isIpad] && !isFullScreen) {
        passFailSegmentedControlY += bottomToolbarStudy.frame.size.height;
    }
    [passFailSegmentedControl setFrame:CGRectMake(10, passFailSegmentedControlY,
                                                  self.view.frame.size.width-20, 88)];
    if ([self isLandscape]) {
        NSArray *segmentTitles = [[NSArray alloc] initWithObjects:
                                  NSLocalizedStringFromTable(@"No Score", @"Study", @"score"),
                                  NSLocalizedStringFromTable(@"1: Fail", @"Study", @"score"),
                                  NSLocalizedStringFromTable(@"2: Almost", @"Study", @"score"),
                                  NSLocalizedStringFromTable(@"3: Barely", @"Study", @"score"),
                                  NSLocalizedStringFromTable(@"4: OK", @"Study", @"score"),
                                  NSLocalizedStringFromTable(@"5: Easy!", @"Study", @"score"),
                                  nil];
        [passFailSegmentedControl setSegmentTitles:segmentTitles];
        [passFailSegmentedControl setRowCount:1];
        [passFailSegmentedControl setColumnCount:6];
    } else {
        NSArray *segmentTitles = [[NSArray alloc] initWithObjects:
                                  NSLocalizedStringFromTable(@"3: Barely", @"Study", @"score"),
                                  NSLocalizedStringFromTable(@"4: OK", @"Study", @"score"),
                                  NSLocalizedStringFromTable(@"5: Easy!", @"Study", @"score"),
                                  NSLocalizedStringFromTable(@"No Score", @"Study", @"score"),
                                  NSLocalizedStringFromTable(@"1: Fail", @"Study", @"score"),
                                  NSLocalizedStringFromTable(@"2: Almost", @"Study", @"score"),
                                  nil];
        [passFailSegmentedControl setSegmentTitles:segmentTitles];
        [passFailSegmentedControl setRowCount:2];
        [passFailSegmentedControl setColumnCount:3];
    }
    [passFailSegmentedControl setPositionY:passFailSegmentedControlY];
    [passFailSegmentedControl setRowHeight:rowHeight];
    [passFailSegmentedControl layoutSubviews];
}

-(void)layoutBackBanner {
    int passFailSegmentedControlY = passFailSegmentedControl.frame.origin.y;
    
    ADBannerView *backBanner = [[FlashCardsCore appDelegate] bannerAd];
    if (![FlashCardsCore hasFeature:@"HideAds"] && backBanner) {
        if (UIInterfaceOrientationIsLandscape([self interfaceOrientation])) {
            backBanner.currentContentSizeIdentifier = ADBannerContentSizeIdentifierLandscape;
        } else {
            backBanner.currentContentSizeIdentifier = ADBannerContentSizeIdentifierPortrait;
        }
    }
    
    // determine where the card should end on the screen:
    float bottomControlsY = passFailSegmentedControl.frame.origin.y;
    if (![FlashCardsCore hasFeature:@"HideAds"] && backBanner && backBanner.bannerLoaded) {
        bottomControlsY = bottomControlsY - backBanner.frame.size.height - 3;
    }
    
    [backScrollView setFrame:CGRectMake(backScrollView.frame.origin.x,
                                        backScrollView.frame.origin.y,
                                        backScrollView.frame.size.width,
                                        (bottomControlsY-10)-backScrollView.frame.origin.y)];
}

-(void)displayCardData {
    CardTest *testCard = [studyController currentCard];
    id cardData;
    NSSet *relatedCards;
    NSData *frontImageData, *backImageData;
    if (previewMode) {
        cardData = previewCard;
        relatedCards = (NSSet*)[[previewCard objectForKey:@"relatedCards"]  filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"isDeletedObject = NO"]];
        frontImageData = (NSData*)[previewCard objectForKey:@"frontImageData"];
        backImageData = (NSData*)[previewCard objectForKey:@"backImageData"];
    } else {
        relatedCards = [NSSet setWithSet:[testCard.card.relatedCards filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"isDeletedObject = NO"]]];
        frontImageData = [NSData dataWithData:testCard.card.frontImageData];
        backImageData = [NSData dataWithData:testCard.card.backImageData];
        
        cardData = testCard.card;
        
        // always show the card # label if we are testing:
        if (testCard.isTest && [self cardFrontIsShown]) {
            cardNumberLabel.hidden = NO;
        }
        [cardNumberLabel setIsAccessibilityElement:!cardNumberLabel.hidden];
        
        // reset the study timer
        // However, we don't want to reset the timer if we are re-configuring the card!!
        if (!testCard.studyBegan) {
            testCard.studyBegan = [NSDate date];
            testCard.studyPauseLength = 0.0;
        }
        
        cardNumberLabel.text = [NSString stringWithFormat:NSLocalizedStringFromTable(@"%d of %d", @"Study", @"1 of 3"), (studyController.currentCardIndex+1), [studyController numCards]];
        
    }
    
    int showSide;
    if (studyController.showFirstSide == showFirstSideRandom) {
        if (testCard.showSide == -1) {
            if ((arc4random() % 2) == 0) {
                showSide = showFirstSideFront;
            } else {
                showSide = showFirstSideBack;
            }
            testCard.showSide = showSide;
        } else {
            showSide = testCard.showSide;
        }
    } else {
        showSide = studyController.showFirstSide;
    }
    
    NSString *frontLanguage, *backLanguage;
    if (showSide == showFirstSideFront) {
        frontLanguage = self.collection.frontValueLanguage;
        backLanguage = self.collection.backValueLanguage;
    } else {
        frontLanguage = self.collection.backValueLanguage;
        backLanguage = self.collection.frontValueLanguage;
    }
    
    BOOL displayAsCard = [FlashCardsCore getSettingBool:@"studyDisplayLikeIndexCard"];
    [self configureImage:[NSData dataWithData:frontImageData]
            inScrollView:(showSide == showFirstSideFront ? self.frontScrollView : self.backScrollView)
        andDisplayAsCard:displayAsCard];
    [self configureImage:[NSData dataWithData:backImageData]
            inScrollView:(showSide == showFirstSideFront ? self.backScrollView : self.frontScrollView)
        andDisplayAsCard:displayAsCard];
    
    if ([frontLanguage usesLatex]) {
        frontLabel.hidden = YES;
        frontWebview.hidden = NO;
    } else {
        frontLabel.hidden = NO;
        frontWebview.hidden = YES;
    }
    if ([backLanguage usesLatex]) {
        backLabel.hidden = YES;
        backWebview.hidden = NO;
    } else {
        backLabel.hidden = NO;
        backWebview.hidden = YES;
    }
    
    int bottomOfStudyZone = [self bottomOfStudyZoneY];
    float maxSize = (bottomOfStudyZone - 10) - frontScrollView.frame.origin.y;
    if (([self interfaceOrientation] == UIInterfaceOrientationLandscapeLeft ||
         [self interfaceOrientation] == UIInterfaceOrientationLandscapeRight)
        && ![FlashCardsAppDelegate isIpad] && !isFullScreen) {
        maxSize += bottomToolbarStudy.frame.size.height;
    }
    ADBannerView *backBanner = [[FlashCardsCore appDelegate] bannerAd];
    if (![FlashCardsCore hasFeature:@"HideAds"] && backBanner && backBanner.bannerLoaded) {
        maxSize -= backBanner.frame.size.height;
    }

    [frontScrollView setPositionHeight:maxSize];
    
    [self configureBackSide:cardData showSide:showSide relatedCards:relatedCards language:backLanguage];
    [self configureFrontSide:cardData showSide:showSide language:frontLanguage];
    
    TTSButton.userInteractionEnabled = YES;

}

-(void)showBannerAd {
    [self configureCard];
}
-(void)hideBannerAd {
    [self configureCard];
}

-(void)configureCard {

    cardNumberLabel.hidden = ![self shouldShowCardNumberLabel];
    [cardNumberLabel setIsAccessibilityElement:!cardNumberLabel.hidden];
    
    bottomToolbarStudy.hidden = NO;
    if (([self interfaceOrientation] == UIInterfaceOrientationLandscapeLeft ||
         [self interfaceOrientation] == UIInterfaceOrientationLandscapeRight)
        && ![FlashCardsAppDelegate isIpad]) {
        bottomToolbarStudy.hidden = YES;
    }
    if (isFullScreen) {
        bottomToolbarStudy.hidden = YES;
    }

    bottomToolbarResults.hidden = YES;
    bottomToolbarTestResults.hidden = YES;
    
    [TTSActivityIndicator setHidden:YES];
    [TTSActivityIndicator stopAnimating];
    
    // enable or disable the PREVIOUS button:
    if (!previewMode) {
        BOOL prevEnabled = YES;
        if ([studyController studyAlgorithmIsLearning]) {
            // In a looped algorithm (e.g. linear or random), "< prev" button should be disabled in the first loop.
            if (studyController.currentRound == 0 && studyController.currentCardIndex == 0) {
                prevEnabled = NO;
            }
        } else {
            // In a non-looped algorithm (e.g. test), "< prev" button should be disabled in the first card.
            if (studyController.currentCardIndex == 0) {
                prevEnabled = NO;
            }
        }
        
        UIBarButtonItem *prevButton = [self.navigationItem.rightBarButtonItems objectAtIndex:1];
        [prevButton setEnabled:prevEnabled];
        [prevButton setIsAccessibilityElement:prevEnabled];
    } else {
        // set the score to 0:
        [self setScore:0];
    }
    
    // Actually display the card if there is something to be displayed:
    if (([studyController numCards] > 0 && studyController.cardListIsTranslated) || previewMode) {
        
        [self layoutPassFailSegmentedController];
        [self layoutBackBanner];

        if (!previewMode && studyController.currentCardIndex == [studyController numCards]) {
            // If it is equal, then display the results:
            [self displayResults:nil animated:NO];
            BOOL isBackSide = NO;
            [self positionBannerAd:isBackSide];
            return;
        }
        
        [self displayCardData];
    }
    BOOL isBackSide = ![self cardFrontIsShown];
    [self positionBannerAd:isBackSide];
    
}

-(void)configureImage:(NSData*)data inScrollView:(UIScrollView*)scrollView andDisplayAsCard:(BOOL)displayAsCard {
    UIImage *image;
    UIImageView *imageView = ([scrollView isEqual:self.backScrollView] ? self.backImage : self.frontImage);
    if (data && [data length] > 0) {
        int maxImageWidth = scrollView.frame.size.width - (displayAsCard ? 20 : 0);
        int x, height;
        image = [[UIImage alloc] initWithData:data];
        [imageView setImage:image];
        // Set the proper image size depending on the size of the image relative to the scroll view:
        if (image.size.width < maxImageWidth) {
            x = ((scrollView.frame.size.width - image.size.width) / 2);
            [imageView setFrame:CGRectMake(x,
                                           imageView.frame.origin.y,
                                           image.size.width,
                                           image.size.height)];
        } else {
            x = ((scrollView.frame.size.width - maxImageWidth) / 2);
            height = image.size.height * (maxImageWidth / image.size.width);
            [imageView setFrame:CGRectMake(x,
                                           imageView.frame.origin.y,
                                           maxImageWidth,
                                           height)];
        }
        [imageView setHidden:NO];
    } else {
        [imageView setImage:nil];
        [imageView setHidden:YES];
    }
}
-(BOOL)shouldShowCardNumberLabel {
    if (previewMode) {
        return NO;
    }
    if (![self cardFrontIsShown]) {
        return NO;
    }
    if ([self resultsDisplayed] || studyController.studyOrder == studyOrderSmart) {
        // hide the card number label - we don't want the user to see that they are studying more
        // than the actual # of cards!!
        return NO;
    } else {
        return YES;
    }
}

-(NSString*)justificationText {
    int studyCardJustification = [FlashCardsCore getSettingInt:@"studyCardJustification"];
    /*
     int const justifyCardLeft = 0;
     int const justifyCardCenter = 1;
     int const justifyCardRight = 2;
     */
    NSString *textAlignment;
    switch (studyCardJustification) {
        default:
        case 1:
            textAlignment = @"center";
            break;
        case 0:
            textAlignment = @"left";
            break;
        case 2:
            textAlignment = @"right";
            break;
    }
    return textAlignment;
}
-(int)fontSizeForLabel:(UILabel*)label {
    int size;
    /*
     // List of options for text size:
     int const sizeExtraLarge = 0;
     int const sizeLarge = 1;
     int const sizeNormal = 2;
     int const sizeSmall = 3;
     int const sizeExtraExtraLarge = 4;
     int const sizeExtraSmall = 5;
     int const sizeExtraExtraSmall = 6;
     */
    
    if ([FlashCardsAppDelegate isIpad]) {
        switch (textSize) {
            case 4:
                size = 115;
                break;
                
            case 0:
                size = 80;
                break;
                
            case 1:
                size = 64;
                break;
                
            default:
            case 2:
                size = 48;
                break;
                
            case 3:
                size = 40;
                break;
            
            case 5:
                size = 25;
                break;

            case 6:
                size = 15;
                break;
        }
    } else {
        switch (textSize) {
            case 4:
                size = 55;
                break;
                
            case 0:
                size = 45;
                break;
                
            case 1:
                size = 35;
                break;
                
            default:
            case 2:
                size = 20;
                break;
                
            case 5:
            case 6:
            case 3:
                size = 12;
                break;
        }
        // we want to find a better way to determine orientation than UIInterfaceOrientationIsPortrait.
        // Since the height is variable, we will determine orientation based on whether the backLabel width
        // is greater than the default portrait width of 300. If it's greater, then it means it's in landscape mode.
        if (label.frame.size.width <= 300) {
            size += 5;
        }
    }
    return size;
}

- (void)setupLabel:(UILabel*)label withString:(NSMutableAttributedString*)attributedString {
    if (attributedString) {
        NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
        [paragraph setParagraphStyle:[NSParagraphStyle defaultParagraphStyle]];
        int studyCardJustification = [(NSNumber*)[FlashCardsCore getSetting:@"studyCardJustification"] intValue];
        /*
         int const justifyCardLeft = 0;
         int const justifyCardCenter = 1;
         int const justifyCardRight = 2;
         */
        switch (studyCardJustification) {
            default:
            case 1:
                // for some reason right and center are getting mixed up... so I swapped them
                paragraph.alignment = kCTRightTextAlignment;
                break;
            case 0:
                paragraph.alignment = kCTLeftTextAlignment;
                break;
            case 2:
                paragraph.alignment = kCTCenterTextAlignment;
                break;
        }
        paragraph.paragraphSpacing = 12.0f;
        
        UIColor *backgroundTextColor = [UIColor colorWithString:(NSString *)[FlashCardsCore getSetting:@"studySettingsBackgroundTextColor"]];
        
        // if something strange happens to the colors, set them to be black & white:
        if (!backgroundTextColor) {
            backgroundTextColor = [UIColor whiteColor];
        }
        UIColor *cardBackgroundTextColor;
        if ([FlashCardsCore getSettingBool:@"studyDisplayLikeIndexCard"]) {
            cardBackgroundTextColor = [UIColor blackColor];
        } else {
            cardBackgroundTextColor = backgroundTextColor;
        }
        
        if (!cardNumberLabel.hidden) {
            cardNumberLabel.textColor = cardBackgroundTextColor;
        }

        [attributedString setParagraphStyle:paragraph];
        if (![DTVersion osVersionIsLessThen:@"6.0"]) {
            [attributedString addAttribute:NSForegroundColorAttributeName value:cardBackgroundTextColor range:NSMakeRange(0, [attributedString length])];
            [label setAttributedText:attributedString];
        } else {
            [label setText:[attributedString string]];
            [label setTextColor:cardBackgroundTextColor];
        }
    }
    
    CGSize maxSize = CGSizeMake(label.superview.frame.size.width, 100000.0f);
    CGSize size = [attributedString sizeConstrainedToSize:maxSize];
    
    [label setPositionWidth:label.superview.frame.size.width];
    [label setNumberOfLines:0];
    [label sizeToFit];
    [label setPositionWidth:label.superview.frame.size.width];
    if (attributedString && label.frame.size.height < size.height) {
        [label setPositionHeight:size.height];
    }
    
}

-(void)setLabelFontSize:(UILabel*)label {
    int fontSize = [self fontSizeForLabel:label];
    [label setFont:[UIFont fontWithName:((NSString*)[FlashCardsCore getSetting:@"studyCardFont"]) size:(float)fontSize]];
}

# pragma mark -
# pragma mark Configure Front Side

-(void)configureFrontSide:(id)cardData
                 showSide:(int)side
                 language:(NSString*)language {

    NSString *_frontLabelText = [cardData valueForKey:(side == showFirstSideFront ? @"frontValue" : @"backValue")];
    [frontScrollView setContentSize:CGSizeMake(frontLabel.frame.size.width,
                                               frontLabel.frame.size.height) ];

    UIView *prevView = nil;
    
    BOOL displayAsCard = [FlashCardsCore getSettingBool:@"studyDisplayLikeIndexCard"];

    if (displayAsCard) {
        frontCardImageTop.hidden = NO;
        frontDropshadowImage.hidden = NO;
        frontCardImageBottom.hidden = NO;
        [frontCardImageTop setPositionZero];
        prevView = frontCardImageTop;
    } else {
        [frontCardImageTop setPositionHidden];
        if (!cardNumberLabel.hidden) {
            [frontView setPositionY:cardNumberLabel.frame.size.height+3];
            prevView = cardNumberLabel; // so that, when we position the frontView, it doesn't go all the way to the top.
        }
    }
    
    frontView.hidden = NO;
    
    UIView *prevViewInside = nil;
    NSMutableAttributedString *attributedString;
    
    int fontSize = [self fontSizeForLabel:frontLabel];
    UIFont *font = [UIFont fontWithName:((NSString*)[FlashCardsCore getSetting:@"studyCardFont"]) size:(float)fontSize];
    if ([language usesLatex]) {
        frontLabel.hidden = YES;
        [frontWebview setPositionWidth:frontWebview.superview.frame.size.width];
        frontWebview.hidden = NO;

        // encode MathJax special characters so they are not screwed up by MarkDown:
        NSString *frontTextMathJaxEncoded = [_frontLabelText stringByEncodingMathJaxEntities];
        NSString *frontTextSimpleHtml = [frontTextMathJaxEncoded toSimpleHtml];
        NSString *finalFrontText = [frontTextSimpleHtml stringByDecodingMathJaxEntities];
        
        NSURL* url = [FlashCardsCore urlForLatexMathString:finalFrontText withJustification:[self justificationText] withSize:fontSize withFilename:@"frontside.html"];
        frontWebview.scalesPageToFit = YES;
        frontWebview.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
        NSURLRequest* req = [[NSURLRequest alloc] initWithURL:url];
        // as per: http://stackoverflow.com/a/9827105/353137
        self.frontWebview.bk_shouldStartLoadBlock = ^BOOL(UIWebView *aWebView, NSURLRequest *aRequest, UIWebViewNavigationType aNavigationType) {
            if (![aRequest.URL.scheme isEqualToString:@"fcppweb"]) {
                return YES;
            }
            FCLog(@"Finished loading FRONT mathjax");
            
            [frontWebview setPositionBehind:prevViewInside distance:0];
            UIView *prevViewInside = frontWebview;
            
            CGRect frame = aWebView.frame;
            frame.size.height = [self.view webviewContentHeight:aWebView];
            aWebView.frame = frame;       // Set the scrollView contentHeight back to the frame itself.
            
            [self configureFrontHeights:prevView withPrevViewInside:prevViewInside language:language attributedString:nil];
            return NO;
        };
        self.frontWebview.bk_didFinishLoadBlock = ^(UIWebView *aWebView) {
            FCLog(@"Finished loading FRONT html");
        };
        [frontWebview setPositionBehind:prevViewInside distance:0];
        prevViewInside = frontWebview;
        [frontLabel setPositionHidden];
        [frontWebview loadRequest:req];
    } else {
        frontLabel.hidden = NO;
        frontWebview.hidden = YES;
        [frontWebview setPositionHidden];
        
        attributedString = [_frontLabelText attributedStringWithFont:font
                                                   useiOS6Attributes:YES
                                                         useMarkdown:[FlashCardsCore getSettingBool:@"studySettingsUseMarkdown"]];
        [self configureFrontHeightsLabel:_frontLabelText andAttributedString:attributedString];
        
        float heightOfSubviews = [frontView heightOfSubviews];
        if (frontView.frame.size.height != heightOfSubviews) {
            [frontView setPositionHeight:heightOfSubviews + (displayAsCard ? 20 : 0)];
            [self configureFrontHeightsLabel:_frontLabelText andAttributedString:attributedString];
        }
        
        // check if the frontLabel has a string. If it does, then pass this as the prevViewInside:
        if (frontLabel.attributedText.length > 0) {
            prevViewInside = frontLabel;
        }

        [self configureFrontHeights:prevView withPrevViewInside:prevViewInside language:language attributedString:attributedString];
    }
    
}

- (void)setFrontViewPositionBehind:(UIView*)positionBehind distance:(int)distance {
    [frontView setPositionBehind:positionBehind distance:distance];
    
    BOOL displayAsCard = [FlashCardsCore getSettingBool:@"studyDisplayLikeIndexCard"];
    if (displayAsCard) {
        [frontCardImageBottom setPositionBehind:frontView distance:0];
    } else {
        [frontCardImageBottom setPositionHidden];
    }
}

- (void)setFrontViewPositionHeight:(float)height {
    [frontView setPositionHeight:height];
    
    BOOL displayAsCard = [FlashCardsCore getSettingBool:@"studyDisplayLikeIndexCard"];
    if (displayAsCard) {
        [frontCardImageBottom setPositionBehind:frontView distance:0];
    } else {
        [frontCardImageBottom setPositionHidden];
    }
}

-(void)configureFrontHeights:(UIView*)prevView
          withPrevViewInside:(UIView*)prevViewInside
                    language:(NSString*)language
            attributedString:(NSMutableAttributedString*)attributedString {
    [self configureFrontHeightsAfterLabel:prevViewInside];
    
    BOOL displayAsCard = [FlashCardsCore getSettingBool:@"studyDisplayLikeIndexCard"];
    [self setFrontViewPositionBehind:prevView distance:0];
    prevView = frontView;
    
    int bottomOfStudyZone = [self bottomOfStudyZoneY];
    float maxSize = (bottomOfStudyZone - 10) - frontScrollView.frame.origin.y;
    if (([self interfaceOrientation] == UIInterfaceOrientationLandscapeLeft ||
         [self interfaceOrientation] == UIInterfaceOrientationLandscapeRight)
        && ![FlashCardsAppDelegate isIpad] && !isFullScreen) {
        maxSize += bottomToolbarStudy.frame.size.height;
    }
    ADBannerView *backBanner = [[FlashCardsCore appDelegate] bannerAd];
    if (![FlashCardsCore hasFeature:@"HideAds"] && backBanner && backBanner.bannerLoaded) {
        maxSize -= backBanner.frame.size.height;
    }
    float maxContentSize = maxSize - frontCardImageTop.frame.size.height - frontCardImageBottom.frame.size.height;
    
    float heightOfSubviews = [frontScrollView heightOfSubviewsExcept:@[frontCardImageBottom, frontCardImageTop]];
    if ([language usesLatex]) {
        if (heightOfSubviews < maxSize) {
            [self setFrontViewPositionHeight:maxContentSize];
        } else {
            [self setFrontViewPositionHeight:heightOfSubviews];
        }
        CGRect frame = frontWebview.frame;
        frame.size.height = [self.view webviewContentHeight:frontWebview];
        frontWebview.frame = frame;       // Set the scrollView contentHeight back to the frame itself.
        frontLabel.hidden = YES;
    } else {
        // need to keep the front label to the proper size, otherwise the code to center the text will not work.
        [self setupLabel:frontLabel withString:attributedString];
        
        // if the text is smaller than size of the screen, center it or so, to make it look good:
        heightOfSubviews = [frontScrollView heightOfSubviews];
        if (heightOfSubviews < maxSize) {
            [self setFrontViewPositionHeight:maxContentSize];
            
            // need to keep the front label to the proper size, otherwise the code to center the text will not work.
            [self setupLabel:frontLabel withString:attributedString];
        } else {
            [self setFrontViewPositionHeight:heightOfSubviews];
        }
    }
    
    // center the front view:
    heightOfSubviews = [frontScrollView heightOfSubviewsExcept:@[frontCardImageBottom, frontCardImageTop]];
    if (heightOfSubviews < maxSize) {
        prevViewInside = nil;
        // Instead of (max - height) / 2 [which is used in the back], divide by 3, which
        // brings the content a bit farther up the screen.
        float y = ((maxContentSize - heightOfSubviews) / 3);
        if (y >= 29) {
            //    y -= 29;
        }
        if ([language usesLatex]) {
            [frontWebview setPositionBehind:prevViewInside orSetY:y];
            prevViewInside = frontWebview;
        } else if (frontLabelText.length > 0) {
            [frontLabel setPositionBehind:prevViewInside orSetY:y];
            prevViewInside = frontLabel;
        } else {
            [frontLabel setPositionHidden];
        }
        
        if (!frontImage.hidden) {
            [frontImage setPositionBehind:prevViewInside orSetY:y];
            prevViewInside = frontImage;
        } else {
            [frontImage setPositionHidden];
        }
    }
    
    if (displayAsCard) {
        [frontCardImageBottom setPositionBehind:prevView distance:0];
        [frontDropshadowImage setPositionY:frontCardImageTop.frame.size.height];
        [frontDropshadowImage setPositionHeight:frontView.frame.size.height];
    } else {
        [frontDropshadowImage setHidden:YES];
        [frontCardImageBottom setPositionHidden];
    }
    
    
    heightOfSubviews = [frontScrollView heightOfSubviews];
    // this causes one little bitty problem -- on the iPad, when there is long text for the card's
    // front value, on the front side swiping does not work!!
    if (frontScrollView.frame.size.height >= heightOfSubviews && [FlashCardsAppDelegate isIpad]) {
        frontScrollView.userInteractionEnabled = NO;
    } else {
        frontScrollView.userInteractionEnabled = YES;
    }
    [frontScrollView setContentSize:CGSizeMake(frontScrollView.frame.size.width,  heightOfSubviews) ];
    [frontScrollView setClipsToBounds:YES];

}

-(void)configureFrontHeightsLabel:(NSString *)_frontLabelText
              andAttributedString:(NSMutableAttributedString*)attributedString {
    UIView *prevViewInside = nil;
    
    [frontLabel setAttributedText:attributedString];
    frontLabelText = _frontLabelText;
    
    if ([frontLabelText length] > 0) {
        [self setupLabel:frontLabel withString:attributedString];
        [frontLabel setPositionBehind:prevViewInside distance:0];
        prevViewInside = frontLabel;
    } else {
        [frontLabel setPositionHidden];
    }
    
    if (!frontImage.hidden) {
        [frontImage setPositionBehind:prevViewInside];
        prevViewInside = frontImage;
    } else {
        [frontImage setPositionHidden];
    }
}

-(void)configureFrontHeightsAfterLabel:(UIView*)prevViewInside {
    if (frontImage.hidden) {
        [frontImage setPositionHidden];
    } else {
        [frontImage setPositionBehind:prevViewInside];
        prevViewInside = frontImage;
    }
}

# pragma mark -
# pragma mark Configure Back Side

-(void)configureBackSide:(id)cardData showSide:(int)side relatedCards:(NSSet*)relatedCards language:(NSString*)language {
    
    UIView *prevView = nil;
    
    BOOL displayAsCard = [FlashCardsCore getSettingBool:@"studyDisplayLikeIndexCard"];
    
    if (displayAsCard) {
        [backCardImageTop setPositionZero];
        prevView = backCardImageTop;
    } else {
        [backCardImageTop setPositionHidden];
    }
    NSString *_backLabelText = [cardData valueForKey:(side == showFirstSideFront ? @"backValue" : @"frontValue")];

    NSMutableAttributedString *attributedString;
    UIView *prevViewInside = nil;

    int fontSize = [self fontSizeForLabel:backLabel];
    UIFont *font = [UIFont fontWithName:((NSString*)[FlashCardsCore getSetting:@"studyCardFont"]) size:(float)fontSize];

    float heightOfSubviews;
    
    if ([language usesLatex]) {
        [backWebview setPositionWidth:backWebview.superview.frame.size.width];
        backWebview.hidden = NO;
        
        // encode MathJax special characters so they are not screwed up by MarkDown:
        NSString *backTextMathJaxEncoded = [_backLabelText stringByEncodingMathJaxEntities];
        NSString *backTextSimpleHtml = [backTextMathJaxEncoded toSimpleHtml];
        NSString *finalBackText = [backTextSimpleHtml stringByDecodingMathJaxEntities];

        NSURL* url = [FlashCardsCore urlForLatexMathString:finalBackText withJustification:[self justificationText] withSize:fontSize withFilename:@"backside.html"];
        backWebview.scalesPageToFit = YES;
        backWebview.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
        NSURLRequest* req = [[NSURLRequest alloc] initWithURL:url];
        // as per: http://stackoverflow.com/a/9827105/353137
        self.backWebview.bk_shouldStartLoadBlock = ^BOOL(UIWebView *aWebView, NSURLRequest *aRequest, UIWebViewNavigationType aNavigationType) {
            if (![aRequest.URL.scheme isEqualToString:@"fcppweb"]) {
                return YES;
            }
            FCLog(@"Finished loading BACK mathjax");
            
            [backWebview setPositionBehind:prevViewInside distance:0];
            UIView *prevViewInside = backWebview;
            
            CGRect frame = aWebView.frame;
            frame.size.height = [self.view webviewContentHeight:aWebView];
            aWebView.frame = frame;       // Set the scrollView contentHeight back to the frame itself.
            
            [self configureBackHeights:prevView withPrevViewInside:prevViewInside language:language attributedString:nil relatedCards:relatedCards];
            return NO;
        };
        self.backWebview.bk_didFinishLoadBlock = ^(UIWebView *aWebView) {
            FCLog(@"Finished loading BACK html");
        };
        [backWebview setPositionBehind:prevViewInside distance:0];
        prevViewInside = backWebview;
        [backLabel setPositionHidden];
        [backWebview loadRequest:req];
    } else {
        backWebview.hidden = YES;
        [backWebview setPositionHidden];
        attributedString = [_backLabelText attributedStringWithFont:font
                                                  useiOS6Attributes:YES
                                                        useMarkdown:[FlashCardsCore getSettingBool:@"studySettingsUseMarkdown"]];
        
        [self configureBackHeightsLabel:attributedString relatedCards:relatedCards language:language];
        
        heightOfSubviews = [backView heightOfSubviews];
        if (backView.frame.size.height != heightOfSubviews) {
            [backView setPositionHeight:heightOfSubviews+(displayAsCard ? 20 : 0)];
            [self configureBackHeightsLabel:attributedString relatedCards:relatedCards language:language];
        }
        
        // check if the backLabel has a string. If it does, then pass this as the prevViewInside:
        if (backLabel.attributedText.length > 0) {
            prevViewInside = backLabel;
        }
        
        [self configureBackHeights:prevView withPrevViewInside:prevViewInside language:language attributedString:attributedString relatedCards:relatedCards];
    }
}

- (void)setBackViewPositionBehind:(UIView*)positionBehind distance:(int)distance {
    [backView setPositionBehind:positionBehind distance:distance];

    BOOL displayAsCard = [FlashCardsCore getSettingBool:@"studyDisplayLikeIndexCard"];
    if (displayAsCard) {
        [backCardImageBottom setPositionBehind:backView distance:0];
    } else {
        [backCardImageBottom setPositionHidden];
    }
}

- (void)setBackViewPositionHeight:(float)height {
    [backView setPositionHeight:height];

    BOOL displayAsCard = [FlashCardsCore getSettingBool:@"studyDisplayLikeIndexCard"];
    if (displayAsCard) {
        [backCardImageBottom setPositionBehind:backView distance:0];
    } else {
        [backCardImageBottom setPositionHidden];
    }
}

- (void)configureBackHeights:(UIView*)prevView
          withPrevViewInside:(UIView*)prevViewInside
                    language:(NSString*)language
            attributedString:(NSMutableAttributedString*)attributedString
                relatedCards:(NSSet*)relatedCards
{
    float heightOfSubviews;
    
    [self configureBackHeightsAfterLabel:prevViewInside relatedCards:relatedCards];
    
    BOOL displayAsCard = [FlashCardsCore getSettingBool:@"studyDisplayLikeIndexCard"];
    [self setBackViewPositionBehind:prevView distance:0];
    
    // determine where the card should end on the screen:
    float bottomControlsY = passFailSegmentedControl.frame.origin.y;
    ADBannerView *backBanner = [[FlashCardsCore appDelegate] bannerAd];
    if (![FlashCardsCore hasFeature:@"HideAds"] && backBanner && backBanner.bannerLoaded) {
        bottomControlsY = bottomControlsY - backBanner.frame.size.height;
    }
    float maxSize = (bottomControlsY - 10) - backScrollView.frame.origin.y;
    float maxContentSize = maxSize - backCardImageTop.frame.size.height - backCardImageBottom.frame.size.height;
    
    [self setRelatedCardsHeights:relatedCards language:language];
    
    heightOfSubviews = [backScrollView heightOfSubviewsExcept:@[backCardImageBottom]];
    if ([language usesLatex]) {
        if (heightOfSubviews < maxSize) {
            [self setBackViewPositionHeight:maxContentSize];
        } else {
            [self setBackViewPositionHeight:heightOfSubviews];
        }
        CGRect frame = backWebview.frame;
        frame.size.height = [self.view webviewContentHeight:backWebview];
        backWebview.frame = frame;       // Set the scrollView contentHeight back to the frame itself.
        backLabel.hidden = YES;
    } else {
        // need to keep the front label to the proper size, otherwise the code to center the text will not work.
        [self setupLabel:backLabel withString:attributedString];
        
        // if the text is smaller than size of the screen, center it or so, to make it look good:
        heightOfSubviews = [backScrollView heightOfSubviews];
        if (heightOfSubviews < maxSize) {
            [self setBackViewPositionHeight:maxContentSize];
            
            // need to keep the backLabel to the proper size, otherwise the code to center the text will not work.
            [self setupLabel:backLabel withString:attributedString];
        } else {
            [self setBackViewPositionHeight:heightOfSubviews];
        }
    }
    
    // code to center the backLabel:
    heightOfSubviews = [backScrollView heightOfSubviewsExcept:@[backCardImageBottom, backCardImageTop]];
    if (heightOfSubviews < maxSize) {
        [self setBackViewPositionHeight:maxContentSize];
        
        if (![language usesLatex]) {
            // need to keep the front label to the proper size, otherwise the code to center the text will not work.
            [self setupLabel:backLabel withString:attributedString];
        }

        // need to keep the front label to the proper size, otherwise the code to center the text will not work.
        [self setRelatedCardsHeights:relatedCards language:language];
        
        prevViewInside = nil;
        heightOfSubviews = [backScrollView heightOfSubviewsExcept:@[backCardImageBottom, backCardImageTop]];
        // determine the height of where the items should start:
        float y = ((maxContentSize - heightOfSubviews) / 2);
        
        if ([language usesLatex]) {
            [backWebview setPositionBehind:prevViewInside orSetY:y];
            prevViewInside = backWebview;
        } else if (backLabel.attributedText.length > 0) {
            [backLabel setPositionBehind:prevViewInside orSetY:y];
            prevViewInside = backLabel;
        } else {
            [backLabel setPositionHidden];
        }

        if (!backImage.hidden) {
            [backImage setPositionBehind:prevViewInside orSetY:y];
            prevViewInside = backImage;
        } else {
            [backImage setPositionHidden];
        }
        
        if ([relatedCards count] > 0) {
            [relatedCardsTableView setPositionBehind:prevViewInside orSetY:y];
            prevViewInside = relatedCardsTableView;
            relatedCardsTableView.hidden = NO;
        } else {
            [relatedCardsTableView setPositionHidden];
            relatedCardsTableView.hidden = YES;
        }
    }
    // NSLog(@"Back height: %f", [backScrollView heightOfSubviews]);
    
    if (displayAsCard) {
        [backCardImageBottom setPositionBehind:backView distance:0];
        [backDropshadowImage setPositionY:backCardImageTop.frame.size.height];
        [backDropshadowImage setPositionHeight:backView.frame.size.height];
    } else {
        [backCardImageBottom setPositionHidden];
        [backDropshadowImage setHidden:YES];
    }
    
    heightOfSubviews = [backScrollView heightOfSubviews];
    if (backScrollView.frame.size.height >= heightOfSubviews) {
        backScrollView.userInteractionEnabled = NO;
    } else {
        backScrollView.userInteractionEnabled = YES;
    }
    
    [backScrollView setContentSize:CGSizeMake(backScrollView.frame.size.width,  heightOfSubviews ) ];
    [backScrollView setClipsToBounds:YES];

}

-(void)setRelatedCardsHeights:(NSSet*)relatedCards language:(NSString*)language {
    // need to keep the front label to the proper size, otherwise the code to center the text will not work.
    if (![language usesLatex]) {
        [self setupLabel:backLabel withString:nil];
    }
    
    if ([relatedCards count] > 0) {
        [relatedCardsTableView reloadData];
        relatedCardsTableView.hidden = NO;
        float relatedCardsTableViewHeight = (44 * [relatedCards count]) + 20;
        if ([FlashCardsAppDelegate isIpad]) {
            // TODO: Fix this hack!
            // as per http://stackoverflow.com/questions/2688007/uitableview-backgroundcolor-always-gray-on-ipad
            [relatedCardsTableView setBackgroundView:nil];
            relatedCardsTableViewHeight += 44;
        } else {
            // Another hack... As per issue 3422, last related card item's back side doesn't show
            // NB: This is also the source of the back side problem where the bottom fo the card doesn't align properly [eg: Bedrohung]
            relatedCardsTableViewHeight += 44;
        }
        [relatedCardsTableView setPositionHeight:relatedCardsTableViewHeight];
    } else {
        [relatedCardsTableView setPositionHidden];
    }
}

-(void)configureBackHeightsLabel:(NSMutableAttributedString *)attributedString
                    relatedCards:(NSSet *)relatedCards
                        language:(NSString*)language {
    UIView *prevViewInside = nil;
    
    [self setupLabel:backLabel withString:attributedString];

    [self setRelatedCardsHeights:relatedCards language:language];

    if (attributedString.length > 0) {
        [self setupLabel:backLabel withString:attributedString];
        [backLabel setPositionBehind:prevViewInside distance:0];
        prevViewInside = backLabel;
    } else {
        [backLabel setPositionHidden];
    }
    
    [self configureBackHeightsAfterLabel:prevViewInside relatedCards:relatedCards];
}

- (void)configureBackHeightsAfterLabel:(UIView*)prevViewInside
                          relatedCards:(NSSet*)relatedCards {
    if (!backImage.hidden) {
        [backImage setPositionBehind:prevViewInside];
        prevViewInside = backImage;
    } else {
        [backImage setPositionHidden];
    }
    
    if ([relatedCards count] > 0) {
        [relatedCardsTableView setAutoresizesSubviews:YES];
        [relatedCardsTableView setPositionBehind:prevViewInside];
        prevViewInside = relatedCardsTableView;
        relatedCardsTableView.hidden = NO;
    } else {
        [relatedCardsTableView setPositionHidden];
        relatedCardsTableView.hidden = YES;
    }
}

# pragma mark -
# pragma mark User Actions

- (void)turnOnFullScreenStudy {
    bottomToolbarStudy.hidden = YES;
    self.navigationController.navigationBarHidden = YES;
    UIImage *newImage = [UIImage imageNamed:@"fullscreen-close.png"];
    [fullScreenButton setImage:newImage forState:UIControlStateNormal];
    [fullScreenButton setAccessibilityLabel:NSLocalizedStringFromTable(@"Turn Off Full Screen", @"Study", @"")];
    [fullScreenButton setAccessibilityHint:NSLocalizedStringFromTable(@"Turn Off Full Screen", @"Study", @"")];
}
- (void)turnOffFullScreenStudy {
    bottomToolbarStudy.hidden = NO;
    self.navigationController.navigationBarHidden = NO;
    UIImage *newImage = [UIImage imageNamed:@"fullscreen-open.png"];
    [fullScreenButton setImage:newImage forState:UIControlStateNormal];
    [fullScreenButton setAccessibilityLabel:NSLocalizedStringFromTable(@"Turn On Full Screen", @"Study", @"")];
    [fullScreenButton setAccessibilityHint:NSLocalizedStringFromTable(@"Turn On Full Screen", @"Study", @"")];
}

-(IBAction)fullScreenButtonTapped:(id)sender {
    if (isFullScreen) {
        isFullScreen = NO;
        [self turnOffFullScreenStudy];
    } else {
        if (![FlashCardsCore hasFeature:@"FullscreenStudy"]) {
            [FlashCardsCore showPurchasePopup:@"FullscreenStudy"];
            return;
        }
        // changing TO YES full screen
        isFullScreen = YES;
        [self turnOnFullScreenStudy];
    }
    [self configureCard];
}

-(IBAction)relatedCardsAction:(id)sender {
    
    appLockedTimerBegin = [NSDate date];
    
    RelatedCardsViewController *vc = [[RelatedCardsViewController alloc] initWithNibName:@"RelatedCardsViewController" bundle:nil];
    vc.card = ((CardTest*)[studyController currentCard]).card;
    vc.relatedCardsTempStore = [NSMutableSet setWithSet:vc.card.relatedCards];
    vc.editInPlace = YES;
    
    [self turnOffFullScreenStudy];
    [self.navigationController pushViewController:vc animated:YES];
    
}

-(IBAction)editCardAction:(id)sender {
    
    if (previewMode) {
        [self turnOffFullScreenStudy];
        [self.navigationController popViewControllerAnimated:YES];
        return;
    }
    
    if ([self resultsDisplayed]) {
        return;
    }
    
    appLockedTimerBegin = [NSDate date];
    
    CardEditViewController *cardEditVC = [[CardEditViewController alloc] initWithNibName:@"CardEditViewController" bundle:nil];
    CardTest *testCard = [studyController currentCard];
    cardEditVC.card = testCard.card;
    cardEditVC.collection = self.collection;
    cardEditVC.editInPlace = YES;
    cardEditVC.editMode = modeEdit;
    cardEditVC.popToViewControllerIndex = [[self.navigationController viewControllers] count]-1;
    [self turnOffFullScreenStudy];
    [self.navigationController pushViewController:cardEditVC animated:YES];
    
    
}

-(IBAction)cardInfo:(id)sender {

    appLockedTimerBegin = [NSDate date];

    if ([FlashCardsCore hasFeature:@"HideAds"]) {
        // the button says "card statistics"
        CardStatisticsViewController *statsVC = [[CardStatisticsViewController alloc] initWithNibName:@"CardStatisticsViewController" bundle:nil];
        statsVC.card = ((CardTest*)[studyController currentCard]).card;

        [self turnOffFullScreenStudy];
        [self.navigationController pushViewController:statsVC animated:YES];
    
    } else {

        // the button says "Hide Ads"
        [Flurry logEvent:@"HideAds"];
        SubscriptionViewController *vc = [[SubscriptionViewController alloc] initWithNibName:@"SubscriptionViewController" bundle:nil];
        vc.showTrialEndedPopup = NO;
        vc.giveTrialOption = NO;
        vc.explainSync = NO;
        
        [self turnOffFullScreenStudy];
        [self.navigationController pushViewController:vc animated:YES];

    }
    
}

- (bool)isLandscape {
    bool retVal = NO;
    if ([FlashCardsAppDelegate isIpad]) {
        if (backLabel.frame.size.width > 748) {
            retVal = YES;
        }
    } else {
        if (backLabel.frame.size.width > 300) {
            retVal = YES;
        }
    }
    return retVal;
}

# pragma mark -
# pragma mark TTS Functions

- (int)currentSideShown {
    int _currentSideShown;
    if ([self cardFrontIsShown]) {
        if (studyController.showFirstSide == showFirstSideFront) {
            _currentSideShown = showFirstSideFront;
        } else if (studyController.showFirstSide == showFirstSideBack) {
            _currentSideShown = showFirstSideBack;
        } else {
            // we are looking at a random card. compare the text to the
            // card which is being studied:
            CardTest *testCard = [studyController currentCard];
            if ([frontLabelText isEqual:testCard.card.frontValue]) {
                _currentSideShown = showFirstSideFront;
            } else {
                _currentSideShown = showFirstSideBack;
            }
        }
    } else {
        if (studyController.showFirstSide == showFirstSideFront) {
            _currentSideShown = showFirstSideBack;
        } else if (studyController.showFirstSide == showFirstSideBack) {
            _currentSideShown = showFirstSideFront;
        } else {
            // we are looking at a random card. compare the text to the
            // card which is being studied:
            CardTest *testCard = [studyController currentCard];
            if ([frontLabelText isEqual:testCard.card.frontValue]) {
                _currentSideShown = showFirstSideBack;
            } else {
                _currentSideShown = showFirstSideFront;
            }
        }
    }
    return _currentSideShown;
}

- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer
 didFinishSpeechUtterance:(AVSpeechUtterance *)utterance {
    UIColor *backgroundTextColor = [UIColor colorWithString:(NSString *)[FlashCardsCore getSetting:@"studySettingsBackgroundTextColor"]];
    
    synthesizer = nil;

    // if something strange happens to the colors, set them to be black & white:
    if (!backgroundTextColor) {
        backgroundTextColor = [UIColor whiteColor];
    }
    UIColor *cardBackgroundTextColor;
    if ([FlashCardsCore getSettingBool:@"studyDisplayLikeIndexCard"]) {
        cardBackgroundTextColor = [UIColor blackColor];
    } else {
        cardBackgroundTextColor = backgroundTextColor;
    }
    
    NSMutableAttributedString *aString;
    if ([self cardFrontIsShown]) {
        aString = [NSMutableAttributedString attributedStringWithAttributedString:self.frontLabel.attributedText];
    } else {
        aString = [NSMutableAttributedString attributedStringWithAttributedString:self.backLabel.attributedText];
    }
    
    [aString addAttribute:NSForegroundColorAttributeName value:cardBackgroundTextColor range:NSMakeRange(0, [aString length])];
    
    if ([self cardFrontIsShown]) {
        [self.frontLabel setAttributedText:aString];
    } else {
        [self.backLabel setAttributedText:aString];
    }
    
    // if we are auto-browsing, and it is currently paused, AND the pausing was caused by the play button, then re-start auto-browse:
    if ((studyBrowseMode == studyBrowseModeAutoBrowse || studyBrowseMode == studyBrowseModeAutoAudio)) {
        self.studyBrowseModePaused = YES;
        self.studyBrowseModePausedForSpeakText = YES;
        
        self.studyBrowseModeFunctionRunning = NO;
        double delay = 0.5;
        [self performSelector:@selector(pausePlayAutoBrowse:) withObject:nil afterDelay:delay]; // restart auto-browse after 0.5 seconds
    }

}

- (void)        speechSynthesizer:(AVSpeechSynthesizer *)synthesizer
     willSpeakRangeOfSpeechString:(NSRange)characterRange
                        utterance:(AVSpeechUtterance *)utterance
{
    
    BOOL isOnFront = ([self currentSideShown] == showFirstSideFront);
    if (self.ttsStudySideIsFrontOfCard != isOnFront) {
        return;
    }

    UIColor *backgroundTextColor = [UIColor colorWithString:(NSString *)[FlashCardsCore getSetting:@"studySettingsBackgroundTextColor"]];
    
    // if something strange happens to the colors, set them to be black & white:
    if (!backgroundTextColor) {
        backgroundTextColor = [UIColor whiteColor];
    }
    UIColor *cardBackgroundTextColor;
    if ([FlashCardsCore getSettingBool:@"studyDisplayLikeIndexCard"]) {
        cardBackgroundTextColor = [UIColor blackColor];
    } else {
        cardBackgroundTextColor = backgroundTextColor;
    }

    NSMutableAttributedString *aString;
    if ([self cardFrontIsShown]) {
        aString = [NSMutableAttributedString attributedStringWithAttributedString:self.frontLabel.attributedText];
    } else {
        aString = [NSMutableAttributedString attributedStringWithAttributedString:self.backLabel.attributedText];
    }
    
    [aString addAttribute:NSForegroundColorAttributeName value:cardBackgroundTextColor range:NSMakeRange(0, self.ttsStringStartLocation + characterRange.location)];
    if ([aString length] > self.ttsStringStartLocation + characterRange.location && [aString length] > self.ttsStringStartLocation + characterRange.location + characterRange.length) {
        [aString addAttribute:NSForegroundColorAttributeName value:[UIColor redColor] range:NSMakeRange(self.ttsStringStartLocation + characterRange.location, characterRange.length)];
    }

    if ([self cardFrontIsShown]) {
        [self.frontLabel setAttributedText:aString];
    } else {
        [self.backLabel setAttributedText:aString];
    }
    
}


- (IBAction)speakText:(id)sender {
    if ([self resultsDisplayed]) {
        return;
    }

    [self speakText:sender withPattern:nil];
}

- (void)speakText:(id)sender withPattern:(NSString*)pattern {
    // determine which side of the card we're looking at:
    
    BOOL hasAudio = NO;
    NSData *audioData;
    CardTest *testCard = [studyController currentCard];
    if ([self currentSideShown] == showFirstSideFront) {
        if (previewMode) {
            NSData *audioDataTest = (NSData*)[previewCard objectForKey:@"frontAudioData"];
            if ([audioDataTest length] > 0) {
                hasAudio = YES;
                audioData = audioDataTest;
            }
        } else if ([testCard.card.frontAudioData length] > 0) {
            hasAudio = YES;
            audioData = testCard.card.frontAudioData;
        }
    } else if ([self currentSideShown] == showFirstSideBack) {
        if (previewMode) {
            NSData *audioDataTest = (NSData*)[previewCard objectForKey:@"backAudioData"];
            if ([audioDataTest length] > 0) {
                hasAudio = YES;
                audioData = audioDataTest;
            }
        } else if ([testCard.card.backAudioData length] > 0) {
            hasAudio = YES;
            audioData = testCard.card.backAudioData;
        }
    }
    if (hasAudio) {
        [Flurry logEvent:@"User-Recorded-Audio"
          withParameters:@{
         @"userDidTap"      : [NSNumber numberWithBool:(sender != nil)],
         @"hasSubscription" : [NSNumber numberWithBool:[FlashCardsCore hasSubscription]]
         }];
        if ([FlashCardsCore hasSubscription]) {
            [TTSButton setHidden:YES];
            [TTSActivityIndicator setHidden:NO];
            [TTSActivityIndicator startAnimating];
            
            double delay = 0.5;
            
            if (audioPlayer.playing) {
                [audioPlayer stop];
            }
            
            // as per: http://stackoverflow.com/a/12868879/353137
            [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
            [[AVAudioSession sharedInstance] setActive:YES error:nil];
            
            audioPlayer = [[AVAudioPlayer alloc] initWithData:audioData error:nil];
            audioPlayer.volume = 0.4f;
            [audioPlayer prepareToPlay];
            [audioPlayer setNumberOfLoops:0];
            delay += (double)audioPlayer.duration;
            [audioPlayer play];
            
            [TTSButton setHidden:NO];
            [TTSActivityIndicator setHidden:YES];
            [TTSActivityIndicator stopAnimating];
            
            // if we are auto-browsing, and it is currently paused, AND the pausing was caused by the play button, then re-start auto-browse:
            if ((studyBrowseMode == studyBrowseModeAutoBrowse || studyBrowseMode == studyBrowseModeAutoAudio)) {
                self.studyBrowseModeFunctionRunning = NO;
                [self performSelector:@selector(autoBrowse:) withObject:pattern afterDelay:delay]; // restart auto-browse after 0.5 seconds
            }
            self.studyBrowseModePausedForSpeakText = NO; // reset the value of studyBrowseModePausedForSpeakText, ALWAYS
            
            return;
        } else {
            if ([FlashCardsCore hasGrandfatherClause]) {
                SubscriptionViewController *vc = [[SubscriptionViewController alloc] initWithNibName:@"SubscriptionViewController" bundle:nil];
                vc.giveTrialOption = NO;
                vc.showTrialEndedPopup = NO;
                vc.explainSync = NO;
                [self.navigationController pushViewController:vc animated:YES];
            } else {
                [FlashCardsCore showPurchasePopup:@"Audio"];
            }
            return;
        }
    }
    
    // get the card's language & text for TTS depending on which side we're looking at:
    NSString *text;
    NSString *language;
    FCCard *card = [[studyController currentCard] card];
    if ([self currentSideShown] == showFirstSideFront) {
        language = collection.frontValueLanguage;
        if (previewMode) {
            text = [previewCard valueForKey:@"frontValue"];
        } else {
            text = [card frontValueTTS];
        }
    } else {
        language = collection.backValueLanguage;
        if (previewMode) {
            text = [previewCard valueForKey:@"backValue"];
        } else {
            text = [card backValueTTS];
        }
    }
    
    if ([language usesLatex]) {
        FCDisplayBasicErrorMessage(@"", NSLocalizedStringFromTable(@"Text-to-speech is not available for math or chemistry cards. However, you can record your own audio.", @"Study", @""));
        return;
    }
    
    if (!language || [language length] == 0) {
        [TTSActivityIndicator stopAnimating];
        [TTSActivityIndicator setHidden:YES];
        [TTSButton setHidden:NO];
        

        NSMutableArray *googleLanguages = [FlashCardsCore loadGoogleLanguageFromManagedObjectContext:[FlashCardsCore mainMOC]];
        NSMutableArray *languages = [NSMutableArray arrayWithCapacity:0];
        for (NSDictionary *language in googleLanguages) {
            [languages addObject:[language valueForKey:@"languageName"]];
        }
        ActionStringCancelBlock cancel = ^(ActionSheetStringPicker *picker) {
            NSLog(@"Block Picker Canceled");
        };
        ActionStringDoneBlock done = ^(ActionSheetStringPicker *picker, NSInteger selectedIndex, id selectedValue) {
            NSDictionary *language = [googleLanguages objectAtIndex:selectedIndex];
            if ([[language valueForKey:@"languageName"] isEqualToString:@"-----"]) {
                selectedIndex = 0;
                language = [googleLanguages objectAtIndex:selectedIndex];
            }
            if ([self currentSideShown] == showFirstSideFront) {
                self.collection.frontValueLanguage = [language valueForKey:@"googleAcronym"];
            } else {
                self.collection.backValueLanguage  = [language valueForKey:@"googleAcronym"];
            }
            [FlashCardsCore saveMainMOC:NO];
            [self speakText:nil];
        };
        // front side: show the picker
        NSString *title;
        if ([self currentSideShown] == showFirstSideFront) {
            title = NSLocalizedStringFromTable(@"Front Language", @"CardManagement", @"UILabel");
        } else {
            title = NSLocalizedStringFromTable(@"Back Language", @"CardManagement", @"UILabel");
        }
        [ActionSheetStringPicker showPickerWithTitle:title
                                                rows:languages
                                    initialSelection:0
                                           doneBlock:done
                                         cancelBlock:cancel
                                              origin:TTSButton];
        isUsingTTS = NO;
        return;
    }
    
    NSString *languageKey = [FlashCardsCore getLanguageAcronymFor:language fromKey:@"googleAcronym" toKey:@"appleTtsAcronym"];
    if ([languageKey length] > 0) {

        self.ttsStringStartLocation = 0;
        self.ttsStudySideIsFrontOfCard = ([self currentSideShown] == showFirstSideFront);
        [self speakText:text withLanguage:languageKey];
 
        return;
    }

    
    if (![FlashCardsCore hasFeature:@"TTS"]) {
        [FlashCardsCore showPurchasePopup:@"TTS"];
        return;
    }
    
    if ([text length] == 0) {
        isUsingTTS = NO;
        return;
    }
    
    [Flurry logEvent:@"Text-To-Speech"
      withParameters:@{
     @"language"        : language,
     @"userDidTap"      : [NSNumber numberWithBool:(sender != nil)],
     @"hasSubscription" : [NSNumber numberWithBool:[FlashCardsCore hasSubscription]],
     @"oneTimeTrial"    : [NSNumber numberWithBool:[FlashCardsCore currentlyUsingOneTimeOfflineTTSTrial]]
     }];
    
    // if we are in auto-browse mode and it's playing, pause the auto-browse while loading up the text
    if ((studyBrowseMode == studyBrowseModeAutoBrowse || studyBrowseMode == studyBrowseModeAutoAudio) && !self.studyBrowseModePaused) {
        [self pausePlayAutoBrowse:nil];
        // tells the app that we specifically paused the auto-browse to download the text.
        self.studyBrowseModePausedForSpeakText = YES;
    } else {
        self.studyBrowseModePausedForSpeakText = NO;
    }

    isUsingTTS = NO;
}

- (void)speakText:(NSString*)text withLanguage:(NSString*)languageKey {
    
    if (speechSynthesizer) {
        speechSynthesizer = nil;
    }
    // as per: http://stackoverflow.com/a/12868879/353137
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
    speechSynthesizer = [[AVSpeechSynthesizer alloc] init];
    if (speechSynthesizer.paused) {
        NSLog(@"PAUSED");
    }
    // [speechSynthesizer continueSpeaking];
    //create an utterance
    
    AVSpeechUtterance* utterance = [AVSpeechUtterance speechUtteranceWithString:text];
    //Speak!
    [speechSynthesizer stopSpeakingAtBoundary:AVSpeechBoundaryWord];
    if ([DTVersion osVersionIsLessThen:@"9.0"]) {
        [utterance setRate:0.15f];
    } else {
        [utterance setRate:0.5f];
    }
    [utterance setVolume:0.9f];
    [utterance setVoice:[AVSpeechSynthesisVoice voiceWithLanguage:languageKey]];
    [speechSynthesizer setDelegate:self];
    [speechSynthesizer speakUtterance:utterance];
    
    isUsingTTS = NO;

}

# pragma mark - Scoring functions

-(IBAction)passFailSelectedIndexChanged:(id)sender {
    cardTestIsChanged = YES;
    bool proceedToNextCardOnScore = [(NSNumber*)[FlashCardsCore getSetting:@"proceedToNextCardOnScore"] boolValue];
    if (proceedToNextCardOnScore) {
        [studyController nextCard];
    }
}

-(void)setScore:(int)score {
    if (passFailSegmentedControl.rowCount == 1) {
        [passFailSegmentedControl setSelectedIndex:score];
    } else {
        int finalScore = score;
        if (finalScore < 3) {
            finalScore += 3;
        } else {
            finalScore -= 3;
        }
        [passFailSegmentedControl setSelectedIndex:finalScore];
    }
}

-(int)getScore {
    int index = passFailSegmentedControl.selectedIndex;
    if (passFailSegmentedControl.rowCount == 1) {
        return index;
    } else {
        int finalScore = index;
        if (finalScore < 3) {
            finalScore += 3;
        } else {
            finalScore -= 3;
        }
        return finalScore;
    }
}

# pragma mark - Timing functions

-(void)applicationWillResign {
    appLockedTimerBegin = [NSDate date];
}

-(void)applicationDidActivate {
    if ([studyController.cardList count] > 0 && studyController.currentCardIndex < [studyController.cardList count]) {
        CardTest *testCard = [studyController currentCard];
        [testCard markStudyPause:appLockedTimerBegin];
        appLockedTimerBegin = nil;
    }
    if (studyBrowseMode != studyBrowseModeManual && self.studyBrowseModePaused) {
        [self pausePlayAutoBrowse:nil];
    }
}

# pragma mark - Test results functions

-(void)displayResults:(id)nilValue animated:(BOOL)animated {

    if (![FlashCardsCore hasFeature:@"HideAds"] && [FlashCardsCore canShowInterstitialAds]) {
        // display an ad:
        FCLog(@"requesting interstitial ads");
        ADInterstitialAd *interstitial = [[FlashCardsCore appDelegate] interstitialAd];
        if (interstitial.loaded) {
            [interstitial presentFromViewController:self];
        }
    }
    
    if (animated) {
        ADBannerView *backBanner = [[FlashCardsCore appDelegate] bannerAd];
        if (backBanner && backBanner.bannerLoaded) {
            [backBanner hide];
        }
        [UIView
         transitionWithView:self.view
         duration:0.60
         options:UIViewAnimationOptionTransitionCurlUp
         animations:^{
             if (![self cardFrontIsShown]) {
                 [self showBackView:NO];
             }
         }
         completion:^(BOOL finished) {
             BOOL isBackShown = ![self cardFrontIsShown];
             [self positionBannerAd:isBackShown];
         }];
    }
    
    cardNumberLabel.hidden = YES;
    [cardNumberLabel setIsAccessibilityElement:!cardNumberLabel.hidden];
    
    BOOL isTest = [studyController studyAlgorithmIsTest];
    bottomToolbarStudy.hidden = YES;
    bottomToolbarTestResults.hidden = !isTest;
    bottomToolbarResults.hidden = isTest;
    if (!bottomToolbarTestResults.hidden) {
        studyCardsWithScoresLessThan4Button.enabled = ([studyController numCardsWithScoresLessThan4] > 0);
    }

    NSMutableString *resultsString = [[NSMutableString alloc] initWithCapacity:0];
    
    // as per: http://www.iphonesdkarticles.com/2008/11/localizing-iphone-apps-part-1.html
    NSNumberFormatter *percentStyle = [[NSNumberFormatter alloc] init];
    [percentStyle setFormatterBehavior:NSNumberFormatterBehavior10_4];
    [percentStyle setLocale:[NSLocale currentLocale]];
    [percentStyle setNumberStyle:NSNumberFormatterPercentStyle];
    [percentStyle setMinimumFractionDigits:2];
    [percentStyle setMaximumFractionDigits:2];

    NSNumberFormatter *decimalStyle = [[NSNumberFormatter alloc] init];
    [decimalStyle setFormatterBehavior:NSNumberFormatterBehavior10_4];
    [decimalStyle setNumberStyle:NSNumberFormatterDecimalStyle];
    [decimalStyle setMinimumFractionDigits:2];
    [decimalStyle setMaximumFractionDigits:2];
    
    double avgScore = [studyController averageScore];
    if (avgScore < 0) {
        [resultsString appendFormat:NSLocalizedStringFromTable(@"Round %d\n", @"Study", @"results"), (studyController.currentRound+1)];
        [resultsString appendString:NSLocalizedStringFromTable(@"\nNo scores recorded", @"Study", @"results")];
    } else if ([studyController studyAlgorithmIsTest]) {
        [resultsString appendString:NSLocalizedStringFromTable(@"Test Results\n", @"Study", @"results")];
        double passed = [studyController percentPassed];
        if (passed > -1) {
            [resultsString appendFormat:NSLocalizedStringFromTable(@"\nPercent Passed: %@", @"Study", @"results"), [percentStyle stringFromNumber:[NSNumber numberWithDouble:passed]]];
        }
        double skipped = [studyController percentSkipped];
        if (skipped > -1) {
            [resultsString appendFormat:NSLocalizedStringFromTable(@"\nPercent Skipped: %@", @"Study", @"results"), [percentStyle stringFromNumber:[NSNumber numberWithDouble:skipped]]];
        }
        [resultsString appendFormat:NSLocalizedStringFromTable(@"\nAverage Score: %@", @"Study", @"results"), [decimalStyle stringFromNumber:[NSNumber numberWithDouble:avgScore]]];
        double avgNextInterval = [studyController averageNextInterval];
        if (avgNextInterval > -1) {
            [resultsString appendFormat:NSLocalizedStringFromTable(@"\nAverage Interval: %@", @"Study", @"results"), [studyController formatInterval:avgNextInterval]];
        }
    } else {
        [resultsString appendFormat:NSLocalizedStringFromTable(@"Round %d\n", @"Study", @"results"), (studyController.currentRound+1)];
        [resultsString appendFormat:NSLocalizedStringFromTable(@"\nAverage Score: %@", @"Study", @"results"), [decimalStyle stringFromNumber:[NSNumber numberWithDouble:avgScore]]];
        if (studyController.studyOrder == studyOrderSmart) {
            double studyScore = ((double)[studyController.studyList count] / (double)[studyController.cardList count]);
            [resultsString appendFormat:NSLocalizedStringFromTable(@"\nSmart Study Ratio: %@", @"Study", @"results"),  [decimalStyle stringFromNumber:[NSNumber numberWithDouble:studyScore]]];
        }
    }
    
    
    if ([studyController studyAlgorithmIsTest] && studyController.studyAlgorithm != studyAlgorithmRepetition && studyController.studyAlgorithm != studyAlgorithmLapsed) {
        [studyController saveCardListDoneToCollection];
    }
    self.title = NSLocalizedStringFromTable(@"Results", @"Study", @"");
    [self configureFrontSide:[NSDictionary dictionaryWithObjectsAndKeys:resultsString, @"frontValue", nil]
                    showSide:showFirstSideFront
                    language:@"en"];
    [self.frontWebview setHidden:YES];
    [self.frontImage setHidden:YES];
    [self.backImage setHidden:YES];
    [self.editButton setHidden:YES];
    [self.TTSButton setHidden:YES];
    [self.fullScreenButton setHidden:YES];
    [self.TTSActivityIndicator setHidden:YES];
    
    studyController.currentCardIndex = [studyController numCards];
}

# pragma mark - Card switching functions

-(void)animateCard:(UIViewAnimationOptions)options {
    double animationDuration = 0.60; // this is how long the animations will take place.

    ADBannerView *backBanner = [[FlashCardsCore appDelegate] bannerAd];
    if (backBanner && backBanner.bannerLoaded) {
        [backBanner hide];
    }
    [UIView
     transitionWithView:self.view
     duration:animationDuration
     options:options
     animations:^{
         // we need to increment the study pause time by the time that the animation took place:
         CardTest *testCard = [studyController currentCard];
         [testCard incrementStudyPause:animationDuration];
         
         
         if (![self cardFrontIsShown] || [self resultsDisplayed]) {
             self.title = (studyController.showFirstSide == showFirstSideBack) ? NSLocalizedStringFromTable(@"Back", @"Study", @"back of card") : NSLocalizedStringFromTable(@"Front", @"Study", @"front of card");
             [self showBackView:NO];
         }
         if (![self resultsDisplayed]) {
             [TTSButton setHidden:NO];
             [editButton setHidden:NO];
             [fullScreenButton setHidden:NO];
             [TTSActivityIndicator setHidden:YES];
         }
     }
     completion:^(BOOL finished) {
         BOOL isBackShown = ![self cardFrontIsShown];
         [self positionBannerAd:isBackShown];
     }];
}

-(void)prevCardAction {
    // don't do anything if we are in preview mode
    if (previewMode) {
        return;
    }
    
    [studyController prevCard];

    [self checkSyncing];
}
-(void)nextCardAction {
    // don't do anything if we are in preview mode
    if (previewMode) {
        return;
    }
    
    if (speechSynthesizer && speechSynthesizer.speaking) {
    //    [speechSynthesizer pauseSpeakingAtBoundary:AVSpeechBoundaryImmediate];
    }
    
    // index 1 = "Next >"
    if ([self resultsDisplayed]) {
        [studyController nextRound];
    } else {
        [studyController nextCard];
    }

    [self checkSyncing];
}
-(void)checkSyncing {
    if ([FlashCardsCore appIsSyncing]) {
        UIViewController *parentVC  = [FlashCardsCore parentViewController];
        if ([parentVC respondsToSelector:@selector(setShouldSyncN:)]) {
            [parentVC performSelector:@selector(setShouldSyncN:) withObject:@YES];
        }
    }
}

-(IBAction)randomizeCardsAction:(id)sender {
    [studyController randomizeStudyList];
    [studyController nextRound];
}

# pragma mark - Card flip functions

-(BOOL)cardFrontIsShown {
    // previously it would just check if backLabel is hidden.
    // however, this doesn't work if the user has math set up - because that hides the backLabel.
    // Instead we now check if backScrollView (which contains the entire back card)
    BOOL backViewIsHidden = backScrollView.hidden;
    return backViewIsHidden;
}

-(void)positionBannerAd:(BOOL)isBackSide {
    ADBannerView *backBanner = [[FlashCardsCore appDelegate] bannerAd];
    if (![FlashCardsCore hasFeature:@"HideAds"] && backBanner && backBanner.bannerLoaded) {
        [backBanner show];
        // and then place it in the proper location:
        int height = backBanner.frame.size.height;
        if (isBackSide) {
            int passFailSegmentedControlY = passFailSegmentedControl.frame.origin.y;
            [backBanner setPositionY:(passFailSegmentedControlY - height - 3)];
        } else {
            int bottomToolbarStudyY = bottomToolbarStudy.frame.origin.y;
            if (isFullScreen) {
                bottomToolbarStudyY = self.view.frame.size.height;
            }
            if (UIInterfaceOrientationIsLandscape([self interfaceOrientation]) &&
                ![FlashCardsAppDelegate isIpad] &&
                !isFullScreen &&
                ![self resultsDisplayed]) {
                bottomToolbarStudyY += bottomToolbarStudy.frame.size.height;
            }
            [backBanner setPositionY:(bottomToolbarStudyY - height)];
        }
    }
    if (backBanner && !backBanner.bannerLoaded) {
        [backBanner hide];
    }

}

-(void)showBackView:(BOOL)isBackSide {
    [self showBackView:isBackSide positionBannerAd:YES];
}

-(void)showBackView:(BOOL)isBackSide positionBannerAd:(BOOL)shouldPositionBannerAd {
    if (isBackSide) {
        // showing the back side:
        
        cardNumberLabel.hidden = YES;
        
        backLabel.hidden = NO;
        backScrollView.hidden = NO;
        backHelpButton.hidden = NO;
        passFailSegmentedControl.hidden = NO;

        if (shouldPositionBannerAd) {
            [self positionBannerAd:isBackSide];
        }
        
        if (!previewMode) {
            passFailSegmentedControl.userInteractionEnabled = YES;
        }
        frontScrollView.hidden = YES;
        frontLabel.hidden = YES;
        if ([FlashCardsAppDelegate isIpad]) {
            [bottomFrontFlipButton setTitle:NSLocalizedStringFromTable(@"    Flip to Front    ", @"Study", @"UIBarButtonItem")];
        } else {
            [bottomFrontFlipButton setAccessibilityLabel:NSLocalizedStringFromTable(@"    Flip to Front    ", @"Study", @"UIBarButtonItem")];
        }
    } else {
        // showing the front side:
        
        backLabel.hidden = YES;
        backScrollView.hidden = YES;
        backHelpButton.hidden = YES;
        passFailSegmentedControl.hidden = YES;
        passFailSegmentedControl.userInteractionEnabled = NO;
        
        if (shouldPositionBannerAd) {
            [self positionBannerAd:isBackSide];
        }

        frontScrollView.hidden = NO;
        frontLabel.hidden = NO;

        if (previewMode) {
            cardNumberLabel.hidden = NO;
        } else {
            // all of the fancy logic wrt testing if the card front is shown only works after
            // doing all of the work above ^^^
            cardNumberLabel.hidden = ![self shouldShowCardNumberLabel];
            if (![self resultsDisplayed] && [studyController numCards] > 0 && studyController.cardListIsTranslated) {
                CardTest *testCard = [studyController currentCard];
                if (testCard != nil) {
                    // always show the card # label if we are testing:
                    if (testCard.isTest && [self cardFrontIsShown]) {
                        cardNumberLabel.hidden = NO;
                    }
                }
            }
        }
        [cardNumberLabel setIsAccessibilityElement:!cardNumberLabel.hidden];
        if ([FlashCardsAppDelegate isIpad]) {
            [bottomFrontFlipButton setTitle:NSLocalizedStringFromTable(@"    Flip to Back    ", @"Study", @"UIBarButtonItem")];
        } else {
            [bottomFrontFlipButton setAccessibilityLabel:NSLocalizedStringFromTable(@"    Flip to Back    ", @"Study", @"UIBarButtonItem")];
        }
    }
}

-(IBAction)flipCard:(id)sender {
    allowLeavingWithoutResultsPrompt = NO;
    
    if (speechSynthesizer && speechSynthesizer.speaking) {
    //    [speechSynthesizer pauseSpeakingAtBoundary:AVSpeechBoundaryImmediate];
    }

    ADBannerView *backBanner = [[FlashCardsCore appDelegate] bannerAd];
    if (backBanner && backBanner.bannerLoaded) {
        [backBanner hide];
    }
    UIViewAnimationOptions flipOption = ([self cardFrontIsShown] ? UIViewAnimationOptionTransitionFlipFromRight : UIViewAnimationOptionTransitionFlipFromLeft);
    [UIView
     transitionWithView:self.view
     duration:0.6
     options:flipOption
     animations:^{
         [self showBackView:[self cardFrontIsShown] positionBannerAd:NO];
     }
     completion:^(BOOL finished) {
         if ([self.title isEqual:NSLocalizedStringFromTable(@"Front", @"Study", @"front of card")]) {
             self.title = NSLocalizedStringFromTable(@"Back", @"Study", @"back of card");
         } else {
             self.title = NSLocalizedStringFromTable(@"Front", @"Study", @"front of card");
         }
         BOOL isBackShown = ![self cardFrontIsShown];
         [self positionBannerAd:isBackShown];
     }];
}

# pragma mark - AutoBrowse Functions

-(IBAction)pausePlayAutoBrowse:(id)sender {
    UIViewController *topVC = [FlashCardsCore currentViewController];
    if (![topVC isEqual:self]) {
        return;
    }
    
    self.studyBrowseModePaused = !self.studyBrowseModePaused;
    BOOL displayAsCard = [(NSNumber*)[FlashCardsCore getSetting:@"studyDisplayLikeIndexCard"] boolValue];
    NSString *imageFileName;
    if (self.studyBrowseModePaused) {
        // set to play button:
        imageFileName = (displayAsCard ? @"playButton-black.png" : @"playButton.png");
        [self.pausePlayAutoBrowseButton setImage:[UIImage imageNamed:imageFileName] forState:UIControlStateNormal];
    } else {
        if (!self.studyBrowseModeFunctionRunning) {
            NSString *pattern = [FlashCardsCore randomStringOfLength:11];
            self.autoBrowsePattern = pattern;
            [self autoBrowse:pattern];
        }
        // set to pause image:
        imageFileName = (displayAsCard ? @"pauseButton-black.png" : @"pauseButton.png");
        [self.pausePlayAutoBrowseButton setImage:[UIImage imageNamed:imageFileName] forState:UIControlStateNormal];
    }
}

-(void)autoBrowse:(NSString*)pattern {
    FCLog(@"Autobrowse pattern: %@", pattern);
    if (![pattern isEqualToString:self.autoBrowsePattern]) {
        return;
    }
    
    if (self.studyBrowseModePaused) {
        self.studyBrowseModeFunctionRunning = NO;
        return;
    } else {
        self.studyBrowseModeFunctionRunning = YES;
        float autoBrowseSpeed = [(NSNumber*)[FlashCardsCore getSetting:@"studySettingsAutoBrowseSpeed"] floatValue];
        if (userTouchTimer) {
            if ([[NSDate date] timeIntervalSinceDate:userTouchTimer] < autoBrowseSpeed) {
                userTouchTimer = nil;
                [self performSelector:@selector(autoBrowse:) withObject:pattern afterDelay:autoBrowseSpeed];
                return;
            }
        }
        userTouchTimer = nil;
        if (studyBrowseMode == studyBrowseModeAutoAudio) {
            if (autoAudioShouldPlay && ![self resultsDisplayed]) {
                autoAudioShouldPlay = NO;
                [self speakText:nil withPattern:pattern];
            } else {
                autoAudioShouldPlay = YES;
                if ([self cardFrontIsShown] && ![self resultsDisplayed]) {
                    [self flipCard:nil];
                } else {
                    [studyController nextCard];
                }
                [self performSelector:@selector(autoBrowse:) withObject:pattern afterDelay:autoBrowseSpeed];
            }
        } else {
            if ([self cardFrontIsShown] && ![self resultsDisplayed]) {
                [self flipCard:nil];
            } else {
                [studyController nextCard];
            }
            [self performSelector:@selector(autoBrowse:) withObject:pattern afterDelay:autoBrowseSpeed];
        }
    }
}

#pragma mark -
#pragma mark Touch functions

- (IBAction)handleSwipeUp:(id)sender {
    [self handleSwipeRight:sender];
}

- (IBAction)handleSwipeDown:(id)sender {
    [self handleSwipeLeft:sender];
}

// left to right
- (IBAction)handleSwipeLeft:(id)sender {
    /*
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    CGPoint startPoint = [recognizer locationInView:self.view];
    
    if (![DTVersion osVersionIsLessThen:@"7.0"]) {
        if (startPoint.x / screenRect.size.width < 0.05) {
            [self doneAction:nil];
            return;
        }
    }
    */
    
    if ([self resultsDisplayed]) {
        self.title = (studyController.showFirstSide == showFirstSideBack) ? NSLocalizedStringFromTable(@"Back", @"Study", @"Back of card") : NSLocalizedStringFromTable(@"Front", @"Study", @"");
    }
    
    BOOL studySwipeToProceedCard = [(NSNumber*)[FlashCardsCore getSetting:@"studySwipeToProceedCard"] boolValue];
    // don't go to the previous/next card if we are in preview mode
    if (!previewMode && studySwipeToProceedCard) {
        // it's a left-to-right swipe:
        [studyController prevCard];
    }

    if (studyBrowseMode == studyBrowseModeAutoAudio) {
        self.studyBrowseModeFunctionRunning = NO;
        self.autoAudioShouldPlay = YES;
    }
}

// right to left
- (IBAction)handleSwipeRight:(id)sender {
    if ([self resultsDisplayed] && studyController.studyAlgorithm != studyAlgorithmRepetition) {
        self.title = (studyController.showFirstSide == showFirstSideBack) ? NSLocalizedStringFromTable(@"Back", @"Study", @"Back of card") : NSLocalizedStringFromTable(@"Front", @"Study", @"");
    }

    BOOL studySwipeToProceedCard = [(NSNumber*)[FlashCardsCore getSetting:@"studySwipeToProceedCard"] boolValue];
    // don't go to the previous/next card if we are in preview mode
    if (!previewMode && studySwipeToProceedCard) {
        // it's a right-to-left swipe:
        [studyController nextCard];
    }

    if (studyBrowseMode == studyBrowseModeAutoAudio) {
        self.studyBrowseModeFunctionRunning = NO;
        self.autoAudioShouldPlay = YES;
    }
}

- (IBAction)handleTap:(UITapGestureRecognizer *)recognizer {
    // check if the tap is in the "button zone" (i.e. in the top right where the edit/tts buttons are)
    // If it is in the "button zone" then just ignore this tap - it should actually be going to the buttons.
    // This resolves the problem where people try to tap the edit button but nothing happens!
    // as per: http://stackoverflow.com/a/1465431/353137
    // for landscape mode, as per: http://stackoverflow.com/q/6452716/353137
    CGPoint TTSInWindow = [TTSButton.superview convertPoint:TTSButton.frame.origin toView:[UIApplication sharedApplication].keyWindow.rootViewController.view];
    CGPoint buttonZone = CGPointMake(TTSInWindow.x - 20,
                                     TTSInWindow.y + TTSButton.frame.size.height + 10);
    CGPoint touchInWindow = [recognizer.view.superview convertPoint:[recognizer locationInView:self.view] toView:[UIApplication sharedApplication].keyWindow.rootViewController.view];
    
    // *** I initially tried just using the location of the taps. But if you don't tap directly on the card then the locations
    // *** are screwed up. So, above I get the locations in the whole widow.
    // CGPoint TTSButtonOrigin = TTSButton.frame.origin;
    // CGPoint touchOrigin = [recognizer locationInView:self.view];
    if (touchInWindow.x > buttonZone.x &&
        touchInWindow.y < buttonZone.y) {
        FCLog(@"touch ignored - in button zone");
        
        // calculate the size of the button touch zones, so we can pass the touch to the proper button:
        CGRect TTSFrameInWindow = CGRectMake(TTSInWindow.x,
                                             TTSInWindow.y,
                                             TTSButton.frame.size.width,
                                             TTSButton.frame.size.height);
        CGPoint autoBrowseInWindow;
        CGRect  autoBrowseFrameInWindow;
        if (!pausePlayAutoBrowseButton.hidden) {
            autoBrowseInWindow = [pausePlayAutoBrowseButton.superview convertPoint:pausePlayAutoBrowseButton.frame.origin toView:[UIApplication sharedApplication].keyWindow.rootViewController.view];
            autoBrowseFrameInWindow = CGRectMake(autoBrowseInWindow.x,
                                                 autoBrowseInWindow.y,
                                                 pausePlayAutoBrowseButton.frame.size.width,
                                                 pausePlayAutoBrowseButton.frame.size.height);
        }
        
        CGPoint editInWindow = [editButton.superview convertPoint:editButton.frame.origin toView:[UIApplication sharedApplication].keyWindow.rootViewController.view];
        CGRect editFrameInWindow = CGRectMake(editInWindow.x,
                                              editInWindow.y,
                                              editButton.frame.size.width,
                                              editButton.frame.size.height);
        
        CGPoint fullScreenInWindow = [fullScreenButton.superview convertPoint:fullScreenButton.frame.origin fromView:[UIApplication sharedApplication].keyWindow.rootViewController.view];
        CGRect fullScreenFrameInWindow = CGRectMake(fullScreenInWindow.x,
                                                    fullScreenInWindow.y,
                                                    fullScreenButton.frame.size.width,
                                                    fullScreenButton.frame.size.height);
        
        // depending on which buttons are available, make a list of the buttons and
        // their touch selectors which will be the basis for calculating touch zones
        NSArray *buttons;
        NSArray *images;
        NSArray *selectors;
        if (pausePlayAutoBrowseButton.hidden) {
            images = @[TTSButton, editButton, fullScreenButton];
            buttons = @[[NSValue valueWithCGRect:TTSFrameInWindow], [NSValue valueWithCGRect:editFrameInWindow], [NSValue valueWithCGRect:fullScreenFrameInWindow]];
            selectors = @[[NSValue valueWithPointer:@selector(speakText:)], [NSValue valueWithPointer:@selector(editCardAction:)], [NSValue valueWithPointer:@selector(fullScreenButtonTapped:)]];
        } else {
            images = @[TTSButton, pausePlayAutoBrowseButton, editButton, fullScreenButton];
            buttons = @[[NSValue valueWithCGRect:TTSFrameInWindow], [NSValue valueWithCGRect:autoBrowseFrameInWindow], [NSValue valueWithCGRect:editFrameInWindow], [NSValue valueWithCGRect:fullScreenFrameInWindow]];
            selectors = @[[NSValue valueWithPointer:@selector(speakText:)], [NSValue valueWithPointer:@selector(pausePlayAutoBrowse:)], [NSValue valueWithPointer:@selector(editCardAction:)], [NSValue valueWithPointer:@selector(fullScreenButtonTapped:)]];
        }
        
        // make an array of "button touch zones" which approximates a broader area for
        // the user to touch than just the image.
        NSMutableArray *buttonTouchZones = [NSMutableArray arrayWithCapacity:0];
        CGRect prevFrame;
        int i = 0;
        for (NSValue *value in buttons) {
            i++;
            CGRect frame = [value CGRectValue];
            CGFloat frameRightPoint = frame.origin.x + frame.size.width;
            CGFloat frameLeftPoint;
            CGRect buttonTouchZone;
            // if we're not on the first one
            if (i > 1) {
                frameLeftPoint = ((prevFrame.origin.x + prevFrame.size.width) + frame.origin.x) / 2;
            } else {
                frameLeftPoint = buttonZone.x;
            }
            // if we are on the last one
            if (i == [buttons count]) {
                frameRightPoint = self.view.frame.size.width;
            } else {
                CGRect nextFrame = [[buttons objectAtIndex:i] CGRectValue];
                frameRightPoint = (frameRightPoint + nextFrame.origin.x) / 2;
            }
            
            buttonTouchZone = CGRectMake(frameLeftPoint, 0,
                                         frameRightPoint - frameLeftPoint, buttonZone.y);
            
            [buttonTouchZones addObject:[NSValue valueWithCGRect:buttonTouchZone]];
            
            prevFrame = frame;
        }
        
        // go through each touch zone. when we find where the touch should go,
        // call the selector:
        int j = 0;
        for (NSValue *value in buttonTouchZones) {
            CGRect frame = [value CGRectValue];
            // if the touch is inside of the button touch zone:
            if (touchInWindow.x > frame.origin.x && touchInWindow.x < (frame.origin.x + frame.size.width) &&
                touchInWindow.y > frame.origin.y && touchInWindow.y < (frame.origin.y + frame.size.height)) {
                // run the selector!
                SEL mySelector = [[selectors objectAtIndex:j] pointerValue];
                [self performSelector:mySelector withObject:[buttons objectAtIndex:j]];
                break;
            }
            j++;
        }
        
        return;
    }
    
    if (!previewMode && [studyController.cardList count] == 0) {
        return;
    }
    
    // It's not a swipe - a regular touch!
    // Don't flip - go to the next round:
    // also, don't flip to next round if we are touching the bottom toolbar.
    if ([self resultsDisplayed]) {
        [studyController nextRound];
    } else {
        // don't flip if the user is using text to speech.
        if (isUsingTTS) {
            return;
        }
        [self flipCard:nil];
    }
    
    if (studyBrowseMode == studyBrowseModeAutoAudio) {
        self.studyBrowseModeFunctionRunning = NO;
        self.autoAudioShouldPlay = YES;
    }
}


// Clicking "Done" on top-left:
-(void)doneEvent {
    NSString *lessThan4Str = NSLocalizedStringFromTable(@"Study Cards With Scores < 4", @"Study", @"");
    NSString *titleStr = NSLocalizedStringFromTable(@"Are You Done Studying?", @"Study", @"");
    NSString *notFinishedMessageStr = NSLocalizedStringFromTable(@"It seems you have not finished studying all of your cards.", @"Study", @"");
    NSString *yesFinishedMessageStr = NSLocalizedStringFromTable(@"You've finished the cards to review in this set.", @"Study", @"");
    NSString *continueStr = NSLocalizedStringFromTable(@"Continue Studying", @"Study", @"");
    NSString *returnStr;
    if (self.cardSet) {
        returnStr = NSLocalizedStringFromTable(@"Return to Card Set", @"Study", @"");
    } else {
        returnStr = NSLocalizedStringFromTable(@"Return to Collection", @"Study", @"");
    }

    RIButtonItem *continueItem = [RIButtonItem item];
    continueItem.label = continueStr;
    continueItem.action = ^{};

    RIButtonItem *lessThan4Item = [RIButtonItem item];
    lessThan4Item.label = lessThan4Str;
    lessThan4Item.action = ^{
        [self studyCardsWithScoresLessThan4:nil];
    };
    
    RIButtonItem *returnItem = [RIButtonItem item];
    returnItem.label = returnStr;
    returnItem.action = ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [self doneAction:nil];
        });
    };
    
    if ([self resultsDisplayed] && studyController.studyAlgorithm == studyAlgorithmRepetition) {
        UIAlertView *alert;
        if ([studyController numCardsWithScoresLessThan4] > 0) {
            NSString *learnNewCards = NSLocalizedStringFromTable(@"Learn New Cards", @"Study", @"");
            RIButtonItem *learnItem = [RIButtonItem item];
            learnItem.label = learnNewCards;
            learnItem.action = ^{
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self startNewStudyActionWorker];
                });
            };
            
            
            alert = [[UIAlertView alloc] initWithTitle:titleStr
                                               message:yesFinishedMessageStr
                                      cancelButtonItem:returnItem
                                      otherButtonItems:lessThan4Item, learnItem, nil];
        } else {
            alert = [[UIAlertView alloc] initWithTitle:@""
                                               message:yesFinishedMessageStr
                                      cancelButtonItem:returnItem
                                      otherButtonItems:nil];
        }
        [alert show];
        return;
    }
    if ((![self resultsDisplayed] && [studyController numCards] > 0 && !allowLeavingWithoutResultsPrompt) || forceDisplayResultsPrompt) {
        forceDisplayResultsPrompt = NO;
        NSString *beginTestStr = NSLocalizedStringFromTable(@"Begin Test", @"Study", @"");
        NSString *resultsStr = NSLocalizedStringFromTable(@"View Results", @"Study", @"");
        
        RIButtonItem *beginTestItem = [RIButtonItem item];
        beginTestItem.label = beginTestStr;
        beginTestItem.action = ^{
            [self beginTest:self];
        };
        
        RIButtonItem *resultsItem = [RIButtonItem item];
        resultsItem.label = resultsStr;
        resultsItem.action = ^{
            [self displayResults:nil animated:YES];
        };

        UIAlertView *alert;
        if ([studyController numCardsWithScoresLessThan4] > 0) {
            if ([studyController studyAlgorithmIsTest]) {
                alert = [[UIAlertView alloc] initWithTitle:titleStr
                                                   message:notFinishedMessageStr
                                          cancelButtonItem:continueItem
                                          otherButtonItems:lessThan4Item, resultsItem, returnItem, nil];
            } else {
                alert = [[UIAlertView alloc] initWithTitle:titleStr
                                                   message:notFinishedMessageStr
                                          cancelButtonItem:continueItem
                                          otherButtonItems:beginTestItem, lessThan4Item, resultsItem, returnItem, nil];
            }
        } else {
            if ([studyController studyAlgorithmIsTest]) {
                alert = [[UIAlertView alloc] initWithTitle:titleStr
                                                   message:notFinishedMessageStr
                                          cancelButtonItem:continueItem
                                          otherButtonItems:resultsItem, returnItem, nil];
            } else {
                alert = [[UIAlertView alloc] initWithTitle:titleStr
                                                   message:notFinishedMessageStr
                                          cancelButtonItem:continueItem
                                          otherButtonItems:beginTestItem, resultsItem, returnItem, nil];
            }
        }
        [alert show];
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [self doneAction:nil];
    });
}

// Clicking "Finish Test" on bottom bar in Results view:
-(IBAction)doneAction:(id)sender {
    // Add HUD to screen
    HUD = [[MBProgressHUD alloc] initWithView:self.view];
    [self.view addSubview:HUD];
    // Register for HUD callbacks so we can remove it from the window at the right time
    HUD.delegate = self;
    HUD.labelText = NSLocalizedStringFromTable(@"Saving", @"Import", @"HUD");
    HUD.minShowTime = 0.5;

    [HUD showWhileExecuting:@selector(doneActionWorker) onTarget:self withObject:nil animated:YES];
}

- (void)doneActionWorker {
    [self saveActionWorker];
    if ([FlashCardsCore appIsSyncing] && self.studyController.ofMatrixChanged) {
        UIViewController *parentVC  = [FlashCardsCore parentViewController];
        if ([parentVC respondsToSelector:@selector(setShouldSyncN:)]) {
            [parentVC performSelector:@selector(setShouldSyncN:) withObject:@YES];
        }
    }
}

- (void)startNewStudyActionWorker {
    [self saveActionWorker];
    
    StudySettingsViewController *studyVC = [[StudySettingsViewController alloc] initWithNibName:@"StudySettingsViewController" bundle:nil];
    studyVC.collection = self.collection;
    studyVC.cardSet = self.cardSet;
    studyVC.collection = self.collection;
    studyVC.studyingImportedSet = NO;
    studyVC.studyAlgorithm = studyAlgorithmLearn;
    // Pass the selected object to the new view controller.
    NSMutableArray *viewControllers = [[NSMutableArray alloc] initWithArray:[self.navigationController viewControllers]];
    [viewControllers removeLastObject];
    [viewControllers addObject:studyVC];
    [self.navigationController setViewControllers:viewControllers animated:YES];

}

- (void)saveActionWorker {
    if (audioPlayer) {
        if (audioPlayer.playing) {
            [audioPlayer stop];
        }
    }
    
    // only make changes if things actually changed -- that way these changes are only registered **once**
    if (self.studyController.ofMatrixChanged) {
        self.collection.ofMatrix = self.studyController.ofMatrix;
        self.collection.ofMatrixAdjusted = self.studyController.ofMatrixAdjusted;
    }
    if (self.studyController.numCasesChanged && self.studyController.numCases >= 0) {
        self.collection.numCases = [NSNumber numberWithInt:self.studyController.numCases];
    }
    
    NSManagedObjectContext *tempMOC = [FlashCardsCore tempMOC];
    [tempMOC performBlockAndWait:^{
        for (CardTest *testCard in self.studyController.cardList) {
            if (testCard.eFactorChanged) {
                NSManagedObjectID *objectID = testCard.card.objectID;
                FCCard *card = (FCCard*)[tempMOC objectWithID:objectID];
                [card setEFactor:[NSNumber numberWithDouble:testCard.eFactor]];
            }
        }
        [tempMOC save:nil];
        [FlashCardsCore saveMainMOC:YES];
    }];
    
    self.studyBrowseModeFunctionRunning = NO;
    self.studyBrowseModePaused = YES;
    [Flurry endTimedEvent:@"Study" withParameters:nil];
}

#pragma mark -
#pragma mark Rotation functions

-(void) receivedRotate: (NSNotification*) notification {
    UIDeviceOrientation interfaceOrientation = [[UIDevice currentDevice] orientation];
    
    if (!(UIInterfaceOrientationIsPortrait(interfaceOrientation) || UIInterfaceOrientationIsLandscape(interfaceOrientation))) {
        return;
    }
    
    if (isFullScreen) {
        FCLog(@"is full screen");
    } else {
        FCLog(@"is NOT full screen");
    }
    
    ADBannerView *backBanner  = [[FlashCardsCore appDelegate] bannerAd];
    
    BOOL currentDeviceIsPortrait;
    if (UIInterfaceOrientationIsPortrait(interfaceOrientation)) {
        currentDeviceIsPortrait = YES;
        FCLog(@"portrait");
        if (backBanner && backBanner.bannerLoaded) {
            [backBanner setCurrentContentSizeIdentifier:ADBannerContentSizeIdentifierPortrait];
        }
    } else {
        currentDeviceIsPortrait = NO;
        FCLog(@"landscape");
        if (backBanner && backBanner.bannerLoaded) {
            [backBanner setCurrentContentSizeIdentifier:ADBannerContentSizeIdentifierLandscape];
        }
    }
    
    if (deviceIsPortrait == currentDeviceIsPortrait) {
        return;
    }
    
    BOOL isStudying = ([self.title isEqualToString:NSLocalizedStringFromTable(@"Front", @"Study", @"")] ||
                       [self.title isEqualToString:NSLocalizedStringFromTable(@"Back", @"Study", @"")]);
    if (isStudying && ![FlashCardsAppDelegate isIpad] && !isFullScreen) {
        BOOL isHidden = bottomToolbarStudy.hidden;
        int height = bottomToolbarStudy.frame.size.height;
        // if the phone is landscape, HIDE the toolbar:
        if (UIInterfaceOrientationIsLandscape(interfaceOrientation)) {
            [bottomToolbarStudy setHidden:YES];
            if (!isHidden) {
                [cardView setFrame:CGRectMake(cardView.frame.origin.x,
                                              cardView.frame.origin.y,
                                              cardView.frame.size.width,
                                              cardView.frame.size.height + height)];
                [frontScrollView setFrame:CGRectMake(frontScrollView.frame.origin.x,
                                                     frontScrollView.frame.origin.y,
                                                     frontScrollView.frame.size.width,
                                                     frontScrollView.frame.size.height + height)];
                [backScrollView setFrame:CGRectMake(backScrollView.frame.origin.x,
                                                    backScrollView.frame.origin.y,
                                                    backScrollView.frame.size.width,
                                                    backScrollView.frame.size.height + height)];
                [passFailSegmentedControl setFrame:CGRectMake(passFailSegmentedControl.frame.origin.x,
                                                              passFailSegmentedControl.frame.origin.y + height,
                                                              passFailSegmentedControl.frame.size.width,
                                                              passFailSegmentedControl.frame.size.height)];
            }
        } else {
            [bottomToolbarStudy setHidden:NO];
            if (isHidden) {
                // previously toolbar was hidden - now it is not.
                // so, we need to reduce the size of the views:
                [cardView setFrame:CGRectMake(cardView.frame.origin.x,
                                              cardView.frame.origin.y,
                                              cardView.frame.size.width,
                                              cardView.frame.size.height - height)];
                [frontScrollView setFrame:CGRectMake(frontScrollView.frame.origin.x,
                                                     frontScrollView.frame.origin.y,
                                                     frontScrollView.frame.size.width,
                                                     frontScrollView.frame.size.height - height)];
                [backScrollView setFrame:CGRectMake(backScrollView.frame.origin.x,
                                                    backScrollView.frame.origin.y,
                                                    backScrollView.frame.size.width,
                                                    backScrollView.frame.size.height - height)];
                [passFailSegmentedControl setFrame:CGRectMake(passFailSegmentedControl.frame.origin.x,
                                                              passFailSegmentedControl.frame.origin.y - height,
                                                              passFailSegmentedControl.frame.size.width,
                                                              passFailSegmentedControl.frame.size.height)];
            }
        }
    }
    
    FCLog(@"configuring card");
    deviceIsPortrait = currentDeviceIsPortrait;

    int score = [self getScore];
    [self configureCard];
    [self setScore:score];
    
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    if (previewMode) {
        NSSet *relatedCards = (NSSet*)[previewCard objectForKey:@"relatedCards"];
        return [relatedCards count];
    } else {
        CardTest *testCard = [studyController currentCard];
        return [testCard.card.relatedCards count];
    }
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
    
    // Configure the cell...
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}


-(void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    NSArray *relatedCards;
    if (previewMode) {
        NSSet *relatedCardsSet = (NSSet*)[previewCard objectForKey:@"relatedCards"];
        relatedCards = [relatedCardsSet allObjects];
    } else {
        CardTest *testCard = [studyController currentCard];
        relatedCards = [testCard.card.relatedCards allObjects];
    }

    if ([relatedCards count] == 0) {
        return;
    }
    FCCard *relatedCard = [relatedCards objectAtIndex:indexPath.row];
    
    cell.textLabel.text = relatedCard.frontValue;
    cell.detailTextLabel.text = relatedCard.backValue;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
}

#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    return;
    
}

# pragma mark -
# pragma mark Memory functions

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {

    // front view:
    frontScrollView = nil;
    frontLabel = nil;
    cardNumberLabel = nil;
    bottomToolbarStudy = nil; // necessary so that we can hide it if there aren't any cards to study at all
    frontImage = nil;
    
    // back view:
    backScrollView = nil;
    backLabel = nil;
    passFailSegmentedControl = nil;
    backImage = nil;
    
    // results view:
    bottomToolbarResults = nil;
    pausePlayAutoBrowseButton = nil;
    
    [[NSNotificationCenter defaultCenter]
     removeObserver:self
     name:NSPersistentStoreCoordinatorStoresDidChangeNotification
     object:[[FlashCardsCore mainMOC] persistentStoreCoordinator]];
    
    [super viewDidUnload];
    
}



@end