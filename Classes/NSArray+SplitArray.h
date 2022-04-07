//
//  NSArray+SplitArray.h
//  FlashCards
//
//  Created by Jason Lustig on 11/13/12.
//  Copyright (c) 2012 Jason Lustig. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSArray (SplitArray)
- (NSMutableArray*)splitIntoSubarraysOfMaxSize:(int)maxSize;
@end
