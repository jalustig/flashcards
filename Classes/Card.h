//
//  Card.h
//  FlashCards
//
//  Created by Jason Lustig on 5/27/10.
//  Copyright 2010 Jason Lustig. All rights reserved.
//

#import <CoreData/CoreData.h>

@class CardSet;

@interface Card :  NSManagedObject  
{
}

@property (nonatomic, retain) NSString * newAttribute;
@property (nonatomic, retain) NSString * frontValue;
@property (nonatomic, retain) CardSet * cardSet;

@end



