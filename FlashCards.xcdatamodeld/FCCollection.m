// 
//  Collection.m
//  FlashCards
//
//  Created by Jason Lustig on 11/5/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import "FCCollection.h"

#import "FCCard.h"
#import "FCCardSet.h"

#import "CHCSVParser.h"
#import "NSData+textEncoding.h"

@implementation FCCollection 

@dynamic studyStateStudyAlgorithm;
@dynamic ofMatrixAdjusted;
@dynamic studyStateShowFirstSide;
@dynamic dateCreated;
@dynamic dateModified;
@dynamic backValueLanguage;
@dynamic defaultFirstSide;
@dynamic numCases;
@dynamic frontValueLanguage;
@dynamic studyStateDate;
@dynamic isLanguage;
@dynamic ofMatrix;
@dynamic studyStateStudyOrder;
@dynamic name;
@dynamic studyStateDone;
@dynamic cardSets;
@dynamic cards;
@dynamic studyStateCardList;
@dynamic masterCardSet;

@dynamic offlineTTS;
@dynamic offlineTTSBack;
@dynamic offlineTTSFront;

- (void)awakeFromInsert {
    [self setDateCreated:[NSDate date]];
    [self setDateModified:[NSDate date]];
    
    NSMutableArray *matrix;
    
    matrix = [SMCore newOFactorMatrix];
    [self setOfMatrix:matrix];
    
    matrix = [SMCore newOFactorAdjustedMatrix];
    [self setOfMatrixAdjusted:matrix];

    FCCardSet *masterSet = (FCCardSet *)[NSEntityDescription insertNewObjectForEntityForName:@"CardSet" inManagedObjectContext:self.managedObjectContext];
    if (self.name) {
        [masterSet setName:self.name];
    } else {
        [masterSet setName:@""];
    }
    [masterSet setCollection:self];
    [masterSet setIsMasterCardSet:[NSNumber numberWithBool:YES]];
    [self setMasterCardSet:masterSet];
}

- (void)resetStatistics {
    // if working on a collection, reset the OF Matrix and tell the user that it has been done:
    NSMutableArray *oFactorMatrix, *matrix;
    
    oFactorMatrix = [SMCore newOFactorMatrix];
    [self setOfMatrix:oFactorMatrix];
    
    matrix = [SMCore newOFactorAdjustedMatrix];
    [self setOfMatrixAdjusted:matrix];
    
    
    for (FCCard *card in [self.cards allObjects]) {
        [card resetStatistics];
    }
    
    self.numCases = [NSNumber numberWithInt:0];
    self.studyStateDone = [NSNumber numberWithBool:YES];
    [self setDateCreated:[NSDate date]];
    for (FCCardSet *set in [[self cardSets] allObjects]) {
        [set setDateCreated:[NSDate date]];
    }
}

- (void)resetDatesObjectsCreated {
    [self setDateCreated:[NSDate date]];
    for (FCCard *card in [self.cards allObjects]) {
        [card setDateCreated:[NSDate date]]; 
    }
    for (FCCardSet *cardSet in [self.cardSets allObjects]) {
        [cardSet setDateCreated:[NSDate date]];
    }

}

-(void)buildExportCSV:(NSString*)path {
    NSOutputStream *output = [NSOutputStream outputStreamToMemory];
    CHCSVWriter *csvWriter = [[CHCSVWriter alloc] initWithOutputStream:output encoding:NSUTF16StringEncoding delimiter:'\t'];
    [csvWriter writeLineOfFields:@[
     NSLocalizedStringFromTable(@"Front Side", @"CardManagement", @"CSV Header"),
     NSLocalizedStringFromTable(@"Back Side", @"CardManagement", @"CSV Header")
     ]];
    
    for (FCCard *card in [self allCards]) {
        if ([card.isDeletedObject boolValue]) {
            continue;
        }
        [csvWriter writeLineOfFields:
         @[
         [card valueForKey:@"frontValue"],
         [card valueForKey:@"backValue"]
         ]];
    }
    [csvWriter closeStream];
    
    NSData *buffer = [output propertyForKey:NSStreamDataWrittenToMemoryStreamKey];
    NSStringEncoding encoding = [buffer textEncoding];
    NSString *string = [[NSString alloc] initWithData:buffer encoding:encoding];
    [string writeToFile:path atomically:YES encoding:NSUTF16StringEncoding error:nil];
}

- (NSDictionary*)buildExportDictionary:(FCCardSet*)cardSet {

    NSEnumerator *enumerator;
    
    /*
     
     Documentation of file format:

    1. Main Dictionary (NSDictionary)
    - collection (NSDictionary, max 1 item)
    - name (string)
    - isLanguage (bool)
    - frontValueLanguage (string)
    - backValueLanguage (string)
    - cardSets (NSArray, no max # items). NB that 1 item = cardset; >1 item = collection.
    - name (string)
    - cards (NSArray) - lists the CardID for each card, referencing the "cards" dictionary.
        - cards (NSDictionary, no max # items)
        - CardID --> Dictionary:
        - fv -- frontValue (string)
        - bv -- backValue (string)
        - i -- hasImages (bool)
        - fid -- frontImageData (data)
        - bid -- backImageData (data)
        - fad -- frontAudioData (data)
        - bad -- backAudioData (data)
        - wt -- wordType (int)
        - rcs -- relatedCards (NSSet). Includes CardID of any related cards.
        If cards are listed here which are not included in the main
        "cards" dictionary, then they will simply be ignored when importing
        the cards.

     */
    
    NSMutableDictionary *cards = [[NSMutableDictionary alloc] initWithCapacity:0];
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Card" inManagedObjectContext:self.managedObjectContext];
    [fetchRequest setEntity:entity];
    if (cardSet) {
        [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"isDeletedObject = NO and any cardSet = %@", cardSet]];
    } else {
        [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"isDeletedObject = NO and collection = %@", self]];
    }
    [fetchRequest setRelationshipKeyPathsForPrefetching:[NSArray arrayWithObjects:@"relatedCards", nil]];
    [fetchRequest setReturnsObjectsAsFaults:NO];
    [fetchRequest setIncludesSubentities:YES];

    NSArray *collectionCards = [self.managedObjectContext executeFetchRequest:fetchRequest error:nil];
    
    FCCard *card, *relatedCard;
    NSMutableDictionary *cardDict;
    NSMutableArray *relatedArray;
    for (int i = 0; i < [collectionCards count]; i++) {
        card = [collectionCards objectAtIndex:i];
        cardDict = [[NSMutableDictionary alloc] initWithCapacity:0];
        
        [cardDict setObject:[card valueForKey:@"frontValue"] forKey:@"fv"];
        [cardDict setObject:[card valueForKey:@"backValue"]  forKey:@"bv"];
        [cardDict setObject:[card valueForKey:@"hasImages"] forKey:@"i"];
        if ([card valueForKey:@"frontImageData"]) {
            [cardDict setObject:[NSNumber numberWithBool:YES] forKey:@"i"];
            [cardDict setObject:[card valueForKey:@"frontImageData"] forKey:@"fid"];
        } else {
            [cardDict setObject:[NSMutableData dataWithLength:0] forKey:@"fid"];
        }
        if ([card valueForKey:@"backImageData"]) {
            [cardDict setObject:[NSNumber numberWithBool:YES] forKey:@"i"];
            [cardDict setObject:[card valueForKey:@"backImageData"] forKey:@"bid"];
        } else {
            [cardDict setObject:[NSMutableData dataWithLength:0] forKey:@"bid"];
        }
        if ([[card valueForKey:@"frontAudioData"] length] > 0) {
            [cardDict setObject:[card valueForKey:@"frontAudioData"] forKey:@"fad"];
        } else {
            [cardDict setObject:[NSMutableData dataWithLength:0] forKey:@"fad"];
        }
        if ([[card valueForKey:@"backAudioData"] length] > 0) {
            [cardDict setObject:[card valueForKey:@"backAudioData"] forKey:@"bad"];
        } else {
            [cardDict setObject:[NSMutableData dataWithLength:0] forKey:@"bad"];
        }
        [cardDict setObject:[card valueForKey:@"wordType"] forKey:@"wt"];
        
        relatedArray = [[NSMutableArray alloc] initWithCapacity:0];
        enumerator = [[card valueForKey:@"relatedCards"] objectEnumerator];
        while ((relatedCard = [enumerator nextObject])) {
            if (![relatedCard.collection isEqual:card.collection]) {
                continue;
            }
            [relatedArray addObject:coreDataId(relatedCard)];
        }
        [cardDict setObject:relatedArray forKey:@"rcs"];
        
        [cards setObject:cardDict forKey:coreDataId(card)];
        
    }
    
    NSMutableArray *cardSets = [[NSMutableArray alloc] initWithCapacity:0];
    NSMutableDictionary *cardSetDict;
    NSMutableArray *cardSetCards;
    
    fetchRequest = [[NSFetchRequest alloc] init];
    entity = [NSEntityDescription entityForName:@"CardSet" inManagedObjectContext:self.managedObjectContext];
    [fetchRequest setEntity:entity];
    if (cardSet) {
        [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"isDeletedObject = NO and self = %@", cardSet]];
    } else {
        [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"isDeletedObject = NO and collection = %@ and isMasterCardSet = NO", self]];
    }
    [fetchRequest setRelationshipKeyPathsForPrefetching:[NSArray arrayWithObjects:@"cards", nil]];
    [fetchRequest setReturnsObjectsAsFaults:NO];
    [fetchRequest setIncludesSubentities:YES];
    NSArray *allCardSets = [self.managedObjectContext executeFetchRequest:fetchRequest error:nil];
    
    for (FCCardSet *myCardSet in allCardSets) {
        cardSetDict = [[NSMutableDictionary alloc] initWithCapacity:0];
        [cardSetDict setObject:myCardSet.name forKey:@"name"];
        cardSetCards = [[NSMutableArray alloc] initWithCapacity:0];
        enumerator = [myCardSet.cards objectEnumerator];
        while ((card = [enumerator nextObject])) {
            [cardSetCards addObject:coreDataId(card)];
        }
        [cardSetDict setObject:cardSetCards forKey:@"cards"];
        [cardSets addObject:cardSetDict];
        
    }
    
    NSMutableDictionary *collectionDict = [[NSMutableDictionary alloc] initWithCapacity:0];
    
    [collectionDict setObject:self.name                 forKey:@"name"];
    [collectionDict setObject:self.isLanguage           forKey:@"isLanguage"];
    // resolves: http://www.bugsense.com/dashboard/project/1777ceac/error/4636148
    if (self.frontValueLanguage) {
        [collectionDict setObject:self.frontValueLanguage   forKey:@"frontValueLanguage"];
    } else {
        [collectionDict setObject:@""   forKey:@"frontValueLanguage"];
    }
    if (self.backValueLanguage) {
        [collectionDict setObject:self.backValueLanguage    forKey:@"backValueLanguage"];
    } else {
        [collectionDict setObject:@""    forKey:@"backValueLanguage"];
    }

    NSDictionary *saveDict = [[NSDictionary alloc] initWithObjectsAndKeys:
                               collectionDict, @"collection",
                               cardSets, @"cardSets",
                               cards, @"cards",
                               nil];

    return saveDict;

}

- (BOOL)shouldSync {
    if (!self.masterCardSet) {
        return NO;
    }
    return [self.masterCardSet.shouldSync boolValue];
}
- (BOOL)canSync {
    if (!self.masterCardSet) {
        return NO;
    }
    return [self.masterCardSet isQuizletSet];
}

- (int)cardsCount {
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"isDeletedObject = NO and collection = %@", self]];
    [fetchRequest setEntity:[NSEntityDescription entityForName:@"Card" inManagedObjectContext:self.managedObjectContext]];
    return (int)[self.managedObjectContext countForFetchRequest:fetchRequest error:nil];
}
- (int)cardSetsCount {
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"isDeletedObject = NO and collection = %@ and isMasterCardSet = NO", self]];
    [fetchRequest setEntity:[NSEntityDescription entityForName:@"CardSet" inManagedObjectContext:self.managedObjectContext]];
    return (int)[self.managedObjectContext countForFetchRequest:fetchRequest error:nil];
}

- (NSSet*)allCardSets {
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"isDeletedObject = NO and collection = %@ and isMasterCardSet = NO", self]];
    [fetchRequest setEntity:[NSEntityDescription entityForName:@"CardSet" inManagedObjectContext:self.managedObjectContext]];
    return [NSSet setWithArray:[self.managedObjectContext executeFetchRequest:fetchRequest error:nil]];
}

- (NSSet*)allCards {
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"isDeletedObject = NO and collection = %@", self]];
    [fetchRequest setEntity:[NSEntityDescription entityForName:@"Card" inManagedObjectContext:self.managedObjectContext]];
    return [NSSet setWithArray:[self.managedObjectContext executeFetchRequest:fetchRequest error:nil]];
}

- (NSSet*)allCardsIncludingDeletedOnes {
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"collection = %@", self]];
    [fetchRequest setEntity:[NSEntityDescription entityForName:@"Card" inManagedObjectContext:self.managedObjectContext]];
    return [NSSet setWithArray:[self.managedObjectContext executeFetchRequest:fetchRequest error:nil]];
}


- (bool)isCardSetsCount {
    return YES;
}

# pragma - Override Methods

- (void)setName:(NSString *)_name {
    [self setDateModified:[NSDate date]];

    [self willChangeValueForKey:@"name"];
    [self setPrimitiveValue:_name forKey:@"name"];
    if (self.masterCardSet) {
        [self.masterCardSet setName:_name];
    }
    [self didChangeValueForKey:@"name"];
}

- (void)setOfflineTTS:(NSNumber *)_offlineTTS {
    [self willChangeValueForKey:@"offlineTTS"];
    BOOL oldValue = [[self offlineTTS] boolValue];
    BOOL newValue = [_offlineTTS boolValue];
    if (oldValue != newValue) {
        if (!newValue) {
            [self setOfflineTTSFront:[NSNumber numberWithBool:NO]];
            [self setOfflineTTSBack:[NSNumber numberWithBool:NO]];
        }
        for (FCCard *card in self.cards) {
            [card setOfflineTTS:_offlineTTS];
        }
    }
    [self setPrimitiveValue:_offlineTTS forKey:@"offlineTTS"];
    [self didChangeValueForKey:@"offlineTTS"];
}

- (void)setFrontValueLanguage:(NSString *)_frontValueLanguage {
    [self setDateModified:[NSDate date]];

    [self willChangeValueForKey:@"frontValueLanguage"];
    if (![self.frontValueLanguage isEqualToString:_frontValueLanguage]) {
        for (FCCard *card in self.cards) {
            [card setOfflineTTSFrontAttempted:[NSNumber numberWithBool:NO]];
        }
    }
    [self setPrimitiveValue:_frontValueLanguage forKey:@"frontValueLanguage"];
    [self didChangeValueForKey:@"frontValueLanguage"];
}

- (void)setBackValueLanguage:(NSString *)_backValueLanguage {
    [self setDateModified:[NSDate date]];

    [self willChangeValueForKey:@"backValueLanguage"];
    if (![self.backValueLanguage isEqualToString:_backValueLanguage]) {
        for (FCCard *card in self.cards) {
            [card setOfflineTTSBackAttempted:[NSNumber numberWithBool:NO]];
        }
    }
    [self setPrimitiveValue:_backValueLanguage forKey:@"backValueLanguage"];
    [self didChangeValueForKey:@"backValueLanguage"];
}

@end
