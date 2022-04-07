//
//  FAQViewController.m
//  FlashCards
//
//  Created by Jason Lustig on 6/30/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import "FlashCardsAppDelegate.h"
#import "FlashCardsCore.h"

#import "FAQViewController.h"
#import "HelpViewController.h"
#import "FeedbackViewController.h"

#import "HelpConstants.h"

#import <MessageUI/MessageUI.h>


@implementation FAQViewController

@synthesize faq, gettingStarted;
@synthesize myTableView;
@synthesize rateInAppStoreButton, sendFeedbackButton;

#pragma mark -
#pragma mark View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = NSLocalizedStringFromTable(@"Help", @"Help", @"UIView title");
    
    rateInAppStoreButton.title = NSLocalizedStringFromTable(@"Rate in App Store", @"Feedback", @"UIBarButtonItem");
    sendFeedbackButton.title = NSLocalizedStringFromTable(@"Send Feedback", @"Feedback", @"UIBarButtonItem");
    
    NSMutableDictionary *question;

    gettingStarted = [[NSMutableArray alloc] initWithCapacity:0];
    question = [[NSMutableDictionary alloc] initWithCapacity:0];
    [question setObject:NSLocalizedStringFromTable(@"Getting Started", @"Help", @"") forKey:@"question"];
    [question setObject:[GettingStartedText stringByAppendingString:GlossaryText] forKey:@"answer"];
    [gettingStarted addObject:question];
        
    question = [[NSMutableDictionary alloc] initWithCapacity:0];
    NSString *version = [FlashCardsCore appVersion];
    [question setObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"What's New in %@", @"Help", @"UIView title"), version]
                 forKey:@"question"];
    [question setObject:whatsNewInThisVersion forKey:@"answer"];
    [question setObject:@YES forKey:@"usesMath"];
    [gettingStarted addObject:question];

    
    faq = [[NSMutableArray alloc] initWithCapacity:0];
    
    question = [[NSMutableDictionary alloc] initWithCapacity:0];
    [question setObject:NSLocalizedStringFromTable(@"What is FlashCards++?", @"Help", @"") forKey:@"question"];
    [question setObject:NSLocalizedStringWithDefaultValue(@"What is FlashCards++? ANSWER", @"Help", [NSBundle mainBundle], @""
        "<p>FlashCards++ is the premier flash card app for the iPhone and iPod touch. "
        "Using FlashCards++, you can study effectively by building a database "
        "of your knowledge and determining the best time to study. FlashCards++ "
        "currently only supports text-based cards, but supports any language.</p>", @"")
        forKey:@"answer"];
    [faq addObject:question];
    
    question = [[NSMutableDictionary alloc] initWithCapacity:0];
    [question setObject:NSLocalizedStringFromTable(@"What is Spaced Repetition?", @"Help", @"") forKey:@"question"];
    [question setObject:NSLocalizedStringWithDefaultValue(@"What is Spaced Repetition? ANSWER", @"Help", [NSBundle mainBundle], @""
                "<p>To enable the most effective long-term memory retention, you should "
                "\"space out\" when you study. If you study every vocabulary word every day, "
                "you might remember them, but you'll spend all day studying. In fact, if you "
                "wait between each study session, your memorization will become deeper as the "
                "information shifts from short-term to long-term memory.</p>"
                "<p>In other words, the best time to study something is when you are about to "
                "forget it. FlashCards++ utilizes an effective and proven algorithm, "
                "pioneered by SuperMemo, to decide when to test you.</p>"
                "<p>Note that FlashCards++ is not affiliated or associated with SuperMemo.</p>", @"")
                 forKey:@"answer"];
    [faq addObject:question];
    
    question = [[NSMutableDictionary alloc] initWithCapacity:0];
    [question setObject:NSLocalizedStringFromTable(@"The FlashCards++ Method", @"Help", @"") forKey:@"question"];
    [question setObject:NSLocalizedStringWithDefaultValue(@"The FlashCards++ Method - ANSWER", @"Help", [NSBundle mainBundle], @""
     "<ol>"
     " <li>Import cards into a Card Set, and de-dupe the cards.</li>"
     " <li>Edit the cards to find typos.</li>"
     " <li>Study cards for a few rounds in Random or Smart study modes until you have memorized them.</li>"
     " <li>\"Test\" the cards to enter them into the Spaced Repetition algorithm.</li>"
     " <li>Study cards when you are prompted, and also study when you need to refresh before a test.</li>"
     " <li>Re-study cards which scored less than 4 (\"OK\") so that you will still remember them later.</li>"
     " <li>After re-studying cards with scores less than 4, you can tap \"Begin Test\" to re-test the cards and re-enter them into the spaced repetition algorithm.</li>"
     " <li>Re-learn any Lapsed cards which you didn't immediately re-test, which are cards you memorized and then forgot, and re-test them to enter them into the Spaced Repetition algorithm.</li>"
     "</ol>", @"")
                 forKey:@"answer"];
    [faq addObject:question];

    
    question = [[NSMutableDictionary alloc] initWithCapacity:0];
    [question setObject:NSLocalizedStringFromTable(@"Can I add photos or audio?", @"Help", @"") forKey:@"question"];
    [question setObject:NSLocalizedStringWithDefaultValue(@"Can I add photos or audio? ANSWER", @"Help", [NSBundle mainBundle], @""
     "<p>You can now add pictures to your flash cards, but unfortunately audio flash cards are not yet supported. You can choose photos "
     "from your library or, if your mobile device has a camera, you can take pictures with your camera and put them into your flash cards.</p>", @"")
                 forKey:@"answer"];
    [faq addObject:question];
    
    question = [[NSMutableDictionary alloc] initWithCapacity:0];
    [question setObject:NSLocalizedStringFromTable(@"Studying Math", @"Help", @"") forKey:@"question"];
    [question setObject:NSLocalizedStringWithDefaultValue(@"Studying Math ANSWER", @"Help", [NSBundle mainBundle], @"", @"")
                 forKey:@"answer"];
    [question setObject:@YES forKey:@"usesMath"];
    [faq addObject:question];

    question = [[NSMutableDictionary alloc] initWithCapacity:0];
    [question setObject:NSLocalizedStringFromTable(@"Studying Chemistry", @"Help", @"") forKey:@"question"];
    [question setObject:NSLocalizedStringWithDefaultValue(@"Studying Chemistry ANSWER", @"Help", [NSBundle mainBundle], @""
    "You can create chemistry math cards with superscripts and subscripts using the LaTeX formatting options. Please see 'Studying Math' for instructions on how to use the special formatting for math and chemistry.", @"")
                 forKey:@"answer"];
    [faq addObject:question];

    question = [[NSMutableDictionary alloc] initWithCapacity:0];
    [question setObject:NSLocalizedStringFromTable(@"Sharing Flash Cards", @"Help", @"") forKey:@"question"];
    [question setObject:NSLocalizedStringWithDefaultValue(@"Studying Flash Cards - ANSWER", @"Help", [NSBundle mainBundle], @""
     "<p>You can easily share flash cards with your friends via e-mail. Here's how: "
     "Go to the collection or card set which you would like to share, and tap \"Share.\" "
     "You will have the option to share in one of two formats. Both formats are great options to share cards, "
     "but there are some differences. Here's what you should know:</p>"
     "<ul>"
     " <li><i>FlashCards++ Format:</i> This is the preferred format for sharing cards, because "
     " they are the native application format. You can also share images in this format, and they can "
     " be directly imported into FlashCards++ by your friend and will retain information about the cards "
     " such as which ones are related to one another.</li>"
     " <li><i>CSV (Comma-Separated Value) Format:</i> This format creates a spreadsheet compatible "
     " with Microsoft Excel which you can open on your computer. Your friends can also import it directly "
     " to FlashCards++, but there are two downsides: (1) CSV format can contain only text, not images, and (2) "
     " the CSV format cannot contain information about which cards are a part of which card set and which cards are related "
     " to one another.</li>"
     "</ul>", @"")
                 forKey:@"answer"];
    [faq addObject:question];
    
    question = [[NSMutableDictionary alloc] initWithCapacity:0];
    [question setObject:NSLocalizedStringFromTable(@"Automatically Syncing Cards", @"Help", @"") forKey:@"question"];
    [question setObject:NSLocalizedStringFromTableInBundle(@"Automatically Syncing Cards - ANSWER", @"Help", [NSBundle mainBundle], @""
    @"You can sync automatically flash cards with FlashCards++ on your other iOS devices, and also with "
    @"the Quizlet web service."
    @""
    @"To turn on automatic sync, go to the device with the most up-to-date data, and simply tap 'Sync with iPhone' or 'Sync with iPad' on the main screen of the app. If it's not listed there, go to the Settings screen and turn the 'Automatically Sync' setting to 'On.'"
    @"After you turn on sync on this main device you will be prompted to upload the master database. Upload your flash card database, and when this is complete, go to your other iOS devices and tap the 'Automatically Sync' button. You will be prompted to download the master database. Once you have downloaded this master database (uploaded from the other device), sync will be fully enabled and any changes you make will be applied on both devices. "
    @""
    @"To sync cards with Quizlet, simply import cards as usual and make sure to select 'Sync with Internet'."
                                                           ) forKey:@"answer"];
    [faq addObject:question];

    
    question = [[NSMutableDictionary alloc] initWithCapacity:0];
    [question setObject:NSLocalizedStringFromTable(@"Cards are Out of Sync", @"Help", @"") forKey:@"question"];
    [question setObject:NSLocalizedStringFromTableInBundle(@"Cards are Out of Sync - ANSWER", @"Help", [NSBundle mainBundle], @""
    @"Usually the automatic sync should work properly. But if your cards ever get out of sync between one iOS device and another, you may need to reset the automatic sync function."
    @""
    @"To reset the sync, on all of your devices go to the Settings screen and turn off the 'Automatic Sync' function. "
    @"Make sure to select 'Turn off on All Devices' when turning off sync. This will ensure that the sync data is cleared out "
    @"so that any corruption which caused the cards to become out of sync will be cleared out. Then, turn sync on as you did initially when setting up the automatic sync."
    @""
    @"Once you have turned sync on again on all of your devices, the cards should be in sync again and should hopefully remain that way."
                                                           ) forKey:@"answer"];
    [faq addObject:question];
    
    question = [[NSMutableDictionary alloc] initWithCapacity:0];
    [question setObject:NSLocalizedStringFromTable(@"Importing Flash Cards", @"Help", @"") forKey:@"question"];
    [question setObject:NSLocalizedStringWithDefaultValue(@"Importing Flash Cards - ANSWER", @"Help", [NSBundle mainBundle], @""
    "<p>You can import flash cards from <a href=\"http://www.quizlet.com/\">Quizlet</a>, one of the most "
    "popular online flash card websites. You can also choose to import cards from CSV files hosted on Dropbox.</p>"
    "<p>Simply go to Your Collection (e.g. German) -> "
    "Import to import cards. Alternately, you may import cards into a specific, already-existing card set "
    "by clicking on Your Collection -> View Card Sets -> Your Card Set (e.g. Lesson 3) -> Import.</p>"
    "<p>At this point you can choose which service (Quizlet or Dropbox) you "
    "wish to import from.</p>"
    "<p>If you are importing from CSV or Excel, make sure that you have entered the front card value in Column A, and the back card value in Column B.</p>", @"")
                 forKey:@"answer"];
    [faq addObject:question];
    
    question = [[NSMutableDictionary alloc] initWithCapacity:0];
    [question setObject:NSLocalizedStringFromTable(@"Importing from Excel & CSV", @"Help", @"") forKey:@"question"];
    [question setObject:NSLocalizedStringWithDefaultValue(@"Importing from Excel - ANSWER", @"Help", [NSBundle mainBundle], @""
    "<p>It is very easy to import flash cards from Excel. The file format is very simple, just put the front card value "
    "in column A of your spreadsheet, and the back card value in column B. Then save the file "
    "in your Dropbox. (You can also save the file as a CSV.) You will then be able to find it in the Import screen and save it to your iPhone or other  mobile device. Alternately, you can email the file to yourself and you can import it "
    "from the Mail app.</p>", @"")
                 forKey:@"answer"];
    [faq addObject:question];
    
    question = [[NSMutableDictionary alloc] initWithCapacity:0];
    [question setObject:NSLocalizedStringFromTable(@"Moving Cards to a Different Card Set", @"Help", @"") forKey:@"question"];
    [question setObject:NSLocalizedStringWithDefaultValue(@"Moving Cards to a Different Card Set - ANSWER", @"Help", [NSBundle mainBundle], @""
    "<p>Moving cards from one card set to another is very easy. Here's how to do it:</p>"
    "<ol>"
    "   <li>Go to edit the card that you want to move from card set A to card set B.</li>"
    "   <li>Tap on the \"Card Sets\" button, which will show you the list of all card sets in the collection. Any card sets which this card is a part of will have a checkmark next to them.</li>"
    "   <li>Tap on your new card set to include the card in this card set. If you don't want the card to be in the old card set, simply tap that card set to remove it from that set.</li>" 
    "</ol>", @"") forKey:@"answer"];
    [faq addObject:question];
    
    question = [[NSMutableDictionary alloc] initWithCapacity:0];
    [question setObject:NSLocalizedStringFromTable(@"Studying Cards Again", @"Help", @"") forKey:@"question"];
    [question setObject:NSLocalizedStringWithDefaultValue(@"Studying Cards Again - ANSWER", @"Help", [NSBundle mainBundle], @""
     "<p>After you study your cards for the first time, FlashCards++ waits a certain period of time before prompting you "
     " to re-study and review those cards. Each card's repetition time is determined based on how easy or difficult it is individually. "
     " However, if you would like, you can re-study cards as often as you like. Whenever you tap <i>Learn Cards</i> or <i>Test Cards</i>, if "
     " all cards in your Card Set or Collection have been marked as \"Memorized\" (i.e. it got a passing score in the Test Cards stage), then "
     " FlashCards++ will alert you and allow you to \"Re-Study\" your cards which will allow you to go through them again if you would like.</p>", @"")
                 forKey:@"answer"];
    [faq addObject:question];
    
    question = [[NSMutableDictionary alloc] initWithCapacity:0];
    [question setObject:NSLocalizedStringFromTable(@"Unicode Support", @"Help", @"") forKey:@"question"];
    [question setObject:NSLocalizedStringWithDefaultValue(@"Unicode Support - ANSWER", @"Help", [NSBundle mainBundle], @""     
     "FlashCards++ supports all languages by using Unicode. However, to type in languages other than your mobile device's"
     "default language (usually English), you need to enable foreign keyboards. Here's how:"
     "<ol>"
     "<li>Open your mobile device's Settings app.</li>"
     "<li>Tap the <i>General</i> tab.</li>"
     "<li>Tap the <i>Keyboard</i> tab.</li>"
     "<li>Tap the <i>International Keyboards</i> tab.</li>"
     "<li>Tap <i>Add New Keyboard</i>.</li>"
     "<li>Tap on any keyboard to add it.</li>"
     "<li>When you return to FlashCards++, whenever you see a keyboard on screen, there will be an \"international\" icon to the left of the space bar. "
     "Tap and hold this icon to see a list of international keyboards which you can use to type in FlashCards++.</li>"
     "</ol>", @"")     
                 forKey:@"answer"];
    [faq addObject:question];

    question = [[NSMutableDictionary alloc] initWithCapacity:0];
    [question setObject:NSLocalizedStringFromTable(@"Importing Tips & Tricks", @"Help", @"") forKey:@"question"];
    [question setObject:NSLocalizedStringWithDefaultValue(@"Importing Tips & Tricks - ANSWER", @"Help", [NSBundle mainBundle], @""                 
    "<ul>"
     "<li><strong>Use a systematic convention</strong> for your cards. That way, you will be more likely "
     "to find duplicate cards. For example, in German, I use a forwardslash to indicate a separable prefix, e.g. "
     "mit/bringen (to bring with).</li>"
     "<li>Put separate notes, such as past tense forms of verbs, in parantheses. "
     "When searching for duplicates, FlashCards++ ignores all text in parentheses or brackets.</li>"
     "</ul>", @"")
                 forKey:@"answer"];
    [faq addObject:question];
    
    question = [[NSMutableDictionary alloc] initWithCapacity:0];
    [question setObject:NSLocalizedStringFromTable(@"What Do the Scores Mean?", @"Help", @"") forKey:@"question"];
    [question setObject:StudyScoresText forKey:@"answer"];
    [faq addObject:question];
    
    
    
    question = [[NSMutableDictionary alloc] initWithCapacity:0];
    [question setObject:NSLocalizedStringFromTable(@"Glossary", @"Help", @"") forKey:@"question"];
    [question setObject:GlossaryText forKey:@"answer"];
    [faq addObject:question];
     
     
    question = [[NSMutableDictionary alloc] initWithCapacity:0];
    [question setObject:NSLocalizedStringFromTable(@"About/Licensing", @"Help", @"") forKey:@"question"];
    // NOTE: We won't actually i18n the license text.
    NSString *appVersion = [NSString stringWithFormat:@"FlashCards++ Version %@ (%@)", [FlashCardsCore appVersion], [FlashCardsCore buildNumber]];
    [question setObject:[NSString stringWithFormat:@""
     "<p>%@<br />"
     "(c) 2010-2013 Jason Lustig (PhonePro)</p>"
     "<hr />"
     "<small>"
     "<p>This software includes icons by Joseph Wain / glyphish.com, which are licensed under the Creative Commons Attribution 3.0 United States License. To view a copy of this license, visit http://creativecommons.org/licenses/by/3.0/us/ or send a letter to Creative Commons, 171 Second Street, Suite 300, San Francisco, California, 94105, USA.</p>"
     "</small>"
     "<hr />"
     "<small>"
     "<p>Contains TextExpander engine library, Copyright © 2009-2010 SmileOnMyMac, LLC. TextExpander is a trademark of SmileOnMyMac, LLC.</p>"
     "<p>libteEngine (distributed in the form of libteEngine_Simulator.a and libteEngine_Device.a) is Copyright © 2009-2010 SmileOnMyMac, LLC, and is supplied \"AS IS\" and without warranty. SmileOnMyMac, LLC disclaims all warranties, expressed or implied, including, without limitation the warranties of merchantability and of fitness for any purpose. SmileOnMyMac assumes no liability for direct, indirect, incidental, special, exemplary, or consequential damages, which may result from the use of libteEngine, even if advised of the possibility of such damage.</p>"
     "</small>"
     "<hr />"
     "<small>"
     "<p>This software includes RegexKitLite (http://regexkit.sourceforge.net/), licensed under the BSD "
     "license, Copyright (c) 2008-2010, John Engelhart</p>"
     "<p>All rights reserved.</p>"
     "<p>Redistribution and use in source and binary forms, with or without modification, are permitted "
     "provided that the following conditions are met:</p>"
     "<ul>"
     " <li> Redistributions of RegexKitLite source code must retain the above copyright notice, this list of conditions and the "
     "following disclaimer.</li>"
     " <li> Redistributions of RegexKitLite in binary form must reproduce the above copyright notice, this list of conditions and "
     "the following disclaimer in the documentation and/or other materials provided with the distribution.</li>"
     " <li> Neither the name of the Zang Industries nor the names of its contributors may be used to endorse or "
     "promote products derived from RegexKitLite without specific prior written permission.</li>"
     "</ul>"
     "<p>THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS \"AS IS\" AND ANY EXPRESS "
     "OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY "
     "AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR "
     "CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL "
     "DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, "
     "DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER "
     "IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT "
     "OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.</p>"
     "</small>"
     "<hr />"
                         "<small>"
                         "<p>This software includes DTCoreText (http://github.com/Cocoanetics/DTCoretext/), licensed under the BSD "
                         "license, Copyright (c) 2011, Oliver Drobnik</p>"
                         "<p>All rights reserved.</p>"
                         "<p>Redistribution and use in source and binary forms, with or without "
                         "modification, are permitted provided that the following conditions are met:"
                         "<ul><li>Redistributions of source code must retain the above copyright notice, this "
                         "list of conditions and the following disclaimer.</li>"
                         "<li>Redistributions in binary form must reproduce the above copyright notice, "
                         "this list of conditions and the following disclaimer in the documentation "
                         "and/or other materials provided with the distribution.</li></ul>"
                         "<p>THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS \"AS IS\" "
                         "AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE "
                         "IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE "
                         "DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE "
                         "FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL "
                         "DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR "
                         "SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER "
                         "CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, "
                         "OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE "
                         "OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.</p>"
                         "</small>"
                         "<hr />"
                         "<small>"
                         "<p>This software includes MathJax (http://www.mathjax.org/), licensed under the Apache License 2.0. Copyright (c) MathJax.org</p>"
                         "</small>"
, appVersion, nil]
                 forKey:@"answer"];
    [faq addObject:question];
    
    [myTableView reloadData];
    
}


// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotate {
    UIInterfaceOrientation interfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    return [FlashCardsAppDelegate shouldAutorotate:interfaceOrientation];
}


-(IBAction)rateApp:(id)sender {
    [FlashCardsCore writeAppReview];
}

-(IBAction)sendFeedback:(id)sender {
    // send feedback
    FeedbackViewController *vc = [[FeedbackViewController alloc] initWithNibName:@"FeedbackViewController" bundle:nil];
    [self.navigationController pushViewController:vc animated:YES];
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 4;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    if (section == 0) {
        return [gettingStarted count];
    } else if (section == 1) {
        return [faq count];
    } else if (section == 2) {
        return 2;
    } else {
        return 1;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (section == 1) {
        return 40;
    }
    return 0;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    
    UIView* customView = [[UIView alloc] initWithFrame:CGRectMake(10.0, 0.0, 300.0, 44.0)];
    
    if (section != 1) {
        return customView;
    }
    
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
    
    headerLabel.text = NSLocalizedStringFromTable(@"Frequently Asked Questions", @"Help", @"");
    
    [customView addSubview:headerLabel];
    
    return customView;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    
    if (indexPath.section == 0) {
        cell.textLabel.text = [[gettingStarted objectAtIndex:indexPath.row] objectForKey:@"question"];
        [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
    } else if (indexPath.section == 1) {
        cell.textLabel.text = [[faq objectAtIndex:indexPath.row] objectForKey:@"question"];
        cell.textLabel.textAlignment = NSTextAlignmentLeft;
        [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
    } else if (indexPath.section == 2) {
        if (indexPath.row == 0) {
            cell.textLabel.text = NSLocalizedStringFromTable(@"FlashCards++ on Twitter", @"Feedback", @"");
        } else {
            cell.textLabel.text = NSLocalizedStringFromTable(@"FlashCards++ on Facebook", @"Feedback", @"");
        }
        cell.textLabel.textAlignment = NSTextAlignmentLeft;
        [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
    } else if (indexPath.section == 3) {
        cell.textLabel.text = NSLocalizedStringFromTable(@"Tell Friends About FlashCards++", @"Feedback", @"");
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        [cell setAccessoryType:UITableViewCellAccessoryNone];
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
}

#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    [self tableView:tableView didSelectRowAtIndexPath:indexPath];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == 0 || indexPath.section == 1) {
        
        NSMutableDictionary *dict;
        if (indexPath.section == 0) {
            dict = [gettingStarted objectAtIndex:indexPath.row];
        } else {
            dict = [faq objectAtIndex:indexPath.row];
        }
        NSString *question = [dict objectForKey:@"question"];
        
        HelpViewController *helpVC = [[HelpViewController alloc] initWithNibName:@"HelpViewController" bundle:nil];
        
        NSString *answer = [dict objectForKey:@"answer"];

        helpVC.title = NSLocalizedStringFromTable(@"Help", @"Help", @"UIView title");
        helpVC.helpText = [NSString stringWithFormat:@"**%@**\n\n%@", question, answer];
        if ([dict objectForKey:@"usesMath"]) {
            helpVC.usesMath = YES;
        } else {
            helpVC.usesMath = NO;
        }
        
        [self.navigationController pushViewController:helpVC animated:YES];
    } else if (indexPath.section == 2) {
        
        /*
        TwitterLoginController *loginController = [[TwitterLoginController new] autorelease];
        loginController.delegate = self;
        [loginController presentFromController:self];
        return;
         */
        
        NSURL *url;
        if (indexPath.row == 0) {
            url = [NSURL URLWithString:@"http://www.twitter.com/studyflashcards"];
        } else {
            // url = [NSURL URLWithString:@"http://touch.facebook.com/#/profile.php?id=103326416386141"];
            url = [NSURL URLWithString:@"http://www.facebook.com/pages/FlashCards-for-iPhone/103326416386141"];
        }
        NSIndexPath* selection = [tableView indexPathForSelectedRow];
        if (selection) {
            [tableView deselectRowAtIndexPath:selection animated:YES];
        }
        [[UIApplication sharedApplication] openURL:url];
        return;
    } else if (indexPath.section == 3) {
        // tell a friend
                
        [FlashCardsCore shareWithEmail:self];
    }
}

# pragma mark -
# pragma mark MFMailComposeViewControllerDelegate functions

- (void)mailComposeController:(MFMailComposeViewController*)controller  
          didFinishWithResult:(MFMailComposeResult)result 
                        error:(NSError*)error;
{
    if (result == MFMailComposeResultSent) {
    //    NSLog(@"It's away!");
    } else if (result == MFMailComposeResultFailed) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"Error", @"Error", @"UIAlert title")
                                                         message:[NSString stringWithFormat:NSLocalizedStringFromTable(@"An error occurred sending your message: %@ %@", @"Error", @"message"), error, [error userInfo]]
                                                        delegate:nil
                                               cancelButtonTitle:NSLocalizedStringFromTable(@"OK", @"FlashCards", @"cancelButtonTitle")
                                               otherButtonTitles:nil];
        [alert show];
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}



#pragma mark -
#pragma mark Memory management

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Relinquish ownership any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
    // Relinquish ownership of anything that can be recreated in viewDidLoad or on demand.
    // For example: self.myOutlet = nil;
    faq = nil;
}




@end

