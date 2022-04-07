//
//  HelpViewController.h
//  FlashCards
//
//  Created by Jason Lustig on 6/17/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface HelpViewController : UIViewController

@property (nonatomic, weak) IBOutlet UIWebView *helpTextView;
@property (nonatomic, strong) NSString *helpText;
@property (nonatomic, assign) BOOL usesMath;

@end
