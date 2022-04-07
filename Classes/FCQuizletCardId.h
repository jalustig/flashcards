//
//  FCQuizletCardId.h
//  FlashCards
//
//  Created by Jason Lustig on 9/28/11.
//  Copyright (c) 2011 Jason Lustig. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "TICoreDataSync.h"

@class FCCard, FCCardSet;

@interface FCQuizletCardId : TICDSSynchronizedManagedObject

@property (nonatomic, strong) NSNumber * quizletCardId;
@property (nonatomic, strong) FCCardSet *cardSet;
@property (nonatomic, strong) FCCard *card;

@end
