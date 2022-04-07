//
//  CollectionStatisticsViewController.m
//  FlashCards
//
//  Created by Jason Lustig on 7/9/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import "FlashCardsAppDelegate.h"
#import "CollectionStatisticsViewController.h"
#import "CollectionGeneralStatisticsViewController.h"
#import "CollectionCardsDueByDayViewController.h"
#import "CollectionCardsStudiedByDayViewController.h"
#import "CollectionCardsStudiedTimeFrameChooserViewController.h"
#import "CollectionEFactorChartViewController.h"
#import "CollectionOFMatrixViewController.h"
#import "CollectionScoreChartViewController.h"

#import "FCCollection.h"
#import "FCCardSet.h"

@implementation CollectionStatisticsViewController

@synthesize tableListOptions;
@synthesize collection, cardSet;
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
    
    self.title = NSLocalizedStringFromTable(@"Statistics", @"Statistics", @"UIView title");

    tableListOptions = [[NSMutableArray alloc] initWithCapacity:1];
    [tableListOptions addObject:NSLocalizedStringFromTable(@"General Statistics", @"Statistics", @"")];
    [tableListOptions addObject:NSLocalizedStringFromTable(@"Cards Due By Day", @"Statistics", @"")];
    int timeInterval;
    if (collection) {
        timeInterval = [collection.dateCreated timeIntervalSinceNow] * -1;
    } else {
        timeInterval = [cardSet.dateCreated timeIntervalSinceNow] * -1;
    }
    if (collection.numCases > 0) {
        if (timeInterval > (86400*7)) {
            [tableListOptions addObject:NSLocalizedStringFromTable(@"Cards Studied", @"Statistics", @"")];
            [tableListOptions addObject:NSLocalizedStringFromTable(@"Cards Lapsed", @"Statistics", @"")];
        } else {
            [tableListOptions addObject:NSLocalizedStringFromTable(@"Cards Studied By Day", @"Statistics", @"")];
            [tableListOptions addObject:NSLocalizedStringFromTable(@"Cards Lapsed By Day", @"Statistics", @"")];
        }
    }
    [tableListOptions addObject:NSLocalizedStringFromTable(@"E-Factors (All Cards)", @"Statistics", @"")];
    [tableListOptions addObject:NSLocalizedStringFromTable(@"E-Factors (Memorized Only)", @"Statistics", @"")];
    [tableListOptions addObject:NSLocalizedStringFromTable(@"E-Factors (Lapsed Only)", @"Statistics", @"")];
    if (self.collection) {
        if (collection.numCases > 0) {
            [tableListOptions addObject:NSLocalizedStringFromTable(@"Avg. Scores", @"Statistics", @"")];
        }
        [tableListOptions addObject:NSLocalizedStringFromTable(@"Optimal Factors (OF-Matrix)", @"Statistics", @"")];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

- (BOOL)shouldAutorotate {
    UIInterfaceOrientation interfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    return [FlashCardsAppDelegate shouldAutorotate:interfaceOrientation];
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    cell.textLabel.text = [tableListOptions objectAtIndex:indexPath.row];
}


#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    return [tableListOptions count];
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    
    [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
    
    [self configureCell:cell atIndexPath:indexPath];
    
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

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    NSString *currentText = [tableListOptions objectAtIndex:indexPath.row];
    
    if ([currentText isEqualToString:NSLocalizedStringFromTable(@"General Statistics", @"Statistics", @"")]) {
        CollectionGeneralStatisticsViewController *listVC = [[CollectionGeneralStatisticsViewController alloc] initWithNibName:@"CollectionGeneralStatisticsViewController" bundle:nil];
        listVC.collection = self.collection;
        listVC.cardSet = self.cardSet;
        
        // Pass the selected object to the new view controller.
        [self.navigationController pushViewController:listVC animated:YES];
        
        
    } else if ([currentText isEqualToString:NSLocalizedStringFromTable(@"Cards Due By Day", @"Statistics", @"")]) {
        
        CollectionCardsDueByDayViewController *listVC = [[CollectionCardsDueByDayViewController alloc] initWithNibName:@"CollectionCardsDueByDayViewController" bundle:nil];
        listVC.collection = self.collection;
        listVC.cardSet = self.cardSet;

        // Pass the selected object to the new view controller.
        [self.navigationController pushViewController:listVC animated:YES];
        
    } else if ([currentText isEqualToString:NSLocalizedStringFromTable(@"Cards Studied", @"Statistics", @"")] || [currentText isEqualToString:NSLocalizedStringFromTable(@"Cards Lapsed", @"Statistics", @"")]) {
        CollectionCardsStudiedTimeFrameChooserViewController *listVC = [[CollectionCardsStudiedTimeFrameChooserViewController alloc] initWithNibName:@"CollectionCardsStudiedTimeFrameChooserViewController" bundle:nil];
        listVC.collection = self.collection;
        listVC.cardSet = self.cardSet;
        listVC.isLapsed = [currentText isEqualToString:NSLocalizedStringFromTable(@"Cards Lapsed", @"Statistics", @"")];
        
        // Pass the selected object to the new view controller.
        [self.navigationController pushViewController:listVC animated:YES];
        
    } else if ([currentText isEqualToString:NSLocalizedStringFromTable(@"Cards Studied By Day", @"Statistics", @"")] || [currentText isEqualToString:NSLocalizedStringFromTable(@"Cards Lapsed By Day", @"Statistics", @"")]) {
        CollectionCardsStudiedByDayViewController *listVC = [[CollectionCardsStudiedByDayViewController alloc] initWithNibName:@"CollectionCardsStudiedByDayViewController" bundle:nil];
        listVC.collection = self.collection;
        listVC.cardSet = self.cardSet;
        listVC.mode = cardsStudiedByDay;
        listVC.launchedFromChoices = NO;
        listVC.isLapsed = [currentText isEqualToString:NSLocalizedStringFromTable(@"Cards Lapsed By Day", @"Statistics", @"")];
        
        // Pass the selected object to the new view controller.
        [self.navigationController pushViewController:listVC animated:YES];
        
    } else if ([currentText isEqualToString:NSLocalizedStringFromTable(@"E-Factors (All Cards)", @"Statistics", @"")] || [currentText isEqualToString:NSLocalizedStringFromTable(@"E-Factors (Memorized Only)", @"Statistics", @"")] || [currentText isEqualToString:NSLocalizedStringFromTable(@"E-Factors (Lapsed Only)", @"Statistics", @"")]) {
        CollectionEFactorChartViewController *listVC = [[CollectionEFactorChartViewController alloc] initWithNibName:@"CollectionEFactorChartViewController" bundle:nil];
        listVC.collection = self.collection;
        listVC.cardSet = self.cardSet;
        listVC.memorizedOnly = ([currentText isEqualToString:NSLocalizedStringFromTable(@"E-Factors (Memorized Only)", @"Statistics", @"")]);
        listVC.lapsedOnly = ([currentText isEqualToString:NSLocalizedStringFromTable(@"E-Factors (Lapsed Only)", @"Statistics", @"")]);
        
        // Pass the selected object to the new view controller.
        [self.navigationController pushViewController:listVC animated:YES];
        
        
    } else if ([currentText isEqualToString:NSLocalizedStringFromTable(@"Optimal Factors (OF-Matrix)", @"Statistics", @"")]) {
        CollectionOFMatrixViewController *listVC = [[CollectionOFMatrixViewController alloc] initWithNibName:@"CollectionOFMatrixViewController" bundle:nil];
        listVC.collection = self.collection;
        
        // Pass the selected object to the new view controller.
        [self.navigationController pushViewController:listVC animated:YES];
        
    } else if ([currentText isEqualToString:NSLocalizedStringFromTable(@"Avg. Scores", @"Statistics", @"")]) {
        CollectionScoreChartViewController * listVC = [[CollectionScoreChartViewController alloc] initWithNibName:@"CollectionScoreChartViewController" bundle:nil];
        listVC.collection = self.collection;
        
        // Pass the selected object to the new view controller.
        [self.navigationController pushViewController:listVC animated:YES];
        
    }
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
