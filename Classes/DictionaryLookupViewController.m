//
//  DictionaryLookupViewController.m
//  FlashCards
//
//  Created by Jason Lustig on 7/26/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import "FlashCardsAppDelegate.h"
#import "DictionaryLookupViewController.h"
#import "Reachability.h"

@implementation DictionaryLookupViewController

@synthesize webView, bottomToolbar, activityIndicator;
@synthesize isAddingMode;
@synthesize sourceLanguage, targetLanguage, term;
@synthesize theConnection, receivedData;
@synthesize internetReach, isFirstLoad;

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
    
    self.title = NSLocalizedStringFromTable(@"Dictionary Lookup", @"CardManagement", @"view title");
    bottomToolbar.hidden = NO;

    activityIndicator = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(0, 0, 20, 20)];
    UIBarButtonItem *activityItem = [[UIBarButtonItem alloc] initWithCustomView:activityIndicator];
    self.navigationItem.rightBarButtonItem = activityItem;
    
    if (!isAddingMode) {
        NSMutableArray *items = [bottomToolbar.items mutableCopy];
        [items removeLastObject];
        bottomToolbar.items = items;
    }
    
    receivedData = [[NSMutableData alloc] initWithLength:0];
    
    // Observe the kNetworkReachabilityChangedNotification. When that notification is posted, the
    // method "reachabilityChanged" will be called. 
    [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(reachabilityChanged:) name: kReachabilityChangedNotification object: nil];
    
    internetReach = [Reachability reachabilityForInternetConnection];
    [internetReach startNotifier];
    isFirstLoad = YES;
    [self loadWebViewWithReachability:internetReach];

}

- (void) loadWebViewWithReachability: (Reachability*) curReach {
    NetworkStatus netStatus = [curReach currentReachabilityStatus];
    if (netStatus == NotReachable) {
        FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"No Internet Connection", @"Error", @"UIAlert title"),
                                   [NSString stringWithFormat:@"%@ %@",
                                    NSLocalizedStringFromTable(@"You are not connected to the internet.", @"Error", @""),
                                    NSLocalizedStringFromTable(@"This feature will only work with an active internet connection.", @"Error", @"message")]);
    } else {
        if (isFirstLoad) {
            NSString *url = [self generateURL];
            [webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:url]]];
            isFirstLoad = NO;
        } else {
            [webView reload];
        }
    }
}

//Called by Reachability whenever status changes.
- (void) reachabilityChanged: (NSNotification* )note
{
    Reachability* curReach = [note object];
    NSParameterAssert([curReach isKindOfClass: [Reachability class]]);
    [self loadWebViewWithReachability: curReach];
}


- (NSString *)generateURL {
    return [NSString stringWithFormat:@"http://translate.google.com/#%@|%@|%@",
            sourceLanguage,
            targetLanguage,
            [term stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
}

- (NSString *)currentHTML {
    return [webView stringByEvaluatingJavaScriptFromString:@"document.body.innerHTML"];
}

- (void)webViewDidStartLoad:(UIWebView *)webView {
    [activityIndicator startAnimating];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    
    
    [activityIndicator stopAnimating];
    
    
}

- (BOOL)webView:(UIWebView*)webView shouldStartLoadWithRequest:(NSURLRequest*)request navigationType:(UIWebViewNavigationType)navigationType {
    // theConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    return YES;
}

- (BOOL)shouldAutorotate {
    UIInterfaceOrientation interfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    return [FlashCardsAppDelegate shouldAutorotate:interfaceOrientation];
}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

# pragma mark -
# pragma mark Connection functions

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    
    // This method is called when the server has determined that it
    // has enough information to create the NSURLResponse.
    
    
    // It can be called multiple times, for example in the case of a
    // redirect, so each time we reset the data.
    
    // receivedData is an instance variable declared elsewhere.
    
    // NSLog(@"Expected content length: %d", [response expectedContentLength]);
    
    
    [receivedData setLength:0];
    
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    
    // Append the new data to receivedData.
    [receivedData appendData:data];
    
    // receivedData is an instance variable declared elsewhere.
    // NSNumber *resourceLength = [NSNumber numberWithUnsignedInteger:[self.receivedData length]];
    // NSLog(@"resourceData length: %d", [resourceLength intValue]);
      
    
    
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"Error", @"Error", @"UIAlert title"),
                               [NSString stringWithFormat:NSLocalizedStringFromTable(@"Error downloading data: %@, %@", @"Error", @"error message"), [error localizedDescription], [error userInfo]]);
    return;
    
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    
    // do something with the data
    // receivedData is declared as a method instance elsewhere
    
    // NSLog(@"Succeeded! Received %d bytes of data",[receivedData length]);
    
    
     
    NSString *receivedHtml = [[NSString alloc] initWithData:receivedData encoding:NSUTF8StringEncoding];

    /*
    // 1. Remove the google bar up top:
    receivedHtml = [receivedHtml stringByReplacingOccurrencesOfRegex:@"<div id=gbar>[\\w\\W]*?<\\/nobr><\\/div>" withString:@""];
    
    // 2. Remove the user bar up top if it's there:
    receivedHtml = [receivedHtml stringByReplacingOccurrencesOfRegex:@"<div[\\w\\W^>]*?id=guser[\\w\\W^>]*?>[\\w\\W]*?<\\/nobr><\\/div>" withString:@""];
    
    // 3. Remove the link around the google image (actually this removes the entire google image):
    receivedHtml = [receivedHtml stringByReplacingOccurrencesOfRegex:@"<td class=\"tc\" valign=\"top\">[\\w\\W]*?<\\/td>" withString:@""];

    // 4. Remove the links at the bottom of the page, but retain the "Copyright google" message:
    
    receivedHtml = [receivedHtml stringByReplacingOccurrencesOfRegex:@"<a href=\"http\\:\\/\\/www\\.google\\.com\\/webhp\\?hl=en\">Google\\&nbsp\\;Home<\\/a>" withString:@""];
    receivedHtml = [receivedHtml stringByReplacingOccurrencesOfRegex:@"<a href=\"http\\:\\/\\/www\\.google\\.com\\/intl\\/en\\/about\\.html\">All About Google<\\/a>" withString:@""];
    
    // 5. hide the language box, and move down the submit button:
    receivedHtml = [receivedHtml stringByAppendingString:@"<style>#gs-box {display:none;} input { display:block; }</style>"];
    
     */
    [webView loadHTMLString:receivedHtml baseURL:[NSURL URLWithString:[self generateURL]]]; 
        
}

# pragma mark -
# pragma mark Memory functions

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    
    self.webView = nil;
    self.bottomToolbar = nil;
    self.activityIndicator = nil;
}




@end
