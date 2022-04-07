//
//  FCMatrix.m
//  FlashCards
//
//  Created by Jason Lustig on 6/3/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import "FCMatrix.h"

@implementation FCMatrix

// @synthesize rows;

+ (NSMutableDictionary *) locationDictionary:(id)nullValue x:(int)x y:(int)y {
    
    
    NSArray *keys = [[NSArray alloc] initWithObjects:@"x", @"y", nil];
    NSMutableArray *objects = [[NSMutableArray alloc] initWithObjects:[NSNumber numberWithInt:x], [NSNumber numberWithInt:y], nil];
    NSMutableDictionary *location = [[NSMutableDictionary alloc] initWithObjects:objects forKeys:keys]; 

    return location;
}
    
// Takes a dictionary with two keys - x and y
+ (id) initWithDimensions:(NSMutableDictionary *)xySizes {
    return [FCMatrix initWithDimensionsAndValues:xySizes initValue:[NSNumber numberWithInt:0]];
}

+ (id) initWithDimensionsAndValues:(NSMutableDictionary *)xySizes initValue:(id)value {
    int x = [[xySizes objectForKey:@"x"] intValue];
    int y = [[xySizes objectForKey:@"y"] intValue];
    // self.rows = [[NSMutableArray alloc] initWithCapacity:y];
    // [matrix initWithCapacity:y];
    NSMutableArray *matrix = [[NSMutableArray alloc] initWithCapacity:0];
    NSMutableArray* row;
    int i, j;
    for (i = 0; i < y; i++) {
        row = [[NSMutableArray alloc] initWithCapacity:x];
        for (j = 0; j < x; j++) {
            [row insertObject:value atIndex:j];
        }
        // [self.rows insertObject:row atIndex:i];
        [matrix insertObject:row atIndex:i];
    }
    return matrix;
}

+ (id) initWithMatrix:(NSMutableArray*)matrix {
    NSMutableDictionary *xySizes = [FCMatrix getDimensions:matrix];
    NSMutableDictionary *location;
    NSMutableArray *newMatrix = [FCMatrix initWithDimensions:xySizes];
    int x = [[xySizes objectForKey:@"x"] intValue];
    int y = [[xySizes objectForKey:@"y"] intValue];
    int i, j;
    for (i = 0; i < y; i++) {
        for (j = 0; j < x; j++) {
            location = [FCMatrix locationDictionary:nil x:j y:i];
            [FCMatrix setValueAtLocation:location
                                   value:[FCMatrix getValueAtLocation:location matrix:matrix]
                                  matrix:newMatrix];
        }
    }
    return newMatrix;
}

// returns a dictionary with two keys - x and y
+ (NSMutableDictionary *) getDimensions:(NSMutableArray *)matrix {
    int x, y;
    y = (int)[FCMatrix numRows:matrix];
    x = (int)[FCMatrix numCols:matrix];
    
    NSMutableDictionary *dimensions = [FCMatrix locationDictionary:nil x:x y:y];
    return dimensions;
}
+ (int) numRows:(NSMutableArray *)matrix {
    return [matrix count];
    // return [rows count];
}
+ (int) numCols:(NSMutableArray *)matrix {
    return [[matrix objectAtIndex:0] count];
    // return [[rows objectAtIndex:0] count];
}

// takes dictionary with two keys - x and y
+ (void) setValueAtLocation:(NSMutableDictionary *)location value:(id)value matrix:(NSMutableArray *)matrix {
    int x, y;
    x = [[location objectForKey:@"x"] intValue];
    y = [[location objectForKey:@"y"] intValue];
    // [[rows objectAtIndex:y] replaceObjectAtIndex:x withObject:value];
    [[matrix objectAtIndex:y] replaceObjectAtIndex:x withObject:value];
}

// takes dictinoary with two keys - x and y
+ (id) getValueAtLocation:(NSMutableDictionary *)location matrix:(NSMutableArray *)matrix {
    int x, y;
    x = [[location objectForKey:@"x"] intValue];
    y = [[location objectForKey:@"y"] intValue];
    return [[matrix objectAtIndex:y] objectAtIndex:x];
    // return [[rows objectAtIndex:y] objectAtIndex:x];
}

+ (NSMutableDictionary *) getLocationNorthOf:(NSMutableDictionary *)location matrix:(NSMutableArray *)matrix {
    int x = [[location objectForKey:@"x"] intValue];
    int y = [[location objectForKey:@"y"] intValue];
    y--;
    if (y < 0) {
        return nil;
    }
    NSMutableDictionary *newLocation = [[NSMutableDictionary alloc] init];
    [newLocation setObject:[NSNumber numberWithInt:y] forKey:@"y"];
    [newLocation setObject:[NSNumber numberWithInt:x] forKey:@"x"];
    return newLocation;
}
+ (NSMutableDictionary *) getLocationWestOf:(NSMutableDictionary *)location matrix:(NSMutableArray *)matrix{
    int x = [[location objectForKey:@"x"] intValue];
    int y = [[location objectForKey:@"y"] intValue];
    x--;
    if (x < 0) {
        return nil;
    }
    NSMutableDictionary *newLocation = [[NSMutableDictionary alloc] init];
    [newLocation setObject:[NSNumber numberWithInt:y] forKey:@"y"];
    [newLocation setObject:[NSNumber numberWithInt:x] forKey:@"x"];
    return newLocation;
}
+ (NSMutableDictionary *) getLocationEastOf:(NSMutableDictionary *)location matrix:(NSMutableArray *)matrix{
    int x = [[location objectForKey:@"x"] intValue];
    int y = [[location objectForKey:@"y"] intValue];
    x++;
    if (x >= [FCMatrix numCols:matrix]) {
        return nil;
    }
    NSMutableDictionary *newLocation = [[NSMutableDictionary alloc] init];
    [newLocation setObject:[NSNumber numberWithInt:y] forKey:@"y"];
    [newLocation setObject:[NSNumber numberWithInt:x] forKey:@"x"];
    return newLocation;
}
+ (NSMutableDictionary *) getLocationSouthOf:(NSMutableDictionary *)location matrix:(NSMutableArray *)matrix{
    int x = [[location objectForKey:@"x"] intValue];
    int y = [[location objectForKey:@"y"] intValue];
    y++;
    if (y >= [FCMatrix numRows:matrix]) {
        return nil;
    }
    NSMutableDictionary *newLocation = [[NSMutableDictionary alloc] init];
    [newLocation setObject:[NSNumber numberWithInt:y] forKey:@"y"];
    [newLocation setObject:[NSNumber numberWithInt:x] forKey:@"x"];
    return newLocation;
}

// adds multiple rows or columns
+ (NSMutableArray *) addRows:(int)numNewRows initValue:(id)value matrix:(NSMutableArray *)matrix {
    int x = [FCMatrix numCols:matrix];
    int y = [FCMatrix numRows:matrix];
    NSMutableArray* row;
    int i, j;
    for (i = 0; i < numNewRows; i++) {
        row = [[NSMutableArray alloc] initWithCapacity:x];
        for (j = 0; j < x; j++) {
            [row insertObject:value atIndex:j];
        }
        [matrix insertObject:row atIndex:(y+i)];
    }
    return matrix;
}
+ (void) duplicateLastRow:(NSMutableArray *)matrix {
    int y = [FCMatrix numRows:matrix];
    NSMutableArray *newRow = [[NSMutableArray alloc] initWithArray:[matrix objectAtIndex:(y-1)] copyItems:YES];
    [matrix insertObject:newRow atIndex:[matrix count]];
}

- (void) addColumns:(int)numNewColumns {
}


+ (int) getX:(NSMutableDictionary*)location {
    int x;
    x = [[location objectForKey:@"x"] intValue];
    return x;
}
+ (int) getY:(NSMutableDictionary*)location {
    int y;
    y = [[location objectForKey:@"y"] intValue];
    return y;
}


+ (void) printLocationToNSLog:(NSMutableDictionary*)location {
    int x, y;
    x = [[location objectForKey:@"x"] intValue];
    y = [[location objectForKey:@"y"] intValue];
    NSLog(@"x=%d y=%d", x, y);
}

+ (void) printToNSLog:(NSMutableArray *)matrix {
    
    NSMutableString *rowString = [[NSMutableString alloc] initWithCapacity:1];
    int x, y;
    
    // Create a mutable location so we can update it for each cell:
    /*
     NSArray *keys = [[NSArray alloc] initWithObjects:@"x", @"y", nil];
    NSArray *objects = [[NSArray alloc] initWithObjects:0, 0, nil];
    NSMutableDictionary *location = [[NSMutableDictionary alloc] initWithObjects:objects forKeys:keys]; 
    [keys release];
    [objects release];
    */
    NSMutableDictionary *location = [FCMatrix locationDictionary:nil x:0 y:0];
    
    NSLog(@"#Cols: %d", [FCMatrix numCols:matrix]);
    NSLog(@"#Rows: %d", [FCMatrix numRows:matrix]);

    
    for (y = 0; y < [FCMatrix numRows:matrix]; y++) {
        [rowString setString:@""];
        [location setObject:[NSNumber numberWithInt:y] forKey:@"y"];
        for (x = 0; x < [FCMatrix numCols:matrix]; x++) {
            [location setObject:[NSNumber numberWithInt:x] forKey:@"x"];
            [rowString appendFormat:@" %@ ", [FCMatrix getValueAtLocation:location matrix:matrix]];
        }
        NSLog(@"%@", rowString);
    }
    
    // [location release];
    return;
}


@end
