//
//  CardStatisticsViewController.m
//  FlashCards
//
//  Created by Jason Lustig on 6/24/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import "FlashCardsAppDelegate.h"
#import "CardStatisticsViewController.h"
#import "FCCard.h"
#import "FCCardSet.h"
#import "FCCardRepetition.h"

@implementation CardStatisticsViewController

@synthesize card, cardRepetitions, statistics, dateFormatter;

#pragma mark -
#pragma mark View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];


    self.title = NSLocalizedStringFromTable(@"Card Statistics", @"Statistics", @"UIView title");
    
    statistics = [[NSMutableArray alloc] initWithCapacity:0];
    
    // Build & sort the card repetitions array:
    cardRepetitions = [[NSMutableArray alloc] initWithArray:[card.repetitions allObjects]];
    NSSortDescriptor *dateSD = [[NSSortDescriptor alloc] initWithKey:@"date" ascending:YES];
    [cardRepetitions sortUsingDescriptors:[NSArray arrayWithObject:dateSD]];
    
    dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateStyle:NSDateFormatterShortStyle];
    [dateFormatter setTimeStyle:NSDateFormatterNoStyle];

    //    Date created
    [self addStatistic:NSLocalizedStringFromTable(@"Date Created", @"Statistics", @"statistics") value:[dateFormatter stringFromDate:card.dateCreated]];
    
    // Last Modified
    [dateFormatter setTimeStyle:NSDateFormatterShortStyle];
    [self addStatistic:NSLocalizedStringFromTable(@"Last Modified", @"Statistics", @"statistics") value:[dateFormatter stringFromDate:card.dateModified]];

    //    E-factor
    [self addStatistic:NSLocalizedStringFromTable(@"E-Factor", @"FlashCards", @"statistics") value:[NSString stringWithFormat:@"%1.2f", [card.eFactor floatValue]]];

    //    Type – not memorized, memorized, pending
    NSString *cardType;
    if ([card.isLapsed boolValue] == YES) {
        cardType = NSLocalizedStringFromTable(@"Lapsed", @"Statistics", @"statistics");
    } else if ([card.isSpacedRepetition boolValue] == YES) {
        cardType = NSLocalizedStringFromTable(@"Memorized", @"Statistics", @"statistics");
    } else {
        cardType = NSLocalizedStringFromTable(@"Not Memorized", @"Statistics", @"statistics");
    }
    [self addStatistic:NSLocalizedStringFromTable(@"Type", @"FlashCards", @"statistics") value:cardType];
    
    if ([card.isSpacedRepetition boolValue] && ![card.isLapsed boolValue]) {
        // # Repetitions
        [self addStatistic:NSLocalizedStringFromTable(@"# Repetitions", @"Statistics", @"statistics") value:[NSNumber numberWithInt:([card.currentIntervalCount intValue]-1)]];
    }
    
    //    # lapses
    [self addStatistic:NSLocalizedStringFromTable(@"# Lapses", @"Statistics", @"statistics") value:card.numLapses];

    if ([card.isSpacedRepetition boolValue] && ![card.isLapsed boolValue]) {
        if (card.currentIntervalCount > 0) {
        
            //    Last repetition
            [dateFormatter setTimeStyle:NSDateFormatterShortStyle];

            [self addStatistic:NSLocalizedStringFromTable(@"Last Repetition", @"Statistics", @"statistics") value:[dateFormatter stringFromDate:card.lastRepetitionDate]];

            [self addStatistic:NSLocalizedStringFromTable(@"Next Repetition", @"Statistics", @"statistics") value:[dateFormatter stringFromDate:card.nextRepetitionDate]];

        }
    }
    

}

-(void)addStatistic:(NSString *)displayString value:(NSObject *)value {
    NSMutableDictionary *stat = [[NSMutableDictionary alloc] initWithCapacity:0];
    [stat setObject:displayString forKey:@"displayString"];
    [stat setObject:value forKey:@"value"];
    [statistics insertObject:stat atIndex:[statistics count]];
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


#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    if ([card.repetitions count] > 0) {
        return 3;
    } else if ([card cardSetsCount] > 0) {
        return 2;
    } else {
        return 1;
    }
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    if (section == 0) {
        return [statistics count];
    } else if (section == 1 && [card.repetitions count] > 0) {
        return [card.repetitions count]+1;
    } else {
        return [card cardSetsCount];
    }
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier];
    }
    
    // Configure the cell...
    if (indexPath.section == 0) {
        // it's the first section: basic card data
        NSMutableDictionary *stat = [statistics objectAtIndex:indexPath.row];
        
        cell.textLabel.text = [stat objectForKey:@"displayString"];
        cell.detailTextLabel.text = [[stat objectForKey:@"value"] description];
    } else if (indexPath.section == 1 && [card.repetitions count] > 0) {
        // it's the second section: card repetitions
        if (indexPath.row < [cardRepetitions count]) {
            FCCardRepetition *repetition = [cardRepetitions objectAtIndex:indexPath.row];
            cell.textLabel.text = [dateFormatter stringFromDate:repetition.date];
            if ([repetition.score intValue] == 5) {
                cell.detailTextLabel.text = NSLocalizedStringFromTable(@"Easy!", @"Study", @"score");
            } else if ([repetition.score intValue] == 4) {
                cell.detailTextLabel.text = NSLocalizedStringFromTable(@"OK", @"Study", @"score");
            } else if ([repetition.score intValue] == 3) {
                cell.detailTextLabel.text = NSLocalizedStringFromTable(@"Barely", @"Study", @"score");
            } else if ([repetition.score intValue] == 2) {
                cell.detailTextLabel.text = NSLocalizedStringFromTable(@"Almost", @"Study", @"score");
            } else if ([repetition.score intValue] == 1) {
                cell.detailTextLabel.text = NSLocalizedStringFromTable(@"Fail", @"Study", @"score");
            } else {
                cell.detailTextLabel.text = NSLocalizedStringFromTable(@"No Score", @"Study", @"score");
            }
        } else {
            // Display the next repetition:
            cell.textLabel.text = [dateFormatter stringFromDate:card.nextRepetitionDate];
            cell.detailTextLabel.text = NSLocalizedStringFromTable(@"Future", @"Statistics", @"statistics");
        }
    } else {
        // It's the third section: which card sets it is a part of
        cell.textLabel.text = ((FCCardSet*)[[[card allCardSets] allObjects] objectAtIndex:indexPath.row]).name;
        cell.detailTextLabel.text = @"";
    }
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    return cell;
}




- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 40;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {

    UIView* customView = [[UIView alloc] initWithFrame:CGRectMake(10.0, 0.0, 300.0, 44.0)];
    
    // create the button object
    UILabel * headerLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    headerLabel.backgroundColor = [UIColor clearColor];
    headerLabel.opaque = NO;
    headerLabel.textColor = [UIColor blackColor];
    headerLabel.highlightedTextColor = [UIColor whiteColor];
    headerLabel.font = [UIFont boldSystemFontOfSize:20];
    if ([FlashCardsAppDelegate isIpad]) {
        headerLabel.frame = CGRectMake(60.0, 0.0, 300.0, 44.0);
    } else {
        headerLabel.frame = CGRectMake(10.0, 0.0, 300.0, 44.0);
    }
    
    NSString *headerLabelText;
    if (section == 0) {
        headerLabelText = NSLocalizedStringFromTable(@"General Statistics", @"Statistics", @"statistics");
    } else if (section == 1 && [card.repetitions count] > 0) {
        headerLabelText = NSLocalizedStringFromTable(@"Repetitions", @"Statistics", @"statistics");
    } else {
        headerLabelText = NSLocalizedStringFromTable(@"Card Sets", @"CardManagement", @"statistics");
    }
    headerLabel.text = headerLabelText;
    [customView addSubview:headerLabel];
    
    return customView;
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
}




@end

