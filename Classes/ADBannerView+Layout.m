//
//  ADBannerView+Layout.m
//  FlashCards
//
//  Created by Jason Lustig on 12/5/13.
//  Copyright (c) 2013 Jason Lustig. All rights reserved.
//

#import "ADBannerView+Layout.h"

@implementation ADBannerView (Layout)

- (BOOL)isDisplayed {
    return (self.alpha == 1.0f);
}
- (void)hide {
    [self setAlpha:0.0f];
    /*
    int y = abs(self.frame.origin.y) * -1;
    if (y == 0) {
        y = -10;
    }
    [self setFrame:CGRectMake(self.frame.origin.x,
                              y,
                              self.frame.size.width,
                              self.frame.size.height)];
     */
}
- (void)show {
    [self setAlpha:1.0f];
    /*
    int y = abs(self.frame.origin.y);
    if (y == -10) {
        y = 0;
    }
    [self setFrame:CGRectMake(self.frame.origin.x,
                              y,
                              self.frame.size.width,
                              self.frame.size.height)];
     */
}

@end
