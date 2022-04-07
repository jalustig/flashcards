//
//  FCSync.m
//  FlashCards
//
//  Created by Jason Lustig on 6/8/13.
//  Copyright (c) 2013 Jason Lustig. All rights reserved.
//

#import "FCSync.h"

@implementation FCSync

@synthesize websiteName;
@synthesize imagesToDownload;

+ (id) alloc {
    return [super alloc];
}

- (id) init {
    if ((self = [super init])) {
        imagesToDownload = [[NSMutableSet alloc] initWithCapacity:0];
    }
    return self;
}

@end
