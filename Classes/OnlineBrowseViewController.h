//
//  QuizletBrowseViewController.h
//  FlashCards
//
//  Created by Jason Lustig on 7/27/10.
//  Copyright 2010 Jason Lustig. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "FCSetsTableViewController.h"

@class CardSet;
@class Collection;

@interface QuizletBrowseViewController : FCSetsTableViewController <UITableViewDelegate> {
    NSMutableDictionary *quizletOptions;
}

- (void) loadQuizletCategories;

@property (nonatomic, retain) NSMutableDictionary *quizletOptions;


@end
