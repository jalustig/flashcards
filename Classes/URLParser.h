//
//  URLParser.h
//  FlashCards
//
//  Created by Jason Lustig on 9/10/11.
//  Copyright 2011-2014 Jason Lustig Lustig. All rights reserved.
//

// as per: http://stackoverflow.com/questions/2225814/nsurl-pull-out-a-single-value-for-a-key-in-a-parameter-string

#import <Foundation/Foundation.h>

@interface URLParser : NSObject {
    NSArray *variables;
}

@property (nonatomic, strong) NSArray *variables;

- (id)initWithURLString:(NSString *)url;
- (NSString *)valueForVariable:(NSString *)varName;

@end
