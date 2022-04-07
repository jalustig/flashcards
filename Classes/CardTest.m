//
//  CardTest.m
//  FlashCards
//
//  Created by Jason Lustig on 6/18/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import "CardTest.h"
#import "FCCard.h"
#import "FCCardRepetition.h"

@implementation CardTest

@synthesize card, collection, isTest, studyCount, score, correctStreakCount;
@synthesize showSide;
@synthesize isLapsed, numLapses;
@synthesize currentIntervalCount, eFactor, lastIntervalOptimalFactor, lastRepetitionDate, nextRepetitionDate;
@synthesize eFactorChanged;
@synthesize studyBegan, studyPauseLength;
@synthesize testRepetition;
@synthesize cardOrder;

- (id) init {
    if ((self = [super init])) {
        isTest = NO;
        isLapsed = NO;
        score = 0; // Merge cards
        studyCount = 0;
        correctStreakCount = 0;
        cardOrder = 0;
        eFactorChanged = NO;
        showSide = -1;
    }
    return self;
}

- (void)markStudyPause:(NSDate*)date {
    [self incrementStudyPause:[[NSDate date] timeIntervalSinceDate:date]];
}
- (void)incrementStudyPause:(double)timeInterval {
    self.studyPauseLength += timeInterval;
}

@end
