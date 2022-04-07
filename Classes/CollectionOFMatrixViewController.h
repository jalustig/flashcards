//
//  CollectionOFMatrixViewController.h
//  FlashCards
//
//  Created by Jason Lustig on 6/20/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import <UIKit/UIKit.h>

@class FCCollection;

@interface CollectionOFMatrixViewController : UIViewController <UIAlertViewDelegate>

- (void) helpEvent;
- (IBAction)alertResetOFMatrix:(id)sender;
- (void) loadOFMatrix;

@property (nonatomic, strong) FCCollection *collection;
@property (nonatomic, weak) IBOutlet UIWebView *textView;

@property (nonatomic, weak) IBOutlet UIBarButtonItem *resetOptimalFactorMatrixButton;

@end
