//
//  ImportTerm.h
//  FlashCards
//
//  Created by Jason Lustig on 6/8/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

@class FCCard;
@class FCCollection;
@class FCCardSet;
@class ImportSet;

#pragma -
# pragma mark ImportTerm

@interface ImportTerm : NSObject {
    
    NSDate *modifiedDate;
    
    BOOL isDuplicate;
    BOOL isDuplicateChecked;
    BOOL isExactDuplicate;
    BOOL matchesOnlineCardId;
    BOOL markRelated;
    BOOL resetStatistics;
    BOOL shouldImportTerm;
    int mergeChoice;
    int importOrder;
    int cardId;
    int wordType;
    
    NSString *importTermFrontValue;
    NSString *importTermBackValue;
    NSString *editedTermFrontValue;
    NSString *editedTermBackValue;
    
    NSString *frontImageUrl;
    NSString *backImageUrl;
    
    NSData *frontImageData;
    NSData *backImageData;
    
    NSData *frontAudioData;
    NSData *backAudioData;
    
    int mergeCardBack;
    int mergeCardFront;
    
    NSManagedObjectID *currentCardId;
    NSManagedObjectID *finalCardId;
    
    ImportSet *importSet;
    
    NSMutableSet *relatedTerms;
}

+ (id) alloc;
- (id) init;

// duplicates functions
- (bool) checkExactDuplicatesOfFront:(FCCard*)card;
- (bool) checkExactDuplicatesOfBack:(FCCard*)card;
- (bool) checkExactDuplicatesOfCard:(FCCard*)card;
- (bool) isPotentialMatchBetterThanCurrentMatch:(FCCard*)potentialCardMatch;

- (bool) hasImages;

- (void) setCurrentCard:(FCCard *)card;
- (FCCard *) currentCardInMOC:(NSManagedObjectContext*)moc;
- (void) setFinalCard:(FCCard*)card;
- (FCCard *) finalCardInMOC:(NSManagedObjectContext*)moc;

@property (nonatomic, strong) NSDate *modifiedDate;
@property (nonatomic, assign) BOOL isDuplicate;
@property (nonatomic, assign) BOOL isDuplicateChecked;
@property (nonatomic, assign) BOOL isExactDuplicate;
@property (nonatomic, assign) BOOL matchesOnlineCardId;
@property (nonatomic, assign) BOOL markRelated;
@property (nonatomic, assign) BOOL resetStatistics;
@property (nonatomic, assign) BOOL shouldImportTerm;
@property (nonatomic, assign) int mergeChoice;
@property (nonatomic, assign) int mergeCardFront;
@property (nonatomic, assign) int mergeCardBack;
@property (nonatomic, assign) int importOrder;
@property (nonatomic, assign) int cardId;
@property (nonatomic, assign) int wordType;
@property (nonatomic, strong) NSString *importTermFrontValue;
@property (nonatomic, strong) NSString *importTermBackValue;
@property (nonatomic, strong) NSString *editedTermFrontValue;
@property (nonatomic, strong) NSString *editedTermBackValue;
@property (nonatomic, strong) NSString *frontImageUrl;
@property (nonatomic, strong) NSString *backImageUrl;
@property (nonatomic, strong) NSData *frontImageData;
@property (nonatomic, strong) NSData *backImageData;

@property (nonatomic, strong) NSData *frontAudioData;
@property (nonatomic, strong) NSData *backAudioData;

@property (nonatomic, strong) NSManagedObjectID *currentCardId;
@property (nonatomic, strong) NSManagedObjectID *finalCardId;

@property (nonatomic, strong) ImportSet *importSet;


@property (nonatomic, strong) NSMutableSet *relatedTerms;

@end

# pragma mark -
# pragma mark NSMutableArray

@interface NSMutableArray (ImportTermArray)

// Duplicate cards functions
- (int)findDuplicatesInCollection:(FCCollection *)collection withImportMethod:(NSString*)importMethod;
- (int)numDuplicateCards;
- (BOOL)allDuplicateCardsChecked;
- (NSMutableArray *)duplicateCards:(BOOL)willSync withWebsite:(NSString*)website importingIntoSet:(FCCardSet*)cardSet;

+ (void)splitTerms:(NSArray *)terms splitKey:(NSString *)splitKey finalArray:(NSMutableArray *)finalArray;

@end

