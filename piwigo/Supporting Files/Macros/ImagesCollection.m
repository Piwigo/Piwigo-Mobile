//
//  ImagesCollection.m
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 28/08/2017.
//  Copyright © 2017 Piwigo.org. All rights reserved.
//

#import "ImagesCollection.h"
#import "Model.h"

NSInteger const kAlbumCellSpacing = 8;          // Spacing between albums (horizontally and vertically)
NSInteger const kAlbumMarginsSpacing = 4;       // Left and right margins for albums
NSInteger const kImageCellSpacing4iPhone = 1;   // Spacing between images (horizontally and vertically)
NSInteger const kImageCellHorSpacing4iPad = 8;
NSInteger const kImageCellVertSpacing4iPad = 8;
NSInteger const kImageMarginsSpacing = 4;       // Left and right margins for images
NSInteger const kThumbnailFileSize = 144;       // Default Piwigo thumbnail file size

@implementation ImagesCollection

+(CGSize)sizeOfPageForView:(UIView *)view
{
    CGSize pageSize;
    if (view == nil) {
        CGRect screenRect = [[UIScreen mainScreen] bounds];
        pageSize = screenRect.size;
    } else {
        pageSize = view.frame.size;
        if (@available(iOS 11.0, *)) {
            pageSize.width -= view.safeAreaInsets.left + view.safeAreaInsets.right;
        } else {
            // Fallback on earlier versions
        }
    }

    return pageSize;
}

+(float)minNberOfImagesPerRow   // => 3 on iPhone, 5 on iPad
{
    return [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone ? 3.0 : 5.0;
}


#pragma mark - Images

+(NSInteger)imageCellHorizontalSpacing
{
    return ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) ? kImageCellSpacing4iPhone : kImageCellHorSpacing4iPad;
}

+(float)numberOfImagesPerRowForViewInPortrait:(UIView *)view withMaxWidth:(CGFloat)maxWidth
{
    // Thumbnails should always be available on server => default size of 144x144 pixels
    // We display at least 3 thumbnails per row and images never exceed the thumbnails size
    CGSize pageSize = [self sizeOfPageForView:view];
    float viewWidth = fmin(pageSize.width, pageSize.height);
    return fmax([self minNberOfImagesPerRow], roundf((viewWidth - 2.0 * kImageMarginsSpacing + [self imageCellHorizontalSpacing]) / ([self imageCellHorizontalSpacing] + maxWidth)));
}

+(float)imageSizeForView:(UIView *)view andNberOfImagesPerRowInPortrait:(NSInteger)imagesPerRowInPortrait
{
    // Size of view or screen
    CGSize pageSize = [self sizeOfPageForView:view];

    // Size of images determined for the portrait mode
    float imagesSizeInPortrait = floorf((fmin(pageSize.width,pageSize.height) - 2.0 * kImageMarginsSpacing - (imagesPerRowInPortrait - 1.0) * [self imageCellHorizontalSpacing]) / imagesPerRowInPortrait);
    
    // Images per row in whichever mode we are displaying them
    float imagesPerRow = fmax([self minNberOfImagesPerRow], roundf((pageSize.width - 2.0 * kImageMarginsSpacing + [self imageCellHorizontalSpacing]) / ([self imageCellHorizontalSpacing] + imagesSizeInPortrait)));
    
    // Size of squared images for that number
    return floorf((pageSize.width - 2.0 * kImageMarginsSpacing - (imagesPerRow - 1.0) * [self imageCellHorizontalSpacing]) / imagesPerRow);
}

+(NSInteger)numberOfImagesPerPageForView:(UIView *)view andNberOfImagesPerRowInPortrait:(NSInteger)imagesPerRowInPortrait
{
    // Size of view or screen
    CGSize pageSize = [self sizeOfPageForView:view];

    // Size of squared images for that number
    float size = [self imageSizeForView:view andNberOfImagesPerRowInPortrait:imagesPerRowInPortrait];

    // Number of images par page
    return (NSInteger)ceilf(pageSize.height / (size + [self imageCellHorizontalSpacing])) * imagesPerRowInPortrait;
}


#pragma mark - Categories

+(float)numberOfAlbumsPerRowForViewInPortrait:(UIView *)view withMaxWidth:(CGFloat)maxWidth
{
    // Size of view or screen
    CGSize pageSize = [self sizeOfPageForView:view];
    float viewWidth = fmin(pageSize.width, pageSize.height);
    
    return roundf((viewWidth - 2.0 * kAlbumMarginsSpacing + kAlbumCellSpacing) / (kAlbumCellSpacing + maxWidth));
}

+(float)albumSizeForView:(UIView *)view andNberOfAlbumsPerRowInPortrait:(NSInteger)albumsPerRowInPortrait
{
    // Size of view or screen
    CGSize pageSize = [self sizeOfPageForView:view];
    
    // Size of album cells determined for the portrait mode
    float albumsSizeInPortrait = floorf((fmin(pageSize.width,pageSize.height) - 2.0 * kAlbumMarginsSpacing - (albumsPerRowInPortrait - 1.0) * kAlbumCellSpacing) / albumsPerRowInPortrait);

    // Album cells per row in whichever mode we are displaying them
    float albumsPerRow = roundf((pageSize.width - 2.0 * kAlbumMarginsSpacing + kAlbumCellSpacing) / (kAlbumCellSpacing + albumsSizeInPortrait));

    // Width of albums for that number
    return floorf((pageSize.width - 2.0 * kAlbumMarginsSpacing - (albumsPerRow - 1.0) * kAlbumCellSpacing) / albumsPerRow);
}

@end
