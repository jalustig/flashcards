// 
//  CardSet.m
//  FlashCards
//
//  Created by Jason Lustig on 10/18/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import "FCCardSet.h"

#import "FCCard.h"
#import "FCCollection.h"
#import "FCQuizletCardId.h"
#import "FCFlashcardExchangeCardId.h"
#import "FCCardSetCard.h"

#import "ImportTerm.h"

#import "Constants.h"

#import "CHCSVParser.h"
#import "NSData+textEncoding.h"

#import "FlashCardsAppDelegate.h"

#import "NSArray+SplitArray.h"
#import "NSDate+Compare.h"

#import "QuizletSync.h"

#import "MBProgressHUD.h"

@implementation FCCardSet 

@dynamic dateCreated;
@dynamic dateModified;
@dynamic hasImages;
@dynamic hasAudio;
@dynamic didReverseFrontAndBack;
@dynamic name;
@dynamic password;
@dynamic collection;
@dynamic cards;
@dynamic cardsOrdered;
@dynamic cardsDeleted;
@dynamic parentSet;
@dynamic cardSets;
@dynamic importSource;
@dynamic internalSetId;
@dynamic quizletSetId;
@dynamic flashcardExchangeSetId;
@dynamic shouldSync;
@dynamic isSubscribed;
@dynamic lastSyncDate;
@dynamic creatorUsername;
@dynamic userCanEditOnline;

@dynamic hasCardOrder;

@dynamic internalIds;
@dynamic flashcardExchangeIds;

@dynamic syncStatus;
@dynamic isDeletedObject;
@dynamic isMasterCardSet;

- (void)awakeFromInsert {
    [self setDateCreated:[NSDate date]];
    [self setDateModified:[NSDate date]];
}

- (void)resetStatistics {
    for (FCCard *card in [self.cards allObjects]) {
        [card resetStatistics];
    }
    [self setDateCreated:[NSDate date]];
}

- (int)minCardOrder {
    if (![self.hasCardOrder boolValue]) {
        return -1;
    }
    NSMutableArray *orderObjects = [NSMutableArray arrayWithArray:[[self cardsOrdered] allObjects]];
    if ([orderObjects count] == 0) {
        return -1;
    }
    [orderObjects sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"cardOrder" ascending:NO]]];
    FCCardSetCard *orderObject = [orderObjects lastObject];
    return [[orderObject cardOrder] intValue];
}
- (int)maxCardOrder {
    if (![self.hasCardOrder boolValue]) {
        return -1;
    }
    NSMutableArray *orderObjects = [NSMutableArray arrayWithArray:[[self cardsOrdered] allObjects]];
    if ([orderObjects count] == 0) {
        return -1;
    }
    [orderObjects sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"cardOrder" ascending:YES]]];
    FCCardSetCard *orderObject = [orderObjects lastObject];
    return [[orderObject cardOrder] intValue];
}
- (void)setupInitialCardOrder {
    [self setHasCardOrder:@YES];
    NSMutableArray *tempCards = [NSMutableArray arrayWithArray:[[self allCards] allObjects]];
    [tempCards sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"frontValue" ascending:YES selector:@selector(caseInsensitiveCompare:)]]];
    
    int i = 0;
    for (FCCard *card in tempCards) {
        // create the new card order
        FCCardSetCard *cardOrder = (FCCardSetCard *)[NSEntityDescription insertNewObjectForEntityForName:@"CardSetCard"
                                                                                  inManagedObjectContext:self.managedObjectContext];
        [cardOrder setCard:card];
        [cardOrder setCardSet:self];
        [cardOrder setCardOrder:[NSNumber numberWithInt:(i * 10000)]];
        i++;
    }
    [self.managedObjectContext save:nil];
}

- (void)openWebsite {
    if ([self isQuizletSet]) {
        NSString *url  = [NSString stringWithFormat:@"http://www.quizlet.com/%d/cardset", [self.quizletSetId intValue]];
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
    }
}

- (BOOL)isQuizletSet {
    return [self.quizletSetId intValue] > 0;
}

- (BOOL)isFlashcardExchangeSet {
    return NO;
//    return [self.flashcardExchangeSetId intValue] > 0;
}

- (BOOL)canSync {
    if ([self isFlashcardExchangeSet]) {
    } else if ([self isQuizletSet]) {
        if ([self.creatorUsername isEqualToString:[QuizletSync username]]) {
            return YES;
        }
    }
    return NO;
}

- (void)syncWithRemoteData:(ImportSet *)remoteSet withSyncController:(FCSync*)syncController {
    // if the remote date modified is newer than the local one, then update the set:
    if ([remoteSet.modifiedDate isLaterThan:self.dateModified]) {
        self.name = remoteSet.name;
        if ([syncController.websiteName isEqualToString:@"quizlet"]) {
            self.quizletSetId = [NSNumber numberWithInt:remoteSet.cardSetId];
        } else {
            // self.flashcardExchangeSetId = [NSNumber numberWithInt:remoteSet.cardSetId];
        }
        self.dateCreated = remoteSet.creationDate;
        self.dateModified = remoteSet.modifiedDate;
        
        NSString *imageUrl;
        
        // ---------------------------------------------------------------------
        // SECTION A: Make a list of all of the card IDs that we have downloaded
        NSMutableSet *newCardIds = [[NSMutableSet alloc] initWithCapacity:0];
        for (ImportTerm *term in remoteSet.flashCards) {
            [newCardIds addObject:[NSNumber numberWithInt:term.cardId]];
        }
        
        // ---------------------------------------------------------------------
        // SECTION B: Figure out which cards need to be removed from the set,
        // based on the card IDs downloaded from the website in Section A.
        
        // We are doing a few things:
        // (1) If it has an image, save the image.
        // (2) If it is NOT in the existing set, then remove it from the set
        // (3) If it IS in the existing set, then add it to a dictionary of the cards.
        NSMutableDictionary *existingCards = [[NSMutableDictionary alloc] initWithCapacity:0];
        NSMutableArray *cardsToBeRemoved = [[NSMutableArray alloc] initWithCapacity:0];
        BOOL isFound = NO;
        // go through each local card and determine which cards need to be removed:
        for (FCCard *localCard in [self allCards]) {
            // search for the card ID. If the newCardIds list does not contain any of the card's ID#s,
            // then we know that it doesn't exist on the site anymore, and needs to be deleted.
            isFound = NO;
            if ([syncController.websiteName isEqualToString:@"quizlet"]) {
                for (FCQuizletCardId *fcCardId in localCard.quizletCardIds) {
                    NSNumber *cardId = [NSNumber numberWithInt:[fcCardId.quizletCardId intValue]];
                    if ([newCardIds containsObject:cardId]) {
                        [existingCards setObject:localCard forKey:cardId]; // it is on the site - save the card
                        isFound = YES;
                    }
                }
            }
            if (!isFound) {
                // the card wasn't found in the list of cards downloaded.
                // Thus, it should be removed.
                // However, if the card's creation date was AFTER the last sync date,
                // then there is no need to remove it.
                if (self.lastSyncDate && [localCard.dateCreated isEarlierThan:self.lastSyncDate]) {
                    [cardsToBeRemoved addObject:localCard];
                }
            }
        }
        
        // ---------------------------------------------------------------------
        // SECTION C: Go through all of the cards that we downloaded and make local changes
        // (1) if the card does not exist in the existing cards, then create it.
        // (2) if the card DOES, then no need to create it.
        // (3) Update the card with the new card order.
        
        BOOL hasImage = NO;
        // divide the cards for the remote set into groups of 30 [for autoreleasepool]
        NSMutableArray *remoteSetCardsArray = [remoteSet.flashCards splitIntoSubarraysOfMaxSize:30];
        // for each of the cards on the site, update the local card or create a new one
        for (NSArray *flashcards in remoteSetCardsArray) {
            @autoreleasepool {
                NSManagedObjectContext *tempMOC2 = [FlashCardsCore tempMOC];
                
                FCCardSet *arLocalCardSet = (FCCardSet*)[tempMOC2 objectWithID:[self objectID]];
                FCCard *arLocalCard;
                
                for (ImportTerm *remoteTerm in flashcards) {
                    NSNumber *cardId = [NSNumber numberWithInt:remoteTerm.cardId];
                    BOOL isNew = NO;
                    if ([existingCards objectForKey:cardId]) {
                        // if the card exists, then we need to check to see if the local card (*arLocalCard)
                        // has been modified later than the remote card (*term)
                        arLocalCard = (FCCard*)[tempMOC2 objectWithID:[[existingCards objectForKey:cardId] objectID]];
                        FCLog(@"%@", arLocalCard.frontValue);
                        // If the LOCAL has been modified more recently than the REMOTE, CONTINUE:
                        if ([arLocalCard.dateModified isLaterThan:remoteTerm.modifiedDate]) {
                            continue;
                        }
                    } else {
                        // if the card doesn't exist, then create it:
                        isNew = YES;
                        
                        // create a new card. In the FlashCards Sync code, it tries to recycle a card
                        // from the cardsToBeRemoved list, but here we don't want to do that because
                        // just b/c a card is in that list, it doesn't mean that the cards will be totally
                        // deleted - just removed from this set.
                        arLocalCard = (FCCard *)[NSEntityDescription insertNewObjectForEntityForName:@"Card"
                                                                              inManagedObjectContext:tempMOC2];
                        [arLocalCardSet addCard:arLocalCard];
                        [arLocalCard setCollection:arLocalCardSet.collection];
                        [arLocalCard setShouldSync:arLocalCardSet.shouldSync];
                        [arLocalCard setIsSubscribed:arLocalCardSet.isSubscribed];
                        
                        // this is a new card, so we will need to add an FCE ID# to the card:
                        [arLocalCard setWebsiteCardId:remoteTerm.cardId
                                           forCardSet:arLocalCardSet
                                          withWebsite:syncController.websiteName];
                    }
                    NSString *imageSide = @"back";
                    if ([arLocalCardSet.didReverseFrontAndBack boolValue]) {
                        [arLocalCard setFrontValue:remoteTerm.importTermBackValue];
                        [arLocalCard setBackValue: remoteTerm.importTermFrontValue];
                    } else {
                        [arLocalCard setFrontValue:remoteTerm.importTermFrontValue];
                        [arLocalCard setBackValue: remoteTerm.importTermBackValue];
                    }
                    
                    // deal with the image:
                    hasImage = NO;
                    if (remoteTerm.backImageUrl) {
                        imageUrl = [NSString stringWithString:remoteTerm.backImageUrl];
                        if ([imageUrl length] > 0) {
                            [arLocalCardSet setHasImages:@YES];
                            [arLocalCard setHasImages:@YES];
                            
                            NSString *currentImageUrl;
                            if ([arLocalCardSet.didReverseFrontAndBack boolValue]) {
                                imageSide = @"front";
                                currentImageUrl = arLocalCard.frontImageURL;
                            } else {
                                imageSide = @"back";
                                currentImageUrl = arLocalCard.backImageURL;
                            }
                            if (![imageUrl isEqualToString:currentImageUrl]) {
                                hasImage = YES;
                                [syncController.imagesToDownload addObject:
                                 @{
                                 @"card" : arLocalCard,
                                 @"cardObjectId" : [arLocalCard objectID],
                                 @"cardSet" : arLocalCardSet,
                                 @"cardSetObjectId" : [arLocalCardSet objectID],
                                 @"url" : imageUrl,
                                 @"imageSide" : imageSide
                                 }];
                            }
                            
                        }
                    }
                    if (remoteTerm.frontImageUrl) {
                        imageUrl = [NSString stringWithString:remoteTerm.frontImageUrl];
                        if ([imageUrl length] > 0) {
                            [arLocalCardSet setHasImages:@YES];
                            [arLocalCard setHasImages:@YES];
                            
                            NSString *currentImageUrl;
                            if ([arLocalCardSet.didReverseFrontAndBack boolValue]) {
                                imageSide = @"back";
                                currentImageUrl = arLocalCard.backImageURL;
                            } else {
                                imageSide = @"front";
                                currentImageUrl = arLocalCard.frontImageURL;
                            }
                            if (![imageUrl isEqualToString:currentImageUrl]) {
                                hasImage = YES;
                                [syncController.imagesToDownload addObject:
                                 @{
                                 @"card" : arLocalCard,
                                 @"cardObjectId" : [arLocalCard objectID],
                                 @"cardSet" : arLocalCardSet,
                                 @"cardSetObjectId" : [arLocalCardSet objectID],
                                 @"url" : imageUrl,
                                 @"imageSide" : imageSide
                                 }];
                            }
                            
                        }
                    }
                    // no image, so we should remove it:
                    if (!hasImage) {
                        [arLocalCard setHasImages:[NSNumber numberWithBool:NO]];
                    }
                    
                    if (isNew) {
                        [arLocalCard setSyncStatus:[NSNumber numberWithInt:syncNoChange]];
                    }
                }
                [tempMOC2 save:nil];
                [tempMOC2 reset];
            } // autoreleasepool
        } // for
        
        // ---------------------------------------------------------------------
        // SECTION D: Remove any local cards that need to be removed since they
        // are no longer listed on the remote set.
        
        // NB: If a card has multiple ID#s, we should only remove it from the set.
        // otherwise, we can actually delete it.
        for (FCCard *localCard in cardsToBeRemoved) {
            int count = -1;
            if ([syncController.websiteName isEqualToString:@"quizlet"]) {
                count = (int)[localCard.quizletCardIds count];
            }
            if (count > 1) {
                // there is more than one FCE ID# - it is part of multiple sets!
                // just remove it from this set
                [self removeCard:localCard];
                // remove the ID related to the set
                if ([syncController.websiteName isEqualToString:@"quizlet"]) {
                    NSSet *cardIds = [NSSet setWithSet:localCard.quizletCardIds];
                    for (FCQuizletCardId *cId in cardIds) {
                        if ([cId.cardSet isEqual:self]) {
                            [localCard removeQuizletCardIdsObject:cId];
                        }
                    }
                }
            } else {
                // there is only one ID# - it is only part of one set!
                // delete the card
                [self removeCard:localCard];
                // we don't need to track that we deleted this card, because it
                // was deleted by the sync process, not by the user.
                [self removeCardsDeletedObject:localCard];
                [localCard removeFromMOC];
            }
        }
        
        // ---------------------------------------------------------------------
        // SECTION E: After deleting the cards we can now compare the cards' order.

        // 0. Make sure that the local card set has an order:
        if (![self.hasCardOrder boolValue]) {
            [self setupInitialCardOrder];
        }
        
        // 1. Make a list of the order of the cards from the website:
        NSMutableArray *remoteTerms = [NSMutableArray arrayWithArray:remoteSet.flashCards];
        [remoteTerms sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"importOrder" ascending:YES]]];
        
        // 2. Make a list of the order of the cards from the local db:
        for (FCCard *card in [self allCards]) {
            [card setCardOrder:@-2];
            [card setCurrentCardSet:self];
        }
        NSMutableArray *localCards = [NSMutableArray arrayWithArray:[[self allCards] allObjects]];
        [localCards sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"cardOrder" ascending:YES]]];
        NSMutableArray *localCardsData = [NSMutableArray arrayWithCapacity:0];
        for (FCCard *localCard in localCards) {
            int localCardId = [localCard cardIdForWebsite:syncController.websiteName forCardSet:self];
            BOOL isNew;
            if ([newCardIds containsObject:[NSNumber numberWithInt:localCardId]]) {
                isNew = NO;
            } else {
                isNew = YES;
            }
            [localCardsData addObject:@{
                                        @"card"   : localCard,
                                        @"isNew"  : (isNew ? @YES : @NO),
                                        @"isLocal": @YES,
                                        @"cardId" : [NSNumber numberWithInt:localCardId]
                                        }];
        }
        
        // 3. Make a dictionary of local cards according to their remote ID#:
        NSMutableDictionary *localCardsByRemoteId = [NSMutableDictionary dictionaryWithCapacity:0];
        for (FCCard *localCard in localCards) {
            int localCardId = [localCard cardIdForWebsite:syncController.websiteName forCardSet:self];
            [localCardsByRemoteId setObject:localCard forKey:[NSNumber numberWithInt:localCardId]];
        }
        
        // 4. Make a list of the new proper card order.
        NSMutableArray *remoteCardIdsProcessed = [NSMutableArray arrayWithCapacity:0];
        NSMutableArray *finalSet = [NSMutableArray arrayWithCapacity:0];
        int i = 0; // keeps track of where we are in the local cards list
        for (ImportTerm *remoteTerm in remoteTerms) {
            NSDictionary *localCardInfo;
            if (i < [localCards count]) {
                localCardInfo = [localCardsData objectAtIndex:i];
                while ([[localCardInfo objectForKey:@"isNew"] boolValue]) {
                    // The local card is new. It will **not** have a remote card
                    // id yet, because it hasn't yet been uploaded to the website.
                    [finalSet addObject:localCardInfo];
                    i++; // Increment i -- local card counter
                    // If we have surpassed the number of local cards then exit the loop
                    if (!(i < [localCards count])) {
                        break;
                    }
                    localCardInfo = [localCardsData objectAtIndex:i];
                }
                while ([remoteCardIdsProcessed containsObject:[localCardInfo objectForKey:@"cardId"]]) {
                    // we have previously processed this local card [e.g. if the
                    // local card moved from position 5 to position 2 on the website,
                    // so we have already moved it up]
                    i++;
                    if (!(i < [localCards count])) {
                        break;
                    }
                    localCardInfo = [localCardsData objectAtIndex:i];
                }
            }
            if (i < [localCards count]) {
                localCardInfo = [localCardsData objectAtIndex:i];
                int localCardId = [[localCardInfo objectForKey:@"cardId"] intValue];
                if (remoteTerm.cardId == localCardId) {
                    // The local & remote cards match -- should add the local
                    // card to the final set
                    [finalSet addObject:localCardInfo];
                    [remoteCardIdsProcessed addObject:[localCardInfo objectForKey:@"cardId"]];
                    i++; // increment i -- local card counter -- because this one passed.
                    continue;
                } else {
                    // The local & remote cards DO NOT match -- what to do?????
                    // At this point we will assume that the website is the 'truth'...
                    NSNumber *cardId = [NSNumber numberWithInt:remoteTerm.cardId];
                    [finalSet addObject:@{
                                          @"isLocal" : @NO,
                                          @"cardId" : cardId
                                          }];
                    [remoteCardIdsProcessed addObject:cardId];
                }
            } else {
                // we have passed the number of cards -- so just add all the remote ones
                // to the final card list
                NSNumber *cardId = [NSNumber numberWithInt:remoteTerm.cardId];
                [finalSet addObject:@{
                                      @"isLocal": @NO,
                                      @"cardId" : cardId
                                      }];
                [remoteCardIdsProcessed addObject:cardId];
            }
        }
        
        // 5. Save the changes to the card set:
        int j = 0; // counter for setting up card
        for (NSDictionary *info in finalSet) {
            FCCard *card = [info objectForKey:@"card"];
            if (!card) {
                card = [localCardsByRemoteId objectForKey:[info objectForKey:@"cardId"]];
            }
            if (!card) {
                continue;
            }
            [card setCardOrder:(j * 10000) forSet:self];
            j++;
        }
        
        // ---------------------------------------------------------------------
        // SECTION F: Set last sync date to NOW and save changes
        
        [self setLastSyncDate:[NSDate date]];
        [self.managedObjectContext save:nil];
    }
}

- (void)importCards:(NSArray *)cardList withImportMethod:(NSString *)importMethod {
    NSManagedObjectID *cardSetId = [self objectID];
    NSManagedObjectID *collectionId = [self.collection objectID];
    
    // count parentehses in our frontValue when seeing if it is a "long" card
    NSRegularExpression *replaceParens = [NSRegularExpression regularExpressionWithPattern:@"[\\(|\\]].*?[\\)|\\]]"
                                                                                   options:NSRegularExpressionCaseInsensitive
                                                                                     error:nil];
    
    NSMutableArray *cardListArray = [cardList splitIntoSubarraysOfMaxSize:30];
    NSManagedObjectContext *tempMOC = [FlashCardsCore tempMOC];
    [tempMOC performBlockAndWait:^{
        int numTotalCardsCount;
        BOOL hasFeatureUnlimitedCards = [FlashCardsCore hasFeature:@"UnlimitedCards"];

        FCCollection *theCollection;
        FCCardSet *theCardSet;
        FCCard *newCard;
        
        double eFactor;
        NSString *shortenedCardTitle;    // if we are working with a language, we should make sure that we don't
        
        BOOL shouldSetupCardId = YES;
        
        int totalCardsToImport = [cardList count];
        int totalCardsImported = 0;
        MBProgressHUD *HUD = [FlashCardsCore currentHUD];
        
        BOOL hasChangedCards = NO;
        
        for (NSArray *cardArray in cardListArray) {
            @autoreleasepool {
                theCollection = (FCCollection*)[tempMOC objectWithID:collectionId];
                theCardSet = (FCCardSet*)[tempMOC objectWithID:cardSetId];
                [theCardSet setHasCardOrder:@YES];
                
                for (ImportTerm *newTerm in cardArray) {
                    if (!hasFeatureUnlimitedCards) {
                        // if we simply get numTotalCards, it will check against the mainMOC!
                        // this won't check anything in the tempMOC.
                        numTotalCardsCount = [FlashCardsCore numTotalCards:tempMOC];
                        FCLog(@"Total cards: %d", numTotalCardsCount);
                        if (numTotalCardsCount >= maxCardsLite) {
                            continue;
                        }
                    }
                    FCCard *currentCard = [newTerm currentCardInMOC:tempMOC];
                    FCCard *finalCard = [newTerm finalCardInMOC:tempMOC];
                    
                    if (newTerm.finalCardId) {
                        // if the term has already been imported:
                        [finalCard setIsSubscribed:self.isSubscribed];
                        [finalCard setShouldSync:self.shouldSync];
                        
                        if (newTerm.cardId > 0) {
                            [finalCard setWebsiteCardId:newTerm.cardId
                                             forCardSet:theCardSet
                                            withWebsite:importMethod];
                        }
                        
                        [theCardSet addCard:finalCard];
                        
                        
                    } else if (!newTerm.isDuplicate || newTerm.mergeChoice == dontMergeCardsChoice) {
                        // Do not merge the cards - create a new one using the imported information
                        newCard = (FCCard *)[NSEntityDescription insertNewObjectForEntityForName:@"Card" inManagedObjectContext:tempMOC];
                        
                        [newCard setFrontValue:[newTerm.importTermFrontValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
                        [newCard setBackValue: [newTerm.importTermBackValue  stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
                        
                        [newCard setIsSubscribed:theCardSet.isSubscribed];
                        [newCard setShouldSync:theCardSet.shouldSync];
                        
                        if ([FlashCardsCore hasFeature:@"Photos"]) {
                            if (newTerm.frontImageData) {
                                if ([newTerm.frontImageData length] > 0) {
                                    [newCard setFrontImageData:newTerm.frontImageData];
                                    [newCard setFrontImageURL:newTerm.frontImageUrl];
                                    [self setHasImages:@YES];
                                }
                            }
                            if (newTerm.backImageData) {
                                if ([newTerm.backImageData length] > 0) {
                                    [newCard setBackImageData:newTerm.backImageData];
                                    [newCard setBackImageURL:newTerm.backImageUrl];
                                    [self setHasImages:@YES];
                                }
                            }
                        }
                        if ([FlashCardsCore hasFeature:@"Audio"]) {
                            if (newTerm.frontAudioData) {
                                if ([newTerm.frontAudioData length] > 0) {
                                    [newCard setFrontAudioData:newTerm.frontAudioData];
                                }
                            }
                            if (newTerm.backAudioData) {
                                if ([newTerm.backAudioData length] > 0) {
                                    [newCard setBackAudioData:newTerm.backAudioData];
                                }
                            }
                        }

                        eFactor = defaultEFactor;
                        // auto-adjust efactor depending on how long the card is:
                        shortenedCardTitle = [replaceParens stringByReplacingMatchesInString:newCard.frontValue
                                                                                     options:0
                                                                                       range:NSMakeRange(0, [newCard.frontValue length])
                                                                                withTemplate:@""];
                        if ([shortenedCardTitle length] > 10) {
                            eFactor -= 0.3;
                        } else if ([shortenedCardTitle length] > 18) {
                            eFactor -= 0.8;
                        }
                        [newCard setEFactor:[NSNumber numberWithDouble:eFactor]];
                        
                        // if the card ***is a duplicate*** and the card IDs in fact do match, but the user
                        // explicitly CHOSE not to merge them [which is why we're here!!], we need to make
                        // sure that the card doesn't have an ID.
                        if (newTerm.cardId > 0) {
                            shouldSetupCardId = YES;
                            if (newTerm.isDuplicate) {
                                if (newTerm.cardId == [currentCard cardIdForWebsite:importMethod
                                                                         forCardSet:(FCCardSet*)[tempMOC objectWithID:cardSetId]]) {
                                    shouldSetupCardId = NO;
                                }
                            }
                            if (shouldSetupCardId) {
                                [newCard setWebsiteCardId:newTerm.cardId
                                               forCardSet:theCardSet
                                              withWebsite:importMethod];
                            }
                        }
                        
                        [newCard setSyncStatus:[NSNumber numberWithInt:syncNoChange]];
                        
                        [theCardSet addCard:newCard];
                        [newCard setCollection:theCollection];
                        [newTerm setFinalCard:newCard];
                        if (newTerm.isDuplicate && newTerm.markRelated) {
                            [[newTerm finalCardInMOC:tempMOC] addRelatedCardsObject:currentCard];
                            [currentCard addRelatedCardsObject:[newTerm finalCardInMOC:tempMOC]];
                        }
                    } else {
                        // At this point, we are merging the cards -- i.e. adding newTerm.currentCard to the new card set.
                        
                        hasChangedCards = YES;
                        
                        if (newTerm.mergeChoice == mergeCardsChoice) {
                            if (newTerm.mergeCardFront == mergeCardNew) {
                                [currentCard setFrontValue:[newTerm.importTermFrontValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
                            } else if (newTerm.mergeCardFront == mergeCardEdit) {
                                [currentCard setFrontValue:[newTerm.editedTermFrontValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
                            }
                            if (newTerm.mergeCardBack == mergeCardNew) {
                                [currentCard setBackValue:[newTerm.importTermBackValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
                            } else if (newTerm.mergeCardBack == mergeCardEdit) {
                                [currentCard setBackValue: [newTerm.editedTermBackValue  stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
                            }
                            if (newTerm.frontImageData && [currentCard.frontImageData length] == 0) {
                                if ([newTerm.frontImageData length] > 0) {
                                    [currentCard setFrontImageData:newTerm.frontImageData];
                                    [currentCard setFrontImageURL:newTerm.frontImageUrl];
                                }
                            }
                            if (newTerm.backImageData && [currentCard.backImageData length] == 0) {
                                if ([newTerm.backImageData length] > 0) {
                                    [currentCard setBackImageData:newTerm.backImageData];
                                    [currentCard setBackImageURL:newTerm.backImageUrl];
                                }
                            }
                        } else if (newTerm.mergeChoice == mergeAndEditCardsChoice) {
                            [currentCard setFrontValue:[newTerm.editedTermFrontValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
                            [currentCard setBackValue: [newTerm.editedTermBackValue  stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
                        } else {
                            NSLog(@"For some reason, we are not doing anything with this card...");
                        }
                        if (!newTerm.currentCardId) {
                            NSLog(@"No current card...");
                        }
                        if (newTerm.resetStatistics) {
                            [currentCard resetStatistics];
                        }
                        
                        if (newTerm.cardId > 0) {
                            [currentCard setWebsiteCardId:newTerm.cardId
                                               forCardSet:theCardSet
                                              withWebsite:importMethod];
                        }
                        // if we are syncing the cards, and anything has changed as a result of merging cards,
                        // then we should mark it to be synced.
                        if ([self.shouldSync boolValue] && (currentCard.frontValue != newTerm.importTermFrontValue || currentCard.backValue != newTerm.importTermBackValue)) {
                            [currentCard setSyncStatus:[NSNumber numberWithInt:syncChanged]];
                        }
                        
                        [newTerm setFinalCard:currentCard];
                        
                        [[newTerm finalCardInMOC:tempMOC] setIsSubscribed:self.isSubscribed];
                        [[newTerm finalCardInMOC:tempMOC] setShouldSync:self.shouldSync];
                        
                        // If the card is already a part of the card set you are adding it to, we won't want to
                        // add it to anything.
                        if (![[currentCard cardSet] containsObject:[tempMOC objectWithID:cardSetId]]) {
                            // Add the current card set to the card you're merging with:
                            [theCardSet addCard:[newTerm finalCardInMOC:tempMOC]];
                        }
                    }
                    
                    totalCardsImported++;
                    if (HUD && totalCardsToImport > 0) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            if (totalCardsToImport < 1) {
                                return;
                            }
                            float progress = ((float)totalCardsImported / (float)totalCardsToImport);
                            if (!HUD) {
                                return;
                            }
                            [HUD setMode:MBProgressHUDModeDeterminate];
                            [HUD setProgress:progress];
                        });

                    }
                }
                NSError *error;
                if (![tempMOC save:&error]) {
                    FCLog(@"%@", error);
                }
                [tempMOC save:nil];
                [FlashCardsCore saveMainMOC:NO];
                [tempMOC reset];
            } // autoreleasepool
        } // for
        if (hasChangedCards) {
            SyncController *controller = [[FlashCardsCore appDelegate] syncController];
            if (controller && [self.shouldSync boolValue]) {
                if ([self isQuizletSet]) {
                    [controller setQuizletDidChange:YES];
                }
            }
        }
        [FlashCardsCore saveMainMOC:NO
                     andRunSelector:@selector(restartOfflineTTSQueue)
                         onDelegate:[FlashCardsCore appDelegate]
                       onMainThread:NO];
        if (HUD) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!HUD) {
                    return;
                }
                [HUD setMode:MBProgressHUDModeIndeterminate];
            });
        }
    }];
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

- (void)removeFromMOC {
    // delete all cards which can be deleted:
    // NB: We extract the array of cards out of the card set b/c it seems 
    // that by working directly on the card set, some cards don't end up deleted!
    for (FCCard *card in [self.cards allObjects]) {
        if (!card) {
            continue;
        }
        if ([card.cardSet count] > 1) {
            // remove the card from this card set:
            [card removeCardSetObject:self];
            continue;
        }
        [self.managedObjectContext deleteObject:card];
    }
    
    // remove all cards from the card set:
    [self removeAllCards];
    
    // delete the card set:
    [self.managedObjectContext deleteObject:self];
}

- (void)makeDeletedObject {
    // mark all cards as deleted which can be:
    // NB: We extract the array of cards out of the card set b/c it seems
    // that by working directly on the card set, some cards don't end up deleted!
    for (FCCard *card in [self.cards allObjects]) {
        if (!card) {
            continue;
        }
        if ([card cardSetsCount] > 1) {
            // it is in multiple sets - don't actually set as deleted
            continue;
        }
        // it is only in one set, which is being deleted: set it as a deleted object
        [card setIsDeletedObject:[NSNumber numberWithBool:YES]];
    }
    [self setIsDeletedObject:[NSNumber numberWithBool:YES]];
}

- (int)cardsCount {
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"isDeletedObject = NO and %@ in cardSet", self]];
    [fetchRequest setEntity:[NSEntityDescription entityForName:@"Card" inManagedObjectContext:self.managedObjectContext]];
    return (int)[self.managedObjectContext countForFetchRequest:fetchRequest error:nil];
}
- (NSSet*)allCards {
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"isDeletedObject = NO and %@ in cardSet", self]];
    [fetchRequest setEntity:[NSEntityDescription entityForName:@"Card" inManagedObjectContext:self.managedObjectContext]];
    return [NSSet setWithArray:[self.managedObjectContext executeFetchRequest:fetchRequest error:nil]];
}
- (NSSet*)allCardsIncludingDeletedOnes {
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"%@ in cardSet", self]];
    [fetchRequest setEntity:[NSEntityDescription entityForName:@"Card" inManagedObjectContext:self.managedObjectContext]];
    return [NSSet setWithArray:[self.managedObjectContext executeFetchRequest:fetchRequest error:nil]];
}
- (NSMutableArray*)allCardsInOrder {
    if (![self.hasCardOrder boolValue]) {
        [self setupInitialCardOrder];
    }
    NSMutableArray *cards = [NSMutableArray arrayWithArray:[[self allCards] allObjects]];
    for (FCCard *card in cards) {
        [card setCardOrder:@-2];
        [card setCurrentCardSet:self];
    }
    [cards sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"cardOrder" ascending:YES]]];
    return cards;
}

- (BOOL)allCardsHaveIdsForWebsite:(NSString*)website {
    if ([website isEqualToString:@"quizlet"]) {
        BOOL isFound = NO;
        for (FCCard *card in [self allCards]) {
            isFound = NO;
            for (FCQuizletCardId *cardId in card.quizletCardIds) {
                if ([[cardId cardSet] isEqual:self]) {
                    isFound = YES;
                }
            }
            // if this card doesn't have an FCE ID#, then we should say that not all cards have FCE ID#s
            if (!isFound) {
                return NO;
            }
        }
        return YES;
    }
    return YES;
}

- (NSMutableSet*)cardsWithoutIdsForWebsite:(NSString*)website {
    NSMutableSet *returnSet = [NSMutableSet setWithCapacity:0];
    if ([website isEqualToString:@"quizlet"]) {
        BOOL isFound = NO;
        for (FCCard *card in [self allCards]) {
            isFound = NO;
            for (FCQuizletCardId *cardId in card.quizletCardIds) {
                if ([[cardId cardSet] isEqual:self]) {
                    isFound = YES;
                }
            }
            // if this card doesn't have an FCE ID#, then we should add it to the
            // list of cards w/o FCE ID#s to return
            if (!isFound) {
                [returnSet addObject:card];
            }
        }
        return returnSet;
    }
    return returnSet;
}

- (void)addCard:(FCCard*)card {
    [self addCardsObject:card];
    if (self.collection.masterCardSet && ![self.isMasterCardSet boolValue]) {
        if (![self.collection.masterCardSet.cards containsObject:card]) {
            [self.collection.masterCardSet addCard:card];
        }
    }
    if ([self.hasCardOrder boolValue] && ![self.isMasterCardSet boolValue]) {
        int cardOrder = [card cardSetOrderInSet:self];
        if (cardOrder < 0) {
            [card addCardOrderForSet:self];
        }
    }
}

- (void)removeCard:(FCCard *)card {
    [self removeCard:card fromThisSetOnly:NO];
}

- (void)removeCard:(FCCard*)card fromThisSetOnly:(BOOL)removeFromThisSetOnly {
    [self removeCardsObject:card];
    [self addCardsDeletedObject:card];
    if (!removeFromThisSetOnly && self.collection.masterCardSet && ![self.isMasterCardSet boolValue]) {
        // if it's not a part of any other card sets, remove it from the collection too:
        if ([card cardSetsCount] == 0) {
            [self.collection.masterCardSet removeCard:card];
        }
    }
}

- (void)removeAllCards {
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"%@ in cardSet", self]];
    [fetchRequest setEntity:[NSEntityDescription entityForName:@"Card" inManagedObjectContext:self.managedObjectContext]];
    NSSet *cardsList = [NSSet setWithArray:[self.managedObjectContext executeFetchRequest:fetchRequest error:nil]];

    for (FCCard *card in cardsList) {
        [self removeCard:card];
    }
}

- (void)setCardsList:(NSSet*)_cards {
    for (FCCard *card in _cards) {
        [self addCard:card];
    }
}

# pragma mark - Override Methods

-(void)setHasCardOrder:(NSNumber *)_hasCardOrder {
    if ([self hasCardOrder] && [[self hasCardOrder] isEqualToNumber:_hasCardOrder]) {
        return;
    }
    
    [self willChangeValueForKey:@"hasCardOrder"];
    [self setPrimitiveValue:_hasCardOrder forKey:@"hasCardOrder"];
    [self didChangeValueForKey:@"hasCardOrder"];
    
}

-(void)setShouldSync:(NSNumber *)_shouldSync {
    if ([self shouldSync] && [[self shouldSync] isEqualToNumber:_shouldSync]) {
        return;
    }
    
    // Adjust the e-factor based on the word type: (cognate, normal, or false cognate)
    BOOL oldSyncValue = [self.shouldSync boolValue];
    BOOL newSyncValue = [_shouldSync boolValue];
    if (oldSyncValue != newSyncValue) {
        if (newSyncValue) {
            // If it should sync, set all cards to sync:
            for (FCCard *card in self.cards) {
                [card setShouldSync:[NSNumber numberWithBool:YES]];
            }
        } else {
            // If it shouldn't sync, then make sure that all the cards are not going to sync:
            BOOL shouldSync = NO;
            for (FCCard *card in self.cards) {
                shouldSync = NO;
                for (FCCardSet *set in card.cardSet) {
                    if ([set isEqual:self]) {
                        continue;
                    }
                    if ([set.shouldSync boolValue]) {
                        // it should still sync
                        shouldSync = YES;
                    }
                }
                if (!shouldSync) {
                    [card setShouldSync:[NSNumber numberWithBool:NO]];
                }
            }
        }
    }
    [self willChangeValueForKey:@"shouldSync"];
    [self setPrimitiveValue:_shouldSync forKey:@"shouldSync"];
    [self didChangeValueForKey:@"shouldSync"];
    
}

-(void)setIsSubscribed:(NSNumber *)_isSubscribed {
    if ([self isSubscribed] && [[self isSubscribed] isEqualToNumber:_isSubscribed]) {
        return;
    }
    
    // Adjust the e-factor based on the word type: (cognate, normal, or false cognate)
    BOOL oldValue = [self.isSubscribed boolValue];
    BOOL newValue = [_isSubscribed boolValue];
    if (oldValue != newValue) {
        if (newValue) {
            // If it should sync, set all cards to sync:
            NSString *website = @"quizlet";
            int cardId;
            for (FCCard *card in [self allCards]) {
                [card setIsSubscribed:[NSNumber numberWithBool:YES]];
                // remove from all other sets:
                [card removeCardSet:card.cardSet];
                [card addCardSetObject:self];
                // also remove all other FCE ID#s, except for those for the currently-syncing website:
                cardId = [card cardIdForWebsite:website forCardSet:self];
                [card removeFlashcardExchangeCardIds:card.flashcardExchangeCardIds];
                [card removeQuizletCardIds:card.quizletCardIds];
                [card setWebsiteCardId:cardId forCardSet:self withWebsite:website];
            }
        } else {
            // If it shouldn't sync, then make sure that all the cards are not going to sync:
            BOOL isSubscribed = NO;
            for (FCCard *card in [self allCards]) {
                isSubscribed = NO;
                for (FCCardSet *set in card.cardSet) {
                    if ([set isEqual:self]) {
                        continue;
                    }
                    if ([set.isSubscribed boolValue]) {
                        // it should still sync
                        isSubscribed = YES;
                    }
                }
                if (!isSubscribed) {
                    [card setIsSubscribed:[NSNumber numberWithBool:NO]];
                }
            }
        }
    }
    [self willChangeValueForKey:@"isSubscribed"];
    [self setPrimitiveValue:_isSubscribed forKey:@"isSubscribed"];
    [self didChangeValueForKey:@"isSubscribed"];
    
}

- (void)setName:(NSString *)_name {
    if ([self name] && [[self name] isEqualToString:_name]) {
        return;
    }
    
    [self setDateModified:[NSDate date]];

    BOOL didChange = NO;
    if (![self.name isEqualToString:_name]) {
        didChange = YES;
    }
    [self willChangeValueForKey:@"name"];
    [self setPrimitiveValue:_name forKey:@"name"];
    if (didChange) {
        [self setSyncStatus:[NSNumber numberWithInt:syncChanged]];
    }
    [self didChangeValueForKey:@"name"];
}

- (void)setFlashcardExchangeSetId:(NSNumber *)_flashcardExchangeSetId {
    if ([self flashcardExchangeSetId] && [[self flashcardExchangeSetId] isEqualToNumber:_flashcardExchangeSetId]) {
        return;
    }
    
    [self willChangeValueForKey:@"flashcardExchangeSetId"];
    [self setPrimitiveValue:_flashcardExchangeSetId forKey:@"flashcardExchangeSetId"];
    [self didChangeValueForKey:@"flashcardExchangeSetId"];
}

- (void)setQuizletSetId:(NSNumber *)_quizletSetId {
    if ([self quizletSetId] && [[self quizletSetId] isEqualToNumber:_quizletSetId]) {
        return;
    }
    
    [self willChangeValueForKey:@"quizletSetId"];
    [self setPrimitiveValue:_quizletSetId forKey:@"quizletSetId"];
    [self didChangeValueForKey:@"quizletSetId"];
}

- (void)setDateCreated:(NSDate *)_dateCreated {
    if ([self dateCreated] && [[self dateCreated] isEqualToDate:_dateCreated]) {
        return;
    }
    
    [self willChangeValueForKey:@"dateCreated"];
    [self setPrimitiveValue:_dateCreated forKey:@"dateCreated"];
    [self didChangeValueForKey:@"dateCreated"];
}

- (void)setDateModified:(NSDate *)_dateModified {
    if ([self dateModified] && [[self dateModified] isEqualToDate:_dateModified]) {
        return;
    }
    
    [self willChangeValueForKey:@"dateModified"];
    [self setPrimitiveValue:_dateModified forKey:@"dateModified"];
    [self didChangeValueForKey:@"dateModified"];
}



@end
