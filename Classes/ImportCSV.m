//
//  ImportCSV.m
//  FlashCards
//
//  Created by Jason Lustig on 4/5/11.
//  Copyright 2011-2014 Jason Lustig Lustig. All rights reserved.
//

#import "ImportCSV.h"

#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
#import "FlashCardsAppDelegate.h"
#endif

#import "ASIHTTPRequest.h"
#import "ASIFormDataRequest.h"
#import "CHCSVParser.h"
#import "NSData+textEncoding.h"
#import "JSONKit.h"

/*
 What is this class, ImportCSV? It is the beginning of a new system for importing
 flashcards to the app. First, a principle: This class is *not* utilized by 
 CardSetImportVC, i.e. it is utilized by the view controller *before* the one where
 the user can see the cards and import them, i.e. the view controller where the user
 *selects* the card set, such as DropboxCSVFilePicker or QuizletMySetsVC.
 
 There is a hierarchy of classes:
 0. The class which the user uses to select the card set. That class creates an
    ImportCSV class (or other Import* class), which it uses to download all of the card data.
    It then passes up an ImportSet class to CardSetImportVC, which can display the cards
    and allow the user to import them.
 1. ImportCSV (Import*) - This class does any and all heavy lifting, including:
    downloading data from servers, parsing data, etc. When data is parsed (or an error
    is found), it calls back to class #0, which is set as its delegate. This delegate
    function then takes the ImportSet class from this class, Import*, and passes it
    up to CardSetImportVC.
 2. ImportCSV (Import*) is also the delegate of two kinds:
    (a) DBRestClient, because the user is most likely downloading a CSV *from dropbox*.
    (b) NSURLConnection, because if the user is downloading an XSL file, it needs
        to be sent up to the server for parsing.
    If the DBRestClient functions find an error, this class will pass an error up
    to class #0. Then, class #0 will display an error message.
  
 In this fashion, the Import* classes will be completely abstracted away from the view
 controllers, allowing me to utilize them in a number of locations: (a) importing cards
 in the primary fashion; (b) importing cards from outside the program (i.e. from mail);
 and (c) potentially to allow the creation of a Mac app, since the business logic
 of importing is now separated more cleanly from the interfaces.

 Example Usage:
 
 #import "ImportSDK.h"
 
 void main() {
    ImportCSV *csv = [[ImportCSV alloc] init];
    [csv setDelegate:self];
    [csv loadCSVFileFromDropBox:@"/CardSet.xlsx"];
 }
 
 - (void)csvFileDidLoad:(ImportCSV *)importCSV {
    NSLog(@"%@", importCSV.cardSet.flashCards);
 }

 
 */
 

@implementation ImportCSV

@synthesize cardSet;
@synthesize localFilePath, dropboxFilePath, dropboxFileName, csvString;
@synthesize restClient, request;
@synthesize theConnection, receivedData, connectionIsLoading;
#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
@synthesize delegate;
#endif
+ (id) alloc {
    return [super alloc];
}
- (id) init {
    if ((self = [super init])) {
        cardSet = [[ImportSet alloc] init];
    }
    return self;
}


- (DBRestClient*)restClient {
    if (!restClient) {
        restClient = [[DBRestClient alloc] initWithSession:[DBSession sharedSession]];
        restClient.delegate = self;
    }
    return restClient;
}


# pragma -
# pragma Parsing functions

- (void)parseCSVFile {
    
    cardSet.name = dropboxFileName;
    
    // using usedEncoding forces CHCSVParser to check the data for which is the proper encoding for the file.
    NSArray *csvTerms;
    if (csvString) {
        csvTerms = [csvString CSVComponents];
    } else {
        NSData *data = [NSData dataWithContentsOfFile:localFilePath];
        NSStringEncoding encoding = [data textEncoding];
        NSString *string = [[NSString alloc] initWithData:data encoding:encoding];
        csvTerms = [string CSVComponents];
    }
    // [csvTerms retain];
    
    NSMutableArray *currentCSVTerm = [[NSMutableArray alloc] initWithCapacity:0];
    ImportTerm *currentTerm;
    for (int i = 0; i < [csvTerms count]; i++) {
        [currentCSVTerm removeAllObjects];
        currentCSVTerm = [csvTerms objectAtIndex:i];
        if ([currentCSVTerm count] < 2) {
            [currentCSVTerm addObject:@""];
        }
        NSString *front = [currentCSVTerm objectAtIndex:0];
        NSString *back  = [currentCSVTerm objectAtIndex:1];
        if ([front length] == 0 && [back length] == 0) {
            continue;
        }
        currentTerm = [[ImportTerm alloc] init];
        currentTerm.importOrder = i;
        currentTerm.importTermFrontValue = [currentCSVTerm objectAtIndex:0];
        currentTerm.importTermBackValue  = [currentCSVTerm objectAtIndex:1];
        if ([currentCSVTerm count] > 2) {
            if ([(NSString*)[currentCSVTerm objectAtIndex:2] length] > 0) {
                currentTerm.frontImageUrl = [currentCSVTerm objectAtIndex:2];
                cardSet.hasImages = YES;
            }
            if ([currentCSVTerm count] > 3) {
                if ([(NSString*)[currentCSVTerm objectAtIndex:3] length] > 0) {
                    currentTerm.backImageUrl = [currentCSVTerm objectAtIndex:3];
                    cardSet.hasImages = YES;
                }
            }
        }
        
        // currentTerm = [[NSArray alloc] initWithObjects:[currentJsonTerm objectAtIndex:0], [currentJsonTerm objectAtIndex:1], [NSNumber numberWithInt:i], nil];
        [[cardSet flashCards] addObject:currentTerm];
    }
    // [csvTerms release];

    if (delegate && [delegate respondsToSelector:@selector(csvFileDidLoad:)]) {
        [delegate csvFileDidLoad:self];
    }
}

- (NSMutableDictionary*) convertToFlashCardsFormat {
    
    NSData *data = [NSData dataWithContentsOfFile:localFilePath];
    NSStringEncoding encoding = [data textEncoding];
    NSString *string = [[NSString alloc] initWithData:data encoding:encoding];
    NSArray *csvTerms = [string CSVComponents];

    /*
     Documentation of file format:
     
     1. Main Dictionary (NSDictionary)
       - collection (NSDictionary, max 1 item)
         - name (string)
         - isLanguage (bool)
         - frontValueLanguage (string)
         - backValueLanguage (string)
       - cardSets (NSArray, no max # items). NB that 1 item = cardset; >1 item = collection.
         - name (string)
         - cards (NSArray) - lists the CardID for each card, referencing the "cards" dictionary.
       - cards (NSDictionary, no max # items)
         - CardID --> Dictionary:
           - fv -- frontValue (string)
           - bv -- backValue (string)
           - i -- hasImages (bool)
           - fid -- frontImageData (data)
           - bid -- backImageData (data)
           - wt -- wordType (int)
           - rcs -- relatedCards (NSSet). Includes CardID of any related cards.
     If cards are listed here which are not included in the main
     "cards" dictionary, then they will simply be ignored when importing
     the cards.
     */    
    
    NSString *name = @"Collection";
    
    NSMutableDictionary *fileData = [[NSMutableDictionary alloc] initWithCapacity:0];
    
    [fileData setObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
                         name, @"name",
                         [NSNumber numberWithBool:NO], @"isLanguage",
                         @"", @"frontValueLanguage",
                         @"", @"backValueLanguage",
                         nil
                         ]
                 forKey:@"collection"];
    [fileData setObject:[NSMutableArray arrayWithObjects:
                         [NSMutableDictionary dictionaryWithObjectsAndKeys:
                          name, @"name",
                          [NSMutableArray arrayWithCapacity:0], @"cards",
                          nil],
                         nil]
                 forKey:@"cardSets"];
    [fileData setObject:[NSMutableDictionary dictionaryWithCapacity:0] forKey:@"cards"];
    
    NSArray *currentCSVTerm;
    NSString *cardId;
    NSMutableDictionary *card;
    NSString *fv;
    NSString *bv;
    for (int i = 0; i < [csvTerms count]; i++) {
        currentCSVTerm = [csvTerms objectAtIndex:i];
        cardId = [NSString stringWithFormat:@"%d", i];
        if ([currentCSVTerm count] > 0) {
            fv = [currentCSVTerm objectAtIndex:0];
        } else {
            fv = @"";
        }
        if ([currentCSVTerm count] > 1) {
            bv = [currentCSVTerm objectAtIndex:1];
        } else {
            bv = @"";
        }
        card = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                fv, @"fv",
                bv, @"bv",
                [NSNumber numberWithBool:NO], @"i",
                [NSMutableData dataWithLength:0], @"fid",
                [NSMutableData dataWithLength:0], @"bid",
                [NSNumber numberWithInt:wordTypeNormal], @"wt",
                [NSMutableSet setWithCapacity:0], @"rcs",
                nil];
        [[fileData objectForKey:@"cards"] setObject:card forKey:cardId];
        [[[[fileData objectForKey:@"cardSets"] objectAtIndex:0] objectForKey:@"cards"] addObject:cardId];
        // no need to release, since [NSMutableDictionary dictionaryWithObjectsAndKeys:] CONTAINS autorelease!
        // [card release];
    }
    
    
    return fileData;
    
}

- (void)processLocalFile {
    // set up the file:
    NSArray *fileParts = [dropboxFilePath componentsSeparatedByString:@"/"];
    dropboxFileName = [fileParts lastObject];
    fileParts = [dropboxFileName componentsSeparatedByString:@"."];
    NSString *extension = [[fileParts lastObject] lowercaseString];
    if ([extension isEqualToString:@"csv"] || [extension isEqualToString:@"txt"]) {
        [self parseCSVFile];
    } else {

        // first, check if we are on the internet. If not, then throw an error:
        
#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
        if (![FlashCardsCore isConnectedToInternet]) {
            if (delegate && [delegate respondsToSelector:@selector(importClient:csvFileLoadFailedWithError:)]) {
                NSMutableDictionary* errorUserInfo = [NSMutableDictionary dictionaryWithCapacity:0];
                [errorUserInfo setObject:NSLocalizedStringFromTable(@"You are not connected to the internet.", @"Error", @"message") forKey:@"errorMessage"];
                NSError *error = [[NSError alloc] initWithDomain:@"iphoneflashcards.com"
                                                            code:kCSVErrorNoInternetConnection
                                                        userInfo:errorUserInfo];
                [delegate importClient:self csvFileLoadFailedWithError:error];
            }
            return;
        }    
#endif

        NSData *fileData = [NSData dataWithContentsOfFile:localFilePath];
        if ([fileData length] >= kMaxFileSize) {
            NSError *error = [[NSError alloc] initWithDomain:@"iphoneflashcards.com"
                                                        code:kCSVErrorFileSizeExceeded
                                                    userInfo:nil];
            [delegate importClient:self csvFileLoadFailedWithError:error];
        }
        
        // we are not dealing with a CSV file, but an excel file. Send it up to the server,
        // and then re-parse it here.
        
        NSString *url = [NSString stringWithFormat:@"http://%@/import", flashcardsServer];
        request = [ASIFormDataRequest requestWithURL:[NSURL URLWithString:url]];
        __block ASIFormDataRequest *requestBlock = request;
        [request setupFlashCardsAuthentication:@"import"];
        [request addData:fileData withFileName:dropboxFileName andContentType:@"application/octet-stream" forKey:@"spreadsheet"];
        [request setDelegate:nil];

        __block ImportCSV *selfBlock = self;

        [request setFailedBlock:^{
            if (selfBlock.delegate && [selfBlock.delegate respondsToSelector:@selector(importClient:csvFileLoadFailedWithError:)]) {
                [selfBlock.delegate importClient:selfBlock csvFileLoadFailedWithError:[requestBlock error]];
            }
        }];
        
        [request setCompletionBlock:^{
            NSLog(@"Response: %@", requestBlock.responseString);

            NSString *receivedJson = [[NSString alloc] initWithData:[requestBlock responseData]
                                                           encoding:NSUTF8StringEncoding];
            NSLog(@"%@", [requestBlock responseString]);
            NSDictionary *parsedJson = [receivedJson objectFromJSONString];
            if (!parsedJson) {
                if (selfBlock.delegate && [selfBlock.delegate respondsToSelector:@selector(importClient:csvFileLoadFailedWithError:)]) {
                    NSMutableDictionary* errorUserInfo = [NSMutableDictionary dictionaryWithCapacity:0];
                    NSError *error = [[NSError alloc] initWithDomain:@"iphoneflashcards.com"
                                                                code:kFCErrorJsonParseError
                                                            userInfo:errorUserInfo];
                    [selfBlock.delegate importClient:selfBlock csvFileLoadFailedWithError:error];
                }
                return;
            }
            if ([[parsedJson valueForKey:@"response_type"] isEqualToString:@"ok"]) {
                
                NSString *fileData = (NSString*)[[parsedJson objectForKey:@"results"] valueForKey:@"file_data"];
                if ([fileData hasPrefix:@"\ufeff"]) {
                    //    fileData = [fileData substringFromIndex:[@"\ufeff" length]];
                }
                if ([fileData length] == 0) {
                    if (selfBlock.delegate && [selfBlock.delegate respondsToSelector:@selector(importClient:csvFileLoadFailedWithError:)]) {
                        NSMutableDictionary* errorUserInfo = [NSMutableDictionary dictionaryWithCapacity:0];
                        [errorUserInfo setObject:NSLocalizedStringFromTable(@"Error: the file was empty.", @"Error", @"message") forKey:@"errorMessage"];
                        NSError *error = [[NSError alloc] initWithDomain:@"iphoneflashcards.com"
                                                                    code:kCSVErrorEmptyCSVDataDownloadedFromServer
                                                                userInfo:errorUserInfo];
                        [selfBlock.delegate importClient:selfBlock csvFileLoadFailedWithError:error];
                    }
                    return;
                }
                csvString = fileData;
                
                localFilePath = [[FlashCardsCore documentsDirectory] stringByAppendingPathComponent:@"temp2.csv"];
                [csvString writeToFile:localFilePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
                // [[NSData dataWithBase64EncodedString:csvString] writeToFile:localFilePath atomically:YES];
                
                [selfBlock parseCSVFile];
                
            } else {
                if (selfBlock.delegate && [selfBlock.delegate respondsToSelector:@selector(importClient:csvFileLoadFailedWithError:)]) {
                    NSMutableDictionary* errorUserInfo = [NSMutableDictionary dictionaryWithCapacity:0];
                    if ([parsedJson valueForKey:@"short_text"]) {
                        [errorUserInfo setObject:[parsedJson valueForKey:@"short_text"] forKey:@"errorMessage"];
                    }
                    NSError *error = [[NSError alloc] initWithDomain:@"iphoneflashcards.com" code:[[parsedJson valueForKey:@"error_number"] intValue] userInfo:errorUserInfo];
                    [selfBlock.delegate importClient:selfBlock csvFileLoadFailedWithError:error];
                }
                return;
            }
        }];
        
        [request startAsynchronous];
    }
    
}


@end
