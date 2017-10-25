//
//  LocalImageCollectionViewCell.h
//  piwigo
//
//  Created by Spencer Baker on 1/28/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>

@class PHAsset;

@interface LocalImageCollectionViewCell : UICollectionViewCell

@property (nonatomic, assign) BOOL cellSelected;
@property (nonatomic, assign) BOOL cellUploading;
@property (nonatomic, assign) CGFloat progress;
@property (nonatomic, strong) UIImageView *cellImage;

-(void)setupWithImageAsset:(PHAsset*)imageAsset andThumbnailSize:(CGFloat)size;

@end
