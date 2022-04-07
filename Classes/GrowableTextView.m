//
//  GrowableTextView.m
//  FlashCards
//
//  Created by Jason Lustig on 4/15/11.
//  Copyright 2011-2014 Jason Lustig Lustig. All rights reserved.
//

#import "GrowableTextView.h"

// as per http://stackoverflow.com/questions/1178010/how-to-stop-uitextview-from-scrolling-up-when-entering-it/1864205#1864205
@implementation GrowableTextView

@synthesize indexPath;

- (UIEdgeInsets) contentInset { return UIEdgeInsetsZero; }

- (void) setDelegate:(id<UITextViewDelegate>)delegate {
    [super setDelegate:delegate];
}

- (CGSize)textViewSize {
    float fudgeFactor = 16.0;
    CGSize tallerSize = CGSizeMake(self.frame.size.width-fudgeFactor, kMaxFieldHeight);
    NSMutableString *testString = [NSMutableString stringWithString:@" "];
    if ([self.text length] > 0) {
        testString = [NSMutableString stringWithString:self.text];
    }
    if ([testString hasSuffix:@"\n"]) {
        [testString appendString:@"s"];
    }
    CGSize stringSize;
    
    CGRect boundingRect = [testString boundingRectWithSize:tallerSize
                                                   options:NSStringDrawingUsesLineFragmentOrigin
                                                attributes:@{NSFontAttributeName:self.font}
                                                   context:nil];
    stringSize = boundingRect.size;
    return stringSize;
}

- (void) setTextViewSize {
    CGSize stringSize = [self textViewSize];
    if (stringSize.height != self.frame.size.height) {
        [self setFrame:CGRectMake(self.frame.origin.x,
                                  self.frame.origin.y,
                                  self.frame.size.width,
                                  stringSize.height+10)];
    }
}

@end

