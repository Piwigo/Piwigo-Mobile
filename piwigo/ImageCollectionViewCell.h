//
//  ImageCollectionViewCell.h
//  piwigo
//
//  Created by Spencer Baker on 1/27/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>

@class PiwigoImageData;

@interface ImageCollectionViewCell : UICollectionViewCell

@property (nonatomic, strong) UIImageView *cellImage;
@property (nonatomic, strong) PiwigoImageData *imageData;
-(void)setupWithImageData:(PiwigoImageData*)imageData;

@end
