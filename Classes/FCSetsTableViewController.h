//
//  FCSetsTableViewController.h
//  FlashCards
//
//  Created by Jason Lustig on 3/13/11.
//  Copyright 2011-2014 Jason Lustig Lustig. All rights reserved.
//

#import <Foundation/Foundation.h>

@class FCCardSet;
@class FCCollection;


@interface FCSetsTableViewController : UIViewController <UITableViewDelegate>

@property (nonatomic, strong) FCCardSet *cardSet;
@property (nonatomic, strong) FCCollection *collection;

@property (nonatomic, assign) int cardSetCreateMode;
@property (nonatomic, assign) int popToViewControllerIndex;
@property (nonatomic, assign) bool hasDownloadedFirstTime;

@property (nonatomic, strong) NSString *importFromWebsite;

@property (nonatomic, weak) IBOutlet UITableView *myTableView;

@property (nonatomic, strong) NSMutableSet *selectedIndexPathsSet;
@property BOOL inPseudoEditMode;
@property (nonatomic, strong) UIImage *selectedImage;
@property (nonatomic, strong) UIImage *unselectedImage;

@end
