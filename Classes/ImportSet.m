//
//  ImportSet.m
//  FlashCards
//
//  Created by Jason Lustig on 3/16/11.
//  Copyright 2011-2014 Jason Lustig Lustig. All rights reserved.
//

#import "ImportSet.h"

#import "ImportTerm.h"
#import "NSString+XMLEntities.h"
#import "FlashCardsCore.h"

#import "FCCardSet.h"

#import "QuizletSync.h"
#import "QuizletRestClient.h"

#import "NSString+TimeZone.h"

@implementation ImportSet

@synthesize cardSetId;
@synthesize willSubscribe, willSync;
@synthesize name, description, tags, hasImages, isPrivateSet;
@synthesize creator;
@synthesize creationDate, modifiedDate;
@synthesize flashCards, _numberCards;
@synthesize userCanEditOnline;
@synthesize password;
@synthesize editable;
@synthesize cardSetCreateMode;
@synthesize matchCardSetChecked;
@synthesize matchCardSetId;
@synthesize imagesDownloaded, duplicatesChecked, isSaved, isFiltered;
@synthesize frontLanguage, backLanguage;
@synthesize delegate;
@synthesize importMethod;
@synthesize reverseFrontAndBackOfCards;

+ (NSMutableArray*) convertFCPPFileFormat:(NSDictionary*)fileData {
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
    NSDictionary *cardData;
    ImportTerm *term;
    // go through all of the cards and create the objects
    for (id key in [fileData objectForKey:@"cards"]) {
        cardData = [[fileData objectForKey:@"cards"] objectForKey:key];
        term = [[ImportTerm alloc] init];
        [term setImportTermFrontValue:[cardData valueForKey:@"fv"]];
        [term setImportTermBackValue:[cardData valueForKey:@"bv"]];
        
        if ([cardData objectForKey:@"fid"]) {
            if ([[cardData objectForKey:@"fid"] length] > 0) {
                [term setFrontImageData:[NSData dataWithData:[cardData objectForKey:@"fid"]]];
            }
        }
        if ([cardData objectForKey:@"bid"]) {
            if ([[cardData objectForKey:@"bid"] length] > 0) {
                [term setBackImageData:[NSData dataWithData:[cardData objectForKey:@"bid"]]];
            }
        }
        
        if ([cardData objectForKey:@"fad"]) {
            [term setFrontAudioData:[cardData objectForKey:@"fad"]];
        }
        if ([cardData objectForKey:@"bad"]) {
            [term setBackAudioData:[cardData objectForKey:@"bad"]];
        }
        
        [term setWordType:[[cardData objectForKey:@"wt"] intValue]];
     //   [[[fileData objectForKey:@"cards"] objectForKey:key] setObject:term forKey:@"termObject"];
        [cards setObject:term forKey:key];
    }
    
    // go through all of the cards and set up which are related to one another:
    for (id key in [fileData objectForKey:@"cards"]) {
        cardData = [[fileData objectForKey:@"cards"] objectForKey:key];
        term = [cards objectForKey:key];
        for (NSString *cardId in [cardData objectForKey:@"rcs"]) {
            ImportTerm *relatedTerm = [cards objectForKey:cardId];
            if (!relatedTerm) {
                continue;
            }
            [term.relatedTerms addObject:relatedTerm];
        }
    }
    
    NSMutableArray *cardSets = [[NSMutableArray alloc] initWithCapacity:0];
    ImportSet *set;
    ImportTerm *theTerm;
    for (NSDictionary *data in [fileData objectForKey:@"cardSets"]) {
        set = [[ImportSet alloc] init];
        [set setName:[data valueForKey:@"name"]];
        
        for (NSString *cardId in [data objectForKey:@"cards"]) {
            theTerm = [cards objectForKey:cardId];
            if ([theTerm hasImages]) {
                [set setHasImages:YES];
            }
            if (!theTerm) {
                continue;
            }
            [set.flashCards addObject:theTerm];
            [theTerm setImportSet:set];
        }
        
        [cardSets addObject:set];
    }
    if ([cardSets count] == 0) {
        set = [[ImportSet alloc] init];
        [set setName:[[fileData objectForKey:@"collection"] valueForKey:@"name"]];
        
        for (ImportTerm *term in [cards allValues]) {
            if (!term) {
                continue;
            }
            [set.flashCards addObject:term];
        }
        
        [cardSets addObject:set];
    }
    return cardSets;
}

+ (id) alloc {
    return [super alloc];
}
- (id) init {
    if ((self = [super init])) {
        cardSetId = -1;
        willSubscribe = NO;
        willSync = NO;
        _numberCards = -1;
        tags = [[NSMutableArray alloc] initWithCapacity:0];
        flashCards = [[NSMutableArray alloc] initWithCapacity:0];
        hasImages = NO;
        isPrivateSet = NO;
        matchCardSetId = nil;
        matchCardSetChecked = NO;
        cardSetCreateMode = modeCreate;
        imagesDownloaded = NO;
        duplicatesChecked = NO;
        isSaved = NO;
        isFiltered = NO;
        frontLanguage = nil;
        backLanguage = nil;
        userCanEditOnline = NO;
        editable = @"";
        reverseFrontAndBackOfCards = NO;
    }
    return self;
}

- (id) initWithQuizletData:(NSDictionary*)setData {
    if ((self = [self init])) {

        self.importMethod = @"quizlet";

        self.name = [[setData valueForKey:@"title"] stringByDecodingXMLEntities];
        self.description = [[setData valueForKey:@"description"] stringByDecodingXMLEntities];
        [self setCreator:[[setData valueForKey:@"creator"] stringByDecodingXMLEntities]];
        self.creationDate = [NSDate dateWithTimeIntervalSince1970:[[setData valueForKey:@"created_date"] intValue]];
        self.modifiedDate = [NSDate dateWithTimeIntervalSince1970:[[setData valueForKey:@"modified_date"] intValue]];
        self.cardSetId = [[setData objectForKey:@"id"] intValue];
        self.tags = (NSMutableArray*)[setData objectForKey:@"subjects"];
        self.hasImages = [[setData objectForKey:@"has_images"] boolValue];
        if ([[setData objectForKey:@"is_private"] boolValue]) {
            self.isPrivateSet = YES;
        }
        [self setNumberCards:[[setData objectForKey:@"term_count"] intValue]];
        
        self.frontLanguage = [FlashCardsCore getLanguageAcronymFor:[setData valueForKey:@"lang_front"] fromKey:@"quizletAcronym" toKey:@"googleAcronym"];
        self.backLanguage  = [FlashCardsCore getLanguageAcronymFor:[setData valueForKey:@"lang_back"]  fromKey:@"quizletAcronym" toKey:@"googleAcronym"];
        if ([setData objectForKey:@"cards"] && [(NSArray*)[setData objectForKey:@"cards"] count] > 0) {
            for (NSDictionary *c in (NSArray*)[setData objectForKey:@"cards"]) {
                ImportTerm *term = [[ImportTerm alloc] init];
                term.importTermFrontValue =[c valueForKey:@"front"];
                term.importTermBackValue = [c valueForKey:@"back"];
                if ([c valueForKey:@"image_back"] && ![[c valueForKey:@"image_back"] isKindOfClass:[NSNull class]]) {
                    term.backImageUrl = [c valueForKey:@"image_back"];
                }
                term.cardId = [(NSNumber*)[c objectForKey:@"id"] intValue];
                [self.flashCards addObject:term];
            }
        }
        
        self.editable = [setData valueForKey:@"editable"];
        if ([QuizletRestClient isLoggedIn] && [creator isEqualToString:[QuizletSync username]]) {
            self.userCanEditOnline = YES;
        }

    }
    return self;
}


- (id) initWithDatafile:(NSDictionary*)setData {
    if ((self = [self init])) {
        self.name = [[setData valueForKey:@"title"] stringByDecodingXMLEntities];
        self.description = [[setData valueForKey:@"description"] stringByDecodingXMLEntities];
        [self setCreator:[[setData valueForKey:@"creator"] stringByDecodingXMLEntities]];
        self.creationDate = [NSDate date];
        self.cardSetId = 0;
        self.tags = [NSMutableArray arrayWithCapacity:0];
        self.isPrivateSet = NO;
        [self setNumberCards:(int)[flashCards count]];
        self.hasImages = NO;
//        for (ImportTerm *term in self.flashCards) {
            
//        }
        self.hasImages = [[setData objectForKey:@"has_images"] boolValue];
    }
    return self;
}


- (void)setNumberCards:(int)num {
    self._numberCards = num;
}

- (int)numberCards {
    if (self._numberCards < 0) {
        return (int)[flashCards count];
    }
    return self._numberCards;
}

- (void) setFlashCards:(NSMutableArray *)_flashCards {
    flashCards = _flashCards;
    for (ImportTerm *term in self.flashCards) {
        [term setImportSet:self];
    }
}

- (void)downloadImages {

    ImportTerm *term;
    NSData *data;
    
    int totalImages = 0;
    for (int i = 0; i < [flashCards count]; i++) {
        term = [flashCards objectAtIndex:i];
        if ([term.frontImageUrl length] > 0) {
            totalImages++;
        }
        if ([term.backImageUrl length] > 0) {
            totalImages++;
        }
    }
    int location = 0;
    for (int i = 0; i < [flashCards count]; i++) {
        term = [flashCards objectAtIndex:i];
        if ([term.frontImageUrl length] > 0) {
            // download the front image:
            location++;
            [self performSelectorOnMainThread:@selector(setHUDLabel:)
                                   withObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Downloading Images: %d of %d", @"Import", @"HUD"), location, totalImages] waitUntilDone:NO];
            data = [NSData dataWithContentsOfURL:[NSURL URLWithString:term.frontImageUrl]];
            if ([term.frontImageUrl hasSuffix:@".png"]) {
                // it's a PNG:
                UIImage *image = [UIImage imageWithData:data];
                data = [NSData dataWithData:UIImageJPEGRepresentation(image, 0.9)];
            }
            term.frontImageData = data;
        } else {
            term.frontImageData = nil;
        }
        if ([term.backImageUrl length] > 0) {
            location++;
            [self performSelectorOnMainThread:@selector(setHUDLabel:)
                                   withObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Downloading Images: %d of %d", @"Import", @"HUD"), location, totalImages] waitUntilDone:NO];
            data = [NSData dataWithContentsOfURL:[NSURL URLWithString:term.backImageUrl]];
            if ([term.backImageUrl hasSuffix:@".png"]) {
                // it's a PNG:
                UIImage *image = [UIImage imageWithData:data];
                data = [NSData dataWithData:UIImageJPEGRepresentation(image, 0.9)];
            }
            term.backImageData = data;
        } else {
            term.backImageData = nil;
        }
    }

    if (delegate && [delegate respondsToSelector:@selector(imagesDidDownload:)]) {
        [delegate imagesDidDownload:self];
    }
}

- (void)setHUDLabel:(NSString*)string {
    if (delegate && [delegate respondsToSelector:@selector(setHUDLabel:)]) {
        [delegate performSelector:@selector(setHUDLabel:) withObject:string];
    }
}

- (void) setMatchCardSet:(FCCardSet*)match {
    [self setMatchCardSetId:[match objectID]];
}

- (void)setCreator:(NSString *)_creator {
    creator = _creator;
    if ([self.importMethod isEqualToString:@"quizlet"] && [QuizletRestClient isLoggedIn] && [creator isEqualToString:[QuizletSync username]]) {
        self.userCanEditOnline = YES;
    }
}

- (FCCardSet*)matchCardSetInMOC:(NSManagedObjectContext*)moc {
    return (FCCardSet*)[moc objectWithID:self.matchCardSetId];
}

@end
