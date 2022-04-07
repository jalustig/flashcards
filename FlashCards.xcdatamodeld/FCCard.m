// 
//  Card.m
//  FlashCards
//
//  Created by Jason Lustig on 10/18/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import "FCCard.h"

#import "FCCardRepetition.h"
#import "FCCardSet.h"
#import "FCCardSetCard.h"
#import "FCCollection.h"
#import "FCFlashcardExchangeCardId.h"
#import "FCQuizletCardId.h"

#import "NSData+MD5.h"
#import "NSString+StripParentheses.h"

#import "Constants.h"

@implementation FCCard 

@synthesize currentCardSet;

@dynamic wordType;
@dynamic numLapses;
@dynamic frontValue;
@dynamic frontImageData;
@dynamic frontImageId;
@dynamic frontImageURL;
@dynamic frontAudioData;
@dynamic lastIntervalOptimalFactor;
@dynamic backImageData;
@dynamic backImageId;
@dynamic backImageURL;
@dynamic backAudioData;
@dynamic dateCreated;
@dynamic dateModified;
@dynamic isLapsed;
@dynamic frontValueFirstChar;
@dynamic eFactor;
@dynamic lastRepetitionDate;
@dynamic isSpacedRepetition;
@dynamic hasImages;
@dynamic hasAudio;
@dynamic backValue;
@dynamic nextRepetitionDate;
@dynamic currentIntervalCount;
@dynamic wordPartOfSpeech;
@dynamic relatedCards;
@dynamic internalCardIds;
@dynamic quizletCardIds;
@dynamic flashcardExchangeCardIds;
@dynamic cardSet;
@dynamic cardSetOrdered;
@dynamic cardSetsDeletedFrom;
@dynamic collectionStudyState;
@dynamic repetitions;
@dynamic collection;

@dynamic syncStatus;
@dynamic isDeletedObject;
@dynamic shouldSync;
@dynamic isSubscribed;

@dynamic offlineTTS;
@dynamic offlineTTSBackAttempted;
@dynamic offlineTTSFrontAttempted;

- (void)awakeFromInsert {
    [self setDateCreated:[NSDate date]];
    [self setDateModified:[NSDate date]];
}

- (void)resetStatistics {
    self.currentIntervalCount = [NSNumber numberWithInt:0];
    self.isSpacedRepetition = [NSNumber numberWithInt:NO];
    self.isLapsed = [NSNumber numberWithInt:NO];
    self.lastIntervalOptimalFactor = nil;
    self.lastRepetitionDate = nil;
    self.nextRepetitionDate = nil;
    self.numLapses = [NSNumber numberWithInt:0];
    for (FCCardRepetition *repetition in [[self repetitions] allObjects]) {
        [self.managedObjectContext deleteObject:repetition];
    }
    [self setRepetitions:[NSSet setWithObjects:nil]];
}

- (void)removeFromMOC {
    // If it is only in one card set, then just simply delete it completely:
    for (FCCardSet *set in [self.cardSet allObjects]) {
        [set removeCard:self];
    }
    [self.managedObjectContext deleteObject:self];
}

- (FCQuizletCardId*)quizletCardIdForCardSet:(FCCardSet*)cardSet {
    for (FCQuizletCardId *cardId in self.quizletCardIds) {
        if ([cardId.cardSet isEqual:cardSet]) {
            return cardId;
        }
    }
    return nil;
}

- (FCFlashcardExchangeCardId*)flashcardExchangeCardIdForCardSet:(FCCardSet*)cardSet {
    for (FCFlashcardExchangeCardId *cardId in self.flashcardExchangeCardIds) {
        if ([cardId.cardSet isEqual:cardSet]) {
            return cardId;
        }
    }
    return nil;
}

- (void)setWebsiteCardId:(int)cardId forCardSet:(FCCardSet*)cardSet withWebsite:(NSString*)website {
    if ([website isEqualToString:@"quizlet"]) {
        FCQuizletCardId *quizletId = [self quizletCardIdForCardSet:cardSet];
        if (!quizletId) {
            quizletId = (FCQuizletCardId *)[NSEntityDescription insertNewObjectForEntityForName:@"QuizletCardId" inManagedObjectContext:self.managedObjectContext];
            [quizletId setCardSet:cardSet];
            [self addQuizletCardIdsObject:quizletId];
        }
        [quizletId setQuizletCardId:[NSNumber numberWithInt:cardId]];
    } else if ([website isEqualToString:@"flashcardExchange"]) {
        FCFlashcardExchangeCardId *currentCardId = [self flashcardExchangeCardIdForCardSet:cardSet];
        if (!currentCardId) {
            currentCardId = (FCFlashcardExchangeCardId *)[NSEntityDescription insertNewObjectForEntityForName:@"FlashcardExchangeCardId" inManagedObjectContext:self.managedObjectContext];
            [currentCardId setCardSet:cardSet];
            [self addFlashcardExchangeCardIdsObject:currentCardId];
        }
        [currentCardId setFlashcardExchangeCardId:[NSNumber numberWithInt:cardId]];
    }
}

- (int)cardIdForWebsite:(NSString*)website forCardSet:(FCCardSet*)cardSet {
    if ([website isEqualToString:@"flashcardExchange"]) {
        for (FCFlashcardExchangeCardId *cardId in self.flashcardExchangeCardIds) {
            if ([cardId.cardSet isEqual:cardSet]) {
                return [cardId.flashcardExchangeCardId intValue];
            }
        }
    } else if ([website isEqualToString:@"quizlet"]) {
        for (FCQuizletCardId *cardId in self.quizletCardIds) {
            if ([cardId.cardSet isEqual:cardSet]) {
                return [cardId.quizletCardId intValue];
            }
        }
    }
    return 0;
}

- (NSSet*)allCardSets {
    return [[self cardSet] filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"isDeletedObject = NO and isMasterCardSet = NO"]];
}

- (int)cardSetsCount {
    return [[[[self cardSet]
              filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"isDeletedObject = NO and isMasterCardSet = NO"]]
             allObjects] count];
}

-(NSString*)prepareTTS:(NSString*)string {
    BOOL TTSIgnoresParentheses = [(NSNumber*)[FlashCardsCore getSetting:@"TTSIgnoresParentheses"] boolValue];
    if (TTSIgnoresParentheses) {
        return [[[string stripParentheses] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] lowercaseString];
    } else {
        return [[string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] lowercaseString];
    }
}
-(NSString*)TTSFileNameForText:(NSString*)text andLanguage:(NSString*)language {
    return [NSString stringWithFormat:@"%@/tts/%@-%@.mp3",
            [FlashCardsCore documentsDirectory],
            [text md5],
            language];
}
- (NSString*)frontValueTTS {
    if (!self) {
        return @"";
    }
    NSString *tts = [self prepareTTS:self.frontValue];
    // if ([tts length] > 100) {
    //    return [tts substringToIndex:100];
    // }
    return tts;
}
- (NSString*)backValueTTS {
    if (!self) {
        return @"";
    }
    NSString *tts = [self prepareTTS:self.backValue];
    // if ([tts length] > 100) {
    //     return [tts substringToIndex:100];
    // }
    return tts;
}

-(NSString*)frontTTSFileName {
    if (!self.collection) {
        return @"";
    }
    return [self TTSFileNameForText:[self frontValueTTS] andLanguage:self.collection.frontValueLanguage];
}
-(NSString*)backTTSFileName {
    if (!self.collection) {
        return @"";
    }
    return [self TTSFileNameForText:[self backValueTTS] andLanguage:self.collection.backValueLanguage];
}

- (int)cardSetOrderInSet:(FCCardSet *)_set {
    for (FCCardSetCard *order in [self cardSetOrdered]) {
        if ([[order cardSet] isEqual:_set]) {
            return [[order cardOrder] intValue];
        }
    }
    return -1;
}
- (void)addCardOrderForSet:(FCCardSet*)_set {
    int maxCardOrder = [_set maxCardOrder];
    if (maxCardOrder == -1 || maxCardOrder == -2) {
        maxCardOrder = 0;
    }
    FCCardSetCard *cardOrder = (FCCardSetCard *)[NSEntityDescription insertNewObjectForEntityForName:@"CardSetCard"
                                                                              inManagedObjectContext:self.managedObjectContext];
    [cardOrder setCard:self];
    [cardOrder setCardSet:_set];
    [cardOrder setCardOrder:[NSNumber numberWithInt:(maxCardOrder + 10000)]];
    [_set setHasCardOrder:@YES];
}
- (void)setCardOrder:(int)_order forSet:(FCCardSet*)_set {
    FCCardSetCard *orderObject = [self cardSetOrderObjectForSet:_set];
    if (!orderObject) {
        [self addCardOrderForSet:_set];
        orderObject = [self cardSetOrderObjectForSet:_set];
    }
    [orderObject setCardOrder:[NSNumber numberWithInt:_order]];
    [self setDateModified:[NSDate date]];
}
- (FCCardSetCard*)cardSetOrderObjectForSet:(FCCardSet*)_set {
    for (FCCardSetCard *order in [self cardSetOrdered]) {
        if ([[order cardSet] isEqual:_set]) {
            return order;
        }
    }
    return nil;
}


# pragma mark - Override Methods

- (void)setSyncStatus:(NSNumber *)_syncStatus {
    if ([self syncStatus] && [[self syncStatus] intValue] == [_syncStatus intValue]) {
        return;
    }
    
    [self willChangeValueForKey:@"syncStatus"];
    [self setPrimitiveValue:_syncStatus forKey:@"syncStatus"];
    [self didChangeValueForKey:@"syncStatus"];

    if ([[self syncStatus] intValue] == syncChanged) {
        for (FCCardSet *_cardSet in [self allCardSets]) {
            if ([_cardSet isQuizletSet]) {
                [_cardSet setSyncStatus:self.syncStatus];
                [_cardSet setDateModified:[NSDate date]];
            }
        }
    }
}

- (void)setCurrentCardSet:(FCCardSet *)_currentCardSet {
    [self setCardOrder:@-2]; // -2 == value is reset
    [self willChangeValueForKey:@"currentCardSet"];
    currentCardSet = _currentCardSet;
    [self didChangeValueForKey:@"currentCardSet"];
}

- (void)setCardOrder:(NSNumber*)__cardOrder {
    [self willChangeValueForKey:@"cardOrder"];
    _cardOrder = __cardOrder;
    [self didChangeValueForKey:@"cardOrder"];
}
- (NSNumber*) cardOrder {
    if (_cardOrder) {
        // if value == -2, then value has been reset
        if ([_cardOrder intValue] != -2) {
            return _cardOrder;
        }
    }
    if (!self.currentCardSet) {
        return @-1;
    }
    [self setCardOrder:[NSNumber numberWithInt:[self cardSetOrderInSet:self.currentCardSet]]];
    return _cardOrder;
}

- (void)setIsSpacedRepetition:(NSNumber *)_isSpacedRepetition {
    if ([self isSpacedRepetition] && [[self isSpacedRepetition] boolValue] == [_isSpacedRepetition boolValue]) {
        return;
    }
    
    [self willChangeValueForKey:@"isSpacedRepetition"];
    [self setPrimitiveValue:_isSpacedRepetition forKey:@"isSpacedRepetition"];
    [self didChangeValueForKey:@"isSpacedRepetition"];
}

- (void)setIsLapsed:(NSNumber *)_isLapsed {
    if ([self isLapsed] && [[self isLapsed] boolValue] == [_isLapsed boolValue]) {
        return;
    }
    
    [self willChangeValueForKey:@"isLapsed"];
    [self setPrimitiveValue:_isLapsed forKey:@"isLapsed"];
    [self didChangeValueForKey:@"isLapsed"];
}

-(void)setWordType:(NSNumber *)_newWordType {
    if ([self wordType] && [[self wordType] isEqual:_newWordType]) {
        return;
    }
    // Adjust the e-factor based on the word type: (cognate, normal, or false cognate)
    int oldWordType = [self.wordType intValue];
    int newWordType = [_newWordType intValue];
    double currentEFactor;
    if (oldWordType != newWordType) {
        [self setDateModified:[NSDate date]];
        currentEFactor = [self.eFactor doubleValue];
        if (newWordType == wordTypeCognate) {
            // If it is a cognate, then the EFactor should be higher by 0.2
            if (oldWordType == wordTypeNormal) {
                // If we are switching from normal to cognate, increase eFactor:
                [self setEFactor:[NSNumber numberWithDouble:[SMCore adjustEFactor:currentEFactor add:0.2]]];
            } else if (oldWordType == wordTypeFalseCognate) {
                // If we are switching from false cognate to cognate, increase eFactor:
                [self setEFactor:[NSNumber numberWithDouble:[SMCore adjustEFactor:currentEFactor add:0.4]]];
            }
        } else if (newWordType == wordTypeFalseCognate) {
            // If it is a false cognate, then the EFactor should be lower by 0.2.
            if (oldWordType == wordTypeNormal) {
                [self setEFactor:[NSNumber numberWithDouble:[SMCore adjustEFactor:currentEFactor add:-0.2]]];
            } else if (oldWordType == wordTypeCognate) {
                [self setEFactor:[NSNumber numberWithDouble:[SMCore adjustEFactor:currentEFactor add:-0.4]]];
            }
        } else if (newWordType == wordTypeNormal) {
            // if it is a normal word, then the EFactor should be "normal".
            if (oldWordType == wordTypeCognate) {
                [self setEFactor:[NSNumber numberWithDouble:[SMCore adjustEFactor:currentEFactor add:-0.2]]];
            } else if (oldWordType == wordTypeFalseCognate) {
                [self setEFactor:[NSNumber numberWithDouble:[SMCore adjustEFactor:currentEFactor add:0.2]]];
            }
        }
    }
    [self willChangeValueForKey:@"wordType"];
    [self setPrimitiveValue:_newWordType forKey:@"wordType"];
    [self didChangeValueForKey:@"wordType"];

}

-(void)setFrontValue:(NSString *)_frontValue {
    if ([self frontValue] && [[self frontValue] isEqualToString:_frontValue]) {
        return;
    }
    [self willChangeValueForKey:@"frontValue"];
    if (![[self frontValue] isEqualToString:_frontValue]) {
        [self setDateModified:[NSDate date]];
        [self setSyncStatus:[NSNumber numberWithInt:syncChanged]];
    }
    if (![[self frontValueTTS] isEqualToString:[self prepareTTS:_frontValue]]) {
        [self setOfflineTTSFrontAttempted:[NSNumber numberWithBool:NO]];
    }
    [self setPrimitiveFrontValue:_frontValue];
    
    if ([_frontValue length] > 0) {
        [self setFrontValueFirstChar:[[_frontValue substringToIndex:1] capitalizedString]];
    } else {
        [self setFrontValueFirstChar:@""];
    }
    
    [self didChangeValueForKey:@"frontValue"];
}

-(void)setFrontImageData:(NSData *)_frontImageData {
    if ([self frontImageData] && [[self frontImageData] isEqualToData:_frontImageData]) {
        return;
    }

    [self willChangeValueForKey:@"frontImageData"];

    if (![[self frontImageData] isEqualToData:_frontImageData]) {
        [self setDateModified:[NSDate date]];
        [self setSyncStatus:[NSNumber numberWithInt:syncChanged]];
        [self setFrontImageId:@""];
    }
    
    if ([_frontImageData length] > 0 || [self.backImageData length] > 0) {
        [self setHasImages:[NSNumber numberWithBool:YES]];
        for (FCCardSet *set in [self allCardSets]) {
            [set setHasImages:[NSNumber numberWithBool:YES]];
        }
    } else {
        [self setHasImages:[NSNumber numberWithBool:NO]];
        if (![[self frontImageData] isEqualToData:_frontImageData] && [_frontImageData length] == 0) {
            BOOL setHasImages = NO;
            for (FCCardSet *set in [self allCardSets]) {
                if (![[set hasImages] boolValue]) {
                    continue;
                }
                @autoreleasepool {
                    setHasImages = NO;
                    for (FCCard *card in [set allCards]) {
                        if ([[card hasImages] boolValue]) {
                            setHasImages = YES;
                            break;
                        }
                    }
                    [set setHasImages:[NSNumber numberWithBool:setHasImages]];
                }
            }
        }
    }

    [self setPrimitiveValue:_frontImageData forKey:@"frontImageData"];
    [self didChangeValueForKey:@"frontImageData"];
}

-(void)setBackValue:(NSString *)_backValue {
    if ([self backValue] && [[self backValue] isEqualToString:_backValue]) {
        return;
    }

    [self willChangeValueForKey:@"backValue"];
    if (![[self backValue] isEqualToString:_backValue]) {
        [self setDateModified:[NSDate date]];
        [self setSyncStatus:[NSNumber numberWithInt:syncChanged]];
    }
    if (![[self backValueTTS] isEqualToString:[self prepareTTS:_backValue]]) {
        [self setOfflineTTSBackAttempted:[NSNumber numberWithBool:NO]];
    }
    [self setPrimitiveValue:_backValue forKey:@"backValue"];
    [self didChangeValueForKey:@"backValue"];
}

-(void)setBackImageData:(NSData *)_backImageData {
    if ([self backImageData] && [[self backImageData] isEqualToData:_backImageData]) {
        return;
    }

    [self willChangeValueForKey:@"backImageData"];

    if (![[self backImageData] isEqualToData:_backImageData]) {
        [self setDateModified:[NSDate date]];
        [self setSyncStatus:[NSNumber numberWithInt:syncChanged]];
        [self setBackImageId:@""];
    }
    
    if ([self.frontImageData length] > 0 || [_backImageData length] > 0) {
        [self setHasImages:[NSNumber numberWithBool:YES]];
        for (FCCardSet *set in [self.cardSet allObjects]) {
            [set setHasImages:[NSNumber numberWithBool:YES]];
        }
    } else {
        [self setHasImages:[NSNumber numberWithBool:NO]];
        if (![[self backImageData] isEqualToData:_backImageData] && [_backImageData length] == 0) {
            BOOL setHasImages = NO;
            for (FCCardSet *set in [self allCardSets]) {
                if (![[set hasImages] boolValue]) {
                    continue;
                }
                @autoreleasepool {
                    setHasImages = NO;
                    for (FCCard *card in [set allCards]) {
                        if ([[card hasImages] boolValue]) {
                            setHasImages = YES;
                            break;
                        }
                    }
                    [set setHasImages:[NSNumber numberWithBool:setHasImages]];
                }
            }
        }
    }

    [self setPrimitiveValue:_backImageData forKey:@"backImageData"];
    [self didChangeValueForKey:@"backImageData"];
}

-(void)setFrontAudioData:(NSData *)_frontAudioData {
    if ([self frontAudioData] && [[self frontAudioData] isEqualToData:_frontAudioData]) {
        return;
    }
    if (![[self frontAudioData] isEqualToData:_frontAudioData]) {
        [self setDateModified:[NSDate date]];
    }
    [self willChangeValueForKey:@"frontAudioData"];
    [self setPrimitiveValue:_frontAudioData forKey:@"frontAudioData"];
    [self didChangeValueForKey:@"frontAudioData"];
}

-(void)setBackAudioData:(NSData *)_backAudioData {
    if ([self backAudioData] && [[self backAudioData] isEqualToData:_backAudioData]) {
        return;
    }
    if (![[self backAudioData] isEqualToData:_backAudioData]) {
        [self setDateModified:[NSDate date]];
    }
    [self willChangeValueForKey:@"backAudioData"];
    [self setPrimitiveValue:_backAudioData forKey:@"backAudioData"];
    [self didChangeValueForKey:@"backAudioData"];
}

- (void)setShouldSync:(NSNumber *)_shouldSync {
    if ([[self shouldSync] isEqual:_shouldSync]) {
        return;
    }
    [self willChangeValueForKey:@"shouldSync"];
    [self setPrimitiveValue:_shouldSync forKey:@"shouldSync"];
    [self didChangeValueForKey:@"shouldSync"];
}

- (void)setDateCreated:(NSDate *)_dateCreated {
    if ([self dateCreated] && [[self dateCreated] isEqualToDate:_dateCreated]) {
        return;
    }
    
    [self willChangeValueForKey:@"dateCreated"];
    [self setPrimitiveValue:_dateCreated forKey:@"dateCreated"];
    [self didChangeValueForKey:@"dateCreated"];
}

- (void)setOfflineTTS:(NSNumber *)_offlineTTS {
    if ([self offlineTTS] && [[self offlineTTS] isEqualToNumber:_offlineTTS]) {
        return;
    }
    
    [self willChangeValueForKey:@"offlineTTS"];
    [self setPrimitiveValue:_offlineTTS forKey:@"offlineTTS"];
    [self didChangeValueForKey:@"offlineTTS"];
}

- (void)setHasImages:(NSNumber *)_hasImages {
    if ([self hasImages] && [[self hasImages] isEqualToNumber:_hasImages]) {
        return;
    }
    
    [self willChangeValueForKey:@"hasImages"];
    [self setPrimitiveValue:_hasImages forKey:@"hasImages"];
    [self didChangeValueForKey:@"hasImages"];
}

- (void)setFrontImageURL:(NSString *)_frontImageURL {
    if ([self frontImageURL] && [[self frontImageURL] isEqualToString:_frontImageURL]) {
        return;
    }
    
    [self willChangeValueForKey:@"frontImageURL"];
    [self setPrimitiveValue:_frontImageURL forKey:@"frontImageURL"];
    [self didChangeValueForKey:@"frontImageURL"];
}

- (void)setFrontImageId:(NSString *)_frontImageId {
    if ([self frontImageId] && [[self frontImageId] isEqualToString:_frontImageId]) {
        return;
    }
    
    [self willChangeValueForKey:@"frontImageId"];
    [self setPrimitiveValue:_frontImageId forKey:@"frontImageId"];
    [self didChangeValueForKey:@"frontImageId"];
}

- (void)setBackImageURL:(NSString *)_backImageURL {
    if ([self backImageURL] && [[self backImageURL] isEqualToString:_backImageURL]) {
        return;
    }
    
    [self willChangeValueForKey:@"backImageURL"];
    [self setPrimitiveValue:_backImageURL forKey:@"backImageURL"];
    [self didChangeValueForKey:@"backImageURL"];
}

- (void)setBackImageId:(NSString *)_backImageId {
    if ([self backImageId] && [[self backImageId] isEqualToString:_backImageId]) {
        return;
    }
    
    [self willChangeValueForKey:@"backImageId"];
    [self setPrimitiveValue:_backImageId forKey:@"backImageId"];
    [self didChangeValueForKey:@"backImageId"];
}

- (void)setCollection:(FCCollection *)_collection {
    if ([self collection]) {
        if ([[self collection] isEqual:_collection]) {
            return;
        }
    }
    
    if (self.collection) {
        if (self.collection.masterCardSet) {
            if ([self.collection.masterCardSet.cards containsObject:self]) {
                [self.collection.masterCardSet removeCard:self];
            }
        }
    }
    
    [self willChangeValueForKey:@"collection"];
    [self setPrimitiveValue:_collection forKey:@"collection"];
    if (_collection.masterCardSet) {
        if (![_collection.masterCardSet.cards containsObject:self]) {
            [self addCardSetObject:_collection.masterCardSet];
            // [_collection.masterCardSet addCardsObject:self];
        }
        if ([_collection.masterCardSet.shouldSync boolValue]) {
            [self setShouldSync:_collection.masterCardSet.shouldSync];
        }
    }
    if ([_collection offlineTTS]) {
        [self setOfflineTTS:[_collection offlineTTS]];
    }
    [self didChangeValueForKey:@"collection"];
}

@end
