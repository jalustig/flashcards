/*
 *  Constants.h
 *  FlashCards
 *
 *  Created by Jason Lustig on 6/10/10.
 *  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
 *
 */

#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
#define FCColor UIColor
#else
#define FCColor NSColor
#endif

#define kInAppPurchaseProUpgrade3Months @"com.iphoneflashcards.fcpp.subscription.3months"
#define kInAppPurchaseProUpgrade6Months @"com.iphoneflashcards.fcpp.subscription.6months"
#define kInAppPurchaseProUpgrade12Months @"com.iphoneflashcards.fcpp.subscription.12months"
#define kInAppPurchaseProUpgradeLifetime @"com.iphoneflashcards.fcpp.subscription.Lifetime"

#define kInAppPurchaseProUpgradeTeachers10 @"com.iphoneflashcards.fcpp.subscription.Teachers10"
#define kInAppPurchaseProUpgradeTeachers25 @"com.iphoneflashcards.fcpp.subscription.Teachers25"
#define kInAppPurchaseProUpgradeTeachers100 @"com.iphoneflashcards.fcpp.subscription.Teachers100"

extern NSString * const AppBundleIdentifier;
extern NSString * const AppBundleVersion;

extern NSString * const appTintColor;

extern NSString *whatsNewInThisVersion;

extern int const AppStoreId;

extern NSString * const flurryApplicationKey;

extern int const maxCardsLite;

extern int const chunkUploadSize;

extern float const firstVersionWithFreeDownload;

extern NSString * const flashcardsServer;
extern NSString * const flashcardsServerApiKey;
extern NSString * const flashcardsServerSecondaryKeyEncryptionKey;
extern NSString * const flashcardsServerCallKeyEncryptionKey;
extern NSString * const flashcardsQuizletAction;

// as per http://stackoverflow.com/questions/753755/using-a-constant-nsstring-as-the-key-for-nsuserdefaults
extern NSString * const quizletApiKey;
extern NSString * const quizletClientID;
extern NSString * const quizletAuthenticationSecretKey;
extern NSString * const quizletApiRedirectUri;

extern NSString * const dropboxApiConsumerKey;
extern NSString * const dropboxApiConsumerSecret;
extern NSString * const contactEmailAddress;

extern int const kMaxFileSize;
extern float const kMaxFieldHeight;

extern int const kCellImageViewTag;
extern int const kCellLabelTag;

extern int const mergeCardCurrent;
extern int const mergeCardNew;
extern int const mergeCardEdit;

// List of whether or not to merge cards
extern int const mergeCardsChoice;
extern int const mergeAndEditCardsChoice;
extern int const dontMergeCardsChoice;

extern int const modeEdit;
extern int const modeCreate;

extern double const minEFactor;
extern double const maxEFactor;
extern double const defaultEFactor;
extern double const minOptimalFactor;
extern double const maxOptimalFactor;

// List of word types -- whether it is a "normal" word, a cognate, or a false cognate:
extern int const wordTypeNormal;
extern int const wordTypeCognate;
extern int const wordTypeFalseCognate;

// List of parts of speech:
extern int const partOfSpeechUndefined;
extern int const partOfSpeechNoun;
extern int const partOfSpeechVerb;
extern int const partOfSpeechModifier;
extern int const partOfSpeechPreposition;

// list of word genders:
extern int const wordGenderNone;
extern int const wordGenderMale;
extern int const wordGenderFemale;
extern int const wordGenderNeuter;

// List of study algorithms:
extern int const studyAlgorithmLearn;
extern int const studyAlgorithmTest;
extern int const studyAlgorithmRepetition;
extern int const studyAlgorithmLapsed;

// List of study orders:
extern int const studyOrderLinear;
extern int const studyOrderRandom;
extern int const studyOrderSmart;
extern int const studyOrderCustom;

// List of "show which side first?" options
extern int const showFirstSideFront;
extern int const showFirstSideBack;
extern int const showFirstSideRandom;

// List of "which cards to study?" options
extern int const selectCardsRandom;
extern int const selectCardsHardest;
extern int const selectCardsNewest;

// List of "browse mode" options
extern int const studyBrowseModeManual;
extern int const studyBrowseModeAutoBrowse;
extern int const studyBrowseModeAutoAudio;

// List of Cards Studied By X modes:
extern int const cardsStudiedByDay;
extern int const cardsStudiedByWeek;
extern int const cardsStudiedByMonth;

// List of options for card justification:
extern int const justifyCardLeft;
extern int const justifyCardCenter;
extern int const justifyCardRight;

// List of options for text size:
extern int const sizeExtraLarge;
extern int const sizeLarge;
extern int const sizeNormal;
extern int const sizeSmall;
extern int const sizeExtraExtraLarge;
extern int const sizeExtraSmall;
extern int const sizeExtraExtraSmall;

// List of potential sync states for objects.
extern int const syncNoChange;
extern int const syncChanged; // can be either edited or created depending on if the object has a Quizlet ID or not.
extern int const syncTemporary; // can be purged

#pragma mark -
#pragma mark PluralForm

NSString* FCPluralLocalizedStringInBundle (NSString *key, NSString* table, NSNumber *number, NSString* comment);
NSString* FCPluralLocalizedStringFromTable (NSString* key, NSString* table, NSString* comment, NSNumber *number);

#pragma mark -
#pragma mark UIALert functions
void FCDisplayBasicErrorMessage(NSString* title, NSString* message);

#pragma mark -
#pragma mark NSLog overrid
extern void FCLog (NSString *format, ...);

#pragma mark -
#pragma mark Core Data functions
NSString* coreDataId(NSManagedObject* object);

NSNumber* fc_CPTDecimalFromFloat(float i);
NSNumber* fc_CPTDecimalFromDouble(double i);