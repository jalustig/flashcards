//
//  CardEditMultipleViewController.m
//  FlashCards
//
//  Created by Jason Lustig on 6/21/13.
//  Copyright (c) 2013 Jason Lustig. All rights reserved.
//

#import "CardEditMultipleViewController.h"
#import "CardEditMultipleCell.h"

#import "FlashCardsAppDelegate.h"

#import "Swipeable.h"
#import "GrowableTextView.h"

#import "FCCard.h"
#import "FCCardSet.h"
#import "FCCollection.h"

#import "UIAlertView+Blocks.h"

@interface CardEditMultipleViewController ()

@end

@implementation CardEditMultipleViewController

@synthesize isAddingNewCard;
@synthesize canResignTextView;
@synthesize calculatedTextViewWidth;

@synthesize cardSet;
@synthesize collection;
@synthesize cards;

@synthesize myTableView;
@synthesize textView;
@synthesize addCardButton;
@synthesize accessoryView;

- (BOOL)shouldAutorotate {
    UIInterfaceOrientation interfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait || interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown);
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    isAddingNewCard = NO;
    
    self.title = NSLocalizedStringFromTable(@"Create Multiple Cards", @"CardManagement", @"");
    
    UIBarButtonItem *cancel = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelEvent)];
    self.navigationItem.leftBarButtonItem = cancel;
    
    UIBarButtonItem *save = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector(saveEvent)];
    self.navigationItem.rightBarButtonItem = save;
    
    [addCardButton setTitle:NSLocalizedStringFromTable(@"Add Card", @"CardManagement", @"UIButton") forState:UIControlStateNormal];
    [addCardButton setTitle:NSLocalizedStringFromTable(@"Add Card", @"CardManagement", @"UIButton") forState:UIControlStateSelected];

    [self.myTableView registerNib:[UINib nibWithNibName:@"CardEditMultipleCell" bundle:[NSBundle mainBundle]]
           forCellReuseIdentifier:@"CardCell"];

    cards = [[NSMutableArray alloc] initWithCapacity:0];
    [self addNewCard];
    
    if ([self hasExceededMaxCards]) {
    }
    
    [self setupWidths];
    
    textView = [[GrowableTextView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, calculatedTextViewWidth, 29.0f)];
    
    [self.myTableView reloadData];
}

- (BOOL)hasExceededMaxCards {
    if (![FlashCardsCore hasFeature:@"UnlimitedCards"]) {
        int initialNumCards = [FlashCardsCore numTotalCards] + [self.cards count];
        if (initialNumCards >= maxCardsLite) {
            [FlashCardsCore showPurchasePopup:@"UnlimitedCards"];
            return YES;
        }
    }
    return NO;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)setupWidths {
    int totalWidth = [UIScreen mainScreen].bounds.size.width - 140;
    self.calculatedTextViewWidth = totalWidth / 2;
}

- (void)addNewCard:(id)sender {
    isAddingNewCard = YES;
    [self addNewCard];
    if ([self hasExceededMaxCards]) {
        [self.cards removeLastObject];
        return;
    }

    [self.myTableView reloadData];
    // try to identify the exact cause of: https://rink.hockeyapp.net/manage/apps/20975/app_versions/63/crash_reasons/8226743
    int cardCount = [self.cards count];
    NSIndexPath *location = [NSIndexPath indexPathForRow:(cardCount-1) inSection:0];
    CardEditMultipleCell *cell = (CardEditMultipleCell*)[self.myTableView cellForRowAtIndexPath:location];
    [cell.frontTextView becomeFirstResponder];
    isAddingNewCard = NO;
}

- (void)addNewCard {
    NSMutableDictionary *card = [NSMutableDictionary dictionaryWithDictionary:@{@"frontValue" : @"", @"backValue": @""}];
    [self.cards addObject:card];
}

- (void)setCardText:(NSString *)text forCard:(int)i forSide:(NSString *)side {
    NSMutableDictionary *card;
    while ([self.cards count] <= i) {
        [self addNewCard];
    }
    card = [self cardAtRow:i];
    [card setObject:text forKey:side];
    [self.cards setObject:card atIndexedSubscript:i];
}

- (NSMutableDictionary*)cardAtRow:(int)row {
    if ([self.cards count] <= row) {
        return [NSMutableDictionary dictionaryWithDictionary:@{@"frontValue" : NSLocalizedStringFromTable(@"Front Side of Card", @"CardManagement", @""), @"backValue": NSLocalizedStringFromTable(@"Back Side of Card", @"CardManagement", @"")}];
    }
    return [self.cards objectAtIndex:row];
}

- (void)cancelEvent {
    
    int saveCount = 0;
    for (NSMutableDictionary *cardData in cards) {
        NSString *frontValue = [cardData objectForKey:@"frontValue"];
        NSString *backValue  = [cardData objectForKey:@"backValue"];
        if ([frontValue length] == 0 && [backValue length] == 0) {
            continue;
        }
        saveCount++;
    }
    
    if (saveCount == 0) {
        [self.navigationController popViewControllerAnimated:YES];
    } else {
        RIButtonItem *cancelItem = [[RIButtonItem alloc] init];
        cancelItem.label = NSLocalizedStringFromTable(@"Exit", @"CardManagement", @"");
        cancelItem.action = ^{
            [self.navigationController popViewControllerAnimated:YES];
        };
        
        RIButtonItem *dontCancelItem = [[RIButtonItem alloc] init];
        dontCancelItem.label = NSLocalizedStringFromTable(@"Don't Exit", @"CardManagement", @"");
        dontCancelItem.action = ^{
        };

        UIAlertView *alert;
        alert = [[UIAlertView alloc] initWithTitle:@""
                                           message:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Are you sure you want to exit this screen? You have entered %d cards. If you exit, they will not be saved.", @"CardManagement", @""), saveCount]
                                  cancelButtonItem:cancelItem
                                  otherButtonItems:dontCancelItem, nil];
        [alert show];
    }
}

- (void)saveEvent {
    FCCard *card;
    int saveCount = 0;
    for (NSMutableDictionary *cardData in cards) {
        NSString *frontValue = [cardData objectForKey:@"frontValue"];
        NSString *backValue  = [cardData objectForKey:@"backValue"];
        if ([frontValue length] == 0 && [backValue length] == 0) {
            continue;
        }
        
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
        [card setFrontValue:frontValue];
        [card setBackValue:backValue];
        
        saveCount++;
    }
    
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

    [FlashCardsCore saveMainMOC:NO];
    FCDisplayBasicErrorMessage(@"", [NSString stringWithFormat:NSLocalizedStringFromTable(@"%d Cards Saved", @"CardManagement", @""), saveCount]);
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)tellParentToSync {
    UIViewController *parentVC = [FlashCardsCore parentViewController];
    if ([parentVC respondsToSelector:@selector(setShouldSyncN:)]) {
        [parentVC performSelector:@selector(setShouldSyncN:) withObject:[NSNumber numberWithBool:YES]];
    }
}

# pragma mark - UITableViewDelegate methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [cards count];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 44;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSMutableDictionary *card = [self cardAtRow:indexPath.row];

    NSString *text;
    
    text = [card objectForKey:@"frontValue"];
    if ([text length] == 0) {
        text = NSLocalizedStringFromTable(@"Front Side of Card", @"CardManagement", @"");
    }
    [textView setText:text];
    [textView setTextViewSize];
    int heightFront = textView.frame.size.height + 12;
    
    text = [card objectForKey:@"backValue"];
    if ([text length] == 0) {
        text = NSLocalizedStringFromTable(@"Back Side of Card", @"CardManagement", @"");
    }
    [textView setText:text];
    [textView setTextViewSize];
    int heightBack = textView.frame.size.height + 12;
    
    if (heightFront < 44) {
        heightFront = 44;
    }
    if (heightBack < 44) {
        heightBack = 44;
    }
    if (heightFront > heightBack) {
        return (CGFloat)heightFront+12;
    }
    return (CGFloat)heightBack+12;
}
// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    CardEditMultipleCell *cell = (CardEditMultipleCell*) [self.myTableView dequeueReusableCellWithIdentifier:@"CardCell"];
    if (cell == nil) {
        cell = [[CardEditMultipleCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"CardCell"];
    }

    NSMutableDictionary *card = [self cardAtRow:(int)indexPath.row];
    NSString *text;
    text = [card objectForKey:@"frontValue"];
    if ([text length] == 0) {
        text = NSLocalizedStringFromTable(@"Front Side of Card", @"CardManagement", @"");
    }
    cell.frontTextView.text = text;
    
    text = [card objectForKey:@"backValue"];
    if ([text length] == 0) {
        text = NSLocalizedStringFromTable(@"Back Side of Card", @"CardManagement", @"");
    }
    cell.backTextView.text = text;
    
    [cell.frontTextView setFrame:CGRectMake(cell.frontTextView.frame.origin.x,
                                            cell.frontTextView.frame.origin.y,
                                            calculatedTextViewWidth,
                                            cell.frontTextView.frame.size.height)];

    [cell.backTextView  setFrame:CGRectMake((cell.frontTextView.frame.origin.x + calculatedTextViewWidth + 20),
                                            cell.backTextView.frame.origin.y,
                                            calculatedTextViewWidth,
                                            cell.backTextView.frame.size.height)];

    cell.controller = self;
    cell.cardNumber = indexPath.row;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
}

@end
