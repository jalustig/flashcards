//
//  FCSetsTableViewController.m
//  FlashCards
//
//  Created by Jason Lustig on 3/13/11.
//  Copyright 2011-2014 Jason Lustig Lustig. All rights reserved.
//

#import "FCSetsTableViewController.h"


#import "FCCardSet.h"
#import "FCCollection.h"

@implementation FCSetsTableViewController

@synthesize cardSet, collection, cardSetCreateMode, popToViewControllerIndex, importFromWebsite, hasDownloadedFirstTime;
@synthesize myTableView;
@synthesize selectedIndexPathsSet, inPseudoEditMode, selectedImage, unselectedImage;


// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.inPseudoEditMode = NO;
    self.selectedIndexPathsSet = [[NSMutableSet alloc] initWithCapacity:0];
    self.selectedImage = [UIImage imageNamed:@"selected.png"];
    self.unselectedImage = [UIImage imageNamed:@"unselected.png"];
     

}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

# pragma mark -
# pragma mark Memory functions

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}




@end
