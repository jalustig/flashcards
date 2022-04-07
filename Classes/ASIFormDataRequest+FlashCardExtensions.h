//
//  ASIFormDataRequest+FlashCardExtensions.h
//  FlashCards
//
//  Created by Jason Lustig on 1/31/13.
//  Copyright (c) 2013 Jason Lustig. All rights reserved.
//

#import "ASIFormDataRequest.h"

@interface ASIFormDataRequest (FlashCardExtensions)
- (void)setupFlashCardsAuthentication:(NSString*)apiAction;
@end

