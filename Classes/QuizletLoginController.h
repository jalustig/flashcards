//
//  QuizletLoginController.h
//  FlashCards
//
//  Created by Jason Lustig on 9/10/11.
//  Copyright 2011-2014 Jason Lustig Lustig. All rights reserved.
//

@protocol QuizletLoginControllerDelegate;

@interface QuizletLoginController : UIViewController

@property (nonatomic, weak) IBOutlet UILabel *descriptionLabel;
@property (nonatomic, weak) IBOutlet UIButton *loginButton;
@property (nonatomic, weak) IBOutlet UIButton *cancelButton;

@property (nonatomic, strong) UIViewController<QuizletLoginControllerDelegate> *delegate;

- (void)presentFromController:(UIViewController*)controller;

- (IBAction)didPressLogin:(id)sender;
- (IBAction)accessAsGuest:(id)sender;
- (IBAction)didPressCancel:(id)sender;
@end


// This controller tells the delegate whether the user sucessfully logged in or not
// The login controller will dismiss itself
@protocol QuizletLoginControllerDelegate

@property (nonatomic, retain) FCCollection *collection;
@property (nonatomic, retain) FCCardSet *cardSet;

@optional
- (void)loginControllerDidLogin:(QuizletLoginController*)controller;
- (void)loginControllerDidCancel:(QuizletLoginController*)controller;

@end
