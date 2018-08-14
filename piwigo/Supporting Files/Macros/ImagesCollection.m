//
//  ImagesCollection.m
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 28/08/2017.
//  Copyright © 2017 Piwigo.org. All rights reserved.
//

#import "ImagesCollection.h"
#import "Model.h"

NSInteger const kCellSpacing = 1;               // Spacing between items (horizontally and vertically)
NSInteger const kMarginsSpacing = 0;            // Left and right margins
NSInteger const kThumbnailFileSize = 144;       // Default Piwigo thumbnail file size

@implementation ImagesCollection

+(CGSize)sizeOfPageForView:(UIView *)view
{
    CGSize pageSize;
    if (view == nil) {
        CGRect screenRect = [[UIScreen mainScreen] bounds];
        pageSize = screenRect.size;
    } else {
        if (@available(iOS 11.0, *)) {
            pageSize = view.safeAreaLayoutGuide.layoutFrame.size;
            if (pageSize.width == 0.0) pageSize = view.frame.size;
        } else {
            // Fallback on earlier versions
            pageSize = view.frame.size;
        }
    }

    return pageSize;
}

#pragma mark - Images

+(float)numberOfImagesPerRowForViewInPortrait:(UIView *)view withMaxWidth:(NSInteger)maxWidth
{
    // Thumbnails should always be available on server
    // => default size of 144x144 pixels set in SettingsViewController
    // We display at least 3 thumbnails per row and images never exceed the thumbnails size
    CGSize pageSize = [self sizeOfPageForView:view];
    float viewWidth = fmin(pageSize.width, pageSize.height);
    
    return fmax(3.0, roundf((viewWidth - 2.0 * kMarginsSpacing + kCellSpacing) / (kCellSpacing + maxWidth)));
}

+(float)imageSizeForView:(UIView *)view andNberOfImagesPerRowInPortrait:(NSInteger)imagesPerRowInPortrait
{
    // Size of view or screen
    CGSize pageSize = [self sizeOfPageForView:view];

    // Size of images determined for the portrait mode
    float imagesSizeInPortrait = floorf((fmin(pageSize.width,pageSize.height) - 2.0 * kMarginsSpacing - (imagesPerRowInPortrait - 1.0) * kCellSpacing) / imagesPerRowInPortrait);
    
    // Images per row in whichever mode we are displaying them
    float imagesPerRow = fmax(3.0, roundf((pageSize.width - 2.0 * kMarginsSpacing + kCellSpacing) / (kCellSpacing + imagesSizeInPortrait)));
    
    // Size of squared images for that number
    return floorf((pageSize.width - 2.0 * kMarginsSpacing - (imagesPerRow - 1.0) * kCellSpacing) / imagesPerRow);
}

+(NSInteger)numberOfImagesPerPageForView:(UIView *)view andNberOfImagesPerRowInPortrait:(NSInteger)imagesPerRowInPortrait
{
    // Size of view or screen
    CGSize pageSize = [self sizeOfPageForView:view];

    // Size of squared images for that number
    float size = [self imageSizeForView:view andNberOfImagesPerRowInPortrait:imagesPerRowInPortrait];

    // Number of images par page
    return (NSInteger)ceilf(pageSize.height / (size + kCellSpacing)) * imagesPerRowInPortrait;
}


#pragma mark - Categories

+(float)numberOfAlbumsPerRowForViewInPortrait:(UIView *)view withMaxWidth:(NSInteger)maxWidth
{
    // Size of view or screen
    CGSize pageSize = [self sizeOfPageForView:view];
    float viewWidth = fmin(pageSize.width, pageSize.height);
    
    return roundf((viewWidth - 2.0 * kMarginsSpacing + kCellSpacing) / (kCellSpacing + maxWidth));
}

+(float)albumSizeForView:(UIView *)view andNberOfAlbumsPerRowInPortrait:(NSInteger)albumsPerRowInPortrait
{
    // Size of view or screen
    CGSize pageSize = [self sizeOfPageForView:view];
    
    // Size of album cells determined for the portrait mode
    float albumsSizeInPortrait = floorf((fmin(pageSize.width,pageSize.height) - 2.0 * kMarginsSpacing - (albumsPerRowInPortrait - 1.0) * kCellSpacing) / albumsPerRowInPortrait);

    // Album cells per row in whichever mode we are displaying them
    float albumsPerRow = roundf((pageSize.width - 2.0 * kMarginsSpacing + kCellSpacing) / (kCellSpacing + albumsSizeInPortrait));

    // Width of albums for that number
    return floorf((pageSize.width - 2.0 * kMarginsSpacing - (albumsPerRow - 1.0) * kCellSpacing) / albumsPerRow);
}

@end
