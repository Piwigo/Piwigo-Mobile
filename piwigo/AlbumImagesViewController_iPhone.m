//
//  AlbumImagesViewController_iPhone.m
//  piwigo
//
//  Created by Olaf on 03.04.15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "AlbumImagesViewController_iPhone.h"


@interface AlbumImagesViewController_iPhone ()

@end

@implementation AlbumImagesViewController_iPhone

-(instancetype)initWithAlbumId:(NSInteger)albumId {
    self = [super initWithAlbumId:albumId];
    if(self) {
        [self.imagesCollection registerClass:[CategoryCollectionViewCell class] forCellWithReuseIdentifier:@"category"];
    }
    return self;
}

-(UICollectionViewCell*)cellWithAlbumData:(PiwigoAlbumData *)albumData
                      collectionView:(UICollectionView *)collectionView
                         atIndexPath:(NSIndexPath *)indexPath {
    CategoryCollectionViewCell *cell =
    [collectionView dequeueReusableCellWithReuseIdentifier:@"category" forIndexPath:indexPath];
    cell.categoryDelegate = self;
    [cell setupWithAlbumData:albumData];
    return cell;
}

-(CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat size = MIN(collectionView.frame.size.width, collectionView.frame.size.height) / 3 - 14;
    if(indexPath.section == 1)
    {
        return CGSizeMake(size, size);
    }
    else
    {
        return CGSizeMake(collectionView.frame.size.width - 20, 188);
    }
}

-(void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
      if(indexPath.section == 1) {
        [super collectionView:collectionView inSectionOneSidSelectItemAtIndexPath:indexPath];
        
    } else {
        MyLog(@"Error, no such section");
    }
    
}

-(void)pushView:(UIViewController *)viewController {
    [super pushView:viewController];
}

@end
