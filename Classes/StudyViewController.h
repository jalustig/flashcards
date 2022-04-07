//
//  StudyViewController.h
//  FlashCards
//
//  Created by Jason Lustig on 5/28/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MessageUI/MessageUI.h>
#import <AVFoundation/AVAudioPlayer.h>
#import <iAd/iAd.h>

#import "StudyController.h"

#import "ASIHTTPRequest.h"

#import "MBProgressHUD.h"

@class FCCard;
@class FCCardSet;
@class FCCollection;
@class CardTest;
@class StudyController;

@class SwipeableView;
@class SwipeableLabel;
@class SwipeableTableView;
@class SwipeableScrollView;
@class SwipeableImageView;
@class SCRSegmentedControl;
@class AVSpeechSynthesizer;

@interface StudyViewController : UIViewController <UITableViewDelegate, UIAlertViewDelegate, MFMailComposeViewControllerDelegate, StudyControllerDelegate, ASIHTTPRequestDelegate, MBProgressHUDDelegate>

- (IBAction)handleSwipeDown:(id)sender;
- (IBAction)handleSwipeUp:(id)sender;
- (IBAction)handleSwipeRight:(id)sender;
- (IBAction)handleSwipeLeft:(id)sender;
- (IBAction)handleTap:(UITapGestureRecognizer *)recognizer;

- (void)setStudyBrowseModePausedB:(NSNumber*)_studyBrowseModePaused;

-(BOOL)resultsDisplayed;
-(void)showPrevNextButton;

# pragma mark -
# pragma mark Configuration Functions

-(IBAction)beginStudying:(id)sender;
-(IBAction)beginTest:(id)sender;
-(IBAction)studyCardsWithScoresLessThan4:(id)sender;
-(IBAction)continueNextRound:(id)sender;
-(void)configurePausePlayAutoBrowseButton;

-(IBAction)fullScreenButtonTapped:(id)sender;

# pragma mark -
# pragma mark TTS Functions

- (IBAction)speakText:(id)sender;

# pragma mark -
# pragma mark Card utility functions

-(void)showNoCardsAlert;

#pragma mark -
#pragma mark Card Configuration functions

-(void)configureCard;

-(bool)isLandscape;

-(IBAction)relatedCardsAction:(id)sender;
-(IBAction)editCardAction:(id)sender;
-(IBAction)cardInfo:(id)sender;

# pragma mark -
# pragma mark Scoring functions

-(IBAction)passFailSelectedIndexChanged:(id)sender;
-(void)setScore:(int)score;
-(int)getScore;

# pragma mark -
# pragma mark Timing functions

-(void)applicationWillResign;
-(void)applicationDidActivate;

# pragma mark -
# pragma mark Test results functions

-(void)displayResults:(id)nilValue animated:(BOOL)animated;

# pragma mark -
# pragma mark Card switching functions

-(void)animateCard:(UIViewAnimationOptions)options;
-(void)prevNextCardAction;
-(IBAction)randomizeCardsAction:(id)sender;

# pragma mark -
# pragma mark Card flip functions

-(BOOL)cardFrontIsShown;
-(void)showBackView:(BOOL)isBackSide;
-(IBAction)flipCard:(id)sender;

# pragma mark -
# pragma mark AutoBrowse Functions

-(IBAction)pausePlayAutoBrowse:(id)sender;
-(void)autoBrowse:(NSString*)pattern;

-(void)doneEvent;
-(IBAction)doneAction:(id)sender;

-(void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath;

-(void)showBannerAd;
-(void)hideBannerAd;

#pragma mark -
#pragma mark @properties

@property (nonatomic, strong) MBProgressHUD *HUD;

@property (nonatomic, strong) StudyController *studyController;

@property (nonatomic, strong) FCCardSet *cardSet;
@property (nonatomic, strong) FCCollection *collection;

@property (nonatomic, assign) BOOL deviceIsPortrait;

@property (nonatomic, assign) BOOL allowLeavingWithoutResultsPrompt;
@property (nonatomic, assign) BOOL forceDisplayResultsPrompt;
@property (nonatomic, assign) BOOL cardTestIsChanged;
@property (nonatomic, strong) NSDate *appLockedTimerBegin;
@property (nonatomic, strong) NSDate *userTouchTimer;

@property (nonatomic, assign) int popToViewControllerIndex;

@property (nonatomic, assign) BOOL previewMode;
@property (nonatomic, strong) NSDictionary *previewCard;

// app settings:
@property (nonatomic, assign) int textSize;
@property (nonatomic) float autoStudySpeed;

// Fullscreen:
@property (nonatomic, weak) IBOutlet UIButton *fullScreenButton;
@property (nonatomic, assign) BOOL isFullScreen;

// TTS:

@property (nonatomic, strong) AVSpeechSynthesizer *speechSynthesizer;
@property (nonatomic, assign) int ttsStringStartLocation;
@property (nonatomic, assign) BOOL ttsStudySideIsFrontOfCard;
@property (nonatomic, strong) AVAudioPlayer *audioPlayer;
@property (nonatomic, weak) IBOutlet UIButton *TTSButton;
@property (nonatomic, weak) IBOutlet UIActivityIndicatorView *TTSActivityIndicator;


// relating to the study state:
@property (nonatomic, assign) int studyBrowseMode;
@property (nonatomic, strong) NSString *autoBrowsePattern;
@property (nonatomic, assign) BOOL studyBrowseModePaused;
@property (nonatomic, assign) BOOL studyBrowseModePausedForSpeakText;
@property (nonatomic, assign) BOOL studyBrowseModeFunctionRunning;

@property (nonatomic, strong) NSString *frontLabelText;

// front view:
@property (nonatomic, weak) IBOutlet UIView *cardView;

@property (nonatomic, weak) IBOutlet SwipeableScrollView *frontScrollView;
@property (nonatomic, weak) IBOutlet SwipeableView *frontView;
@property (nonatomic, weak) IBOutlet SwipeableLabel *frontLabel;
@property (nonatomic, weak) IBOutlet UIWebView *frontWebview;
@property (nonatomic, weak) IBOutlet SwipeableImageView *frontImage;
@property (nonatomic, weak) IBOutlet UILabel *cardNumberLabel;
@property (nonatomic, weak) IBOutlet UIButton *pausePlayAutoBrowseButton;
@property (nonatomic, weak) IBOutlet SwipeableImageView *frontCardImageTop;
@property (nonatomic, weak) IBOutlet SwipeableImageView *frontCardImageBottom;
@property (nonatomic, weak) IBOutlet UIImageView *frontDropshadowImage;

// back view:
@property (nonatomic, weak) IBOutlet SwipeableScrollView *backScrollView;
@property (nonatomic, weak) IBOutlet SwipeableView *backView;
@property (nonatomic, weak) IBOutlet SwipeableLabel *backLabel;
@property (nonatomic, weak) IBOutlet UIWebView *backWebview;
@property (nonatomic, weak) IBOutlet SwipeableImageView *backImage;
@property (nonatomic, weak) IBOutlet UIButton *backHelpButton;
@property (nonatomic, assign) BOOL failPassChanging;
@property (nonatomic, weak) IBOutlet SwipeableImageView *backCardImageTop;
@property (nonatomic, weak) IBOutlet SwipeableImageView *backCardImageBottom;
@property (nonatomic, weak) IBOutlet UIImageView *backDropshadowImage;

@property (nonatomic, strong) SCRSegmentedControl *passFailSegmentedControl;
@property (nonatomic, weak) IBOutlet SwipeableTableView *relatedCardsTableView;

// results view:
@property (nonatomic, weak) IBOutlet UIToolbar *bottomToolbarResults;
@property (nonatomic, weak) IBOutlet UIToolbar *bottomToolbarTestResults;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *studyCardsWithScoresLessThan4Button;

@property (nonatomic, strong) NSError *error;
@property (nonatomic, strong) NSString *errorStr;
@property (nonatomic, strong) NSDictionary *userInfo;
@property (nonatomic, strong) NSString *localizedDescription;

@property (nonatomic, assign) BOOL isReportingError;
@property (nonatomic, assign) BOOL studyingImportedSet;
@property (nonatomic, assign) BOOL didBeginStudying;
@property (nonatomic, assign) BOOL hasAlreadyLoaded;
@property (nonatomic, assign) BOOL isUsingTTS;
@property (nonatomic, assign) BOOL autoAudioShouldPlay;

@property (nonatomic, weak) IBOutlet UIToolbar *bottomToolbarStudy;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *bottomFrontFlipButton;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *bottomFrontRelatedButton;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *bottomFrontStatsButton;


@property (nonatomic, weak) IBOutlet UIButton *editButton;

@property (nonatomic, weak) IBOutlet UIBarButtonItem *resultsNextRoundButton;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *resultsRandomOrderButton;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *resultsBeginTestButton;

@property (nonatomic, weak) IBOutlet UIBarButtonItem *testResultsStudyLessThan4Button;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *testResultsFinishTestButton;


@end
