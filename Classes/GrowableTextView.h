//
//  GrowableTextView.h
//  FlashCards
//
//  Created by Jason Lustig on 4/15/11.
//  Copyright 2011-2014 Jason Lustig Lustig. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface GrowableTextView : UITextView {
    NSIndexPath *indexPath;
}

@property (nonatomic, strong) NSIndexPath *indexPath;

- (CGSize)textViewSize;
- (void)setTextViewSize;

@end

