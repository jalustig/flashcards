//
//  UIView+Layout.h
//  FlashCards
//
//  Created by Jason Lustig on 4/13/11.
//  Copyright 2011-2014 Jason Lustig Lustig. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface UIView (Layout)

-(float)heightOfSubviews;
-(float)heightOfSubviewsExcept:(NSArray*)exclude;
-(void) setPositionBehind:(UIView*)prevView orSetY:(int)y;
-(void) setPositionBehind:(UIView*)prevView distance:(int)distance;
-(void) setPositionBehind:(UIView*)prevView;
-(void) setPositionZero;
-(void) setPositionHidden;
-(void) setPositionY:(float)y;
-(void) setPositionHeight:(float)h;
-(void) setPositionWidth:(float)w;
- (CGFloat)webviewContentHeight:(UIWebView*)aWebView;

@end

@interface UIToolbar (Layout)

-(float)widthOfSubviews;

@end