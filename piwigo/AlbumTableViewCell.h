//
//  AlbumTableViewCell.h
//  piwigo
//
//  Created by Spencer Baker on 1/24/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>

@class PiwigoAlbumData;

@interface AlbumTableViewCell : UITableViewCell

-(instancetype)initWithAlbumData:(PiwigoAlbumData*)albumData;
-(void)setupWithAlbumData:(PiwigoAlbumData*)albumData;

@property (nonatomic, strong) PiwigoAlbumData *albumData;
@property (nonatomic, strong) UILabel *albumName;
@property (nonatomic, strong) UIImageView *thumbnail;

@end
