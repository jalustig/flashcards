//
//  NSData+MD5.h
//  FlashCards
//
//  Created by Jason Lustig on 10/21/12.
//  Copyright (c) 2012 Jason Lustig. All rights reserved.
//

#import <Foundation/Foundation.h>

// see: http://stackoverflow.com/questions/1524604/md5-algorithm-in-objective-c

@interface NSString (MD5)
- (NSString *) md5;
@end

@interface NSData (MD5)
- (NSString*)md5;
@end
