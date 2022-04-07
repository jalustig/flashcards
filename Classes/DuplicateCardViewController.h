//
//  DuplicateCardViewController.h
//  FlashCards
//
//  Created by Jason Lustig on 8/28/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import <UIKit/UIKit.h>

@class GrowableTextView;
@class ImportTerm;

@interface DuplicateCardViewController : UIViewController <UITableViewDelegate, UITextViewDelegate>

- (void)cancelEvent;
- (void)saveEvent;
- (void)returnToImportView;
- (void) mergeNextPrevCardAction;
- (void)resignAllTextViews;

- (UITextView*) textViewAtIndex:(NSIndexPath*)indexPath;

- (IBAction)doneEditingKeyboard:(id)sender;
- (IBAction)textViewTypeLeftParens:(id)sender;
- (IBAction)textViewTypeRightParens:(id)sender;
- (IBAction)textViewTypeComma:(id)sender;
- (IBAction)textViewTypeSemicolon:(id)sender;
- (IBAction)textViewTypePeriod:(id)sender;
- (IBAction)textViewTypeAsterix:(id)sender;
- (IBAction)textViewTypeApostrophe:(id)sender;
- (void)addCharacterToTextView:(NSString*)character;

- (CGSize)textViewSize:(UITextView*)textView;
- (void) setTextViewSize:(UITextView*)textView;    

- (IBAction)switchDidChange:(id)sender;

- (IBAction)doneEditing:(id)sender;
- (IBAction)mergeViewBackgroundTap:(id)sender;

- (void)configureMergeLabels;
- (void)saveMergeChoices;

- (BOOL)allDuplicateCardsChecked;
- (int)numDuplicateCards;
- (ImportTerm*)currentTerm;

- (BOOL)mergingWillUpdateTheWeb;

- (void)tableViewCell:(UITableViewCell*)cell setSelected:(bool)isSelected;

- (NSString*)mergeString:(NSString*)oldCardString withString:(NSString*)newCardString;

- (NSString*)syncExplanationString;

// Merge View

@property (nonatomic, weak) IBOutlet UISegmentedControl *mergePrevNextSegmentedControl;
@property (nonatomic, weak) IBOutlet UIToolbar *prevNextToolbar;

@property (nonatomic, strong) IBOutlet UITableViewCell    *mergeCell;
@property (nonatomic, weak) IBOutlet UILabel            *mergeLabel;
@property (nonatomic, weak) IBOutlet UISwitch           *mergeSwitch;

@property (nonatomic, strong) IBOutlet UITableViewCell    *markRelatedCell;
@property (nonatomic, weak) IBOutlet UILabel            *markRelatedLabel;
@property (nonatomic, weak) IBOutlet UISwitch           *markRelatedSwitch;

@property (nonatomic, strong) IBOutlet UITableViewCell    *resetStatisticsCell;
@property (nonatomic, weak) IBOutlet UILabel            *resetStatisticsLabel;
@property (nonatomic, weak) IBOutlet UISwitch           *resetStatisticsSwitch;

@property (nonatomic, strong) IBOutlet UITableViewCell    *mergeFrontCell;
@property (nonatomic, weak) IBOutlet UILabel            *mergeFrontLabel;
@property (nonatomic, weak) IBOutlet UISwitch           *mergeFrontSwitch;

@property (nonatomic, strong) IBOutlet UITableViewCell    *mergeBackCell;
@property (nonatomic, weak) IBOutlet UILabel            *mergeBackLabel;
@property (nonatomic, weak) IBOutlet UISwitch           *mergeBackSwitch;


@property (nonatomic, strong) IBOutlet UITableViewCell    *remoteCardFrontValueCell;
@property (nonatomic, weak) IBOutlet UILabel            *remoteCardFrontValueLabel;
@property (nonatomic, weak) IBOutlet GrowableTextView   *remoteCardFrontValueTextView;

@property (nonatomic, strong) IBOutlet UITableViewCell    *oldCardFrontValueCell;
@property (nonatomic, weak) IBOutlet UILabel            *oldCardFrontValueLabel;
@property (nonatomic, weak) IBOutlet GrowableTextView   *oldCardFrontValueTextView;

@property (nonatomic, strong) IBOutlet UITableViewCell    *remoteCardBackValueCell;
@property (nonatomic, weak) IBOutlet UILabel            *remoteCardBackValueLabel;
@property (nonatomic, weak) IBOutlet GrowableTextView   *remoteCardBackValueTextView;

@property (nonatomic, strong) IBOutlet UITableViewCell    *oldCardBackValueCell;
@property (nonatomic, weak) IBOutlet UILabel            *oldCardBackValueLabel;
@property (nonatomic, weak) IBOutlet GrowableTextView   *oldCardBackValueTextView;

@property (nonatomic, strong) IBOutlet UITableViewCell    *mergedCardFrontValueCell;
@property (nonatomic, weak) IBOutlet UILabel            *mergedCardFrontValueLabel;
@property (nonatomic, weak) IBOutlet GrowableTextView   *mergedCardFrontValueTextView;

@property (nonatomic, strong) IBOutlet UITableViewCell    *mergedCardBackValueCell;
@property (nonatomic, weak) IBOutlet UILabel            *mergedCardBackValueLabel;
@property (nonatomic, weak) IBOutlet GrowableTextView   *mergedCardBackValueTextView;


@property (nonatomic, weak) IBOutlet UITableView        *myTableView;

@property (nonatomic, strong) IBOutlet UIView *accessoryView;

@property (nonatomic, strong) NSMutableArray *termsList;

@property (nonatomic, assign) int mergeCardFront; // keeps track of whether the merged card (option 0) will use the current or new card's front value
@property (nonatomic, assign) int mergeCardBack; // keeps track of whether the merged card (option 0) will use the current or new card's back value

// Used to track our progress through looking at the list of duplicated cards.
@property (nonatomic, assign) int duplicateCardsIndex;
@property (nonatomic, strong) NSMutableArray *duplicateCards;
@property (nonatomic, assign) BOOL autoMergeIdenticalCards;
@property (nonatomic, assign) bool canResignTextView;
@property (nonatomic, weak) NSIndexPath *currentlySelectedTextViewIndexPath;

@property (nonatomic, assign) int popToViewControllerIndex;

@end
