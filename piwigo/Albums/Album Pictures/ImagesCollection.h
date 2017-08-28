//
//  ImagesCollection.h
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 28/08/2017.
//  Copyright © 2017 Piwigo.org. All rights reserved.
//

extern NSInteger const kCellSpacing;
extern NSInteger const kMarginsSpacing;

@interface ImagesCollection : NSObject

+(NSInteger)numberOfImagesPerRowForCollectionView:(UICollectionView *)collectionView;
+(CGFloat)imageSizeForCollectionView:(UICollectionView *)collectionView;
+(NSInteger)numberOfImagesPerScreenForCollectionView:(UICollectionView *)collectionView;

@end
