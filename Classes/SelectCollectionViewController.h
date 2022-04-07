//
//  SelectCollectionViewController.h
//  FlashCards
//
//  Created by Jason Lustig on 9/23/11.
//  Copyright (c) 2011 Jason Lustig. All rights reserved.
//

#import <UIKit/UIKit.h>

@class MBProgressHUD;
@class FCCollection;

@interface SelectCollectionViewController : UITableViewController

@property (nonatomic, weak) IBOutlet UILabel *explanationLabel;

@property (nonatomic, strong) FCCollection *collection;

@property (nonatomic, strong) ImportSet *importSet;

@property (nonatomic, strong) NSMutableArray *topicsOptions;
@property (nonatomic, strong) NSMutableArray *collectionOptions;

@property (nonatomic, strong) MBProgressHUD *HUD;

@end
