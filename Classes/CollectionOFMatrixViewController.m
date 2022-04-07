//
//  CollectionOFMatrixViewController.m
//  FlashCards
//
//  Created by Jason Lustig on 6/20/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import "FlashCardsAppDelegate.h"
#import "CollectionOFMatrixViewController.h"
#import "HelpViewController.h"

#import "FCCollection.h"
#import "FCMatrix.h"

#import "DTVersion.h"

@implementation CollectionOFMatrixViewController

@synthesize collection, textView;
@synthesize resetOptimalFactorMatrixButton;

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
    
    if (![DTVersion osVersionIsLessThen:@"7.0"]) {
        self.edgesForExtendedLayout= UIRectEdgeNone;
    }
    
    self.title = NSLocalizedStringFromTable(@"Optimal Factors", @"Statistics", @"UIView title");
    
    resetOptimalFactorMatrixButton.title = NSLocalizedStringFromTable(@"Reset Optimal Factor Matrix", @"Statistics", @"UIBarButtonItem");
    
    // Help buttons
    UIButton *helpButton = [UIButton buttonWithType:UIButtonTypeInfoLight];
    [helpButton addTarget:self action:@selector(helpEvent) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *rightItem = [[UIBarButtonItem alloc] initWithCustomView:helpButton];
    self.navigationItem.rightBarButtonItem = rightItem;
    
    // load the HTML:
    [self loadOFMatrix];

}

- (BOOL)shouldAutorotate {
    UIInterfaceOrientation interfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    return [FlashCardsAppDelegate shouldAutorotate:interfaceOrientation];
}

- (void) loadOFMatrix {
    [textView loadHTMLString:[SMCore outputOptimalFactorMatrixAsHtml:collection] baseURL:[NSURL URLWithString:@"http://www.google.com"]];
}

- (void) helpEvent {
    HelpViewController *helpVC = [[HelpViewController alloc] initWithNibName:@"HelpViewController" bundle:nil];
    
    helpVC.title = self.title;
    helpVC.helpText = NSLocalizedStringWithDefaultValue(@"CollectionOFMatrixVCHelp", @"Help", [NSBundle mainBundle], @""
    "<p>FlashCards++ works on the assumption that the optimal time to study a card is when "
    "you are just about to forget it. To estimate the best time to study, FlashCards++ uses "
    "an advanced algorithm, based on SuperMemo's SM-5, which at its core utilizes a tool called "
    "the matrix of Optimal Factors, or OF-Matrix for short. This matrix auto-adjusts to keep "
    "track of how long you should study a card depending on its difficulty (E-Factor) and repetition. "
    "The E-Factors are listed across the top of the matrix, and the repetition number is listed across "
    "the left-hand side.</p>"
    "<p>This matrix is used as follows: When you study a card, if you get it right (score > 3), then the "
    "next repetition is calculated to be: previousRepetitionLength * OF-Value, where the optimal value "
    "is based on this table.</p>"
    "<p>When you create a new collection, we begin with a base or univalent matrix of optimal factors "
    "built directly upon the values of the E-Factors. However as you study more, based on your self-scoring "
    "FlashCards++ auto-adjusts this matrix to better calculate the best spacing between repetitions. Cells "
    "with a red background indicate that this item has been adjusted by the study algorithm.</p>", @"");
    // Pass the selected object to the new view controller.
    [self.navigationController pushViewController:helpVC animated:YES];
    
}

- (IBAction)alertResetOFMatrix:(id)sender {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Are You Sure?", @"FlashCards", @"UIAlert title")
                                                     message:NSLocalizedStringFromTable(@"Are you sure you want to reset the matrix of Optimal Factors? This matrix has been adjusted to match the knowledge stored in this Collection and your individual study habits.", @"Statistics", @"message")
                                                    delegate:self
                                           cancelButtonTitle:NSLocalizedStringFromTable(@"Don't Reset", @"Statistics", @"cancelButtonTitle")
                                           otherButtonTitles:NSLocalizedStringFromTable(@"Yes, Reset", @"Statistics", @"otherButtonTitles"), nil];
    [alert show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 1) {
        // reset the OF Matrix and tell the user that it has been done:
        
        NSMutableArray *oFactorMatrix, *matrix;
        
        oFactorMatrix = [SMCore newOFactorMatrix];
        [collection setOfMatrix:oFactorMatrix];
        
        matrix = [SMCore newOFactorAdjustedMatrix];
        [collection setOfMatrixAdjusted:matrix];

        [FlashCardsCore saveMainMOC];

        [self loadOFMatrix];
        
        FCDisplayBasicErrorMessage(@"",
                                   NSLocalizedStringFromTable(@"The matrix of Optimal Factors has been reset to its default settings.", @"Statistics", @"message"));
    }
}


- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    
    textView = nil;
    
}




@end
