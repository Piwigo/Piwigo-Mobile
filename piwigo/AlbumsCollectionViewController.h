//
//  AlbumsCollectionViewController.h
//  piwigo
//
//  Created by Olaf on 01.04.15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "AlbumCollectionViewCell.h"

@interface AlbumsCollectionViewController : UICollectionViewController <AlbumCollectionViewCellDelegate, UIGestureRecognizerDelegate>

+(NSString *)nibName;

@end
