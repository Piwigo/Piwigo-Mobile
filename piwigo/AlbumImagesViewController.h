//
//  AlbumImagesViewController.h
//  piwigo
//
//  Created by Spencer Baker on 1/27/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>
@class PiwigoAlbumData;

#import "AlbumCollectionViewCell.h"
#import "CategoryCollectionViewCell.h"
#import "Model.h"

@interface AlbumImagesViewController : UIViewController <CategoryCollectionViewCellDelegate, AlbumCollectionViewCellDelegate>

@property (nonatomic, strong) UICollectionView *imagesCollection;
@property (nonatomic, strong) UIBarButtonItem *selectBarButton;
@property (nonatomic, strong) UIBarButtonItem *uploadBarButton;
@property (nonatomic, assign) BOOL isSelect;

-(instancetype)initWithAlbumId:(NSInteger)albumId;

-(UICollectionViewCell*)cellWithAlbumData:(PiwigoAlbumData *)albumData
                      collectionView:(UICollectionView *)collectionView
                         atIndexPath:(NSIndexPath *)indexPath;

-(void)collectionView:(UICollectionView *)collectionView inSectionOneSidSelectItemAtIndexPath:(NSIndexPath *)indexPath;

-(void)deleteImages;
-(void)downloadImages;
-(void)cancelSelect;

-(NSArray *)prepareSelectedImages;

/**
 Child must override
 */
-(void)loadNavButtons;

@end
