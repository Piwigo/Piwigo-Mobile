//
//  ImagesCollection.m
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 28/08/2017.
//  Copyright © 2017 Piwigo.org. All rights reserved.
//

#import "ImagesCollection.h"

CGFloat const kAlbumCellSpacing = 8;              // Spacing between albums (horizontally and vertically)
CGFloat const kAlbumMarginsSpacing = 4;           // Left and right margins for albums

CGFloat const kImageCellSpacing4iPhone = 1;       // Spacing between images (horizontally and vertically)
CGFloat const kImageCellHorSpacing4iPad = 8;
CGFloat const kImageCellHorSpacing4iPadPopup = 1;
CGFloat const kImageCellVertSpacing4iPad = 8;
CGFloat const kImageCellVertSpacing4iPadPopup = 1;
CGFloat const kImageMarginsSpacing = 4;           // Left and right margins for images
CGFloat const kThumbnailFileSize = 144;           // Default Piwigo thumbnail file size

CGFloat const kImageDetailsCellSpacing = 8;       // Spacing between image details cells
CGFloat const kImageDetailsMarginsSpacing = 16;   // Left and right margins for image details cells

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

+(NSInteger)imageCellHorizontalSpacingForCollectionType:(kImageCollectionType)type
{
    NSInteger imageCellHorizontalSpacing;

    switch (type) {
        case kImageCollectionPopup:
            imageCellHorizontalSpacing = ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) ? kImageCellSpacing4iPhone : kImageCellHorSpacing4iPadPopup;
            break;
            
        case kImageCollectionFull:
            imageCellHorizontalSpacing = ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) ? kImageCellSpacing4iPhone : kImageCellHorSpacing4iPad;
            break;
            
        default:
            imageCellHorizontalSpacing = 0;
            break;
    }

    return imageCellHorizontalSpacing;
}

+(NSInteger)imageCellVerticalSpacingForCollectionType:(kImageCollectionType)type
{
    NSInteger imageCellVerticalSpacing;
    
    switch (type) {
        case kImageCollectionPopup:
            imageCellVerticalSpacing = ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) ? kImageCellSpacing4iPhone : kImageCellVertSpacing4iPadPopup;
            break;
            
        case kImageCollectionFull:
            imageCellVerticalSpacing = ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) ? kImageCellSpacing4iPhone : kImageCellVertSpacing4iPad;
            break;
            
        default:
            imageCellVerticalSpacing = 0;
            break;
    }
    
    return imageCellVerticalSpacing;
}

+(float)imagesPerRowInPortraitForView:(UIView *)view maxWidth:(float)maxWidth
{
    // We display at least 3 thumbnails per row and images never exceed the thumbnails size
    return [self imagesPerRowInPortraitForView:view maxWidth:maxWidth collectionType:kImageCollectionFull];
}

+(float)imagesPerRowInPortraitForView:(UIView *)view maxWidth:(float)maxWidth collectionType:(kImageCollectionType)type
{
    // We display at least 3 thumbnails per row and images never exceed the thumbnails size
    CGSize pageSize = [self sizeOfPageForView:view];
    float viewWidth = fmin(pageSize.width, pageSize.height);
    return fmax([self minNberOfImagesPerRow], roundf((viewWidth - 2.0 * kImageMarginsSpacing + [self imageCellHorizontalSpacingForCollectionType:type]) / ([self imageCellHorizontalSpacingForCollectionType:type] + maxWidth)));
}

+(float)imageSizeForView:(UIView *)view imagesPerRowInPortrait:(NSInteger)imagesPerRowInPortrait 
{
    return [self imageSizeForView:view imagesPerRowInPortrait:imagesPerRowInPortrait collectionType:kImageCollectionFull];
}

+(float)imageSizeForView:(UIView *)view imagesPerRowInPortrait:(NSInteger)imagesPerRowInPortrait collectionType:(kImageCollectionType)type
{
    // Size of view or screen
    CGSize pageSize = [self sizeOfPageForView:view];
    
    // Image horizontal cell spacing
    NSInteger imageCellHorizontalSpacing = [self imageCellHorizontalSpacingForCollectionType:type];

    // Size of images determined for the portrait mode
    float imagesSizeInPortrait = floorf((fmin(pageSize.width,pageSize.height) - 2.0 * kImageMarginsSpacing - (imagesPerRowInPortrait - 1.0) * imageCellHorizontalSpacing) / imagesPerRowInPortrait);
    
    // Images per row in whichever mode we are displaying them
    float imagesPerRow = fmax([self minNberOfImagesPerRow], roundf((pageSize.width - 2.0 * kImageMarginsSpacing + imageCellHorizontalSpacing) / (imageCellHorizontalSpacing + imagesSizeInPortrait)));
    
    // Size of squared images for that number
    return floorf((pageSize.width - 2.0 * kImageMarginsSpacing - (imagesPerRow - 1.0) * imageCellHorizontalSpacing) / imagesPerRow);
}

+(NSInteger)numberOfImagesPerPageForView:(UIView *)view imagesPerRowInPortrait:(NSInteger)imagesPerRowInPortrait
{
    return [self numberOfImagesPerPageForView:view imagesPerRowInPortrait:imagesPerRowInPortrait collectionType:kImageCollectionFull];
}

+(NSInteger)numberOfImagesPerPageForView:(UIView *)view imagesPerRowInPortrait:(NSInteger)imagesPerRowInPortrait collectionType:(kImageCollectionType)type
{
    // Size of view or screen
    CGSize pageSize = [self sizeOfPageForView:view];

    // Size of squared images for that number
    float size = [self imageSizeForView:view imagesPerRowInPortrait:imagesPerRowInPortrait];

    // Image horizontal cell spacing
    NSInteger imageCellHorizontalSpacing = [self imageCellHorizontalSpacingForCollectionType:type];
    
    // Number of images par page
    return (NSInteger)ceil(pageSize.height / (size + imageCellHorizontalSpacing)) * imagesPerRowInPortrait;
}


#pragma mark - Thumbnails

+(float)imageDetailsSizeForView:(UIView *)view // andNberOfImageDetailsPerRowInPortrait:(NSInteger)detailsPerRowInPortrait
{
    // Size of view or screen
    CGSize cellSize = [self sizeOfPageForView:view];
    
    return MIN(cellSize.width - 2.0 * kImageDetailsMarginsSpacing, 340.0);
}


#pragma mark - Categories

+(float)numberOfAlbumsPerRowForViewInPortrait:(UIView *)view withMaxWidth:(float)maxWidth
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
