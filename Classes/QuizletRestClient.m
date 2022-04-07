//
//  DBRestClient.m
//  DropboxSDK
//
//  Created by Brian Smith on 4/9/10.
//  Copyright 2010 Dropbox, Inc. All rights reserved.
//

#import "FlashCardsAppDelegate.h"
#import "FlashCardsCore.h"

#import "QuizletRestClient.h"
#import "QuizletSync.h"
#import "FCRequest.h"

#import "ASIHTTPRequest.h"
#import "ASIFormDataRequest.h"

#import "NSString+URLEscapingAdditions.h"
#import "NSString+URLEncoding.h"
#import "NSString+XMLEntities.h"
#import "NSString+AESCrypt.h"

#import "ImportSet.h"
#import "ImportTerm.h"
#import "ImportGroup.h"

#import "FCCard.h"
#import "FCCardSet.h"
#import "FCCollection.h"

#import <CommonCrypto/CommonCryptor.h>

@implementation QuizletRestClient

@synthesize username, password;
@synthesize encryptedUsername, encryptedPassword;

- (void)encryptCredentials {
    
    if ([(NSNumber*)[FlashCardsCore getSetting:@"quizletIsLoggedIn"] boolValue]) {
        [Flurry setUserID:[NSString stringWithFormat:@"Quizlet/%@", username]];
    }
    
    // as per: http://stackoverflow.com/questions/4260108/encrypt-in-objective-c-decrypt-in-ruby-using-anything/4322453#4322453
    NSData     *usernameData    = [username dataUsingEncoding: NSUTF8StringEncoding];
    NSData     *keyUsername     = [NSData dataWithBytes: [[@"api.iphoneflashcards.com/username" sha256] bytes] length: kCCKeySizeAES128];
    self.encryptedUsername      = [usernameData aesEncryptedDataWithKey: keyUsername];
    
    NSData     *passwordData    = [password dataUsingEncoding: NSUTF8StringEncoding];
    NSData     *keyPassword     = [NSData dataWithBytes: [[@"com.iphoneflashcards.api/access_token" sha256] bytes] length: kCCKeySizeAES128];
    self.encryptedPassword      = [passwordData aesEncryptedDataWithKey: keyPassword];

}

+ (BOOL)isLoggedIn {
    return [(NSNumber*)[FlashCardsCore getSetting:@"quizletIsLoggedIn"] boolValue];
    return NO;
}

+ (BOOL)isQuizletPlus {
    return [(NSNumber*)[FlashCardsCore getSetting:@"quizletPlus"] boolValue];
}

+ (void)pingApiLogWithMethod:(NSString *)method andSearchTerm:(NSString *)searchTerm {
    ASIFormDataRequest *urlRequest = [[ASIFormDataRequest alloc]
                                      initWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://%@/quizlet", flashcardsServer]]];
    [urlRequest addPostValue:[FlashCardsCore appVersion] forKey:@"appVersion"];
    [urlRequest addPostValue:[FlashCardsCore buildNumber] forKey:@"buildNumber"];
    [urlRequest addPostValue:[FlashCardsCore osVersionNumber] forKey:@"iosVersion"];
    [urlRequest addPostValue:method forKey:@"method"];
    [urlRequest addPostValue:[NSNumber numberWithBool:[QuizletRestClient isLoggedIn]] forKey:@"is_logged_in"];
    [urlRequest addPostValue:searchTerm forKey:@"search_term"];
    [urlRequest addPostValue:[FlashCardsCore getSetting:@"fceUsername"] forKey:@"username"];
    [urlRequest addPostValue:[[UIDevice currentDevice] model] forKey:@"device"];
    [urlRequest setDelegate:nil];
    [urlRequest setDidFinishSelector:nil];
    [urlRequest setDidFailSelector:nil];
    [urlRequest startAsynchronous];
}

# pragma mark -
# pragma mark Load User Card Sets

/* Loads user's card sets */
- (void)loadUserCardSetsList:(NSString*)_username withPage:(int)pageNumber {
    // THE IDEA: always request the data from the website directly (i.e., skip API). If the user is logged in, include their
    // cookie data. This way we just have one API to deal with. Potentiall can use NSXMLDocument code to traverse / strip tree data.
    
    NSString *fullPath;
    fullPath = [NSString stringWithFormat:@"http://%@/%@/user/",
                flashcardsServer,
                flashcardsQuizletAction];
    
    ASIFormDataRequest *urlRequest = [[ASIFormDataRequest alloc] initWithURL:[NSURL URLWithString:fullPath]];
    [urlRequest setupFlashCardsAuthentication:@"user"];
    // save data in the request's userInfo, so that if we need to reconstruct the request with the Quizlet server, we will
    // know which username and page# we asked for originally.
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              _username, @"username",
                              [NSNumber numberWithInt:pageNumber], @"pageNumber",
                              nil];
    [urlRequest setUserInfo:userInfo];
    // if the user is logged in, then we will encrypt the data:
    if ([(NSNumber*)[FlashCardsCore getSetting:@"quizletIsLoggedIn"] boolValue]) {
        self.username = (NSString*)[FlashCardsCore getSetting:@"quizletLoginUsername"];
        self.password = (NSString*)[FlashCardsCore getSetting:@"quizletAPI2AccessToken"];
        [self encryptCredentials];
        [urlRequest addPostValue:[self.encryptedUsername base64Encoding] forKey:@"username"];
        [urlRequest addPostValue:[self.encryptedPassword base64Encoding] forKey:@"access_token"]; 
    }
    [urlRequest addPostValue:_username forKey:@"name"];
    [urlRequest addPostValue:[NSNumber numberWithInt:pageNumber] forKey:@"page"];
    
    FCRequest* request =  [[FCRequest alloc] initWithURLRequest:urlRequest
                                                andInformTarget:self
                                                       selector:@selector(requestDidLoadUserCardSetsList:)];
    [requests addObject:request];
}

- (void)loadUserCardSetsList:(NSString*)_username {
    [self loadUserCardSetsList:_username withPage:0];
}


- (void)requestDidLoadUserCardSetsList:(FCRequest*)request {
    NSString *url = [request.request.url absoluteString];
    NSString *server = [NSString stringWithFormat:@"http://%@/", flashcardsServer];
    if (request.error) {
        // if we tried going to the server (which may be down), first try to load from the Quizlet server:
        if ([url hasPrefix:server]) {
            NSString *fullPath;
            // build the full-path  using data from the request's userInfo:
            fullPath = [NSString stringWithFormat:@"http://%@/1.0/sets?dev_key=%@&q=creator:%@&sort=most_recent&page=%d&whitespace=off",
                        @"api.quizlet.com",
                        quizletApiKey,
                        [[request.request.userInfo valueForKey:@"username"] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
                        [[request.request.userInfo objectForKey:@"pageNumber"] intValue]
                        ];
            ASIFormDataRequest *urlRequest = [[ASIFormDataRequest alloc] initWithURL:[NSURL URLWithString:fullPath]];
            FCRequest* request = [[FCRequest alloc] initWithURLRequest:urlRequest
                                                       andInformTarget:self
                                                              selector:@selector(requestDidLoadUserCardSetsList:)];
            [requests addObject:request];
            if (delegate && [delegate respondsToSelector:@selector(flashcardsServerAPINotAvailable:)]) {
                [delegate flashcardsServerAPINotAvailable:self];
            }

        } else if ([delegate respondsToSelector:@selector(restClient:loadUserCardSetsListFailedWithError:)]) {
            [delegate restClient:self loadUserCardSetsListFailedWithError:request.error];
        }
    } else {
        FCLog(@"%@", request.resultString);
        NSMutableDictionary *parsedJson = [NSMutableDictionary dictionaryWithDictionary:(NSDictionary*)request.resultJSON];
        if ([self checkJsonErrors:parsedJson withErrorSelector:@selector(restClient:loadUserCardSetsListFailedWithError:)]) {
            return;
        }
        
        // if the URL is not on our web server, then it means we are using the native API. Mark it in the Json:
        if (![url hasPrefix:server]) {
            [parsedJson setValue:@"native_quizlet_api" forKey:@"api_method"];
        }
        
        if ([parsedJson objectForKey:@"account_type"]) {
            if ([[parsedJson valueForKey:@"account_type"] isEqualToString:@"plus"] ||
                [[parsedJson valueForKey:@"account_type"] isEqualToString:@"teacher"]) {
                [FlashCardsCore setSetting:@"quizletPlus" value:@YES];
            } else {
                [FlashCardsCore setSetting:@"quizletPlus" value:@NO];
            }
        } else {
            [FlashCardsCore setSetting:@"quizletPlus" value:@NO];
        }
        
        NSArray *setsLoaded = [parsedJson valueForKey:@"sets"];
        int pageNumber = 1;
        if ([parsedJson objectForKey:@"page"]) {
            pageNumber = [(NSNumber*)[parsedJson objectForKey:@"page"] intValue];
        }

        NSMutableArray *cardSets = [[NSMutableArray alloc] initWithCapacity:0];
        ImportSet *cardSet;
        NSDictionary *setData;
        
        for (int i = 0; i < [setsLoaded count]; i++) {
            setData = [setsLoaded objectAtIndex:i];
            cardSet = [[ImportSet alloc] initWithQuizletData:setData];
            [cardSets addObject:cardSet];
        }
        
        int numberTotalSets = [[parsedJson valueForKey:@"total_results"] intValue];
        
        if ([[parsedJson objectForKey:@"api_method"] isEqual:@"native_quizlet_api"] && delegate && [delegate respondsToSelector:@selector(flashcardsServerAPINotAvailable:)]) {
            [delegate flashcardsServerAPINotAvailable:self];
        }
        if (delegate && [delegate respondsToSelector:@selector(restClient:loadedUserCardSetsList:pageNumber:numberTotalSets:)]) {
            [delegate restClient:self loadedUserCardSetsList:cardSets pageNumber:pageNumber numberTotalSets:numberTotalSets];
        }
    }
    [requests removeObject:request];
}

# pragma mark -
# pragma mark Load User's Groups

- (void)loadUserGroupsList:(NSString *)_username {
    NSString *fullPath;
    fullPath = [NSString stringWithFormat:@"http://%@/%@/userGroups/",
                flashcardsServer,
                flashcardsQuizletAction];
    
    ASIFormDataRequest *urlRequest = [[ASIFormDataRequest alloc] initWithURL:[NSURL URLWithString:fullPath]];
    [urlRequest setupFlashCardsAuthentication:@"userGroups"];
    // save data in the request's userInfo, so that if we need to reconstruct the request with the Quizlet server, we will
    // know which username and page# we asked for originally.
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              _username, @"username",
                              nil];
    [urlRequest setUserInfo:userInfo];
    // if the user is logged in, then we will encrypt the data:
    if ([(NSNumber*)[FlashCardsCore getSetting:@"quizletIsLoggedIn"] boolValue]) {
        self.username = (NSString*)[FlashCardsCore getSetting:@"quizletLoginUsername"];
        self.password = (NSString*)[FlashCardsCore getSetting:@"quizletAPI2AccessToken"];
        [self encryptCredentials];
        [urlRequest addPostValue:[self.encryptedUsername base64Encoding] forKey:@"username"];
        [urlRequest addPostValue:[self.encryptedPassword base64Encoding] forKey:@"access_token"]; 
    }
    [urlRequest addPostValue:_username forKey:@"name"];
    
    FCRequest* request = [[FCRequest alloc] initWithURLRequest:urlRequest
                                               andInformTarget:self
                                                      selector:@selector(requestDidLoadUserGroupsList:)];
    [requests addObject:request];
    
}

- (void) requestDidLoadUserGroupsList:(FCRequest*)request {
    if (request.error) {
        // there is no native api, so no need to check if we went to the server.
        if ([delegate respondsToSelector:@selector(restClient:loadUserGroupsListFailedWithError:)]) {
            [delegate restClient:self loadUserGroupsListFailedWithError:request.error];
        }
    } else {
        FCLog(@"%@", request.resultString);
        NSMutableDictionary *parsedJson = [NSMutableDictionary dictionaryWithDictionary:(NSDictionary*)request.resultJSON];
        if ([self checkJsonErrors:parsedJson withErrorSelector:@selector(restClient:loadUserGroupsListFailedWithError:)]) {
            return;
        }
        
        NSArray *groupsLoaded = [parsedJson valueForKey:@"groups"];
        NSMutableArray *groups = [[NSMutableArray alloc] initWithCapacity:0];
        ImportGroup *group;
        NSDictionary *setData;
        
        for (int i = 0; i < [groupsLoaded count]; i++) {
            setData = [groupsLoaded objectAtIndex:i];
            group = [[ImportGroup alloc] initWithDictionary:setData];
            [groups addObject:group];
        }
        
        if (delegate && [delegate respondsToSelector:@selector(restClient:loadedUserGroupsList:)]) {
            [delegate restClient:self loadedUserGroupsList:groups];
        }
    }
    [requests removeObject:request];

}

# pragma mark -
# pragma mark Get card sets for a group


- (void)loadGroupCardSetsList:(ImportGroup*)group {
    NSString *fullPath;
    fullPath = [NSString stringWithFormat:@"http://%@/%@/group/id/%d",
                flashcardsServer,
                flashcardsQuizletAction,
                group.groupId];
    
    ASIFormDataRequest *urlRequest = [[ASIFormDataRequest alloc] initWithURL:[NSURL URLWithString:fullPath]];
    [urlRequest setupFlashCardsAuthentication:@"group"];
    // save data in the request's userInfo, so that if we need to reconstruct the request with the Quizlet server, we will
    // know which username and page# we asked for originally.
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              group, @"group",
                              nil];
    [urlRequest setUserInfo:userInfo];
    // if the user is logged in, then we will encrypt the data:
    if ([(NSNumber*)[FlashCardsCore getSetting:@"quizletIsLoggedIn"] boolValue]) {
        self.username = (NSString*)[FlashCardsCore getSetting:@"quizletLoginUsername"];
        self.password = (NSString*)[FlashCardsCore getSetting:@"quizletAPI2AccessToken"];
        [self encryptCredentials];
        [urlRequest addPostValue:[self.encryptedUsername base64Encoding] forKey:@"username"];
        [urlRequest addPostValue:[self.encryptedPassword base64Encoding] forKey:@"access_token"]; 
    }
    
    FCRequest* request = [[FCRequest alloc] initWithURLRequest:urlRequest
                                                andInformTarget:self
                                                       selector:@selector(requestDidLoadGroupCardSetsList:)];
    [requests addObject:request];
}

- (void)requestDidLoadGroupCardSetsList:(FCRequest*)request {
    if (request.error) {
        // there is no native api, so no need to check if we went to the server.
        if ([delegate respondsToSelector:@selector(restClient:loadGroupCardSetsListFailedWithError:)]) {
            [delegate restClient:self loadGroupCardSetsListFailedWithError:request.error];
        }
    } else {
        FCLog(@"%@", request.resultString);
        NSMutableDictionary *parsedJson = [NSMutableDictionary dictionaryWithDictionary:(NSDictionary*)request.resultJSON];
        if ([self checkJsonErrors:parsedJson withErrorSelector:@selector(restClient:loadGroupCardSetsListFailedWithError:)]) {
            return;
        }
        
        NSArray *setsLoaded = [parsedJson valueForKey:@"sets"];
        
        ImportGroup *group = (ImportGroup*)[request.request.userInfo objectForKey:@"group"];
        group.name = [parsedJson valueForKey:@"title"];
        if ([parsedJson valueForKey:@"description"]) {
            group.description = [parsedJson valueForKey:@"description"];
        }
        group.numberCardSets = [[parsedJson valueForKey:@"set_count"] intValue];
        group.numberUsers = [[parsedJson valueForKey:@"user_count"] intValue];
        if ([(NSNumber*)[parsedJson valueForKey:@"is_private"] boolValue]) {
            group.isPrivateGroup = YES;
        }
        if ([(NSNumber*)[parsedJson valueForKey:@"is_member"] boolValue]) {
            group.isMemberOfGroup = YES;
        }

        NSMutableArray *cardSets = [[NSMutableArray alloc] initWithCapacity:0];
        ImportSet *cardSet;
        NSDictionary *setData;
        
        for (int i = 0; i < [setsLoaded count]; i++) {
            setData = [setsLoaded objectAtIndex:i];
            cardSet = [[ImportSet alloc] initWithQuizletData:setData];
            [cardSets addObject:cardSet];
        }
        
        if (delegate && [delegate respondsToSelector:@selector(restClient:loadedGroupCardSetsList:)]) {
            [delegate restClient:self loadedGroupCardSetsList:cardSets];
        }
    }
    [requests removeObject:request];
}


# pragma mark -
# pragma mark Join group

- (void) joinGroup:(ImportGroup *)group withInput:(NSString *)input {
    NSString *fullPath;
    fullPath = [NSString stringWithFormat:@"http://%@/%@/joinGroup/id/%d",
                flashcardsServer,
                flashcardsQuizletAction,
                group.groupId];
    
    ASIFormDataRequest *urlRequest = [[ASIFormDataRequest alloc] initWithURL:[NSURL URLWithString:fullPath]];
    [urlRequest setupFlashCardsAuthentication:@"joinGroup"];
    // save data in the request's userInfo, so that if we need to reconstruct the request with the Quizlet server, we will
    // know which username and page# we asked for originally.
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              group, @"group",
                              input, @"input",
                              nil];
    [urlRequest setUserInfo:userInfo];
    // if the user is logged in, then we will encrypt the data:
    if ([(NSNumber*)[FlashCardsCore getSetting:@"quizletIsLoggedIn"] boolValue]) {
        self.username = (NSString*)[FlashCardsCore getSetting:@"quizletLoginUsername"];
        self.password = (NSString*)[FlashCardsCore getSetting:@"quizletAPI2AccessToken"];
        [self encryptCredentials];
        [urlRequest addPostValue:[self.encryptedUsername base64Encoding] forKey:@"username"];
        [urlRequest addPostValue:[self.encryptedPassword base64Encoding] forKey:@"access_token"]; 
    }
    
    if (group.isPrivateGroup) {
        if (group.requiresPassword) {
            [urlRequest addPostValue:@"password" forKey:@"joinType"];
            [urlRequest addPostValue:input forKey:@"groupPassword"];
        } else {
            [urlRequest addPostValue:@"message" forKey:@"joinType"];
            [urlRequest addPostValue:input forKey:@"groupMessage"];
        }
    } else {
        [urlRequest addPostValue:@"open" forKey:@"joinType"];
    }
    
    FCRequest* request =  [[FCRequest alloc] initWithURLRequest:urlRequest
                                                andInformTarget:self
                                                       selector:@selector(requestDidJoinGroup:)];
    [requests addObject:request];    
}

- (void)requestDidJoinGroup:(FCRequest*)request {
    if (request.error) {
        // there is no native api, so no need to check if we went to the server.
        if ([delegate respondsToSelector:@selector(restClient:joinGroupFailedWithError:)]) {
            [delegate restClient:self joinGroupFailedWithError:request.error];
        }
    } else {
        FCLog(@"%@", request.resultString);
        NSMutableDictionary *parsedJson = [NSMutableDictionary dictionaryWithDictionary:(NSDictionary*)request.resultJSON];
        if ([self checkJsonErrors:parsedJson withErrorSelector:@selector(restClient:joinGroupFailedWithError:)]) {
            return;
        }
        
        NSArray *setsLoaded = [parsedJson valueForKey:@"sets"];
        
        NSMutableArray *cardSets = [[NSMutableArray alloc] initWithCapacity:0];
        ImportSet *cardSet;
        NSDictionary *setData;
        
        for (int i = 0; i < [setsLoaded count]; i++) {
            setData = [setsLoaded objectAtIndex:i];
            cardSet = [[ImportSet alloc] initWithQuizletData:setData];
            [cardSets addObject:cardSet];
        }
        
        ImportGroup *group = (ImportGroup*)[request.request.userInfo objectForKey:@"group"];
        group.isMemberOfGroup = YES;
        
        if (delegate && [delegate respondsToSelector:@selector(restClient:joinedGroup:withCardSets:)]) {
            [delegate restClient:self
                     joinedGroup:group
                    withCardSets:cardSets];
        }
    }
    [requests removeObject:request];
}

# pragma mark -
# pragma mark Leave group

- (void)leaveGroup:(ImportGroup*)group {
    NSString *fullPath;
    fullPath = [NSString stringWithFormat:@"http://%@/%@/leaveGroup/id/%d",
                flashcardsServer,
                flashcardsQuizletAction,
                group.groupId];
    
    ASIFormDataRequest *urlRequest = [[ASIFormDataRequest alloc] initWithURL:[NSURL URLWithString:fullPath]];
    [urlRequest setupFlashCardsAuthentication:@"leaveGroup"];
    // save data in the request's userInfo, so that if we need to reconstruct the request with the Quizlet server, we will
    // know which username and page# we asked for originally.
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              group, @"group",
                              nil];
    [urlRequest setUserInfo:userInfo];
    // if the user is logged in, then we will encrypt the data:
    if ([(NSNumber*)[FlashCardsCore getSetting:@"quizletIsLoggedIn"] boolValue]) {
        self.username = (NSString*)[FlashCardsCore getSetting:@"quizletLoginUsername"];
        self.password = (NSString*)[FlashCardsCore getSetting:@"quizletAPI2AccessToken"];
        [self encryptCredentials];
        [urlRequest addPostValue:[self.encryptedUsername base64Encoding] forKey:@"username"];
        [urlRequest addPostValue:[self.encryptedPassword base64Encoding] forKey:@"access_token"]; 
    }
    
    FCRequest* request = [[FCRequest alloc] initWithURLRequest:urlRequest
                                               andInformTarget:self
                                                      selector:@selector(requestDidLeaveGroup:)];
    [requests addObject:request];    
}
                              
-(void)requestDidLeaveGroup:(FCRequest*)request {
    if (request.error) {
        // there is no native api, so no need to check if we went to the server.
        if ([delegate respondsToSelector:@selector(restClient:leaveGroupFailedWithError:)]) {
            [delegate restClient:self leaveGroupFailedWithError:request.error];
        }
    } else {
        FCLog(@"%@", request.resultString);
        NSMutableDictionary *parsedJson = [NSMutableDictionary dictionaryWithDictionary:(NSDictionary*)request.resultJSON];
        if ([self checkJsonErrors:parsedJson withErrorSelector:@selector(restClient:leaveGroupFailedWithError:)]) {
            return;
        }
        
        ImportGroup *group = (ImportGroup*)[request.request.userInfo objectForKey:@"group"];
        group.isMemberOfGroup = NO;
        
        if (delegate && [delegate respondsToSelector:@selector(restClient:leftGroup:)]) {
            [delegate restClient:self leftGroup:group];
        }
    }
    [requests removeObject:request];
}

# pragma mark -
# pragma mark Search for groups

- (void)loadSearchGroupsList:(NSString*)searchTerm withPage:(int)pageNumber {
    NSString *fullPath;
    fullPath = [NSString stringWithFormat:@"http://%@/%@/searchGroups/",
                flashcardsServer,
                flashcardsQuizletAction];
    
    ASIFormDataRequest *urlRequest = [[ASIFormDataRequest alloc] initWithURL:[NSURL URLWithString:fullPath]];
    [urlRequest setupFlashCardsAuthentication:@"searchGroups"];
    // save data in the request's userInfo, so that if we need to reconstruct the request with the Quizlet server, we will
    // know which username and page# we asked for originally.
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              searchTerm, @"searchTerm",
                              nil];
    [urlRequest setUserInfo:userInfo];
    // if the user is logged in, then we will encrypt the data:
    if ([(NSNumber*)[FlashCardsCore getSetting:@"quizletIsLoggedIn"] boolValue]) {
        self.username = (NSString*)[FlashCardsCore getSetting:@"quizletLoginUsername"];
        self.password = (NSString*)[FlashCardsCore getSetting:@"quizletAPI2AccessToken"];
        [self encryptCredentials];
        [urlRequest addPostValue:[self.encryptedUsername base64Encoding] forKey:@"username"];
        [urlRequest addPostValue:[self.encryptedPassword base64Encoding] forKey:@"access_token"]; 
    }
    
    [urlRequest addPostValue:searchTerm forKey:@"term"];
    [urlRequest addPostValue:[NSNumber numberWithInt:pageNumber] forKey:@"page"];
    
    FCRequest* request = [[FCRequest alloc] initWithURLRequest:urlRequest
                                               andInformTarget:self
                                                      selector:@selector(requestDidLoadSearchGroupsList:)];
    [requests addObject:request];    

}
- (void)requestDidLoadSearchGroupsList:(FCRequest*)request {
    if (request.error) {
        // there is no native api, so no need to check if we went to the server.
        if ([delegate respondsToSelector:@selector(restClient:loadSearchGroupsListFailedWithError:)]) {
            [delegate restClient:self loadSearchGroupsListFailedWithError:request.error];
        }
    } else {
        FCLog(@"%@", request.resultString);
        NSMutableDictionary *parsedJson = [NSMutableDictionary dictionaryWithDictionary:(NSDictionary*)request.resultJSON];
        if ([self checkJsonErrors:parsedJson withErrorSelector:@selector(restClient:loadSearchGroupsListFailedWithError:)]) {
            return;
        }
        
        NSArray *groupsLoaded = [parsedJson valueForKey:@"groups"];
        NSMutableArray *groups = [[NSMutableArray alloc] initWithCapacity:0];
        ImportGroup *group;
        NSDictionary *setData;
        
        for (int i = 0; i < [groupsLoaded count]; i++) {
            setData = [groupsLoaded objectAtIndex:i];
            group = [[ImportGroup alloc] initWithDictionary:setData];
            [groups addObject:group];
        }
        
        int pageNumber = 1;
        if ([parsedJson objectForKey:@"page"]) {
            pageNumber = [(NSNumber*)[parsedJson objectForKey:@"page"] intValue];
        }
        int totalGroups = [[parsedJson objectForKey:@"total_results"] intValue];
        
        if (delegate && [delegate respondsToSelector:@selector(restClient:loadedSearchGroupsList:pageNumber:numberTotalGroups:)]) {
            [delegate restClient:self loadedSearchGroupsList:groups pageNumber:pageNumber numberTotalGroups:totalGroups];
        }
    }
    [requests removeObject:request];

}




# pragma mark -
# pragma mark Search for Card Sets

- (void)loadSearchCardSetsList:(NSString *)searchTerm withScope:(int)scope {
    [self loadSearchCardSetsList:searchTerm withPage:0 withScope:scope];
}
- (void)loadSearchCardSetsList:(NSString *)searchTerm withPage:(int)pageNumber withScope:(int)scope {
    NSString *fullPath, *scopeText;
    switch (scope) {
        case 0:
            scopeText = @"most_studied";
            break;
        case 1:
            scopeText = @"most_recent";
            break;
        default:
        case 2:
            scopeText = @"alphabetical";
            break;
    }
    
    fullPath = [NSString stringWithFormat:@"http://%@/%@/search/",
                flashcardsServer,
                flashcardsQuizletAction];
    
    ASIFormDataRequest *urlRequest = [[ASIFormDataRequest alloc] initWithURL:[NSURL URLWithString:fullPath]];
    [urlRequest setupFlashCardsAuthentication:@"search"];
    // save data in the request's userInfo, so that if we need to reconstruct the request with the Quizlet server, we will
    // know which username and page# we asked for originally.
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              searchTerm, @"searchTerm",
                              [NSNumber numberWithInt:pageNumber], @"pageNumber",
                              scopeText, @"scopeText",
                              nil];
    [urlRequest setUserInfo:userInfo];
    // if the user is logged in, then we will encrypt the data:
    if ([(NSNumber*)[FlashCardsCore getSetting:@"quizletIsLoggedIn"] boolValue]) {
        self.username = (NSString*)[FlashCardsCore getSetting:@"quizletLoginUsername"];
        self.password = (NSString*)[FlashCardsCore getSetting:@"quizletAPI2AccessToken"];
        [self encryptCredentials];
        [urlRequest addPostValue:[self.encryptedUsername base64Encoding] forKey:@"username"];
        [urlRequest addPostValue:[self.encryptedPassword base64Encoding] forKey:@"access_token"]; 
    }
    
    [urlRequest addPostValue:searchTerm forKey:@"term"];
    [urlRequest addPostValue:[NSNumber numberWithInt:pageNumber] forKey:@"page"];
    [urlRequest addPostValue:scopeText forKey:@"scope"];
    
    FCRequest* request =  [[FCRequest alloc] initWithURLRequest:urlRequest
                                                andInformTarget:self
                                                       selector:@selector(requestDidLoadSearchCardSetsList:)];
    [requests addObject:request];

}

- (void)requestDidLoadSearchCardSetsList:(FCRequest*)request {
    NSString *url = [request.request.url absoluteString];
    NSString *server = [NSString stringWithFormat:@"http://%@/", flashcardsServer];
    if (request.error) {
        if ([url hasPrefix:server]) {
            NSString *fullPath;
            // build the full-path  using data from the request's userInfo:
            fullPath = [NSString stringWithFormat:
                        @"http://%@/1.0/sets?dev_key=%@&q=%@&sort=%@&per_page=50&page=%d&whitespace=off",
                        @"api.quizlet.com",
                        quizletApiKey,
                        [[request.request.userInfo valueForKey:@"searchTerm"] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
                        [request.request.userInfo valueForKey:@"scopeText"],
                        [[request.request.userInfo objectForKey:@"pageNumber"] intValue]
                        ];
            ASIFormDataRequest *urlRequest = [[ASIFormDataRequest alloc] initWithURL:[NSURL URLWithString:fullPath]];
            FCRequest* request = [[FCRequest alloc] initWithURLRequest:urlRequest
                                                       andInformTarget:self
                                                              selector:@selector(requestDidLoadUserCardSetsList:)];
            [requests addObject:request];
            if (delegate && [delegate respondsToSelector:@selector(flashcardsServerAPINotAvailable:)]) {
                [delegate flashcardsServerAPINotAvailable:self];
            }
            
        } else if ([delegate respondsToSelector:@selector(restClient:loadSearchCardSetsListFailedWithError:)]) {
            [delegate restClient:self loadSearchCardSetsListFailedWithError:request.error];
        }
    } else {
        
        FCLog(@"%@", request.resultString);
        NSDictionary *parsedJson = (NSDictionary*)request.resultJSON;
        if ([self checkJsonErrors:parsedJson withErrorSelector:@selector(restClient:loadSearchCardSetsListFailedWithError:)]) {
            return;
        }
        
        // if the URL is not on our web server, then it means we are using the native API. Mark it in the Json:
        if (![url hasPrefix:server]) {
            [parsedJson setValue:@"native_quizlet_api" forKey:@"api_method"];
        }

        NSArray *setsLoaded = [parsedJson valueForKey:@"sets"];
        int pageNumber = 1;
        if ([parsedJson objectForKey:@"page"]) {
            pageNumber = [(NSNumber*)[parsedJson objectForKey:@"page"] intValue];
        }
        
        NSMutableArray *cardSets = [[NSMutableArray alloc] initWithCapacity:0];
        ImportSet *cardSet;
        NSDictionary *setData;
        
        for (int i = 0; i < [setsLoaded count]; i++) {
            setData = [setsLoaded objectAtIndex:i];
            cardSet = [[ImportSet alloc] initWithQuizletData:setData];
            [cardSets addObject:cardSet];
        }
        
        int numberTotalSets = [[parsedJson valueForKey:@"total_results"] intValue];
        
        if (delegate && [delegate respondsToSelector:@selector(restClient:loadedSearchCardSetsList:pageNumber:numberTotalSets:)]) {
            [delegate restClient:self loadedSearchCardSetsList:cardSets pageNumber:pageNumber numberTotalSets:numberTotalSets];
        }
    }
    [requests removeObject:request];
}


# pragma mark -
# pragma mark Download Card Set's Cards

/* Loads a particular card set */
- (void)loadCardSetCards:(int)cardSetId {
    
    [self loadCardSetCards:cardSetId withPassword:@""];
    
}
- (void)loadCardSetCards:(int)cardSetId withPassword:(NSString*)setPassword {

// pull out the quizlet ID into the set ID:
    NSString *fullPath = [NSString stringWithFormat:
               @"http://%@/%@/cardset/id/%d",
               flashcardsServer,
               flashcardsQuizletAction,
               cardSetId];

    ASIFormDataRequest *urlRequest = [[ASIFormDataRequest alloc] initWithURL:[NSURL URLWithString:fullPath]];
    [urlRequest setupFlashCardsAuthentication:@"cardset"];
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              [NSNumber numberWithInt:cardSetId], @"cardSetId",
                              nil];
    [urlRequest setUserInfo:userInfo];
    // if the user is logged in, then we will encrypt the data:
    if ([(NSNumber*)[FlashCardsCore getSetting:@"quizletIsLoggedIn"] boolValue]) {
        self.username = (NSString*)[FlashCardsCore getSetting:@"quizletLoginUsername"];
        self.password = (NSString*)[FlashCardsCore getSetting:@"quizletAPI2AccessToken"];
        [self encryptCredentials];
        [urlRequest addPostValue:[self.encryptedUsername base64Encoding] forKey:@"username"];
        [urlRequest addPostValue:[self.encryptedPassword base64Encoding] forKey:@"access_token"]; 
    }
    if ([setPassword length] > 0) {
        [urlRequest addPostValue:setPassword forKey:@"setPassword"];
    }

    FCRequest* request = [[FCRequest alloc] initWithURLRequest:urlRequest
                                               andInformTarget:self
                                                      selector:@selector(requestDidLoadCardSetCards:)];
    [requests addObject:request];
}

- (void)requestDidLoadCardSetCards:(FCRequest*)request {
    NSString *url = [request.request.url absoluteString];
    NSString *server = [NSString stringWithFormat:@"http://%@/", flashcardsServer];
    if (request.error) {
        // if we tried going to the server (which may be down), first try to load from the Quizlet server:
        if ([url hasPrefix:server]) {
            NSString *fullPath;
            // build the full-path  using data from the request's userInfo:
            fullPath = [NSString stringWithFormat:@"http://%@/1.0/sets?dev_key=%@&q=ids:%d&extended=on&whitespace=off",
                        @"api.quizlet.com",
                        quizletApiKey,
                        [[request.request.userInfo objectForKey:@"cardSetId"] intValue]
                        ];
            ASIFormDataRequest *urlRequest = [[ASIFormDataRequest alloc] initWithURL:[NSURL URLWithString:fullPath]];
            FCRequest* request =  [[FCRequest alloc] initWithURLRequest:urlRequest
                                                        andInformTarget:self
                                                               selector:@selector(requestDidLoadCardSetCards:)];
            [requests addObject:request];
            if (delegate && [delegate respondsToSelector:@selector(flashcardsServerAPINotAvailable:)]) {
                [delegate flashcardsServerAPINotAvailable:self];
            }
        } else if ([delegate respondsToSelector:@selector(restClient:loadCardSetCardsFailedWithError:)]) {
            [delegate restClient:self loadCardSetCardsFailedWithError:request.error];
        }
    } else {
        FCLog(@"%@", request.resultString);
        NSMutableDictionary *parsedJson = [NSMutableDictionary dictionaryWithDictionary:(NSDictionary*)request.resultJSON];

        // if the URL is not on our web server, then it means we are using the native API. Mark it in the Json:
        if (![url hasPrefix:server]) {
            [parsedJson setValue:@"native_quizlet_api" forKey:@"api_method"];
        }
        
        if ([self checkJsonErrors:parsedJson withErrorSelector:@selector(restClient:loadCardSetCardsFailedWithError:)]) {
            return;
        }
        NSArray *sets = (NSArray *)[parsedJson objectForKey:@"sets"];
        NSMutableArray *termList = (NSMutableArray *)[[sets objectAtIndex:0] objectForKey:@"terms"];
        NSString *frontLanguage = (NSString *)[[sets objectAtIndex:0] objectForKey:@"lang_front"];
        NSString *backLanguage  = (NSString *)[[sets objectAtIndex:0] objectForKey:@"lang_back"];
        
        NSArray *currentJsonTermArray;
        ImportTerm *currentTerm;
        NSMutableArray *terms = [[NSMutableArray alloc] initWithCapacity:0];
        int quoteLocation;
        NSRange quoteRange;
        NSString *frontValue, *backValue, *frontImageUrl, *backImageUrl;
        BOOL hasImages = NO;
        int cardId;
        
        for (int i = 0; i < [termList count]; i++) {
            currentJsonTermArray = (NSArray*)[termList objectAtIndex:i];
            frontValue = [[currentJsonTermArray objectAtIndex:0] stringByDecodingXMLEntities];
            backValue = [[currentJsonTermArray objectAtIndex:1] stringByDecodingXMLEntities];
            backImageUrl = [NSString stringWithString:[[currentJsonTermArray objectAtIndex:2] stringByDecodingXMLEntities]];
            if ([backImageUrl length] > 0) {
                // extract URL: ex. <img src=\"http:\/\/i.quizlet.net\/i\/p0O5cfXcR1J1V5DAqj_wew_m.jpg\" width=\"132\" height=\"240\" \/>
                backImageUrl = [backImageUrl stringByReplacingCharactersInRange:NSMakeRange(0, 10) withString:@""];
                quoteRange = [backImageUrl rangeOfString:@"\""];
                quoteLocation = quoteRange.location;
                backImageUrl = [backImageUrl stringByReplacingCharactersInRange:NSMakeRange(quoteLocation, [backImageUrl length]-quoteLocation) withString:@""];
            } else {
                backImageUrl = @"";
            }
            frontImageUrl = @"";
            if ([currentJsonTermArray count] > 4) {
                cardId = [[currentJsonTermArray objectAtIndex:4] intValue];
            } else {
                cardId = -1;
            }

            currentTerm = [[ImportTerm alloc] init];
            currentTerm.importOrder = i;
            currentTerm.importTermFrontValue = frontValue;
            currentTerm.importTermBackValue  = backValue;
            if ([frontImageUrl length] > 0) {
                currentTerm.frontImageUrl = frontImageUrl;
                hasImages = YES;
            }
            if ([backImageUrl length] > 0) {
                currentTerm.backImageUrl = backImageUrl;
                hasImages = YES;
            }
            currentTerm.cardId = cardId;

            [terms addObject:currentTerm];
        }
        if ([[parsedJson objectForKey:@"api_method"] isEqual:@"native_quizlet_api"] && delegate && [delegate respondsToSelector:@selector(flashcardsServerAPINotAvailable:)]) {
            [delegate flashcardsServerAPINotAvailable:self];
        }
        if ([delegate respondsToSelector:@selector(restClient:loadedCardSetCards:withImages:frontLanguage:backLanguage:)]) {
            [delegate restClient:self loadedCardSetCards:terms withImages:hasImages frontLanguage:frontLanguage backLanguage:backLanguage];
        }

    }
    [requests removeObject:request];
}

# pragma mark -
# pragma mark Download multiple card sets

/* Loads multiple card sets */
- (void)loadMultipleCardSetCards:(NSArray*)cardSetIdArray {
    // pull out the quizlet ID into the set ID:
    NSString *fullPath = [NSString stringWithFormat:
                          @"http://%@/%@/multiplecardsets/",
                          flashcardsServer,
                          flashcardsQuizletAction];
    
    ASIFormDataRequest *urlRequest = [[ASIFormDataRequest alloc] initWithURL:[NSURL URLWithString:fullPath]];
    [urlRequest setupFlashCardsAuthentication:@"multiplecardsets"];
    // if the user is logged in, then we will encrypt the data:
    if ([(NSNumber*)[FlashCardsCore getSetting:@"quizletIsLoggedIn"] boolValue]) {
        self.username = (NSString*)[FlashCardsCore getSetting:@"quizletLoginUsername"];
        self.password = (NSString*)[FlashCardsCore getSetting:@"quizletAPI2AccessToken"];
        [self encryptCredentials];
        [urlRequest addPostValue:[self.encryptedUsername base64Encoding] forKey:@"username"];
        [urlRequest addPostValue:[self.encryptedPassword base64Encoding] forKey:@"access_token"]; 
    }
    for (NSNumber *setId in cardSetIdArray) {
        [urlRequest addPostValue:setId forKey:@"cardSetIdList[]"];
    }
    
    FCRequest* request = [[FCRequest alloc] initWithURLRequest:urlRequest
                                               andInformTarget:self
                                                      selector:@selector(requestDidLoadMultipleCardSetCards:)];
    [requests addObject:request];
}
- (void)requestDidLoadMultipleCardSetCards:(FCRequest*)request {
    NSString *url = [request.request.url absoluteString];
    NSString *server = [NSString stringWithFormat:@"http://%@/", flashcardsServer];
    if (request.error) {
        [delegate restClient:self loadCardSetCardsFailedWithError:request.error];
    } else {
        FCLog(@"%@", request.resultString);
        NSDictionary *parsedJson = (NSDictionary*)request.resultJSON;
        
        // if the URL is not on our web server, then it means we are using the native API. Mark it in the Json:
        if (![url hasPrefix:server]) {
            [parsedJson setValue:@"native_quizlet_api" forKey:@"api_method"];
        }
        
        if ([self checkJsonErrors:parsedJson withErrorSelector:@selector(restClient:loadCardSetCardsFailedWithError:)]) {
            return;
        }
        NSArray *sets = (NSArray *)[parsedJson objectForKey:@"sets"];
        NSMutableArray *cardSets = [[NSMutableArray alloc] initWithCapacity:0];
        ImportSet *cardSet;
        ImportTerm *currentTerm;
        NSMutableArray *termList, *terms;
        NSArray *currentJsonTermArray;
        int quoteLocation;
        NSRange quoteRange;
        NSString *frontValue, *backValue, *frontImageUrl, *backImageUrl;
        BOOL hasImages = NO;
        int cardId;
        
        for (NSDictionary *setData in sets) {
            cardSet = [[ImportSet alloc] initWithQuizletData:setData];
            
            termList = (NSMutableArray *)[setData objectForKey:@"terms"];
            terms = [[NSMutableArray alloc] initWithCapacity:0];
            
            for (int i = 0; i < [termList count]; i++) {
                currentJsonTermArray = (NSArray*)[termList objectAtIndex:i];
                frontValue = [[currentJsonTermArray objectAtIndex:0] stringByDecodingXMLEntities];
                backValue = [[currentJsonTermArray objectAtIndex:1] stringByDecodingXMLEntities];
                backImageUrl = [NSString stringWithString:[[currentJsonTermArray objectAtIndex:2] stringByDecodingXMLEntities]];
                if ([backImageUrl length] > 0) {
                    // extract URL: ex. <img src=\"http:\/\/i.quizlet.net\/i\/p0O5cfXcR1J1V5DAqj_wew_m.jpg\" width=\"132\" height=\"240\" \/>
                    backImageUrl = [backImageUrl stringByReplacingCharactersInRange:NSMakeRange(0, 10) withString:@""];
                    quoteRange = [backImageUrl rangeOfString:@"\""];
                    quoteLocation = quoteRange.location;
                    backImageUrl = [backImageUrl stringByReplacingCharactersInRange:NSMakeRange(quoteLocation, [backImageUrl length]-quoteLocation) withString:@""];
                } else {
                    backImageUrl = @"";
                }
                frontImageUrl = @"";
                if ([currentJsonTermArray count] > 4) {
                    cardId = [[currentJsonTermArray objectAtIndex:4] intValue];
                } else {
                    cardId = -1;
                }
                
                currentTerm = [[ImportTerm alloc] init];
                currentTerm.importOrder = i;
                currentTerm.importTermFrontValue = frontValue;
                currentTerm.importTermBackValue  = backValue;
                if ([frontImageUrl length] > 0) {
                    currentTerm.frontImageUrl = frontImageUrl;
                    hasImages = YES;
                }
                if ([backImageUrl length] > 0) {
                    currentTerm.backImageUrl = backImageUrl;
                    hasImages = YES;
                }
                currentTerm.cardId = cardId;
                
                [terms addObject:currentTerm];
            }
            
            [cardSet setFlashCards:terms];
            

            [cardSets addObject:cardSet];
        }
        
        if ([[parsedJson objectForKey:@"api_method"] isEqual:@"native_quizlet_api"] && delegate && [delegate respondsToSelector:@selector(flashcardsServerAPINotAvailable:)]) {
            [delegate flashcardsServerAPINotAvailable:self];
        }
        if ([delegate respondsToSelector:@selector(restClient:loadedMultipleCardSetCards:)]) {
            [delegate restClient:self loadedMultipleCardSetCards:cardSets];
        }
        
    }
    [requests removeObject:request];
}


# pragma mark -
# pragma mark Upload Card Set
- (void)uploadCardSetWithName:(NSString*)setName
                    withCards:(NSArray*)setCards
                fromFCCardSet:(FCCardSet *)cardSet
             fromFCCollection:(FCCollection *)collection
                   shouldSync:(BOOL)shouldSync
                    isPrivate:(BOOL)isPrivate
                 isDiscussion:(BOOL)isDiscussion
                      toGroup:(int)groupId
            withFrontLanguage:(NSString *)frontLanguage
             withBackLanguage:(NSString *)backLanguage {
    // pull out the quizlet ID into the set ID:
    NSString *fullPath = [NSString stringWithFormat:
                          @"http://%@/%@/uploadcardset",
                          flashcardsServer,
                          flashcardsQuizletAction];
    
    ASIFormDataRequest *urlRequest = [[ASIFormDataRequest alloc] initWithURL:[NSURL URLWithString:fullPath]];
    [urlRequest setupFlashCardsAuthentication:@"uploadcardset"];
    // if the user is logged in, then we will encrypt the data:
    if ([(NSNumber*)[FlashCardsCore getSetting:@"quizletIsLoggedIn"] boolValue]) {
        self.username = (NSString*)[FlashCardsCore getSetting:@"quizletLoginUsername"];
        self.password = (NSString*)[FlashCardsCore getSetting:@"quizletAPI2AccessToken"];
        [self encryptCredentials];
        [urlRequest addPostValue:[self.encryptedUsername base64Encoding] forKey:@"username"];
        [urlRequest addPostValue:[self.encryptedPassword base64Encoding] forKey:@"access_token"]; 
    }
    
    [urlRequest addPostValue:[NSNumber numberWithInt:(isPrivate ? 1 : 0)]    forKey:@"isPrivate"];
    [urlRequest addPostValue:[NSNumber numberWithInt:(isDiscussion ? 1 : 0)] forKey:@"isDiscussion"];
    [urlRequest addPostValue:setName forKey:@"setName"];
    [urlRequest addPostValue:[NSNumber numberWithInt:groupId] forKey:@"groupId"];
    
    [urlRequest addPostValue:frontLanguage forKey:@"lang_terms"];
    [urlRequest addPostValue:backLanguage forKey:@"lang_definitions"];
    
    for (FCCard *card in setCards) {
        [urlRequest addPostValue:card.frontValue forKey:@"frontValue[]"];
        [urlRequest addPostValue:card.backValue forKey:@"backValue[]"];
    }
    
    [urlRequest setUserInfo:@{
     @"cardSet" : (cardSet ? cardSet : collection.masterCardSet),
     @"shouldSync" : [NSNumber numberWithBool:shouldSync],
     @"setCards" : setCards
     }];
    
    FCRequest* request = [[FCRequest alloc] initWithURLRequest:urlRequest
                                               andInformTarget:self
                                                      selector:@selector(requestDidUploadCardSet:)];
    [requests addObject:request];

}
- (void)requestDidUploadCardSet:(FCRequest*)request {
    NSString *url = [request.request.url absoluteString];
    NSString *server = [NSString stringWithFormat:@"http://%@/", flashcardsServer];
    if (request.error) {
        if ([delegate respondsToSelector:@selector(restClient:uploadCardSetFailedWithError:)]) {
            [delegate restClient:self uploadCardSetFailedWithError:request.error];
        }
    } else {
        FCLog(@"%@", request.resultString);
        NSDictionary *parsedJson = (NSDictionary*)request.resultJSON;
        
        // if the URL is not on our web server, then it means we are using the native API. Mark it in the Json:
        if (![url hasPrefix:server]) {
            [parsedJson setValue:@"native_quizlet_api" forKey:@"api_method"];
        }
        
        if ([self checkJsonErrors:parsedJson withErrorSelector:@selector(restClient:uploadCardSetFailedWithError:)]) {
            return;
        }

        if ([[parsedJson objectForKey:@"api_method"] isEqual:@"native_quizlet_api"] && delegate && [delegate respondsToSelector:@selector(flashcardsServerAPINotAvailable:)]) {
            [delegate flashcardsServerAPINotAvailable:self];
        }
        
        BOOL shouldSync = [(NSNumber*)[request.request.userInfo objectForKey:@"shouldSync"] boolValue];

        FCCardSet *cardSet = [request.request.userInfo objectForKey:@"cardSet"];
        [cardSet setShouldSync:[NSNumber numberWithBool:shouldSync]];
        if (shouldSync) {
            [cardSet setLastSyncDate:[NSDate date]];
            [cardSet setDateModified:[NSDate date]];
        }
        [cardSet setQuizletSetId:[parsedJson objectForKey:@"set_id"]];
        [cardSet setFlashcardExchangeSetId:@0];
        
        // get the list of card ID#'s to match with the local cards:
        NSString *fullPath = [NSString stringWithFormat:
                              @"https://api.quizlet.com/2.0/sets/%d",
                              [cardSet.quizletSetId intValue]];
        
        ASIFormDataRequest *urlRequest = [[ASIFormDataRequest alloc] initWithURL:[NSURL URLWithString:fullPath]];
        [urlRequest addRequestHeader:@"Authorization"
                               value:[NSString stringWithFormat:@"Bearer %@", [FlashCardsCore getSetting:@"quizletAPI2AccessToken"]]];
        [urlRequest setUserInfo:@{
         @"cardSet" : cardSet,
         @"setCards" : [request.request.userInfo objectForKey:@"setCards"],
         @"shouldSync" : [request.request.userInfo objectForKey:@"shouldSync"],
         @"isPrivate" : [parsedJson objectForKey:@"is_private"]
         }];
        [urlRequest setRequestMethod:@"GET"];
        
        FCRequest* newRequest = [[FCRequest alloc] initWithURLRequest:urlRequest
                                                      andInformTarget:self
                                                             selector:@selector(requestDidLoadUploadedCardsetData:)];
        [requests addObject:newRequest];
    }
    [requests removeObject:request];

}

- (void) requestDidLoadUploadedCardsetData:(FCRequest*)request {
    if (request.error) {
        if ([delegate respondsToSelector:@selector(restClient:uploadCardSetFailedWithError:)]) {
            [delegate restClient:self uploadCardSetFailedWithError:request.error];
        }
    } else {
        FCLog(@"%@", request.resultString);
        NSDictionary *parsedJson = (NSDictionary*)request.resultJSON;
        
        NSArray *setCards = [NSArray arrayWithArray:[(NSSet*)[request.request.userInfo objectForKey:@"setCards"] allObjects]];
        FCCardSet *cardSet = (FCCardSet*)[request.request.userInfo objectForKey:@"cardSet"];
        BOOL shouldSync = [(NSNumber*)[request.request.userInfo objectForKey:@"shouldSync"] boolValue];
        int i = 0;
        for (NSDictionary *term in [parsedJson objectForKey:@"terms"]) {
            FCCard *card = [setCards objectAtIndex:i];
            [card setWebsiteCardId:[(NSNumber*)[term objectForKey:@"id"] intValue]
                        forCardSet:cardSet
                       withWebsite:@"quizlet"];
            i++;
        }
        [cardSet.managedObjectContext save:nil];
        
        if ([delegate respondsToSelector:@selector(restClient:uploadedCardSetWithName:withNumberCards:shouldSync:isPrivate:isDiscussion:andFinalURL:)]) {
            [delegate restClient:self
         uploadedCardSetWithName:[parsedJson valueForKey:@"title"]
                 withNumberCards:[[parsedJson objectForKey:@"term_count"] intValue]
                      shouldSync:shouldSync
                       isPrivate:[[request.request.userInfo objectForKey:@"isPrivate"] boolValue]
                    isDiscussion:[[parsedJson objectForKey:@"has_discussion"] boolValue]
                     andFinalURL:[parsedJson valueForKey:@"url"]];
        }

    }
}

# pragma mark -
# pragma mark -


// returns YES if there are errors; NO if there are no errors.
- (bool)checkJsonErrors:(NSDictionary*)parsedJson withErrorSelector:(SEL)errorSelector {
    if (!parsedJson) {
        if (delegate && [delegate respondsToSelector:errorSelector]) {
            NSError *error = [[NSError alloc] initWithDomain:@"api.quizlet.com"
                                                        code:kFCErrorJsonParseError
                                                    userInfo:nil];
            [delegate performSelector:errorSelector withObject:self withObject:error]; 
        }
        return YES;
    }
    
    NSString *responseType = (NSString *)[parsedJson objectForKey:@"response_type"];
    // response_type = "error" for both Quizlet & FlashcardExchange APIs.
    if ([responseType isEqual:@"error"]) {
        NSString *responseString = (NSString *)[parsedJson objectForKey:@"long_text"];
        if (![responseString isEqual:@"There are no sets in this subject."]) {
            if (delegate && [delegate respondsToSelector:errorSelector]) {
                NSMutableDictionary* errorUserInfo = [NSMutableDictionary dictionaryWithCapacity:0];
                [errorUserInfo setObject:responseString forKey:@"errorMessage"];
                NSError *error = [[NSError alloc] initWithDomain:@"api.quizlet.com"
                                                            code:[[parsedJson objectForKey:@"error_number"] intValue]
                                                        userInfo:errorUserInfo];
                
                [delegate performSelector:errorSelector withObject:self withObject:error]; 
            }
            return YES;
        }
    }
    return NO;
}

@end
