//
//  CardSetShareViewController.h
//  FlashCards
//
//  Created by Jason Lustig on 10/15/10.
//  Copyright 2010-2014 Jason Lustig Lustig. All rights reserved.
//

#import <UIKit/UIKit.h>

#import <MessageUI/MessageUI.h>

@class FCCardSet;
@class FCCollection;

@interface CardSetShareViewController : UIViewController <MFMailComposeViewControllerDelegate>

-(void)buildExportNativeFile:(NSString*)path;
-(void)buildExportCSV:(NSString*)path;

@property (nonatomic, strong) FCCardSet *cardSet;
@property (nonatomic, strong) FCCollection *collection;


@property (nonatomic, strong) NSString *fileName;

@end
