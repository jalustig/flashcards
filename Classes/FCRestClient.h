//
//  FCRestClient.h
//  FlashCards
//
//  Created by Jason Lustig on 3/16/11.
//  Copyright 2011-2014 Jason Lustig Lustig. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol FCRestClientDelegate;
@class ImportGroup;
@class FCCollection;
@class FCCardSet;

// Error codes in the dropbox.com domain represent the HTTP status code if less than 1000
enum {
    kFCErrorFileNotFound,
    kFCErrorSetDoesNotExist = 5,
    kFCErrorUserDoesNotExist = 8,
    kFCErrorPrivateSet = 20,
    kFCErrorNoUsernameSupplied = 100,
    kFCErrorNoPasswordSupplied = 101,
    kFCErrorNoMessageSupplied = 102,
    kFCErrorNoSearchTermSupplied = 200,
    kFCErrorNoCardsetIdSupplied = 300,
    kFCErrorLoginNotValid = 500,
    kFCErrorLoginNotAvailable = 501,
    kFCErrorUserNotLoggedIn = 502,
    kFCErrorNoGroupIdSupplied = 600,
    kFCErrorGroupAccessOk = 601,
    kFCErrorGroupAccessPending = 602,
    kFCErrorGroupAccessInvited = 603,
    kFCErrorGroupAccessRemoved = 604,
    kFCErrorGroupLimitExceeded = 605,
    kFCErrorGroupRemovedOk = 650,
    kFCErrorGroupRemoveFailed = 651,
    kFCErrorPrivateSetWithPassword = 701,
    kFCErrorPrivateSetPasswordNotValid = 702,
    kFCErrorObjectDeleted = 703,
    kFCErrorObjectDoesNotExist = 704,
    kFCErrorAPIError = 800,
    kFCErrorJsonParseError = 900,
    kFCErrorGenericError = 1000,
    kFCErrorFunctionNotSupported = -1000,
    kFCErrorFunctionNotImplemented = -2000,
};

@class FCRequest;

@interface FCRestClient : NSObject {
    NSString* root;
    NSMutableSet* requests;
    BOOL isCanceled;
    id<FCRestClientDelegate> __weak delegate;
}

- (void)cancelLastRequest;
- (void)cancelAllRequests;

/* Loads user's card sets */
- (void)loadUserStudiedCardSetsList:(NSString*)_username withPage:(int)pageNumber;
- (void)loadUserSavedCardSetsList:(NSString*)_username withPage:(int)pageNumber;
- (void)loadUserCardSetsList:(NSString*)_username withPage:(int)pageNumber;
- (void)loadUserCardSetsList:(NSString*)_username;
- (void)requestDidLoadUserCardSetsList:(FCRequest*)request;

/* loads a user's groups */
- (void)loadUserGroupsList:(NSString*)_username;
- (void) requestDidLoadUserGroupsList:(FCRequest*)request;

/* loads the card sets in a group */
- (void)loadGroupCardSetsList:(ImportGroup*)group;
- (void)requestDidLoadGroupCardSetsList:(FCRequest*)request;

/* joining and leaving groups */
- (void)joinGroup:(ImportGroup*)group withInput:(NSString*)input;
- (void)requestDidJoinGroup:(FCRequest*)request;
- (void)leaveGroup:(ImportGroup*)group;
- (void)requestDidLeaveGroup:(FCRequest*)request;

/* searches for groups */
- (void)loadSearchGroupsList:(NSString*)searchTerm withPage:(int)pageNumber;
- (void)requestDidLoadSearchGroupsList:(FCRequest*)request;

/* Searches for card sets */
- (void)loadSearchCardSetsList:(NSString*)searchTerm withPage:(int)pageNumber withScope:(int)scope;
- (void)loadSearchCardSetsList:(NSString*)searchTerm withScope:(int)scope;
- (void)requestDidLoadSearchCardSetsList:(FCRequest*)request;

/* Loads a particular card set */
- (void)loadCardSetCards:(int)cardSetId;
- (void)loadCardSetCards:(int)cardSetId withPassword:(NSString*)setPassword;
- (void)requestDidLoadCardSetCards:(FCRequest*)request;

/* Loads multiple card sets */
- (void)loadMultipleCardSetCards:(NSArray*)cardSetIdArray;
- (void)requestDidLoadMultipleCardSetCards:(FCRequest*)request;



/* Uploads a particular card set */
- (void)uploadCardSetWithName:(NSString*)setName
                    withCards:(NSArray*)setCards
                fromFCCardSet:(FCCardSet*)cardSet
             fromFCCollection:(FCCollection*)collection
                   shouldSync:(BOOL)shouldSync
                    isPrivate:(BOOL)isPrivate
                 isDiscussion:(BOOL)isDiscussion
                      toGroup:(int)groupId
            withFrontLanguage:(NSString*)frontLanguage
             withBackLanguage:(NSString*)backLanguage;
- (void)requestDidUploadCardSet:(FCRequest*)request;

@property (nonatomic, weak) id<FCRestClientDelegate> delegate;
@property (nonatomic, assign) BOOL isCanceled;

@end


/* The delegate provides allows the user to get the result of the calls made on the DBRestClient.
 Right now, the error parameter of failed calls may be nil and [error localizedDescription] does
 not contain an error message appropriate to show to the user. */
@protocol FCRestClientDelegate <NSObject>

@optional

- (void)flashcardsServerAPINotAvailable:(FCRestClient*)client;

- (void)restClientDidLogin:(FCRestClient*)client;
- (void)restClient:(FCRestClient*)client loginFailedWithError:(NSError*)error;
- (void)restClient:(FCRestClient*)client loginSucceededWithUsername:(NSString*)username andWithPassword:(NSString*)password;

- (void)restClient:(FCRestClient*)client loadedUserCardSetsList:(NSMutableArray*)cardSets pageNumber:(int)pageNumber numberTotalSets:(int)numberTotalSets;
- (void)restClient:(FCRestClient*)client loadUserCardSetsListFailedWithError:(NSError*)error; 

- (void)restClient:(FCRestClient*)client loadedUserGroupsList:(NSMutableArray*)groups;
- (void)restClient:(FCRestClient*)client loadUserGroupsListFailedWithError:(NSError*)error;

- (void)restClient:(FCRestClient*)client loadedGroupCardSetsList:(NSMutableArray*)cardSets;
- (void)restClient:(FCRestClient*)client loadGroupCardSetsListFailedWithError:(NSError*)error;

- (void)restClient:(FCRestClient*)client joinedGroup:(ImportGroup*)group withCardSets:(NSMutableArray*)cardSets;
- (void)restClient:(FCRestClient*)client joinGroupFailedWithError:(NSError*)error;

- (void)restClient:(FCRestClient*)client leftGroup:(ImportGroup*)group;
- (void)restClient:(FCRestClient*)client leaveGroupFailedWithError:(NSError*)error;

- (void)restClient:(FCRestClient *)client loadedSearchGroupsList:(NSMutableArray*)groups pageNumber:(int)pageNumber numberTotalGroups:(int)numberTotalGroups;
- (void)restClient:(FCRestClient *)client loadSearchGroupsListFailedWithError:(NSError*)error;

- (void)restClient:(FCRestClient*)client loadedSearchCardSetsList:(NSMutableArray*)cardSets pageNumber:(int)pageNumber numberTotalSets:(int)numberTotalSets;
- (void)restClient:(FCRestClient*)client loadSearchCardSetsListFailedWithError:(NSError*)error;

- (void)restClient:(FCRestClient*)client loadedCardSetCards:(NSArray*)cards withImages:(BOOL)withImages frontLanguage:(NSString*)frontLanguage backLanguage:(NSString*)backLanguage;
- (void)restClient:(FCRestClient*)client loadCardSetCardsFailedWithError:(NSError*)error;

- (void)restClient:(FCRestClient*)client loadedMultipleCardSetCards:(NSArray*)cardSets;
- (void)restClient:(FCRestClient*)client loadMultipleCardSetCardsFailedWithError:(NSError*)error;

- (void)restClient:(FCRestClient*)client
uploadedCardSetWithName:(NSString*)setName
   withNumberCards:(int)numberCards
        shouldSync:(BOOL)shouldSync
         isPrivate:(BOOL)isPrivate
      isDiscussion:(BOOL)isDiscussion
       andFinalURL:(NSString*)finalURL;
- (void)restClient:(FCRestClient*)client uploadCardSetFailedWithError:(NSError*)error;

- (void)restClient:(FCRestClient*)client isUploadingImages:(BOOL)isUploadingImages;
- (void)restClient:(FCRestClient*)client isUploadingCards:(BOOL)isUploadingCards number:(int)number outOf:(int)total;

@end
