//
//  ImportCSV.h
//  FlashCards
//
//  Created by Jason Lustig on 4/5/11.
//  Copyright 2011-2014 Jason Lustig Lustig. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ImportSet;
@class ImportCard;
@class ASIFormDataRequest;
@protocol ImportCSVDelegate;
@protocol DBRestClientDelegate;

// Error codes in the dropbox.com domain represent the HTTP status code if less than 1000
enum {
    kCSVErrorNoFileUploaded = 100,
    kCSVErrorFileSizeExceeded = 101,
    kCSVErrorFileTooLarge = 200,
    kCSVErrorFileType = 300,
    kCSVErrorServerCannotReadFile = 400,
    kCSVErrorServerCannotWriteFile = 500,
    kCSVErrorNoInternetConnection = 90,
    kCSVErrorEmptyCSVDataDownloadedFromServer = 92,
    kCSVErrorFileNotFound,
};


@interface ImportCSV : NSObject <DBRestClientDelegate> {
    ImportSet *cardSet;
    NSString *csvString;
    NSString *localFilePath;
    NSString *dropboxFilePath;
    NSString *dropboxFileName;

    DBRestClient *restClient;

    ASIFormDataRequest *request;

    NSURLConnection *theConnection;
    NSMutableData *receivedData;
    bool connectionIsLoading;
    
    id<ImportCSVDelegate> __weak delegate;

}

- (void)processLocalFile;
- (void)parseCSVFile;
- (NSMutableDictionary*) convertToFlashCardsFormat;

@property (nonatomic, strong) ImportSet *cardSet;
@property (nonatomic, strong) NSString *csvString;
@property (nonatomic, strong) NSString *localFilePath;
@property (nonatomic, strong) NSString *dropboxFilePath;
@property (nonatomic, strong) NSString *dropboxFileName;

@property (nonatomic, strong) DBRestClient *restClient;

@property (nonatomic, strong) ASIFormDataRequest *request;

@property (nonatomic, strong) NSURLConnection *theConnection;
@property (nonatomic, strong) NSMutableData *receivedData;
@property (nonatomic, assign) bool connectionIsLoading;

@property (nonatomic, weak) id<ImportCSVDelegate> delegate;

@end

/* The delegate provides allows the user to get the result of the calls made on the DBRestClient.
 Right now, the error parameter of failed calls may be nil and [error localizedDescription] does
 not contain an error message appropriate to show to the user. */
@protocol ImportCSVDelegate <NSObject>

@optional

- (void)csvFileDidLoad:(ImportCSV*)importCSV;
- (void)importClient:(ImportCSV*)importCSV csvFileLoadFailedWithError:(NSError*)error;

@end

