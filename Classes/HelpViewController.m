//
//  HelpViewController.m
//  FlashCards
//
//  Created by Jason Lustig on 6/17/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import "FlashCardsAppDelegate.h"
#import "HelpViewController.h"

#import "NSString+Markdown.h"
#import "NSString+HTML.h"

@implementation HelpViewController

@synthesize helpTextView, helpText;
@synthesize usesMath;

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
    
    

    if (self.usesMath) {
        // encode MathJax special characters so they are not screwed up by MarkDown:
        NSString *mathJaxEncoded = [helpText stringByEncodingMathJaxEntities];
        NSString *simpleHtml = [mathJaxEncoded toSimpleHtml];
        helpText = [simpleHtml stringByDecodingMathJaxEntities];
        
        // helpText = [helpText toSimpleHtml];
        
        NSURL* url = [FlashCardsCore urlForLatexMathString:helpText withJustification:@"left" withSize:12];
        helpTextView.scalesPageToFit = YES;
        helpTextView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
        NSURLRequest* req = [[NSURLRequest alloc] initWithURL:url];
        [helpTextView loadRequest:req];
    } else {
        
    helpText = [helpText toHtml];
    
    [helpTextView loadHTMLString:[helpText stringByAppendingString:@""
                                  "<style>"
                                  " p, ol, ul { font-family: Baskerville; }"
                                  " h1 { font-family: Futura; font-size: 1.2em; }"
                                  " ol, ul { padding-left: 25px; }"
                                  "</style>"
                                  ] baseURL:[NSURL URLWithString:@"http://www.google.com"]];
    }
}

// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotate {
    UIInterfaceOrientation interfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    return [FlashCardsAppDelegate shouldAutorotate:interfaceOrientation];
}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
    [super viewDidUnload];
    
    helpTextView = nil;
    
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}




@end
