//
//  AlbumTableViewCell.h
//  piwigo
//
//  Created by Spencer Baker on 1/24/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol AlbumTableViewCellDelegate <NSObject>

-(void)pushView:(UIViewController*)viewController;

@end

@class PiwigoAlbumData;

@interface AlbumTableViewCell : MGSwipeTableCell

-(void)setupWithAlbumData:(PiwigoAlbumData*)albumData;
@property (nonatomic, weak) id<AlbumTableViewCellDelegate> cellDelegate;
@property (nonatomic, strong) PiwigoAlbumData *albumData;
@property (nonatomic, readonly) UIImageView *backgroundImage;

@end
