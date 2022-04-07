//
//  ASIFormDataRequest+FlashCardExtensions.m
//  FlashCards
//
//  Created by Jason Lustig on 1/31/13.
//  Copyright (c) 2013 Jason Lustig. All rights reserved.
//

#import "ASIFormDataRequest+FlashCardExtensions.h"

#import "NSString+AESCrypt.h"
#import "NSData+AESCrypt.h"
#import <CommonCrypto/CommonCryptor.h>
#import <CommonCrypto/CommonDigest.h>

@implementation ASIFormDataRequest (FlashCardExtensions)
- (void)setupFlashCardsAuthentication:(NSString*)apiAction {
    // for statistical purposes, include the app version & iOS version
    [self addPostValue:[FlashCardsCore appVersion] forKey:@"appVersion"];
    [self addPostValue:[FlashCardsCore osVersionNumber] forKey:@"iosVersion"];
    [self addPostValue:[[UIDevice currentDevice] model] forKey:@"device"];
    /*
     Each API call self-authenticates in the following manner:
     1. There will be two keys to authenticate the API call.
     2. One of the keys will be the same for all calls. However each of the different API functions
     will have a different key, i.e. it will be the original key PLUS the name of the call, i.e.
     "originalKey/functionCall." That way, if someone starts to pull the two keys and re-use them, they
     will only work for the specific function call.
     3. The second key will be the encryption key for the first key. This will be a randomly generated string,
     but will be encrypted with a standard key.
     4. The server will receive both keys, and (a) decrypt the secondary key. This secondary key will not be authenticated
     but will be used to (b) decrypt the primary key. If the primary key does not match what it is supposed to look like,
     then the server throws the proper error.
     
     And... why do all this work? Because I want to authenticate that the API calls are actually
     coming from my app! If someone else reverse-engineers the API, then I will never know and another app
     will be able to offer the same functionality as me!!
     
     http://iphonedevelopertips.com/general/create-a-universally-unique-identifier-uuid.html
     http://stackoverflow.com/questions/2633801/generate-a-random-alphanumeric-string-in-cocoa
     
     */
    
    NSString *secondaryKey = [FlashCardsCore randomStringOfLength:10];
    // NSLog(@"Secondary Key: %@", secondaryKey);
    
    NSData *secondaryKeyData = [secondaryKey dataUsingEncoding:NSUTF8StringEncoding];
    NSData *keySecondaryKey = [NSData dataWithBytes:[[flashcardsServerSecondaryKeyEncryptionKey sha256] bytes] length:kCCKeySizeAES128];
    NSData *encryptedSecondaryKey = [secondaryKeyData aesEncryptedDataWithKey:keySecondaryKey];
    
    NSString   *primaryKey      = [[NSString stringWithFormat:@"%@/%@", flashcardsServerApiKey, apiAction] lowercaseString];
    
    // NSLog(@"Primary Key: %@", primaryKey);
    NSData     *primaryKeyData  = [primaryKey dataUsingEncoding: NSUTF8StringEncoding];
    NSData *keyPrimaryKey       = [NSData dataWithBytes:[[secondaryKey sha256] bytes] length:kCCKeySizeAES128];
    NSData *encryptedPrimaryKey = [primaryKeyData aesEncryptedDataWithKey:keyPrimaryKey];
    //NSLog(@"Decrypted: %@", [[encryptedPrimaryKey AES256DecryptWithKey:secondaryKey] base64Encoding]);
    
    [self addPostValue:[encryptedPrimaryKey base64Encoding]   forKey:@"primaryKey"];
    [self addPostValue:[encryptedSecondaryKey base64Encoding] forKey:@"secondaryKey"];
    
}
@end
