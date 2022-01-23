//
//  AlbumCollectionViewCell.h
//  piwigo
//
//  Created by Spencer Baker on 3/9/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>

FOUNDATION_EXPORT NSString * const kAlbumTableCell_ID;

@class PiwigoAlbumData;

@protocol AlbumCollectionViewCellDelegate <NSObject>

-(void)pushCategoryView:(UIViewController*)viewController;
-(void)removeCategory:(UICollectionViewCell *)albumCell;

@end

@interface AlbumCollectionViewCell : UICollectionViewCell

@property (nonatomic, weak) id<AlbumCollectionViewCellDelegate> categoryDelegate;
@property (nonatomic, strong) PiwigoAlbumData *albumData;

-(void)setupWithAlbumData:(PiwigoAlbumData*)albumData;
-(void)applyColorPalette;

@end
