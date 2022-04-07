//
//  NSString+Languages.m
//  FlashCards
//
//  Created by Jason Lustig on 11/20/13.
//  Copyright (c) 2013 Jason Lustig. All rights reserved.
//

#import "NSString+Languages.h"

@implementation NSString (Languages)

- (BOOL) usesLatex {
    if ([self isEqualToString:@"math"] || [self isEqualToString:@"chemistry"]) {
        return YES;
    }
    return NO;
}

@end
