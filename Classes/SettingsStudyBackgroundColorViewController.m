//
//  SettingsStudyBackgroundColorViewController.m
//  FlashCards
//
//  Created by Jason Lustig on 10/4/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import "FlashCardsAppDelegate.h"
#import "FlashCardsCore.h"


#import "SettingsStudyBackgroundColorViewController.h"

#import "UIColor-Expanded.h"

@implementation SettingsStudyBackgroundColorViewController

@synthesize backgroundColorOptions;
@synthesize backgroundColor, backgroundTextColor;
@synthesize checkedCell;

#pragma mark -
#pragma mark View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = NSLocalizedStringFromTable(@"Background Color", @"Settings", @"UIView title");
    
    backgroundColor = [UIColor colorWithString:(NSString *)[FlashCardsCore getSetting:@"studySettingsBackgroundColor"]];
    backgroundTextColor = [UIColor colorWithString:(NSString *)[FlashCardsCore getSetting:@"studySettingsBackgroundTextColor"]];
    
    backgroundColorOptions = [[NSMutableArray alloc] initWithCapacity:0];
    
    [backgroundColorOptions addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                       [UIColor whiteColor], @"backgroundColor",
                                       [UIColor blackColor], @"textColor",
                                       NSLocalizedStringFromTable(@"Index Card", @"Settings", @"color"), @"description",
                                       nil]];
    [backgroundColorOptions addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                       [UIColor blackColor], @"backgroundColor",
                                       [UIColor whiteColor], @"textColor",
                                       NSLocalizedStringFromTable(@"Black", @"Settings", @"color"), @"description",
                                       nil]];
    [backgroundColorOptions addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                       [UIColor whiteColor], @"backgroundColor",
                                       [UIColor blackColor], @"textColor",
                                       NSLocalizedStringFromTable(@"White", @"Settings", @"color"), @"description",
                                       nil]];
    [backgroundColorOptions addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                       [UIColor brownColor], @"backgroundColor",
                                       [UIColor blackColor], @"textColor",
                                       NSLocalizedStringFromTable(@"Brown", @"Settings", @"color"), @"description",
                                       nil]];
    [backgroundColorOptions addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                       [UIColor grayColor], @"backgroundColor",
                                       [UIColor blackColor], @"textColor",
                                       NSLocalizedStringFromTable(@"Gray", @"Settings", @"color"), @"description",
                                       nil]];
    [backgroundColorOptions addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                       [UIColor redColor], @"backgroundColor",
                                       [UIColor blackColor], @"textColor",
                                       NSLocalizedStringFromTable(@"Red", @"Settings", @"color"), @"description",
                                       nil]];
    [backgroundColorOptions addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                       [UIColor orangeColor], @"backgroundColor",
                                       [UIColor blackColor], @"textColor",
                                       NSLocalizedStringFromTable(@"Orange", @"Settings", @"color"), @"description",
                                       nil]];

    [backgroundColorOptions addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                       [UIColor yellowColor], @"backgroundColor",
                                       [UIColor blackColor], @"textColor",
                                       NSLocalizedStringFromTable(@"Yellow", @"Settings", @"color"), @"description",
                                       nil]];
    [backgroundColorOptions addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                       [UIColor greenColor], @"backgroundColor",
                                       [UIColor blackColor], @"textColor",
                                       NSLocalizedStringFromTable(@"Green", @"Settings", @"color"), @"description",
                                       nil]];
    [backgroundColorOptions addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                       [UIColor cyanColor], @"backgroundColor",
                                       [UIColor blackColor], @"textColor",
                                       NSLocalizedStringFromTable(@"Cyan", @"Settings", @"color"), @"description",
                                       nil]];
    [backgroundColorOptions addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                       [UIColor blueColor], @"backgroundColor",
                                       [UIColor whiteColor], @"textColor",
                                       NSLocalizedStringFromTable(@"Blue", @"Settings", @"color"), @"description",
                                       nil]];
    [backgroundColorOptions addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                       [UIColor purpleColor], @"backgroundColor",
                                       [UIColor whiteColor], @"textColor",
                                       NSLocalizedStringFromTable(@"Purple", @"Settings", @"color"), @"description",
                                       nil]];
}

- (BOOL)shouldAutorotate {
    UIInterfaceOrientation interfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    return [FlashCardsAppDelegate shouldAutorotate:interfaceOrientation];
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


#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    return [backgroundColorOptions count];
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    NSString *CellIdentifier = [NSString stringWithFormat:@"Cell%d", indexPath.row];
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    
    NSDictionary *dict = [backgroundColorOptions objectAtIndex:indexPath.row];
    cell.textLabel.text = [dict objectForKey:@"description"];
    cell.textLabel.textColor = [dict objectForKey:@"textColor"];
    if (indexPath.row == 0) {
        if ([FlashCardsCore getSettingBool:@"studyDisplayLikeIndexCard"]) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
            self.checkedCell = indexPath;
        } else {
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
    } else if ([(NSString*)[FlashCardsCore getSetting:@"studySettingsBackgroundColor"] isEqual:[(UIColor*)[dict objectForKey:@"backgroundColor"] stringFromColor]] &&
               ![FlashCardsCore getSettingBool:@"studyDisplayLikeIndexCard"]) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
        self.checkedCell = indexPath;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    // Configure the cell...
    
    return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    [cell setBackgroundColor:[[backgroundColorOptions objectAtIndex:indexPath.row] objectForKey:@"backgroundColor"]];
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
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
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
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    if (cell.accessoryType == UITableViewCellAccessoryCheckmark) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        return;
    }
    cell.accessoryType = UITableViewCellAccessoryCheckmark;
    cell = [tableView cellForRowAtIndexPath:self.checkedCell];
    cell.accessoryType = UITableViewCellAccessoryNone;
    self.checkedCell = indexPath;
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.row == 0) {
        [FlashCardsCore setSetting:@"studyDisplayLikeIndexCard" value:@YES];
    } else {
        
        backgroundColor = [[backgroundColorOptions objectAtIndex:indexPath.row] objectForKey:@"backgroundColor"];
        backgroundTextColor = [[backgroundColorOptions objectAtIndex:indexPath.row] objectForKey:@"textColor"];
        
        [FlashCardsCore setSetting:@"studySettingsBackgroundColor" value:[backgroundColor stringFromColor]];
        [FlashCardsCore setSetting:@"studySettingsBackgroundTextColor" value:[backgroundTextColor stringFromColor]];
        [FlashCardsCore setSetting:@"studyDisplayLikeIndexCard" value:@NO];
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

