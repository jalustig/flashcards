//
//  StudySettingsViewController.h
//  FlashCards
//
//  Created by Jason Lustig on 8/22/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SCRSegmentedControl.h"

@class FCCardSet;
@class FCCollection;

@interface StudySettingsViewController : UIViewController <UIAlertViewDelegate, UITableViewDataSource, UITableViewDelegate>

- (IBAction)onlyNewCardsSwitchChanged:(id)sender;
- (IBAction)beginStudying:(id)sender;
- (void)displaySettings;
- (void)settingsAllCardsChanged;

@property (nonatomic, strong) FCCardSet *cardSet;
@property (nonatomic, strong) FCCollection *collection;
@property (nonatomic, assign) int cardListCount;
@property (nonatomic, assign) int allCardsListCount;

@property (nonatomic, assign) BOOL studyingImportedSet;

// study options:
@property (nonatomic, assign) int studyAlgorithm;
@property (nonatomic, assign) int studyOrder;
@property (nonatomic, assign) int selectCards;
@property (nonatomic, assign) int showFirstSide;
@property (nonatomic, assign) int studyBrowseMode;
@property (nonatomic, assign) BOOL loadingCardsFromSavedState;
@property (nonatomic, assign) int numCardsToLoad; // 0 = all cards
@property (nonatomic, assign) BOOL loadNewCardsOnly;

// settings view:

@property (nonatomic, weak) IBOutlet UIBarButtonItem *beginStudyingButton;
@property (nonatomic, weak) IBOutlet UIToolbar *beginStudyingToolbar;
@property (nonatomic, weak) IBOutlet UITableView *myTableView;

@property (nonatomic, strong) IBOutlet UITableViewCell *onlyNewCardsCell;
@property (nonatomic, weak)   IBOutlet UILabel         *onlyNewCardsLabel;
@property (nonatomic, weak)   IBOutlet UISwitch        *onlyNewCardsSwitch;

@end
