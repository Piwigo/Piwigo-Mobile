//
//  PiwigoImageData.h
//  piwigo
//
//  Created by Spencer Baker on 1/15/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PiwigoImageData : NSObject

@property (nonatomic, strong) NSString *file;
@property (nonatomic, strong) NSString *squarePath;
@property (nonatomic, assign) NSInteger categoryId;

@end
