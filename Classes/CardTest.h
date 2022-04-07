//
//  CardTest.h
//  FlashCards
//
//  Created by Jason Lustig on 6/18/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//


@class FCCard;
@class FCCollection;
@class FCCardRepetition;

@interface CardTest : NSObject {

    FCCard *card;
    FCCollection *collection;
    FCCardRepetition *testRepetition; // keeps track of the specific repetition so that we can change it if we go back!
    
    BOOL isTest;
    int studyCount; // keeps track of how many times the item is in the studyList array
    int correctStreakCount; // keeps track of how many times the item has been answered correctly in a row
    int cardOrder;
    int showSide;
    
    // Duplicated data from Card, so we can re-calculate if we go back:
    BOOL isLapsed;
    int score;
    int currentIntervalCount;
    double eFactor;
    BOOL eFactorChanged;
    NSDate *lastRepetitionDate;
    NSDate *nextRepetitionDate;
    double lastIntervalOptimalFactor;
    int numLapses;
    
    NSMutableArray *studyRounds;
    
    // Calculate how long we studied this time
    NSDate *studyBegan;
    double studyPauseLength;
}

- (id) init;
- (void)markStudyPause:(NSDate*)date;
- (void)incrementStudyPause:(double)timeInterval;

@property (nonatomic, strong) FCCard *card;
@property (nonatomic, strong) FCCollection *collection;
@property (nonatomic, strong) FCCardRepetition *testRepetition;
@property (nonatomic, assign) int studyCount;
@property (nonatomic, assign) int showSide;
@property (nonatomic, assign) int correctStreakCount;
@property (nonatomic, assign) int cardOrder;
@property (nonatomic, assign) BOOL isTest;
@property (nonatomic, assign) BOOL isLapsed;
@property (nonatomic, assign) int numLapses;
@property (nonatomic, assign) int score;
@property (nonatomic, assign) int currentIntervalCount;
@property (nonatomic) double eFactor;
@property (nonatomic, assign) BOOL eFactorChanged;
@property (nonatomic, strong) NSDate *lastRepetitionDate;
@property (nonatomic, strong) NSDate *nextRepetitionDate;
@property (nonatomic) double lastIntervalOptimalFactor;

@property (nonatomic, strong) NSDate *studyBegan;
@property (nonatomic) double studyPauseLength;

@end
