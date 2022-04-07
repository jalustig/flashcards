//
//  SCRSegment.m
//  TouchCustoms
//
//  Created by Aleks Nesterow on 1/26/10.
//    aleks.nesterow@gmail.com
//    
//  Copyright © 2010 Screen Customs s.r.o.
//    All rights reserved.
//

#import "SCRGrfx.h"
#import "SCRSegment.h"
#import "SCRMemoryManagement.h"

@interface SCRSegment (/* Private methods */) 

- (void)__initializeComponent:(SCRSegmentStyle)style;

@end

@interface SCRSegment (Drawing)

- (void)clipBackground:(CGContextRef)c;
- (void)clipForeground:(CGContextRef)c;
- (void)clipCore:(CGContextRef)c rect:(CGRect)rect;

@end

@implementation SCRSegment

@synthesize colorScheme = _colorScheme;
@synthesize selected = _selected;
@synthesize style = _style;
@synthesize titleLabel = _titleLabel;
@synthesize imageView = _imageView;

- (void)setSelected:(BOOL)value {
    
    if (_selected != value) {
        
        _selected = value;
        self.titleLabel.highlighted = _selected;
        [self setNeedsDisplay];
    }
}

- (void)setStyle:(SCRSegmentStyle)value {
    
    if (_style != value) {
        
        _style = value;
        [self setNeedsDisplay];
    }
}

+ (SCRSegment *)segmentWithStyle:(SCRSegmentStyle)style {
    
    return [[[SCRSegment alloc] initWithStyle:style] autorelease];
}

- (BOOL)isAccessibilityElement {
    return YES;
}

- (NSString*)accessibilityLabel {
    return self.titleLabel.text;
}

- (UIAccessibilityTraits) accessibilityTraits {
    UIAccessibilityTraits traits = UIAccessibilityTraitButton;
    if (self.selected) {
        traits = traits | UIAccessibilityTraitSelected;
    }
    return traits;
}
- (id)init {
    
    return [self initWithFrame:CGRectMake(0, 0, 100, 37)];
}

- (id)initWithStyle:(SCRSegmentStyle)style {
    
    return [self initWithStyle:style frame:CGRectMake(0, 0, 100, 37)];
}

- (id)initWithFrame:(CGRect)frame {
    
    return [self initWithStyle:SCRSegmentCenter frame:frame];
}

- (id)initWithStyle:(SCRSegmentStyle)style frame:(CGRect)frame {
    
    if ((self = [super initWithFrame:frame])) {
        
        [self __initializeComponent:style];
    }
    
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    
    if ((self = [super initWithCoder:decoder])) {
        
        [self __initializeComponent:SCRSegmentCenter];
    }
    
    return self;
}

- (void)dealloc {
    
    SCR_RELEASE_SAFELY(_titleLabel);
    
    [super dealloc];
}

- (void)__initializeComponent:(SCRSegmentStyle)style {
    
    _style = style;
    
    self.backgroundColor = [UIColor clearColor];
    
    _titleLabel = [[UILabel alloc] initWithFrame:self.bounds];
    _titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _titleLabel.backgroundColor = [UIColor clearColor];
    _titleLabel.textAlignment = NSTextAlignmentCenter;
    _titleLabel.textColor = [UIColor blackColor];
    _titleLabel.highlightedTextColor = [UIColor whiteColor];
    
    _imageView = [[UIImageView alloc] initWithFrame:self.bounds];
    _imageView.autoresizingMask = _titleLabel.autoresizingMask;
    _imageView.backgroundColor = [UIColor clearColor];
    _imageView.contentMode = UIViewContentModeCenter;
    
    [self addSubview:_titleLabel];
    [self addSubview:_imageView];
}

@end


#define kForeColorArraySize    16

static CGFloat _DefaultForeColor[kForeColorArraySize] = {
    /* Stop 1 */ .15, .36, .73, 1,
    /* Stop 2 */ .21, .49, .92, 1,
    /* Stop 3 */ .27, .53, .93, 1,
    /* Stop 4 */ .42, .65, .99, 1
};

static CGFloat _BlackOpaqueForeColor[kForeColorArraySize] = {    
    /* Stop 1 */ .01, .01, .01, 1,
    /* Stop 2 */ .11, .11, .11, 1,
    /* Stop 3 */ .16, .16, .16, 1,
    /* Stop 4 */ .29, .29, .29, 1
};

static CGFloat _BlueContrastForeColor[kForeColorArraySize] = {    
    /* Stop 1 */ .37, .37, .37, 1,
    /* Stop 2 */ .196, .196, .196, 1,
    /* Stop 3 */ .196, .196, .196, 1,
    /* Stop 4 */ .02, .02, .02, 1
};

#define kBorderWidth            1.
#define kCornerRadius            10.
#define kBorderStates            2
#define kBorderComponentCount    kBorderStates * 4

static CGFloat _DefaultBorderComponents[kBorderStates][kBorderComponentCount] = {
    /* Default */ { /* Stop 1 */ .68, .68, .68, 1, /* Stop 2 */ .61, .61, .61, 1 },
    /* Selected */ { /* Stop 1 */ 0, .2, .53, 1, /* Stop 2 */ .3, .53, .88, 1 }
};

static CGFloat _BlackOpaqueBorderComponents[kBorderStates][kBorderComponentCount] = {
    /* Default */ { /* Stop 1 */ .68, .68, .68, 1, /* Stop 2 */ .61, .61, .61, 1 },
    /* Selected */ { /* Stop 1 */ .01, .01, .01, 1, /* Stop 2 */ .29, .29, .29, 1 }
};

static CGFloat _BlueContrastBorderComponents[kBorderStates][kBorderComponentCount] = {
    /* Default */ { /* Stop 1 */ .58, .71, .74, 1, /* Stop 2 */ .62, .73, .76, 1 },
    /* Selected */ { /* Stop 1 */ .01, .01, .01, 1, /* Stop 2 */ .29, .29, .29, 1 }
};

static CGFloat _BorderLocations[2] = { 0, 1 };

@implementation SCRSegment (Drawing)

- (void)drawRect:(CGRect)rect {
    
    [super drawRect:rect];
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGFloat width = CGRectGetWidth(self.frame);
    CGFloat height = CGRectGetHeight(self.frame);
    
    CGColorSpaceRef gradientColorSpace = CGColorSpaceCreateDeviceRGB();
    CGPoint gradientStartPoint = CGPointMake(width / 2., 0);
    CGPoint gradientEndPoint = CGPointMake(width / 2., height);
    
    /* Border */
    
    [self clipBackground:context];
    
    CGFloat *borderComponents;
    
    switch (self.colorScheme) {
            
        case SCRSegmentColorSchemeBlackOpaque:
            borderComponents = _BlackOpaqueBorderComponents[self.selected];
            break;
        case SCRSegmentColorSchemeBlueContrast:
            borderComponents = _BlueContrastBorderComponents[self.selected];
            break;
        default:
            borderComponents = _DefaultBorderComponents[self.selected];
            break;
    }
    
    CGGradientRef borderGradient = CGGradientCreateWithColorComponents(gradientColorSpace, borderComponents
                                                                       , _BorderLocations, 2);
    CGContextDrawLinearGradient(context, borderGradient, gradientStartPoint, gradientEndPoint
                                , kCGGradientDrawsBeforeStartLocation);
    CFRelease(borderGradient);
    
    /* Foreground */
    
    [self clipForeground:context];
    
    if (self.selected) {
        
        CGFloat *colorScheme;
        
        switch (self.colorScheme) {
                
            case SCRSegmentColorSchemeBlackOpaque:
                colorScheme = _BlackOpaqueForeColor;
                break;
            case SCRSegmentColorSchemeBlueContrast:
                colorScheme = _BlueContrastForeColor;
                break;
            default:
                colorScheme = _DefaultForeColor;
                break;
        }
        
        CGFloat foreLocations[4] = { 0, .5, .5, 1 };
        CGGradientRef foreGradient = CGGradientCreateWithColorComponents(gradientColorSpace, colorScheme
                                                                         , foreLocations, 4);
        
        CGContextDrawLinearGradient(context, foreGradient, gradientStartPoint
                                    , gradientEndPoint, kCGGradientDrawsBeforeStartLocation);
        CFRelease(foreGradient);
        
    } else {
        
        CGGradientRef foreGradient;
        
        switch (self.colorScheme) {
                
            case SCRSegmentColorSchemeBlueContrast: {
            
                CGFloat foreComponents[16] = {
                
                    /* Stop 1 */ .8, .86, .88, 1,
                    /* Stop 2 */ .7, .79, .81, 1,
                    /* Stop 3 */ .66, .76, .79, 1,
                    /* Stop 4 */ .66, .76, .79, 1
                };
                CGFloat foreLocations[4] = { 0, .5, .5, 1 };
                foreGradient = CGGradientCreateWithColorComponents(gradientColorSpace, foreComponents, foreLocations, 4);
                break;
            }
            default: {        
                CGFloat foreComponents[8] = {
                    /* Stop 1 */ .97, .97, .97, 1,
                    /* Stop 2 */ .78, .78, .78, 1
                };
                CGFloat foreLocations[2] = { 0, 1 };
                foreGradient = CGGradientCreateWithColorComponents(gradientColorSpace, foreComponents, foreLocations, 2);
                
                break;
            }
        }
        
        CGContextDrawLinearGradient(context, foreGradient, gradientStartPoint, gradientEndPoint
                                    , kCGGradientDrawsBeforeStartLocation);
        CFRelease(foreGradient);
    }
    
    CFRelease(gradientColorSpace);
}

- (void)clipBackground:(CGContextRef)c {
    
    [self clipCore:c rect:self.bounds];
}

- (void)clipForeground:(CGContextRef)c {
    
    CGRect rect = self.bounds;
    
    CGFloat left = CGRectGetMinX(rect);
    CGFloat top = CGRectGetMinY(rect);
    CGFloat width = CGRectGetWidth(rect);
    CGFloat height = CGRectGetHeight(rect);
    
    CGRect foreRect;
    
    if (self.selected) {
        
        foreRect = CGRectMake(left + kBorderWidth, top + kBorderWidth, width - kBorderWidth, height - kBorderWidth * 2);
        
    } else {
        
        foreRect = CGRectMake(left, top + kBorderWidth, width - kBorderWidth, height - kBorderWidth * 2);
        
        switch (self.style) {
            case SCRSegmentLeftRound:
            case SCRSegmentLeftBottomRound:
            case SCRSegmentLeftTopRound:
            case SCRSegmentLeft:
                foreRect.origin.x += kBorderWidth;
                foreRect.size.width -= kBorderWidth;
                break;
            default:
                break;
        }
    }
    
    [self clipCore:c rect:foreRect];
}

- (void)clipCore:(CGContextRef)c rect:(CGRect)rect {
    
    switch (self.style) {
        case SCRSegmentLeftRound:
            SCRContextAddLeftRoundedRect(c, rect, kCornerRadius);
            break;
        case SCRSegmentLeftBottomRound:
            SCRContextAddLeftBottomRoundedRect(c, rect, kCornerRadius);
            break;
        case SCRSegmentLeftTopRound:
            SCRContextAddLeftTopRoundedRect(c, rect, kCornerRadius);
            break;
        case SCRSegmentRightRound:
            SCRContextAddRightRoundedRect(c, rect, kCornerRadius);
            break;
        case SCRSegmentRightTopRound:
            SCRContextAddRightTopRoundedRect(c, rect, kCornerRadius);
            break;
        case SCRSegmentRightBottomRound:
            SCRContextAddRightBottomRoundedRect(c, rect, kCornerRadius);
            break;
        default:
            SCRContextAddRoundedRect(c, rect, 0);
            break;
    }
    
    CGContextClip(c);
}

@end
