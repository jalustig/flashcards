//
//  Swipeable.m
//  FlashCards
//
//  Created by Jason Lustig on 8/3/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import "Swipeable.h"
#import "CardEditViewController.h"

# pragma mark -
# pragma mark ResignableTableView

@implementation ResignableTableView

@synthesize resignObjectsOnTouchesEnded, superviewController;

-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesEnded:touches withEvent:event];
    [self.superview touchesEnded:touches withEvent:event];

    if (self.superviewController) {
        self.superviewController.canResignTextView = YES;
    }

    UIView *obj;
    for (int i = 0; i < [resignObjectsOnTouchesEnded count]; i++) {
        obj = [resignObjectsOnTouchesEnded objectAtIndex:i];
        [obj resignFirstResponder];
    }
} 

@end

# pragma mark -
# pragma mark NonSwipeableButton

@implementation NonSwipeableButton {
    
}


- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];
    
    // [self.superview touchesBegan:touches withEvent:event];
    
}
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesMoved:touches withEvent:event];
    
    // [self.superview touchesMoved:touches withEvent:event];
}

-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesEnded:touches withEvent:event];
    
    // [self.superview touchesEnded:touches withEvent:event];
    // if (self.nextResponder != nil && [self.nextResponder respondsToSelector:@selector(touchesEnded:withEvent:)]) {
    //     [self.nextResponder touchesEnded:touches withEvent:event];
    // }
} 

@end

# pragma mark -
# pragma mark SwipeableView

@implementation SwipeableView

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];
    
    [self.superview touchesBegan:touches withEvent:event];
    
}
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesMoved:touches withEvent:event];
    
    [self.superview touchesMoved:touches withEvent:event];
}

-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesEnded:touches withEvent:event];
    
    [self.superview touchesEnded:touches withEvent:event];
    if (self.nextResponder != nil && [self.nextResponder respondsToSelector:@selector(touchesEnded:withEvent:)]) {
        [self.nextResponder touchesEnded:touches withEvent:event];
    }
} 

-(void)touchesCancelled:(NSSet*)touches withEvent:(UIEvent*)event {
    [self.superview touchesCancelled:touches withEvent:event];
}

@end

# pragma mark -
# pragma mark SwipeableScrollView

@implementation SwipeableScrollView

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];
    
    [self.superview touchesBegan:touches withEvent:event];
    
}
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesMoved:touches withEvent:event];
    
    [self.superview touchesMoved:touches withEvent:event];
}

-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesEnded:touches withEvent:event];
    
    [self.superview touchesEnded:touches withEvent:event];
    if (self.nextResponder != nil && [self.nextResponder respondsToSelector:@selector(touchesEnded:withEvent:)]) {
        [self.nextResponder touchesEnded:touches withEvent:event];
    }
} 

-(void)touchesCancelled:(NSSet*)touches withEvent:(UIEvent*)event {
    [self.superview touchesCancelled:touches withEvent:event];
}

@end

# pragma mark -
# pragma mark SwipeableImageView

@implementation SwipeableImageView


- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesCancelled:touches withEvent:event];
    [self.superview touchesCancelled:touches withEvent:event];
}


- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];
    
    [self.superview touchesBegan:touches withEvent:event];
    
}
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesMoved:touches withEvent:event];
    
    [self.superview touchesMoved:touches withEvent:event];
}

-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesEnded:touches withEvent:event];
    
    [self.superview touchesEnded:touches withEvent:event];
} 

@end

# pragma mark -
# pragma mark SwipeableLabel

@implementation SwipeableLabel

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesCancelled:touches withEvent:event];
    [self.superview touchesCancelled:touches withEvent:event];
}


- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];
    
    [self.superview touchesBegan:touches withEvent:event];
    
}
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesMoved:touches withEvent:event];
    
    [self.superview touchesMoved:touches withEvent:event];
}

-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesEnded:touches withEvent:event];
    
    [self.superview touchesEnded:touches withEvent:event];
} 

@end

# pragma mark -
# pragma mark SwipeableTextView

@implementation SwipeableTextView

// as per http://stackoverflow.com/questions/1426731/how-disable-copy-cut-select-select-all-in-uitextview
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    [UIMenuController sharedMenuController].menuVisible = NO;
    if (action == @selector(paste:) || action == @selector(copy:) || action == @selector(select:) || action == @selector(selectAll:)) {
        return NO;
    }
    return [super canPerformAction:action withSender:sender];
}


// from http://stackoverflow.com/questions/2038975/resize-font-size-to-fill-uitextview
-(BOOL)sizeFontToFit:(NSString*)aString minSize:(float)aMinFontSize maxSize:(float)aMaxFontSize {   
    float fudgeFactor = 16.0;
    float fontSize = aMaxFontSize;
    
    self.font = [self.font fontWithSize:fontSize];
    
    CGSize tallerSize = CGSizeMake(self.frame.size.width-fudgeFactor, kMaxFieldHeight);
    CGSize stringSize = [aString sizeWithFont:self.font constrainedToSize:tallerSize lineBreakMode:NSLineBreakByWordWrapping];
    
    while (stringSize.height >= self.frame.size.height) {
        if (fontSize <= aMinFontSize) {
            // it just won't fit
            return NO;
        }
        
        fontSize -= 1.0;
        self.font = [self.font fontWithSize:fontSize];
        tallerSize = CGSizeMake(self.frame.size.width-fudgeFactor, kMaxFieldHeight);
        stringSize = [aString sizeWithFont:self.font constrainedToSize:tallerSize lineBreakMode:NSLineBreakByWordWrapping];
    }
    
    return YES; 
}


- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];
    
    [self.superview touchesBegan:touches withEvent:event];
    
}
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesMoved:touches withEvent:event];
    
    [self.superview touchesMoved:touches withEvent:event];
}

-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesEnded:touches withEvent:event];
    
    [self.superview touchesEnded:touches withEvent:event];
} 

@end

# pragma mark -
# pragma mark SwipeableTableView

@implementation SwipeableTableView

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];
    
    [self.superview touchesBegan:touches withEvent:event];
    
}
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesMoved:touches withEvent:event];
    
    [self.superview touchesMoved:touches withEvent:event];
}

-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesEnded:touches withEvent:event];
    
    [self.superview touchesEnded:touches withEvent:event];
} 

@end
