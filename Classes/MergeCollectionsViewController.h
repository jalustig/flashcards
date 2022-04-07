//
//  MergeCollectionsViewController.h
//  FlashCards
//
//  Created by Jason Lustig on 9/28/12.
//  Copyright (c) 2012 Jason Lustig. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "MBProgressHUD.h"

@class FCCollection;
@class FCCardSet;
@class MBProgressHUD;
@protocol MBProgressHUDDelegate;

@interface MergeCollectionsViewController : UIViewController <UITableViewDelegate, MBProgressHUDDelegate, UIAlertViewDelegate>

- (void)loadTableListOptions;
- (void)mergeCards;
- (void)checkIfUserReallyWantsToMerge;
- (void)addSourceAtIndexPath:(NSIndexPath*)indexPath;

# pragma mark -
# pragma mark PseudoEditMode Methods

-(IBAction)togglePseudoEditMode:(id)sender;
-(IBAction)importAllSets:(id)sender;
-(IBAction)importSelectedSets:(id)sender;

@property (nonatomic, strong) FCCollection *destinationCollection;
@property (nonatomic, strong) FCCardSet *destinationCardSet;
@property (nonatomic, strong) NSMutableArray *source;

@property (nonatomic, assign) BOOL isMergingCollections;

@property (nonatomic, strong) NSMutableArray *tableListOptions;

@property (nonatomic, weak) IBOutlet UITableView *myTableView;

@property (nonatomic, strong) MBProgressHUD *HUD;

@property (nonatomic, strong) NSMutableSet *selectedIndexPathsSet;
@property BOOL inPseudoEditMode;
@property (nonatomic, strong) UIImage *selectedImage;
@property (nonatomic, strong) UIImage *unselectedImage;
@property (nonatomic, weak) IBOutlet UIToolbar *pseudoEditToolbar;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *importAllSetsButton;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *importSelectedSetsButton;

@end
