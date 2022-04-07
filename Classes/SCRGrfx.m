//
//  SCRGrfx.m
//  TouchCustoms
//
//  Created by Aleks Nesterow on 10/15/09.
//  aleks.nesterow@gmail.com
//  
//  Copyright © 2009-2010 Screen Customs s.r.o.
//  All rights reserved.
//

#import "SCRGrfx.h"

SCRRoundedRect SCRRoundedRectMake(CGRect rect, CGFloat cornerRadius) {

    SCRRoundedRect result;
    
    result.xLeft = CGRectGetMinX(rect);
    result.xLeftCorner = result.xLeft + cornerRadius;
    
    result.xRight = CGRectGetMaxX(rect);
    result.xRightCorner = result.xRight - cornerRadius;
    
    result.yTop = CGRectGetMinY(rect);
    result.yTopCorner = result.yTop + cornerRadius;
    
    result.yBottom = CGRectGetMaxY(rect);
    result.yBottomCorner = result.yBottom - cornerRadius;
    
    return result;
}

void SCRContextAddRoundedRect(CGContextRef c, CGRect rect, CGFloat cornerRadius) {
    
    SCRRoundedRect roundedRect = SCRRoundedRectMake(rect, cornerRadius);
    
    /* Begin */
    CGContextBeginPath(c);
    CGContextMoveToPoint(c, roundedRect.xLeft, roundedRect.yTopCorner);
    
    /* First corner */
    CGContextAddArcToPoint(c, roundedRect.xLeft, roundedRect.yTop, roundedRect.xLeftCorner, roundedRect.yTop, cornerRadius);
    CGContextAddLineToPoint(c, roundedRect.xRightCorner, roundedRect.yTop);
    
    /* Second corner */
    CGContextAddArcToPoint(c, roundedRect.xRight, roundedRect.yTop, roundedRect.xRight, roundedRect.yTopCorner, cornerRadius);
    CGContextAddLineToPoint(c, roundedRect.xRight, roundedRect.yBottomCorner);
    
    /* Third corner */
    CGContextAddArcToPoint(c, roundedRect.xRight, roundedRect.yBottom, roundedRect.xRightCorner, roundedRect.yBottom, cornerRadius);
    CGContextAddLineToPoint(c, roundedRect.xLeftCorner, roundedRect.yBottom);
    
    /* Fourth corner */
    CGContextAddArcToPoint(c, roundedRect.xLeft, roundedRect.yBottom, roundedRect.xLeft, roundedRect.yBottomCorner, cornerRadius);
    CGContextAddLineToPoint(c, roundedRect.xLeft, roundedRect.yTopCorner);
    
    /* Done */
    CGContextClosePath(c);
}

void SCRContextAddLeftRoundedRect(CGContextRef c, CGRect rect, CGFloat radius) {

    SCRRoundedRect roundedRect = SCRRoundedRectMake(rect, radius);
    
    CGContextBeginPath(c);
    CGContextMoveToPoint(c, roundedRect.xLeft, roundedRect.yTopCorner);
    
    CGContextAddArcToPoint(c, roundedRect.xLeft, roundedRect.yTop, roundedRect.xLeftCorner, roundedRect.yTop, radius);
    
    CGContextAddLineToPoint(c, roundedRect.xRight, roundedRect.yTop);
    CGContextAddLineToPoint(c, roundedRect.xRight, roundedRect.yBottom);
    CGContextAddLineToPoint(c, roundedRect.xLeftCorner, roundedRect.yBottom);
    
    CGContextAddArcToPoint(c, roundedRect.xLeft, roundedRect.yBottom, roundedRect.xLeft, roundedRect.yBottomCorner, radius);
    
    CGContextClosePath(c);
}

void SCRContextAddLeftTopRoundedRect(CGContextRef c, CGRect rect, CGFloat radius) {
    
    SCRRoundedRect roundedRect = SCRRoundedRectMake(rect, radius);
    
    CGContextBeginPath(c);
    CGContextMoveToPoint(c, roundedRect.xLeft, roundedRect.yTopCorner);
    
    CGContextAddArcToPoint(c, roundedRect.xLeft, roundedRect.yTop, roundedRect.xLeftCorner, roundedRect.yTop, radius);
    
    CGContextAddLineToPoint(c, roundedRect.xRight, roundedRect.yTop);
    CGContextAddLineToPoint(c, roundedRect.xRight, roundedRect.yBottom);
    CGContextAddLineToPoint(c, roundedRect.xLeft, roundedRect.yBottom);
    
    CGContextClosePath(c);
}

void SCRContextAddLeftBottomRoundedRect(CGContextRef c, CGRect rect, CGFloat radius) {

    SCRRoundedRect roundedRect = SCRRoundedRectMake(rect, radius);
    
    CGContextBeginPath(c);
    CGContextMoveToPoint(c, roundedRect.xLeft, roundedRect.yTop);
    
    CGContextAddLineToPoint(c, roundedRect.xRight, roundedRect.yTop);
    CGContextAddLineToPoint(c, roundedRect.xRight, roundedRect.yBottom);
    CGContextAddLineToPoint(c, roundedRect.xLeftCorner, roundedRect.yBottom);
    
    CGContextAddArcToPoint(c, roundedRect.xLeft, roundedRect.yBottom, roundedRect.xLeft, roundedRect.yBottomCorner, radius);
    
    CGContextClosePath(c);
}

void SCRContextAddRightRoundedRect(CGContextRef c, CGRect rect, CGFloat radius) {

    SCRRoundedRect roundedRect = SCRRoundedRectMake(rect, radius);
    
    CGContextBeginPath(c);
    CGContextMoveToPoint(c, roundedRect.xLeft, roundedRect.yTop);
    
    CGContextAddLineToPoint(c, roundedRect.xRightCorner, roundedRect.yTop);
    CGContextAddArcToPoint(c, roundedRect.xRight, roundedRect.yTop, roundedRect.xRight, roundedRect.yTopCorner, radius);
    CGContextAddLineToPoint(c, roundedRect.xRight, roundedRect.yBottomCorner);
    CGContextAddArcToPoint(c, roundedRect.xRight, roundedRect.yBottom, roundedRect.xRightCorner, roundedRect.yBottom, radius);
    CGContextAddLineToPoint(c, roundedRect.xLeft, roundedRect.yBottom);
    
    CGContextClosePath(c);
}

void SCRContextAddRightTopRoundedRect(CGContextRef c, CGRect rect, CGFloat radius) {
    
    SCRRoundedRect roundedRect = SCRRoundedRectMake(rect, radius);
    
    CGContextBeginPath(c);
    CGContextMoveToPoint(c, roundedRect.xLeft, roundedRect.yTop);
    
    CGContextAddLineToPoint(c, roundedRect.xRightCorner, roundedRect.yTop);
    CGContextAddArcToPoint(c, roundedRect.xRight, roundedRect.yTop, roundedRect.xRight, roundedRect.yTopCorner, radius);
    CGContextAddLineToPoint(c, roundedRect.xRight, roundedRect.yBottom);
    CGContextAddLineToPoint(c, roundedRect.xLeft, roundedRect.yBottom); 
    
    CGContextClosePath(c);
}

void SCRContextAddRightBottomRoundedRect(CGContextRef c, CGRect rect, CGFloat radius) {
    
    SCRRoundedRect roundedRect = SCRRoundedRectMake(rect, radius);
    
    CGContextBeginPath(c);
    CGContextMoveToPoint(c, roundedRect.xLeft, roundedRect.yTop);
    
    CGContextAddLineToPoint(c, roundedRect.xRight, roundedRect.yTop);
    CGContextAddLineToPoint(c, roundedRect.xRight, roundedRect.yBottomCorner);
    CGContextAddArcToPoint(c, roundedRect.xRight, roundedRect.yBottom, roundedRect.xRightCorner, roundedRect.yBottom, radius);
    CGContextAddLineToPoint(c, roundedRect.xLeft, roundedRect.yBottom);
    
    CGContextClosePath(c);
}
