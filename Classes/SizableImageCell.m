//
//  SizableImageCell.m
//  FlashCards
//
//  Created by Jason Lustig on 2/13/13.
//  Copyright (c) 2013 Jason Lustig. All rights reserved.
//

#import "SizableImageCell.h"

@implementation SizableImageCell

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


// as per: stackoverflow.com/questions/2788028
- (void)layoutSubviews {
    [super layoutSubviews];

    float desiredWidth = 32;
    float w = self.imageView.frame.size.width;
    if (w < desiredWidth) {
        float widthSub = w - desiredWidth;
        self.imageView.frame = CGRectMake(self.imageView.frame.origin.x,
                                          self.imageView.frame.origin.y,
                                          desiredWidth,
                                          self.imageView.frame.size.height);
        self.textLabel.frame = CGRectMake(self.textLabel.frame.origin.x - widthSub,
                                          self.textLabel.frame.origin.y,
                                          self.textLabel.frame.size.width,
                                          self.textLabel.frame.size.height);
        self.imageView.contentMode = UIViewContentModeScaleAspectFit;
    }
    // self.imageView.contentMode = UIViewContentModeScaleAspectFit;
    // self.imageView.bounds = CGRectMake(0,0,32,32);
}

@end
