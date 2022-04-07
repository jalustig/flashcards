//
//  ImportGroup.h
//  FlashCards
//
//  Created by Jason Lustig on 4/13/11.
//  Copyright 2011-2014 Jason Lustig Lustig. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface ImportGroup : NSObject {
    
    int groupId;
    NSString *name;
    NSString *description;
    NSString *creator;
    bool isPrivateGroup;
    bool requiresPassword;
    bool isMemberOfGroup;
    int numberCardSets;
    int numberUsers;
    NSMutableArray *cardSets;
    
}

- (id) initWithDictionary:(NSDictionary*)setData;

@property (nonatomic, assign) int groupId;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *description;
@property (nonatomic, strong) NSString *creator;

@property (nonatomic, assign) bool isPrivateGroup;
@property (nonatomic, assign) bool requiresPassword;
@property (nonatomic, assign) bool isMemberOfGroup;
@property (nonatomic, assign) int numberCardSets;
@property (nonatomic, assign) int numberUsers;

@property (nonatomic, strong) NSMutableArray *cardSets;

@end
