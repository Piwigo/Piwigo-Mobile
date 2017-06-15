//
//  PiwigoTagData.h
//  piwigo
//
//  Created by Spencer Baker on 2/17/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PiwigoTagData : NSObject

@property (nonatomic, assign) NSInteger tagId;
@property (nonatomic, strong) NSString *tagName;
@property (nonatomic, assign) NSInteger numberOfImagesUnderTag;

@end
