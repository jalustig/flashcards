//
//  FeedbackViewController.m
//  FlashCards
//
//  Created by Jason Lustig on 8/22/11.
//  Copyright 2011-2014 Jason Lustig Lustig. All rights reserved.
//

#import "FeedbackViewController.h"
#import "FlashCardsCore.h"
#import "FlashCardsAppDelegate.h"

#import "ILikeThisAppViewController.h"
#import "ThereIsAProblemViewController.h"

@implementation FeedbackViewController

@synthesize doYouLikeThisAppLabel;
@synthesize theTableView;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
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
    // Do any additional setup after loading the view from its nib.
    
    self.title = NSLocalizedStringFromTable(@"Send Feedback", @"Feedback", @"");
    doYouLikeThisAppLabel.text = NSLocalizedStringFromTable(@"Do You Like This App?", @"Feedback", @"");
    
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotate {
    UIInterfaceOrientation interfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    // Return YES for supported orientations
    return [FlashCardsAppDelegate shouldAutorotate:interfaceOrientation];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier];
    }
    
    if (indexPath.section == 0) {
        // I Like This App
        cell.textLabel.text = NSLocalizedStringFromTable(@"I Like This App", @"Feedback", @"");
        [cell.imageView setImage:[UIImage imageNamed:@"29-heart.png"]];
    } else {
        // There's a problem...
        cell.textLabel.text = NSLocalizedStringFromTable(@"There's a problem...", @"Feedback", @"");
        [cell.imageView setImage:[UIImage imageNamed:@"10-medical.png"]];
    }
    
    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    [self tableView:tableView didSelectRowAtIndexPath:indexPath];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == 0) {
        // I like this app
        ILikeThisAppViewController *vc = [[ILikeThisAppViewController alloc] initWithNibName:@"ILikeThisAppViewController" bundle:nil];
        [self.navigationController pushViewController:vc animated:YES];

    } else {
        // there's a problem...
        ThereIsAProblemViewController *vc = [[ThereIsAProblemViewController alloc] initWithNibName:@"ThereIsAProblemViewController" bundle:nil];
        [self.navigationController pushViewController:vc animated:YES];
    }
}



@end
