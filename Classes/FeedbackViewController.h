//
//  FeedbackViewController.h
//  FlashCards
//
//  Created by Jason Lustig on 8/22/11.
//  Copyright 2011-2014 Jason Lustig Lustig. All rights reserved.
//



@interface FeedbackViewController : UIViewController <UITableViewDelegate>

@property (nonatomic, weak) IBOutlet UILabel *doYouLikeThisAppLabel;
@property (nonatomic, weak) IBOutlet UITableView *theTableView;


@end
