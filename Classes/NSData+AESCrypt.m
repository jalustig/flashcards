//
//  NSData+AESCrypt.m
//
//  AES Encrypt/Decrypt
//  Created by Jim Dovey and 'Jean'
//  See http://iphonedevelopment.blogspot.com/2009/02/strong-encryption-for-cocoa-cocoa-touch.html
//
//  BASE64 Encoding/Decoding
//  Copyright (c) 2001 Kyle Hammond. All rights reserved.
//  Original development by Dave Winer.
//
//  Put together by Michael Sedlaczek, Gone Coding on 2011-02-22
//

// Also see: http://stackoverflow.com/questions/4260108/encrypt-in-objective-c-decrypt-in-ruby-using-anything

#import "NSData+AESCrypt.h"
#import <CommonCrypto/CommonCryptor.h>
#import <CommonCrypto/CommonDigest.h>


static char encodingTable[64] = 
{
   'A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P',
   'Q','R','S','T','U','V','W','X','Y','Z','a','b','c','d','e','f',
   'g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v',
   'w','x','y','z','0','1','2','3','4','5','6','7','8','9','+','/'
};

@implementation NSData (AESCrypt)

- (NSData *)AES256EncryptWithKey:(NSString *)key
{
   // 'key' should be 32 bytes for AES256, will be null-padded otherwise
   char keyPtr[kCCKeySizeAES256 + 1]; // room for terminator (unused)
   bzero( keyPtr, sizeof( keyPtr ) ); // fill with zeroes (for padding)
   
   // fetch key data
   [key getCString:keyPtr maxLength:sizeof( keyPtr ) encoding:NSUTF8StringEncoding];
   
   NSUInteger dataLength = [self length];
   
   //See the doc: For block ciphers, the output size will always be less than or 
   //equal to the input size plus the size of one block.
   //That's why we need to add the size of one block here
   size_t bufferSize = dataLength + kCCBlockSizeAES128;
   void *buffer = malloc( bufferSize );
   
   size_t numBytesEncrypted = 0;
   CCCryptorStatus cryptStatus = CCCrypt( kCCEncrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding,
                                          keyPtr, kCCKeySizeAES256,
                                          NULL /* initialization vector (optional) */,
                                          [self bytes], dataLength, /* input */
                                          buffer, bufferSize, /* output */
                                          &numBytesEncrypted );
   if( cryptStatus == kCCSuccess )
   {
      //the returned NSData takes ownership of the buffer and will free it on deallocation
      return [NSData dataWithBytesNoCopy:buffer length:numBytesEncrypted];
   }
   
   free( buffer ); //free the buffer
   return nil;
}

- (NSData *)AES256DecryptWithKey:(NSString *)key
{
   // 'key' should be 32 bytes for AES256, will be null-padded otherwise
   char keyPtr[kCCKeySizeAES256+1]; // room for terminator (unused)
   bzero( keyPtr, sizeof( keyPtr ) ); // fill with zeroes (for padding)
   
   // fetch key data
   [key getCString:keyPtr maxLength:sizeof( keyPtr ) encoding:NSUTF8StringEncoding];
   
   NSUInteger dataLength = [self length];
   
   //See the doc: For block ciphers, the output size will always be less than or 
   //equal to the input size plus the size of one block.
   //That's why we need to add the size of one block here
   size_t bufferSize = dataLength + kCCBlockSizeAES128;
   void *buffer = malloc( bufferSize );
   
   size_t numBytesDecrypted = 0;
   CCCryptorStatus cryptStatus = CCCrypt( kCCDecrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding,
                                          keyPtr, kCCKeySizeAES256,
                                          NULL /* initialization vector (optional) */,
                                          [self bytes], dataLength, /* input */
                                          buffer, bufferSize, /* output */
                                          &numBytesDecrypted );
   
   if( cryptStatus == kCCSuccess )
   {
      //the returned NSData takes ownership of the buffer and will free it on deallocation
      return [NSData dataWithBytesNoCopy:buffer length:numBytesDecrypted];
   }
   
   free( buffer ); //free the buffer
   return nil;
}

#pragma mark -

+ (NSData *)dataWithBase64EncodedString:(NSString *)string
{
   return [[NSData allocWithZone:nil] initWithBase64EncodedString:string];
}

- (id)initWithBase64EncodedString:(NSString *)string
{
   NSMutableData *mutableData = nil;
   
   if( string )
   {
      unsigned long ixtext = 0;
      unsigned long lentext = 0;
      unsigned char ch = 0;
      unsigned char inbuf[4], outbuf[3];
      short i = 0, ixinbuf = 0;
      BOOL flignore = NO;
      BOOL flendtext = NO;
      NSData *base64Data = nil;
      const unsigned char *base64Bytes = nil;
      
      // Convert the string to ASCII data.
      base64Data = [string dataUsingEncoding:NSASCIIStringEncoding];
      base64Bytes = [base64Data bytes];
      mutableData = [NSMutableData dataWithCapacity:base64Data.length];
      lentext = base64Data.length;
      
      while( YES )
      {
         if( ixtext >= lentext ) break;
         ch = base64Bytes[ixtext++];
         flignore = NO;
         
         if( ( ch >= 'A' ) && ( ch <= 'Z' ) ) ch = ch - 'A';
         else if( ( ch >= 'a' ) && ( ch <= 'z' ) ) ch = ch - 'a' + 26;
         else if( ( ch >= '0' ) && ( ch <= '9' ) ) ch = ch - '0' + 52;
         else if( ch == '+' ) ch = 62;
         else if( ch == '=' ) flendtext = YES;
         else if( ch == '/' ) ch = 63;
         else flignore = YES;
         
         if( ! flignore )
         {
            short ctcharsinbuf = 3;
            BOOL flbreak = NO;
            
            if( flendtext ) 
            {
               if( ! ixinbuf ) break;
               if( ( ixinbuf == 1 ) || ( ixinbuf == 2 ) ) ctcharsinbuf = 1;
               else ctcharsinbuf = 2;
               ixinbuf = 3;
               flbreak = YES;
            }
            
            inbuf [ixinbuf++] = ch;
            
            if( ixinbuf == 4 ) 
            {
               ixinbuf = 0;
               outbuf [0] = ( inbuf[0] << 2 ) | ( ( inbuf[1] & 0x30) >> 4 );
               outbuf [1] = ( ( inbuf[1] & 0x0F ) << 4 ) | ( ( inbuf[2] & 0x3C ) >> 2 );
               outbuf [2] = ( ( inbuf[2] & 0x03 ) << 6 ) | ( inbuf[3] & 0x3F );
               
               for( i = 0; i < ctcharsinbuf; i++ )
                  [mutableData appendBytes:&outbuf[i] length:1];
            }
            
            if( flbreak )  break;
         }
      }
   }
   
   self = [self initWithData:mutableData];
   return self;
}

#pragma mark -

- (NSString *)base64Encoding
{
   return [self base64EncodingWithLineLength:0];
}

- (NSString *)base64EncodingWithLineLength:(NSUInteger)lineLength
{
   const unsigned char   *bytes = [self bytes];
   NSMutableString *result = [NSMutableString stringWithCapacity:self.length];
   unsigned long ixtext = 0;
   unsigned long lentext = self.length;
   long ctremaining = 0;
   unsigned char inbuf[3], outbuf[4];
   unsigned short i = 0;
   unsigned short charsonline = 0, ctcopy = 0;
   unsigned long ix = 0;
   
   while( YES )
   {
      ctremaining = lentext - ixtext;
      if( ctremaining <= 0 ) break;
      
      for( i = 0; i < 3; i++ )
      {
         ix = ixtext + i;
         if( ix < lentext ) inbuf[i] = bytes[ix];
         else inbuf [i] = 0;
      }
      
      outbuf [0] = (inbuf [0] & 0xFC) >> 2;
      outbuf [1] = ((inbuf [0] & 0x03) << 4) | ((inbuf [1] & 0xF0) >> 4);
      outbuf [2] = ((inbuf [1] & 0x0F) << 2) | ((inbuf [2] & 0xC0) >> 6);
      outbuf [3] = inbuf [2] & 0x3F;
      ctcopy = 4;
      
      switch( ctremaining )
      {
         case 1:
            ctcopy = 2;
            break;
         case 2:
            ctcopy = 3;
            break;
      }
      
      for( i = 0; i < ctcopy; i++ )
         [result appendFormat:@"%c", encodingTable[outbuf[i]]];
      
      for( i = ctcopy; i < 4; i++ )
         [result appendString:@"="];
      
      ixtext += 3;
      charsonline += 4;
      
      if( lineLength > 0 )
      {
         if( charsonline >= lineLength )
         {
            charsonline = 0;
            [result appendString:@"\n"];
         }
      }
   }
   
   return [NSString stringWithString:result];
}

#pragma mark -

- (BOOL)hasPrefixBytes:(const void *)prefix length:(NSUInteger)length
{
   if( ! prefix || ! length || self.length < length ) return NO;
   return ( memcmp( [self bytes], prefix, length ) == 0 );
}

- (BOOL)hasSuffixBytes:(const void *)suffix length:(NSUInteger)length
{
   if( ! suffix || ! length || self.length < length ) return NO;
   return ( memcmp( ((const char *)[self bytes] + (self.length - length)), suffix, length ) == 0 );
}

@end





@implementation NSData( Crypto )

- (NSData *) aesEncryptedDataWithKey:(NSData *) key {
    unsigned char               *buffer = nil;
    size_t                      bufferSize;
    CCCryptorStatus             err;
    NSUInteger                  i, keyLength, plainTextLength;
    
    // make sure there's data to encrypt
    err = ( plainTextLength = [self length] ) == 0;
    
    // pass the user's passphrase through SHA256 to obtain 32 bytes
    // of key data.  Use all 32 bytes for an AES256 key or just the
    // first 16 for AES128.
    if ( ! err ) {
        switch ( ( keyLength = [key length] ) ) {
            case kCCKeySizeAES128:
            case kCCKeySizeAES256:                      break;
                
                // invalid key size
            default:                    err = 1;        break;
        }
    }
    
    // create an output buffer with room for pad bytes
    if ( ! err ) {
        bufferSize = kCCBlockSizeAES128 + plainTextLength + kCCBlockSizeAES128;     // iv + cipher + padding
        
        err = ! ( buffer = (unsigned char *) malloc( bufferSize ) );
    }
    
    // encrypt the data
    if ( ! err ) {
        srandomdev();
        
        // generate a random iv and prepend it to the output buffer.  the
        // decryptor needs to be aware of this.
        for ( i = 0; i < kCCBlockSizeAES128; ++i ) buffer[ i ] = random() & 0xff;
        
        err = CCCrypt( kCCEncrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding,
                      [key bytes], keyLength, buffer, [self bytes], plainTextLength,
                      buffer + kCCBlockSizeAES128, bufferSize - kCCBlockSizeAES128, &bufferSize );
    }
    
    if ( err ) {
        if ( buffer ) free( buffer );
        
        return nil;
    }
    
    // dataWithBytesNoCopy takes ownership of buffer and will free() it
    // when the NSData object that owns it is released.
    return [NSData dataWithBytesNoCopy: buffer length: bufferSize + kCCBlockSizeAES128];
}

- (NSString *) base64Encoding {
    char                    *encoded, *r;
    const char              eTable[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    unsigned                i, l, n, t;
    UInt8                   *p, pad = '=';
    NSString                *result;
    
    p = (UInt8 *) [self bytes];
    if ( ! p || ( l = [self length] ) == 0 ) return @"";
    r = encoded = malloc( 4 * ( ( n = l / 3 ) + ( l % 3 ? 1 : 0 ) ) + 1 );
    
    if ( ! encoded ) return nil;
    
    for ( i = 0; i < n; ++i ) {
        t  = *p++ << 16;
        t |= *p++ << 8;
        t |= *p++;
        
        *r++ = eTable[ t >> 18 ];
        *r++ = eTable[ t >> 12 & 0x3f ];
        *r++ = eTable[ t >>  6 & 0x3f ];
        *r++ = eTable[ t       & 0x3f ];
    }
    
    if ( ( i = n * 3 ) < l ) {
        t = *p++ << 16;
        
        *r++ = eTable[ t >> 18 ];
        
        if ( ++i < l ) {
            t |= *p++ << 8;
            
            *r++ = eTable[ t >> 12 & 0x3f ];
            *r++ = eTable[ t >>  6 & 0x3f ];
        } else {
            *r++ = eTable[ t >> 12 & 0x3f ];
            *r++ = pad;
        }
        
        *r++ = pad;
    }
    
    *r = 0;
    
    result = [NSString stringWithUTF8String: encoded];
    
    free( encoded );
    
    return result;
}

@end
