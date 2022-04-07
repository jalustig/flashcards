//
//  CardEditViewController.h
//  FlashCards
//
//  Created by Jason Lustig on 5/28/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "Swipeable.h"
#import "GrowableTextView.h"

#import "QuizletSync.h"

#import "MBProgressHUD.h"

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@class FCCard;
@class FCCardSet;
@class FCCollection;
@class SwipeableScrollView;
@class GrowableTextView;
@protocol MBProgressHUDDelegate;
@class MBProgressHUD;

#if TARGET_IPHONE_SIMULATOR
#else
@class SMTEDelegateController;
#endif

@interface CardEditViewController : UIViewController <UIAlertViewDelegate, UITableViewDelegate, UITextViewDelegate, MBProgressHUDDelegate, QuizletSyncDelegate, UIActionSheetDelegate> {

    enum
    {
        ENC_AAC = 1,
        ENC_ALAC = 2,
        ENC_IMA4 = 3,
        ENC_ILBC = 4,
        ENC_ULAW = 5,
        ENC_PCM = 6,
    } encodingTypes;

}

- (void) saveEvent;
- (void) nextEvent;
- (void) cancelEvent;

- (IBAction)cardSets:(id)sender;
- (IBAction)relatedCards:(id)sender;
- (IBAction)cardStatistics:(id)sender;
- (IBAction)launchDictionary:(id)sender;
- (IBAction)confirmDeleteCard:(id)sender;
- (void)previewCard;

- (void)startRecording;
- (void)endRecording;
- (void)playRecording;

- (void)loadCardData:(FCCard*)_card;
- (void)loadImageSelector:(NSMutableData*)imageData dataKey:(NSString*)dataKey;

- (CGSize)textViewSize:(UITextView*)textView;
- (void) setTextViewSize:(UITextView*)textView;    

- (void)setTableCellImageView:(UIImageView*)imageView withImage:(UIImage*)image;
- (void)configureCard:(bool)initialLoad;
- (void)saveCard:(BOOL)didPressNextButton;
- (void)isDoneSaving:(BOOL)didPressNextButton;
- (void)prevNextCardAction;
- (bool)allCardsEdited;

- (void)hideMyTableViewFooter;
- (IBAction)doneEditingKeyboard:(id)sender;

- (IBAction)textViewTypeContents:(id)sender;
- (void)addCharacterToTextView:(NSString*)character;

- (void) swapFrontBackValues;

- (void)checkNumberCardsToAdd;

@property (nonatomic, weak) IBOutlet ResignableTableView *myTableView;
@property (nonatomic, strong) IBOutlet UIView *myTableViewFooter;
@property (nonatomic, weak) IBOutlet UIButton *deleteCardButton;

@property (nonatomic, strong) IBOutlet UITableViewCell *frontTextTableCell;
@property (nonatomic, weak) IBOutlet GrowableTextView *frontTextView;
@property (nonatomic, strong) IBOutlet UITableViewCell *backTextTableCell;
@property (nonatomic, weak) IBOutlet GrowableTextView *backTextView;

@property (nonatomic, strong) IBOutlet UITableViewCell *backImageTableCell;
@property (nonatomic, weak) IBOutlet UIImageView *backImageView;
@property (nonatomic, weak) IBOutlet UILabel *backNoImageLabel;
@property (nonatomic, strong) IBOutlet UITableViewCell *frontImageTableCell;
@property (nonatomic, weak) IBOutlet UIImageView *frontImageView;
@property (nonatomic, weak) IBOutlet UILabel *frontNoImageLabel;

@property (nonatomic, strong) IBOutlet UITableViewCell *frontAudioTableCell;
@property (nonatomic, weak) IBOutlet UIImageView *frontAudioLabel;
@property (nonatomic, weak) IBOutlet UILabel *frontAudioDescriptionLabel;

@property (nonatomic, strong) IBOutlet UITableViewCell *backAudioTableCell;
@property (nonatomic, weak) IBOutlet UIImageView *backAudioLabel;
@property (nonatomic, weak) IBOutlet UILabel *backAudioDescriptionLabel;

@property (nonatomic, strong) NSString *audioRecordingKey;
@property (nonatomic, strong) AVAudioRecorder *audioRecorder;
@property (nonatomic, strong) AVAudioPlayer   *audioPlayer;

@property (nonatomic, strong) NSArray *wordTypeOptions;

@property (nonatomic, weak) IBOutlet UISegmentedControl *prevNextSegmentedControl;
@property (nonatomic, weak) IBOutlet UIToolbar *prevNextToolbar;
@property (nonatomic, weak) IBOutlet UIToolbar *mainCardToolbar;

@property (nonatomic, assign) int popToViewControllerIndex;
@property (nonatomic, assign) int cardIndex;
@property (nonatomic, strong) FCCard *card;
@property (nonatomic, strong) NSMutableDictionary *cardData;
@property (nonatomic, strong) FCCardSet *cardSet;
@property (nonatomic, strong) FCCollection *collection;
@property (nonatomic, strong) NSMutableArray *cardList;
@property (nonatomic, strong) NSMutableArray *cardListEdited;


@property (nonatomic, assign) bool hasDisplayedUnlimitedCardsMessage;

@property (nonatomic, assign) int editMode;
@property (nonatomic, assign) bool editInPlace;
@property (nonatomic, assign) bool hasAdjustedFrontFieldWidth;
@property (nonatomic, assign) bool isAttemptingDelete;
@property (nonatomic, assign) bool hasFirstLoaded;
@property (nonatomic, assign) bool canResignTextView;
@property (nonatomic, weak) NSIndexPath *currentlySelectedTextViewIndexPath;

@property (nonatomic, strong) IBOutlet UIView *accessoryView;
@property (nonatomic, strong) IBOutlet UIView *accessoryViewLatex;

@property (nonatomic, strong) UIBarButtonItem *saveButton;

/*
#if TARGET_IPHONE_SIMULATOR
#else
@property (nonatomic, retain) SMTEDelegateController *textExpander;
#endif
*/

@property (nonatomic, weak) IBOutlet UIBarButtonItem *doneEditingButton;
@property (nonatomic, weak) IBOutlet UIImageView *backImageLabel;
@property (nonatomic, weak) IBOutlet UIImageView *frontImageLabel;
@property (nonatomic, weak) IBOutlet UIImageView *backTextLabel;
@property (nonatomic, weak) IBOutlet UIImageView *frontTextLabel;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *cardSetsButton;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *cardStatisticsButton;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *relatedCardsButton;

@property (nonatomic, assign) bool hasAlreadyLoaded;

@property (nonatomic, strong) MBProgressHUD *HUD;
@property (nonatomic, strong) QuizletSync *quizletSync;

@end
