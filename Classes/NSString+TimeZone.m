//
//  NSString+TimeZone.m
//  FlashCards
//
//  Created by Jason Lustig on 5/29/13.
//  Copyright (c) 2013 Jason Lustig. All rights reserved.
//

#import "NSString+TimeZone.h"

@implementation NSString (TimeZone)

- (NSString*)addTimeZone:(NSString *)timeZone {
    if ([self hasSuffix:@" UTC"]) {
        return self;
    } else {
        // A BIG HACK! Tries to see if the current time zone would use DST for the date in question.
        NSDateFormatter *dateStringFormatter = [[NSDateFormatter alloc] init];
        dateStringFormatter.dateFormat = @"yyyy-MM-dd HH:mm:ss zzz";
        
        NSString *tempDateString = [self stringByAppendingFormat:@" %@", timeZone];

        NSDate *tempDate = [dateStringFormatter dateFromString:tempDateString];

        NSDateComponents *components = [[NSCalendar currentCalendar]
                                        components:NSDayCalendarUnit | NSMonthCalendarUnit | NSYearCalendarUnit | NSTimeZoneCalendarUnit
                                        fromDate:tempDate];

        NSTimeZone *tempTimeZone = [components timeZone];
        if ([tempTimeZone isDaylightSavingTimeForDate:tempDate]) {
            timeZone = @"CDT";
        } else {
            timeZone = @"CST";
        }

        NSString *retVal = [self stringByAppendingFormat:@" %@", timeZone];
        return retVal;
    }
}

@end
