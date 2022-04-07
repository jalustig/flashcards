//
//  FlashcardExchangeCardId.h
//  FlashCards
//
//  Created by Jason Lustig on 9/27/12.
//  Copyright (c) 2012 Jason Lustig. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "TICoreDataSync.h"

@class FCCard, FCCardSet;

@interface FCFlashcardExchangeCardId : TICDSSynchronizedManagedObject

@property (nonatomic, strong) NSNumber* flashcardExchangeCardId;
@property (nonatomic, strong) FCCard *card;
@property (nonatomic, strong) FCCardSet *cardSet;

@end
