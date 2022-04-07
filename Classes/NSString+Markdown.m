//
//  NSString+Markdown.m
//  FlashCards
//
//  Created by Jason Lustig on 2/7/13.
//  Copyright (c) 2013 Jason Lustig. All rights reserved.
//

#import "NSString+Markdown.h"

#import "markdown.h"
#import "html.h"
#import "buffer.h"

#import "NSString+HTML.h"

#import "DTCoreText.h"

#import <OHAttributedStringAdditions/OHAttributedStringAdditions.h>

@implementation NSString (Markdown)

- (NSString*) toSimpleHtml {
    int extensions = 0;
    extensions = extensions | MKDEXT_NO_INTRA_EMPHASIS;
    return [self toHtmlWIthExtensions:extensions];
}

- (NSString*) toHtml {
    
    int extensions = 0;
    // extensions = extensions | MKDEXT_LAX_SPACING;
    extensions = extensions | MKDEXT_STRIKETHROUGH;
    extensions = extensions | MKDEXT_NO_INTRA_EMPHASIS;
    extensions = extensions | MKDEXT_SPACE_HEADERS;
    extensions = extensions | MKDEXT_SUPERSCRIPT;
    extensions = extensions | MKDEXT_AUTOLINK;

    return [self toHtmlWIthExtensions:extensions];
}
- (NSString*)toHtmlWIthExtensions:(int)extensions {
    const char * prose = [self UTF8String];
    struct buf *ib, *ob;
    
    int length = [self lengthOfBytesUsingEncoding:NSUTF8StringEncoding] + 1;
    
    ib = bufnew(length);
    bufgrow(ib, length);
    memcpy(ib->data, prose, length);
    ib->size = length;
    
    ob = bufnew(64);
    
    struct sd_callbacks callbacks;
    struct html_renderopt options;
    struct sd_markdown *markdown;
    
    sdhtml_renderer(&callbacks, &options, 0);
    markdown = sd_markdown_new(extensions, 16, &callbacks, &options);
    
    sd_markdown_render(ob, ib->data, ib->size, markdown);
    sd_markdown_free(markdown);
    
    
    NSString *shinyNewHTML = [NSString stringWithUTF8String: ob->data];
    
    bufrelease(ib);
    bufrelease(ob);
    
    return shinyNewHTML;

}

- (NSMutableAttributedString *)attributedStringUsingiOS6Attributes:(BOOL)useiOS6Attributes {
    return [self attributedStringWithFont:[UIFont systemFontOfSize:12] useiOS6Attributes:useiOS6Attributes useMarkdown:YES];
}

- (NSMutableAttributedString *)attributedStringWithFont:(UIFont*)font useiOS6Attributes:(BOOL)useiOS6Attributes useMarkdown:(BOOL)useMarkdown {
    // Load HTML data
    NSString *encoded = [self stringByEncodingHTMLEntities];
    NSString *html;
    if (useMarkdown) {
        html = [encoded toHtml];
    } else {
        html = encoded;
    }
    
    // NSLog(@"%@", html);
    NSData *data = [html dataUsingEncoding:NSUTF8StringEncoding];
    
    // Create attributed string from HTML
    UIViewController *vc = [FlashCardsCore currentViewController];
    CGSize maxImageSize = CGSizeMake(vc.view.bounds.size.width - 20.0,
                                     vc.view.bounds.size.height - 20.0);
    
    // example for setting a willFlushCallback, that gets called before elements are written to the generated attributed string
    void (^callBackBlock)(DTHTMLElement *element) = ^(DTHTMLElement *element) {
        // if an element is larger than twice the font size put it in it's own block
        if (element.displayStyle == DTHTMLElementDisplayStyleInline && element.textAttachment.displaySize.height > 2.0 * element.fontDescriptor.pointSize)
        {
            element.displayStyle = DTHTMLElementDisplayStyleBlock;
        }
    };
    
    float multiplier = [font pointSize] / 12.0f;
    NSString *fontName = [font familyName];
    
    NSMutableDictionary *options = [NSMutableDictionary dictionaryWithDictionary:
                                    @{
                                                                 DTMaxImageSize : [NSValue valueWithCGSize:maxImageSize],
                                                             DTDefaultLinkColor : @"purple",
                                                            DTDefaultFontFamily : fontName,
                                             NSTextSizeMultiplierDocumentOption : [NSNumber numberWithFloat:multiplier],
                                                       DTWillFlushBlockCallBack : callBackBlock
                                    
                                    }];
    
    if (useiOS6Attributes) {
        [options setObject:@YES
                    forKey:DTUseiOS6Attributes];
    }
    
    NSAttributedString *string = [[NSAttributedString alloc] initWithHTMLData:data options:options documentAttributes:NULL];
    NSMutableAttributedString *mString = [[NSMutableAttributedString alloc] initWithAttributedString:string];
    // [mString setFont:font];
    return mString;
}

@end
