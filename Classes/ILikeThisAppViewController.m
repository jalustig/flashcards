//
//  ILikeThisAppViewController.m
//  FlashCards
//
//  Created by Jason Lustig on 8/22/11.
//  Copyright 2011-2014 Jason Lustig Lustig. All rights reserved.
//

#import "ILikeThisAppViewController.h"
#import "FlashCardsCore.h"
#import "FlashCardsAppDelegate.h"

#ifndef TARGET_IPHONE_SIMULATOR
#import "iHasApp.h"
#endif

#import <MessageUI/MessageUI.h>

#import "MBProgressHUD.h"

@implementation ILikeThisAppViewController

@synthesize thankYouLabel;
@synthesize appsArray;
#ifndef TARGET_IPHONE_SIMULATOR
@synthesize appObject;
#endif
@synthesize HUD, isLoadingApps;

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
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


#pragma mark -
#pragma mark MBProgressHUDDelegate methods

- (void)hudWasHidden:(MBProgressHUD *)hud {
    // Remove HUD from screen when the HUD was hidded
    [hud removeFromSuperview];
    hud = nil;
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;

    self.title = NSLocalizedStringFromTable(@"Send Feedback", @"Feedback", @"");
    thankYouLabel.text = NSLocalizedStringFromTable(@"Thank You :-)", @"Feedback", @"");

    // keeps track of whether we are loading the apps or not. This helps us know whether or not
    // we should hide the HUD.
    isLoadingApps = NO;
    
    // set up the app array functionality. We only look up the apps we have when are trying to get 
    // somewhere:
    appsArray = [[NSMutableArray alloc] init];
#ifndef TARGET_IPHONE_SIMULATOR
    appObject = [[iHasApp alloc] init];
    appObject.delegate = self;
#endif
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotate {
    UIInterfaceOrientation interfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    // Return YES for supported orientations
    return [FlashCardsAppDelegate shouldAutorotate:interfaceOrientation];
}

# pragma mark - iHasApp
// App search callback
- (void) appSearchSuccess:(NSArray *)appList{
    [appsArray removeAllObjects];
    [appsArray addObjectsFromArray:appList];
    // if we have a callback selector, then we know what we should do after we look up the apps:
    if (self.appLookupCallbackSelector) {
        [self performSelector:self.appLookupCallbackSelector withObject:nil];
    }
}

// Scheme load callback
- (void) appSchemesSuccess{
#ifndef TARGET_IPHONE_SIMULATOR
    [appObject findApps];
#endif
}

// Connectivity fail callback
- (void) loadFailure:(NSError *)error{
}

- (void)loadApps {
#ifndef TARGET_IPHONE_SIMULATOR
    // boilerplate code for how to get the apps:
    if([appObject schemesLoaded]){
        [appObject findApps];
    } else {
        [appObject loadSchemes];
    }
#endif
}

// checks to see if we have a specific app:
- (BOOL)hasApp:(int)appId {
    int appTestId;
    for (NSDictionary *app in appsArray) {
        appTestId = [[app objectForKey:@"APP_ID"] intValue];
        if (appTestId == appId) {
            return YES;
        }
    }
    return NO;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 4;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier];
    }
    
    // Configure the cell...
    
    if (indexPath.section == 0) {
        // Leave a Review on the App Store
        cell.textLabel.text = NSLocalizedStringFromTable(@"Leave an App Store Review", @"Feedback", @"");
        [cell.imageView setImage:[UIImage imageNamed:@"28-star.png"]];
    } else if (indexPath.section == 1) {
        // Share by Email
        cell.textLabel.text = NSLocalizedStringFromTable(@"Share by Email", @"Feedback", @"");
        [cell.imageView setImage:[UIImage imageNamed:@"18-envelope.png"]];
    } else if (indexPath.section == 2) {
        // Share with Facebook
        cell.textLabel.text = NSLocalizedStringFromTable(@"Share with Facebook", @"Feedback", @"");
        [cell.imageView setImage:[UIImage imageNamed:@"facebook.png"]];
    } else {
        // Share with Twitter
        cell.textLabel.text = NSLocalizedStringFromTable(@"Share with Twitter", @"Feedback", @"");
        [cell.imageView setImage:[UIImage imageNamed:@"twitter.png"]];
    }

    return cell;
}

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == 0) {
        // Leave a Review on the App Store
        [FlashCardsCore writeAppReview];
    } else if (indexPath.section == 1) {
        // Share by Email
        [FlashCardsCore shareWithEmail:self];
    } else if (indexPath.section == 2) {
        // Share with Facebook

        // if we already have loaded the apps, then there is no reason to re-do the work:
        //if ([appsArray count] > 0) {
            [self shareWithFacebook];
        /*} else {
            // after we're done, share with facebook
            appLookupCallbackSelector = @selector(shareWithFacebook);
            
            isLoadingApps = YES;
            
            HUD = [[MBProgressHUD alloc] initWithView:self.view];
            
            // Add HUD to screen
            [self.view addSubview:HUD];
            
            // Regisete for HUD callbacks so we can remove it from the window at the right time
            HUD.delegate = self;
            // HUD.minShowTime = 2.0;
            [HUD show:YES];
            [self loadApps];
        }
         */
    } else {
        // Share with Twitter
        
        // if we already have loaded the apps, then there is no reason to re-do the work:
        if ([appsArray count] > 0) {
            [self shareWithTwitter];
        } else {
            // after we're done, share with Facebook
            self.appLookupCallbackSelector = @selector(shareWithTwitter);
            
            isLoadingApps = YES;
            
            HUD = [[MBProgressHUD alloc] initWithView:self.view];
            
            // Add HUD to screen
            [self.view addSubview:HUD];
            
            // Regisete for HUD callbacks so we can remove it from the window at the right time
            HUD.delegate = self;
            // HUD.minShowTime = 2.0;
            [HUD show:YES];
            [self loadApps];
        }
    }
}

- (void)shareWithFacebook {
    NSString *status = @"http://bit.ly/h52GZD";
    // as per: http://www.bagonca.com/blog/2009/04/08/iphone-tip-1-url-encoding-in-objective-c/
    NSString *statusEncoded = (NSString *) CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)status, NULL, CFSTR(":/?#[]@!$&’()*+,;="), kCFStringEncodingUTF8));
    
    // app ids:
    // int facebookId = 284882215;
    
    NSString *url;
    /*
    // go through the apps. if we find a good app, then we will use it.
    if ([self hasApp:facebookId]) {
        // There is the official Facebook app, load it up there:
        url = [NSString stringWithFormat:@"fb://publish/profile/me?text=%@", statusEncoded];
    } else {
        // there is no facebook app. Just load it in the web browser
        url = [NSString stringWithFormat:@"http://www.facebook.com/iphoneflashcards/"];
    }
    if (HUD && isLoadingApps) {
        [HUD hide:YES];
    }
     */
    
    url = [NSString stringWithFormat:@"http://touch.facebook.com/sharer.php?u=%@", statusEncoded];
    isLoadingApps = NO;
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
}

- (void)shareWithTwitter {
    NSString *status = @"Check out FlashCards++ http://bit.ly/h52GZD @studyflashcards";
    // as per: http://www.bagonca.com/blog/2009/04/08/iphone-tip-1-url-encoding-in-objective-c/
    NSString *statusEncoded = (NSString *) CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)status, NULL, CFSTR(":/?#[]@!$&’()*+,;="), kCFStringEncodingUTF8));
    
    // app ids:
    int twitterId = 333903271;
    
    NSString *url;
    
    // URL schemes: http://handleopenurl.com/search?scheme=twitter
    
    // go through the apps. if we find a good app, then we will use it.
    if ([self hasApp:twitterId]) {
        // There is the official Twitter app, load it up there:
        url = [NSString stringWithFormat:@"twitter://post?message=%@", statusEncoded];
    } else {
        // there is no twitter app. Load it in the web browser
        // as per: http://stuff.nekhbet.ro/2009/08/24/how-to-prefill-the-twitter-status-box-what-are-you-doing.html
        url = [NSString stringWithFormat:@"http://twitter.com/home?status=%@", statusEncoded];
    }
    if (HUD && isLoadingApps) {
        [HUD hide:YES];
    }
    isLoadingApps = NO;
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];

}

# pragma mark -
# pragma mark MFMailComposeViewControllerDelegate functions

- (void)mailComposeController:(MFMailComposeViewController*)controller  
          didFinishWithResult:(MFMailComposeResult)result 
                        error:(NSError*)error;
{
    if (result == MFMailComposeResultSent) {
        //    NSLog(@"It's away!");
    } else if (result == MFMailComposeResultFailed) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Error", @"Error", @"UIAlert title")
                                                         message:[NSString stringWithFormat:NSLocalizedStringFromTable(@"An error occurred sending your message: %@ %@", @"Error", @"message"), error, [error userInfo]]
                                                        delegate:nil
                                               cancelButtonTitle:NSLocalizedStringFromTable(@"OK", @"FlashCards", @"cancelButtonTitle")
                                               otherButtonTitles:nil];
        [alert show];
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}


@end
