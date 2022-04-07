//
//  CollectionGeneralStatisticsViewController.m
//  FlashCards
//
//  Created by Jason Lustig on 6/20/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import "FlashCardsAppDelegate.h"
#import "CollectionGeneralStatisticsViewController.h"
#import "HelpViewController.h"

#import "FCCardRepetition.h"
#import "FCCardSet.h"
#import "FCCard.h"
#import "FCCollection.h"

#import "MBProgressHUD.h"


@implementation CollectionGeneralStatisticsViewController


@synthesize collection, cardSet, statistics;
@synthesize myTableView;
@synthesize resetAllStatisticsButton;
@synthesize HUD;

#pragma mark -
#pragma mark View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];


    self.title = NSLocalizedStringFromTable(@"Statistics", @"Statistics", @"UIView title");
    
    resetAllStatisticsButton.title = NSLocalizedStringFromTable(@"Reset All Statistics", @"Statistics", @"UIBarButtonItem");
    
    // Help buttons
    UIButton *helpButton = [UIButton buttonWithType:UIButtonTypeInfoLight];
    [helpButton addTarget:self action:@selector(helpEvent) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *rightItem = [[UIBarButtonItem alloc] initWithCustomView:helpButton];
    self.navigationItem.rightBarButtonItem = rightItem;

    HUD = [[MBProgressHUD alloc] initWithView:self.view];
    
    HUD.center = self.myTableView.center;
    
    // Add HUD to screen
    [self.view addSubview:HUD];
    
    // Regisete for HUD callbacks so we can remove it from the window at the right time
    HUD.delegate = self;
    HUD.minShowTime = 1.0;
    HUD.labelText = NSLocalizedStringFromTable(@"Calculating Statistics...", @"Statistics", @"HUD");
    [HUD showWhileExecuting:@selector(loadStatistics) onTarget:self withObject:nil animated:YES];

    [self.myTableView reloadData];
    
}

-(void)viewWillDisappear:(BOOL)animated {
    // This is a HUGE hack. We set HUD.isFinished = YES when exiting the view,
    // so that the HUD knows that it should not be calling the [self done] function.
    // However, when going UP the view tree (i.e. to the help screen), we also need
    // to make sure that the HUD is not deleted from memory; so we don't release HUD in 
    // the hudWasHidden method, but in the UITableVC's dealloc method.
    HUD.delegate = nil;
}

-(void)loadStatistics {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateStyle:NSDateFormatterShortStyle];
    [dateFormatter setTimeStyle:NSDateFormatterNoStyle];
    
    
    // as per: http://www.iphonesdkarticles.com/2008/11/localizing-iphone-apps-part-1.html
    NSNumberFormatter *percentStyle = [[NSNumberFormatter alloc] init];
    [percentStyle setFormatterBehavior:NSNumberFormatterBehavior10_4];
    [percentStyle setLocale:[NSLocale currentLocale]];
    [percentStyle setNumberStyle:NSNumberFormatterPercentStyle];
    [percentStyle setMinimumFractionDigits:2];
    [percentStyle setMaximumFractionDigits:2];
    
    NSNumberFormatter *decimalStyle = [[NSNumberFormatter alloc] init];
    [decimalStyle setFormatterBehavior:NSNumberFormatterBehavior10_4];
    [decimalStyle setNumberStyle:NSNumberFormatterDecimalStyle];
    [decimalStyle setMinimumFractionDigits:2];
    [decimalStyle setMaximumFractionDigits:2];
    
    statistics = [[NSMutableArray alloc] initWithCapacity:0];
    
    // generate all of the statistics - keys: displayString, value
    
    NSError *error;
    NSFetchRequest *fetchRequest, *cardsFetchRequest;
    NSEntityDescription *entity;
    
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    NSDateComponents *components = [gregorian components:(NSYearCalendarUnit | NSMonthCalendarUnit |  NSDayCalendarUnit) fromDate:(self.collection ? collection.dateCreated : cardSet.dateCreated)];
    NSDate *firstDay = [gregorian dateFromComponents:components]; // this date is at midnight
    
    
    double numDaysDbl = ((double)[[NSDate date] timeIntervalSinceDate:firstDay]) / 86400;
    int numDays = ceil(numDaysDbl);
    
    // Create the fetch request for the entity.
    cardsFetchRequest = [[NSFetchRequest alloc] init];
    // Edit the entity name as appropriate.
    entity = [NSEntityDescription entityForName:@"Card"
                         inManagedObjectContext:[FlashCardsCore mainMOC]];
    [cardsFetchRequest setEntity:entity];
    
    NSMutableArray *predicates = [[NSMutableArray alloc] initWithCapacity:0];
    if (self.collection) {
        [predicates addObject:[NSPredicate predicateWithFormat:@"collection = %@", collection]];
    } else {
        [predicates addObject:[NSPredicate predicateWithFormat:@"any cardSet = %@", cardSet]];
    }
    [predicates addObject:[NSPredicate predicateWithFormat:@"isDeletedObject = NO"]];
    [cardsFetchRequest setPredicate:[NSCompoundPredicate andPredicateWithSubpredicates:predicates]];
    
    int countTotal = [[FlashCardsCore mainMOC] countForFetchRequest:cardsFetchRequest error:&error]; // [cards count];
    // TODO: Handle the Error
    
    [predicates addObject:[NSPredicate predicateWithFormat:@"isSpacedRepetition = YES"]];
    [cardsFetchRequest setPredicate:[NSCompoundPredicate andPredicateWithSubpredicates:predicates]];
    int countMemorized = [[FlashCardsCore mainMOC] countForFetchRequest:cardsFetchRequest error:&error];
    // TODO: Handle the error
    
    // Date created
    
    [self addStatistic:NSLocalizedStringFromTable(@"First Day", @"Statistics", @"") 
                 value:[dateFormatter stringFromDate:firstDay]];
    
    // # Days
    [self addStatistic:NSLocalizedStringFromTable(@"# Days", @"Statistics", @"")
                 value:[NSNumber numberWithInt:numDays]];
    
    // # Memorized/day
    double memorizedPerDay = (double)countMemorized / numDays;
    [self addStatistic:NSLocalizedStringFromTable(@"# Memorized / Day", @"Statistics", @"")
                 value:[decimalStyle stringFromNumber:[NSNumber numberWithDouble:memorizedPerDay]]];
    
    // # Cards - Total
    [self addStatistic:NSLocalizedStringFromTable(@"# Cards", @"FlashCards", @"") 
                 value:[NSNumber numberWithInt:countTotal]];
    
    // # Cards - Memorized
    [self addStatistic:NSLocalizedStringFromTable(@"# Cards Memorized", @"Statistics", @"") 
                 value:[NSNumber numberWithInt:countMemorized]];
    
    // # Pending
    [predicates removeLastObject];
    [predicates addObject:[NSPredicate predicateWithFormat:@"isSpacedRepetition = NO and isLapsed = NO"]];
    [cardsFetchRequest setPredicate:[NSCompoundPredicate andPredicateWithSubpredicates:predicates]];
    // TODO: Handle the error
    int countPending = [[FlashCardsCore mainMOC] countForFetchRequest:cardsFetchRequest error:&error];
    [self addStatistic:NSLocalizedStringFromTable(@"# Cards Pending", @"Statistics", @"") 
                 value:[NSNumber numberWithInt:countPending]];
    
    // # Lapsed
    [predicates removeLastObject];
    [predicates addObject:[NSPredicate predicateWithFormat:@"isLapsed = YES"]];
    [cardsFetchRequest setPredicate:[NSCompoundPredicate andPredicateWithSubpredicates:predicates]];
    // TODO: Handle the error
    int countLapsed = [[FlashCardsCore mainMOC] countForFetchRequest:cardsFetchRequest error:&error];
    [self addStatistic:NSLocalizedStringFromTable(@"# Cards Lapsed", @"Statistics", @"") 
                 value:[NSNumber numberWithInt:countLapsed]];
    [predicates removeLastObject];
    
    // Get an array with all of the card information:
    [cardsFetchRequest setPredicate:[predicates objectAtIndex:0]];
    [cardsFetchRequest setPropertiesToFetch:[NSArray arrayWithObjects:@"isSpacedRepetition", @"lastRepetitionDate", @"nextRepetitionDate", nil]];
    [cardsFetchRequest setResultType:NSDictionaryResultType];
    NSMutableArray *cards = (NSMutableArray *)[[FlashCardsCore mainMOC] executeFetchRequest:cardsFetchRequest error:&error];
    
    // TODO: Handle the error
    // [cardsFetchRequest release];
    
    NSExpression *numLapsesEx = [NSExpression expressionForKeyPath:@"numLapses"];
    NSExpression *sumNumLapsesEx = [NSExpression expressionForFunction:@"sum:" arguments:[NSArray arrayWithObject:numLapsesEx]];
    
    NSExpressionDescription *sumNumLapsesED = [[NSExpressionDescription alloc] init];
    [sumNumLapsesED setExpression:sumNumLapsesEx];
    [sumNumLapsesED setExpressionResultType:NSInteger16AttributeType];
    [sumNumLapsesED setName:@"countNumLapses"];
    
    [cardsFetchRequest setPropertiesToFetch:[NSArray arrayWithObjects:sumNumLapsesED, nil]];
    [cardsFetchRequest setResultType:NSDictionaryResultType];
    NSArray *temp = [[FlashCardsCore mainMOC] executeFetchRequest:cardsFetchRequest error:&error];
    NSMutableDictionary *cardsResults = [[NSMutableDictionary alloc] initWithCapacity:0];
    if ([temp count] > 0) {
        [cardsResults addEntriesFromDictionary:[temp objectAtIndex:0]];
    } else {
        [cardsResults addEntriesFromDictionary:@{@"countNumLapses" : [NSNumber numberWithInt:0]}];
    }
    // TODO: Handle error
    
    
    [predicates addObject:[NSPredicate predicateWithFormat:@"isSpacedRepetition = YES"]];
    [cardsFetchRequest setPredicate:[NSCompoundPredicate andPredicateWithSubpredicates:predicates]];
    
    NSExpression *currentIntervalCountEx = [NSExpression expressionForKeyPath:@"currentIntervalCount"];
    NSExpression *avgIntervalCountEx = [NSExpression expressionForFunction:@"sum:" arguments:[NSArray arrayWithObject:currentIntervalCountEx]];
    
    NSExpressionDescription *avgIntervalCountED = [[NSExpressionDescription alloc] init];
    [avgIntervalCountED setExpression:avgIntervalCountEx];
    [avgIntervalCountED setExpressionResultType:NSInteger16AttributeType];
    [avgIntervalCountED setName:@"avgIntervalCount"];
    [cardsFetchRequest setPropertiesToFetch:[NSArray arrayWithObject:avgIntervalCountED]];
    temp = [[FlashCardsCore mainMOC] executeFetchRequest:cardsFetchRequest error:&error];
    if ([temp count] > 0) {
        [cardsResults addEntriesFromDictionary:[temp objectAtIndex:0]];
    } else {
        [cardsResults addEntriesFromDictionary:@{@"avgIntervalCount" : [NSNumber numberWithInt:0]}];
    }
    
    
    
    // Get Repetitions Data:
    
    // Create the fetch request for the entity.
    fetchRequest = [[NSFetchRequest alloc] init];
    // Edit the entity name as appropriate.
    entity = [NSEntityDescription entityForName:@"CardRepetition"
                         inManagedObjectContext:[FlashCardsCore mainMOC]];
    [fetchRequest setEntity:entity];
    predicates = [[NSMutableArray alloc] initWithCapacity:0];
    if (self.collection) {
        [predicates addObject:[NSPredicate predicateWithFormat:@"card.collection = %@", collection]];
    } else {
        [predicates addObject:[NSPredicate predicateWithFormat:@"any card.cardSet = %@", cardSet]];
    }
    [predicates addObject:[NSPredicate predicateWithFormat:@"card.isDeletedObject = NO"]];
    [fetchRequest setPredicate:[NSCompoundPredicate andPredicateWithSubpredicates:predicates]];
    int countRepetitions = [[FlashCardsCore mainMOC] countForFetchRequest:fetchRequest error:&error];
    // TODO: Handle error
    
    if (countRepetitions > 0) {
        
        [predicates addObject:[NSPredicate predicateWithFormat:@"score > %d", 2]];
        [fetchRequest setPredicate:[NSCompoundPredicate andPredicateWithSubpredicates:predicates]];
        int numRepetitionsPassed = [[FlashCardsCore mainMOC] countForFetchRequest:fetchRequest error:&error];
        // TODO: Handle the error
        
        
        [fetchRequest setPredicate:[predicates objectAtIndex:0]];
        
        NSExpression *repetitionTime = [NSExpression expressionForKeyPath:@"repetitionTime"];
        NSExpression *totalRepetitionTimeEx = [NSExpression expressionForFunction:@"sum:" arguments:[NSArray arrayWithObject:repetitionTime]];
        
        NSExpressionDescription *totalRepetitionTimeED = [[NSExpressionDescription alloc] init];
        [totalRepetitionTimeED setExpression:totalRepetitionTimeEx];
        [totalRepetitionTimeED setExpressionResultType:NSInteger16AttributeType];
        [totalRepetitionTimeED setName:@"totalRepetitionTime"];
        
        [fetchRequest setPropertiesToFetch:[NSArray arrayWithObjects:totalRepetitionTimeED, nil]];
        [fetchRequest setResultType:NSDictionaryResultType];
        temp = [[FlashCardsCore mainMOC] executeFetchRequest:fetchRequest error:&error];
        // TODO: Handle the error
        NSDictionary *repetitionsResults = [temp objectAtIndex:0];
        
        [fetchRequest setResultType:NSDictionaryResultType];
        [fetchRequest setPropertiesToFetch:[NSArray arrayWithObjects:@"date", @"dateScheduled", nil]];
        NSMutableArray *repetitions = (NSMutableArray *)[[FlashCardsCore mainMOC] executeFetchRequest:fetchRequest error:&error];
        if (repetitions == nil) {
            // TODO: handle the error
        }
        
        
        if (self.collection) {
            // # Cases
            [self addStatistic:NSLocalizedStringFromTable(@"# Cases", @"Statistics", @"")
                         value:collection.numCases];
            
        }
        
        FCCardRepetition *repetition;
        
        // retention rate:
        // due to NSNumberFormatter, no need to multiple percentage by 100.
        double retentionRate = (((double)numRepetitionsPassed) / [repetitions count]);
        [self addStatistic:NSLocalizedStringFromTable(@"Retention Rate", @"Statistics", @"") 
                     value:[percentStyle stringFromNumber:[NSNumber numberWithDouble:retentionRate]]];
        
        // Total repetition time:
        
        int totalRepetitionTime = [[repetitionsResults objectForKey:@"totalRepetitionTime"] intValue];
        double averageRepetitionTime = 0.0;
        if (totalRepetitionTime > 0) {
            // average repetition time:
            
            averageRepetitionTime = (double)totalRepetitionTime / countRepetitions;
            [self addStatistic:NSLocalizedStringFromTable(@"Avg. Repetition Time", @"Statistics", @"")
                         value:[NSString stringWithFormat:FCPluralLocalizedStringFromTable(@"%1.1f Secs", @"Plural", @"", [NSNumber numberWithFloat:averageRepetitionTime]), averageRepetitionTime]];
            
            [self addStatistic:NSLocalizedStringFromTable(@"Total Repetition Time", @"Statistics", @"") 
                         value:[self formatInterval:(double)totalRepetitionTime]];
            
        }
        
        // Burden: estimation of the average number of items and topics repeated per day.
        // This value is equal to the  sum of all interval reciprocals (i.e. 1/interval).
        // The interpretation of this number is as follows: every item with interval of
        // 100 days is on average repeated 1/100 times per day. Thus the sum of interval
        // reciprocals is a good indicator of the total repetition workload in the
        // collection.
        double burden = 0.0;
        double interval;
        double totalInterval = 0.0;
        FCCard *card;
        for (int i = 0; i < [cards count]; i++) {
            card = (FCCard*)[cards objectAtIndex:i];
            interval = (double)[[card valueForKey:@"nextRepetitionDate"] timeIntervalSinceDate:[card valueForKey:@"lastRepetitionDate"]];
            totalInterval += interval;
            interval = interval / 86400.0;
            if ([[card valueForKey:@"isSpacedRepetition"] boolValue] && interval > 0) {
                burden += 1 / interval;
            }
        }
        [self addStatistic:NSLocalizedStringFromTable(@"Burden", @"Statistics", @"") 
                     value:[decimalStyle stringFromNumber:[NSNumber numberWithDouble:burden]]];
        
        // workload: estimation of the average daily time used for responding to
        // questions in a given collection.
        // Workload = (Item Burden)*Avg time
        
        double workload = burden * averageRepetitionTime;
        [self addStatistic:NSLocalizedStringFromTable(@"Workload", @"Statistics", @"") 
                     value:[self formatInterval:(double)workload]];
        
        // Speed: The average knowledge acquisition rate, i.e. the number
        // of items memorized per year per minute of daily work. Initially this value
        // may be as high as 100,000 items/year/minute (esp. if you enthusiastically
        // start working with the program before truly measuring its limitations; or to
        // be precise: the limitations of human memory); however, it should later
        // stabilize between 40 and 400 items/year/minute.
        // Speed=(Memorized items/Day)/Workload*365
        
        double speed = memorizedPerDay / workload * 365;
        [self addStatistic:NSLocalizedStringFromTable(@"Speed", @"Statistics", @"")
                     value:[NSString stringWithFormat:@"%1.2f it/yr/min", speed]]; // TODO: i18n !!!
        
        // average interval: average interval among memorized items in the collection.
        // Here an average memorized item has reached the inter-repetition interval of 4
        // years, 2 months and 15 days
        
        if (totalInterval > 0 && countMemorized > 0) {
            double avgInterval = totalInterval / countMemorized;
            [self addStatistic:NSLocalizedStringFromTable(@"Avg. Interval", @"Statistics", @"") 
                         value:[self formatInterval:(double)avgInterval]];
        }
        
        // average repetition count: average number of repetitions per memorized item in
        // the collection. Here an average item has been repeated 3.212 times    
        
        if (countMemorized > 0) {
            double avgIntervalCount = [[cardsResults valueForKey:@"avgIntervalCount"] doubleValue] / countMemorized;
            [self addStatistic:NSLocalizedStringFromTable(@"Avg. Repetitions", @"Statistics", @"") 
                         value:[decimalStyle stringFromNumber:[NSNumber numberWithDouble:avgIntervalCount]]];
        }
        
        double averageDelay = 0.0;
        for (int i = 0; i < [repetitions count]; i++) {
            repetition = (FCCardRepetition *)[repetitions objectAtIndex:i];
            averageDelay += (double)[[repetition valueForKey:@"date"] timeIntervalSinceDate:[repetition valueForKey:@"dateScheduled"]];
        }
        averageDelay /= [repetitions count];
        [self addStatistic:NSLocalizedStringFromTable(@"Avg. Repetition Delay", @"Statistics", @"") 
                     value:[self formatInterval:(double)averageDelay]];
        
        
        double avgLapsesCount = [[cardsResults objectForKey:@"countNumLapses"] doubleValue];
        if (avgLapsesCount > 0 && countTotal > 0) {
            avgLapsesCount /= countTotal;
            [self addStatistic:NSLocalizedStringFromTable(@"Avg. Lapses / Card", @"Statistics", @"") 
                         value:[decimalStyle stringFromNumber:[NSNumber numberWithDouble:avgLapsesCount]]];
        }
        
    }
    
    
    [self.myTableView reloadData];

}

-(void)addStatistic:(NSString *)displayString value:(NSObject *)value {
    NSMutableDictionary *stat = [[NSMutableDictionary alloc] initWithCapacity:0];
    [stat setObject:displayString forKey:@"displayString"];
    [stat setObject:value forKey:@"value"];
    [statistics insertObject:stat atIndex:[statistics count]];
}

-(NSString*)formatInterval:(double)avgNextInterval {
    int avgNextIntervalHours, avgNextIntervalTotalDays, avgNextIntervalDays, avgNextIntervalMonths;
    avgNextInterval /= 60; // turn it into minutes
    if (avgNextInterval < 60) {
        return [NSString stringWithFormat:FCPluralLocalizedStringFromTable(@"%d minutes", @"Plural", @"", [NSNumber numberWithDouble:avgNextInterval]), [[NSNumber numberWithDouble:avgNextInterval] intValue]];
    } else {
        avgNextInterval /= 60; // turn it into hours
        if (avgNextInterval < 24) {
            return [NSString stringWithFormat:FCPluralLocalizedStringFromTable(@"%1.2f hours", @"Plural", @"", [NSNumber numberWithDouble:avgNextInterval]), avgNextInterval]; 
        } else {
            avgNextInterval = floor(avgNextInterval); // turn it into a flat # of hours
            avgNextIntervalHours = (int)avgNextInterval % 24;
            avgNextIntervalTotalDays = (avgNextInterval - avgNextIntervalHours) / 24;
            avgNextIntervalMonths = (avgNextIntervalTotalDays - (avgNextIntervalTotalDays % 30)) / 30;
            avgNextIntervalDays = avgNextIntervalTotalDays % 30;
            NSString *avgDays =        [NSString stringWithFormat:FCPluralLocalizedStringFromTable(@"%d days", @"Plural", @"", [NSNumber numberWithInt:avgNextIntervalDays]), avgNextIntervalDays];
            NSString *avgMonths =    [NSString stringWithFormat:FCPluralLocalizedStringFromTable(@"%d months", @"Plural", @"", [NSNumber numberWithInt:avgNextIntervalMonths]), avgNextIntervalMonths];
            NSString *avgHours =    [NSString stringWithFormat:FCPluralLocalizedStringFromTable(@"%d hours", @"Plural", @"", [NSNumber numberWithInt:avgNextIntervalHours]), avgNextIntervalHours];
            if (avgNextIntervalMonths > 0) {
                return [NSString stringWithFormat:@"%@, %@", avgMonths, avgDays];
            } else if (avgNextIntervalHours == 0) {
                return avgDays;
            } else {
                return [NSString stringWithFormat:@"%@, %@", avgDays, avgHours];
            }
        }
    }
}


/*
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}
*/

/*
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}
*/
/*
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}
*/
/*
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}
*/

- (BOOL)shouldAutorotate {
    UIInterfaceOrientation interfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    return [FlashCardsAppDelegate shouldAutorotate:interfaceOrientation];
}

- (void) helpEvent {
    HelpViewController *helpVC = [[HelpViewController alloc] initWithNibName:@"HelpViewController" bundle:nil];
    
    helpVC.title = self.title;
    helpVC.helpText = NSLocalizedStringWithDefaultValue(@"CollectionGeneralStatisticsVCHelp", @"Help", [NSBundle mainBundle], @""
            "<p>These general statistics try to sum up some information about your flash card collection and study habits. "
            "Specific statistics include:</p>"
            "<ul>"
            "    <li>First Day - Date when you created the collection\n"
            "    <li># Days - How many days you have been studying\n"
            "    <li># Cards - How many cards are in your collection\n"
            "    <li># Cards Memorized - How many of the cards have been memorized and entered into Spaced Repetition\n"
            "    <li># Memorized / Day - How many cards you have memorized per day you have been studying\n"
            "    <li># Cards Pending - How many cards remain to enter into the Spaced Repetition regiment\n"
            "    <li>Retention Rate - Estimated knowledge retention based on how you score on repetitions\n"
            "    <li>Avg. Repetition Time - Average time spent on each card repetition\n"
            "    <li>Total Repetition Time - Combined total time spent on all card repetitions\n"
            "    <li>Burden - Estimation of how many cards you study per day\n"
            "    <li>Workload - Estimation of how much time you spend studying repetitions per day\n"
            "    <li>Speed - Average knowledge acquisition rate, measured in number of memorized items per year per daily "
            "    minute of work; may be very high at the beginning but will probably settle in the range of 50-500 "
            "    items/year/minute\n"
            "    <li>Avg. Interval - Average current interval for memorized items in the Collection\n"
            "    <li>Avg. Repetitions - Average number of repetitions for memorized item in the Collection\n"
            "</ul>", @"");
    // Pass the selected object to the new view controller.
    [self.navigationController pushViewController:helpVC animated:YES];
    
}

- (void)doneEvent {
    [self.navigationController popViewControllerAnimated:YES];
}

- (IBAction)alertResetStatistics:(id)sender {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Are You Sure?", @"FlashCards", @"UIAlert title")
                                                     message:[NSString stringWithFormat:(self.collection ? 
                                                                                            NSLocalizedStringFromTable(@"Are you sure you want to reset the statistics for this Collection? Doing this will remove your entire study history and cannot be undone.", @"Statistics", @"message") :
                                                                                            NSLocalizedStringFromTable(@"Are you sure you want to reset the statistics for this Card Set? Doing this will remove your entire study history and cannot be undone.", @"Statistics", @"message") 
                                                                                        ), nil]
                                                    delegate:self
                                           cancelButtonTitle:NSLocalizedStringFromTable(@"Don't Reset", @"Statistics", @"cancelButtonTitle")
                                           otherButtonTitles:NSLocalizedStringFromTable(@"Yes, Reset", @"Statistics", @"otherButtonTitles"), nil];
    [alert show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 1) {

        // if working on a collection, reset the OF Matrix and tell the user that it has been done:
        if (self.collection) {
            [self.collection resetStatistics];
        } else {
            [self.cardSet resetStatistics];
        }

        [FlashCardsCore saveMainMOC];
        
        [self loadStatistics];
        [self.myTableView reloadData];
        
        FCDisplayBasicErrorMessage(@"",
                                   NSLocalizedStringFromTable(@"The statistics have been reset to their default settings.", @"Statistics", @"message"));
        
    }
}

#pragma mark -
#pragma mark MBProgressHUDDelegate methods

- (void)hudWasHidden:(MBProgressHUD *)hud {
    // Remove HUD from screen when the HUD was hidded
    [hud removeFromSuperview];
    hud.delegate = nil;
    hud = nil;
}


#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    return [statistics count];
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier];
    }
    
    // Configure the cell...
    
    NSMutableDictionary *stat = [statistics objectAtIndex:indexPath.row];
    
    cell.textLabel.text = [stat objectForKey:@"displayString"];
    cell.detailTextLabel.text = [[stat objectForKey:@"value"] description];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    return cell;
}


/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/


/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:YES];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/


/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/


/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/


#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // Navigation logic may go here. Create and push another view controller.
    /*
     <#DetailViewController#> *detailViewController = [[<#DetailViewController#> alloc] initWithNibName:@"<#Nib name#>" bundle:nil];
     // ...
     // Pass the selected object to the new view controller.
     [self.navigationController pushViewController:detailViewController animated:YES];
     [detailViewController release];
     */
}


#pragma mark -
#pragma mark Memory management

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Relinquish ownership any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
    // Relinquish ownership of anything that can be recreated in viewDidLoad or on demand.
    // For example: self.myOutlet = nil;
    
    statistics = nil;
    
}




@end

