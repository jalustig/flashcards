//
//  Collection.h
//  FlashCards
//
//  Created by Jason Lustig on 5/27/10.
//  Copyright 2010 Jason Lustig. All rights reserved.
//

#import <CoreData/CoreData.h>

@class CardSet;

@interface Collection :  NSManagedObject  
{
}

@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSSet* cardSets;

@end


@interface Collection (CoreDataGeneratedAccessors)
- (void)addCardSetsObject:(CardSet *)value;
- (void)removeCardSetsObject:(CardSet *)value;
- (void)addCardSets:(NSSet *)value;
- (void)removeCardSets:(NSSet *)value;

@end

