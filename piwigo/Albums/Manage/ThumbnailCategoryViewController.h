//
//  ThumbnailCategoryViewController.h
//  piwigo
//
//  Created by Spencer Baker on 3/16/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "PiwigoImageData.h"

@protocol SetAlbumImageDelegate <NSObject>

-(void)didSetImageAsAlbumThumbnail;

@end

@interface ThumbnailCategoryViewController : UIViewController

@property (nonatomic, weak) id<SetAlbumImageDelegate> setAlbumImageDelegate;

-(instancetype)initForImage:(PiwigoImageData *)imageData andCategoryId:(NSInteger)categoryId;

@end
