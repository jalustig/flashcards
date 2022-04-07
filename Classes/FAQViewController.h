//
//  FAQViewController.h
//  FlashCards
//
//  Created by Jason Lustig on 6/30/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import <UIKit/UIKit.h>

#import <MessageUI/MessageUI.h>

@interface FAQViewController : UIViewController <UITableViewDelegate, MFMailComposeViewControllerDelegate, UIAlertViewDelegate>

-(IBAction)rateApp:(id)sender;
-(IBAction)sendFeedback:(id)sender;

@property (nonatomic, strong) NSMutableArray *faq;
@property (nonatomic, strong) NSMutableArray *gettingStarted;

@property (nonatomic, weak) IBOutlet UITableView *myTableView;

@property (nonatomic, weak) IBOutlet UIBarButtonItem *rateInAppStoreButton;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *sendFeedbackButton;

@end
