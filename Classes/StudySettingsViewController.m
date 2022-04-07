//
//  StudySettingsViewController.m
//  FlashCards
//
//  Created by Jason Lustig on 8/22/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import "FlashCardsAppDelegate.h"
#import "FlashCardsCore.h"

#import "StudySettingsViewController.h"
#import "StudyViewController.h"
#import "SettingsStudyViewController.h"

#import "FCCollection.h"
#import "FCCardSet.h"
#import "StudyController.h"

#import "UIView+Layout.h"
#import "SCRSegmentedControl.h"
#import "UIAlertView+Blocks.h"
#import "NSString+Languages.h"

#import "SubscriptionViewController.h"

#import "UIAlertView+Blocks.h"
#import "ActionSheetStringPicker.h"

#import <iAd/iAd.h>

#import "SizableImageCell.h"

#import "DTVersion.h"

@implementation StudySettingsViewController

@synthesize collection, cardSet;
@synthesize cardListCount, allCardsListCount, studyingImportedSet;
@synthesize studyOrder;
@synthesize selectCards;
@synthesize showFirstSide;
@synthesize studyAlgorithm;
@synthesize loadingCardsFromSavedState;
@synthesize numCardsToLoad;
@synthesize loadNewCardsOnly;
@synthesize studyBrowseMode;

@synthesize beginStudyingButton;
@synthesize beginStudyingToolbar;

@synthesize myTableView;

@synthesize onlyNewCardsCell, onlyNewCardsLabel, onlyNewCardsSwitch;

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {

    [super viewDidLoad];

    // Find out how many cards we may end up studying:
    cardListCount = 0;
    allCardsListCount = 0;
    
    loadNewCardsOnly = YES;
    if (studyAlgorithm == studyAlgorithmLapsed) {
        numCardsToLoad = 15;
    } else {
        numCardsToLoad = 30;
    }
    selectCards = selectCardsRandom;
    studyOrder = studyOrderSmart;
    studyBrowseMode = studyBrowseModeManual;
    loadNewCardsOnly = YES;
    
    // load setting for first side from the Collection at hand.
    showFirstSide = (cardSet? [cardSet.collection.defaultFirstSide intValue] : [collection.defaultFirstSide intValue]);
    
    if (showFirstSide > 3) {
        showFirstSide = showFirstSideFront;
    }
    
    // load settings from NSDefaults
    selectCards= [FlashCardsCore getSettingInt:@"studySettingSelectCards"];
    studyOrder = [FlashCardsCore getSettingInt:@"studySettingOrder"];
    if (studyOrder == studyOrderCustom) {
        if (self.cardSet) {
            if (![[self.cardSet hasCardOrder] boolValue]) {
                studyOrder = studyOrderSmart;
            }
        } else {
            studyOrder = studyOrderSmart;
        }
    }
    studyBrowseMode = [(NSNumber*)[FlashCardsCore getSetting:@"studySettingBrowseMode"] intValue];

    [beginStudyingButton setTitle:NSLocalizedStringFromTable(@"Begin Studying", @"Study", @"UIBarButtonItem")];
    
    // build the list of cards:
    // Create the fetch request for the entity.
    NSError *error;
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    // Edit the entity name as appropriate.
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Card"
                                              inManagedObjectContext:[FlashCardsCore mainMOC]];
    [fetchRequest setEntity:entity];
    
    NSMutableArray *predicates = [[NSMutableArray alloc] initWithCapacity:0];
    if (cardSet) {
        [predicates addObject:[NSPredicate predicateWithFormat:@"isDeletedObject = NO and collection = %@ and any cardSet = %@", collection, cardSet]];
    } else {
        [predicates addObject:[NSPredicate predicateWithFormat:@"isDeletedObject = NO and collection = %@", collection]];
    }
    
    if (studyAlgorithm == studyAlgorithmTest || studyAlgorithm == studyAlgorithmLearn) {
        // find out how many cards there are to test
        
        if (studyAlgorithm == studyAlgorithmLearn) {
            // find out how many cards we could look at - TOTAL: 
            [fetchRequest setPredicate:[predicates objectAtIndex:0]];
            allCardsListCount = (int)[[FlashCardsCore mainMOC] countForFetchRequest:fetchRequest error:&error];
            // TODO: Handle the error
        }
        
        [predicates addObject:[NSPredicate predicateWithFormat:@"isSpacedRepetition = NO"]];
        
        
    } else if (studyAlgorithm == studyAlgorithmRepetition) {
        // find out how many repetition cards there are:
        
        [predicates addObject:[NSPredicate predicateWithFormat:@"isSpacedRepetition = YES and nextRepetitionDate <= %@", [NSDate date]]];
        
    } else if (studyAlgorithm == studyAlgorithmLapsed) {
        // find out how many lapsed cards there are:
        
        [predicates addObject:[NSPredicate predicateWithFormat:@"isLapsed = YES"]];
        
    }
    
    [fetchRequest setPredicate:[NSCompoundPredicate andPredicateWithSubpredicates:predicates]];
    
    cardListCount = (int)[[FlashCardsCore mainMOC] countForFetchRequest:fetchRequest error:&error];
    // TODO: Handle the error
    
    
    
    if (cardListCount > 0 || (studyAlgorithm == studyAlgorithmLearn && allCardsListCount > 0)) {
        if (studyAlgorithm == studyAlgorithmTest || studyAlgorithm == studyAlgorithmRepetition) {
            [self beginStudying:nil];
        } else {
            // show the settings screen:
            loadNewCardsOnly = [FlashCardsCore getSettingBool:@"studyOnlyNewCards"];
            if (studyAlgorithm == studyAlgorithmLearn && allCardsListCount > 0 && cardListCount == 0) {
                loadNewCardsOnly = NO;
                [onlyNewCardsSwitch setOn:loadNewCardsOnly]; // make sure that the "All Cards" option is checked off.
            }
            
            [self displaySettings];
            
            if (![collection.studyStateDone boolValue] && [collection.studyStateCardList count] > 0 && !studyingImportedSet) {
                
                NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                
                [dateFormatter setDateStyle:NSDateFormatterShortStyle];
                [dateFormatter setTimeStyle:NSDateFormatterShortStyle];
                
                
                RIButtonItem *beginNewSession = [RIButtonItem item];
                beginNewSession.label = NSLocalizedStringFromTable(@"Begin New Session", @"Study", @"cancelButtonTitle");
                beginNewSession.action = ^{
                };
                
                RIButtonItem *loadCardsTest = [RIButtonItem item];
                loadCardsTest.label = NSLocalizedStringFromTable(@"Load Saved Cards (Test)", @"Study", @"otherButtonTitles");
                loadCardsTest.action = ^{
                    loadingCardsFromSavedState = YES;
                    
                    studyOrder = [collection.studyStateStudyOrder intValue];
                    showFirstSide = [collection.studyStateShowFirstSide intValue];

                    // begin with test - so, set the algorithm to test since test is never saved
                    // as the study algorithm in the state.
                    studyAlgorithm = studyAlgorithmTest;
                    
                    [self beginStudying:nil];
                };

                RIButtonItem *loadCardsNoTest = [RIButtonItem item];
                loadCardsNoTest.label = NSLocalizedStringFromTable(@"Load Saved Cards (Study)", @"Study", @"otherButtonTitles");
                loadCardsNoTest.action = ^{
                    loadingCardsFromSavedState = YES;
                    
                    studyOrder = [collection.studyStateStudyOrder intValue];
                    showFirstSide = [collection.studyStateShowFirstSide intValue];

                    studyAlgorithm = [collection.studyStateStudyAlgorithm intValue];
                    
                    // begin with study
                    [self beginStudying:nil];
                };


                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Saved Study Session Found", @"Study", @"UIAlert title")
                                                                 message:[NSString stringWithFormat:FCPluralLocalizedStringFromTable(@"It seems you have a study session (%d cards) from %@ which you never finished. Would you like to reload those cards now?", @"Plural", @"message", [NSNumber numberWithInt:(int)[collection.studyStateCardList count]]),  [collection.studyStateCardList count], [dateFormatter stringFromDate:collection.studyStateDate]]
                                                       cancelButtonItem:beginNewSession
                                                       otherButtonItems:loadCardsTest, loadCardsNoTest, nil];
                [alert show];
            }
            
        }
    } else {
        NSMutableString *labelText = [[NSMutableString alloc] initWithCapacity:0];
        if (studyAlgorithm == studyAlgorithmTest) {
            [labelText appendString:NSLocalizedStringFromTable(@"All cards in this set have already been memorized and entered into Spaced Repetition, so there are no cards in this set which need to be tested at this time.", @"Study", @"")];
        } else if (studyAlgorithm == studyAlgorithmRepetition) {
            [labelText appendString:NSLocalizedStringFromTable(@"There are no cards which need to be studied with Spaced Repetition at this time.", @"Study", @"")];
        } else if (studyAlgorithm == studyAlgorithmLapsed) {
            [labelText appendString:NSLocalizedStringFromTable(@"There are no lapsed cards which need to be studied at this time.", @"Study", @"")];
        } else {
            [labelText appendString:NSLocalizedStringFromTable(@"There are no cards in this card set, add some cards to begin studying.", @"Study", @"")];
        }
        
        RIButtonItem *cancelItem = [RIButtonItem item];
        cancelItem.label = NSLocalizedStringFromTable(@"OK", @"FlashCards", @"cancelButtonTitle");
        cancelItem.action = ^{
            [self.navigationController popViewControllerAnimated:YES];
        };

        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@""
                                                         message:labelText
                                                        cancelButtonItem:cancelItem
                                               otherButtonItems:nil];
        [alert show];
    }
    
    
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [self displaySettings];
    
    if (![FlashCardsCore hasFeature:@"HideAds"]) {
        if (![DTVersion osVersionIsLessThen:@"7.0"]) {
            FCLog(@"preparing interstitial ads");
            [UIViewController prepareInterstitialAds];
        }
        ADBannerView *bannerAd = [[FlashCardsCore appDelegate] bannerAd];
        BOOL alreadyDisplayed = [[self.view subviews] containsObject:bannerAd];
        if (bannerAd.bannerLoaded) {
            if (!alreadyDisplayed) {
                // float toolbarY = beginStudyingToolbar.frame.origin.y;
                // float bannerH = bannerAd.frame.size.height;
                // float bannerY =  toolbarY - bannerH;
                
                if (UIInterfaceOrientationIsLandscape([self interfaceOrientation]) && [FlashCardsAppDelegate isIpad]) {
                    bannerAd.currentContentSizeIdentifier = ADBannerContentSizeIdentifierLandscape;
                } else {
                    bannerAd.currentContentSizeIdentifier = ADBannerContentSizeIdentifierPortrait;
                }
                
                [myTableView setPositionHeight:myTableView.frame.size.height - bannerAd.frame.size.height];
                [self.view addSubview:bannerAd];
                [bannerAd setPositionBehind:myTableView distance:0];
            }
        }
    }
}

- (BOOL)shouldAutorotate {
    UIInterfaceOrientation interfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    return [FlashCardsAppDelegate shouldAutorotate:interfaceOrientation];
}

-(IBAction)beginStudying:(id)sender {

    int defaultFirstSide = -1;
    if (collection) {
        defaultFirstSide = [collection.defaultFirstSide intValue];
    } else if (cardSet) {
        if (cardSet.collection) {
            defaultFirstSide = [cardSet.collection.defaultFirstSide intValue];
        }
    }
    if (defaultFirstSide >= 0 && defaultFirstSide != self.showFirstSide) {
        
        RIButtonItem *cancelItem = [RIButtonItem item];
        cancelItem.label = NSLocalizedStringFromTable(@"Cancel", @"Feedback", @"");
        cancelItem.action = ^{};
        
        RIButtonItem *saveChangeItem = [RIButtonItem item];
        saveChangeItem.label = NSLocalizedStringFromTable(@"Change Default First Side", @"Settings", @"");
        saveChangeItem.action = ^{
            // save the change

            if (collection) {
                [collection setDefaultFirstSide:[NSNumber numberWithInt:self.showFirstSide]];
            } else if (cardSet) {
                if (cardSet.collection) {
                    [cardSet.collection setDefaultFirstSide:[NSNumber numberWithInt:self.showFirstSide]];
                }
            }

            [self actuallyBeginStudying];
        };
        
        RIButtonItem *dontSaveChangeItem = [RIButtonItem item];
        dontSaveChangeItem.label = NSLocalizedStringFromTable(@"Don't Change Default", @"Settings", @"");
        dontSaveChangeItem.action = ^{
            [self actuallyBeginStudying];
        };
        
        NSString *firstSideText = @"";
        if (showFirstSide == showFirstSideFront) {
            firstSideText = NSLocalizedStringFromTable(@"Front", @"Study", @"");
        } else if (showFirstSide == showFirstSideBack) {
            firstSideText = NSLocalizedStringFromTable(@"Back", @"Study", @"");
        } else if (showFirstSide == showFirstSideRandom) {
            firstSideText = NSLocalizedStringFromTable(@"Random", @"Study", @"");
        } else {
            [self actuallyBeginStudying];
            return;
        }
        
        NSString *collectionName = @"";
        if (collection) {
            collectionName = collection.name;
        } else if (cardSet) {
            if (cardSet.collection) {
                collectionName = cardSet.collection.name;
            }
        }
        if ([collectionName length] == 0) {
            [self actuallyBeginStudying];
            return;
        }
        
        NSString *message = [NSString stringWithFormat:NSLocalizedStringFromTable(@"You have selected '%@' as the first study side. Would you like to save this as the default for the Collection '%@'? Then the Review mode will use this as the first study side as well.", @"Study", @""),
                             firstSideText,
                             collectionName];
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@""
                                                        message:message
                                               cancelButtonItem:cancelItem
                                               otherButtonItems:saveChangeItem, dontSaveChangeItem, nil];
        [alert show];

    } else {
        [self actuallyBeginStudying];
    }
    
}

- (void)actuallyBeginStudying {
    if (self.loadingCardsFromSavedState) {
        numCardsToLoad = 0;
    }
    
    // save settings in NSDefaults:
    [FlashCardsCore setSetting:@"studySettingSelectCards" value:[NSNumber numberWithInt:selectCards]];
    [FlashCardsCore setSetting:@"studySettingOrder" value:[NSNumber numberWithInt:studyOrder]];
    [FlashCardsCore setSetting:@"studySettingBrowseMode" value:[NSNumber numberWithInt:studyBrowseMode]];
    
    if (studyBrowseMode == studyBrowseModeAutoAudio) {
        if (![FlashCardsCore isConnectedToInternet]) {
            if ([FlashCardsCore hasSubscription] || [FlashCardsCore currentlyUsingOneTimeOfflineTTSTrial]) {
                // continue -- allow them to use offline text-to-speech
            } else {
                if ([FlashCardsCore hasGrandfatherClause]) {
                    SubscriptionViewController *vc = [[SubscriptionViewController alloc] initWithNibName:@"SubscriptionViewController" bundle:nil];
                    vc.giveTrialOption = YES;
                    vc.showTrialEndedPopup = NO;
                    vc.explainSync = NO;
                    [self.navigationController pushViewController:vc animated:YES];
                } else {
                    [FlashCardsCore showPurchasePopup:@"TTS"];
                }
                return;
            }
        }
        if ((collection.frontValueLanguage && [collection.frontValueLanguage usesLatex]) ||
            (collection.backValueLanguage &&  [collection.backValueLanguage usesLatex])) {
            FCDisplayBasicErrorMessage(@"", NSLocalizedStringFromTable(@"Text-to-speech is not available for math or chemistry cards, so auto-browse with audio is not supported.", @"Error", @""));
            return;
        }
        if (!collection.frontValueLanguage || !collection.backValueLanguage) {
            FCDisplayBasicErrorMessage(@"",
                                       NSLocalizedStringFromTable(@"To use text-to-speech, select the language on the front and back side of your cards in the Collection settings.", @"Error", @""));
            return;
        }
    }
    
    StudyViewController *studyVC = [[StudyViewController alloc] initWithNibName:@"StudyViewController" bundle:nil];
    studyVC.previewMode = NO;
    studyVC.collection = self.collection;
    studyVC.cardSet = self.cardSet;
    studyVC.studyingImportedSet = self.studyingImportedSet;
    
    studyVC.popToViewControllerIndex = [[self.navigationController viewControllers] count]-2;
    
    // study options:
    studyVC.studyController.studyAlgorithm = self.studyAlgorithm;
    studyVC.studyController.studyOrder = self.studyOrder;
    studyVC.studyController.selectCards = self.selectCards;
    studyVC.studyController.loadNewCardsOnly = self.loadNewCardsOnly;
    studyVC.studyController.showFirstSide = self.showFirstSide;
    studyVC.studyController.loadingCardsFromSavedState = self.loadingCardsFromSavedState;
    studyVC.studyController.numCardsToLoad = self.numCardsToLoad;
    studyVC.studyBrowseMode = self.studyBrowseMode;

    if (![FlashCardsCore hasFeature:@"HideAds"] && [studyVC respondsToSelector:@selector(interstitialPresentationPolicy)]) {
        studyVC.interstitialPresentationPolicy = ADInterstitialPresentationPolicyManual;
    }

    [self.navigationController pushViewController:studyVC animated:YES];
    
    // Pass the selected object to the new view controller.
    // [self.navigationController pushViewController:studyVC animated:YES];
}

-(void)displaySettings {
    self.title = NSLocalizedStringFromTable(@"Study", @"Study", @"UIView title");
    
    [onlyNewCardsSwitch setOn:loadNewCardsOnly];
    
    int studyOrderSection = 1;
    int studyBrowseModeSection = 2;
    if ([FlashCardsCore hasFeature:@"HideAds"]) {
        studyOrderSection--;
        studyBrowseModeSection--;
    }
    
    UITableViewCell *cell;
    for (int i = 0; i < 3; i++) {
        cell = [self.myTableView cellForRowAtIndexPath:
                [NSIndexPath indexPathForRow:i inSection:studyBrowseModeSection]];
        if (studyBrowseMode == i) {
            [cell setAccessoryType:UITableViewCellAccessoryCheckmark];
        } else {
            [cell setAccessoryType:UITableViewCellAccessoryNone];
        }
    }

    for (int i = 0; i < 3; i++) {
        cell = [self.myTableView cellForRowAtIndexPath:
                [NSIndexPath indexPathForRow:i inSection:studyOrderSection]];
        if (studyOrder == i) {
            [cell setAccessoryType:UITableViewCellAccessoryCheckmark];
        } else {
            [cell setAccessoryType:UITableViewCellAccessoryNone];
        }
    }
}

- (IBAction)onlyNewCardsSwitchChanged:(id)sender {
    loadNewCardsOnly = [onlyNewCardsSwitch isOn];
    int count;
    if (loadNewCardsOnly) {
        // only new cards
        count = cardListCount;
    } else {
        // all cards - including cards which have been memorized
        count = allCardsListCount;
    }
    if (numCardsToLoad > 30) {
        numCardsToLoad = count;
    }

    [FlashCardsCore setSetting:@"studyOnlyNewCards" value:[NSNumber numberWithBool:loadNewCardsOnly]];
    
    [self.myTableView reloadData];
    [self displaySettings];
}

#pragma mark -
#pragma mark Table view data source


- (NSMutableArray*)tableRows {
    NSMutableArray *rows;
    rows = [NSMutableArray arrayWithArray:
    @[
      @[@"hide ads"],
      @[@"linear", @"random", @"smart", @"custom"],
      @[@"manual", @"auto-browse", @"auto-audio"],
      @[@"display settings"],
      // if we are studying lapsed cards, don't show the "Type of Cards" label:
      ((studyAlgorithm == studyAlgorithmLapsed) ?
       @[@"number cards", @"type of cards"] :
       @[@"study only new?", @"number cards", @"type of cards"]),
      @[@"first side shown"]
      ]];
    if (studyAlgorithm == studyAlgorithmLapsed) {
        if (cardListCount <= 15) {
            [rows removeObjectAtIndex:4];
        }
    } else {
        int count = cardListCount;
        if (![onlyNewCardsSwitch isOn]) {
            count = allCardsListCount;
        }
        if (count < 30) {
            [rows replaceObjectAtIndex:4
                            withObject:@[@"study only new?"]];
        }
    }
    // get rid of the "hide ads" row if they are a subscriber or otherwise have unlimited cards
    if ([FlashCardsCore hasFeature:@"HideAds"]) {
        [rows removeObjectAtIndex:0];
    }
    return rows;
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    NSArray *rows = [self tableRows];
    return [rows count];
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    NSArray *rows = [self tableRows];
    return [[rows objectAtIndex:section] count];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if ([FlashCardsCore hasFeature:@"HideAds"]) {
        section++;
    }

    if (section > 0 && section < 3) {
        return 40;
    }
    return 0;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    
    if ([FlashCardsCore hasFeature:@"HideAds"]) {
        section++;
    }

    if (section >= 3) {
        return nil;
    }
    
    UIView* customView = [[UIView alloc] initWithFrame:CGRectMake(10.0, 0.0, 300.0, 44.0)];
    
    // create the button object
    UILabel * headerLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    headerLabel.backgroundColor = [UIColor clearColor];
    headerLabel.opaque = NO;
    headerLabel.textColor = [UIColor blackColor];
    headerLabel.highlightedTextColor = [UIColor whiteColor];
    headerLabel.font = [UIFont boldSystemFontOfSize:20];
    if ([FlashCardsAppDelegate isIpad]) {
        headerLabel.frame = CGRectMake(60.0, 0.0, 300.0, 44.0);
    } else {
        headerLabel.frame = CGRectMake(10.0, 0.0, 300.0, 44.0);
    }
    
    if (section == 1) {
        headerLabel.text = NSLocalizedStringFromTable(@"Study Order", @"Study", @"UILabel");
    } else if (section == 2) {
        headerLabel.text = NSLocalizedStringFromTable(@"Study Mode", @"Study", @"UILabel");
    }
    
    [customView addSubview:headerLabel];
    
    return customView;
}

- (NSString*)studyModeExplanationString {
    if (studyBrowseMode == studyBrowseModeAutoAudio) {
        return NSLocalizedStringFromTable(@"Automatically move from one card to the next, and text-to-speech automatically reads both sides.", @"Study", @"");
    } else if (studyBrowseMode == studyBrowseModeAutoBrowse) {
        return NSLocalizedStringFromTable(@"Automatically move from one card to the next.", @"Study", @"");
    }
    return @"";
}

- (NSString*)studyOrderExplanationString {
    if (studyOrder == studyOrderSmart) {
        return NSLocalizedStringFromTable(@"FlashCards++ learns which cards are easier or more difficult for you and presents the more difficult ones more frequently as you study.", @"Study", @"");
    }
    return @"";
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    if ([FlashCardsCore hasFeature:@"HideAds"]) {
        section++;
    }

    if (section != 2 && section != 1) {
        return 0;
    }
    NSString *explanation;
    if (section == 1) {
        explanation = [self studyOrderExplanationString];
    } else {
        explanation = [self studyModeExplanationString];
    }
    if ([explanation length] == 0) {
        return 0.0;
    }
    
    // create the button object
    UITextView * footerLabel = [[UITextView alloc] initWithFrame:CGRectMake(0.0f,
                                                                            0.0f,
                                                                            self.view.frame.size.width-16.0,
                                                                            0.0f)];
    footerLabel.backgroundColor = [UIColor clearColor];
    footerLabel.opaque = NO;
    footerLabel.textColor = [UIColor blackColor];
    footerLabel.text = explanation;
    [footerLabel setFont:[UIFont systemFontOfSize:12.0f]];
    [footerLabel setTextAlignment:NSTextAlignmentCenter];
    
    CGSize tallerSize, stringSize;
    tallerSize = CGSizeMake(self.view.frame.size.width-16.0, kMaxFieldHeight);
    stringSize = [footerLabel.text sizeWithFont:footerLabel.font constrainedToSize:tallerSize lineBreakMode:NSLineBreakByWordWrapping];
    return stringSize.height+10.0f;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    if ([FlashCardsCore hasFeature:@"HideAds"]) {
        section++;
    }

    if (section != 2 && section != 1) {
        return nil;
    }
    
    NSString *explanation;
    if (section == 1) {
        explanation = [self studyOrderExplanationString];
    } else {
        explanation = [self studyModeExplanationString];
    }
    
    if ([explanation length] == 0) {
        return nil;
    }
    
    // create the button object
    UITextView * footerLabel = [[UITextView alloc] initWithFrame:CGRectMake(0.0f,
                                                                            0.0f,
                                                                            self.view.frame.size.width-16.0,
                                                                            0.0f)];
    footerLabel.backgroundColor = [UIColor clearColor];
    footerLabel.opaque = NO;
    footerLabel.textColor = [UIColor blackColor];
    footerLabel.text = explanation;
    [footerLabel setFont:[UIFont systemFontOfSize:12.0f]];
    [footerLabel setTextAlignment:NSTextAlignmentCenter];
    footerLabel.userInteractionEnabled = NO;
    
    CGSize tallerSize, stringSize;
    tallerSize = CGSizeMake(self.view.frame.size.width-16.0, kMaxFieldHeight);
    CGRect boundingRect = [footerLabel.text boundingRectWithSize:tallerSize
                                                         options:NSStringDrawingUsesLineFragmentOrigin
                                                      attributes:@{NSFontAttributeName:footerLabel.font}
                                                         context:nil];
    stringSize = boundingRect.size;
    [footerLabel setFrame:CGRectMake(footerLabel.frame.origin.x,
                                     footerLabel.frame.origin.y,
                                     footerLabel.frame.size.width,
                                     stringSize.height+10.0f)];
    
    return footerLabel;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    int row = (int)indexPath.row;
    NSArray *_tableRows = [self tableRows];
    NSArray *rows = [_tableRows objectAtIndex:indexPath.section];
    NSString *rowName = [rows objectAtIndex:indexPath.row];
    int section = (int)indexPath.section;
    if ([FlashCardsCore hasFeature:@"HideAds"]) {
        section++;
    }

    if (section == 0) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"hideAdsCell"];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"hideAdsCell"];
        }
        cell.userInteractionEnabled = YES;
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.textLabel.text = NSLocalizedStringFromTable(@"Hide Ads", @"Subscription", @"UILabel");
        cell.detailTextLabel.text = @"";
        return cell;
    } else if (section == 1) {
        SizableImageCell *cell = (SizableImageCell*)[tableView dequeueReusableCellWithIdentifier:@"studyOrderCell"];
        if (cell == nil) {
            cell = [[SizableImageCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"studyOrderCell"];
        }
        cell.userInteractionEnabled = YES;
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        if (indexPath.row == studyOrder) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        } else {
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
        if ([rowName isEqualToString:@"random"]) {
            [cell.imageView setImage:[UIImage imageNamed:@"05-shuffle.png"]];
            cell.textLabel.text = NSLocalizedStringFromTable(@"Random", @"Study", @"");
        } else if ([rowName isEqualToString:@"smart"]) {
            [cell.imageView setImage:[UIImage imageNamed:@"84-lightbulb.png"]];
            cell.textLabel.text = NSLocalizedStringFromTable(@"Smart", @"Study", @"");
        } else if ([rowName isEqualToString:@"linear"]) {
            [cell.imageView setImage:[UIImage imageNamed:@"104-index-cards.png"]];
            cell.textLabel.text = NSLocalizedStringFromTable(@"Linear", @"Study", @"");
        } else if ([rowName isEqualToString:@"custom"]) {
            [cell.imageView setImage:[UIImage imageNamed:@"04-squiggle.png"]];
            cell.textLabel.text = NSLocalizedStringFromTable(@"Custom Order", @"Study", @"");
        }
        cell.detailTextLabel.text = @"";
        return cell;
    } else if (section == 2) {
        SizableImageCell *cell = (SizableImageCell*)[tableView dequeueReusableCellWithIdentifier:@"studyModeCell"];
        if (cell == nil) {
            cell = [[SizableImageCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"studyModeCell"];
        }
        cell.userInteractionEnabled = YES;
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        if (indexPath.row == studyBrowseMode) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        } else {
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
        if ([rowName isEqualToString:@"manual"]) {
            [cell.imageView setImage:[UIImage imageNamed:@"102-walk.png"]];
            cell.textLabel.text = NSLocalizedStringFromTable(@"Manual", @"Study", @"");
        } else if ([rowName isEqualToString:@"auto-browse"]) {
            [cell.imageView setImage:[UIImage imageNamed:@"02-redo.png"]];
            cell.textLabel.text = NSLocalizedStringFromTable(@"Auto-Browse", @"Study", @"");
        } else if ([rowName isEqualToString:@"auto-audio"]) {
            [cell.imageView setImage:[UIImage imageNamed:@"speaker-on.png"]];
            cell.textLabel.text = NSLocalizedStringFromTable(@"Auto-Browse with Audio", @"Study", @"");
        }
        cell.detailTextLabel.text = @"";
        return cell;
    } else {
        if ([rowName isEqualToString:@"display settings"]) {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"displaySettingsCell"];
            if (cell == nil) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"displaySettingsCell"];
            }
            cell.userInteractionEnabled = YES;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.textLabel.text = NSLocalizedStringFromTable(@"Display Settings", @"Settings", @"UILabel");
            cell.detailTextLabel.text = @"";
            return cell;
        } else if ([rowName isEqualToString:@"study only new?"]) {
            return onlyNewCardsCell;
        } else if ([rowName isEqualToString:@"number cards"]) {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell1"];
            if (cell == nil) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"cell1"];
            }
            cell.userInteractionEnabled = YES;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.textLabel.text = NSLocalizedStringFromTable(@"Number of Cards", @"Study", @"UILabel");
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%d", numCardsToLoad];
            return cell;
        } else if ([rowName isEqualToString:@"first side shown"]) {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell2"];
            if (cell == nil) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"cell2"];
            }
            cell.userInteractionEnabled = YES;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.textLabel.text = NSLocalizedStringFromTable(@"First Side Shown", @"Study", @"UILabel");
            if (showFirstSide == showFirstSideFront) {
                cell.detailTextLabel.text = NSLocalizedStringFromTable(@"Front", @"Study", @"");
            } else if (showFirstSide == showFirstSideBack) {
                cell.detailTextLabel.text = NSLocalizedStringFromTable(@"Back", @"Study", @"");
            } else if (showFirstSide == showFirstSideRandom) {
                cell.detailTextLabel.text = NSLocalizedStringFromTable(@"Random", @"Study", @"");
            } else {
                cell.detailTextLabel.text = @"";
            }
            return cell;
        } else if ([rowName isEqualToString:@"type of cards"]) {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell2"];
            if (cell == nil) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"cell2"];
            }
            cell.userInteractionEnabled = YES;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.textLabel.text = NSLocalizedStringFromTable(@"Select", @"Study", @"UILabel");
            if (selectCards == selectCardsRandom) {
                cell.detailTextLabel.text = NSLocalizedStringFromTable(@"Random Cards", @"Study", @"");
            } else if (selectCards == selectCardsHardest) {
                cell.detailTextLabel.text = NSLocalizedStringFromTable(@"Hardest Cards", @"Study", @"");
            } else if (selectCards == selectCardsNewest) {
                cell.detailTextLabel.text = NSLocalizedStringFromTable(@"Newest Cards", @"Study", @"");
            } else {
                cell.detailTextLabel.text = @"";
            }
            return cell;
        }
    }
    return nil;
}

#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // Navigation logic may go here. Create and push another view controller.
    ActionStringCancelBlock cancel = ^(ActionSheetStringPicker *picker) {
        NSLog(@"Block Picker Canceled");
    };
    int section = (int)indexPath.section;
    if ([FlashCardsCore hasFeature:@"HideAds"]) {
        section++;
    }

    if (section == 0) {
        [tableView deselectRowAtIndexPath:indexPath animated:NO];
        [Flurry logEvent:@"HideAds"];
        SubscriptionViewController *vc = [[SubscriptionViewController alloc] initWithNibName:@"SubscriptionViewController" bundle:nil];
        vc.showTrialEndedPopup = NO;
        vc.giveTrialOption = NO;
        vc.explainSync = NO;
        [self.navigationController pushViewController:vc animated:YES];
    } else if (section == 1) {
        [tableView deselectRowAtIndexPath:indexPath animated:NO];
        if (indexPath.row == studyOrderCustom) {
            if (self.cardSet) {
                if (![[self.cardSet hasCardOrder] boolValue]) {
                    FCDisplayBasicErrorMessage(@"",
                                               NSLocalizedStringFromTable(@"This card set does not yet have a custom card order yet.", @"CardManagement", @""));
                    return;
                }
            } else {
                FCDisplayBasicErrorMessage(@"",
                                           NSLocalizedStringFromTable(@"You can only set a custom card order within a Card Set, not a Collection (top level group).", @"CardManagement", @""));
                return;
            }
        }
        studyOrder = (int)indexPath.row;
        [self.myTableView reloadData];
    } else if (section == 2) {
        [tableView deselectRowAtIndexPath:indexPath animated:NO];
        studyBrowseMode = (int)indexPath.row;
        [self.myTableView reloadData];
    } else {
        NSArray *rows = [self tableRows];
        NSString *row = [[rows objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
        if ([row isEqualToString:@"display settings"]) {
            [tableView deselectRowAtIndexPath:indexPath animated:NO];
            SettingsStudyViewController *vc = [[SettingsStudyViewController alloc] initWithNibName:@"SettingsStudyViewController" bundle:nil];
            vc.goToStudySettings = YES;
            [self.navigationController pushViewController:vc animated:YES];

        } else if ([row isEqualToString:@"first side shown"]) {
            [tableView deselectRowAtIndexPath:indexPath animated:NO];
            ActionStringDoneBlock done = ^(ActionSheetStringPicker *picker, NSInteger selectedIndex, id selectedValue) {
                showFirstSide = (int)selectedIndex;
                [self.myTableView reloadData];
            };
            NSArray *options = @[
                                 NSLocalizedStringFromTable(@"Front", @"Study", @""),
                                 NSLocalizedStringFromTable(@"Back", @"Study", @""),
                                 NSLocalizedStringFromTable(@"Random", @"Study", @"")
                                 ];
            int i = 0;
            int initialSelection = 0;
            for (NSString *option in options) {
                if (i == showFirstSide) {
                    initialSelection = i;
                }
                i++;
            }
            [ActionSheetStringPicker showPickerWithTitle:NSLocalizedStringFromTable(@"First Side Shown", @"Study", @"")
                                                    rows:options
                                        initialSelection:initialSelection
                                               doneBlock:done
                                             cancelBlock:cancel
                                                  origin:beginStudyingButton];
        } else if ([row isEqualToString:@"type of cards"]) {
            [tableView deselectRowAtIndexPath:indexPath animated:NO];
            ActionStringDoneBlock done = ^(ActionSheetStringPicker *picker, NSInteger selectedIndex, id selectedValue) {
                selectCards = selectedIndex;
                [self.myTableView reloadData];
            };
            NSArray *options = @[
                                 NSLocalizedStringFromTable(@"Random Cards", @"Study", @""),
                                 NSLocalizedStringFromTable(@"Hardest Cards", @"Study", @""),
                                 NSLocalizedStringFromTable(@"Newest Cards", @"Study", @"")
                                 ];
            int i = 0;
            int initialSelection = 0;
            for (NSString *option in options) {
                if (i == selectCards) {
                    initialSelection = i;
                }
                i++;
            }
            [ActionSheetStringPicker showPickerWithTitle:NSLocalizedStringFromTable(@"Select", @"Study", @"")
                                                    rows:options
                                        initialSelection:initialSelection
                                               doneBlock:done
                                             cancelBlock:cancel
                                                  origin:beginStudyingButton];
        } else if ([row isEqualToString:@"number cards"]) {
            [tableView deselectRowAtIndexPath:indexPath animated:NO];

            NSMutableArray *options = [NSMutableArray arrayWithCapacity:0];
            NSMutableArray *optionsNumbers = [NSMutableArray arrayWithCapacity:0];
            // display the settings:
            if (studyAlgorithm == studyAlgorithmLapsed) {
                // if the number of cards > 15, then show the # cards interface,
                [options addObject:NSLocalizedStringFromTable(@"Only 15", @"Study", @"")];
                [optionsNumbers addObject:@15];
                [options addObject:NSLocalizedStringFromTable(@"All Lapsed", @"Study", @"")];
                [optionsNumbers addObject:[NSNumber numberWithInt:cardListCount]];
            } else {
                // we are not looking at lapsed cards, it is probably "learning" mode:

                // the max number of cards which users have the option to study
                int maxCardsToStudy = 50;

                // set the allCards button to update the # of cards in "All X Cards" whenever it changes:
                // set the right value for the # cards in "All X Cards"
                int count;
                if ([onlyNewCardsSwitch isOn]) {
                    // only new cards
                    count = cardListCount;
                } else {
                    // all cards - including cards which have been memorized
                    count = allCardsListCount;
                }
                
                int maxCardsInList = 0;
                for (int i = 10; i <= maxCardsToStudy && i < count; i += 5) {
                    [options addObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Random %d", @"Study", @""), i]];
                    [optionsNumbers addObject:[NSNumber numberWithInt:i]];
                    maxCardsInList = i;
                }

                // we used to compare the count of cards to maxCardsInList (i.e. 50)
                // but if there were e.g. 34 cards, then we would have 10, 15, 20, 25, 30
                // but **not** 34! It would only work if e.g. there were 134 cards. Then
                // count = 134 > 50. But count = 34 < 50, but count = 34 > 30.
                if (count > maxCardsInList) {
                    [options addObject:[NSString stringWithFormat:FCPluralLocalizedStringFromTable(@"%d Cards", @"Plural", @"", [NSNumber numberWithInt:count]), count]];
                    [optionsNumbers addObject:[NSNumber numberWithInt:count]];
                }
            }
            int i = 0;
            int initialSelection = 0;
            for (NSNumber *option in optionsNumbers) {
                if ([option intValue] == numCardsToLoad) {
                    initialSelection = i;
                }
                i++;
            }
            
            ActionStringDoneBlock done = ^(ActionSheetStringPicker *picker, NSInteger selectedIndex, id selectedValue) {
                NSNumber *num = [optionsNumbers objectAtIndex:selectedIndex];
                numCardsToLoad = [num intValue];
                [self.myTableView reloadData];
            };

            [ActionSheetStringPicker showPickerWithTitle:NSLocalizedStringFromTable(@"Number of Cards", @"Study", @"")
                                                    rows:options
                                        initialSelection:initialSelection
                                               doneBlock:done
                                             cancelBlock:cancel
                                                  origin:beginStudyingButton];
            
        }
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
