//
//  QuizletRestClient+ErrorMessages.h
//  FlashCards
//
//  Created by Jason Lustig on 4/14/11.
//  Copyright 2011-2014 Jason Lustig Lustig. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "QuizletRestClient.h"

@class ImportGroup;
@class ImportSet;
@protocol QuizletLoginControllerDelegate;

@interface QuizletRestClient (ErrorMessages)

#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
- (void)genericCardSetAccessFailedWithError:(NSError*)error withDelegateView:(UIViewController<QuizletLoginControllerDelegate>*)delegateView withCardSet:(ImportSet*)cardSet;
- (void)genericGroupAccessFailedWithError:(NSError *)error withDelegateView:(UIViewController<QuizletLoginControllerDelegate>*)delegateView withGroup:(ImportGroup*)group;
#endif

@end
