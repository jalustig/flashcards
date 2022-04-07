//
//  NSArray+SplitArray.m
//  FlashCards
//
//  Created by Jason Lustig on 11/13/12.
//  Copyright (c) 2012 Jason Lustig. All rights reserved.
//

#import "NSArray+SplitArray.h"

@implementation NSArray (SplitArray)
-(NSMutableArray*)splitIntoSubarraysOfMaxSize:(int)maxSize {
    // as per: http://stackoverflow.com/a/6852105/353137

    NSMutableArray *arrayOfArrays = [[NSMutableArray alloc] initWithCapacity:0];
    
    int itemsRemaining = [self count];
    int j = 0;
    while(j < [self count]) {
        NSRange range = NSMakeRange(j, MIN(maxSize, itemsRemaining));
        NSArray *subarray = [self subarrayWithRange:range];
        [arrayOfArrays addObject:subarray];
        itemsRemaining-=range.length;
        j+=range.length;
    }

    return arrayOfArrays;
}
@end
