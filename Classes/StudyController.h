//
//  StudyController.h
//  FlashCards
//
//  Created by Jason Lustig on 4/24/11.
//  Copyright 2011-2014 Jason Lustig Lustig. All rights reserved.
//

#import <Foundation/Foundation.h>
#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
#import <MessageUI/MessageUI.h>
#else
#import "iOSCompatabilityConstants.h"
#endif

@class FCCard;
@class FCCardSet;
@class CardTest;
@class FCCollection;
@protocol StudyControllerDelegate;

#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
@interface StudyController : NSObject <UIAlertViewDelegate, MFMailComposeViewControllerDelegate>
#else
@interface StudyController : NSObject
#endif
{
    
    int numCases;
    BOOL numCasesChanged;
    
    NSMutableArray *ofMatrix;
    NSMutableArray *ofMatrixAdjusted;
    BOOL ofMatrixChanged;
    
    int currentRound;
    NSMutableArray *cardList; // list of cards to be studied - actually is the card holder.
    NSMutableArray *studyList; // list of references to the cards
    NSInteger currentCardIndex; // where we are right now
    
    BOOL cardListIsTranslated;
    
    // relating to the study state:
    BOOL loadingCardsFromSavedState;
    int studyAlgorithm;
    int studyOrder;
    int showFirstSide;
    int numCardsToLoad;
    int selectCards;
    BOOL loadNewCardsOnly;
    int studyBrowseMode;
    BOOL studyBrowseModePaused;
    BOOL studyBrowseModeFunctionRunning;
    
    NSString *errorStr;
    NSDictionary *userInfo;
    NSString *localizedDescription;

    BOOL studyingImportedSet; // allows us to tell when the user is importing the set. 
    // if this is set to YES, then we never prompt with a previously saved study sessino.
    BOOL didBeginStudying;
    
    id<StudyControllerDelegate>delegate;
    
}

# pragma mark -
# pragma mark Saving State Functions

-(void)saveCardListToCollection;
-(void)saveCardListDoneToCollection;

# pragma mark -
# pragma mark Configuration Functions

-(void)loadCardsFromStore;
-(void)beginStudying:(id)sender;
-(void)beginSmartStudying;
-(void)beginTest:(id)sender;
-(int)numCardsWithScoresLessThan4;
-(void)studyCardsWithScoresLessThan4:(id)sender;
-(void)nextRound;
-(void)prevCard;
-(void)nextCard;
-(void)randomizeCards;
-(void)randomizeStudyList;

# pragma mark -
# pragma mark Card utility functions

-(int)numCards;
-(void)removeCardFromStudy:(FCCard*)card;
-(CardTest*)currentCard;
-(CardTest*)getCard:(int)cardIndex;
-(void)resetStudyList;
-(void)queueCardInStudyList:(int)cardListIndex;
-(void)dequeueCardInStudyList:(int)cardListIndex;
-(void)translateCardsToCardTests;
-(BOOL)studyAlgorithmIsLearning;
-(BOOL)studyAlgorithmIsTest;

# pragma mark -
# pragma mark Scoring functions

-(void)resetCurrentCardScore;
-(void)setCurrentCardScore;
-(void)resetScores;
-(void)saveScore;

# pragma mark -
# pragma mark Test results functions

-(double)percentSkipped;
-(double)percentPassed;
-(double)averageNextInterval;
-(NSString*)formatInterval:(double)avgNextInterval;
-(double)averageScore;

#pragma mark -
#pragma mark @properties

@property (nonatomic, assign) int numCases;
@property (nonatomic, assign) BOOL numCasesChanged;

@property (nonatomic, strong) NSMutableArray *ofMatrix;
@property (nonatomic, strong) NSMutableArray *ofMatrixAdjusted;
@property (nonatomic, assign) BOOL ofMatrixChanged;

@property (nonatomic, assign) int currentRound;

@property (nonatomic, strong) NSMutableArray *cardList;
@property (nonatomic, strong) NSMutableArray *studyList;
@property (nonatomic) NSInteger currentCardIndex;

@property (nonatomic, assign) BOOL cardListIsTranslated;
@property (nonatomic, assign) BOOL loadingCardsFromSavedState;

// relating to the study state:
@property (nonatomic, assign) int studyAlgorithm;
@property (nonatomic, assign) int studyOrder;
@property (nonatomic, assign) int showFirstSide;
@property (nonatomic, assign) int numCardsToLoad;
@property (nonatomic, assign) int selectCards;
@property (nonatomic, assign) BOOL loadNewCardsOnly;

@property (nonatomic, strong) NSString *errorStr;
@property (nonatomic, strong) NSDictionary *userInfo;
@property (nonatomic, strong) NSString *localizedDescription;

@property (nonatomic, assign) BOOL studyingImportedSet;
@property (nonatomic, assign) BOOL didBeginStudying;

@property (nonatomic, strong) id<StudyControllerDelegate>delegate;


@end

@protocol StudyControllerDelegate <NSObject>

@required 

@property (nonatomic, retain) FCCollection *collection;
@property (nonatomic, retain) FCCardSet *cardSet;
@property (nonatomic, assign) BOOL cardTestIsChanged;
@property (nonatomic, assign) BOOL allowLeavingWithoutResultsPrompt;
@property (nonatomic, assign) BOOL forceDisplayResultsPrompt;
@property (nonatomic, assign) int studyBrowseMode;
@property (nonatomic, assign) BOOL studyBrowseModePaused;
@property (nonatomic, assign) BOOL studyBrowseModeFunctionRunning;

@optional

- (void)hideCardNumberLabel;
- (void)showCardNumberLabel;
- (void)configureCard;
- (void)animateCard:(UIViewAnimationOptions)options;
- (void)showPrevNextButton;
- (void)configurePausePlayAutoBrowseButton;
- (void)showNoCardsAlert;
- (void)showBackView:(BOOL)yesno;

- (void)setScore:(int)score;
- (int)getScore;

- (bool)resultsDisplayed;
- (void)displayResults:(id)nilValue animated:(BOOL)animated;

- (void)doneEvent;

#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
- (void)presentViewController:(UIViewController *)viewControllerToPresent
                     animated:(BOOL)flag
                   completion:(void (^)(void))completion;
- (void)presentModalViewController:(UIViewController*)controller animated:(BOOL)animated;
- (void)dismissModalViewControllerAnimated:(BOOL)animated;
- (void)dismissViewControllerAnimated:(BOOL)flag
                           completion:(void (^)(void))completion;
#endif

@end

