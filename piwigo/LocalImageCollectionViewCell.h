//
//  LocalImageCollectionViewCell.h
//  piwigo
//
//  Created by Spencer Baker on 1/28/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ALAsset;

@interface LocalImageCollectionViewCell : UICollectionViewCell

@property (nonatomic, strong) UIImageView *cellImage;
-(void)setupWithImageAsset:(ALAsset*)imageAsset;

@end
