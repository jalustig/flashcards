//
//  SMCore.m
//  FlashCards
//
//  Created by Jason Lustig on 6/5/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import "SMCore.h"
#import "FCMatrix.h"
#import "FCCollection.h"

static double baseOptimalFactor = 1.7;
static int oFactorMatrixStartRowCount = 20;

static int directionBegin = 0;
static int directionHorizontal = 1;
static int directionVertical = 2;


@implementation SMCore

+ (double) adjustEFactor:(double)eFactor add:(double)adjustFactor {
    eFactor += adjustFactor;
    if (eFactor >= maxEFactor) {
        eFactor = maxEFactor;
    } else if (eFactor <= minEFactor) {
        eFactor = minEFactor;
    }
    return eFactor;
}

+ (int) calcColNum:(double)eFactor {
    int integer = (int)(eFactor * 10);
    return integer-((int)(minEFactor*10)); //13;
}
+ (double) calcEFactorFromColumn:(int)colNum {
    double dbl = ((double)colNum) / 10.0;
    return dbl+minEFactor;
}


+ (NSMutableArray *)newOFactorMatrix {
    
    int numCols = ((int)((maxEFactor - minEFactor)*10))+1;
    int numRows = oFactorMatrixStartRowCount;
    
    NSMutableDictionary *location = [FCMatrix locationDictionary:nil x:numCols y:numRows];
    NSMutableArray *matrix = [FCMatrix initWithDimensionsAndValues:location initValue:[NSNumber numberWithFloat:0]];
    
    double eFactor;
    double oFactor;
    int column, row;
    for (eFactor = minEFactor; eFactor <= (maxEFactor+0.0001); eFactor += 0.1) {
        column = [SMCore calcColNum:eFactor];
        [location setObject:[NSNumber numberWithInt:column] forKey:@"x"];
        
        for (row = 0; row < numRows; row++) {
            [location setObject:[NSNumber numberWithInt:row] forKey:@"y"];
            
            // Based on original;
            
            if (row == 0 && eFactor <= baseOptimalFactor) {
                oFactor = baseOptimalFactor;
            } else if (eFactor < minOptimalFactor) {
                oFactor = minOptimalFactor;
            } else {
                oFactor = eFactor;
            }
            
            // oFactor = eFactor;
            
            // Based on http://www.supermemo.com/english/ol/sm5.htm, section 3.6:
            
            /*
             if (row == 0) {
             oFactor = 8-(( (eFactor-minEFactor)/(maxEFactor-minEFactor) )*3);
             } else if (row == 1) {
             oFactor = 13+(((eFactor-minEFactor)/(maxEFactor-minEFactor))*8);
             } else {
             oFactor = [[FCMatrix getValueAtLocation:[FCMatrix locationDictionary:nil x:column y:(row-1)] matrix:matrix] doubleValue];
             oFactor = oFactor*(eFactor-0.1);
             }
             */
            [FCMatrix setValueAtLocation:location value:[NSNumber numberWithDouble:oFactor] matrix:matrix];
        }
    }
    
    // [location release];
    
    // [FCMatrix printToNSLog:matrix];
    
    return matrix;
    
}

+ (NSMutableArray *) newOFactorAdjustedMatrix {
    
    int numCols = ((int)((maxEFactor - minEFactor)*10))+1;
    int numRows = oFactorMatrixStartRowCount;
    
    NSMutableDictionary *location = [FCMatrix locationDictionary:nil x:numCols y:numRows];
    
    NSMutableArray *matrix = [FCMatrix initWithDimensionsAndValues:location initValue:[NSNumber numberWithInt:0]];
    // [location release];
    
    // [FCMatrix printToNSLog:matrix];
    return matrix;
}

+ (double) optimalFactor:(NSMutableArray*)oFactorMatrix interval:(int)interval eFactor:(double)eFactor {
    int colNumber = [SMCore calcColNum:eFactor];
    NSMutableDictionary *location = [FCMatrix locationDictionary:nil x:colNumber y:(int)interval];
    double OF = [[FCMatrix getValueAtLocation:location matrix:oFactorMatrix] doubleValue];
    return OF;
}

+ (double) optimalInterval:(NSMutableArray*)oFactorMatrix iMatrix:(NSMutableArray *)iMatrix interval:(int)interval eFactor:(double)eFactor {
    int colNumber = [SMCore calcColNum:eFactor];
    NSMutableDictionary *location = [FCMatrix locationDictionary:nil x:colNumber y:(int)interval];
    if (interval == 1) {
        return [[FCMatrix getValueAtLocation:location matrix:oFactorMatrix] doubleValue];
    } else {
        NSNumber *OF = [FCMatrix getValueAtLocation:location matrix:oFactorMatrix];
        location = [FCMatrix locationDictionary:nil x:colNumber y:(int)(interval-1)];
        NSNumber *myI = [FCMatrix getValueAtLocation:location matrix:iMatrix];
        return [OF doubleValue] * [myI doubleValue];
    }
}

+ (double) calcRandomNum {
    double a = 0.047;
    double b = 0.092;
    double arc = (double)( arc4random() % 100 );
    double random = arc / 100;
    double p = random-0.5;
    double logVal = log(1.0-b/a*fabs(p));
    double m = (-1/b*logVal);
    if (m < 0) {
        m *= -1;
    }
    return m;
}

+ (double) nearOptimalInterval:(id)nilVal previousInterval:(double)previousInterval optimalFactor:(double)optimalFactor {
    double NOI;
    double m = [SMCore calcRandomNum];
    NOI = previousInterval*(1+(optimalFactor-1)*(100+m)/100);
    return NOI;
}

+ (double) calcEFactor:(double)quality oldEFactor:(double)oldEFactor {
    double newEFactor;
    newEFactor = oldEFactor+(0.1-(5-quality)*(0.08+(5-quality)*0.02));
    if (newEFactor > maxEFactor) {
        newEFactor = maxEFactor;
    } else if (newEFactor < minEFactor) {
        newEFactor = minEFactor;
    }
    return newEFactor;
}

// Rounds the E-Factor to a single digit, e.g. 2.31 -> 2.3 and 1.49 -> 1.5
+ (double) roundEFactor:(double)eFactor {
    // eFactor = 2.31
    double tenEFactor = eFactor * 10; // tenEFactor = 23.1
    double floorEFactor = floor(tenEFactor); // floorEFactor = 23
    if ((tenEFactor - floorEFactor) > 0.5) {
        return (floorEFactor+1) / 10;
    } else {
        return floorEFactor / 10;
    }
}

/*
 * interval_used - the last interval used for the item in question
 * quality - the quality of the repetition response
 * usedOptimalFactor (used_of) - the optimal factor used in calculation of the last interval used for the item in question
 * lastOptimalFactor (old_of) - the previous value of the OF entry corresponding to the relevant repetition number and the E-Factor of the item
 ^^^ i.e., in calculating a new OF, it is the current OF in the location in the matrix.
 * fraction - a number belonging to the range (0,1) determining the rate of modifications (the greater it is the faster the changes of the OF matrix)
 */
+ (double) calcNewOptimalFactor:(id)nilVal intervalUsed:(double)intervalUsed lastOptimalFactor:(double)lastOptimalFactor usedOptimalFactor:(double)usedOptimalFactor quality:(int)quality {
    double newOptimalFactor;
    
    double fraction = 0.4;
    
    double modifier, mod5, mod2;
    
    mod5 = (intervalUsed+1)/intervalUsed;
    if (mod5 < 1.05) {
        mod5 = 1.05;
    }
    mod2 = (intervalUsed-1)/intervalUsed;
    if (mod2 > 0.75) {
        mod2 = 0.75;
    }
    if (quality > 4) {
        modifier = 1+(mod5-1)*(quality-4);
    } else {
        modifier = 1-(1-mod2)/2*(4-quality);
    }
    if (modifier < 0.05) {
        modifier = 0.05;
    }
    newOptimalFactor = usedOptimalFactor*modifier;
    if (quality > 4) {
        if (newOptimalFactor < lastOptimalFactor) {
            newOptimalFactor = lastOptimalFactor;
        }
    } else if (quality < 4) {
        if (newOptimalFactor > lastOptimalFactor) {
            newOptimalFactor = lastOptimalFactor;
        }
    }
    newOptimalFactor = newOptimalFactor*fraction+lastOptimalFactor*(1-fraction);
    
    // check to make sure it isn't out of bounds:
    if (newOptimalFactor < minOptimalFactor) {
        newOptimalFactor = minOptimalFactor;
    }
    if (newOptimalFactor > maxOptimalFactor) {
        newOptimalFactor = maxOptimalFactor;
    }
    return newOptimalFactor;
}

+ (void) propagateOFMatrixChanges:(NSMutableArray *)ofMatrix ofMatrixAdjusted:(NSMutableArray*)ofMatrixAdjusted startLocation:(NSMutableDictionary*)startLocation {
    
    // NSLog(@"Before changes:");
    // [FCMatrix printToNSLog:ofMatrix];
    // [FCMatrix printToNSLog:ofMatrixAdjusted];
    
    // NSMutableArray *ofMatrixAdjustedCopy = [ofMatrixAdjusted copy];
    
    [SMCore propagateOFMatrixChangesWorker:ofMatrix ofMatrixVisited:ofMatrixAdjusted location:startLocation previousLocation:startLocation direction:directionBegin];
    
    // NSLog(@"\n\nAfter changes:");
    // [FCMatrix printToNSLog:ofMatrix];
    // [FCMatrix printToNSLog:ofMatrixAdjusted];
    
}

+ (void) propagateOFMatrixChangesWorker:(NSMutableArray *)ofMatrix ofMatrixVisited:(NSMutableArray*)ofMatrixVisited location:(NSMutableDictionary*)location previousLocation:(NSMutableDictionary*)previousLocation direction:(int)direction {
    
    // getLocation___Of returns NIL if it is out of bounds of the matrix:
    if (!location) {
        return;
    }
    
    double prevValue, newValue;
    double prevEFactor, newEFactor;
    
    // Update the values:
    if (direction != directionBegin) {
        // Get out of here if we have already looked at this location:
        if ([[FCMatrix getValueAtLocation:location matrix:ofMatrixVisited] intValue]) {
            return;
        }
        
        prevValue = [[FCMatrix getValueAtLocation:previousLocation matrix:ofMatrix] doubleValue];
        prevEFactor = [SMCore calcEFactorFromColumn:[FCMatrix getX:previousLocation]];
        newEFactor  = [SMCore calcEFactorFromColumn:[FCMatrix getX:location]];
        if (direction == directionHorizontal) {
            newValue = prevValue * newEFactor / prevEFactor;
        } else {
            newValue = prevValue;
        }
        
        // check to make sure it isn't out of bounds:
        if (newValue < minOptimalFactor) {
            newValue = minOptimalFactor;
        } else if (newValue > maxOptimalFactor) {
            newValue = maxOptimalFactor;
        }
        
        // Save the change, and mark that we have visited this location:
        [FCMatrix setValueAtLocation:location value:[NSNumber numberWithDouble:newValue] matrix:ofMatrix];
        [FCMatrix setValueAtLocation:location value:[NSNumber numberWithInt:1] matrix:ofMatrixVisited];
    }
    
    // Visit all locations north, south, east, and west:
    // NSMutableDictionary *north = [FCMatrix getLocationNorthOf:location matrix:ofMatrix];
    NSMutableDictionary *south = [FCMatrix getLocationSouthOf:location matrix:ofMatrix];
    NSMutableDictionary *east =  [FCMatrix getLocationEastOf: location matrix:ofMatrix];
    NSMutableDictionary *west =  [FCMatrix getLocationWestOf: location matrix:ofMatrix];
    NSMutableDictionary *north = [FCMatrix getLocationNorthOf: location matrix:ofMatrix];
    
    [SMCore propagateOFMatrixChangesWorker:ofMatrix ofMatrixVisited:ofMatrixVisited location:east  previousLocation:location direction:directionHorizontal];
    [SMCore propagateOFMatrixChangesWorker:ofMatrix ofMatrixVisited:ofMatrixVisited location:west  previousLocation:location direction:directionHorizontal];
    [SMCore propagateOFMatrixChangesWorker:ofMatrix ofMatrixVisited:ofMatrixVisited location:north previousLocation:location direction:directionVertical];
    [SMCore propagateOFMatrixChangesWorker:ofMatrix ofMatrixVisited:ofMatrixVisited location:south previousLocation:location direction:directionVertical];
    
}

+ (NSString*) outputOptimalFactorMatrixAsHtml:(FCCollection*)collection {
    
    NSMutableString *html = [[NSMutableString alloc] initWithCapacity:1];
    NSString *style;
    int x, y;
    
    NSMutableDictionary *location = [FCMatrix locationDictionary:nil x:0 y:0];
    
    [html appendString:@"<table>"];
    [html appendFormat:@"<tr><th colspan=\"2\">&nbsp;</th><th colspan=\"%d\" align=\"center\">%@</th></tr>", (((int)((maxEFactor - minEFactor) * 10))+1), NSLocalizedStringFromTable(@"E-Factors", @"FlashCards", @"")];
    [html appendString:@"<tr>"];
    [html appendFormat:@"<th rowspan=\"%d\" valign=\"center\" style=\"width: 1em !important;\"><div style=\"width:1em !important; -webkit-transform: rotate(-90deg);\">%@</div></th>", ([FCMatrix numRows:collection.ofMatrix]+1), NSLocalizedStringFromTable(@"Repetitions", @"Statistics", @"")];
    [html appendString:@"<th>&nbsp;</th>"];
    for (double i = minEFactor; i <= maxEFactor+0.01; i += 0.1) {
        [html appendFormat:@"<th>%1.1f</th>", i];
    }
    [html appendString:@"</tr>"];
    
    for (y = 0; y < [FCMatrix numRows:collection.ofMatrix]; y++) {
        
        [html appendString:@"<tr>"];
        [html appendFormat:@"<th>%d</th>", y];
        
        [location setObject:[NSNumber numberWithInt:y] forKey:@"y"];
        for (x = 0; x < [FCMatrix numCols:collection.ofMatrix]; x++) {
            [location setObject:[NSNumber numberWithInt:x] forKey:@"x"];
            
            if ([[FCMatrix getValueAtLocation:location matrix:collection.ofMatrixAdjusted] boolValue]) {
                style = @"background-color:red;";
            } else {
                style = @"";
            }
            [html appendFormat:@"<td style=\"%@\">%1.2f</td>", style, [[FCMatrix getValueAtLocation:location matrix:collection.ofMatrix] doubleValue]];
        }
        
        [html appendString:@"</tr>"];
        
    }
    
    [html appendString:@"</table>"];
    
    
    return html;
}


@end
