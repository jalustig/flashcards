//
//  CardEditMultipleViewController.h
//  FlashCards
//
//  Created by Jason Lustig on 6/21/13.
//  Copyright (c) 2013 Jason Lustig. All rights reserved.
//

#import <UIKit/UIKit.h>

@class FCCardSet;
@class FCCollection;
@class ResignableTableView;
@class GrowableTextView;

@interface CardEditMultipleViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>

- (void)setCardText:(NSString*)text forCard:(int)i forSide:(NSString*)side;
- (NSMutableDictionary*)cardAtRow:(int)row;
- (void)addNewCard;
- (IBAction)addNewCard:(id)sender;

@property (nonatomic) BOOL isAddingNewCard;
@property (nonatomic) BOOL canResignTextView;
@property (nonatomic) float calculatedTextViewWidth;

@property (nonatomic, strong) FCCardSet *cardSet;
@property (nonatomic, strong) FCCollection *collection;
@property (nonatomic, strong) NSMutableArray *cards;

@property (nonatomic, weak) IBOutlet ResignableTableView *myTableView;
@property (nonatomic, weak) IBOutlet UIButton *addCardButton;

@property (nonatomic, strong) GrowableTextView *textView;

@property (nonatomic, strong) IBOutlet UIView *accessoryView;

@end
