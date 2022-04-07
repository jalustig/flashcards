//
//  ASIFormDataRequest+FcppExtension.m
//  FlashCards
//
//  Created by Jason Lustig on 1/15/13.
//  Copyright (c) 2013 Jason Lustig. All rights reserved.
//

#import "ASIFormDataRequest+FcppExtension.h"

@implementation ASIFormDataRequest (FcppExtension)

- (void)prepareCoreDataSyncRequest {
    [self addPostValue:[FlashCardsCore getSetting:@"fcppUsername"] forKey:@"email"];
    [self addPostValue:[FlashCardsCore getSetting:@"fcppLoginKey"] forKey:@"login_key"];
    [self setShouldContinueWhenAppEntersBackground:YES];
    [self setShouldAttemptPersistentConnection:YES];
    [self setDelegate:nil];
}

@end
