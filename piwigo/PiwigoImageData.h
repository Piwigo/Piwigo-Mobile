//
//  PiwigoImageData.h
//  piwigo
//
//  Created by Spencer Baker on 1/15/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PiwigoImageData : NSObject

@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *thumbPath;
@property (nonatomic, strong) NSString *squarePath;
@property (nonatomic, strong) NSArray *categoryIds;
@property (nonatomic, strong) NSString *mediumPath;
@property (nonatomic, strong) NSString *fullResPath;

@end
