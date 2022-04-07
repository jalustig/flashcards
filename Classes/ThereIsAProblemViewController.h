//
//  ThereIsAProblemViewController.h
//  FlashCards
//
//  Created by Jason Lustig on 8/22/11.
//  Copyright 2011-2014 Jason Lustig Lustig. All rights reserved.
//

#import <MessageUI/MessageUI.h>

@interface ThereIsAProblemViewController : UIViewController <UIAlertViewDelegate, MFMailComposeViewControllerDelegate>

- (IBAction)sendFeedback:(id)sender;

@property (nonatomic, weak) IBOutlet UITextView *messageTextView;
@property (nonatomic, weak) IBOutlet UIButton *iUnderstandButton;


@end
