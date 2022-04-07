//
//  CollectionCardsStudiedTimeFrameChooserViewController.m
//  FlashCards
//
//  Created by Jason Lustig on 7/18/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import "FlashCardsAppDelegate.h"
#import "CollectionCardsStudiedTimeFrameChooserViewController.h"
#import "CollectionCardsStudiedByDayViewController.h"

#import "FCCollection.h"
#import "FCCardSet.h"

@implementation CollectionCardsStudiedTimeFrameChooserViewController


@synthesize isLapsed;
@synthesize collection, cardSet;
@synthesize tableListOptions;


#pragma mark -
#pragma mark View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    
    if (isLapsed) {
        self.title = NSLocalizedStringFromTable(@"Cards Lapsed", @"Statistics", @"UIView title");
    } else {
        self.title = NSLocalizedStringFromTable(@"Cards Studied", @"Statistics", @"UIView title");
    }
    
    tableListOptions = [[NSMutableArray alloc] initWithCapacity:0];

    int timeInterval;
    if (collection) {
        timeInterval = [collection.dateCreated timeIntervalSinceNow] * -1;
    } else {
        timeInterval = [cardSet.dateCreated timeIntervalSinceNow] * -1;
    }
    
    if (isLapsed) {
        [tableListOptions addObject:NSLocalizedStringFromTable(@"Cards Lapsed By Day", @"Statistics", @"")];
    } else {
        [tableListOptions addObject:NSLocalizedStringFromTable(@"Cards Studied By Day", @"Statistics", @"")];
    }
    if (timeInterval > (86400*7)) {
        if (isLapsed) {
            [tableListOptions addObject:NSLocalizedStringFromTable(@"Cards Lapsed By Week", @"Statistics", @"")];
        } else {
            [tableListOptions addObject:NSLocalizedStringFromTable(@"Cards Studied By Week", @"Statistics", @"")];
        }
        if (timeInterval > (86400*31)) {
            if (isLapsed) {
                [tableListOptions addObject:NSLocalizedStringFromTable(@"Cards Lapsed By Month", @"Statistics", @"")];
            } else {
                [tableListOptions addObject:NSLocalizedStringFromTable(@"Cards Studied By Month", @"Statistics", @"")];
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

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    cell.textLabel.text = [tableListOptions objectAtIndex:indexPath.row];
    [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    
    [self configureCell:cell atIndexPath:indexPath];
    
    // Configure the cell...
    
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
    
    CollectionCardsStudiedByDayViewController *listVC = [[CollectionCardsStudiedByDayViewController alloc] initWithNibName:@"CollectionCardsStudiedByDayViewController" bundle:nil];
    listVC.collection = self.collection;
    listVC.cardSet = self.cardSet;
    listVC.mode = indexPath.row;
    listVC.launchedFromChoices = YES;
    listVC.isLapsed = self.isLapsed;
    
    // Pass the selected object to the new view controller.
    [self.navigationController pushViewController:listVC animated:YES];
    

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

