//
//  Constants.m
//  FlashCards
//
//  Created by Jason Lustig on 6/10/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import "Constants.h"

// *************************************

NSString *whatsNewInThisVersion =
@" - Text-to-speech improvements: FlashCards++ can now read cards of arbirtrary length, and speaking speed is more natural.\n"
@" - Resolved an issue where it was impossible to edit cards which contained a large amount of text.\n"
@" - Resolved iOS 9 compatability issues\n"
@" - A note from the developer: Unfortunately, Cram.com has discontinued support for third-party apps. As a result, I have removed integration with Cram.  (The Cram functionality would stop working either way, because they have disabled their API. I have made it so that the app will continue to work properly without this API, which would cause some issues for people who had cards syncing with Cram.com.)\n"

@" - Improvements to make the app faster\n"
@"\n"
@"\n"
@"**What's New in FlashCards++ 5.9:**\n"
@"\n"
@" - You can now create beautiful math & chemistry flash cards using the Latex formatting method. To turn it on, go to your collection (top level group) and select 'Math' or 'Chemistry' as the language for the appropriate side of the card. Put math between `$` and `$`. You can read much more about it in the FAQ, but here's a taste of what can be done:\n"
@"\n"
@"<small>`$ area = \\pi r^2 $`</small>\n"
@"$ \\to area = \\pi r^2 $\n"
@"\n"
@"<small>`$ x = {{-b \\pm \\sqrt{b^2-4ac}} \\over 2a} $`</small>\n"
@"$ \\to x = {{-b \\pm \\sqrt{b^2-4ac}} \\over 2a} $\n"
@"\n"
@"`$ \\int_a^b f(x)\\,dx $`\n"
@"$ \\to \\int_a^b f(x)\\,dx $\n"
@"\n"

@"<small><code>&#36; z = \\overbrace{<br>"
@"\\underbrace{x}_\\text{real} +<br>"
@"\\underbrace{iy}_\\text{imaginary}<br>"
@"}^\\text{complex number} &#36;</code></small>\n"

@"$ \\to z = \\overbrace{\n"
@"\\underbrace{x}_\\text{real} +\n"
@"\\underbrace{iy}_\\text{imaginary}\n"
@"}^\\text{complex number} $\n"
@"\n"
@"<small><code>&#36; f(x) = \\left\\{<br>"
@"&nbsp;&nbsp;\\begin{array}{lr}<br>"
@"&nbsp;&nbsp;&nbsp;&nbsp;x^2 & : x < 0 \\\\<br>"
@"&nbsp;&nbsp;&nbsp;&nbsp;x^3 & : x \\ge 0<br>"
@"&nbsp;&nbsp;\\end{array}<br>"
@"\\right.&#36;</code></small>\n"

@"$ \\to f(x) = \\left\\{\n"
@"  \\begin{array}{lr}\n"
@"    x^2 & : x < 0 \\\\ \n"
@"    x^3 & : x \\ge 0\n"
@"  \\end{array}\n"
@"\\right.$\n"
@"\n"
@"\n"
@" ... in other news:\n"
@"\n"
@" - Text-to-speech can now handle long cards (i.e. longer than 100 characters)\n"
@" - Resolved some crashes\n"
@" - Resolved an issue where auto-browse would stop at the end of a study round\n"
@" - Improved automatic sync\n"
@" - Resolved an issue when creating multiple cards on the iPad\n";

// *************************************

NSString * const AppBundleIdentifier = @"com.iphoneFlashCards.FlashCards";
NSString * const AppBundleVersion = @"1124";

NSString * const appTintColor = @"e08301";

int const AppStoreId = 378786877;

NSString * const flurryApplicationKey = @"SECRET";

int const maxCardsLite = 150;

int const chunkUploadSize = 1024 * 100;

float const firstVersionWithFreeDownload = 5.5f;

NSString * const flashcardsServer = @"SECRET";
NSString * const flashcardsServerApiKey = @"SECRET";
NSString * const flashcardsServerSecondaryKeyEncryptionKey = @"SECRET";
NSString * const flashcardsServerCallKeyEncryptionKey = @"SECRET";
NSString * const flashcardsQuizletAction = @"quizlet"; // http://api.iphoneflashcards.com/quizlet/asdf
// quizlet - live
// quizlettwo - testing

// as per http://stackoverflow.com/questions/753755/using-a-constant-nsstring-as-the-key-for-nsuserdefaults
NSString * const quizletApiKey = @"SECRET";
NSString * const quizletClientID = @"SECRET";
NSString * const quizletAuthenticationSecretKey = @"SECRET";
NSString * const quizletApiRedirectUri = @"fcpp://quizletauthorized";

NSString * const dropboxApiConsumerKey = @"SECRET";
NSString * const dropboxApiConsumerSecret = @"SECRET";

NSString * const contactEmailAddress = @"oldemail@gmail.com";

int const kMaxFileSize = 7.8 * 1024 * 1024;
float const kMaxFieldHeight = 9999.0f;

int const kCellImageViewTag    = 1000;
int const kCellLabelTag = 1001;

int const mergeCardCurrent = -1;
int const mergeCardNew = 1;
int const mergeCardEdit = 2;

// List of whether or not to merge cards
int const mergeCardsChoice = 0;
int const mergeAndEditCardsChoice = 1;
int const dontMergeCardsChoice = 2;

// List of edit/create modes:
int const modeEdit = 0;
int const modeCreate = 1;

// Min/max eFactors
double const minEFactor = 1.2;
double const maxEFactor = 2.5;
double const defaultEFactor = 2.3;
double const minOptimalFactor = 1.2;
double const maxOptimalFactor = 5.0;

// List of word types -- whether it is a "normal" word, a cognate, or a false cognate:
int const wordTypeNormal = 0;
int const wordTypeCognate = 1;
int const wordTypeFalseCognate = 2;

// List of parts of speech:
int const partOfSpeechUndefined = 0;
int const partOfSpeechNoun = 1;
int const partOfSpeechVerb = 2;
int const partOfSpeechModifier = 3;
int const partOfSpeechPreposition = 4;

// List of word genders:
int const wordGenderNone = 0;
int const wordGenderMale = 1;
int const wordGenderFemale = 2;
int const wordGenderNeuter = 3;


// List of study algorithms:
int const studyAlgorithmLearn = 0;
int const studyAlgorithmTest = 3;
int const studyAlgorithmRepetition = 4;
int const studyAlgorithmLapsed = 5;

// List of study orders:
int const studyOrderLinear = 0;
int const studyOrderRandom = 1;
int const studyOrderSmart = 2;
int const studyOrderCustom = 3;

// List of "show which side first?" options
int const showFirstSideFront = 0;
int const showFirstSideBack = 1;
int const showFirstSideRandom = 2;

// List of "which cards to study?" options
int const selectCardsRandom = 0;
int const selectCardsHardest = 1;
int const selectCardsNewest = 2;

// List of "browse mode" options
int const studyBrowseModeManual = 0;
int const studyBrowseModeAutoBrowse = 1;
int const studyBrowseModeAutoAudio = 2;

// List of Cards Studied By X modes:
int const cardsStudiedByDay = 0;
int const cardsStudiedByWeek = 1;
int const cardsStudiedByMonth = 2;

// List of options for card justification:
int const justifyCardLeft = 0;
int const justifyCardCenter = 1;
int const justifyCardRight = 2;

// List of options for text size:
int const sizeExtraLarge = 0;
int const sizeLarge = 1;
int const sizeNormal = 2;
int const sizeSmall = 3;
int const sizeExtraExtraLarge = 4;
int const sizeExtraSmall = 5;
int const sizeExtraExtraSmall = 6;

int const syncNoChange = 0;
int const syncChanged = 1; // can be either edited or created depending on if the object has a Quizlet ID or not.
int const syncTemporary = 2; // can be purged

#pragma mark -
#pragma mark PluralForm

// for documentation of rules, see https://developer.mozilla.org/en/Localization_and_Plurals
NSString* FCPluralLocalizedStringInBundle (NSString *key, NSString* table, NSNumber *number, NSString* comment) {
    return FCPluralLocalizedStringFromTable(key, table, comment, number);
}
NSString* FCPluralLocalizedStringFromTable (NSString* key, NSString* table, NSString* comment, NSNumber *number) {
    // The process:
    // 1. For the current language, find out what rule set it should follow.
    // 2. For the current rule set, find out which sub-rule we should follow based on the number.
    // 3. Append the suffix for the rule to the key, and get it from the proper table using NSLocalizedStringFromTable
    
    /*
     NSArray* languages = [[NSUserDefaults standardUserDefaults] objectForKey:@"AppleLanguages"];
     for (int i = 0; i < [languages count]; i++) {
     NSLog(@"%@ - %@", [languages objectAtIndex:i], [[NSLocale currentLocale] displayNameForKey:NSLocaleIdentifier value:[languages objectAtIndex:i]]);
     }
     
     NSLog(@"current locale: %@", [[NSLocale currentLocale] localeIdentifier]);
     NSLog(@"Current language: %@", [[NSLocale preferredLanguages] objectAtIndex:0]);
     
     */
    
    // 1. For the current language, fund out which rule set we should follow.
    // as per: http://stackoverflow.com/questions/3910244/getting-current-device-language-in-ios/4221416#4221416
    NSString *currentLanguage = [[NSLocale preferredLanguages] objectAtIndex:0];
    int rule;
    if ([currentLanguage isEqual:@"ar"]) {
        // ar - Arabic
        rule = 12;
    } else if ([currentLanguage isEqual:@"ca"]) {
        // ca - Catalan
        rule = 1;
    } else if ([currentLanguage isEqual:@"cs"]) {
        // cs - Czech
        rule = 8;
    } else if ([currentLanguage isEqual:@"da"]) {
        // da - Danish
        rule = 1;
    } else if ([currentLanguage isEqual:@"de"]) {
        // de - German
        rule = 1;
    } else if ([currentLanguage isEqual:@"el"]) {
        // el - Greek
        rule = 1;
    } else if ([currentLanguage isEqual:@"en"]) {
        // en - English
        rule = 1;
    } else if ([currentLanguage isEqual:@"en-GB"]) {
        // en-GB - English (United Kingdom)
        rule = 1;
    } else if ([currentLanguage isEqual:@"fi"]) {
        // fi - Finnish
        rule = 1;
    } else if ([currentLanguage isEqual:@"fr"]) {
        // fr - French
        rule = 2;
    } else if ([currentLanguage isEqual:@"he"]) {
        // he - Hebrew
        rule = 1;
    } else if ([currentLanguage isEqual:@"hr"]) {
        // hr - Croatian
        rule = 7;
    } else if ([currentLanguage isEqual:@"hu"]) {
        // hu - Hungarian
        rule = 1;
    } else if ([currentLanguage isEqual:@"id"] && NO) {
        // id - Indonesian
        // N.b. there doesn't seem to be a parallel in the Mozilla rules.
        rule = 1;
    } else if ([currentLanguage isEqual:@"it"]) {
        // it - Italian
        rule = 1;
    } else if ([currentLanguage isEqual:@"ja"]) {
        // ja - Japanese
        rule = 0;
    } else if ([currentLanguage isEqual:@"ko"]) {
        // ko - Korean
        rule = 0;
    } else if ([currentLanguage isEqual:@"nl"]) {
        // nl - Dutch
        rule = 1;
    } else if ([currentLanguage isEqual:@"pt"]) {
        // pt - Portuguese
        rule = 1;
    } else if ([currentLanguage isEqual:@"pt-PT"]) {
        // pt-PT - Portuguese (Portugal)
        rule = 1;
    } else if ([currentLanguage isEqual:@"nb"]) {
        // nb - Norwegian Bokmål
        rule = 1;
    } else if ([currentLanguage isEqual:@"pl"]) {
        // pl - Polish
        rule = 9;
    } else if ([currentLanguage isEqual:@"ro"]) {
        // ro - Romanian
        rule = 5;
    } else if ([currentLanguage isEqual:@"ru"]) {
        // ru - Russian
        rule = 7;
    } else if ([currentLanguage isEqual:@"sl"]) {
        // sk - Slovak
        rule = 8;
    } else if ([currentLanguage isEqual:@"sv"]) {
        // sv - Swedish
        rule = 1;
    } else if ([currentLanguage isEqual:@"th"]) {
        // th - Thai
        rule = 0;
    } else if ([currentLanguage isEqual:@"tr"]) {
        // tr - Turkish
        rule = 0;
    } else if ([currentLanguage isEqual:@"uk"]) {
        // uk - Ukrainian
        rule = 7;
    } else if ([currentLanguage isEqual:@"vi"]) {
        // vi - Vietnamese
        rule = 0;
    } else if ([currentLanguage isEqual:@"zh-Hans"]) {
        // zh-Hans - Chinese (Simplified Han)
        rule = 0;
    } else if ([currentLanguage isEqual:@"zh-Hant"]) {
        // zh-Hant - Chinese (Traditional Han)
        rule = 0;
    } else {
        rule = 1; // default
    }
    
    // 2. For the current rule set, find out which sub-rule we should follow based on the number.
    // as per http://mxr.mozilla.org/mozilla2.0/source/intl/locale/src/PluralForm.jsm#70
    int subrule;
    int n = [number intValue];
    switch (rule) {
            // 0: Chinese
        case 0: subrule = 0; break;
            
            // 1: English
        default:
        case 1: subrule = n!=1?1:0; break;
            
            // 2: French
        case 2: subrule = n>1?1:0; break;
            
            // 3: Latvian
        case 3: subrule = n%10==1&&n%100!=11?1:n!=0?2:0; break;
            
            // 4: Scottish Gaelic
        case 4: subrule = n==1||n==11?0:n==2||n==12?1:n>0&&n<20?2:3; break;
            
            // 5: Romanian
        case 5: subrule = n==1?0:n==0||(n%100>0&&n%100<20)?1:2; break;
            
            // 6: Lithuanian
        case 6: subrule = n%10==1&&n%100!=11?0:n%10>=2&&(n%100<10||n%100>=20)?2:1; break;
            
            // 7: Russian
        case 7: subrule = n%10==1&&n%100!=11?0:n%10>=2&&n%10<=4&&(n%100<10||n%100>=20)?1:2; break;
            
            // 8: Slovak
        case 8: subrule = n==1?0:n>=2&&n<=4?1:2; break;
            
            // 9: Polish
        case 9: subrule = n==1?0:n%10>=2&&n%10<=4&&(n%100<10||n%100>=20)?1:2; break;
            
            // 10: Slovenian
        case 10: subrule = n%100==1?0:n%100==2?1:n%100==3||n%100==4?2:3; break;
            
            // 11: Irish Gaeilge
        case 11: subrule = n==1?0:n==2?1:n>=3&&n<=6?2:n>=7&&n<=10?3:4; break;
            
            // 12: Arabic
        case 12: subrule = n==0?5:n==1?0:n==2?1:n%100>=3&&n%100<=10?2:n%100>=11&&n%100<=99?3:4; break;
            
            // 13: Maltese
        case 13: subrule = n==1?0:n==0||(n%100>0&&n%100<=10)?1:n%100>10&&n%100<20?2:3;
            
            // 14: Macedonian
        case 14: subrule = n%10==1?0:n%10==2?1:2;
            
            // 15: Icelandic
        case 15: subrule = n%10==1&&n%100!=11?0:1; break;
    }
    
    // 3. Append the suffix for the rule to the key, and get it from the proper table using NSLocalizedStringFromTable
    NSString *finalKey = [NSString stringWithFormat:@"%@;%d", key, subrule];
    // NSLog(@"\n");
    // NSLog(@"n: %d", n);
    // NSLog(@"rule: %d; subrule: %d", rule, subrule);
    // NSLog(@"final key: %@", finalKey);
    return NSLocalizedStringFromTable(finalKey, table,  @"");
}

# pragma mark -
# pragma mark UIAlert functions

void FCDisplayBasicErrorMessage(NSString* title, NSString* message) {
    if (![[NSThread currentThread] isMainThread]) {
        // as per: http://stackoverflow.com/questions/5662360/gcd-to-perform-task-in-main-thread
        dispatch_sync(dispatch_get_main_queue(), ^{
            FCDisplayBasicErrorMessage(title, message);
        });
        
        return;
    }
#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title
                                                     message:message
                                                    delegate:nil
                                           cancelButtonTitle:NSLocalizedStringFromTable(@"OK", @"FlashCards", @"cancelButtonTitle")
                                           otherButtonTitles:nil];
    [alert show];
#else
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert addButtonWithTitle:NSLocalizedStringFromTable(@"OK", @"FlashCards", @"cancelButtonTitle")];
    [alert setMessageText:title];
    [alert setInformativeText:message];
    [alert setAlertStyle:NSWarningAlertStyle];
    [alert runModal];
#endif
}

void FCLog(NSString *format, ...) {
#ifdef DEBUG
    if (format == nil) {
        printf("nil\n");
        return;
    }
    // Get a reference to the arguments that follow the format parameter
    va_list argList;
    va_start(argList, format);
    // Perform format string argument substitution, reinstate %% escapes, then print
    NSMutableString *s = [[NSMutableString alloc] initWithFormat:format arguments:argList];
    [s replaceOccurrencesOfString:@"%%"
                       withString:@"%%%%"
                          options:0
                            range:NSMakeRange(0, [s length])];
    printf("%s\n", [s UTF8String]);
    va_end(argList);
#endif
}

# pragma mark -
# pragma mark Core Data functions
NSString* coreDataId(NSManagedObject* object) {
    int coreDataLength = [@"x-coredata://73ED2084-08A8-45BD-89B0-BFCA2178CDD1/Card/" length];
    NSString *dataId = [[[object objectID] URIRepresentation] absoluteString];
    // NSLog(@"%@", dataId);
    dataId = [dataId substringFromIndex:coreDataLength];
    // NSLog(@"%@", dataId);
    return dataId;
}

NSNumber* fc_CPTDecimalFromFloat(float i) {
    return [NSNumber numberWithFloat:i];
}

NSNumber* fc_CPTDecimalFromDouble(double i) {
    return [NSNumber numberWithDouble:i];
}
