//
//  CollectionCardsDueByDayViewController.m
//  FlashCards
//
//  Created by Jason Lustig on 7/9/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import "FlashCardsAppDelegate.h"
#import "CollectionCardsDueByDayViewController.h"

#import "FCCard.h"
#import "FCCardSet.h"
#import "FCCollection.h"

#import "HelpViewController.h"

#import "DTVersion.h"

@implementation CollectionCardsDueByDayViewController

@synthesize days;
@synthesize collection, cardSet;
@synthesize fetchedResultsController;


#pragma mark -
#pragma mark View lifecycle

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
    
    if (![DTVersion osVersionIsLessThen:@"7.0"]) {
        self.edgesForExtendedLayout= UIRectEdgeNone;
    }

    self.title = NSLocalizedStringFromTable(@"Cards Due By Day", @"Statistics", @"UIView Title");
    
    // Help buttons
    UIButton *helpButton = [UIButton buttonWithType:UIButtonTypeInfoLight];
    [helpButton addTarget:self action:@selector(helpEvent) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *rightItem = [[UIBarButtonItem alloc] initWithCustomView:helpButton];
    self.navigationItem.rightBarButtonItem = rightItem;
    
    days = [[NSMutableArray alloc] initWithCapacity:0];
    NSMutableDictionary *day;
    NSDate *today = [NSDate date];
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    NSDateComponents *components = [gregorian components:(NSYearCalendarUnit | NSMonthCalendarUnit |  NSDayCalendarUnit) fromDate:today];

    NSDate *todayMidnight = [gregorian dateFromComponents:components];
    NSDate *date;
    int intervalSince1970 = [[NSDate date] timeIntervalSince1970];
    intervalSince1970 += [todayMidnight timeIntervalSinceNow];
    intervalSince1970 += 60;
    date = [NSDate dateWithTimeIntervalSince1970:intervalSince1970];
    

    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    
    [dateFormatter setDateStyle:NSDateFormatterShortStyle];
    [dateFormatter setTimeStyle:NSDateFormatterNoStyle];
    
    for (int i = 0; i < 7; i++) {
        day = [[NSMutableDictionary alloc] initWithCapacity:0];
        if (i == 0) {
            [day setObject:NSLocalizedStringFromTable(@"Today", @"Statistics", @"") forKey:@"displayString"];
        } else {
            [day setObject:[dateFormatter stringFromDate:date] forKey:@"displayString"];
        }
        intervalSince1970 += 86400;
        date = [NSDate dateWithTimeIntervalSince1970:intervalSince1970];
        [day setObject:(NSDate*)date forKey:@"endDate"];
        [day setObject:[NSNumber numberWithInt:0] forKey:@"numCards"];
        [days insertObject:day atIndex:i];
    }
    
    // add a "Next week" item:
    day = [[NSMutableDictionary alloc] initWithCapacity:0];
    [day setObject:NSLocalizedStringFromTable(@"Next Week", @"Statistics", @"") forKey:@"displayString"];
    intervalSince1970 += 86400 * 7;
    date = [NSDate dateWithTimeIntervalSince1970:intervalSince1970];
    [day setObject:(NSDate*)date forKey:@"endDate"];
    [day setObject:[NSNumber numberWithInt:0] forKey:@"numCards"];
    [days insertObject:day atIndex:[days count]];
    
    // month item:

    NSDateComponents *offsetComponents;
    NSString *monthStr, *restOfStr;

    NSMutableArray *monthsArray = [[NSMutableArray alloc] initWithCapacity:0];
    // as per http://stackoverflow.com/questions/5114055/how-to-programmatically-build-nsarray-of-localized-calendar-month-names/5114902
    for (int i = 0; i < 12; i++) {
        NSString *monthName = [[dateFormatter monthSymbols] objectAtIndex:i];
        [monthsArray addObject:monthName];
    }
        
    NSDateComponents *currentDateComponents = [gregorian components:(NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit) fromDate:[NSDate date]];
    offsetComponents = [[NSDateComponents alloc] init];
    [offsetComponents setMonth:1];
    [offsetComponents setDay:0]; // we used to try to calculate the beginning of the month with this, but the new
                                 // technique is to add a month & then set the day # to "1."
    date = [gregorian dateByAddingComponents:offsetComponents toDate:date options:0];

    components = [gregorian components:(NSYearCalendarUnit | NSMonthCalendarUnit |  NSDayCalendarUnit | NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit) fromDate:date];
    [components setDay:1];
    [components setHour:0];
    [components setMinute:0];
    [components setSecond:0];
    date = [gregorian dateFromComponents:components];
    
    [offsetComponents setMonth:0];
    [offsetComponents setSecond:-1];
    date = [gregorian dateByAddingComponents:offsetComponents toDate:date options:0];

    components = [gregorian components:(NSYearCalendarUnit | NSMonthCalendarUnit |  NSDayCalendarUnit | NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit) fromDate:date];
    if (components.month == currentDateComponents.month) {
        restOfStr = NSLocalizedStringFromTable(@"Rest of", @"Statistics", @"Rest of [September/October/November]");
    } else {
        restOfStr = @"";
    }
    monthStr = [monthsArray objectAtIndex:components.month-1];
    
    day = [[NSMutableDictionary alloc] initWithCapacity:0];
    [day setObject:[NSString stringWithFormat:@"%@%@", restOfStr, monthStr] forKey:@"displayString"];
    [day setObject:(NSDate*)date forKey:@"endDate"];
    [day setObject:[NSNumber numberWithInt:0] forKey:@"numCards"];
    [days insertObject:day atIndex:[days count]];
    
    
    
    // 3 month items:
    
    for (int z = 0; z < 3; z++) {
        offsetComponents = [[NSDateComponents alloc] init];
        [offsetComponents setMonth:1];
        [offsetComponents setDay:0];
        [offsetComponents setHour:0];
        [offsetComponents setMinute:0];
        [offsetComponents setSecond:0];
        date = [gregorian dateByAddingComponents:offsetComponents toDate:date options:0];
        components = [gregorian components:(NSYearCalendarUnit | NSMonthCalendarUnit |  NSDayCalendarUnit) fromDate:date];

        monthStr = [monthsArray objectAtIndex:components.month-1];
        
        day = [[NSMutableDictionary alloc] initWithCapacity:0];
        [day setObject:monthStr forKey:@"displayString"];
        [day setObject:(NSDate*)date forKey:@"endDate"];
        [day setObject:[NSNumber numberWithInt:0] forKey:@"numCards"];
        [days insertObject:day atIndex:[days count]];
    }
    
    
        
    
    // Now, get all of the cards from the database:
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    // Edit the entity name as appropriate.
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Card"
                                              inManagedObjectContext:[FlashCardsCore mainMOC]];
    if (self.collection) {
        [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"isDeletedObject = NO and collection = %@ and isSpacedRepetition = YES and isLapsed = NO", collection, [NSDate date]]];
    } else {
        [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"isDeletedObject = NO and any cardSet = %@ and isSpacedRepetition = YES and isLapsed = NO", cardSet, [NSDate date]]];
    }
    [fetchRequest setEntity:entity];
    [fetchRequest setPropertiesToFetch:[NSArray arrayWithObjects:@"nextRepetitionDate", nil]];
    [fetchRequest setResultType:NSDictionaryResultType];

    // Edit the sort key as appropriate.
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"nextRepetitionDate" ascending:YES];
    NSArray *sortDescriptors = [[NSArray alloc] initWithObjects:sortDescriptor, nil];
    
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    NSError *error;
    NSArray *cards = [[FlashCardsCore mainMOC] executeFetchRequest:fetchRequest error:&error];
    if (cards == nil) {
        // TODO: handle the error
    }
    
    
    // Go through the cards, and count how many are in each day:
    int dayCount = 0;
    int cardCount = 0;
    FCCard *currentCard;
    NSDate *currentEndDate, *nextRepetitionDate;
    int j;
    
    int comparison;
    BOOL hasCards = NO;
    
    for (j = 0; j < [cards count] && dayCount < [days count]; j++) {
        currentEndDate = [[days objectAtIndex:dayCount] valueForKey:@"endDate"];
        currentCard = [cards objectAtIndex:j];
        nextRepetitionDate = [currentCard valueForKey:@"nextRepetitionDate"];

        comparison = [currentEndDate compare:nextRepetitionDate];
        cardCount++;
        if (comparison == NSOrderedDescending) {
            hasCards = YES;
        } else {
            while (comparison == NSOrderedAscending && dayCount < [days count]) {
                if (hasCards == YES) {
                    [[days objectAtIndex:dayCount] setObject:[NSNumber numberWithInt:cardCount] forKey:@"numCards"];
                }
                dayCount++; // go to the next day
                if (dayCount >= [days count]) {
                    break;
                }
                currentEndDate = [[days objectAtIndex:dayCount] valueForKey:@"endDate"];
                cardCount = 0;
                hasCards = NO;
                comparison = [currentEndDate compare:nextRepetitionDate];
            }
        }
        if (dayCount >= [days count]) {
            break;
        }
    }
    if (cardCount > 0 && dayCount < [days count]) {
        [[days objectAtIndex:dayCount] setObject:[NSNumber numberWithInt:cardCount+1] forKey:@"numCards"];
    }
    
    day = [[NSMutableDictionary alloc] initWithCapacity:0];
    [day setObject:NSLocalizedStringFromTable(@"Future", @"Statistics", @"") forKey:@"displayString"];
    [day setObject:[NSNumber numberWithInt:((int)[cards count] - j)] forKey:@"numCards"];
    [days insertObject:day atIndex:[days count]];

    day = [[NSMutableDictionary alloc] initWithCapacity:0];
    [day setObject:NSLocalizedStringFromTable(@"Total", @"Statistics", @"") forKey:@"displayString"];
    [day setObject:[NSNumber numberWithInt:(int)[cards count]] forKey:@"numCards"];
    [days insertObject:day atIndex:[days count]];
    
    
    
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

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
    helpVC.helpText = NSLocalizedStringWithDefaultValue(@"CollectionCardsDueByDayVCHelp", @"Help", [NSBundle mainBundle], @""
                "<p>Based on your self-assessments in tests and repetitions, cards are assigned a date "
                "for the next repetition. This chart displays how many cards are scheduled to be studied "
                "on which days in the future.</p>", @"");
    // Pass the selected object to the new view controller.
    [self.navigationController pushViewController:helpVC animated:YES];
    
}


#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    return [days count];
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier];
    }
    
    NSMutableDictionary *day = [days objectAtIndex:indexPath.row];
    
    cell.textLabel.text = [day objectForKey:@"displayString"];
    cell.detailTextLabel.text = [[day objectForKey:@"numCards"] description];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    return cell;
}


// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return NO;
}


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

/*
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
}
*/


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
}




@end
