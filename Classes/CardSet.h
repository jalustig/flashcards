//
//  CardSet.h
//  FlashCards
//
//  Created by Jason Lustig on 5/27/10.
//  Copyright 2010 Jason Lustig. All rights reserved.
//

#import <CoreData/CoreData.h>


@interface CardSet :  NSManagedObject  
{
}

@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSSet* cards;
@property (nonatomic, retain) NSManagedObject * collection;

@end


@interface CardSet (CoreDataGeneratedAccessors)
- (void)addCardsObject:(NSManagedObject *)value;
- (void)removeCardsObject:(NSManagedObject *)value;
- (void)addCards:(NSSet *)value;
- (void)removeCards:(NSSet *)value;

@end

