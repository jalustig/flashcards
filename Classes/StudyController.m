//
//  StudyController.m
//  FlashCards
//
//  Created by Jason Lustig on 4/24/11.
//  Copyright 2011-2014 Jason Lustig Lustig. All rights reserved.
//

#import "StudyController.h"

#import "FCCollection.h"
#import "FCCardSet.h"
#import "FCCard.h"
#import "FCCardRepetition.h"
#import "FCCardSetCard.h"

#import "CardTest.h"
#import "FCMatrix.h"

#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
#import "FlashCardsAppDelegate.h"
#else
#import "iOSCompatabilityConstants.h"
#endif

@implementation StudyController

@synthesize delegate;
@synthesize currentRound, currentCardIndex, cardListIsTranslated;
@synthesize cardList, studyList;
@synthesize loadingCardsFromSavedState;
@synthesize studyAlgorithm;
@synthesize studyOrder;
@synthesize showFirstSide;
@synthesize numCardsToLoad;
@synthesize loadNewCardsOnly;
@synthesize selectCards;
@synthesize errorStr, userInfo, localizedDescription;
@synthesize studyingImportedSet, didBeginStudying;
@synthesize ofMatrix, ofMatrixAdjusted;
@synthesize ofMatrixChanged;
@synthesize numCases;
@synthesize numCasesChanged;

- (id)init {
    if ((self = [super init])) {
        cardListIsTranslated = NO;
        currentRound = 0;
        currentCardIndex = 0;
        
        selectCards = 0;
        numCardsToLoad = 0;
        loadNewCardsOnly = NO;
        loadingCardsFromSavedState = NO;
        
        ofMatrixChanged = NO;
        numCasesChanged = NO;
        numCases = -1;
    }
    return self;
}


# pragma mark -
# pragma mark Alert functions & error reporting

#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
-(void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 0) {
        // OK
        return;
    }
    
    // Report error:
    MFMailComposeViewController* controller = [[MFMailComposeViewController alloc] init];
    controller.mailComposeDelegate = self;
    [controller setToRecipients:[NSArray arrayWithObject:contactEmailAddress]];
    [controller setSubject:@"FlashCards++ Error"];
    [controller setMessageBody:[FlashCardsAppDelegate buildErrorReportEmail:errorStr userInfo:userInfo localizedDescription:localizedDescription viewControllerName:@"StudyViewController"] isHTML:NO]; 
    if (delegate && [delegate respondsToSelector:@selector(presentViewController:animated:completion:)]) {
        [delegate presentViewController:controller animated:YES completion:nil];
    }
    
    return;
}

-(void)mailComposeController:(MFMailComposeViewController*)controller  
         didFinishWithResult:(MFMailComposeResult)result 
                       error:(NSError*)myError;
{
    if (result == MFMailComposeResultSent) {
        // thank the user for sending feedback:
        // FIX!!!!!
        FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"Thank You", @"Feedback", @""), 
                                   NSLocalizedStringFromTable(@"Thank you for sending your message. We will be in touch shortly.", @"Feedback", @""));
    } else if (result == MFMailComposeResultFailed) {
        FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"Error", @"Error", @"UIAlert title"),
                                   [NSString stringWithFormat:NSLocalizedStringFromTable(@"An error occurred sending your message: %@ %@", @"Error", @"message"), myError, [myError userInfo]]);
    }
    if (delegate && [delegate respondsToSelector:@selector(dismissViewControllerAnimated:completion:)]) {
        [delegate dismissViewControllerAnimated:YES completion:nil];
    }
}
#endif


# pragma mark -
# pragma mark Saving State Functions

-(void)saveCardListToCollection {
    [delegate.collection setStudyStateDate:[NSDate date]];
    [delegate.collection setStudyStateDone:[NSNumber numberWithBool:NO]];
    [delegate.collection setStudyStateStudyOrder:[NSNumber numberWithInt:studyOrder]];
    [delegate.collection setStudyStateStudyAlgorithm:[NSNumber numberWithInt:studyAlgorithm]];
    [delegate.collection setStudyStateShowFirstSide:[NSNumber numberWithInt:showFirstSide]];
    // clear out the study card list:
    [delegate.collection removeStudyStateCardList:delegate.collection.studyStateCardList];
    // add the current study card list:
    //   1. Re-translate the cards list from CardTest objects to Card objects:
    NSMutableArray *allCards = [[NSMutableArray alloc] initWithCapacity:0];
    for (int i = 0; i < [cardList count]; i++) {
        [allCards addObject:((CardTest *)[cardList objectAtIndex:i]).card];
    }
    [delegate.collection addStudyStateCardList:[NSSet setWithArray:allCards]];
    
    [FlashCardsCore saveMainMOC];
    
}
-(void)saveCardListDoneToCollection {
    
    [delegate.collection setStudyStateDone:[NSNumber numberWithBool:YES]];
    
    [FlashCardsCore saveMainMOC];
}

# pragma mark -
# pragma mark Configuration Functions

-(void)loadCardsFromStore {
    
    if (loadingCardsFromSavedState) {
        cardList = [[NSMutableArray alloc] initWithArray:
                    [[delegate.collection.studyStateCardList filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"isDeletedObject = NO"]]
                     allObjects]];
        return;
    }
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    // Edit the entity name as appropriate.
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Card"
                                              inManagedObjectContext:[FlashCardsCore mainMOC]];
    [fetchRequest setEntity:entity];
    
    NSMutableArray *predicates = [[NSMutableArray alloc] initWithCapacity:0];
    [predicates addObject:[NSPredicate predicateWithFormat:@"isDeletedObject = NO"]];
    if (delegate.cardSet) {
        [predicates addObject:[NSPredicate predicateWithFormat:@"collection = %@ and any cardSet = %@", delegate.collection, delegate.cardSet]];
    } else {
        [predicates addObject:[NSPredicate predicateWithFormat:@"collection = %@", delegate.collection]];
    }
    
    if (studyAlgorithm == studyAlgorithmTest) {
        [predicates addObject:[NSPredicate predicateWithFormat:@"isSpacedRepetition = NO"]];
        
    } else if (studyAlgorithm == studyAlgorithmLearn) {
        
        // find out how many cards there are to test
        
        if (loadNewCardsOnly) {
            // only new cards
            [predicates addObject:[NSPredicate predicateWithFormat:@"isSpacedRepetition = NO"]];
        } else {
            // all cards
        }
        
    } else if (studyAlgorithm == studyAlgorithmRepetition) {
        // find out how many repetition cards there are:
        
        [predicates addObject:[NSPredicate predicateWithFormat:@"isSpacedRepetition = YES and nextRepetitionDate <= %@", [NSDate date]]];
        
    } else if (studyAlgorithm == studyAlgorithmLapsed) {
        // find out how many lapsed cards there are:
        
        [predicates addObject:[NSPredicate predicateWithFormat:@"isLapsed = YES"]];
        
    }
    
    if (numCardsToLoad > 0) { // NB: numCardsToLoad == 0 means ALL CARDS
        if (selectCards == selectCardsRandom) {
            [fetchRequest setResultType:NSManagedObjectIDResultType];
            [fetchRequest setIncludesPropertyValues:NO];
            [fetchRequest setPredicate:[NSCompoundPredicate andPredicateWithSubpredicates:predicates]];
            NSArray *tempIds = [[FlashCardsCore mainMOC] executeFetchRequest:fetchRequest error:nil];
            NSMutableArray *tempIdsMutable = [NSMutableArray arrayWithArray:tempIds];
            
            // Based on http://en.wikipedia.org/wiki/Fisher%E2%80%93Yates_shuffle#The_modern_algorithm
            int j;
            for (int i = (int)[tempIdsMutable count]-1; i > 0; i--) {
                j = arc4random() % i;
                [tempIdsMutable exchangeObjectAtIndex:i withObjectAtIndex:j];
            }
            
            while ([tempIdsMutable count] > numCardsToLoad) {
                [tempIdsMutable removeLastObject];
            }
            
            [predicates addObject:[NSPredicate predicateWithFormat:@"self in %@", tempIdsMutable]];
            [fetchRequest setResultType:NSManagedObjectResultType];
            [fetchRequest setIncludesPropertyValues:YES];

        } else if (selectCards == selectCardsHardest) {
            [fetchRequest setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"eFactor" ascending:YES]]];
            [fetchRequest setFetchLimit:numCardsToLoad];
        } else if (selectCards == selectCardsNewest) {
            [fetchRequest setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"dateCreated" ascending:NO]]];
            [fetchRequest setFetchLimit:numCardsToLoad];
        }
    }
    
    
    [fetchRequest setPredicate:[NSCompoundPredicate andPredicateWithSubpredicates:predicates]];
    
    
    [fetchRequest setRelationshipKeyPathsForPrefetching:[NSArray arrayWithObject:@"relatedCards"]];
    [fetchRequest setReturnsObjectsAsFaults:NO];
    // [fetchRequest setIncludesSubentities:YES];
    [fetchRequest setIncludesPropertyValues:YES];
    
    NSArray *temp = [[FlashCardsCore mainMOC] executeFetchRequest:fetchRequest error:nil];
    cardList = [[NSMutableArray alloc] initWithArray:temp];

    if (studyOrder == studyOrderLinear) {
        NSString *key = (showFirstSide == showFirstSideBack) ? @"backValue" : @"frontValue";
        NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:key
                                                                       ascending:YES
                                                                        selector:@selector(localizedCaseInsensitiveCompare:)];
        [cardList sortUsingDescriptors:@[sortDescriptor]];
    } else if (selectCards != selectCardsRandom) {
        // randomize the order of the cards
        // as per http://stackoverflow.com/a/56656/353137
        NSUInteger count = [cardList count];
        for (NSUInteger i = 0; i < count; ++i) {
            // select a random element between i and end of array to swap with
            NSInteger nElements = count - i;
            NSInteger n = (arc4random() % nElements) + i;
            [cardList exchangeObjectAtIndex:i withObjectAtIndex:n];
        }
    }
}

-(void)beginStudying:(id)sender {
    didBeginStudying = YES;
    if (studyOrder == studyOrderRandom) {
        [self randomizeStudyList];
    }
    if (studyOrder == studyOrderSmart) {
        // hide the card number label - we don't want the user to see that they are studying more
        // than the actual # of cards!!
        if (delegate && [delegate respondsToSelector:@selector(hideCardNumberLabel)]) {
            [delegate hideCardNumberLabel];
        }
        [self beginSmartStudying];
    }
    // self.title = (showFirstSide == showFirstSideBack) ? NSLocalizedStringFromTable(@"Back", @"Study", @"back of card") : NSLocalizedStringFromTable(@"Front", @"Study", @"front of card");
    if (delegate) {
        if ([delegate respondsToSelector:@selector(showPrevNextButton)]) {
            [delegate showPrevNextButton];
        }
        if (sender) {
            if ([delegate respondsToSelector:@selector(configureCard)]) {
                [delegate configureCard];
            }
        }
    }
    [self resetCurrentCardScore];
    if (!loadingCardsFromSavedState && (studyAlgorithm == studyAlgorithmLearn || studyAlgorithm == studyAlgorithmLapsed)) {
        // only save the cards to the collection if we aren't currently loading them:
        // (if we are loading them, this is redundant since it is the same information)
        [self saveCardListToCollection];
    }
}


-(void)beginSmartStudying {
    // with the smart algorithm, auto-populate the queue based on EFactor:
    CardTest *testCard;
    int queue;
    
    double queue2limit = 1.6;
    double queue1limit = 2.0;
    
    if (studyAlgorithm == studyAlgorithmLapsed) {
        queue2limit = 1.4;
        queue1limit = 1.8;
    }
    
    [self randomizeStudyList];
    for (int i = 0; i < [cardList count]; i++) {
        testCard = [cardList objectAtIndex:i];
        queue = 0;
        if (testCard.eFactor < queue2limit) {
            // queue(+2) all cards which are under E-Factor 1.6:
            queue = 2;
        } else if (testCard.eFactor < queue1limit) {
            // queue(+1) all cards which are under E-Factor 2.0:
            queue = 1;
        }
        for (int j = 0; j < queue; j++) {
            [self queueCardInStudyList:i];
        }
    }
}


-(void)beginTest:(id)sender {
    // Go through the cards and set isTest=YES
    CardTest *testCard;
    for (int i = 0; i < [cardList count]; i++) {
        testCard = [cardList objectAtIndex:i];
        testCard.isTest = YES;
    }
    [self resetStudyList];
    [self resetScores];
    currentCardIndex = 0;
    [self randomizeStudyList];
    if (studyAlgorithm != studyAlgorithmRepetition) {
        studyAlgorithm = studyAlgorithmTest;
    }
    delegate.studyBrowseMode = studyBrowseModeManual;
    if (delegate) {
        if ([delegate respondsToSelector:@selector(configurePausePlayAutoBrowseButton)]) {
            [delegate configurePausePlayAutoBrowseButton];
        }
        if (sender && [delegate respondsToSelector:@selector(configureCard)]) {
            [delegate configureCard];
        }
        if (sender && [delegate respondsToSelector:@selector(animateCard:)]) {
            [delegate animateCard:UIViewAnimationOptionTransitionCurlUp];
        }
    }
    [self resetCurrentCardScore];
}

-(int)numCardsWithScoresLessThan4 {
    int count = 0;
    CardTest *testCard;
    for (int i = 0; i < [cardList count]; i++) {
        testCard = [cardList objectAtIndex:i];
        // Count cards which are:
        // 1) NOT with no score (== 0), and
        // 2) score < 4 (they are not good enough), and
        // 3) which we have looked at (in the case that we prematurely looked at the results!)
        if (testCard.score > 0 && testCard.score < 4) {
            count++;
        }
    }
    return count;
}

-(void)studyCardsWithScoresLessThan4:(id)sender {
    // remove cards with scores 4 or 5:
    CardTest *testCard;
    for (int i = 0; i < [cardList count]; i++) {
        testCard = [cardList objectAtIndex:i];
        testCard.isTest = NO;
        // Remove cards which are:
        // 1) With no score (== 0), or
        // 2) score > 3 (they are good enough), or
        // 3) which we have not yet looked at (in the case that we prematurely looked at the results!)
        if (testCard.score == 0 || testCard.score > 3 || i > currentCardIndex) {
            [cardList removeObjectAtIndex:i];
            i--;
        } else {
            // copy the information from the card back to the CardTest object:
            testCard.currentIntervalCount = [testCard.card.currentIntervalCount intValue];
            testCard.isLapsed = [testCard.card.isLapsed boolValue];
            testCard.numLapses = [testCard.card.numLapses intValue];
        }
    }
    // re-create study list:
    [self resetStudyList];
    // reset the scores to 0:
    [self resetScores];
    // begin smart studying & randomize cards:
    [self beginSmartStudying];
    // set current round to 0:
    currentRound = 0;
    currentCardIndex = 0;
    studyAlgorithm = studyAlgorithmLearn;
    studyOrder = studyOrderSmart;
    
    if (delegate) {
        if ([delegate respondsToSelector:@selector(showPrevNextButton)]) {
            [delegate showPrevNextButton];
        }
        if ([delegate respondsToSelector:@selector(configureCard)]) {
            [delegate configureCard];
        }
        if ([delegate respondsToSelector:@selector(animateCard:)]) {
            [delegate animateCard:UIViewAnimationOptionTransitionCurlUp];
        }
    }
    [self resetCurrentCardScore];
}

-(void)nextRound {
    
    if (studyAlgorithm == studyAlgorithmRepetition) {
        // if we are in the review mode, then we don't want to go back to the
        // beginning of the next round. We are in this position because we are viewing
        // the results! Thus we should allow the user to view the options to leave the
        // study session?
        if (delegate && [delegate respondsToSelector:@selector(doneEvent)]) {
            delegate.forceDisplayResultsPrompt = YES; // force it to display the results prompt
            delegate.allowLeavingWithoutResultsPrompt = NO; // force the delegate to show the popup
            [delegate doneEvent];
            return;
        }
    }

    currentRound++;
    currentCardIndex = 0;
    // self.title = (showFirstSide == showFirstSideBack) ? @"Back" : @"Front";
    
    double studyScore = ((double)[studyList count] / (double)[cardList count]);
    if (studyOrder == studyOrderSmart && studyScore == 1.0f) {
        [self randomizeStudyList];
    }
    
    // forget which side of each card was shown, if random
    for (NSNumber *_studyListLocation in studyList) {
        int studyListLocation = [_studyListLocation intValue];
        ((CardTest*)[cardList objectAtIndex:studyListLocation]).showSide = -1;
    }
    
    [self resetScores];
    if (delegate) {
        if ([delegate respondsToSelector:@selector(configureCard)]) {
            [delegate configureCard];
        }
        if ([delegate respondsToSelector:@selector(animateCard:)]) {
            [delegate animateCard:UIViewAnimationOptionTransitionCurlUp];
        }
        if ([delegate respondsToSelector:@selector(studyBrowseMode)] &&
            [delegate respondsToSelector:@selector(studyBrowseModePaused)]) {
            if ([delegate studyBrowseMode] != studyBrowseModeManual && [delegate studyBrowseModePaused]) {
                [delegate performSelector:@selector(pausePlayAutoBrowse:) withObject:nil];
            }

        }
    }
    [self setCurrentCardScore];
}


-(void)nextCard {
    // CardTest *testCard;
    if (currentCardIndex < [self numCards]) {
        [self saveScore];
    }
    
    
    currentCardIndex++;
    if (currentCardIndex == [self numCards]) {
        // If it is equal, then display the results:
        if (delegate && [delegate respondsToSelector:@selector(displayResults:animated:)]) {
            [delegate displayResults:nil animated:YES];
        }
        return;
    } else if (currentCardIndex > [self numCards]) {
        // we are currently viewing the results, and are going to the next round.
        if (studyAlgorithm == studyAlgorithmRepetition) {
            // if we are in the review mode, then we don't want to go back to the
            // beginning of the next round. We are in this position because we are viewing
            // the results! Thus we should allow the user to view the options to leave the
            // study session?
            if (delegate && [delegate respondsToSelector:@selector(doneEvent)]) {
                delegate.forceDisplayResultsPrompt = YES; // force it to display the results prompt
                delegate.allowLeavingWithoutResultsPrompt = NO; // force the delegate to show the popup
                [delegate doneEvent];
                return;
            }
        }
        currentRound++;
        currentCardIndex = 0;
        [self resetScores];
    }
    
    if (currentCardIndex > 0) {
        // force the delegate to show the popup
        delegate.allowLeavingWithoutResultsPrompt = NO;
    }
    delegate.forceDisplayResultsPrompt = NO; // don't force it to display the results prompt
    
    delegate.cardTestIsChanged = NO;
    if (delegate) {
        if ([delegate respondsToSelector:@selector(configureCard)]) {
            [delegate configureCard];
        }
    }
    [self resetCurrentCardScore];
    if (delegate && [delegate respondsToSelector:@selector(animateCard:)]) {
        [delegate animateCard:UIViewAnimationOptionTransitionCurlUp];
    }
    [[self currentCard] incrementStudyPause:0.60];
}

-(void)prevCard {
    [self saveScore];
    currentCardIndex--;
    // If we are at the very beginning of the study loop, do nothing:
    if (currentCardIndex < 0) {
        if (![self studyAlgorithmIsLearning] || currentRound == 0) {
            currentCardIndex = 0;
            return;
        } else {
            // if we are past the first round, then go back to the results page by setting the index to the # cards:
            currentCardIndex = [self numCards];
        }
    }
    if (currentCardIndex == [self numCards]) {
        currentRound--;
        // Display results:
        if (delegate && [delegate respondsToSelector:@selector(displayResults:animated:)]) {
            [delegate displayResults:nil animated:YES];
        }
        return;
    }
    
    delegate.cardTestIsChanged = NO;
    if (delegate && [delegate respondsToSelector:@selector(configureCard)]) {
        [delegate configureCard];
    }
    [self setCurrentCardScore];
    if (delegate && [delegate respondsToSelector:@selector(animateCard:)]) {
        [delegate animateCard:UIViewAnimationOptionTransitionCurlDown];
    }
}


-(void)randomizeCards {
    // Based on http://en.wikipedia.org/wiki/Fisher%E2%80%93Yates_shuffle#The_modern_algorithm
    int j;
    // we are now going to randomize the cards - not the Study List!
    for (int i = (int)[cardList count]-1; i > 0; i--) {
        j = arc4random() % i;
        [cardList exchangeObjectAtIndex:i withObjectAtIndex:j];
    }
}
-(void)randomizeStudyList {
    // Based on http://en.wikipedia.org/wiki/Fisher%E2%80%93Yates_shuffle#The_modern_algorithm
    int j;
    // we are now going to randomize the Study List - not the cards themselves!
    for (int i = (int)[studyList count]-1; i > 0; i--) {
        j = arc4random() % i;
        [studyList exchangeObjectAtIndex:i withObjectAtIndex:j];
    }
}

# pragma mark -
# pragma mark Card utility functions

-(int)numCards {
    if ([studyList count] == 0) {
        return (int)[cardList count];
    }
    return (int)[studyList count];
}

-(void)printStudyListFronts {
    CardTest *test;
    for (int i = 0; i < [studyList count]; i++) {
        test = [self getCard:i];
        NSLog(@"%d: %@", i, test.card.frontValue);
    }
}

-(void)printCardListFronts {
    CardTest *test;
    for (int i = 0; i < [cardList count]; i++) {
        test = [cardList objectAtIndex:i];
        NSLog(@"%d: %@", i, test.card.frontValue);
    }
}

-(void)removeCardFromStudy:(FCCard *)card {
    NSMutableSet *locations = [[NSMutableSet alloc] initWithCapacity:0];
    CardTest *test;
#ifdef DEBUG
    NSLog(@"\n\nBEFORE:\n");
    [self printStudyListFronts];
#endif
    for (int i = (int)[studyList count]-1; i >= 0; i--) {
        test = [self getCard:i];
        if ([[test card] isEqual:card]) {
            [locations addObject:[studyList objectAtIndex:i]];
            [studyList removeObjectAtIndex:i];
            
            // if the studyList location (NOT where it refers to in cardList, but in the studyList itself -- "i")
            // is less than currentCardIndex, we need to deincrement currentCardIndex, in order to match
            // the new location since everything past this will deincrement. HOWEVER, if it currentCardIndex
            // is EQUAL to i, then it doesn't matter - this is the card we are deleting.
            
            if (i < currentCardIndex) {
                currentCardIndex--;
            }
            
        }
    }
#ifdef DEBUG
    NSLog(@"\n\nAFTER:\n");
    [self printStudyListFronts];
    NSLog(@"Locations: %@", locations);
#endif
    NSArray *locationsSorted = [[locations allObjects] sortedArrayUsingComparator:(NSComparator)^(id obj1, id obj2){
        int int1 = [(NSNumber*)obj1 intValue];
        int int2 = [(NSNumber*)obj2 intValue];
        if (int1 == int2) {
            return NSOrderedSame;
        } else if (int1 < int2) {
            return NSOrderedAscending;
        } else {
            return NSOrderedDescending;
        }
    }];
    int location, studyListLocation;
#ifdef DEBUG
    NSLog(@"\n\nBEFORE:\n");
    [self printCardListFronts];
#endif
    for (int i = (int)[locationsSorted count]-1; i >= 0; i--) {
        location = [[locationsSorted objectAtIndex:i] intValue];
        [cardList removeObjectAtIndex:[[locationsSorted objectAtIndex:i] intValue]];
        
        // any studyList items which have a counter ABOVE the location need to be deincremented,
        // otherwise they will refer to the wrong items, since by removing the item from the cardList,
        // we are deincrementing the numbers of all of the objects behind it in the cardList.
        for (int j = 0; j < [studyList count]; j++) {
            studyListLocation = [[studyList objectAtIndex:j] intValue];
            if (studyListLocation >= location) {
                [studyList replaceObjectAtIndex:j withObject:[NSNumber numberWithInt:studyListLocation-1]];
            }
        }
    }
#ifdef DEBUG
    NSLog(@"\n\nAFTER:\n");
    [self printCardListFronts];
#endif
    if (delegate) {
        if ([delegate respondsToSelector:@selector(showBackView:)]) {
            [delegate showBackView:NO];
        }
        if ([self numCards] == 0 && [delegate respondsToSelector:@selector(showNoCardsAlert)]) {
            [delegate showNoCardsAlert];
        }
        if ([delegate respondsToSelector:@selector(configureCard)]) {
            [delegate configureCard];
        }
    }
}

-(CardTest*)currentCard {
    if (currentCardIndex >= [studyList count]) {
        return nil;
    }
    return [self getCard:(int)currentCardIndex];
}

-(CardTest*)getCard:(int)cardIndex {
    cardIndex = [[studyList objectAtIndex:cardIndex] intValue];
    return [cardList objectAtIndex:cardIndex];
}

-(void)resetStudyList {
    // if studyOrder = studyOrderCustom, then sort by cardOrder:
    if (studyOrder == studyOrderCustom) {
        [cardList sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            CardTest *card1 = (CardTest*)obj1;
            CardTest *card2 = (CardTest*)obj2;
            if (card1.cardOrder > card2.cardOrder) {
                return (NSComparisonResult) NSOrderedDescending;
            }
            if (card1.cardOrder < card2.cardOrder) {
                return (NSComparisonResult) NSOrderedAscending;
            }
            
         return (NSComparisonResult) NSOrderedSame;
        }];
    }
    // add each item to the study list
    studyList = [[NSMutableArray alloc] initWithCapacity:0];
    for (int n = 0; n < [cardList count]; n++) {
        ((CardTest*)[cardList objectAtIndex:n]).studyCount = 1; // increment the number of times it is in the study list
        [studyList addObject:[NSNumber numberWithInt:n]];
    }    
}

-(void)queueCardInStudyList:(int)cardListIndex {

#ifdef DEBUG
    // NSLog(@"\n\nBEFORE QUEUE:\n");
    // [self printStudyListFronts];
#endif
    CardTest *testCard = [cardList objectAtIndex:cardListIndex];
    // Only queue additional cards if they are less than 1/3 of the total number studied
    if (testCard.studyCount >= floor([self numCards] / 3)) {
        return;
    }
    testCard.studyCount++;
    int random;
    int cardAdjacentId;
    CardTest *testCardAdjacent;
    
    /*
     Algorithm creates three lists:
     (a) list of "ideal" slots for card, i.e. neither card next to it is equal to inserted card or related to it
     (b) list of "OK" slots for card, i.e. neither card next ot it is equal, but one is related
     (c) list of all potential slots (i.e. studyList)
     If the first list is blank, then try to find a spot in the second list, and if that is blank, just pick a random
     spot in the third list.
     
     Algorithm: Go through each slot in the studyList (list of cards to be studied). Find out which lists the spot would
     fit into, and then pick one of the items randomly.
     */
    
    NSMutableArray *idealInsertionSlots = [[NSMutableArray alloc] initWithCapacity:0];
    NSMutableArray *okInsertionSlots = [[NSMutableArray alloc] initWithCapacity:0];
    
    BOOL neitherSideEqualsCard, neitherSideRelatedToCard;
    
    for (int i = 0; i < [self numCards]; i++) {
        neitherSideEqualsCard = NO;
        neitherSideRelatedToCard = NO;
        
        random = i;
        if (random == 0) {
            cardAdjacentId = [[studyList objectAtIndex:0] intValue];
            testCardAdjacent = [cardList objectAtIndex:cardAdjacentId];
            // if we want to put it at the beginning, then check if the first item is equal to the item to add:
            if (cardAdjacentId == cardListIndex) {
                neitherSideEqualsCard = NO;
            } else {
                neitherSideEqualsCard = YES;
                if ([testCardAdjacent.card.relatedCards containsObject:testCard.card]) {
                    neitherSideRelatedToCard = YES;
                }
            }
        } else if (random == ([self numCards]-1)) {
            // if we are looking at the last item, then check to see if the last item is equal to the item to add:
            cardAdjacentId = [[studyList objectAtIndex:([studyList count]-1)] intValue];
            testCardAdjacent = [cardList objectAtIndex:cardAdjacentId];
            if (cardAdjacentId == cardListIndex) {
                neitherSideEqualsCard = NO;
            } else {
                neitherSideEqualsCard = YES;
                if ([testCardAdjacent.card.relatedCards containsObject:testCard.card]) {
                    neitherSideRelatedToCard = NO;
                }
            }
            // otherwise, we are looking somewhere in the middle--check to see if the item which will be after it
            // is equal to the item to add:
        } else if ([[studyList objectAtIndex:random] intValue] == cardListIndex) {
            neitherSideEqualsCard = NO;
        } else if ([[studyList objectAtIndex:(random-1)] intValue] == cardListIndex) {
            // note - we know that this is within the range of objects because we already tried when random == 0
            // thus, random must be greater than 0 - and then random-1 > 0, thus it is available.
            neitherSideEqualsCard = NO;
        } else {
            neitherSideEqualsCard = YES;
            cardAdjacentId = [[studyList objectAtIndex:random] intValue];
            testCardAdjacent = [cardList objectAtIndex:cardAdjacentId];
            if ([testCardAdjacent.card.relatedCards containsObject:testCard.card]) {
                neitherSideRelatedToCard = NO;
            } else {
                cardAdjacentId = [[studyList objectAtIndex:(random-1)] intValue];
                testCardAdjacent = [cardList objectAtIndex:cardAdjacentId];
                if ([testCardAdjacent.card.relatedCards containsObject:testCard.card]) {
                    neitherSideRelatedToCard = NO;
                } else {
                    neitherSideRelatedToCard = YES;
                }
            }
        }
        
        
        if (neitherSideEqualsCard) {
            [okInsertionSlots addObject:[NSNumber numberWithInt:i]];
            if (neitherSideRelatedToCard) {
                [idealInsertionSlots addObject:[NSNumber numberWithInt:i]];
            }
        }
    }
    
    
    if ([idealInsertionSlots count] > 0) {
        // there are some ideal insertion slots -- pick one of them
        random = arc4random() % [idealInsertionSlots count];
        random = [[idealInsertionSlots objectAtIndex:random] intValue];
    } else if ([okInsertionSlots count] > 0) {
        // there are no ideal insertion slots, but there are some OK ones
        random = arc4random() % [okInsertionSlots count];
        random = [[okInsertionSlots objectAtIndex:random] intValue];
    } else {
        // there are no good slots at all! Don't insert the card:
        return;
    }
    
    // 2. add the card at that location
    // check to make sure that the items on both sides are not 
    [studyList insertObject:[NSNumber numberWithInt:cardListIndex] atIndex:random];
    // 3. If it is before the current card count, reduce the current card count by 1
    if (random <= currentCardIndex) {
        currentCardIndex++;
    }
    
    
#ifdef DEBUG
    // NSLog(@"\n\nAFTER QUEUE:\n");
    // [self printStudyListFronts];
#endif
    
}

-(void)dequeueCardInStudyList:(int)cardListIndex {
    
#ifdef DEBUG
    // NSLog(@"\n\nBEFORE DEQUEUE:\n");
    // [self printStudyListFronts];
#endif
    CardTest *testCard = [cardList objectAtIndex:cardListIndex];
    
    // only dequeue a card from the study list if it is there more than once
    if (testCard.studyCount <= 1) {
        return;
    }
    testCard.studyCount--;
    
    // 1. Find all instances
    NSMutableArray *cardInstances = [[NSMutableArray alloc] initWithCapacity:0];
    NSMutableArray *bothSidesClearCardInstances = [[NSMutableArray alloc] initWithCapacity:0];
    int cardLocation;
    int prevValue, nextValue;
    BOOL bothSidesClear;
    CardTest *prevCardTest;
    CardTest *nextCardTest;
    for (int i = 0; i < [self numCards]; i++) {
        
        // make sure not to dequeue the card we are currently working on:
        if (i == currentCardIndex) {
            continue;
        }
        
        // find all instances where the card we are dequeueing is found:
        if ([[studyList objectAtIndex:i] intValue] == cardListIndex) {
            // bothSidesClear = NO; // reset bothSidesClear to NO for each item.
            // we used to set bothSidesClear (^^^), but if we look below, in every
            // control statement case, bothSidesClear is set to some other value (vvv)
            
            [cardInstances addObject:[NSNumber numberWithInt:i]];
            // Check to see if both sides are clear; the idea is that we will TRY
            // to pick a location to remove which is a member of this list but if it's
            // empty then we'll pick one from the cardInstances list.
            cardLocation = i;
            if (cardLocation == ([studyList count]-1)) {
                // if we are looking at the last location. It shouldn't matter what the next card is.
                bothSidesClear = YES;
            } else if (cardLocation == 0) {
                // if we are looking at the first location. It shouldn't matter what the next card is
                bothSidesClear = YES;
            } else {
                // we are somewhere in the middle, and there are two sides to compare:
                prevValue = [[studyList objectAtIndex:(cardLocation-1)] intValue];
                nextValue = [[studyList objectAtIndex:(cardLocation+1)] intValue];
                prevCardTest = [cardList objectAtIndex:prevValue];
                nextCardTest = [cardList objectAtIndex:nextValue];
                if (nextValue == prevValue) {
                    // if both the prev & next cards are the SAME, it is not OK to remove the card
                    // in the middle:
                    bothSidesClear = NO;
                } else if ([prevCardTest.card.relatedCards containsObject:nextCardTest.card]) {
                    // if the prev & next cards are RELATED, then it is also not OK to remove the card
                    // in the middle:
                    bothSidesClear = NO;
                } else {
                    bothSidesClear = YES;
                }
            }
            if (bothSidesClear) {
                [bothSidesClearCardInstances addObject:[NSNumber numberWithInt:i]];
            }
        }
    }
    
    // if it isn't to be found - get out of here!!!
    if ([cardInstances count] == 0) {
        return;
    }
    
    // 2. Randomly pick one
    int random;
    
    if ([bothSidesClearCardInstances count] > 0) {
        random = arc4random() % ((int)[bothSidesClearCardInstances count]);
        cardLocation = [[bothSidesClearCardInstances objectAtIndex:random] intValue];
    } else {
        random = arc4random() % ((int)[cardInstances count]);
        cardLocation = [[cardInstances objectAtIndex:random] intValue];
    }
    
    // 3. Remove it
    [studyList removeObjectAtIndex:cardLocation];
    
    // 3. If it is before the current card count, reduce the current card count by 1
    
    if (cardLocation <= currentCardIndex) {
        currentCardIndex--;
    }
#ifdef DEBUG
    // NSLog(@"\n\nAFTER DEQUEUE:\n");
    // [self printStudyListFronts];
#endif

}

-(void)translateCardsToCardTests {
    // Translate the cardList items in CardTest items:
    for (int m = 0; m < [cardList count]; m++) {
        CardTest *testCard = [[CardTest alloc] init];
        testCard.card = [cardList objectAtIndex:m];
        testCard.collection = testCard.card.collection;
        
        testCard.isLapsed = [testCard.card.isLapsed boolValue];
        testCard.numLapses = [testCard.card.numLapses intValue];
        testCard.currentIntervalCount = [testCard.card.currentIntervalCount intValue];
        testCard.eFactor = [testCard.card.eFactor doubleValue];
        testCard.lastRepetitionDate = testCard.card.lastRepetitionDate;
        testCard.nextRepetitionDate = testCard.card.nextRepetitionDate;
        testCard.lastIntervalOptimalFactor = [testCard.card.lastIntervalOptimalFactor doubleValue];
        
        if (studyAlgorithm == studyAlgorithmTest || studyAlgorithm == studyAlgorithmRepetition) {
            testCard.isTest = YES;
        }
        if (studyOrder == studyOrderCustom && self.delegate.cardSet) {
            for (FCCardSetCard *order in [testCard.card cardSetOrdered]) {
                if ([[order cardSet] isEqual:self.delegate.cardSet]) {
                    testCard.cardOrder = [[order cardOrder] intValue];
                    break;
                }
            }
        }
        [cardList replaceObjectAtIndex:m withObject:testCard];
        // [cardList addObject:testCard];
    }
    [self resetStudyList];
    cardListIsTranslated = YES;
}

-(BOOL)studyAlgorithmIsLearning {
    return (studyAlgorithm == studyAlgorithmLearn || studyAlgorithm == studyAlgorithmLapsed);
}

-(BOOL)studyAlgorithmIsTest {
    return (studyAlgorithm == studyAlgorithmTest || studyAlgorithm == studyAlgorithmRepetition);
}


# pragma mark -
# pragma mark Scoring functions

-(void)resetCurrentCardScore {
    if (delegate && [delegate respondsToSelector:@selector(setScore:)]) {
        [delegate setScore:0];
    }
}

-(void)setCurrentCardScore {
    CardTest *testCard = [self currentCard];
    if (delegate && [delegate respondsToSelector:@selector(setScore:)]) {
        [delegate setScore:testCard.score];
    }
}

-(void)resetScores {
    for (int i = 0; i < [cardList count]; i++) {
        ((CardTest*)[cardList objectAtIndex:i]).score = 0;
    }
}

-(void)saveScore {
    if (!delegate.cardTestIsChanged) {
        return;
    }
    
    if (!delegate) {
        return;
    }
    if (![delegate respondsToSelector:@selector(resultsDisplayed)] ||
        ![delegate respondsToSelector:@selector(getScore)]) {
        return;
    }
    
    // Don't save the score if you are looking at the results
    if ([delegate resultsDisplayed]) {
        return;
    }
    
    int score = (double)[delegate getScore];
    CardTest *testCard = [self currentCard];
    
#ifdef DEBUG
    NSLog(@"\n\n\n%@ (Score: %d)\n----\n", testCard.card.frontValue, score);
#endif
    
    NSMutableDictionary *ofMatrixLocation;
    
    double eFactor;
    double nearOptimalInterval;
    double optimalFactor;
    double currentOFValue, newOFValue;
    int timeInterval;
    double lastInterval = 0.0;
    int colNumber;
    double randomValue;
    double factor;
    
    testCard.score = score;
    
    // we want the repetition time in milliseconds:
    double repetitionTime = [[NSDate date] timeIntervalSince1970] - [testCard.studyBegan timeIntervalSince1970];
    repetitionTime -= testCard.studyPauseLength;
    FCLog(@"Time: %1.2f", repetitionTime);
    // Adjust the card's streak count:
    if (score >= 3) {
        testCard.correctStreakCount++;
    } else {
        testCard.correctStreakCount = 0;
    }
    // If it is the smart study algorithm, then queue or dequeue the item based on a scoring method:
    if (studyOrder == studyOrderSmart && !testCard.isTest) {
        int cardIndex = [[studyList objectAtIndex:currentCardIndex] intValue];
        if (score == 5) {
            if (testCard.correctStreakCount > 3) {
                [self dequeueCardInStudyList:cardIndex];
            }
            [self dequeueCardInStudyList:cardIndex];
            [self dequeueCardInStudyList:cardIndex];
        } else if (score >= 3) {
            // answer was correct
            if (testCard.correctStreakCount > 4) {
                [self dequeueCardInStudyList:cardIndex];
                [self dequeueCardInStudyList:cardIndex];
                [self dequeueCardInStudyList:cardIndex];
            } else if (testCard.correctStreakCount > 3) {
                [self dequeueCardInStudyList:cardIndex];
                [self dequeueCardInStudyList:cardIndex];
            } else if (testCard.correctStreakCount > 2 || testCard.correctStreakCount > testCard.studyCount) {
                [self dequeueCardInStudyList:cardIndex];
            }
        } else if (score == 2) {
            // answer was incorrect
            [self queueCardInStudyList:cardIndex];
        } else if (score == 1) {
            // answer was totally wrong!
            [self queueCardInStudyList:cardIndex];
            [self queueCardInStudyList:cardIndex];
        }
    }
    
    if (score > 0) {
        // ALWAYS update the card's e-factor.
        double adjustedScore = (double)score;
        if ([self studyAlgorithmIsTest] && score == 4) {
            if (repetitionTime < 1) {
                adjustedScore += 0.5;
            } else if (repetitionTime < 2) {
                adjustedScore += 0.3;
            } else if (repetitionTime < 3) {
                adjustedScore += 0.2;
            } else if (repetitionTime > 10) { 
                adjustedScore -= 0.2;
            } else if (repetitionTime > 15) {
                adjustedScore -= 0.3;
            }
        }
        eFactor = [SMCore calcEFactor:adjustedScore oldEFactor:testCard.eFactor];
        FCLog(@"Original Score: %1.2f", (double)score);
        FCLog(@"Adjusted Score: %1.2f", adjustedScore);
        FCLog(@"Old eFactor: %1.2f", testCard.eFactor);
        FCLog(@"New/Org eFactor: %1.2f", [SMCore calcEFactor:(double)score oldEFactor:testCard.eFactor]);
        FCLog(@"New/Adj eFactor: %1.2f", eFactor);
        FCLog(@" ");
        
        // Step 6: update the card's efactor
        if (eFactor != testCard.eFactor) {
            testCard.eFactorChanged = YES;
        }
        testCard.eFactor = eFactor;
        // don't save the eFactor until the very end, if the eFactor changed
        // testCard.card.eFactor = [NSNumber numberWithDouble:eFactor];
        
        if (testCard.isTest) {
            
            if ([FCMatrix numRows:ofMatrix] - testCard.currentIntervalCount < 5) {
                // if we are within 5 intervals of the end of the OF-Matrix, then we should add a bunch of rows to the matrix:
                for (int i = 0; i < 7; i++) {
                    [FCMatrix duplicateLastRow:ofMatrix];
                    [FCMatrix duplicateLastRow:ofMatrixAdjusted];
                }
                ofMatrixChanged = YES;
            }
            
            if (score >= 3) {
                // Update the card's basic information:
                testCard.card.isSpacedRepetition = [NSNumber numberWithBool:YES];
                testCard.card.currentIntervalCount = [NSNumber numberWithInt:(testCard.currentIntervalCount+1)];
                testCard.card.isLapsed = [NSNumber numberWithBool:NO];
                
                // Calculate the last interval
                lastInterval = ([[NSDate date] timeIntervalSinceDate:testCard.lastRepetitionDate]) / 60 / 60 / 24;
                
                // Calculate the optimum interval, and update the next interval
                
                optimalFactor = [SMCore optimalFactor:ofMatrix interval:testCard.currentIntervalCount eFactor:[testCard.card.eFactor doubleValue]];
                if (isnan(optimalFactor)) {
                    optimalFactor = 2.0f;
                }
                // If it is the first interval, then don't calculate a near-optimal interval:
                if (testCard.currentIntervalCount == 0) {
                    randomValue = [SMCore calcRandomNum];
                    factor = ((double)score - 2) / 4; // this factor will ensure that items with higher scores receive longer repetition times, but nothing gets the lowest repetition time
                    nearOptimalInterval = optimalFactor * (1 + ((randomValue / 100) * factor));
                } else {
                    // If it has a previous interval, then I will calculate a "near-optimal interval"
                    nearOptimalInterval = [SMCore nearOptimalInterval:nil previousInterval:lastInterval optimalFactor:optimalFactor];
                }
                if (isnan(nearOptimalInterval)) {
                    nearOptimalInterval = 1.5f;
                }
                timeInterval = nearOptimalInterval * (60*60*24);
                testCard.card.nextRepetitionDate = [NSDate dateWithTimeIntervalSinceNow:timeInterval];
#ifdef DEBUG
                NSLog(@"Next repetition: %@", testCard.card.nextRepetitionDate);
#endif
                // set the last repetition date to now so that when we do the card again, we can calculate the last interval:
                testCard.card.lastRepetitionDate = [NSDate date];
                
                // track data for the next time we want to re-calculate the optimal factors:
                testCard.card.lastIntervalOptimalFactor = [NSNumber numberWithDouble:optimalFactor];
                
            } else {
                // Undo anything that we just did by resetting the values to what we had before.
                if (studyAlgorithm == studyAlgorithmTest) {
                    testCard.card.isSpacedRepetition = [NSNumber numberWithBool:NO];
                    testCard.card.currentIntervalCount = [NSNumber numberWithInt:testCard.currentIntervalCount];
                    testCard.card.numLapses = [NSNumber numberWithInt:testCard.numLapses];
                    testCard.card.isLapsed = [NSNumber numberWithBool:testCard.isLapsed];
                } else if (studyAlgorithm == studyAlgorithmRepetition) {
                    // If we are studying with repetition, then set the interval back to 1.
                    if (testCard.card.isSpacedRepetition) {
                        testCard.card.currentIntervalCount = [NSNumber numberWithInt:0];
                        testCard.card.isSpacedRepetition = [NSNumber numberWithBool:NO];
                        testCard.card.isLapsed = [NSNumber numberWithBool:YES];
                        testCard.card.numLapses = [NSNumber numberWithInt:(testCard.numLapses+1)];
                    }
                }
            }
            
            // Step 7: Update the O-Factor Matrix for the O-Factor we used last time to calculate the last Optimal Interval:
            // Only can calculate this if it is not the first time we are calculating the intervals!!
            if (testCard.currentIntervalCount > 0) {
                
                // 1. Create a location space where we will update the O-Factor matrix 
                int yInterval = (int)(testCard.currentIntervalCount)-1;
                colNumber = [SMCore calcColNum:[SMCore roundEFactor:testCard.eFactor]];
                ofMatrixLocation = [FCMatrix locationDictionary:nil x:colNumber y:yInterval];
                // 2. Find out what is currently in the space:
                currentOFValue = [[FCMatrix getValueAtLocation:ofMatrixLocation matrix:ofMatrix] doubleValue];
                // 3. Calculate the new value:
                newOFValue = [SMCore calcNewOptimalFactor:nil intervalUsed:lastInterval lastOptimalFactor:currentOFValue usedOptimalFactor:testCard.lastIntervalOptimalFactor quality:score];
                FCLog(@"Current OF - %1.2f; New OF - %1.2f", currentOFValue, newOFValue);
                [FCMatrix setValueAtLocation:ofMatrixLocation value:[NSNumber numberWithDouble:newOFValue] matrix:ofMatrix];
                // 4. Mark that we have adjusted this O-Factor value:
                [FCMatrix setValueAtLocation:ofMatrixLocation value:[NSNumber numberWithInt:1] matrix:ofMatrixAdjusted];
                
                // 5. Adjust all of the non-adjusted O-Matrix values:
                
                [SMCore propagateOFMatrixChanges:ofMatrix ofMatrixAdjusted:[FCMatrix initWithMatrix:ofMatrixAdjusted] startLocation:ofMatrixLocation];
                
                // 6. Save the changes!!
                // we will save changes at the ****end**** of the study session!
                ofMatrixChanged = YES;
            }
            
            
            // If we are not doing the initial test, then save the specific repetition information:
            if (testCard.currentIntervalCount > 0) {
                if (!testCard.testRepetition) {
                    // if we don't have a test repetition yet, create one:
                    // this will happen every time unless we go back to re-do a previous card.
                    testCard.testRepetition = (FCCardRepetition *)[NSEntityDescription
                                                                 insertNewObjectForEntityForName:@"CardRepetition"
                                                                          inManagedObjectContext:[FlashCardsCore mainMOC]];
                    
                    // set the reciprocal relationship btwn. the card & the repetition
                    [testCard.card addRepetitionsObject:testCard.testRepetition];
                    [testCard.testRepetition setCard:testCard.card];
                    
                    // increment the # of repetitions in the collection:
                    // (we do it here since this only is done the first time that we study the card,
                    // if we return to redo it then we won't re-increment the variable)
                    if (numCases >= 0) {
                        numCases++;
                        numCasesChanged = YES;
                    }
                }
                
                [testCard.testRepetition setEFactor:[NSNumber numberWithDouble:testCard.eFactor]];
                [testCard.testRepetition setDate:[NSDate date]];
                [testCard.testRepetition setDateScheduled:testCard.nextRepetitionDate]; // the date when the repetition was scheduled to be tested, allows us to figure out how long it was delayed
                if (!testCard.testRepetition.dateScheduled) {
                    [testCard.testRepetition setDateScheduled:[NSDate date]];
                }
                [testCard.testRepetition setRepetitionTime:[NSNumber numberWithInt:repetitionTime]]; // how long the repetition took - seconds
                [testCard.testRepetition setRepetitionNumber:[NSNumber numberWithInt:testCard.currentIntervalCount]]; // the number interval we were on
                [testCard.testRepetition setScore:[NSNumber numberWithInt:testCard.score]]; // the score
                [testCard.testRepetition setLastRepetitionDate:testCard.lastRepetitionDate];
                if (!testCard.testRepetition.lastRepetitionDate) {
                    [testCard.testRepetition setLastRepetitionDate:[NSDate date]];
                }
                [testCard.testRepetition setNextRepetitionDate:testCard.card.nextRepetitionDate];
                if (!testCard.testRepetition.nextRepetitionDate) {
                    [testCard.testRepetition setNextRepetitionDate:[NSDate date]];
                }
            }
            
        }
        [FlashCardsCore saveMainMOC:NO];
    }
    
    // clear out the testcard's timer information:
    testCard.studyBegan = nil;
    testCard.studyPauseLength = 0.0;
}

# pragma mark -
# pragma mark Test results functions

-(double)percentSkipped {
    int numSkipped = 0;
    int numScored = 0;
    // go through the actual cards - not the abstracted studyList:
    if ([cardList count] > 0) {
        CardTest *testCard;
        for (int i = 0; i < [cardList count]; i++) {
            testCard = [self getCard:i];
            // find percentage of *all* cards passed, not just the ones tested.
            if (i >= currentCardIndex) {
                break;
            }
            numScored++;
            if (testCard.score == 0) {
                numSkipped++;
            }
        }
    }
    if (numScored == 0) {
        return -1;
    } else {
        // due to NSNumberFormatter, don't need to multiple by 100. Wants a fraction!
        return (double)(((double)numSkipped / (double)numScored));
    }
}

-(double)percentPassed {
    int numPassed = 0;
    int numScored = 0;
    // go through the actual cards - not the abstracted studyList:
    if ([cardList count] > 0) {
        CardTest *testCard;
        for (int i = 0; i < [cardList count]; i++) {
            testCard = [self getCard:i];
            // find percentage of *all* cards passed, not just the ones tested.
            if (i >= currentCardIndex) {
                break;
            }
            numScored++;
            if (testCard.score >= 3) {
                numPassed++;
            }
        }
    }
    if (numScored == 0) {
        return -1;
    } else {
        // due to NSNumberFormatter, don't need to multiple by 100. Wants a fraction!
        return (double)(((double)numPassed / (double)numScored));
    }
}

-(double)averageNextInterval {
    int totalIntervals = 0;
    int numScored = 0;
    
    // go through the actual cards - not the abstracted studyList:
    CardTest *testCard;
    for (int i = 0; i < [cardList count]; i++) {
        testCard = (CardTest*)[cardList objectAtIndex:i];
        // only do this if it passed:
        if (testCard.score >= 3) {
            numScored++;
            totalIntervals += [testCard.card.nextRepetitionDate timeIntervalSinceDate:testCard.card.lastRepetitionDate];
        } 
    }
    if (numScored == 0) {
        return -1;
    } else {
        return totalIntervals / numScored;
    }
}

-(NSString*)formatInterval:(double)avgNextInterval {
    int avgNextIntervalHours, avgNextIntervalTotalDays, avgNextIntervalDays, avgNextIntervalMonths;
    avgNextInterval /= 60; // turn it into minutes
    if (avgNextInterval < 60) {
        return [NSString stringWithFormat:FCPluralLocalizedStringFromTable(@"%d minutes", @"Plural", @"", [NSNumber numberWithDouble:avgNextInterval]), [[NSNumber numberWithDouble:avgNextInterval] intValue]];
    } else {
        avgNextInterval /= 60; // turn it into hours
        if (avgNextInterval < 24) {
            return [NSString stringWithFormat:FCPluralLocalizedStringFromTable(@"%1.2f hours", @"Plural", @"", [NSNumber numberWithDouble:avgNextInterval]), avgNextInterval]; 
        } else {
            avgNextInterval = floor(avgNextInterval); // turn it into a flat # of hours
            avgNextIntervalHours = (int)avgNextInterval % 24;
            avgNextIntervalTotalDays = (avgNextInterval - avgNextIntervalHours) / 24;
            avgNextIntervalMonths = (avgNextIntervalTotalDays - (avgNextIntervalTotalDays % 30)) / 30;
            avgNextIntervalDays = avgNextIntervalTotalDays % 30;
            NSString *avgDays =        [NSString stringWithFormat:FCPluralLocalizedStringFromTable(@"%d days", @"Plural", @"", [NSNumber numberWithInt:avgNextIntervalDays]), avgNextIntervalDays];
            NSString *avgMonths =    [NSString stringWithFormat:FCPluralLocalizedStringFromTable(@"%d months", @"Plural", @"", [NSNumber numberWithInt:avgNextIntervalMonths]), avgNextIntervalMonths];
            NSString *avgHours =    [NSString stringWithFormat:FCPluralLocalizedStringFromTable(@"%d hours", @"Plural", @"", [NSNumber numberWithInt:avgNextIntervalHours]), avgNextIntervalHours];
            if (avgNextIntervalMonths > 0) {
                return [NSString stringWithFormat:@"%@, %@", avgMonths, avgDays];
            } else if (avgNextIntervalHours == 0) {
                return avgDays;
            } else {
                return [NSString stringWithFormat:@"%@, %@", avgDays, avgHours];
            }
        }
    }
}

-(double)averageScore {
    if ([cardList count] == 0) {
        return -1;
    }
    double scoreSum = 0.0;
    int scoreCount = 0;
    // go through the actual cards - not the abstracted studyList:
    CardTest *testCard;
    for (int i = 0; i < [cardList count]; i++) {
        testCard = (CardTest*)[cardList objectAtIndex:i];
        if (testCard.score > 0) {
            scoreSum += testCard.score;
            scoreCount++;
        }
    }
    if (scoreCount == 0) {
        return -1;
    }
    return scoreSum / scoreCount;
}


@end
