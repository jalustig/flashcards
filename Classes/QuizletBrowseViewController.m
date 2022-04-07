//
//  QuizletBrowseViewController.m
//  FlashCards
//
//  Created by Jason Lustig on 7/27/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import "FlashCardsAppDelegate.h"
#import "QuizletBrowseViewController.h"
#import "QuizletSearchSetsViewController.h"

@implementation QuizletBrowseViewController

@synthesize quizletOptions;

#pragma mark -
#pragma mark View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    if (!quizletOptions) {
        [self loadQuizletCategories];
    }
    self.title = [quizletOptions valueForKey:@"name"];

    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES selector:@selector(caseInsensitiveCompare:)];
    [[quizletOptions valueForKey:@"children"] sortUsingDescriptors:[NSArray arrayWithObject:sortDescriptor]];

    
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

/*
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}
*/
- (void)viewDidAppear:(BOOL)animated {
    NSIndexPath* selection = [self.myTableView indexPathForSelectedRow];
    if (selection) {
        [self.myTableView deselectRowAtIndexPath:selection animated:YES];
    }
}
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
    NSArray *children = [quizletOptions valueForKey:@"children"];
    return [children count];
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
    
    NSDictionary *option = [[quizletOptions valueForKey:@"children"] objectAtIndex:indexPath.row];
    
    cell.textLabel.text = [option valueForKey:@"name"];
    NSString *detailLabel;
    if ([option valueForKey:@"tag"] && !([[option valueForKey:@"name"] isEqual:[option valueForKey:@"tag"]])) {
        detailLabel = [NSString stringWithFormat:NSLocalizedStringFromTable(@"Tag: %@", @"Import", @""), [option valueForKey:@"tag"]];
    } else {
        detailLabel = @"";
    }
    cell.detailTextLabel.text = detailLabel;
    
    [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
    
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

- (void)loadQuizletCategories {
    NSString *path = [[NSBundle mainBundle] pathForResource:@"QuizletCategories" ofType:@"plist"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:path]) {
        NSLog(@"File does not exist.");
        return;
    }
    quizletOptions = [[NSMutableDictionary alloc] initWithContentsOfFile:path];
    NSMutableArray *children = (NSMutableArray*)[quizletOptions objectForKey:@"children"];
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"namece" ascending:YES  selector:@selector(caseInsensitiveCompare:)];
    [children sortUsingDescriptors:[NSArray arrayWithObject:sortDescriptor]];
    [quizletOptions setObject:children forKey:@"children"];
}

#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // Navigation logic may go here. Create and push another view controller.
    NSMutableDictionary *option = [[quizletOptions valueForKey:@"children"] objectAtIndex:indexPath.row];
    if ([[option valueForKey:@"children"] count] > 0) {
        QuizletBrowseViewController *vc = [[QuizletBrowseViewController alloc] initWithNibName:@"QuizletBrowseViewController" bundle:nil];
        
        vc.cardSet = self.cardSet;
        [vc setImportFromWebsite:[self importFromWebsite]];
        vc.quizletOptions = option;
        [vc setPopToViewControllerIndex:[self popToViewControllerIndex]];
        [vc setCardSetCreateMode:[self cardSetCreateMode]];
        [vc setCollection:[self collection]];
        
        // Pass the selected object to the new view controller.
        [self.navigationController pushViewController:vc animated:YES];
        

    } else {
    
        // go to search:
        
        
        QuizletSearchSetsViewController *vc = [[QuizletSearchSetsViewController alloc] initWithNibName:@"QuizletSearchSetsViewController" bundle:nil];
        
        vc.importFromWebsite = self.importFromWebsite;
        vc.searchIsActive = NO;
        NSString *searchTerm = [option valueForKey:@"tag"];
        if (!searchTerm) {
            searchTerm = [option valueForKey:@"name"];
        }
        vc.savedSearchTerm = searchTerm;
        vc.popToViewControllerIndex = [self popToViewControllerIndex];
        vc.cardSetCreateMode = [self cardSetCreateMode];
        vc.collection = [self collection];
        vc.cardSet = self.cardSet;
        
        // Pass the selected object to the new view controller.
        [self.navigationController pushViewController:vc animated:YES];
        
        
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

