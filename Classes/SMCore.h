//
//  SMCore.h
//  FlashCards
//
//  Created by Jason Lustig on 6/5/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

@class FCCollection;

@interface SMCore : NSObject {
    
}

+ (double) adjustEFactor:(double)eFactor add:(double)adjustFactor;
+ (int) calcColNum:(double)eFactor;
+ (double) calcEFactorFromColumn:(int)colNum;
+ (NSMutableArray *)newOFactorMatrix;
+ (NSMutableArray *)newOFactorAdjustedMatrix;

+ (double)optimalFactor:(NSMutableArray*)oFactorMatrix interval:(int)interval eFactor:(double)eFactor;
+ (double)optimalInterval:(NSMutableArray*)oFactorMatrix iMatrix:(NSMutableArray *)iMatrix interval:(int)interval eFactor:(double)eFactor;

+ (double) calcRandomNum;
+ (double)nearOptimalInterval:(id)nilVal previousInterval:(double)previousInterval optimalFactor:(double)optimalFactor;

+ (double)calcEFactor:(double)quality oldEFactor:(double)oldEFactor;
+ (double)roundEFactor:(double)eFactor;
+ (double)calcNewOptimalFactor:(id)nilVal intervalUsed:(double)intervalUsed lastOptimalFactor:(double)lastOptimalFactor usedOptimalFactor:(double)usedOptimalFactor quality:(int)quality;

+ (void)propagateOFMatrixChanges:(NSMutableArray *)oFMatrix ofMatrixAdjusted:(NSMutableArray*)ofMatrixAdjusted startLocation:(NSMutableDictionary*)startLocation;
+ (void)propagateOFMatrixChangesWorker:(NSMutableArray *)ofMatrix ofMatrixVisited:(NSMutableArray*)ofMatrixVisited location:(NSMutableDictionary*)location previousLocation:(NSMutableDictionary*)previousLocation direction:(int)direction;

+ (NSString*) outputOptimalFactorMatrixAsHtml:(FCCollection*)collection;

@end
