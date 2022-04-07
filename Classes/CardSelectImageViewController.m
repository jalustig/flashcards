//
//  CardSelectImageViewController.m
//  FlashCards
//
//  Created by Jason Lustig on 10/20/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import "CardSelectImageViewController.h"
#import "CardEditViewController.h"
#import "FlashCardsAppDelegate.h"

#import "UIImage+Rotate.h"
#import "UIImage+ProportionalFill.h"

@implementation CardSelectImageViewController

@synthesize imageView, bottomToolbar, noImageLabel, popover;
@synthesize imageData, dataKey;
@synthesize isReLoading;
@synthesize didChooseCamera;
@synthesize initialButtonList;
@synthesize removePhotoButton;
@synthesize choosePhotoButton;
@synthesize rotatePhotoButton;

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
    
    self.title = NSLocalizedStringFromTable(@"Choose Photo", @"CardManagement", @"View Title");
    
    [removePhotoButton setAccessibilityHint:NSLocalizedStringFromTable(@"Remove Photo", @"CardManagement", @"UIBarButtonItem")];
    choosePhotoButton.title = NSLocalizedStringFromTable(@"Choose Photo", @"CardManagement", @"UIBarButtonItem");
    
    didChooseCamera = NO;
    isReLoading = NO;
    
    if ([FlashCardsAppDelegate isIpad]) {
        noImageLabel.font = [UIFont systemFontOfSize:30];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receivedRotate:) name:UIDeviceOrientationDidChangeNotification object:NULL];
    } else {
        noImageLabel.font = [UIFont systemFontOfSize:17];
    }
    
    UIBarButtonItem *button;
    button = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector(saveEvent)];
    button.enabled = YES;
    self.navigationItem.rightBarButtonItem = button;
    
    button = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelEvent)];
    button.enabled = YES;
    self.navigationItem.leftBarButtonItem = button;
    
    initialButtonList = [[NSMutableArray alloc] initWithCapacity:self.bottomToolbar.items.count];
    [initialButtonList addObjectsFromArray:self.bottomToolbar.items];
    
    if ([imageData length] > 0) {
        noImageLabel.hidden = YES;
        [self showClearButton:YES animated:NO];
    } else {
        noImageLabel.hidden = NO;
        [self showClearButton:NO animated:NO];
    }
        
}

- (void)viewDidAppear:(BOOL)animated {
    [self configureImage:!isReLoading];
    [super viewDidAppear:animated];
    isReLoading = YES;
}

- (void) configureImage:(BOOL)showChoosePhoto {
    if ([imageData length] > 0) {
        imageView.hidden = NO;
        noImageLabel.hidden = YES;

        [self configureImageLocation];
        [self showClearButton:YES animated:NO];

    } else {
        imageView.hidden = YES;
        noImageLabel.hidden = NO;
        [self showClearButton:NO animated:NO];
        if (showChoosePhoto) {
            [self choosePhoto:nil];
        }
    }
    
}

- (void)configureImageLocation {
    
    UIImage *image = [[UIImage alloc] initWithData:imageData];
    
    // NSLog(@"W: %1.2f / H: %1.2f", image.size.width, image.size.height);
    
    CGFloat maxWidth = self.view.frame.size.width;
    CGFloat maxHeight = self.view.frame.size.height - (480-417);

    int originX = 0;
    int originY = 0;
    int x, y;
    // Set the proper image size depending on the size of the image relative to the scroll view:
    if (image.size.width <= maxWidth && image.size.height <= maxHeight) {
        x = ((maxWidth - image.size.width) / 2);
        y = ((maxHeight - image.size.height) / 2);
        [imageView setFrame:CGRectMake(x + originX,
                                       y + originY,
                                       image.size.width,
                                       image.size.height)];
    } else {
        CGFloat height, width;
        width = image.size.width;
        height = image.size.height;
        if (width >= maxWidth) {
            height *= (maxWidth / width);
            width *= (maxWidth / width);
        }
        if (height >= maxHeight) {
            width *= (maxHeight / height);
            height *= (maxHeight / height);
        }
        x = ((maxWidth - width) / 2);
        y = ((maxHeight - height) / 2);
        [imageView setFrame:CGRectMake(x + originX,
                                       y + originY,
                                       width,
                                       height)];
    }
    
    [imageView setImage:image];
    
}

// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotate {
    UIInterfaceOrientation interfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    // Return YES for supported orientations
    return [FlashCardsAppDelegate shouldAutorotate:interfaceOrientation];
}

#pragma mark -
#pragma mark Rotation functions

-(void) receivedRotate: (NSNotification*) notification {
    UIDeviceOrientation interfaceOrientation = [[UIDevice currentDevice] orientation];
    
    if (!(UIInterfaceOrientationIsPortrait(interfaceOrientation) || UIInterfaceOrientationIsLandscape(interfaceOrientation))) {
        return;
    }
    [self configureImageLocation];
    
}


# pragma mark -
# pragma mark Alert functions

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 0) {
        // if they hit cancel, don't do anything:
        return;
    }
    if (buttonIndex == 1) {
        // camera
        [self choosePhotoCamera];
    } else {
        // library
        [self choosePhotoLibrary];
    }
}


# pragma mark -
# pragma mark Button functions

- (void)showClearButton:(BOOL)yesNo animated:(BOOL)animated {
    NSMutableArray *toolbarItems = [NSMutableArray arrayWithArray:initialButtonList];

    if (!yesNo) {
        [toolbarItems removeObjectAtIndex:3];
        [toolbarItems removeObjectAtIndex:2];
    }

    [self.bottomToolbar setItems:toolbarItems animated:animated];
}


# pragma mark -
# pragma mark Event functions

- (void)saveEvent {
    CardEditViewController *vc = (CardEditViewController*)[[self.navigationController viewControllers] objectAtIndex:([[self.navigationController viewControllers] count]-2)];
    [vc.cardData setObject:imageData forKey:dataKey];
    
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)cancelEvent {
    [self.navigationController popViewControllerAnimated:YES];
}

- (IBAction)rotatePhoto:(id)sender {
    UIImage *image = [UIImage imageWithData:imageData];
    UIImage *rotated = [image imageRotatedByDegrees:90.0f];

    float compression = 0.4;
    imageData = [[NSMutableData alloc] initWithData:UIImageJPEGRepresentation(rotated, compression)];
    
    [self configureImage:NO];
}

- (IBAction)removePhoto:(id)sender {
    [imageData setLength:0];
    imageView.hidden = YES;
    noImageLabel.hidden = NO;
    [self showClearButton:NO animated:YES];
}

- (IBAction)choosePhoto:(id)sender {
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        // camera is not on this device, go straight to library:
        [self choosePhotoLibrary];
    } else {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Choose Photo Source", @"CardManagement", @"UIAlert title")
                                                         message:@""
                                                        delegate:self
                                               cancelButtonTitle:NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"cancelButtonTitle")
                                               otherButtonTitles:NSLocalizedStringFromTable(@"Camera", @"CardManagement", @"otherButtonTitles"), NSLocalizedStringFromTable(@"Photo Library", @"CardManagement", @"otherButtonTitles"), nil];
        [alert show];
    }
}

- (void)choosePhotoCamera {
    didChooseCamera = YES;
    UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
    imagePicker.delegate = self;
    imagePicker.sourceType = UIImagePickerControllerSourceTypeCamera;
    imagePicker.editing = YES;
    if ([FlashCardsAppDelegate isIpad]) {
        popover = [[UIPopoverController alloc] initWithContentViewController:imagePicker];
        [self showIpadPicker];
    } else {
        [self presentViewController:imagePicker animated:YES completion:nil];
    }
}

- (void)choosePhotoLibrary {
    didChooseCamera = NO;
    UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
    imagePicker.delegate = self;
    imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    if ([FlashCardsAppDelegate isIpad]) {
        popover = [[UIPopoverController alloc] initWithContentViewController:imagePicker];
        [self showIpadPicker];
    } else {
        [self presentViewController:imagePicker animated:YES completion:nil];
    }
}

- (void)showIpadPicker {
    CGFloat height = 480; // self.view.frame.size.height-100;
    CGFloat width = 320; // self.view.frame.size.width-100;
    NSMutableArray* buttons = [[NSMutableArray alloc] init];
    for (UIControl* btn in bottomToolbar.subviews) {
        if ([btn isKindOfClass:[UIControl class]]) {
            [buttons addObject:btn];
        }
    }
    // NSLog(@"Count: %d", [buttons count]);
    UIView *chooseItem = [buttons objectAtIndex:0];
    CGRect frame = [chooseItem convertRect:chooseItem.bounds toView:nil];
    // NSLog(@"X: %1.2f Y: %1.2f CX: %1.2f CY: %1.2f", frame.origin.x, frame.origin.y, frame.origin.x+(frame.size.width/2), frame.origin.y+(frame.size.height/2));
    // NSLog(@"Full width: %1.2f", self.view.frame.size.width);
    CGFloat buttonX, buttonWidth;
    
    UIDeviceOrientation interfaceOrientation = [[UIDevice currentDevice] orientation];
    if (UIInterfaceOrientationIsPortrait(interfaceOrientation)) {
        buttonX = frame.origin.x;
        buttonWidth = frame.size.width;
    } else {
        buttonX = frame.origin.y;
        buttonWidth = frame.size.width;
    }
    
    [popover presentPopoverFromRect:CGRectMake(buttonX+(buttonWidth/2)-(width/2),
                                               bottomToolbar.frame.origin.y,
                                               width,
                                               height) 
                             inView:self.view
           permittedArrowDirections:UIPopoverArrowDirectionDown 
                           animated:YES];
}

- (void)imagePickerController:(UIImagePickerController  *)picker didFinishPickingMediaWithInfo:(NSDictionary  *)info {

    UIImage *selectedImage = [info valueForKey:UIImagePickerControllerOriginalImage];

    int maxImageSize = 1000;
    float compression = 0.4;
    
    NSData *originalImageData = [[NSMutableData alloc] initWithData:UIImageJPEGRepresentation(selectedImage, compression)];
    FCLog(@"Previous size: %d", [originalImageData length]);
    int oldSize = (int)[originalImageData length];
    if (selectedImage.size.height > maxImageSize || selectedImage.size.width > maxImageSize) {
        selectedImage = [selectedImage imageToFitSize:CGSizeMake(maxImageSize, maxImageSize) method:MGImageResizeScale];
    }
    NSData *newImageData = UIImageJPEGRepresentation(selectedImage, compression);
    FCLog(@"New size: %d", [newImageData length]);
    int newSize = (int)[newImageData length];
    if (newSize < oldSize) {
        imageData = [NSMutableData dataWithData:newImageData];
    } else {
        imageData = [NSMutableData dataWithData:originalImageData];
    }
    
    [self configureImage:NO];
    
    if ([FlashCardsAppDelegate isIpad]) {
        [popover dismissPopoverAnimated:YES];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}


- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    // The user canceled -- simply dismiss the image picker.
    if ([FlashCardsAppDelegate isIpad]) {
        [popover dismissPopoverAnimated:YES];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}


# pragma mark -
# pragma mark Memory functions

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}




@end
