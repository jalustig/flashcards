#import "QuizletLoginController.h"

#import "FlashCardsAppDelegate.h"
#import "FlashCardsCore.h"

#import "DTVersion.h"

#define kTextFieldFrame CGRectMake(100, 11, 190, 24)


@implementation QuizletLoginController

@synthesize descriptionLabel, loginButton, cancelButton;
@synthesize delegate;

- (BOOL)shouldAutorotate {
    UIInterfaceOrientation interfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        return interfaceOrientation == UIInterfaceOrientationPortrait;
    } else {
        return YES;
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if (![DTVersion osVersionIsLessThen:@"7.0"]) {
        self.edgesForExtendedLayout= UIRectEdgeNone;
    }
    
    UIBarButtonItem* cancelItem =
    [[UIBarButtonItem alloc] 
      initWithBarButtonSystemItem:UIBarButtonSystemItemCancel 
      target:self action:@selector(didPressCancel:)];
    
    self.title = NSLocalizedStringFromTable(@"Log in to Quizlet", @"Import", @"UIView title");
    
    self.navigationItem.leftBarButtonItem = cancelItem;
    
    descriptionLabel.text = NSLocalizedStringFromTable(@"Log in to import card sets, upload and share cards on Quizlet, and access your groups. You can now access both public and private groups and sets.", @"Import", @"");
    
    [loginButton setTitle:NSLocalizedStringFromTable(@"Log In", @"FlashCards", @"UIButton") forState:UIControlStateNormal]; 
    [loginButton setTitle:NSLocalizedStringFromTable(@"Log In", @"FlashCards", @"UIButton") forState:UIControlStateSelected];


    [cancelButton setTitle:NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"UIButton") forState:UIControlStateNormal]; 
    [cancelButton setTitle:NSLocalizedStringFromTable(@"Cancel", @"FlashCards", @"UIButton") forState:UIControlStateSelected];

    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc]
          initWithTitle:NSLocalizedStringFromTable(@"Log in", @"FlashCards", @"") style:UIBarButtonItemStyleDone
          target:self action:@selector(didPressLogin:)];
        self.navigationItem.backBarButtonItem = 
        [[UIBarButtonItem alloc] 
          initWithTitle:NSLocalizedStringFromTable(@"Log in", @"FlashCards", @"") style:UIBarButtonItemStylePlain target:nil action:nil];
    }
}


- (void)releaseViews {
}

- (void)viewDidUnload {
    [super viewDidUnload];
    [self releaseViews];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

- (void)dealloc {
    [self releaseViews];
}


- (void)presentFromController:(UIViewController*)controller {
    UINavigationController* navController = 
    [[UINavigationController alloc] initWithRootViewController:self];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        navController.modalPresentationStyle = UIModalPresentationFormSheet;
    }
    [controller presentViewController:navController animated:YES completion:nil];
}


- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad && 
        UIInterfaceOrientationIsPortrait(self.interfaceOrientation)) {
        
    }
}



- (IBAction)didPressLogin:(id)sender {
    // hide the modal view controller...

    [self.navigationController.parentViewController dismissViewControllerAnimated:YES completion:nil];

    // presumably they are not logged in to quizlet, so we will make sure to save that:
    [FlashCardsCore setSetting:@"quizletIsLoggedIn" value:[NSNumber numberWithBool:NO]];
    
    // should save the current state, but not at this point:
    NSString *urlString = [NSString stringWithFormat:@"https://quizlet.com/authorize/?response_type=code&client_id=%@&scope=read%%20write_set%%20write_group&state=%@",
                           quizletApiKey,
                           [FlashCardsCore randomStringOfLength:10]];
    NSURL *url = [NSURL URLWithString:urlString];
    [[UIApplication sharedApplication] openURL:url];
}

- (IBAction)accessAsGuest:(id)sender {
    // continue to the next stage, without logging in
}


- (IBAction)didPressCancel:(id)sender {
    if (delegate && [delegate respondsToSelector:@selector(loginControllerDidCancel:)]) {
        [delegate performSelector:@selector(loginControllerDidCancel:) withObject:self];
    }
    [delegate dismissViewControllerAnimated:YES completion:nil];
}

@end
