//
//  MatchLocalCardsWithRemoteCardsViewController.h
//  FlashCards
//
//  Created by Jason Lustig on 11/2/12.
//  Copyright (c) 2012 Jason Lustig. All rights reserved.
//

#import <UIKit/UIKit.h>

@class FCCardSet;
@class ImportSet;

@interface MatchLocalCardsWithRemoteCardsViewController : UIViewController <UITableViewDelegate>

- (void)cancelEvent;
- (void)saveEvent;
- (void)returnToImportView:(BOOL)animated;
- (IBAction)proceedToNextCard:(id)sender;

- (void)findExactMatches;

- (void)configureCard:(int)index;

@property (nonatomic, strong) FCCardSet *localSet;
@property (nonatomic, strong) ImportSet *remoteSet;
@property (nonatomic, assign) int currentCardIndex;
@property (nonatomic, strong) NSMutableArray *localCardsWithoutWebIds;

@property (nonatomic, strong) ImportTerm *selectedImportTerm;
@property (nonatomic, strong) NSMutableArray *bestPotentialMatches;
@property (nonatomic, strong) NSMutableArray *otherPotentialMatches;
@property (nonatomic, strong) NSMutableArray *remoteTermsThatHaveNotYetBeenMatched;

@property (nonatomic, weak) IBOutlet UITableView *myTableView;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *proceedToNextCardButton;

@property (nonatomic, strong) NSString *importMethod;

@property (nonatomic, assign) int popToViewControllerIndex;

@end
