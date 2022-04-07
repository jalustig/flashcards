//
//  NSDate+Compare.m
//  FlashCards
//
//  Created by Jason Lustig on 5/16/13.
//  Copyright (c) 2013 Jason Lustig. All rights reserved.
//

#import "NSDate+Compare.h"

@implementation NSDate (Compare)

- (BOOL)isEarlierThan:(NSDate*)otherDate {
    NSComparisonResult result = [self compare:otherDate];
    if (result == NSOrderedAscending) { // if (self < otherDate)
        // for: - (NSComparisonResult)compare:(NSDate *)anotherDate
        // if the receiver and anotherDate are exactly equal to each other, NSOrderedSame
        // if the receiver is later in time than anotherDate, NSOrderedDescending
        // if the receiver is earlier in time than anotherDate, NSOrderedAscending.
        return YES;
    } else {
        return NO;
    }
}

- (BOOL)isLaterThan:(NSDate*)otherDate {
    NSComparisonResult result = [self compare:otherDate];
    if (result == NSOrderedDescending) { // if (self > otherDate)
        // for: - (NSComparisonResult)compare:(NSDate *)anotherDate
        // if the receiver and anotherDate are exactly equal to each other, NSOrderedSame
        // if the receiver is later in time than anotherDate, NSOrderedDescending
        // if the receiver is earlier in time than anotherDate, NSOrderedAscending.
        return YES;
    } else {
        return NO;
    }
}

@end
