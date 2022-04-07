//
//  SCRSegmentedControl.m
//  TouchCustoms
//
//  Created by Aleks Nesterow on 1/25/10.
//    aleks.nesterow@gmail.com
//    
//  Copyright © 2010 Screen Customs s.r.o.
//    All rights reserved.
//

#import "SCRSegment.h"
#import "SCRSegmentedControl.h"
#import "SCRMemoryManagement.h"
#import "UIView+Layout.h"

#define kRowHeight    37

@interface SCRSegmentedControl (/* Private methods */)

- (void)__initializeComponent;

@end

@interface SCRSegmentedControl (UserInteraction) 

- (NSInteger)__getSegmentIndexFromTouches:(NSSet *)touches withEvent:(UIEvent *)event;

@end

@implementation SCRSegmentedControl

@synthesize colorScheme = _colorScheme;

- (void)setColorScheme:(SCRSegmentColorScheme)value {
    
    if (_colorScheme != value) {
        
        _colorScheme = value;
        [self setNeedsLayout];
    }
}

@synthesize columnCount = _columnCount, rowCount = _rowCount;
@synthesize columnPattern = _columnPattern;
@synthesize segmentTitles = _segmentTitles, segmentImages = _segmentImages;
@synthesize selectedIndex = _selectedIndex;
@synthesize rowHeight, extraHeight;

- (void)setColumnCount:(NSUInteger)value {
    
    if (_columnCount != value) {
        
        _columnCount = value;
        [self setNeedsLayout];
    }
}

- (void)setRowCount:(NSUInteger)value {
    
    if (_rowCount != value) {
        
        _rowCount = value;
        [self setNeedsLayout];
    }
}

- (void)setColumnPattern:(NSArray *)value {
    
    if (_columnPattern != value) {
        
        SCR_RELEASE_SAFELY(_columnPattern);
        _columnPattern = [value retain];
        [self setNeedsLayout];
    }
}

- (void)setSegmentTitles:(NSArray *)value {
    
    if (_segmentTitles != value) {
        
        SCR_RELEASE_SAFELY(_segmentTitles);
        _segmentTitles = [[NSArray alloc] initWithArray:value];
        [self setNeedsLayout];
    }
}

- (void)setTitle:(NSString*)title forSegmentAtIndex:(NSUInteger)segment {
    NSMutableArray *newTitles = [[NSMutableArray alloc] initWithArray:_segmentTitles];
    [newTitles replaceObjectAtIndex:segment withObject:title];
    SCR_RELEASE_SAFELY(_segmentTitles);
    _segmentTitles = [[NSArray alloc] initWithArray:newTitles];
    [self setNeedsLayout];
    [self layoutIfNeeded];
    [newTitles release];
}

- (void)setSegmentImages:(NSArray *)value {

    if (_segmentImages != value) {
    
        SCR_RELEASE_SAFELY(_segmentImages);
        _segmentImages = [[NSArray alloc] initWithArray:value];
        [self setNeedsLayout];
    }
}

- (void)setSelectedIndex:(NSInteger)value {
    
    if (_selectedIndex != value) {
        
        if (_segments.count > _selectedIndex && _selectedIndex != SCRSegmentedControlNoSegment) {
            [[_segments objectAtIndex:_selectedIndex] setSelected:NO];
        }
        
        _selectedIndex = value;
        
        if (_segments.count > _selectedIndex && _selectedIndex != SCRSegmentedControlNoSegment) {
            [[_segments objectAtIndex:_selectedIndex] setSelected:YES];
        }
        
        [self sendActionsForControlEvents:UIControlEventValueChanged];
    }
}

- (int)selectedSegmentIndex {
    SCRSegment *segment;
    for (int i = 0; i < [_segments count]; i++) {
        segment = [_segments objectAtIndex:i];
        if (segment.selected) {
            return i;
        }
    }
    return 0;
}

- (id)init {
    rowHeight = kRowHeight;
    extraHeight = 0;
    return [self initWithFrame:CGRectMake(0, 0, 200, 37)];
}

- (id)initWithFrame:(CGRect)frame {
    
    if ((self = [super initWithFrame:frame])) {
        
        [self __initializeComponent];
    }
    
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    
    if ((self = [super initWithCoder:decoder])) {
        
        [self __initializeComponent];
    }
    
    return self;
}

- (void)__initializeComponent {
    
    _segments = [[NSMutableArray alloc] initWithCapacity:12];
}

- (void)dealloc {
    
    SCR_RELEASE_SAFELY(_columnPattern);
    SCR_RELEASE_SAFELY(_segmentTitles);
    SCR_RELEASE_SAFELY(_segmentImages);
    SCR_RELEASE_SAFELY(_segments);
    
    [super dealloc];
}

- (void)layoutSubviews {
    
    [super layoutSubviews];
    
    NSUInteger mustItemCount = 0;
    
    if (self.columnPattern) {
        
        for (NSUInteger i = 0; i < self.rowCount; i++) {
            
            mustItemCount += [[self.columnPattern objectAtIndex:i] unsignedIntValue];
        }
        
    } else {
        
        mustItemCount = self.columnCount * self.rowCount;
    }
    
    for (SCRSegment *segment in _segments) {
        
        [segment removeFromSuperview];
    }
    
    [_segments removeAllObjects];
    
    if (0 == mustItemCount) {
        
        return;
    }
    
    BOOL useImages = NO;
    
    if (mustItemCount == self.segmentImages.count) {
        
        useImages = YES;
        
    } else if (mustItemCount != self.segmentTitles.count) {
        
        return;
    }
    
    CGFloat width = CGRectGetWidth(self.frame);
    CGFloat segmentOffsetY = 0;
    NSUInteger segmentIndex = 0;
    
    for (NSUInteger row = 0; row < self.rowCount; row++) {
        
        NSUInteger columnCount;
        
        if (self.columnPattern) {
            
            columnCount = [[self.columnPattern objectAtIndex:row] unsignedIntValue];
            
        } else {
            
            columnCount = self.columnCount;
        }
        
        CGFloat segmentWidth = width / columnCount;
        CGFloat buttonOffsetX = 0;
        
        for (NSUInteger col = 0; col < columnCount; col++) {
            
            SCRSegment *segment = [SCRSegment segmentWithStyle:SCRSegmentCenter];
            
            segment.colorScheme = self.colorScheme;
            segment.frame = CGRectMake(buttonOffsetX, segmentOffsetY, segmentWidth, rowHeight);
            segment.tag = segmentIndex;
            
            if (useImages) {
                
                segment.imageView.image = [self.segmentImages objectAtIndex:segmentIndex];
                segment.titleLabel.text = nil;
                
            } else {
                
                segment.titleLabel.font = [UIFont boldSystemFontOfSize:14];
                segment.titleLabel.text = [self.segmentTitles objectAtIndex:segmentIndex];
                segment.imageView.image = nil;
            }
            
            if (self.selectedIndex == segmentIndex) {
                
                segment.selected = YES;
            }
            
            segment.style = SCRSegmentCenter;
            
            if (1 == self.rowCount) {
                
                if (0 == col) {
                    
                    /* +---+---+---+
                     | * |   |   |
                     +---+---+---+
                     */
                    
                    segment.style = SCRSegmentLeftRound;
                    
                } else if (columnCount - 1 == col) {
                    
                    /* +---+---+---+
                     |   |   | * |
                     +---+---+---+
                     */
                    
                    segment.style = SCRSegmentRightRound;
                }
            } else if (0 == row) {
                
                if (0 == col) {
                    
                    /* +---+---+---+
                     | * |   |   |
                     +---+---+---+
                     |   |   |   |
                     +---+---+---+
                     |   |   |   |
                     +---+---+---+
                     */
                    
                    segment.style = SCRSegmentLeftTopRound;
                    
                } else if (columnCount - 1 == col) {
                    
                    /* +---+---+---+
                     |   |   | * |
                     +---+---+---+
                     |   |   |   |
                     +---+---+---+
                     |   |   |   |
                     +---+---+---+
                     */
                    
                    segment.style = SCRSegmentRightTopRound;
                }
            } else if (self.rowCount - 1 == row) {
                
                if (0 == col) {
                    
                    /* +---+---+---+
                     |   |   |   |
                     +---+---+---+
                     |   |   |   |
                     +---+---+---+
                     | * |   |   |
                     +---+---+---+
                     */
                    
                    segment.style = SCRSegmentLeftBottomRound;
                    
                } else if (columnCount - 1 == col) {
                    
                    /* +---+---+---+
                     |   |   |   |
                     +---+---+---+
                     |   |   |   |
                     +---+---+---+
                     |   |   | * |
                     +---+---+---+
                     */
                    
                    segment.style = SCRSegmentRightBottomRound;
                }
            } else {
                
                if (0 == col) {
                    
                    /* +---+---+---+
                     |   |   |   |
                     +---+---+---+
                     | * |   |   |
                     +---+---+---+
                     |   |   |   |
                     +---+---+---+
                     */
                    
                    segment.style = SCRSegmentLeft;
                    
                } else if (columnCount - 1 == col) {
                    
                    /* +---+---+---+
                     |   |   |   |
                     +---+---+---+
                     |   |   | * |
                     +---+---+---+
                     |   |   |   |
                     +---+---+---+
                     */
                    
                    segment.style = SCRSegmentRight;
                }
            }
            
            buttonOffsetX += segmentWidth;
            segmentIndex += 1;
            
            [_segments addObject:segment];
            [self addSubview:segment];
            [self sendSubviewToBack:segment];
        }
        
        segmentOffsetY += rowHeight - 1;
    }
    [self setPositionHeight:(rowHeight*self.rowCount)+extraHeight];
}

/*
- (NSArray *)accessibleElements
{
    if ( _accessibleElements != nil )
    {
        return _accessibleElements;
    }
    _accessibleElements = [[NSMutableArray alloc] init];

    // Create an accessibility element to represent the first contained element and initialize it as a component of MultiFacetedView.
    
    UIAccessibilityElement *element1 = [[[UIAccessibilityElement alloc] initWithAccessibilityContainer:self] autorelease];
    
    // Set attributes of the first contained element here.
    
    [_accessibleElements addObject:element1];
    
    // Perform similar steps for the second contained element.
    
    UIAccessibilityElement *element2 = [[[UIAccessibilityElement alloc] initWithAccessibilityContainer:self] autorelease];
    
    // Set attributes of the second contained element here.
    
    [_accessibleElements addObject:element2];
}

// The container itself is not accessible, so MultiFacetedView should return NO in isAccessiblityElement. 
- (BOOL)isAccessibilityElement
{
    return NO;
}

// The following methods are implementations of UIAccessibilityContainer protocol methods.

- (NSInteger)accessibilityElementCount
{
    return [[self accessibleElements] count];
}

- (id)accessibilityElementAtIndex:(NSInteger)index
{
    return [[self accessibleElements] objectAtIndex:index];
}

- (NSInteger)indexOfAccessibilityElement:(id)element
{
    return [[self accessibleElements] indexOfObject:element];
}
*/

@end

@implementation SCRSegmentedControl (UserInteraction)

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    
    NSInteger segmentIndex = [self __getSegmentIndexFromTouches:touches withEvent:event];
    if (0 <= segmentIndex) {
        [self setSelectedIndex:segmentIndex];
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    [self sendActionsForControlEvents:UIControlEventTouchUpInside];
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    
    if (self.userInteractionEnabled && [self pointInside:point withEvent:event]) {
        return self; /* Only intercept events if the touch happened inside the view. */
    }
    return [super hitTest:point withEvent:event];
}

- (void)setUserInteractionEnabled:(BOOL)value {
    
    [super setUserInteractionEnabled:value];
    
    for (SCRSegment *segment in _segments) {
        segment.userInteractionEnabled = value;
    }
}

- (NSInteger)__getSegmentIndexFromTouches:(NSSet *)touches withEvent:(UIEvent *)event {
    
    id touch = [touches anyObject];
    
    for (SCRSegment *segment in _segments) {
        if ([segment pointInside:[touch locationInView:segment] withEvent:event]) {
            return segment.tag;
        }
    }
    
    return -1;
}

@end
