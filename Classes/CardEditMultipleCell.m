//
//  CardEditMultipleCell.m
//  FlashCards
//
//  Created by Jason Lustig on 6/21/13.
//  Copyright (c) 2013 Jason Lustig. All rights reserved.
//

#import "CardEditMultipleCell.h"
#import "GrowableTextView.h"

#import "CardEditMultipleViewController.h"
#import "Swipeable.h"

@implementation CardEditMultipleCell

@synthesize frontTextView;
@synthesize backTextView;
@synthesize controller;
@synthesize cardNumber;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
    }
    return self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

# pragma mark -
# pragma mark Text view delegate

- (void)textViewDidBeginEditing:(UITextView *)_textView {
    NSMutableDictionary *card = [controller cardAtRow:self.cardNumber];
    NSString *text;
    if ([_textView isEqual:self.frontTextView]) {
        text = [card objectForKey:@"frontValue"];
        if ([text length] == 0) {
            self.frontTextView.text = @"";
        }
    } else {
        text = [card objectForKey:@"backValue"];
        if ([text length] == 0) {
            self.backTextView.text = @"";
        }
    }
}


- (void)textViewDidEndEditing:(UITextView *)_textView {
    NSMutableDictionary *card = [controller cardAtRow:self.cardNumber];
    NSString *text;
    if ([_textView isEqual:self.frontTextView]) {
        text = [card objectForKey:@"frontValue"];
        if ([text length] == 0) {
            self.frontTextView.text = NSLocalizedStringFromTable(@"Front Side of Card", @"CardManagement", @"");
        }
    } else {
        text = [card objectForKey:@"backValue"];
        if ([text length] == 0) {
            self.backTextView.text = NSLocalizedStringFromTable(@"Back Side of Card", @"CardManagement", @"");
        }
    }
}

// as per: http://stackoverflow.com/questions/3749746/uitextview-in-a-uitableviewcell-smooth-auto-resize
- (void)textViewDidChange:(UITextView *)_textView {

    if (controller.isAddingNewCard) {
        return;
    }
    
    GrowableTextView *text;
    if ([_textView isEqual:self.frontTextView]) {
        [controller setCardText:_textView.text forCard:cardNumber forSide:@"frontValue"];
        text = self.frontTextView;
    } else {
        [controller setCardText:_textView.text forCard:cardNumber forSide:@"backValue"];
        text = self.backTextView;
    }
    [text setTextViewSize];
    UIView *contentView = _textView.superview;
    if ((_textView.frame.size.height + 12.0f) != contentView.frame.size.height) {

        UITableView *tableView = [self myTableView];
        [tableView beginUpdates];
        [tableView endUpdates];
        
        [contentView setFrame:CGRectMake(0,
                                         0,
                                         contentView.frame.size.width,
                                         (_textView.frame.size.height+12.0f))];
        
    }
    
    /*
    NSMutableDictionary *card = [controller cardAtRow:self.cardNumber];
    if ([[card valueForKey:@"frontValue"] length] > 0 || [[card valueForKey:@"backValue"] length] > 0) {
        if ((self.cardNumber + 1) >= [[[self controller] cards] count]) {
            [[self controller] addNewCard];
            [[[self controller] myTableView] reloadData];
            [_textView becomeFirstResponder];
        }
    }
     */

}

// as per: http://stackoverflow.com/a/13680864/353137
-(UITableView *) myTableView {
    // iterate up the view hierarchy to find the table containing this cell/view
    UIView *aView = self.superview;
    while(aView != nil) {
        if([aView isKindOfClass:[UITableView class]]) {
            return (UITableView *)aView;
        }
        aView = aView.superview;
    }
    return nil; // this view is not within a tableView
}

@end
