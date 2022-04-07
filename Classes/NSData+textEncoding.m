//
//  NSData+textEncoding.m
//  FlashCards
//
//  Created by Jason Lustig on 1/11/13.
//  Copyright (c) 2013 Jason Lustig. All rights reserved.
//

#import "NSData+textEncoding.h"

@implementation NSData (textEncoding)

- (NSStringEncoding) textEncoding {
    NSUInteger length = [self length];
    NSStringEncoding encoding = NSUTF8StringEncoding;
    
    if (length > 0) {
        UInt8* bytes = (UInt8*)[self bytes];
        encoding = CFStringConvertEncodingToNSStringEncoding(CFStringGetSystemEncoding());
        switch (bytes[0]) {
            case 0x00:
                if (length>3 && bytes[1]==0x00 && bytes[2]==0xFE && bytes[3]==0xFF) {
                    encoding = NSUTF32BigEndianStringEncoding;
                }
                break;
            case 0xEF:
                if (length>2 && bytes[1]==0xBB && bytes[2]==0xBF) {
                    encoding = NSUTF8StringEncoding;
                }
                break;
            case 0xFE:
                if (length>1 && bytes[1]==0xFF) {
                    encoding = NSUTF16BigEndianStringEncoding;
                }
                break;
            case 0xFF:
                if (length>1 && bytes[1]==0xFE) {
                    if (length>3 && bytes[2]==0x00 && bytes[3]==0x00) {
                        encoding = NSUTF32LittleEndianStringEncoding;
                    } else {
                        encoding = NSUTF16LittleEndianStringEncoding;
                    }
                }
                break;
            default:
                encoding = NSUTF8StringEncoding; // fall back on UTF8
                break;
        }
    }
    // for more encodings see: https://developer.apple.com/library/mac/#documentation/Cocoa/Reference/Foundation/Classes/NSString_Class/Reference/NSString.html
    /*
     NSISOLatin1StringEncoding = 5,
     NSSymbolStringEncoding = 6,
     NSNonLossyASCIIStringEncoding = 7,
     NSShiftJISStringEncoding = 8,
     NSISOLatin2StringEncoding = 9,
     NSUnicodeStringEncoding = 10,
     NSWindowsCP1251StringEncoding = 11,
     NSWindowsCP1252StringEncoding = 12, // Microsoft Windows codepage 1252; equivalent to WinLatin1.
     NSWindowsCP1253StringEncoding = 13, // Microsoft Windows codepage 1253, encoding Greek characters.
     NSWindowsCP1254StringEncoding = 14, // Microsoft Windows codepage 1254, encoding Turkish characters.
     NSWindowsCP1250StringEncoding = 15, // Microsoft Windows codepage 1250; equivalent to WinLatin2.
     */
    NSString *dataStr;
    dataStr = [[NSString alloc] initWithData:self encoding:encoding];
    if (!dataStr) {
        encoding = NSASCIIStringEncoding;
        dataStr = [[NSString alloc] initWithData:self encoding:encoding];
        if (!dataStr) {
            encoding = NSMacOSRomanStringEncoding;
            dataStr = [[NSString alloc] initWithData:self encoding:encoding];
            if (!dataStr) {
                encoding = NSWindowsCP1252StringEncoding;
                dataStr = [[NSString alloc] initWithData:self encoding:encoding];
                if (!dataStr) {
                    encoding = NSWindowsCP1250StringEncoding;
                    dataStr = [[NSString alloc] initWithData:self encoding:encoding];
                    if (!dataStr) {
                        encoding = NSISOLatin1StringEncoding;
                        dataStr = [[NSString alloc] initWithData:self encoding:encoding];
                        if (!dataStr) {
                            encoding = NSISOLatin2StringEncoding;
                            dataStr = [[NSString alloc] initWithData:self encoding:encoding];
                        }
                    }
                }
            }
        }
    }
    return encoding;
}

@end
