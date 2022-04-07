//
//  FCSyncViewController.m
//  FlashCards
//
//  Created by Jason Lustig on 1/28/13.
//  Copyright (c) 2013 Jason Lustig. All rights reserved.
//

#import "FCSyncViewController.h"
#import "FlashCardsAppDelegate.h"

@interface FCSyncViewController ()

@end

@implementation FCSyncViewController

@synthesize syncHUD;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

# pragma mark - Sync Methods

- (void)createSyncHUD {
    syncHUD = [[MBProgressHUD alloc] initWithView:self.view];
    
    // Add HUD to screen
    [self.view addSubview:syncHUD];
    // Register for HUD callbacks so we can remove it from the window at the right time
    syncHUD.delegate = self;
    syncHUD.minShowTime = 2.0;
    [syncHUD show:YES];
}

- (void)syncEvent {
    [self syncEvent:YES];
}

- (void)syncEvent:(BOOL)userDidInitiate {
    SyncController *controller = [[FlashCardsCore appDelegate] syncController];
    if (controller.isCurrentlySyncing || controller.isCurrentlyDownloading || controller.isCurrentlyUploading) {
        return;
    }
    if (![FlashCardsCore isConnectedToInternet]) {
        if (userDidInitiate) {
            FCDisplayBasicErrorMessage(NSLocalizedStringFromTable(@"No Internet Connection", @"Error", @"UIAlert title"),
                                       [NSString stringWithFormat:@"%@ %@",
                                        NSLocalizedStringFromTable(@"You are not connected to the internet.", @"Error", @""),
                                        NSLocalizedStringFromTable(@"This feature will only work with an active internet connection.", @"Error", @"message")]);
        }
        return;
    }
    if (![FlashCardsCore hasFeature:@"WebsiteSync"]) {
        [FlashCardsCore showPurchasePopup:@"WebsiteSync"];
        return;
    }
    [controller setUserInitiatedSync:userDidInitiate];
    [FlashCardsCore showSyncHUD];
    [FlashCardsCore sync:self];
}

- (void)hudWasHidden:(MBProgressHUD *)hud {
    [hud removeFromSuperview];
    hud = nil;
}

@end
