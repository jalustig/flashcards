//
//  SCRGrfx.h
//  TouchCustoms
//
//  Created by Aleks Nesterow on 10/15/09.
//  aleks.nesterow@gmail.com
//  
//  Copyright © 2009, Screen Customs s.r.o.
//  All rights reserved.
//  
//  Purpose
//    Contains extension methods for Core Graphics.
//

struct SCRRoundedRect {
    CGFloat xLeft, xLeftCorner;
    CGFloat xRight, xRightCorner;
    CGFloat yTop, yTopCorner;
    CGFloat yBottom, yBottomCorner;
};
typedef struct SCRRoundedRect SCRRoundedRect;

SCRRoundedRect SCRRoundedRectMake(CGRect, CGFloat);

void SCRContextAddRoundedRect(CGContextRef, CGRect, CGFloat);

void SCRContextAddLeftRoundedRect(CGContextRef, CGRect, CGFloat);
void SCRContextAddLeftTopRoundedRect(CGContextRef, CGRect, CGFloat);
void SCRContextAddLeftBottomRoundedRect(CGContextRef, CGRect, CGFloat);

void SCRContextAddRightRoundedRect(CGContextRef, CGRect, CGFloat);
void SCRContextAddRightTopRoundedRect(CGContextRef, CGRect, CGFloat);
void SCRContextAddRightBottomRoundedRect(CGContextRef, CGRect, CGFloat);
