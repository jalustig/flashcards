//
//  CollectionEFactorChartViewController.m
//  FlashCards
//
//  Created by Jason Lustig on 6/16/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import "FlashCardsAppDelegate.h"
#import "CollectionEFactorChartViewController.h"
#import "HelpViewController.h"

#import "FCCollection.h"
#import "FCCardSet.h"
#import "FCCard.h"

#import "DTVersion.h"

@implementation CollectionEFactorChartViewController

@synthesize collection, cardSet;
@synthesize eFactorCounts, graph, memorizedOnly, lapsedOnly;
@synthesize fetchedResultsController;

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

    if (memorizedOnly) {
        self.title = NSLocalizedStringFromTable(@"E-Factors", @"FlashCards", @"UIView title");
    } else {
        if (lapsedOnly) {
            self.title = NSLocalizedStringFromTable(@"E-Factors (Lapsed Only)", @"CardManagement", @"UIView title");
        } else {
            self.title = NSLocalizedStringFromTable(@"E-Factors (All Cards)", @"CardManagement", @"UIView title");
        }
    }
    
    // Help buttons
    UIButton *helpButton = [UIButton buttonWithType:UIButtonTypeInfoLight];
    [helpButton addTarget:self action:@selector(helpEvent) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *rightItem = [[UIBarButtonItem alloc] initWithCustomView:helpButton];
    self.navigationItem.rightBarButtonItem = rightItem;
    
    
    // Create the structure which will hold the counts:
    eFactorCounts = [[NSMutableArray alloc] initWithCapacity:([SMCore calcColNum:maxEFactor]+1)];
    for (int i = 0; i <= [SMCore calcColNum:maxEFactor]; i++) {
        [eFactorCounts addObject:[NSNumber numberWithInt:0]];
    }
    
    // Now, get all of the cards from the database:
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    // Edit the entity name as appropriate.
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Card" inManagedObjectContext:[FlashCardsCore mainMOC]];
    if (self.collection) {
        if (memorizedOnly) {
            [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"isDeletedObject = NO and collection = %@ and isSpacedRepetition = YES", collection]];
        } else if (lapsedOnly) {
            [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"isDeletedObject = NO and collection = %@ and isLapsed = YES", collection]];
        } else {
            [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"isDeletedObject = NO and collection = %@", collection]];
        }
    } else {
        if (memorizedOnly) {
            [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"isDeletedObject = NO and any cardSet = %@ and isSpacedRepetition = YES", cardSet]];
        } else if (lapsedOnly) {
            [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"isDeletedObject = NO and any cardSet = %@ and isLapsed = YES", cardSet]];
        } else {
            [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"isDeletedObject = NO and any cardSet = %@", cardSet]];
        }
    }
    [fetchRequest setEntity:entity];
    [fetchRequest setPropertiesToFetch:[NSArray arrayWithObjects:@"eFactor", nil]];
    [fetchRequest setResultType: NSDictionaryResultType];

    // Edit the sort key as appropriate.
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"eFactor" ascending:YES];
    NSArray *sortDescriptors = [[NSArray alloc] initWithObjects:sortDescriptor, nil];
    
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    NSError *error;
    NSArray *cards = (NSMutableArray *)[[FlashCardsCore mainMOC] executeFetchRequest:fetchRequest error:&error];
    if (cards == nil) {
        // TODO: handle the error
    }
    
    
    FCCard *currentCard;
    double simpleEFactor;
    int colNum, count;
    // Go through the cards, and count how many are in each day:
    for (int j = 0; j < [cards count]; j++) {
        currentCard = [cards objectAtIndex:j];
        simpleEFactor = [SMCore roundEFactor:[[currentCard valueForKey:@"eFactor"] doubleValue]];
        // NSLog(@"eFactor -> %1.2f / %1.2f", [currentCard.eFactor doubleValue], simpleEFactor);
        colNum = [SMCore calcColNum:simpleEFactor];
        count = [[eFactorCounts objectAtIndex:colNum] intValue];
        [eFactorCounts replaceObjectAtIndex:colNum withObject:[NSNumber numberWithInt:(count+1)]];
    }
    int maxCount = 5;
    for (int k = 0; k < [eFactorCounts count]; k++) {
        if ([[eFactorCounts objectAtIndex:k] intValue] > maxCount) {
            maxCount = [[eFactorCounts objectAtIndex:k] intValue];
        }
    }
     
    graph = [[CPTXYGraph alloc] initWithFrame:self.view.bounds];
    self.view = [[CPTGraphHostingView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    CPTGraphHostingView *hostingView = (CPTGraphHostingView *)self.view;
    hostingView.hostedGraph = graph;
    graph.paddingLeft = 10.0;
    graph.paddingTop = 20.0; // 74.0; // 20.0;
    graph.paddingRight = 20.0;
    graph.paddingBottom = 20.0;
    
    CPTXYPlotSpace *plotSpace =  (CPTXYPlotSpace *)graph.defaultPlotSpace;
    plotSpace.xRange = [CPTPlotRange plotRangeWithLocation:fc_CPTDecimalFromFloat(minEFactor-0.35)
                                                    length:fc_CPTDecimalFromFloat(maxEFactor-minEFactor+0.45)];
    double minYValue = -1*maxCount/10;
    double yLength = maxCount * 1.2;
    double maxYValue = minYValue + yLength;
    while (-1*(minYValue / maxYValue) < 0.09) {
        // NSLog(@"%1.2f / %1.2f = %1.2f", minYValue, maxYValue, (minYValue / maxYValue));
        minYValue -= 1;
        yLength += 1;
        maxYValue = minYValue + yLength;
    }
    // NSLog(@"%1.2f / %1.2f = %1.2f", minYValue, maxYValue, (minYValue / maxYValue));
    plotSpace.yRange = [CPTPlotRange plotRangeWithLocation:fc_CPTDecimalFromFloat(minYValue)
                                                    length:fc_CPTDecimalFromFloat(yLength)];
     
    CPTMutableLineStyle *lineStyle =  [CPTMutableLineStyle lineStyle];
    lineStyle.lineColor = [CPTColor blackColor];
    lineStyle.lineWidth = 2.0f;
    
    CPTXYAxisSet *axisSet = (CPTXYAxisSet *)graph.axisSet;
    axisSet.xAxis.majorIntervalLength = fc_CPTDecimalFromFloat(0.5);
    axisSet.xAxis.minorTicksPerInterval = 4;
    axisSet.xAxis.majorTickLineStyle = lineStyle;
    axisSet.xAxis.minorTickLineStyle = lineStyle;
    axisSet.xAxis.axisLineStyle = lineStyle;
    axisSet.xAxis.minorTickLength = 5.0f;
    axisSet.xAxis.majorTickLength = 7.0f;
    axisSet.xAxis.title = NSLocalizedStringFromTable(@"E-Factors", @"FlashCards", @"");
    axisSet.xAxis.titleOffset = 20.0f;
    axisSet.xAxis.visibleRange = [CPTPlotRange plotRangeWithLocation:fc_CPTDecimalFromFloat(minEFactor-0.1)
                                                              length:fc_CPTDecimalFromFloat(maxEFactor-minEFactor+0.2)];
    
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
    
    int majorIntervalLength;
    if (maxCount < 50) {
        majorIntervalLength = 5;
    } else if (maxCount < 100) {
        majorIntervalLength = 10;
    } else if (maxCount < 300) {
        majorIntervalLength = 25;
    } else if (maxCount < 500) {
        majorIntervalLength = 50;
    } else if (maxCount < 1000) {
        majorIntervalLength = 100;
    } else if (maxCount < 3000) {
        majorIntervalLength = 250;
    } else if (maxCount < 5000) {
        majorIntervalLength = 500;
    } else {
        majorIntervalLength = 1000;
    }
    
    axisSet.yAxis.majorIntervalLength = fc_CPTDecimalFromFloat(majorIntervalLength);
    axisSet.yAxis.minorTicksPerInterval = 4;
    axisSet.yAxis.labelFormatter = formatter;
    axisSet.yAxis.majorTickLineStyle = lineStyle;
    axisSet.yAxis.minorTickLineStyle = lineStyle;
    axisSet.yAxis.axisLineStyle = lineStyle;
    axisSet.yAxis.minorTickLength = 5.0f;
    axisSet.yAxis.majorTickLength = 7.0f;
    // TODO: Depricated??
    // axisSet.yAxis.orthogonalCoordinateDecimal = fc_CPTDecimalFromFloat(1.1f);
    axisSet.yAxis.title = NSLocalizedStringFromTable(@"# Cards", @"FlashCards", @"");
    axisSet.yAxis.titleOffset = 20.0f;
    axisSet.yAxis.visibleRange = [CPTPlotRange plotRangeWithLocation:fc_CPTDecimalFromFloat(0)
                                                              length:fc_CPTDecimalFromFloat(maxCount * 1.2)];

    
    CPTBarPlot *eFactorPlot = [[CPTBarPlot alloc]
                                    initWithFrame:self.graph.defaultPlotSpace.graph.bounds];

    eFactorPlot.identifier = NSLocalizedStringFromTable(@"E-Factor", @"FlashCards", @"");
    eFactorPlot.dataSource = self;

    double spaceAvailableOnXaxis = 320;
    spaceAvailableOnXaxis = spaceAvailableOnXaxis - (self.graph.paddingLeft + self.graph.paddingRight);
    // double barWidth = spaceAvailableOnXaxis / (((int)((maxEFactor - minEFactor) * 10) + 1) + 5.5);
    eFactorPlot.barWidth = fc_CPTDecimalFromFloat(0.1f);
    // [eFactorPlot setBarWidth:CPTDecimalFromFloat(0.5f)];
    // [eFactorPlot setBarWidth:CPTDecimalFromDouble(barWidth)];
    
    // eFactorPlot.barWidth = 5.0f;
    eFactorPlot.fill = [CPTFill fillWithColor:[CPTColor redColor]];
    [graph addPlot:eFactorPlot];
    
}

- (void) helpEvent {
    HelpViewController *helpVC = [[HelpViewController alloc] initWithNibName:@"HelpViewController" bundle:nil];
    
    helpVC.title = self.title;
    helpVC.helpText = NSLocalizedStringWithDefaultValue(@"CollectionEFactorChartViewController", @"Help", [NSBundle mainBundle], @"<p>Based upon your responses to card tests and repetitions, each card is assigned an \"e-factor\" ranging between 1.2 to 2.5. The e-factor represents how easy or difficult the card is, with a lower e-factor meaning that the card is more difficult and a higher e-factor meaning that the card is easier. This chart displays the distribution of e-factors amongst cards in this collection.</p>", @"");
    // Pass the selected object to the new view controller.
    [self.navigationController pushViewController:helpVC animated:YES];
    
}

- (BOOL)shouldAutorotate {
    UIInterfaceOrientation interfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    return [FlashCardsAppDelegate shouldAutorotate:interfaceOrientation];
}

-(NSUInteger)numberOfRecordsForPlot:(CPTPlot *)plot {
    return [eFactorCounts count];
}

-(NSNumber *)numberForPlot:(CPTPlot *)plot
                     field:(NSUInteger)fieldEnum
               recordIndex:(NSUInteger)index
{
    NSNumber *num;
    // NSLog(@"fieldEnum = %d",fieldEnum);
    switch (fieldEnum) {
        case CPTBarPlotFieldBarBase:
            
            break;
        default:
        case CPTBarPlotFieldBarLocation:
            num = (NSDecimalNumber *)[NSDecimalNumber numberWithDouble:[SMCore calcEFactorFromColumn:index]];
            NSLog(@"CPTBarPlotFieldBarLocation return num = %@",num);
            break;
        case CPTBarPlotFieldBarTip:
            /*CPBarPlotFieldBarLength*/
            num = [NSNumber numberWithDouble:((double)[[eFactorCounts objectAtIndex:index] intValue])];
            // NSLog(@"CPTBarPlotFieldBarTip return num = %@",num);
            break;
    }
    return num;
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
