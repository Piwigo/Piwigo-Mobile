//
//  AlbumCollectionViewCell.h
//  piwigo
//
//  Created by Olaf on 01.04.15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol AlbumCollectionViewCellDelegate <NSObject>

-(void)pushView:(UIViewController*)viewController;

@end

@class PiwigoAlbumData;

@interface AlbumCollectionViewCell : UICollectionViewCell

+(NSString *)cellReuseIdentifier;

-(void)setupWithAlbumData:(PiwigoAlbumData*)albumData;
@property (nonatomic, weak) id<AlbumCollectionViewCellDelegate> cellDelegate;
@property (nonatomic, strong) PiwigoAlbumData *albumData;
@property (nonatomic, readonly) UIImageView *backgroundImage;



@end
