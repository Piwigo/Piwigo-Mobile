//
//  CategoryCollectionViewCell.h
//  piwigo
//
//  Created by Spencer Baker on 3/9/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>

@class PiwigoAlbumData;

@interface CategoryCollectionViewCell : UICollectionViewCell

-(void)setupWithAlbumData:(PiwigoAlbumData*)albumData;

@end
