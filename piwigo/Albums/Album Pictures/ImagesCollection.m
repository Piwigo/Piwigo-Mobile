//
//  ImagesCollection.m
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 28/08/2017.
//  Copyright © 2017 Piwigo.org. All rights reserved.
//

#import "ImagesCollection.h"

NSInteger const kCellSpacing = 2;               // Spacing between items (horizontally and vertically)
NSInteger const kMarginsSpacing = 0;            // Left and right margins

#pragma mark Determine number of images per row

@implementation ImagesCollection

+(float)numberOfImagesPerRowForCollectionView:(UICollectionView *)collectionView
{
    // Thumbnails should always be available on server (default size of 144x144 pixels)
    // We display at least 3 thumbnails per row and images never exceed the thumbnails size
    return fmax(3.0, roundf((collectionView.frame.size.width - 2.0 * kMarginsSpacing + kCellSpacing) / (kCellSpacing + 144.0)));
}

+(float)imageSizeForCollectionView:(UICollectionView *)collectionView
{
    // Optimum number of images per row
    float imagesPerRow = [self numberOfImagesPerRowForCollectionView:collectionView];
    
    // Size of squared images for that number
    return floorf((collectionView.frame.size.width - 2.0 * kMarginsSpacing - (imagesPerRow - 1.0) * kCellSpacing) / imagesPerRow);
}

+(NSInteger)numberOfImagesPerScreenForCollectionView:(UICollectionView *)collectionView
{
    // Optimum number of images per row
    float imagesPerRow = [self numberOfImagesPerRowForCollectionView:collectionView];

    // Size of squared images for that number
    float size = [self imageSizeForCollectionView:collectionView];

    return (NSInteger)ceilf(collectionView.frame.size.height / (size + kCellSpacing)) * imagesPerRow;
}

@end
