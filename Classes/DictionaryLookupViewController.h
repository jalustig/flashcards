//
//  DictionaryLookupViewController.h
//  FlashCards
//
//  Created by Jason Lustig on 7/26/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import <UIKit/UIKit.h>


@class Reachability;

@interface DictionaryLookupViewController : UIViewController <UIWebViewDelegate>

- (NSString *) generateURL;
- (NSString *) currentHTML;
- (void) reachabilityChanged: (NSNotification* )note;
- (void) loadWebViewWithReachability: (Reachability*) curReach;

@property (nonatomic, weak) IBOutlet UIWebView *webView;
@property (nonatomic, weak) IBOutlet UIToolbar *bottomToolbar;
@property (nonatomic, weak) IBOutlet UIActivityIndicatorView *activityIndicator;

@property (nonatomic, assign) BOOL isAddingMode;

@property (nonatomic, strong) NSString *sourceLanguage;
@property (nonatomic, strong) NSString *targetLanguage;
@property (nonatomic, strong) NSString *term;

@property (nonatomic, strong) NSURLConnection *theConnection;
@property (nonatomic, strong) NSMutableData *receivedData;

@property (nonatomic, strong) Reachability* internetReach;
@property (nonatomic, assign) bool isFirstLoad;

@end
