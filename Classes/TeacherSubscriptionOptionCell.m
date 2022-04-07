//
//  TeacherSubscriptionOptionCell.m
//  FlashCards
//
//  Created by Jason Lustig on 6/21/13.
//  Copyright (c) 2013 Jason Lustig. All rights reserved.
//

#import "TeacherSubscriptionOptionCell.h"

@implementation TeacherSubscriptionOptionCell

@synthesize subscriptionName;
@synthesize subscriptionDescription;
@synthesize subscriptionPrice;

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

@end
