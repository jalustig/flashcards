//
//  QuizletBrowseViewController.h
//  FlashCards
//
//  Created by Jason Lustig on 7/27/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "FCSetsTableViewController.h"

@class FCCardSet;
@class FCCollection;

@interface QuizletBrowseViewController : FCSetsTableViewController <UITableViewDelegate>

- (void) loadQuizletCategories;

@property (nonatomic, strong) NSMutableDictionary *quizletOptions;

@end
