//
//  ImportTerm.m
//  FlashCards
//
//  Created by Jason Lustig on 6/8/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import "ImportTerm.h"

#import "FlashCardsCore.h"
#import "FlashCardsAppDelegate.h"

#import "FCCard.h"
#import "FCCardSet.h"
#import "FCCollection.h"
#import "FCFlashcardExchangeCardId.h"

#import "NSString+URLEscapingAdditions.h"
#import "NSString+XMLEntities.h"
#import "NSString+TimeZone.h"

#import "TICoreDataSync.h"

// List of whether or not to merge cards
// extern int const mergeCardsChoice = 0;
// extern int const mergeAndEditCardsChoice = 1;
// extern int const dontMergeCardsChoice = 2;

static int compareSplitImportTerms (NSArray *t1, NSArray *t2, void *context) {
    // split terms: 0=compare, 1=card
    return [[t1 objectAtIndex:0] caseInsensitiveCompare:[t2 objectAtIndex:0]];
}

# pragma mark -
# pragma mark ImportTerm

@implementation ImportTerm

@synthesize modifiedDate;
@synthesize isDuplicate, isDuplicateChecked, isExactDuplicate, mergeChoice, importOrder, cardId, wordType;
@synthesize matchesOnlineCardId;
@synthesize mergeCardBack, mergeCardFront;
@synthesize importTermFrontValue, importTermBackValue, editedTermFrontValue, editedTermBackValue;
@synthesize frontImageUrl, backImageUrl, frontImageData, backImageData;
@synthesize frontAudioData, backAudioData;
@synthesize finalCardId, currentCardId;
@synthesize markRelated, resetStatistics, shouldImportTerm;
@synthesize importSet;
@synthesize relatedTerms;

+ (id) alloc {
    return [super alloc];
}
- (id) init {
    if ((self = [super init])) {
        cardId = -1;
        wordType = wordTypeNormal;
        isDuplicate = NO;
        isDuplicateChecked = NO;
        isExactDuplicate = NO;
        matchesOnlineCardId = NO;
        markRelated = NO;
        resetStatistics = [(NSNumber*)[FlashCardsCore getSetting:@"importSettingsAutoMergeIdenticalCardsAndResetStatistics"] boolValue];
        shouldImportTerm = YES;
        mergeChoice = dontMergeCardsChoice; // Merge cards
        mergeCardBack = mergeCardNew; // use current card
        mergeCardFront = mergeCardNew; // user current card
        relatedTerms = [[NSMutableSet alloc] initWithCapacity:0];
    }
    return self;
}


- (void) setCurrentCard:(FCCard *)card {
    currentCardId = [card objectID];
    self.isExactDuplicate = [self checkExactDuplicatesOfCard:card];
    if (self.isExactDuplicate) {
        // if it is an exact duplicate, the choice should be to merge the cards.
        self.mergeChoice = mergeCardsChoice;
    }
}

- (FCCard *) currentCardInMOC:(NSManagedObjectContext*)moc {
    if (self.currentCardId) {
        return (FCCard*)[moc objectWithID:self.currentCardId];
    }
    return nil;
}

- (void) setFinalCard:(FCCard*)card {
    finalCardId = [card objectID];
}

- (FCCard *) finalCardInMOC:(NSManagedObjectContext*)moc {
    if (self.finalCardId) {
        return (FCCard*)[moc objectWithID:self.finalCardId];
    }
    return nil;
}



- (bool) checkExactDuplicatesOfFront:(FCCard*)card {
    // NSLog(@"Checking card duplicate front: Self: %@ / Compare: %@", self.importTermFrontValue, [card valueForKey:@"frontValue"]);
    // NSLog(@"Result: %d", ([[card valueForKey:@"frontValue"] caseInsensitiveCompare:self.importTermFrontValue]));
    NSString *cardValue = [[card valueForKey:@"frontValue"] stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"];
    NSString *selfValue = [self.importTermFrontValue stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"];
    BOOL val = ([cardValue caseInsensitiveCompare:selfValue] == NSOrderedSame);
    return val;
}

- (bool) checkExactDuplicatesOfBack:(FCCard*)card {
    // NSLog(@"Checking card duplicate back: Self: %@ / Compare: %@", self.importTermBackValue, [card valueForKey:@"backValue"]);
    // NSLog(@"Result: %d", ([[card valueForKey:@"backValue"] caseInsensitiveCompare:self.importTermBackValue]));
    NSString *cardValue = [[card valueForKey:@"backValue"] stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"];
    NSString *selfValue = [self.importTermBackValue stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"];
    BOOL val = ([cardValue caseInsensitiveCompare:selfValue] == NSOrderedSame);
    return val;
}

- (bool) checkExactDuplicatesOfCard:(FCCard*)card {
    if ([self checkExactDuplicatesOfFront:card] && [self checkExactDuplicatesOfBack:card]) {
        return YES;
    }
    return NO;
}

- (bool) isPotentialMatchBetterThanCurrentMatch:(FCCard*)potentialCardMatch {
    NSManagedObjectContext *threadMOC = potentialCardMatch.managedObjectContext;
    TICDSDocumentSyncManager *manager = [[[FlashCardsCore appDelegate] syncController] documentSyncManager];
    if (manager) {
        [threadMOC setDocumentSyncManager:manager];
        [manager addManagedObjectContext:threadMOC];
    }

    // if there is no current match card, then just mark it that the potential match
    // is better than nothing.
    if (!self.currentCardId) {
        return YES;
    }
    
    int isCurrentExactFrontMatch = ([self checkExactDuplicatesOfFront:[self currentCardInMOC:threadMOC]] ? 1 : 0);
    int isCurrentExactBackMatch  = ([self checkExactDuplicatesOfBack:[self currentCardInMOC:threadMOC]] ? 1 : 0);

    int isPotentialExactFrontMatch = ([self checkExactDuplicatesOfFront:potentialCardMatch] ? 1 : 0);
    int isPotentialExactBackMatch  = ([self checkExactDuplicatesOfBack:potentialCardMatch] ? 1 : 0);
    
    // if the number of matches is greater than the old one, then it is a better match
    if ((isPotentialExactBackMatch + isPotentialExactFrontMatch) > (isCurrentExactFrontMatch + isCurrentExactBackMatch)) {
        return YES;
    }
    
    // if the front is a match in the front, but not before, then it's a better match
    if (isPotentialExactFrontMatch && !isCurrentExactFrontMatch) {
        return YES;
    }
    
    // also check: levenshtein distance of front values:
    int currentFrontMatchLevenshtein = 0;
    int potentialFrontMatchLevenshtein = 0;
    
    if (potentialFrontMatchLevenshtein < currentFrontMatchLevenshtein) {
        return YES;
    }
    
    
    return NO;
}


- (bool) hasImages {
    if (frontImageUrl || backImageUrl) {
        return YES;
    }
    /*
    NSData *temp;
    
    temp = [NSData dataWithData:frontImageData];
    if ([temp length] > 0) {
        return YES;
    }
    
    temp = [NSData dataWithData:backImageData];
    if ([temp length] > 0) {
        return YES;
    }
    */

    return NO;
}


@end

# pragma mark -
# pragma mark NSMutableArray

@implementation NSMutableArray (ImportTermArray)

- (int) numDuplicateCards {
    int count = 0;
    ImportTerm *term;
    for (int i = 0; i < [self count]; i++) {
        term = [self objectAtIndex:i];
        if (term.isDuplicate) {
            count++;
        }
    }
    return count;
}

- (BOOL) allDuplicateCardsChecked {
    ImportTerm *term;
    for (int i = 0; i < [self count]; i++) {
        term = [self objectAtIndex:i];
        if (term.isDuplicate && !term.isDuplicateChecked) {
            return NO;
        }
    }
    return YES;
}

+ (void) splitTerms:(NSArray *)terms splitKey:(NSString *)splitKey finalArray:(NSMutableArray *)finalArray {
    id tmpCard;
    NSString *compareValue;
    NSArray *compareValueSplit;
    NSCharacterSet *splitSet = [NSCharacterSet characterSetWithCharactersInString:@",;="];
        
    NSString *replaceRegexPattern = @"\\([^\\)]*\\)|\\[[^\\]]*\\]";
    NSRegularExpression* replaceRegex = [NSRegularExpression regularExpressionWithPattern:replaceRegexPattern
                                                                                   options:NSRegularExpressionCaseInsensitive
                                                                                     error:nil];
    for (int i = 0; i < [terms count]; i++) {
        tmpCard = [terms objectAtIndex:i];
        compareValue = [replaceRegex stringByReplacingMatchesInString:[tmpCard valueForKey:splitKey]
                                                              options:0
                                                                range:NSMakeRange(0, [(NSString*)[tmpCard valueForKey:splitKey] length])
                                                         withTemplate:@""];
        compareValueSplit = [compareValue componentsSeparatedByCharactersInSet:splitSet];
        for (int j = 0; j < [compareValueSplit count]; j++) {
            compareValue = [[compareValueSplit objectAtIndex:j] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]; 

            // don't include blank items:
            if ([compareValue length] == 0) {
                continue;
            }
                    
            // in previous versions of the algorithm, we used a regular expression to get this out. But this is somewhat faster,
            // and also allows us to check at the beginning of very split string, rather than just at the beginning of each whole string.
            if ([compareValue hasPrefix:@"to "]) {
                compareValue = [compareValue substringFromIndex:3];
            }
            if ([splitKey isEqual:@"frontValue"]) {
                // as per http://stackoverflow.com/questions/2503436/how-to-check-if-nsstring-begins-with-a-certain-character
                if ([compareValue hasPrefix:@"-"]) {
                    continue;
                }
            }
            
            // 0: compare
            // 1: card
            [finalArray addObject:[NSArray arrayWithObjects:compareValue, ([tmpCard isKindOfClass:[ImportTerm class]] ? tmpCard : [tmpCard valueForKey:@"objectID"]), nil]];
        }
        
        if (i % 250 == 0) {
        //    [pool drain];
        //    pool = [[NSAutoreleasePool alloc] init];
        }
    }
    
    
    // [pool drain];
}

// NB: Returns -1 if error.
- (int) findDuplicatesInCollection:(FCCollection *)collection withImportMethod:(NSString *)importMethod {
    NSManagedObjectContext *threadMOC = collection.managedObjectContext;
    TICDSDocumentSyncManager *manager = [[[FlashCardsCore appDelegate] syncController] documentSyncManager];
    if (manager) {
        [threadMOC setDocumentSyncManager:manager];
        [manager addManagedObjectContext:threadMOC];
    }

    @autoreleasepool {
        
        NSError *error;
        
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        
        NSExpressionDescription* objectIdDesc = [NSExpressionDescription new];
        objectIdDesc.name = @"objectID";
        objectIdDesc.expression = [NSExpression expressionForEvaluatedObject];
        objectIdDesc.expressionResultType = NSObjectIDAttributeType;
        
        [fetchRequest setEntity:[NSEntityDescription entityForName:@"Card" inManagedObjectContext:threadMOC]];
        [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"isDeletedObject = NO and collection = %@ and isSubscribed = NO", collection]];
        [fetchRequest setPropertiesToFetch:[NSArray arrayWithObjects:objectIdDesc, @"frontValue", @"backValue", nil]];
        [fetchRequest setResultType:NSDictionaryResultType];
        
        // NOTE: We used to actually do the sorting in the DB, but since we are now splitting
        // up the text anyway we find that is is best to do it in the program.
        
        // 1. Fetch all cards in the current collection, against which we will check.
        // We will get it twice - once sorted by the front card, and then sorted by the back card.
        // Will do a sort match since it is WAY WAY WAY faster..
        
        NSArray *allCardsTmp; // will hold the cards which we pulled from the DB
        
        [fetchRequest setReturnsObjectsAsFaults:NO]; // get all the data NOW:
        allCardsTmp = [threadMOC executeFetchRequest:fetchRequest error:&error];
        if (!allCardsTmp) {
#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Error", @"Error", @"UIAlert title")
                                                            message:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Error: %@ (%@)", @"Error", @"message"), error, [error userInfo] ]
                                                           delegate:nil
                                                  cancelButtonTitle:NSLocalizedStringFromTable(@"OK", @"FlashCards", @"cancelButtonTitle")
                                                  otherButtonTitles:nil];
            [alert show];
#endif
            return -1;
        }
        
        NSMutableArray *allCardsSortFront = [[NSMutableArray alloc] initWithCapacity:0];
        NSMutableArray *allCardsSortBack = [[NSMutableArray alloc] initWithCapacity:0];
        
        ////// 1(b) - Split these items by comma & semicolon in the FRONT, and remove any parentheses sections
        //////          while also retaining the relationship between them and the actual card:
        [NSMutableArray splitTerms:allCardsTmp splitKey:@"frontValue" finalArray:allCardsSortFront];
        
        ////// 1(b) - Split these items by comma & semicolon in the BACK, and remove any parentheses sections
        //////          while also retaining the relationship between them and the actual card:
        
        // sort it again, by the back:
        if ([allCardsSortFront count] > 0) {
            // Only go through the back if we are actually going to get anything:
            [NSMutableArray splitTerms:allCardsTmp splitKey:@"backValue" finalArray:allCardsSortBack];
        }
        
        // [allCardsTmp release];
        
        ////// 1(c) - Actually sort them by the front and the back:
        [allCardsSortBack sortUsingFunction:compareSplitImportTerms context:nil];
        [allCardsSortFront sortUsingFunction:compareSplitImportTerms context:nil];
        
        // NSLog(@"%@", allCardsSortFront);
        // NSLog(@"%@", allCardsSortBack);
        
        // 2. Sort the array of terms by the front value:
        
        NSComparisonResult matchResult;
        
        int termCount, cardCount;
        
        
        
        NSArray *currentComparisonCard;
        NSManagedObjectID *currentComparisonCardCardId;
        FCCard        *currentComparisonCardCard;
        NSString    *currentComparisonCardTerm;
        
        ImportTerm    *currentImportCard;
        NSString    *currentImportTerm;
        
        NSMutableArray *splitTerms;
        NSArray *allCards;
        
        // split terms: 0=compare, 1=card
        
        // Only look for comparison cards if there are cards to compare against:
        if ([allCardsSortFront count] > 0 || [allCardsSortBack count] > 0) {
            // Look for merge-able cards by the front, then the back:
            // this is important since we find that doing the front first
            // will find front matches before back matches.
            for (int key = 0; key <= 1; key++) {
                @autoreleasepool {
                    
                    splitTerms = [[NSMutableArray alloc] initWithCapacity:0];
                    if (key == 0) {
                        // front value
                        allCards = [NSArray arrayWithArray:allCardsSortFront];
                        [NSMutableArray splitTerms:self splitKey:@"importTermFrontValue" finalArray:splitTerms];
                    } else {
                        allCards = [NSArray arrayWithArray:allCardsSortBack];
                        [NSMutableArray splitTerms:self splitKey:@"importTermBackValue" finalArray:splitTerms];
                    }
                    // what if there are no split terms? There is a possibility that either the front or back could be completely empty.
                    // bugsense error: 4477047
                    if ([allCards count] == 0) {
                        continue;
                    }
                    [splitTerms sortUsingFunction:compareSplitImportTerms context:nil];
                    cardCount = 0;
                    currentComparisonCard = [allCards objectAtIndex:cardCount];
                    // go through all of the split terms & see if any match
                    for (termCount = 0; termCount < [splitTerms count]; termCount++ && cardCount < [allCards count]) {
                        currentImportCard = (ImportTerm *)[[splitTerms objectAtIndex:termCount] objectAtIndex:1]; // card
                        
                        // in the old version, if the card was already marked as a duplicate, we skipped it.
                        // this caused a problem where if we had two potential matches, and match A was found
                        // before match B, we would never know if match B was a better match (i.e. an exact match).
                        // Now, we check!
                        if (currentImportCard.isDuplicate) {
                            //    NSLog(@"Term (%@) is already duplicate!", currentImportTerm);
                        }
                        currentImportTerm = [[splitTerms objectAtIndex:termCount] objectAtIndex:0]; //compare
                        
                        currentComparisonCardTerm = [currentComparisonCard objectAtIndex:0]; // compare
                        currentComparisonCardCardId = [currentComparisonCard objectAtIndex:1]; // card
                        // NSLog(@"Term: %@", currentImportTerm);
                        // NSLog(@"Card: %@\n", currentComparisonCardTerm);
                        matchResult = [currentComparisonCardTerm caseInsensitiveCompare:currentImportTerm];
                        if (matchResult == NSOrderedSame) {
                            // as per http://stackoverflow.com/questions/5035057/how-to-get-core-data-object-from-specific-object-id
                            currentComparisonCardCard = (FCCard*)[threadMOC existingObjectWithID:currentComparisonCardCardId error:nil];
                            // if the card is already a duplicate, we need to figure out
                            if (currentImportCard.isDuplicate) {
                                if ([currentImportCard isPotentialMatchBetterThanCurrentMatch:currentComparisonCardCard]) {
                                    // NSLog(@"BETTER MATCH FOUND!");
                                    // NSLog(@"OLD FRONT: %@", currentImportCard.currentCard.frontValue);
                                    // NSLog(@"OLD BACK: %@", currentImportCard.currentCard.backValue);
                                    [currentImportCard setCurrentCard:currentComparisonCardCard];
                                }
                            } else {
                                // it's not already a duplicate, thus set up the comparison card:
                                [currentImportCard setCurrentCard:currentComparisonCardCard];
                            }
                            currentImportCard.isDuplicate = YES;
                            // NSLog(@"MATCH FOUND!!");
                            continue;
                        }
                        while (matchResult != NSOrderedDescending && cardCount < [allCards count]) {
                            cardCount++;
                            if (cardCount == [allCards count]) {
                                break;
                            }
                            currentComparisonCard = [allCards objectAtIndex:cardCount];
                            currentComparisonCardTerm = [currentComparisonCard objectAtIndex:0]; // compare
                            currentComparisonCardCardId = [currentComparisonCard objectAtIndex:1]; // card
                            // NSLog(@"Term: %@", currentImportTerm);
                            // NSLog(@"Card: %@\n", currentComparisonCardTerm);
                            matchResult = [currentComparisonCardTerm caseInsensitiveCompare:currentImportTerm];
                            if (matchResult == NSOrderedSame) {
                                // as per http://stackoverflow.com/questions/5035057/how-to-get-core-data-object-from-specific-object-id
                                currentComparisonCardCard = (FCCard*)[threadMOC existingObjectWithID:currentComparisonCardCardId error:nil];
                                // if the card is already a duplicate, we need to figure out 
                                if (currentImportCard.isDuplicate) {
                                    if ([currentImportCard isPotentialMatchBetterThanCurrentMatch:currentComparisonCardCard]) {
                                        [currentImportCard setCurrentCard:currentComparisonCardCard];
                                    }
                                } else {
                                    // it's not already a duplicate, thus set up the comparison card:
                                    [currentImportCard setCurrentCard:currentComparisonCardCard];
                                }
                                currentImportCard.isDuplicate = YES;
                                // NSLog(@"MATCH FOUND!!");
                                continue;
                            }
                        }
                    }
                    
                }
            }
            [self sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"importOrder" ascending:YES]]];
        }
    }
    return 0;
}

- (NSMutableArray *)duplicateCards:(BOOL)willSync withWebsite:(NSString*)website importingIntoSet:(FCCardSet*)cardSet {
    NSManagedObjectContext *threadMOC = cardSet.managedObjectContext;
    TICDSDocumentSyncManager *manager = [[[FlashCardsCore appDelegate] syncController] documentSyncManager];
    if (manager) {
        [threadMOC setDocumentSyncManager:manager];
        [manager addManagedObjectContext:threadMOC];
    }

    BOOL autoMergeIdenticalCards = [(NSNumber*)[FlashCardsCore getSetting:@"importSettingsAutoMergeIdenticalCards"] boolValue];
    
    NSMutableArray *dc = [[NSMutableArray alloc] initWithCapacity:0]; // keeps track of all the matches we find.
    for (int i = 0; i < [self count]; i++) {
        ImportTerm *term = [self objectAtIndex:i];
        if (term.isDuplicate) {
            if (term.isExactDuplicate && term.cardId == [[term currentCardInMOC:threadMOC] cardIdForWebsite:website forCardSet:cardSet]) {
                // if it's an exact match and the card IDs are the same, then we should actually just merge them:
                term.matchesOnlineCardId = YES;
                term.mergeChoice = mergeCardsChoice;
                continue;
            }
            if (!(autoMergeIdenticalCards && term.isExactDuplicate)) {
                [dc addObject:[NSNumber numberWithInt:i]];
            }
        }
    }
    return dc;
}


@end