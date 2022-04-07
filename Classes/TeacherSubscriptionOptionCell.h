//
//  TeacherSubscriptionOptionCell.h
//  FlashCards
//
//  Created by Jason Lustig on 6/21/13.
//  Copyright (c) 2013 Jason Lustig. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface TeacherSubscriptionOptionCell : UITableViewCell

@property (nonatomic, weak) IBOutlet UILabel* subscriptionName;
@property (nonatomic, weak) IBOutlet UILabel* subscriptionDescription;
@property (nonatomic, weak) IBOutlet UILabel* subscriptionPrice;

@end
