//
//  AlbumImagesViewController_iPad.m
//  piwigo
//
//  Created by Olaf on 03.04.15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "AlbumImagesViewController_iPad.h"

#import "AlbumCollectionViewCell.h"
#import "PiwigoAlbumData.h"

@interface AlbumImagesViewController_iPad ()

@end

@implementation AlbumImagesViewController_iPad

-(instancetype)initWithAlbumId:(NSInteger)albumId {
    self = [super initWithAlbumId:albumId];
    if(self) {
        [self.imagesCollection registerClass:[AlbumCollectionViewCell class] forCellWithReuseIdentifier:[AlbumCollectionViewCell cellReuseIdentifier]];
    }
    return self;
}

-(UICollectionViewCell*)cellWithAlbumData:(PiwigoAlbumData *)albumData
                           collectionView:(UICollectionView *)collectionView
                              atIndexPath:(NSIndexPath *)indexPath {
    AlbumCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:[AlbumCollectionViewCell cellReuseIdentifier] forIndexPath:indexPath];
    
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
        CGSize returnSize   = CGSizeMake(260, 180);
        returnSize.height   += 35;
        returnSize.width    += 35;
        return returnSize;
//        return CGSizeMake(collectionView.frame.size.width - 20, 188);
    }
}

-(void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    if(indexPath.section == 0) {
        AlbumCollectionViewCell *cell = (AlbumCollectionViewCell *)[collectionView cellForItemAtIndexPath:indexPath];
        AlbumImagesViewController_iPad *album = [[AlbumImagesViewController_iPad alloc] initWithAlbumId:cell.albumData.albumId];
        [self.navigationController pushViewController:album animated:YES];
        
    } else if(indexPath.section == 1) {
        [super collectionView:collectionView inSectionOneSidSelectItemAtIndexPath:indexPath];
    
    } else {
        MyLog(@"Error, no such section");
    }

}

@end
