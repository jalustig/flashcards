//
//  NSString+AESCrypt.m
//
//  Created by Michael Sedlaczek, Gone Coding on 2011-02-22
//

#import "NSString+AESCrypt.h"

#import <CommonCrypto/CommonCryptor.h>
#import <CommonCrypto/CommonDigest.h>

@implementation NSString (AESCrypt)

- (NSString *)AES256EncryptWithKey:(NSString *)key
{
   NSData *plainData = [self dataUsingEncoding:NSUTF8StringEncoding];
   NSData *encryptedData = [plainData AES256EncryptWithKey:key];
   
   NSString *encryptedString = [encryptedData base64Encoding];
   
   return encryptedString;
}

- (NSString *)AES256DecryptWithKey:(NSString *)key
{
   NSData *encryptedData = [NSData dataWithBase64EncodedString:self];
   NSData *plainData = [encryptedData AES256DecryptWithKey:key];
   
   NSString *plainString = [[NSString alloc] initWithData:plainData encoding:NSUTF8StringEncoding];
   
   return plainString;
}

- (NSString*)encryptWithKey:(NSString*)key {
    NSData *dataToEncrypt = [self dataUsingEncoding:NSUTF8StringEncoding];
    NSData *encryptionKey = [NSData dataWithBytes:[[key sha256] bytes] length:kCCKeySizeAES128];
    NSData *encryptedData = [dataToEncrypt aesEncryptedDataWithKey:encryptionKey];
    return [encryptedData base64Encoding];
}

@end



@implementation NSString( Crypto )

- (NSData *) sha256 {
    unsigned char               *buffer;
    
    if ( ! ( buffer = (unsigned char *) malloc( CC_SHA256_DIGEST_LENGTH ) ) ) return nil;
    
    CC_SHA256( [self UTF8String], [self lengthOfBytesUsingEncoding: NSUTF8StringEncoding], buffer );
    
    return [NSData dataWithBytesNoCopy: buffer length: CC_SHA256_DIGEST_LENGTH];
}

@end
