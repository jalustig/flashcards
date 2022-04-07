//
//  CardSelectImageViewController.h
//  FlashCards
//
//  Created by Jason Lustig on 10/20/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface CardSelectImageViewController : UIViewController <UIAlertViewDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate>

- (void)saveEvent;
- (void)cancelEvent;

- (void)showClearButton:(BOOL)yesNo animated:(BOOL)animated;
- (void)configureImage:(BOOL)showChoosePhoto;
- (void)configureImageLocation;

- (IBAction)removePhoto:(id)sender;
- (IBAction)choosePhoto:(id)sender;
- (IBAction)rotatePhoto:(id)sender;

- (void)showIpadPicker;

- (void)choosePhotoCamera;
- (void)choosePhotoLibrary;


@property (nonatomic, weak) IBOutlet UIImageView *imageView;
@property (nonatomic, weak) IBOutlet UIToolbar *bottomToolbar;
@property (nonatomic, weak) IBOutlet UILabel *noImageLabel;
@property (nonatomic, strong) UIPopoverController *popover;

@property (nonatomic, strong) NSMutableArray *initialButtonList;
@property (nonatomic, strong) NSMutableData *imageData;
@property (nonatomic, strong) NSString *dataKey;
@property (nonatomic, assign) bool isReLoading;

@property (nonatomic, assign) BOOL didChooseCamera;

@property (nonatomic, weak) IBOutlet UIBarButtonItem *removePhotoButton;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *choosePhotoButton;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *rotatePhotoButton;


@end
