//
//  DBRestClient.h
//  DropboxSDK
//
//  Created by Brian Smith on 4/9/10.
//  Copyright 2010 Dropbox, Inc. All rights reserved.
//


#import "FCRestClient.h"

@protocol QuizletRestClientDelegate;

@class ImportSet;

@interface QuizletRestClient : FCRestClient {
    NSString *username;
    NSString *password;
    NSData *encryptedUsername;
    NSData *encryptedPassword;
}

+ (BOOL)isLoggedIn;
+ (BOOL)isQuizletPlus;
+ (void)pingApiLogWithMethod:(NSString*)method andSearchTerm:(NSString*)searchTerm;

- (void)encryptCredentials;
- (bool)checkJsonErrors:(NSDictionary*)parsedJson withErrorSelector:(SEL)errorSelector;

@property (nonatomic, strong) NSString *username;
@property (nonatomic, strong) NSString *password;
@property (nonatomic, strong) NSData *encryptedUsername;
@property (nonatomic, strong) NSData *encryptedPassword;

@end

