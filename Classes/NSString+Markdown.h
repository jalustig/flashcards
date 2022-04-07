//
//  NSString+Markdown.h
//  FlashCards
//
//  Created by Jason Lustig on 2/7/13.
//  Copyright (c) 2013 Jason Lustig. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (Markdown)

- (NSString*) toSimpleHtml;
- (NSString*) toHtml;
- (NSMutableAttributedString *)attributedStringUsingiOS6Attributes:(BOOL)useiOS6Attributes;
- (NSMutableAttributedString *)attributedStringWithFont:(UIFont*)font useiOS6Attributes:(BOOL)useiOS6Attributes useMarkdown:(BOOL)useMarkdown;

@end
