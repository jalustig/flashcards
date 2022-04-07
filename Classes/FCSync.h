//
//  FCSync.h
//  FlashCards
//
//  Created by Jason Lustig on 6/8/13.
//  Copyright (c) 2013 Jason Lustig. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FCSync : NSObject {
    NSString *websiteName;
    NSMutableSet *imagesToDownload;
}

@property (nonatomic, strong) NSString *websiteName;
@property (nonatomic, strong) NSMutableSet *imagesToDownload;

@end
