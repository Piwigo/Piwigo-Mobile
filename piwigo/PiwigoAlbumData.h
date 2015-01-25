//
//  PiwigoAlbumData.h
//  piwigo
//
//  Created by Spencer Baker on 1/24/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PiwigoAlbumData : NSObject

@property (nonatomic, assign) NSInteger albumId;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *comment;
@property (nonatomic, assign) NSInteger globalRank;
@property (nonatomic, assign) NSInteger numberOfImages;
@property (nonatomic, assign) NSInteger albumThumbnailId;
@property (nonatomic, strong) NSString *albumThumbnailUrl;

@end
