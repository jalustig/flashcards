//
//  ThereIsAProblemViewController.m
//  FlashCards
//
//  Created by Jason Lustig on 8/22/11.
//  Copyright 2011-2014 Jason Lustig Lustig. All rights reserved.
//

#import "ThereIsAProblemViewController.h"

#import "FlashCardsCore.h"
#import "FlashCardsAppDelegate.h"

#import "UIDevice+IdentifierAddition.h"
#import "UIAlertView+Blocks.h"

#import <MessageUI/MessageUI.h>

@implementation ThereIsAProblemViewController

@synthesize iUnderstandButton, messageTextView;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}




#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.

    self.title = NSLocalizedStringFromTable(@"Send Feedback", @"Feedback", @"");

    [iUnderstandButton setTitle:NSLocalizedStringFromTable(@"OK, I Understand", @"Feedback", @"UIButton") forState:UIControlStateNormal]; 
    [iUnderstandButton setTitle:NSLocalizedStringFromTable(@"OK, I Understand", @"Feedback", @"UIButton") forState:UIControlStateSelected];
    
    messageTextView.text = NSLocalizedStringFromTable(@"ThereIsAProblemText", @"Feedback", @"");
    
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotate {
    UIInterfaceOrientation interfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    // Return YES for supported orientations
    return [FlashCardsAppDelegate shouldAutorotate:interfaceOrientation];
}

- (IBAction)sendFeedback:(id)sender {
    if (![FlashCardsCore deviceCanSendEmail]) {
        return;
    }
    
    RIButtonItem *noThankYou = [RIButtonItem item];
    noThankYou.label = NSLocalizedStringFromTable(@"No, thank you", @"Feedback", @"otherButtonTitles");
    noThankYou.action = ^{
        [self openFeedbackEmail:NO];
    };

    RIButtonItem *attach = [RIButtonItem item];
    attach.label = NSLocalizedStringFromTable(@"Yes, Attach", @"Feedback", @"otherButtonTitles");
    attach.action = ^{
        [self openFeedbackEmail:YES];
    };

    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil
                                                    message:NSLocalizedStringFromTable(@"Would you like to attach a copy of your FlashCards++ data file? If you are sending feedback about a bug or crash, attaching your data file will help to solve your issue more quickly.", @"Feedback", @"")
                                           cancelButtonItem:noThankYou
                                           otherButtonItems:attach, nil];
    [alert show];

}

- (void)openFeedbackEmail:(BOOL)attachFile {
    
    // we are sending feedback:
    MFMailComposeViewController *feedbackController = [[MFMailComposeViewController alloc] init];
    feedbackController.mailComposeDelegate = self;
    [feedbackController setToRecipients:[NSArray arrayWithObject:contactEmailAddress]];
    [feedbackController setSubject:NSLocalizedStringFromTable(@"Feedback about FlashCards++", @"Feedback", @"")];

    NSString *subscription;
    if ([FlashCardsCore hasSubscription]) {
        NSDate *subscriptionEndDate = [FlashCardsCore getSettingDate:@"subscriptionEndDate"];
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateStyle:NSDateFormatterMediumStyle];
        NSString *endDate = [dateFormatter stringFromDate:subscriptionEndDate];
        subscription = [NSString stringWithFormat:@"S: %@", endDate];
    } else {
        subscription = @"";
    }
    
    NSString *hash = [FlashCardsCore managedObjectModelHash];

    [feedbackController setMessageBody:[NSString stringWithFormat:@"\n\nVersion: %@ (%@) [init: %@]\niOS: %@ (%@)\nDevice: %@ (%@, %@)\n%@\n%@\n\n",
                                        [FlashCardsCore appVersion],
                                        [FlashCardsCore buildNumber],
                                        [FlashCardsCore getSetting:@"firstVersionInstalled"],
                                        [FlashCardsCore osVersionNumber],
                                        [FlashCardsCore osVersionBuild],
                                        [FlashCardsCore deviceName],
                                        [[UIDevice currentDevice] uniqueDeviceIdentifier],
                                        [[UIDevice currentDevice] advertisingIdentifier],
                                        [NSString stringWithFormat:@"M: %@", hash],
                                        subscription
                                        ]
                                isHTML:NO];
    
    if (attachFile) {
        NSString *path = [[FlashCardsCore documentsDirectory] stringByAppendingPathComponent: @"FlashCards.sqlite"];
        NSData *data = [NSData dataWithContentsOfMappedFile:path];
        [feedbackController addAttachmentData:data mimeType:@"application/x-sqlite3" fileName:@"FlashCardsData.sqlite"];
    }
    
    NSString *debug = [FlashCardsCore debuggingString];
    [feedbackController addAttachmentData:[debug dataUsingEncoding:NSUTF8StringEncoding]
                                 mimeType:@"text/plain"
                                 fileName:@"debugging.txt"];
    
    [self presentViewController:feedbackController animated:YES completion:nil];
}

# pragma mark -
# pragma mark MFMailComposeViewControllerDelegate functions

- (void)mailComposeController:(MFMailComposeViewController*)controller  
          didFinishWithResult:(MFMailComposeResult)result 
                        error:(NSError*)error;
{
    if (result == MFMailComposeResultSent) {
        // thank the user for sending feedback:
        FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"Thank You", @"Feedback", @"UIAlert title"),
                                   NSLocalizedStringFromTable(@"Thank you for sending your message. We will be in touch shortly.", @"Feedback", @"message"));
        //    NSLog(@"It's away!");
    } else if (result == MFMailComposeResultFailed) {
        FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"Error", @"Error", @"UIAlert title"),
                                   [NSString stringWithFormat:NSLocalizedStringFromTable(@"An error occurred sending your message: %@ %@", @"Error", @"message"), error, [error userInfo]]);
    }
    [self dismissViewControllerAnimated:YES completion:nil];

    [self.navigationController popViewControllerAnimated:YES];

}


@end
