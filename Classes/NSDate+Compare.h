//
//  NSDate+Compare.h
//  FlashCards
//
//  Created by Jason Lustig on 5/16/13.
//  Copyright (c) 2013 Jason Lustig. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSDate (Compare)

- (BOOL)isEarlierThan:(NSDate*)otherDate;
- (BOOL)isLaterThan:(NSDate*)otherDate;

@end
