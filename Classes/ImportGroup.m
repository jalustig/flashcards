//
//  ImportGroup.m
//  FlashCards
//
//  Created by Jason Lustig on 4/13/11.
//  Copyright 2011-2014 Jason Lustig Lustig. All rights reserved.
//

#import "ImportGroup.h"


@implementation ImportGroup

@synthesize groupId;
@synthesize name, description, creator, isPrivateGroup, requiresPassword, isMemberOfGroup, numberCardSets, numberUsers;
@synthesize cardSets;

+ (id) alloc {
    return [super alloc];
}

-(id) init {
    if ((self = [super init])) {
        groupId = -1;
        numberCardSets = 0;
        numberUsers = 0;
        cardSets = [[NSMutableArray alloc] initWithCapacity:0];
        isPrivateGroup = NO;
        requiresPassword = NO;
        isMemberOfGroup = NO;
    }
    return self;
}

- (id) initWithDictionary:(NSDictionary*)setData {
    if ((self = [self init])) {
        self.groupId = [[setData valueForKey:@"id"] intValue];
        self.name = [setData valueForKey:@"title"];
        if ([setData valueForKey:@"description"]) {
            self.description = [setData valueForKey:@"description"];
        }
        self.numberCardSets = [[setData valueForKey:@"set_count"] intValue];
        self.numberUsers = [[setData valueForKey:@"user_count"] intValue];
        if ([(NSNumber*)[setData valueForKey:@"is_private"] boolValue]) {
            self.isPrivateGroup = YES;
        }
        if ([(NSNumber*)[setData valueForKey:@"is_member"] boolValue]) {
            self.isMemberOfGroup = YES;
        }
    }
    return self;
}


@end
