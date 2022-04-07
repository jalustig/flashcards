//
//  SelectCollectionViewController.m
//  FlashCards
//
//  Created by Jason Lustig on 9/23/11.
//  Copyright (c) 2011 Jason Lustig. All rights reserved.
//

#import "SelectCollectionViewController.h"
#import "FlashCardsAppDelegate.h"
#import "FlashCardsCore.h"

#import "FCCollection.h"

#import "CollectionCreateViewController.h"
#import "CardSetImportViewController.h"

@implementation SelectCollectionViewController

@synthesize explanationLabel;
@synthesize topicsOptions, collectionOptions;
@synthesize importSet;
@synthesize HUD, collection;


- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}


#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    if (self.collection) {
//        [self.navigationController popViewControllerAnimated:NO];
//        return;
    }

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;

    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:[NSEntityDescription entityForName:@"Collection"
                                        inManagedObjectContext:[FlashCardsCore mainMOC]]];
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES  selector:@selector(caseInsensitiveCompare:)];
    NSArray *sortDescriptors = [[NSArray alloc] initWithObjects:sortDescriptor, nil];
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    collectionOptions = [[NSMutableArray alloc] initWithArray:[[FlashCardsCore mainMOC] executeFetchRequest:fetchRequest error:nil]];
    
    self.title = NSLocalizedStringFromTable(@"Select Collection", @"Import", @"");
    
    [self.tableView reloadData];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if (self.collection) {
//        [self.navigationController popViewControllerAnimated:NO];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotate {
    UIInterfaceOrientation interfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if ([collectionOptions count] > 0) {
        return 3;
    }
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if ([collectionOptions count] == 0) {
        section++;
    }
    if (section == 0) {
        return [collectionOptions count];
    } else if (section == 1) {
        return 1;
    } else {
        return [topicsOptions count];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    
    // Configure the cell...
    [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
    
    int section = indexPath.section;
    if ([collectionOptions count] == 0) {
        section++;
    }
    
    if (section == 0) {
        FCCollection *theCollection = [collectionOptions objectAtIndex:indexPath.row];
        cell.textLabel.text = theCollection.name;
        [cell.imageView setImage:[UIImage imageNamed:@"Collection.png"]];
    } else if (section == 1) {
        cell.textLabel.text = NSLocalizedStringFromTable(@"Other Topic", @"Import", @"");
        [cell.imageView setImage:[UIImage imageNamed:@"green-plus-button.png"]];
    } else {
        NSString *topic = [topicsOptions objectAtIndex:indexPath.row];
        topic = [topic stringByReplacingCharactersInRange:NSMakeRange(0,1) withString:[[topic substringToIndex:1] uppercaseString]];
        cell.textLabel.text = topic;
        [cell.imageView setImage:[UIImage imageNamed:@"green-plus-button.png"]];
    }    
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (section != 2) {
        return 40;
    }
    return 0;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    
    if ([collectionOptions count] == 0) {
        section++;
    }
    
    if (section == 2) {
        return nil;
    }
    
    UIView* customView = [[UIView alloc] initWithFrame:CGRectMake(10.0, 0.0, 300.0, 44.0)];
    
    // create the button object
    UILabel * headerLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    headerLabel.backgroundColor = [UIColor clearColor];
    headerLabel.opaque = NO;
    headerLabel.textColor = [UIColor blackColor];
    headerLabel.highlightedTextColor = [UIColor whiteColor];
    headerLabel.font = [UIFont boldSystemFontOfSize:19];
    if ([FlashCardsAppDelegate isIpad]) {
        headerLabel.frame = CGRectMake(60.0, 0.0, 300.0, 44.0);
    } else {
        headerLabel.frame = CGRectMake(10.0, 0.0, 300.0, 44.0);
    }
    
    if (section == 0) {
        headerLabel.text = NSLocalizedStringFromTable(@"Current Collections", @"Import", @"");
    } else {
        headerLabel.text = NSLocalizedStringFromTable(@"New Collection", @"CardManagement", @"");
    }
    [customView addSubview:headerLabel];
    
    return customView;
}


/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
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
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    int section = (int)indexPath.section;
    if ([collectionOptions count] == 0) {
        section++;
    }
    if (section == 0) {
        // they selected a current collection
        FCCollection *theCollection = [collectionOptions objectAtIndex:indexPath.row];
        CardSetImportViewController *vc = [self.navigationController.viewControllers objectAtIndex:([self.navigationController.viewControllers count]-2)];
        [vc setCollection:theCollection];
        vc.shouldImmediatelyPressImportButton = YES;
        [self.navigationController popViewControllerAnimated:YES];
    } else {
        // they selected to create a new collection
        NSString *topic = @"";
        if (section == 1) {
            topic = @"";
        } else {
            // they selected an option
            topic = [[[tableView cellForRowAtIndexPath:indexPath] textLabel] text];
        }
        CollectionCreateViewController *vc = [[CollectionCreateViewController alloc] initWithNibName:@"CollectionCreateViewController" bundle:nil];
        vc.editMode = modeCreate;
        vc.isImportWorkflow = YES;
        vc.defaultCollectionName = topic;
        if (self.importSet) {
            vc.importSet = self.importSet;
        }
        [self.navigationController pushViewController:vc animated:YES];
    }
}

@end
