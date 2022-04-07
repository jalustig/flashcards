//
//  CollectionCardsStudiedByDayViewController.m
//  FlashCards
//
//  Created by Jason Lustig on 7/16/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import "FlashCardsAppDelegate.h"
#import "CollectionCardsStudiedByDayViewController.h"
#import "HelpViewController.h"

#import "FCCardRepetition.h"
#import "FCCollection.h"
#import "FCCardSet.h"

#import "NSDate+Compare.h"

#import "DTVersion.h"

#import "CPTUtilities.h"

@implementation CollectionCardsStudiedByDayViewController

@synthesize collection, cardSet, isLapsed;
@synthesize dateCounts, graph, mode, launchedFromChoices;

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

    NSString *defaultTitle;
    NSString *yAxisTitle;
    NSString *plotIdentifier;
    if (isLapsed) {
        yAxisTitle = NSLocalizedStringFromTable(@"# Cards Lapsed", @"Statistics", @"yAxisTitle");
        plotIdentifier = NSLocalizedStringFromTable(@"Cards Lapsed", @"Statistics", @"plotIdentifier");
        defaultTitle = NSLocalizedStringFromTable(@"Lapsed By Day", @"Statistics", @"UIView title");
    } else {
        yAxisTitle = NSLocalizedStringFromTable(@"# Cards Studied", @"Statistics", @"yAxisTitle");
        plotIdentifier = NSLocalizedStringFromTable(@"Cards Studied", @"Statistics", @"plotIdentifier");
        defaultTitle = NSLocalizedStringFromTable(@"Studied By Day", @"Statistics", @"UIView title");
    }
    
    if (!launchedFromChoices) {
        self.title = defaultTitle;
    } else if (mode == cardsStudiedByDay) {
        self.title = NSLocalizedStringFromTable(@"By Day", @"Statistics", @"UIView Title; i.e., 'Lapsed By Day'");
    } else if (mode == cardsStudiedByWeek) {
        self.title = NSLocalizedStringFromTable(@"By Week", @"Statistics", @"UIView Title; i.e., 'Lapsed By Week'");
    } else if (mode == cardsStudiedByMonth) {
        self.title = NSLocalizedStringFromTable(@"By Month", @"Statistics", @"UIView Title; i.e., 'Lapsed By Month'");
    } else {
        self.title = defaultTitle;
    }
    
    // Help buttons
    UIButton *helpButton = [UIButton buttonWithType:UIButtonTypeInfoLight];
    [helpButton addTarget:self action:@selector(helpEvent) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *rightItem = [[UIBarButtonItem alloc] initWithCustomView:helpButton];
    self.navigationItem.rightBarButtonItem = rightItem;
    
    
    // Create the structure which will hold the counts:
    dateCounts = [[NSMutableArray alloc] initWithCapacity:0];
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    // Edit the entity name as appropriate.
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"CardRepetition"
                                              inManagedObjectContext:[FlashCardsCore mainMOC]];
    
    
    NSMutableArray *predicates = [[NSMutableArray alloc] initWithCapacity:0];
    [predicates addObject:[NSPredicate predicateWithFormat:@"card.isDeletedObject = NO"]];
    if (self.collection) {
        [predicates addObject:[NSPredicate predicateWithFormat:@"card.collection = %@", collection]];
    } else {
        [predicates addObject:[NSPredicate predicateWithFormat:@"any card.cardSet = %@", cardSet]];
    }
    
    if (isLapsed) {
        [predicates addObject:[NSPredicate predicateWithFormat:@"score < 3"]];
    }
    
    [fetchRequest setPredicate:[NSCompoundPredicate andPredicateWithSubpredicates:predicates]];
    
    
    [fetchRequest setEntity:entity];
    [fetchRequest setPropertiesToFetch:[NSArray arrayWithObjects:@"date", nil]];
    
    // Edit the sort key as appropriate.
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"date" ascending:YES];
    [fetchRequest setSortDescriptors:[NSArray arrayWithObject:sortDescriptor]];
    [fetchRequest setResultType: NSDictionaryResultType];
    [fetchRequest setReturnsObjectsAsFaults:NO];
    
    NSArray *cardRepetitions = [[FlashCardsCore mainMOC] executeFetchRequest:fetchRequest error:nil];
    
    int count;
    NSMutableDictionary *dateCountsObj;
    
    int oneDay = 60 * 60 * 24;
    int x;
    
    NSDate *firstDate, *currentRepDate, *currentDate, *now;
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateStyle:NSDateFormatterShortStyle];
    [dateFormatter setTimeStyle:NSDateFormatterNoStyle];
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    NSDateComponents *dateComponents, *plusOneDay;
    
    plusOneDay = [[NSDateComponents alloc] init];
    if (mode == cardsStudiedByDay) {
        [plusOneDay setDay:1];
    } else if (mode == cardsStudiedByWeek) {
        [plusOneDay setWeek:1];
        oneDay *= 7;
    } else if (mode == cardsStudiedByMonth) {
        [plusOneDay setMonth:1];
        oneDay *= 30;
    }
    now = [NSDate date];
    if (self.collection) {
        firstDate = collection.dateCreated;
    } else {
        firstDate = cardSet.dateCreated;
    }
    dateComponents = [gregorian components:(NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit) fromDate:firstDate];
    [dateComponents setHour:23];
    [dateComponents setMinute:59];
    [dateComponents setSecond:59];
    firstDate = [gregorian dateFromComponents:dateComponents];
    firstDate = [gregorian dateByAddingComponents:plusOneDay toDate:firstDate options:0];
    currentDate = firstDate;
    int cardRepI = 0;
    BOOL addExtraDate = NO;
    // while: currentDate < now 
    while ([currentDate isEarlierThan:now] || addExtraDate) {
        count = 0;
        while (cardRepI < [cardRepetitions count]) {
            currentRepDate = [[cardRepetitions objectAtIndex:cardRepI] valueForKey:@"date"];
            // if currentRepDate > currentDate
            if ([currentRepDate isLaterThan:currentDate]) {
                break;
            }
            count++;
            cardRepI++;
        }

        x = oneDay * (int)[dateCounts count];
        dateCountsObj = [[NSMutableDictionary alloc] initWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:x], [NSNumber numberWithInt:count], currentDate, nil]
                                                             forKeys:[NSArray arrayWithObjects:@"x", @"count", @"date", nil]];
        [dateCounts addObject:dateCountsObj];
        
        currentDate = [gregorian dateByAddingComponents:plusOneDay toDate:currentDate options:0];
        if (!addExtraDate && [currentDate compare:now] != NSOrderedAscending) {
            addExtraDate = YES;
        } else {
            addExtraDate = NO;
        }
    }

    
    int maxCount = 5;
    for (int k = 0; k < [dateCounts count]; k++) {
        count = [[[dateCounts objectAtIndex:k] valueForKey:@"count"] intValue];
        if (count > maxCount) {
            maxCount = count;
        }
    }
    
    int numDays = [dateCounts count]; 
    
    graph = [[CPTXYGraph alloc] initWithFrame: self.view.bounds];
    self.view = [[CPTGraphHostingView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    CPTGraphHostingView *hostingView = (CPTGraphHostingView *)self.view;
    hostingView.hostedGraph = graph;
    graph.paddingLeft = 10.0;
    graph.paddingTop = 20.0;
    graph.paddingRight = 20.0;
    graph.paddingBottom = 20.0;
    
    float leftSpace = numDays / 4.5;
    if (leftSpace < 0.7) {
        leftSpace = 0.7;
    }
    
    CPTXYPlotSpace *plotSpace =  (CPTXYPlotSpace *)graph.defaultPlotSpace;
    plotSpace.xRange = [CPTPlotRange plotRangeWithLocation:fc_CPTDecimalFromFloat(oneDay * leftSpace * -1)
                                                    length:fc_CPTDecimalFromFloat(oneDay * (numDays+leftSpace+1))];
    double minYValue = -1*maxCount/10;
    double yLength = maxCount * 1.2;
    double maxYValue = minYValue + yLength;
    while (-1*(minYValue / maxYValue) < 0.09) {
        minYValue -= 1;
        yLength += 1;
        maxYValue = minYValue + yLength;
    }
    plotSpace.yRange = [CPTPlotRange plotRangeWithLocation:fc_CPTDecimalFromFloat(minYValue)
                                                    length:fc_CPTDecimalFromFloat(yLength)];
    
    CPTMutableLineStyle *lineStyle = [CPTMutableLineStyle lineStyle];
    lineStyle.lineColor = [CPTColor blackColor];
    lineStyle.lineWidth = 2.0f;
    
    int majorIntervalLength = ceil((float)numDays / 5.0);
    if (majorIntervalLength == 0) {
        majorIntervalLength    = 1;
    }
    
    CPTXYAxisSet *axisSet = (CPTXYAxisSet *)graph.axisSet;
    axisSet.xAxis.majorIntervalLength = fc_CPTDecimalFromFloat((float)oneDay*majorIntervalLength);
    axisSet.xAxis.minorTicksPerInterval = majorIntervalLength-1;
    axisSet.xAxis.majorTickLineStyle = lineStyle;
    axisSet.xAxis.minorTickLineStyle = lineStyle;
    axisSet.xAxis.axisLineStyle = lineStyle;
    axisSet.xAxis.minorTickLength = 5.0f;
    axisSet.xAxis.majorTickLength = 7.0f;
    if (!launchedFromChoices || mode == cardsStudiedByDay) {
        axisSet.xAxis.title = NSLocalizedStringFromTable(@"Date", @"Statistics", @"x axis");
    } else if (mode == cardsStudiedByWeek) {
        axisSet.xAxis.title = NSLocalizedStringFromTable(@"Week Ending", @"Statistics", @"x axis");
    } else if (mode == cardsStudiedByMonth) {
        axisSet.xAxis.title = NSLocalizedStringFromTable(@"Month Ending", @"Statistics", @"x axis");
    } else {
        axisSet.xAxis.title = NSLocalizedStringFromTable(@"Date", @"Statistics", @"x axis");
    }
    axisSet.xAxis.titleOffset = 20.0f;
    axisSet.xAxis.visibleRange = [CPTPlotRange plotRangeWithLocation:fc_CPTDecimalFromFloat(0.0f)
                                                              length:fc_CPTDecimalFromFloat(oneDay * (numDays+1+(majorIntervalLength/4)))];
    
    dateFormatter = [[NSDateFormatter alloc] init];
    // as per http://stackoverflow.com/questions/5135482/how-to-determine-if-locales-date-format-is-month-day-or-day-month
    [dateFormatter setDateFormat:[NSDateFormatter dateFormatFromTemplate:@"Md" options:0 locale:[NSLocale currentLocale]]];
    CPTTimeFormatter *timeFormatter = [[CPTTimeFormatter alloc] initWithDateFormatter:dateFormatter];
    timeFormatter.referenceDate = firstDate;
    axisSet.xAxis.labelFormatter = timeFormatter;
    
    
    
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
    
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
    // TODO: Depricated?
    // axisSet.yAxis.orthogonalCoordinateDecimal = fc_CPTDecimalFromFloat(0.0f);
    axisSet.yAxis.title = yAxisTitle;
    axisSet.yAxis.titleOffset = 30.0f;
    axisSet.yAxis.visibleRange = [CPTPlotRange plotRangeWithLocation:fc_CPTDecimalFromFloat(0)
                                                             length:fc_CPTDecimalFromFloat(maxCount * 1.2)];
    
    
    CPTScatterPlot *dateCountsPlot = [[CPTScatterPlot alloc]
                                       initWithFrame:self.graph.defaultPlotSpace.graph.bounds];
    
    dateCountsPlot.identifier = plotIdentifier;
    dateCountsPlot.dataSource = self;
    CPTMutableLineStyle *dateCountLineStyle =  [CPTMutableLineStyle lineStyle];
    dateCountLineStyle.lineWidth = 3.0f;
    dateCountLineStyle.lineColor = (isLapsed ? [CPTColor redColor] : [CPTColor greenColor]);
    dateCountsPlot.dataLineStyle = dateCountLineStyle;
    
    
    CPTPlotSymbol *greenCirclePlotSymbol = [CPTPlotSymbol ellipsePlotSymbol];
    greenCirclePlotSymbol.fill = [CPTFill fillWithColor:[CPTColor greenColor]];
    greenCirclePlotSymbol.size = CGSizeMake(2.0, 2.0);
    dateCountsPlot.plotSymbol = greenCirclePlotSymbol;  
    
    [graph addPlot:dateCountsPlot];

}

- (void) helpEvent {
    HelpViewController *helpVC = [[HelpViewController alloc] initWithNibName:@"HelpViewController" bundle:nil];
    
    helpVC.title = self.title;
    helpVC.helpText = NSLocalizedStringWithDefaultValue(@"CollectionCardsStudiedByDayVCHelp", @"Help", [NSBundle mainBundle], @"<p>Shows a graph of how many cards you actually studied by day, week, or month.</p>", @"");
    // Pass the selected object to the new view controller.
    [self.navigationController pushViewController:helpVC animated:YES];
    
}


- (BOOL)shouldAutorotate {
    UIInterfaceOrientation interfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    return [FlashCardsAppDelegate shouldAutorotate:interfaceOrientation];
}

-(NSUInteger)numberOfRecordsForPlot:(CPTPlot *)plot {
    return [dateCounts count];
}

-(NSNumber *)numberForPlot:(CPTPlot *)plot
                     field:(NSUInteger)fieldEnum
               recordIndex:(NSUInteger)index
{
    NSNumber *ret;
    switch (fieldEnum) {
        default:
        case CPTScatterPlotFieldX:
            ret = [[dateCounts objectAtIndex:index] valueForKey:@"x"]; 
        //    NSDate *date = [NSDate dateWithTimeInterval:[ret intValue] sinceDate:[[dateCounts objectAtIndex:0] valueForKey:@"date"]];
        //    NSLog(@"%@", date);
            return ret;
            break;
            
        case CPTScatterPlotFieldY:
            ret = [[dateCounts objectAtIndex:index] valueForKey:@"count"];
        //    NSLog(@"%d", [ret intValue]);
            return ret;
            break;
    }
    /*
    // NSLog(@"fieldEnum = %d",fieldEnum);
    switch (fieldEnum) {
        default:
        case CPBarPlotFieldBarLocation:
            num = (NSDecimalNumber *)[NSDecimalNumber numberWithDouble:[SMCore calcEFactorFromColumn:index]];
            // NSLog(@"CPBarPlotFieldBarLocation return num = %@",num);
            break;
        case CPBarPlotFieldBarLength:
            num = [NSNumber numberWithDouble:((double)[[eFactorCounts objectAtIndex:index] intValue])];
            // NSLog(@"CPBarPlotFieldBarLength return num = %@",num);
            break;
    }
    return num;
     */
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
