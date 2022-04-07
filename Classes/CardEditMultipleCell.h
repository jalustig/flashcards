//
//  CardEditMultipleCell.h
//  FlashCards
//
//  Created by Jason Lustig on 6/21/13.
//  Copyright (c) 2013 Jason Lustig. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "GrowableTextView.h"

@class CardEditMultipleViewController;

@interface CardEditMultipleCell : UITableViewCell <UITextViewDelegate>

@property (nonatomic, strong) IBOutlet GrowableTextView *frontTextView;
@property (nonatomic, strong) IBOutlet GrowableTextView * backTextView;
@property (nonatomic, strong) CardEditMultipleViewController *controller;
@property (nonatomic) int cardNumber;

@end
