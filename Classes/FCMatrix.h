//
//  FCMatrix.h
//  FlashCards
//
//  Created by Jason Lustig on 6/3/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import <Foundation/Foundation.h>

/*
 
@interface FCMatrix : NSObject {
    NSMutableArray *rows;
}
 
*/

// SELF = ROWS

@interface FCMatrix : NSMutableArray
{
}

+ (NSMutableDictionary *) locationDictionary:(id)nullValue x:(int)x y:(int)y;

// Takes a dictionary with two keys - x and y
+ (id) initWithDimensions:(NSMutableDictionary *)xySizes;
+ (id) initWithDimensionsAndValues:(NSMutableDictionary *)xySizes initValue:(id)value;
+ (id) initWithMatrix:(NSMutableArray*)matrix;

+ (int) getX:(NSMutableDictionary*)location;
+ (int) getY:(NSMutableDictionary*)location;


// returns a dictionary with two keys - x and y
+ (NSMutableDictionary *) getDimensions:(NSMutableArray *)matrix;
+ (int) numRows:(NSMutableArray *)matrix;
+ (int) numCols:(NSMutableArray *)matrix;

// takes dictionary with two keys - x and y
+ (void) setValueAtLocation:(NSMutableDictionary *)location value:(id)value matrix:(NSMutableArray *)matrix;

// takes dictinoary with two keys - x and y
+ (id) getValueAtLocation:(NSMutableDictionary *)location matrix:(NSMutableArray *)matrix;

+ (NSMutableDictionary *) getLocationNorthOf:(NSMutableDictionary *)location matrix:(NSMutableArray *)matrix;
+ (NSMutableDictionary *) getLocationWestOf: (NSMutableDictionary *)location matrix:(NSMutableArray *)matrix;
+ (NSMutableDictionary *) getLocationEastOf: (NSMutableDictionary *)location matrix:(NSMutableArray *)matrix;
+ (NSMutableDictionary *) getLocationSouthOf:(NSMutableDictionary *)location matrix:(NSMutableArray *)matrix;

// adds multiple rows or columns
+ (NSMutableArray *) addRows:(int)numNewRows initValue:(id)value matrix:(NSMutableArray *)matrix;
+ (void) duplicateLastRow:(NSMutableArray *)matrix;
- (void) addColumns:(int)numNewColumns;

+ (void) printLocationToNSLog:(NSMutableDictionary*)location;
+ (void) printToNSLog:(NSMutableArray *)matrix;

// @property (nonatomic, retain) NSMutableArray* rows;

@end
