//
//  Swipeable.h
//  FlashCards
//
//  Created by Jason Lustig on 8/3/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <OHAttributedStringAdditions/OHAttributedStringAdditions.h>

# pragma mark -
# pragma mark ResignableTableView

@class CardEditViewController;

@interface ResignableTableView : UITableView {
    NSArray *resignObjectsOnTouchesEnded;
    CardEditViewController *superviewController;
}

@property (nonatomic, strong) NSArray *resignObjectsOnTouchesEnded;
@property (nonatomic, strong) CardEditViewController *superviewController;

@end

# pragma mark -
# pragma mark SwipeableScrollView

@interface SwipeableScrollView : UIScrollView {
    
}

@end


# pragma mark -
# pragma mark NonSwipeableButton

@interface NonSwipeableButton : UIButton {
    
}

@end


# pragma mark -
# pragma mark SwipeableView

@interface SwipeableView : UIView {
    
}

@end


# pragma mark -
# pragma mark SwipeableImage

@interface SwipeableImageView : UIImageView {
    
}

@end


# pragma mark -
# pragma mark SwipeableLabel

@interface SwipeableLabel : UILabel {
    
}

@end


# pragma mark -
# pragma mark SwipeableTextView

@interface SwipeableTextView : UITextView {
    
}

-(BOOL)sizeFontToFit:(NSString*)aString minSize:(float)aMinFontSize maxSize:(float)aMaxFontSize;

@end 

# pragma mark -
# pragma mark SwipeableTableView

@interface SwipeableTableView : UITableView {
    
}

@end
