//
//  FCRestClient.m
//  FlashCards
//
//  Created by Jason Lustig on 3/16/11.
//  Copyright 2011-2014 Jason Lustig Lustig. All rights reserved.
//

#import "FCRestClient.h"
#import "FCRequest.h"

#import "FCCollection.h"
#import "FCCardSet.h"

@implementation FCRestClient

- (id)init {
    if ((self = [super init])) {
        requests = [[NSMutableSet alloc] initWithCapacity:0];
        isCanceled = NO;
    }
    return self;
}

- (void)dealloc {
    for (FCRequest* request in requests) {
        [request cancel];
    }
}

@synthesize delegate;
@synthesize isCanceled;

- (void)cancelLastRequest {
    if ([[requests allObjects] count] == 0) {
        return;
    }
    [[[requests allObjects] lastObject] cancel];
    [requests removeObject:[[requests allObjects] lastObject]];
}

- (void)cancelAllRequests {
    FCRequest *request;
    while ([[requests allObjects] count] > 0) {
        request = [[requests allObjects] lastObject];
        [request.request setDelegate:nil];
        [request cancel];
        [requests removeObject:[[requests allObjects] lastObject]];
    }
}


# pragma mark -
# pragma mark empty functions:

- (void)reportFunctionNotImplementedWithSelector:(SEL)errorSelector {
    if (delegate && [delegate respondsToSelector:errorSelector]) {
        NSError *error = [[NSError alloc] initWithDomain:@"www.iphoneflashcards.com"
                                                    code:kFCErrorFunctionNotImplemented
                                                userInfo:nil];
        [delegate performSelector:errorSelector withObject:self withObject:error]; 
    }
}

/* Loads user's card sets */
- (void)loadUserStudiedCardSetsList:(NSString*)_username withPage:(int)pageNumber {
    [self reportFunctionNotImplementedWithSelector:@selector(restClient:loadUserCardSetsListFailedWithError:)];
}
- (void)loadUserSavedCardSetsList:(NSString*)_username withPage:(int)pageNumber {
    [self reportFunctionNotImplementedWithSelector:@selector(restClient:loadUserCardSetsListFailedWithError:)];
}
- (void)loadUserCardSetsList:(NSString*)_username withPage:(int)pageNumber {
    [self reportFunctionNotImplementedWithSelector:@selector(restClient:loadUserCardSetsListFailedWithError:)];
}
- (void)loadUserCardSetsList:(NSString*)_username {
    [self reportFunctionNotImplementedWithSelector:@selector(restClient:loadUserCardSetsListFailedWithError:)];
}
- (void)requestDidLoadUserCardSetsList:(FCRequest*)request {}

/* loads a user's groups */
- (void)loadUserGroupsList:(NSString*)_username {
    [self reportFunctionNotImplementedWithSelector:@selector(restClient:loadUserGroupsListFailedWithError:)];
}
- (void) requestDidLoadUserGroupsList:(FCRequest*)request {}

/* loads the card sets in a group */
- (void)loadGroupCardSetsList:(ImportGroup*)group {
    [self reportFunctionNotImplementedWithSelector:@selector(restClient:loadGroupCardSetsListFailedWithError:)];
}
- (void)requestDidLoadGroupCardSetsList:(FCRequest*)request {}

/* joining and leaving groups */
- (void)joinGroup:(ImportGroup*)group withInput:(NSString*)input {
    [self reportFunctionNotImplementedWithSelector:@selector(restClient:joinGroupFailedWithError:)];
}
- (void)requestDidJoinGroup:(FCRequest*)request {}
- (void)leaveGroup:(ImportGroup*)group {
    [self reportFunctionNotImplementedWithSelector:@selector(restClient:leaveGroupFailedWithError:)];
}
- (void)requestDidLeaveGroup:(FCRequest*)request {}

/* searches for groups */
- (void)loadSearchGroupsList:(NSString*)searchTerm withPage:(int)pageNumber {
    [self reportFunctionNotImplementedWithSelector:@selector(restClient:loadSearchGroupsListFailedWithError:)];
}
- (void)requestDidLoadSearchGroupsList:(FCRequest*)request {}


/* Searches for card sets */
- (void)loadSearchCardSetsList:(NSString*)searchTerm withPage:(int)pageNumber withScope:(int)scope {
    [self reportFunctionNotImplementedWithSelector:@selector(restClient:loadSearchCardSetsListFailedWithError:)];
}
- (void)loadSearchCardSetsList:(NSString*)searchTerm withScope:(int)scope {
    [self reportFunctionNotImplementedWithSelector:@selector(restClient:loadSearchCardSetsListFailedWithError:)];
}
- (void)requestDidLoadSearchCardSetsList:(FCRequest*)request {}

/* Loads a particular card set */
- (void)loadCardSetCards:(int)cardSetId {
    [self reportFunctionNotImplementedWithSelector:@selector(restClient:loadCardSetCardsFailedWithError:)];
}
- (void)loadCardSetCards:(int)cardSetId withPassword:(NSString*)setPassword {
    [self reportFunctionNotImplementedWithSelector:@selector(restClient:loadCardSetCardsFailedWithError:)];
}
- (void)requestDidLoadCardSetCards:(FCRequest*)request {}

/* Loads multiple card sets */
- (void)loadMultipleCardSetCards:(NSArray*)cardSetIdArray {
    [self reportFunctionNotImplementedWithSelector:@selector(restClient:loadCardSetCardsFailedWithError:)];
}
- (void)requestDidLoadMultipleCardSetCards:(FCRequest*)request {}


/* Uploads a particular card set */
- (void)uploadCardSetWithName:(NSString*)setName
                    withCards:(NSArray *)setCards
                fromFCCardSet:(FCCardSet*)cardSet
             fromFCCollection:(FCCollection*)collection
                   shouldSync:(BOOL)shouldSync
                    isPrivate:(BOOL)isPrivate
                 isDiscussion:(BOOL)isDiscussion
                      toGroup:(int)groupId
            withFrontLanguage:(NSString *)frontLanguage
             withBackLanguage:(NSString *)backLanguage {}
- (void)requestDidUploadCardSet:(FCRequest*)request {}

@end
