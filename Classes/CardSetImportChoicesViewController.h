//
//  CardSetImportChoicesViewController.h
//  FlashCards
//
//  Created by Jason Lustig on 6/3/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "QuizletLoginController.h"

@class FCCardSet;
@class FCCollection;
@protocol QuizletLoginControllerDelegate;

@interface CardSetImportChoicesViewController : UITableViewController <QuizletLoginControllerDelegate>

@property (nonatomic, strong) FCCardSet *cardSet;
@property (nonatomic, strong) FCCollection *collection;

@property (nonatomic, assign) int cardSetCreateMode;
@property (nonatomic, assign) int quizletLoginControllerChoice;

@property (nonatomic, strong) NSMutableArray *tableListOptions;

@end
