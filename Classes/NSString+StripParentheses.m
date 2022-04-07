//
//  NSString+StripParentheses.m
//  FlashCards
//
//  Created by Jason Lustig on 11/8/12.
//  Copyright (c) 2012 Jason Lustig. All rights reserved.
//

#import "NSString+StripParentheses.h"
#import "FlashCardsCore.h"
#import "FlashCardsAppDelegate.h"

@implementation NSString (StripParentheses)

- (NSString*)stripParentheses {
    NSRegularExpression *regex = [(FlashCardsAppDelegate*)[FlashCardsCore appDelegate] stripParenthesesRegex];
    NSString *newValue = [regex stringByReplacingMatchesInString:self
                                                         options:0
                                                           range:NSMakeRange(0, [self length])
                                                    withTemplate:@""];
    return newValue;
}

@end

