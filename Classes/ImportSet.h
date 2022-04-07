//
//  ImportSet.h
//  FlashCards
//
//  Created by Jason Lustig on 3/16/11.
//  Copyright 2011-2014 Jason Lustig Lustig. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol ImportSetDelegate;
@class FCCardSet;

@interface ImportSet : NSObject {
    
    int cardSetId;
    
    BOOL willSubscribe;
    BOOL willSync;

    NSString *name;
    NSString *description;
    NSMutableArray *tags;

    NSString *creator;
    NSDate *creationDate;
    NSDate *modifiedDate;

    bool hasImages;
    bool isPrivateSet;
    NSMutableArray *flashCards;
    int _numberCards;
    bool userCanEditOnline;
    
    NSString *password;
    NSString *editable;
    
    int cardSetCreateMode;
    bool matchCardSetChecked;
    NSManagedObjectID *matchCardSetId; // if there is a set with the same name
    
    bool imagesDownloaded;
    bool duplicatesChecked;
    bool isSaved;
    bool isFiltered;
    
    BOOL reverseFrontAndBackOfCards;
    
    NSString *frontLanguage;
    NSString *backLanguage;
    
    NSString *importMethod;
    
    id<ImportSetDelegate> __weak delegate;
    
}

+ (NSMutableArray*) convertFCPPFileFormat:(NSDictionary*)fileData;

- (id) initWithQuizletData:(NSDictionary*)setData;
- (id) initWithDatafile:(NSDictionary*)setData;
- (void)setNumberCards:(int)num;
- (int)numberCards;
- (void)downloadImages;

- (void) setMatchCardSet:(FCCardSet*)match;
- (FCCardSet*)matchCardSetInMOC:(NSManagedObjectContext*)moc;

@property (nonatomic, assign) int cardSetId;

@property (nonatomic, assign) BOOL willSubscribe;
@property (nonatomic, assign) BOOL willSync;

@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *description;
@property (nonatomic, strong) NSMutableArray *tags;

@property (nonatomic, strong) NSString *creator;
@property (nonatomic, strong) NSDate *creationDate;
@property (nonatomic, strong) NSDate *modifiedDate;
@property (nonatomic, assign) int _numberCards;
@property (nonatomic, assign) bool userCanEditOnline;

@property (nonatomic, strong) NSString *password;
@property (nonatomic, strong) NSString *editable;


@property (nonatomic, assign) bool hasImages;
@property (nonatomic, assign) bool isPrivateSet;
@property (nonatomic, strong) NSMutableArray *flashCards;

@property (nonatomic, assign) int cardSetCreateMode;
@property (nonatomic, assign) bool matchCardSetChecked;
@property (nonatomic, strong) NSManagedObjectID *matchCardSetId; // if there is a set with the same name

@property (nonatomic, assign) bool imagesDownloaded;
@property (nonatomic, assign) bool duplicatesChecked;
@property (nonatomic, assign) bool isSaved;
@property (nonatomic, assign) bool isFiltered;

@property (nonatomic, assign) BOOL reverseFrontAndBackOfCards;

@property (nonatomic, strong) NSString *frontLanguage;
@property (nonatomic, strong) NSString *backLanguage;

@property (nonatomic, strong) NSString *importMethod;


@property (nonatomic, weak) id<ImportSetDelegate> delegate;

@end

@protocol ImportSetDelegate <NSObject>

@optional

- (void)imagesDidDownload:(ImportSet*)importSet;
- (void)importSet:(ImportSet*)importSet imageDownloadFailedWithError:(NSError*)error;

@end
