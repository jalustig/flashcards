//
//  UIImage+Rotate.h
//  FlashCards
//
//  Created by Jason Lustig on 2/18/13.
//  Copyright (c) 2013 Jason Lustig. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIImage (Rotate)

- (UIImage *)imageRotatedByRadians:(CGFloat)radians;
- (UIImage *)imageRotatedByDegrees:(CGFloat)degrees;

@end
