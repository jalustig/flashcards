//
//  CollectionScoreChartViewController.m
//  FlashCards
//
//  Created by Jason Lustig on 7/22/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import "FlashCardsAppDelegate.h"
#import "CollectionScoreChartViewController.h"
#import "HelpViewController.h"
#import "FCMatrix.h"

#import "FCCollection.h"
#import "FCCardSet.h"

#import "DTVersion.h"

@implementation CollectionScoreChartViewController

@synthesize cardSet, collection;
@synthesize textView;

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

    self.title = NSLocalizedStringFromTable(@"Repetition Scores", @"Statistics", @"UIView title");
    
    // Help buttons
    UIButton *helpButton = [UIButton buttonWithType:UIButtonTypeInfoLight];
    [helpButton addTarget:self action:@selector(helpEvent) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *rightItem = [[UIBarButtonItem alloc] initWithCustomView:helpButton];
    self.navigationItem.rightBarButtonItem = rightItem;
    
    // load the HTML:
    [self loadScoreChart];
    
}

- (void) loadScoreChart {
    
    // NSMutableDictionary *location = [FCMatrix locationDictionary:nil x:[FCMatrix numCols:collection.ofMatrix] y:[FCMatrix numRows:collection.ofMatrix]];
    // NSMutableArray *scoreMatrix = [FCMatrix initWithDimensionsAndValues:location initValue:[NSNumber numberWithFloat:0]];
    
    
    // Now, get all of the card repetitions from the database:
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    // Edit the entity name as appropriate.
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"CardRepetition"
                                              inManagedObjectContext:[FlashCardsCore mainMOC]];
    if (self.collection) {
        [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"card.isDeletedObject = NO and card.collection = %@", collection]];
    } else {
        [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"card.isDeletedObject = NO and any card.cardSet = %@", cardSet]];
    }
    [fetchRequest setEntity:entity];
    [fetchRequest setPropertiesToFetch:[NSArray arrayWithObjects:@"score", @"repetitionNumber", @"eFactor", nil]];
    
    // Edit the sort key as appropriate.
    NSSortDescriptor *repetitionSD = [[NSSortDescriptor alloc] initWithKey:@"repetitionNumber" ascending:YES];
    NSSortDescriptor *eFactorSD = [[NSSortDescriptor alloc] initWithKey:@"eFactor" ascending:YES];
    NSArray *sortDescriptors = [[NSArray alloc] initWithObjects:repetitionSD, eFactorSD, nil];
    
    [fetchRequest setSortDescriptors:sortDescriptors];
    [fetchRequest setResultType: NSDictionaryResultType];
    [fetchRequest setReturnsObjectsAsFaults:NO];
        
    NSError *error;
    NSArray *cardRepetitions = (NSMutableArray *)[[FlashCardsCore mainMOC] executeFetchRequest:fetchRequest error:&error];
    if (cardRepetitions == nil) {
        // TODO: handle the error
    }
    
    
    
    NSMutableString *html = [[NSMutableString alloc] initWithCapacity:0]; 
    
    int x, y;
    
    NSMutableDictionary *location = [FCMatrix locationDictionary:nil x:0 y:0];
    
    // NSArray *cellRepetitions;
    // NSPredicate *predicate;
    
    [html appendString:@"<table>"];
    [html appendFormat:@"<tr><th colspan=\"2\">&nbsp;</th><th colspan=\"%d\" align=\"center\">%@</th></tr>", (((int)((maxEFactor - minEFactor) * 10))+1), NSLocalizedStringFromTable(@"E-Factors", @"FlashCards", @"")];
    [html appendString:@"<tr>"];
    [html appendFormat:@"<th rowspan=\"%d\" valign=\"center\" style=\"width: 1em !important;\"><div style=\"width:1em !important; -webkit-transform: rotate(-90deg);\">%@</div></th>", ([FCMatrix numRows:collection.ofMatrix]+1), NSLocalizedStringFromTable(@"Repetitions", @"Statistics", @"")];
    [html appendString:@"<th>&nbsp;</th>"];
    for (double i = minEFactor+0.1; i <= maxEFactor+0.01; i += 0.1) {
        [html appendFormat:@"<th>&lt;%1.1f</th>", i];
    }
    [html appendString:@"</tr>"];
    
    double avgScore;
    int avgScoreCount;
    double maxCellEFactor;
    
    int repetitionCount = 0;
    int repetitionNumber;
    NSDictionary *repetition;
    
    for (y = 1; y < [FCMatrix numRows:collection.ofMatrix]; y++) {
        

        if (repetitionCount >= [cardRepetitions count]) {
            break;
        }

        [html appendString:@"<tr>"];
        [html appendFormat:@"<th>%d</th>", y];
        
        [location setObject:[NSValue value:&y withObjCType:@encode(NSNumber)] forKey:@"y"];
        for (x = 0; x < [FCMatrix numCols:collection.ofMatrix]; x++) {
            
            [location setObject:[NSValue value:&x withObjCType:@encode(NSNumber)] forKey:@"x"];
            
            maxCellEFactor = (float)(minEFactor + ((x+1)*0.1));
        
            repetitionNumber = y;
            
            avgScore = 0.0;
            avgScoreCount = 0;
            if (repetitionCount < [cardRepetitions count]) {
                repetition = (NSDictionary*)[cardRepetitions objectAtIndex:repetitionCount];
                
                while (repetitionCount < [cardRepetitions count] && [[repetition valueForKey:@"repetitionNumber"] intValue] == repetitionNumber && [[repetition valueForKey:@"eFactor"] doubleValue] <= maxCellEFactor) {
                    avgScore += [[repetition valueForKey:@"score"] doubleValue];
                    avgScoreCount++;
                    repetitionCount++;
                    if (repetitionCount >= [cardRepetitions count]) {
                        break;
                    }
                    repetition = (NSDictionary*)[cardRepetitions objectAtIndex:repetitionCount];
                }
                
                if (avgScoreCount > 0) {
                    avgScore /= avgScoreCount;
                }
            }            
            
            if (avgScore > 0) {
                [html appendFormat:@"<td>%1.2f</td>", avgScore];
            } else {
                [html appendFormat:@"<td>&nbsp;</td>"];
            }
        }
        
        [html appendString:@"</tr>"];
        
    }
    
    [html appendString:@"</table>"];
    
    [textView loadHTMLString:html baseURL:[NSURL URLWithString:@"http://www.google.com"]];
    
}

- (void) helpEvent {
    HelpViewController *helpVC = [[HelpViewController alloc] initWithNibName:@"HelpViewController" bundle:nil];
    
    helpVC.title = self.title;
    helpVC.helpText = NSLocalizedStringWithDefaultValue(@"CollectionScoreChartVC", @"Help", [NSBundle mainBundle], @"<p>This chart displays the average score for cards in each E-Factor range by repetition number. Scores range from 1-5.</p>", @"");
    // Pass the selected object to the new view controller.
    [self.navigationController pushViewController:helpVC animated:YES];
    
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

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}




@end
