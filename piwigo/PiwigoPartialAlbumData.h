//
//  PiwigoPartialAlbumData.h
//  piwigo
//
//  Created by Olaf Greck on 5.Jun.15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "PiwigoAlbumData.h"

@interface PiwigoPartialAlbumData : NSObject

@property (nonatomic, strong) NSString *albumPath;
@property (nonatomic, strong) NSString *albumName;
@property (nonatomic) NSInteger albumId;
@property (nonatomic) NSInteger numberOfImages;
@property (nonatomic) BOOL isSelected;

-(NSString *) imageNames;

-(instancetype)initWithAlbum:(PiwigoAlbumData *)fullAlbum;

-(void)addImageAsMember:(PiwigoImageData *)anImage;

@end
