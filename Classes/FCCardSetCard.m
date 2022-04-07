//
//  FCCardSetCard.m
//  FlashCards
//
//  Created by Jason Lustig on 6/7/13.
//  Copyright (c) 2013 Jason Lustig. All rights reserved.
//

#import "FCCardSetCard.h"
#import "FCCard.h"
#import "FCCardSet.h"


@implementation FCCardSetCard

@dynamic cardOrder;
@dynamic ticdsSyncID;
@dynamic card;
@dynamic cardSet;

# pragma mark Override Methods

-(void)setCardSet:(FCCardSet *)_cardSet {
    [self willChangeValueForKey:@"cardSet"];
    [self setPrimitiveValue:_cardSet forKey:@"cardSet"];
    [self didChangeValueForKey:@"cardSet"];
    
    [self.cardSet setHasCardOrder:@YES];
    
}



@end
