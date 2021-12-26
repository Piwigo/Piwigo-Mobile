//
//  CategoryCollectionViewCell.h
//  piwigo
//
//  Created by Spencer Baker on 3/9/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>

@class PiwigoAlbumData;

@protocol CategoryCollectionViewCellDelegate <NSObject>

-(void)pushCategoryView:(UIViewController*)viewController;

@end

@interface CategoryCollectionViewCell : UICollectionViewCell

@property (nonatomic, weak) id<CategoryCollectionViewCellDelegate> categoryDelegate;

-(void)setupWithAlbumData:(PiwigoAlbumData*)albumData;
-(void)applyColorPalette;

@end
