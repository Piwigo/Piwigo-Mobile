//
//  AlbumPhotoTableViewCell.h
//  piwigo
//
//  Created by Spencer Baker on 1/20/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>

@class PiwigoImageData;

@interface AlbumPhotoTableViewCell : UITableViewCell

@property (nonatomic, strong) UILabel *imageName;
@property (nonatomic, strong) UIImageView *thumbnail;

-(void)setupWithImageData:(PiwigoImageData*)imageData;

@end
