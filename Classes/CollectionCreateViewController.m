//
//  CollectionCreateViewController.m
//  FlashCards
//
//  Created by Jason Lustig on 5/27/10.
//  Copyright 2010 Jason Lustig. All rights reserved.
//

#import "CollectionCreateViewController.h"
#import "Collection.h"
#import "FCMatrix.h"
#import "SuperMemo.h"
#import "Constants.h"


@implementation CollectionCreateViewController

@synthesize collectionNameField, isLanguageField;
@synthesize saveButton, cancelButton;
@synthesize collection, editMode;
@synthesize managedObjectContext;

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

    if (editMode == modeEdit) {
        self.title = NSLocalizedStringFromTable(@"Edit Collection", @"CardManagement", @"UIView title");
        collectionNameField.text = collection.name;
        isLanguageField.on = [collection.isLanguage boolValue];
    } else {
        self.title = NSLocalizedStringFromTable(@"New Collection", @"CardManagement", @"UIView title");
    }
    
    saveButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector(saveEvent)];
    saveButton.enabled = YES;
    self.navigationItem.rightBarButtonItem = saveButton;
    
    cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelEvent)];
    cancelButton.enabled = YES;
    self.navigationItem.leftBarButtonItem = cancelButton;
    
    [super viewDidLoad];
}

# pragma mark -
# pragma mark Events functions

- (void)cancelEvent {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)saveEvent {
    
    if (editMode == modeCreate) {
        // create and configure a new instance of the Collection entity:
        
        collection = (Collection *)[NSEntityDescription
                                                insertNewObjectForEntityForName:@"Collection" inManagedObjectContext:managedObjectContext];
        
        [collection setName:collectionNameField.text];
        [collection setIsLanguage:[NSNumber numberWithBool:isLanguageField.on]];
        [collection setDateCreated:[NSDate date]];
        
        NSMutableArray *oFactorMatrix, *matrix;
        
        oFactorMatrix = [SuperMemo newOFactorMatrix];
        [collection setofMatrix:oFactorMatrix];
        
        matrix = [SuperMemo newOFactorAdjustedMatrix];
        [collection setofMatrixAdjusted:matrix];
        [matrix release];
        
        matrix = [SuperMemo newIMatrix:oFactorMatrix];
        [collection setiMatrix:matrix];
        [matrix release];
        
        [oFactorMatrix release];
    } else {
        [collection setName:collectionNameField.text];
        [collection setIsLanguage:[NSNumber numberWithBool:isLanguageField.on]];

    }
    NSError *error;
    if (![managedObjectContext save:&error]) {
        // handle the error
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Error", @"Error", @"UIAlert title")
                                                         message:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Unresolved error saving data: %@, %@", @"Error", @"message"), error, [error userInfo] ]
                                                        delegate:self
                                               cancelButtonTitle:NSLocalizedStringFromTable(@"OK", @"FlashCards", @"cancelButtonTitle")
                                               otherButtonTitles:nil] autorelease];
        [alert show];
        return;
    }
    
    [self.navigationController popViewControllerAnimated:YES];

}

- (IBAction)doneEditing:(id)sender {
    [sender resignFirstResponder];
}

# pragma mark -
# pragma mark Memory functions

/*
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
*/

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;

    self.collectionNameField = nil;
    self.isLanguageField = nil;
    self.saveButton = nil;
    self.cancelButton = nil;
}


- (void)dealloc {
    
    [collection release];
    
    [collectionNameField release];
    [isLanguageField release];
    
    [saveButton release];
    [cancelButton release];
    
    [managedObjectContext release];
    
    [super dealloc];
}


@end
