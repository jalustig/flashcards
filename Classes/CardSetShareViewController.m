//
//  CardSetShareViewController.m
//  FlashCards
//
//  Created by Jason Lustig on 10/15/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import "CardSetShareViewController.h"
#import "FlashCardsAppDelegate.h"

#import "CHCSVParser.h"

#import "FCCardSet.h"
#import "FCCard.h"
#import "FCCollection.h"

@implementation CardSetShareViewController

@synthesize cardSet, collection;
@synthesize fileName;

/*
 // The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        // Custom initialization
    }
    return self;
}
*/

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = NSLocalizedStringFromTable(@"Share Cards", @"CardManagement", @"UIView title");
    

    MFMailComposeViewController *shareController = [[MFMailComposeViewController alloc] init];
    shareController.mailComposeDelegate = self;
    [shareController setSubject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"My FlashCards++ Card Set: %@", @"CardManagement", @"share-mail subject"), (self.collection ? collection.name : cardSet.name), nil]];
    [shareController setMessageBody:  NSLocalizedStringFromTable(@""
                                      "Here is a flash card set I created using FlashCards++, "
                                      "a flash card app for iPod touch, iPhone, and iPad."
                                      "\n"
                                      "\n"
                                      "If you have the app installed, touch and hold the attached card set "
                                      "to open it directly with FlashCards++."
                                      "\n"
                                      "\n"
                                      "If you don't have the app, you can purchase it "
                                      "at http://bit.ly/flashcardapp. Learn more at www.iphoneflashcards.com."
                                      "\n", @"CardManagement", @"share-mail message")
                             isHTML:NO];
    
    NSString *path = [[FlashCardsCore documentsDirectory] stringByAppendingPathComponent:fileName];
    
    [shareController addAttachmentData:[NSData dataWithContentsOfMappedFile:path] mimeType:@"application/octet-stream" fileName:fileName];
    
    [self presentViewController:shareController animated:YES completion:nil];
    
}

-(void)buildExportCSV:(NSString*)path {
    if (self.cardSet) {
        [self.cardSet buildExportCSV:path];
    } else {
        [self.collection buildExportCSV:path];
    }
}

-(void)buildExportNativeFile:(NSString*)path {

    NSDictionary *saveDict;
    if (self.cardSet) {
        saveDict = [self.collection buildExportDictionary:self.cardSet];
    } else {
        saveDict = [self.collection buildExportDictionary:nil];
    }
    [NSKeyedArchiver archiveRootObject:saveDict toFile:path];    
}

// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotate {
    UIInterfaceOrientation interfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    return [FlashCardsAppDelegate shouldAutorotate:interfaceOrientation];
}

# pragma mark -
# pragma mark MFMailComposeViewControllerDelegate functions

- (void)mailComposeController:(MFMailComposeViewController*)controller  
          didFinishWithResult:(MFMailComposeResult)result 
                        error:(NSError*)error
{
    [Flurry logEvent:@"Share"
      withParameters:@{
     @"method" : @"email"
     }];
    if (result == MFMailComposeResultSent) {
            // thank the user for sending feedback:
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@""
                                                             message:NSLocalizedStringFromTable(@"Your message has been sent successfully.", @"FlashCards", @"message")
                                                            delegate:nil
                                                   cancelButtonTitle:NSLocalizedStringFromTable(@"OK", @"FlashCards", @"cancelButtonTitle")
                                                   otherButtonTitles:nil];
            [alert show];
        //    NSLog(@"It's away!");
    } else if (result == MFMailComposeResultFailed) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@""
                                                         message:[NSString stringWithFormat:NSLocalizedStringFromTable(@"An error occurred sending your message: %@ %@", @"Error", @"message"), error, [error userInfo]]
                                                        delegate:nil
                                               cancelButtonTitle:NSLocalizedStringFromTable(@"OK", @"FlashCards", @"cancelButtonTitle")
                                               otherButtonTitles:nil];
        [alert show];
    }
    
    [self dismissViewControllerAnimated:NO completion:nil];
    [self.navigationController popViewControllerAnimated:YES];
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
