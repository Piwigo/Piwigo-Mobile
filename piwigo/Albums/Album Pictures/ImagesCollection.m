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

#pragma mark Determine number of images per row

@implementation ImagesCollection

+(float)numberOfImagesPerRowForViewInPortrait:(UIView *)view withMaxWidth:(NSInteger)maxWidth
{
    // Thumbnails should always be available on server
    // => default size of 144x144 pixels set in SettingsViewController
    // We display at least 3 thumbnails per row and images never exceed the thumbnails size
    return fmax(3.0, roundf((fmin(view.frame.size.width,view.frame.size.height) - 2.0 * kMarginsSpacing + kCellSpacing) / (kCellSpacing + maxWidth)));
}

+(float)imageSizeForView:(UIView *)view andNberOfImagesPerRowInPortrait:(NSInteger)imagesPerRowInPortrait
{
    float imagesSizeInPortrait = floorf((fmin(view.frame.size.width,view.frame.size.height) - 2.0 * kMarginsSpacing - (imagesPerRowInPortrait - 1.0) * kCellSpacing) / imagesPerRowInPortrait);
    float imagesPerRow = fmax(3.0, roundf((view.frame.size.width - 2.0 * kMarginsSpacing + kCellSpacing) / (kCellSpacing + imagesSizeInPortrait)));
    
    // Size of squared images for that number
    return floorf((view.frame.size.width - 2.0 * kMarginsSpacing - (imagesPerRow - 1.0) * kCellSpacing) / imagesPerRow);
}

+(NSInteger)numberOfImagesPerScreenForView:(UIView *)view andNberOfImagesPerRowInPortrait:(NSInteger)imagesPerRowInPortrait
{
    // Size of squared images for that number
    float size = [self imageSizeForView:view andNberOfImagesPerRowInPortrait:imagesPerRowInPortrait];

    return (NSInteger)ceilf(view.frame.size.height / (size + kCellSpacing)) * imagesPerRowInPortrait;
}

@end
