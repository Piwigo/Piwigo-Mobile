//
//  AlbumImagesViewController.h
//  piwigo
//
//  Created by Spencer Baker on 1/27/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>
@class PiwigoAlbumData;

@interface AlbumImagesViewController : UIViewController

@property (nonatomic, strong) UICollectionView *imagesCollection;

-(instancetype)initWithAlbumId:(NSInteger)albumId;

-(UICollectionViewCell*)cellWithAlbumData:(PiwigoAlbumData *)albumData
                      collectionView:(UICollectionView *)collectionView
                         atIndexPath:(NSIndexPath *)indexPath;

-(void)collectionView:(UICollectionView *)collectionView inSectionOneSidSelectItemAtIndexPath:(NSIndexPath *)indexPath;

@end
