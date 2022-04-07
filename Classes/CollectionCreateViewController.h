//
//  CollectionCreateViewController.h
//  FlashCards
//
//  Created by Jason Lustig on 5/27/10.
//  Copyright 2010 Jason Lustig. All rights reserved.
//

#import <UIKit/UIKit.h>

@class FCMatrix;
@class SuperMemo;
@class Collection;

@interface CollectionCreateViewController : UIViewController {
    
    Collection *collection;
    
    IBOutlet UITextField *collectionNameField;
    IBOutlet UISwitch *isLanguageField;
    
    UIBarButtonItem *saveButton;
    UIBarButtonItem *cancelButton;
    
    int editMode;
    
    NSManagedObjectContext *managedObjectContext;
}

-(void)saveEvent;
-(void)cancelEvent;

- (IBAction)doneEditing:(id)sender;

@property (nonatomic, retain) Collection *collection;

@property (nonatomic, retain) IBOutlet UITextField *collectionNameField;
@property (nonatomic, retain) IBOutlet UISwitch *isLanguageField;

@property (nonatomic, retain) UIBarButtonItem *saveButton;
@property (nonatomic, retain) UIBarButtonItem *cancelButton;

@property (nonatomic) int editMode;

@property (nonatomic, retain) NSManagedObjectContext *managedObjectContext;

@end
