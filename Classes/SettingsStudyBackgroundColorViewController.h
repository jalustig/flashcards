//
//  SettingsStudyBackgroundColorViewController.h
//  FlashCards
//
//  Created by Jason Lustig on 10/4/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface SettingsStudyBackgroundColorViewController : UITableViewController

@property (nonatomic, strong) NSMutableArray *backgroundColorOptions;

@property (nonatomic, strong) UIColor *backgroundColor;
@property (nonatomic, strong) UIColor *backgroundTextColor;

@property (nonatomic, strong) NSIndexPath *checkedCell;

@end
