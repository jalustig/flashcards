//
//  UIView+Layout.m
//  FlashCards
//
//  Created by Jason Lustig on 4/13/11.
//  Copyright 2011-2014 Jason Lustig Lustig. All rights reserved.
//

#import "UIView+Layout.h"
#import "Swipeable.h"

@implementation UIView(Layout)

- (CGFloat)webviewContentHeight:(UIWebView*)aWebView {
    /*
     // as per: http://stackoverflow.com/a/3937599/353137
     CGRect frame = aWebView.frame;
     frame.size.height = 1;
     aWebView.frame = frame;
     CGSize fittingSize = [aWebView sizeThatFits:CGSizeZero];
     frame.size = fittingSize;
     aWebView.frame = frame;
     
     NSLog(@"New size: %f, %f", fittingSize.width, fittingSize.height);
     */
    
    // CGFloat heightT = [[aWebView stringByEvaluatingJavaScriptFromString:@"document.getElementById('mathTable').offsetHeight"] floatValue];
    // CGFloat widthT = [[aWebView stringByEvaluatingJavaScriptFromString:@"document.getElementById('mathTable').offsetWidth"] floatValue];

    // as per: http://stackoverflow.com/a/13096183/353137
    aWebView.scrollView.scrollEnabled = NO;    // Property available in iOS 5.0 and later
    CGRect frame = CGRectMake(aWebView.frame.origin.x,
                              aWebView.frame.origin.y,
                              aWebView.frame.size.width,
                              aWebView.frame.size.height);
    CGRect originalFrame = CGRectMake(frame.origin.x,
                                      frame.origin.y,
                                      frame.size.width,
                                      frame.size.height);
    
    // Your desired width here.
    frame.size.width = aWebView.frame.size.width;
    
    // Set the height to a small one.
    frame.size.height = 1;
    
    // Set webView's Frame, forcing the Layout of its embedded scrollView with current Frame's constraints (Width set above).
    aWebView.frame = frame;
    
    // CGSize fittingSize = [aWebView sizeThatFits:frame.size];
    // frame.size = fittingSize;
    
    // CGFloat height = [[aWebView stringByEvaluatingJavaScriptFromString:@"document.height"] floatValue];
    // CGFloat width = [[aWebView stringByEvaluatingJavaScriptFromString:@"document.width"] floatValue];

    // Get the corresponding height from the webView's embedded scrollView.
    frame.size.height = aWebView.scrollView.contentSize.height;

    // Set the scrollView contentHeight back to the frame itself.
    aWebView.frame = originalFrame;
    
    return frame.size.height;
}

-(float)heightOfSubviews {
    return [self heightOfSubviewsExcept:@[]];
}
-(float)heightOfSubviewsExcept:(NSArray *)exclude {
    UIView *sview;
    CGFloat topPosition, bottomPosition;
    CGFloat minTopPosition = 100000, maxBottomPosition = 0;
    // NSLog(@"%@", self.subviews);
    for (int i = 0; i < [[self subviews] count]; i++) {
        sview = [[self subviews] objectAtIndex:i];
        if ([sview isHidden]) {
            continue;
        }
        if ([exclude containsObject:sview]) {
            continue;
        }
        if ([sview isKindOfClass:[UILabel class]] && ![sview isKindOfClass:[SwipeableLabel class]]) {
            continue;
        }
        if ([sview isKindOfClass:[UIImageView class]] && ![sview isKindOfClass:[SwipeableImageView class]]) {
            continue;
        }
        // if it's a webview, then we need to know 
        if ([sview isMemberOfClass:[UIWebView class]]) {
            topPosition = sview.frame.origin.y;
            bottomPosition = sview.frame.origin.y + [self webviewContentHeight:(UIWebView*)sview];
        } else if ([sview isMemberOfClass:[UIImageView class]]) {
            // If it is a UIImageView, then SKIP IT:
            continue;
        } else if ([sview isMemberOfClass:[SwipeableView class]]) {
            topPosition = sview.frame.origin.y;
            bottomPosition = sview.frame.origin.y + [sview heightOfSubviews];
        } else {
            topPosition = sview.frame.origin.y;
            bottomPosition = sview.frame.origin.y + sview.frame.size.height;
        }
        if (topPosition < minTopPosition) {
            minTopPosition = topPosition;
        }
        if (bottomPosition > maxBottomPosition) {
            maxBottomPosition = bottomPosition;
        }
    }
    float height = (float)(maxBottomPosition - minTopPosition);
    if (height < 0.0f) {
        height = 0.0f;
    }
    return height;
}

-(void) setPositionBehind:(UIView *)prevView orSetY:(int)y {
    if (prevView) {
        [self setPositionBehind:prevView];
    } else {
        [self setPositionY:y];
    }

}

-(void) setPositionBehind:(UIView *)prevView distance:(int)distance {
    if (!prevView) {
        [self setPositionZero];
        return;
    }
    
    CGRect myFrame;
    myFrame = prevView.frame;
    myFrame.size.height = myFrame.size.height + distance;
    [prevView setFrame:myFrame];
    
    myFrame = self.frame;
    myFrame.origin.y = prevView.frame.origin.y + prevView.frame.size.height;
    [self setFrame:myFrame];
}

-(void) setPositionBehind:(UIView*)prevView {
    [self setPositionBehind:prevView distance:10];
}

-(void) setPositionZero {
    CGRect myFrame = self.frame;
    myFrame.origin.y = 0.0;
    [self setFrame:myFrame];
}

-(void) setPositionHidden {
    CGRect myFrame = self.frame;
    myFrame.size.height = 0.0;
    myFrame.origin.y = 0.0;
    [self setFrame:myFrame];
}

-(void) setPositionY:(float)y {
    CGRect myFrame = self.frame;
    myFrame.origin.y = y;
    [self setFrame:myFrame];
}

-(void) setPositionHeight:(float)h {
    CGRect myFrame = self.frame;
    myFrame.size.height = h;
    [self setFrame:myFrame];
}

-(void) setPositionWidth:(float)w {
    CGRect myFrame = self.frame;
    myFrame.size.width = w;
    [self setFrame:myFrame];
}

@end


@implementation UIToolbar (Layout)

// as per: http://stackoverflow.com/questions/2994354/figure-out-uibarbuttonitem-frame-in-window
-(float) widthOfSubviews {
    float totalWidth = 0.0;
    for (UIControl* btn in self.subviews) {
        if ([btn isKindOfClass:[UIControl class]]) {
            totalWidth += btn.frame.size.width;
            totalWidth += 8;
        }
    }
    return totalWidth;
}

@end

