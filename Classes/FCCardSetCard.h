//
//  FCCardSetCard.h
//  FlashCards
//
//  Created by Jason Lustig on 6/7/13.
//  Copyright (c) 2013 Jason Lustig. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class FCCard, FCCardSet;

@interface FCCardSetCard : TICDSSynchronizedManagedObject

@property (nonatomic, retain) NSNumber * cardOrder;
@property (nonatomic, retain) FCCard *card;
@property (nonatomic, retain) FCCardSet *cardSet;

@end
