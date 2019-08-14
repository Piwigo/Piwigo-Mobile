//
//  PiwigoImageData.m
//  piwigo
//
//  Created by Spencer Baker on 1/15/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "ImagesCollection.h"
#import "PiwigoImageData.h"
#import "Model.h"

@implementation PiwigoImageData

-(NSString*)getURLFromImageSizeType:(kPiwigoImageSize)imageSize
{
	NSString *url = @"";
	
	switch(imageSize) {
		case kPiwigoImageSizeSquare:
			url = self.SquarePath;
			break;
		case kPiwigoImageSizeThumb:
			url = self.ThumbPath;
			break;
		case kPiwigoImageSizeXXSmall:
			url = self.XXSmallPath;
			break;
		case kPiwigoImageSizeXSmall:
			url = self.XSmallPath;
			break;
		case kPiwigoImageSizeSmall:
			url = self.SmallPath;
			break;
		case kPiwigoImageSizeMedium:
			url = self.MediumPath;
			break;
		case kPiwigoImageSizeLarge:
			url = self.LargePath;
			break;
		case kPiwigoImageSizeXLarge:
			url = self.XLargePath;
			break;
		case kPiwigoImageSizeXXLarge:
			url = self.XXLargePath;
			break;
		case kPiwigoImageSizeFullRes:
			url = self.fullResPath;
			break;
		default:
			break;
	}
	
	return url;
}

+(CGFloat)widthForImageSizeType:(kPiwigoImageSize)imageSize
{
    // Get device scale factor
    CGFloat scale = [[UIScreen mainScreen] scale];
    
    // Default width
    CGFloat width = 120;
    
    switch(imageSize) {
        case kPiwigoImageSizeSquare:
            width = 120;
            break;
        case kPiwigoImageSizeThumb:
            width = 144;
            break;
        case kPiwigoImageSizeXXSmall:
            width = 240;
            break;
        case kPiwigoImageSizeXSmall:
            width = 324;
            break;
        case kPiwigoImageSizeSmall:
            width = 432;
            break;
        case kPiwigoImageSizeMedium:
            width = 594;
            break;
        case kPiwigoImageSizeLarge:
            width = 756;
            break;
        case kPiwigoImageSizeXLarge:
            width = 918;
            break;
        case kPiwigoImageSizeXXLarge:
            width = 1242;
            break;
        case kPiwigoImageSizeFullRes:
            width = 1242;
            break;
        default:
            break;
    }
    
    return width/scale;
}

+(NSString*)sizeForImageSizeType:(kPiwigoImageSize)imageSize
{
    NSString *sizeName = @"";
    
    switch(imageSize) {
        case kPiwigoImageSizeSquare:
            sizeName = @" (120x120@1x)";
            break;
        case kPiwigoImageSizeThumb:
            sizeName = @" (144x144@1x)";
            break;
        case kPiwigoImageSizeXXSmall:
            sizeName = @" (240x240@1x)";
            break;
        case kPiwigoImageSizeXSmall:
            sizeName = @" (432x324@1x)";
            break;
        case kPiwigoImageSizeSmall:
            sizeName = @" (576x432@1x)";
            break;
        case kPiwigoImageSizeMedium:
            sizeName = @" (792x594@1x)";
            break;
        case kPiwigoImageSizeLarge:
            sizeName = @" (1008x756@1x)";
            break;
        case kPiwigoImageSizeXLarge:
            sizeName = @" (1224x918@1x)";
            break;
        case kPiwigoImageSizeXXLarge:
            sizeName = @" (1656x1242@1x)";
            break;
        case kPiwigoImageSizeFullRes:
            sizeName = @"";
            break;
        default:
            break;
    }
    
    return sizeName;
}


#pragma mark - Album thumbnails

+(NSInteger)optimumAlbumThumbnailSizeForDevice
{
    // Size of album thumbnails is 144x144 points (see AlbumTableViewCell.xib)
    // => recommend 144@3x
    return kPiwigoImageSizeSmall;
}

+(NSString*)nameForAlbumThumbnailSizeType:(kPiwigoImageSize)imageSize withInfo:(BOOL)addInfo
{
    NSString *sizeName = @"";
    
    // Determine the optimum image size for the current device
    NSInteger optimumSize = [self optimumAlbumThumbnailSizeForDevice];
    
    // Return name for given thumbnail size
    switch(imageSize) {
        case kPiwigoImageSizeSquare:
            sizeName = NSLocalizedString(@"thumbnailSizeSquare", @"Square");
            if (addInfo) {
                if (optimumSize == kPiwigoImageSizeSquare) {
                    sizeName = [sizeName stringByAppendingString:NSLocalizedString(@"defaultImageSize_recommended", @" (recommended)")];
                } else {
                    sizeName = [sizeName stringByAppendingString:[PiwigoImageData sizeForImageSizeType:imageSize]];
                }
            }
            break;
        case kPiwigoImageSizeThumb:
            sizeName = NSLocalizedString(@"thumbnailSizeThumbnail", @"Thumbnail");
            if (addInfo) {
                if (optimumSize == kPiwigoImageSizeThumb) {
                    sizeName = [sizeName stringByAppendingString:NSLocalizedString(@"defaultImageSize_recommended", @" (recommended)")];
                } else {
                    sizeName = [sizeName stringByAppendingString:[PiwigoImageData sizeForImageSizeType:imageSize]];
                }
            }
            break;
        case kPiwigoImageSizeXXSmall:
            sizeName = NSLocalizedString(@"thumbnailSizeXXSmall", @"Tiny");
            if (addInfo) {
                if (optimumSize == kPiwigoImageSizeXXSmall) {
                    sizeName = [sizeName stringByAppendingString:NSLocalizedString(@"defaultImageSize_recommended", @" (recommended)")];
                } else {
                    sizeName = [sizeName stringByAppendingString:[PiwigoImageData sizeForImageSizeType:imageSize]];
                }
            }
            break;
        case kPiwigoImageSizeXSmall:
            sizeName = NSLocalizedString(@"thumbnailSizeXSmall", @"Extra Small");
            if (addInfo) {
                if (optimumSize == kPiwigoImageSizeXSmall) {
                    sizeName = [sizeName stringByAppendingString:NSLocalizedString(@"defaultImageSize_recommended", @" (recommended)")];
                } else {
                    sizeName = [sizeName stringByAppendingString:[PiwigoImageData sizeForImageSizeType:imageSize]];
                }
            }
            break;
        case kPiwigoImageSizeSmall:
            sizeName = NSLocalizedString(@"thumbnailSizeSmall", @"Small");
            if (addInfo) {
                if (optimumSize == kPiwigoImageSizeSmall) {
                    sizeName = [sizeName stringByAppendingString:NSLocalizedString(@"defaultImageSize_recommended", @" (recommended)")];
                } else {
                    sizeName = [sizeName stringByAppendingString:[PiwigoImageData sizeForImageSizeType:imageSize]];
                }
            }
            break;
        case kPiwigoImageSizeMedium:
            sizeName = NSLocalizedString(@"thumbnailSizeMedium", @"Medium");
            if (addInfo) {
                if (optimumSize == kPiwigoImageSizeMedium) {
                    sizeName = [sizeName stringByAppendingString:NSLocalizedString(@"defaultImageSize_recommended", @" (recommended)")];
                } else {
                    sizeName = [sizeName stringByAppendingString:[PiwigoImageData sizeForImageSizeType:imageSize]];
                }
            }
            break;
        case kPiwigoImageSizeLarge:
            sizeName = NSLocalizedString(@"thumbnailSizeLarge", @"Large");
            if (addInfo) {
                sizeName = [sizeName stringByAppendingString:[PiwigoImageData sizeForImageSizeType:imageSize]];
            }
            break;
        case kPiwigoImageSizeXLarge:
            sizeName = NSLocalizedString(@"thumbnailSizeXLarge", @"Extra Large");
            if (addInfo) {
                sizeName = [sizeName stringByAppendingString:[PiwigoImageData sizeForImageSizeType:imageSize]];
            }
            break;
        case kPiwigoImageSizeXXLarge:
            sizeName = NSLocalizedString(@"thumbnailSizeXXLarge", @"Huge");
            if (addInfo) {
                sizeName = [sizeName stringByAppendingString:[PiwigoImageData sizeForImageSizeType:imageSize]];
            }
            break;
        case kPiwigoImageSizeFullRes:
            sizeName = NSLocalizedString(@"thumbnailSizexFullRes", @"Full Resolution");
            break;
        default:
            break;
    }
    
    return sizeName;
}


#pragma mark - Image thumbnails

+(NSInteger)optimumImageThumbnailSizeForDevice
{
    // Get optimum number of images per row
    float nberThumbnailsPerRow = [ImagesCollection minNberOfImagesPerRow];
    
    // Square ?
    NSInteger minNberOfImages = [ImagesCollection numberOfImagesPerRowForViewInPortrait:nil withMaxWidth:[self widthForImageSizeType:kPiwigoImageSizeSquare]];
    if (minNberOfImages <= nberThumbnailsPerRow) {
        return kPiwigoImageSizeSquare;
    }

    // Thumbnail ?
    minNberOfImages = [ImagesCollection numberOfImagesPerRowForViewInPortrait:nil withMaxWidth:[self widthForImageSizeType:kPiwigoImageSizeThumb]];
    if (minNberOfImages <= nberThumbnailsPerRow) {
        return kPiwigoImageSizeThumb;
    }

    // XXSmall ?
    minNberOfImages = [ImagesCollection numberOfImagesPerRowForViewInPortrait:nil withMaxWidth:[self widthForImageSizeType:kPiwigoImageSizeXXSmall]];
    if (minNberOfImages <= nberThumbnailsPerRow) {
        return kPiwigoImageSizeXXSmall;
    }
    
    // XSmall ?
    minNberOfImages = [ImagesCollection numberOfImagesPerRowForViewInPortrait:nil withMaxWidth:[self widthForImageSizeType:kPiwigoImageSizeXSmall]];
    if (minNberOfImages <= nberThumbnailsPerRow) {
        return kPiwigoImageSizeXSmall;
    }
    
    // Small ?
    minNberOfImages = [ImagesCollection numberOfImagesPerRowForViewInPortrait:nil withMaxWidth:[self widthForImageSizeType:kPiwigoImageSizeSmall]];
    if (minNberOfImages <= nberThumbnailsPerRow) {
        return kPiwigoImageSizeSmall;
    }
    
    // Medium ?
    minNberOfImages = [ImagesCollection numberOfImagesPerRowForViewInPortrait:nil withMaxWidth:[self widthForImageSizeType:kPiwigoImageSizeMedium]];
    if (minNberOfImages <= nberThumbnailsPerRow) {
        return kPiwigoImageSizeMedium;
    }
    
    // Large ?
    minNberOfImages = [ImagesCollection numberOfImagesPerRowForViewInPortrait:nil withMaxWidth:[self widthForImageSizeType:kPiwigoImageSizeLarge]];
    if (minNberOfImages <= nberThumbnailsPerRow) {
        return kPiwigoImageSizeLarge;
    }
    
    // XLarge ?
    minNberOfImages = [ImagesCollection numberOfImagesPerRowForViewInPortrait:nil withMaxWidth:[self widthForImageSizeType:kPiwigoImageSizeXLarge]];
    if (minNberOfImages <= nberThumbnailsPerRow) {
        return kPiwigoImageSizeXLarge;
    }
    
    // XXLarge ?
    minNberOfImages = [ImagesCollection numberOfImagesPerRowForViewInPortrait:nil withMaxWidth:[self widthForImageSizeType:kPiwigoImageSizeXXLarge]];
    if (minNberOfImages <= nberThumbnailsPerRow) {
        return kPiwigoImageSizeXXLarge;
    }
    
    return kPiwigoImageSizeThumb;
}

+(NSString*)nameForImageThumbnailSizeType:(kPiwigoImageSize)imageSize withInfo:(BOOL)addInfo
{
    NSString *sizeName = @"";
    
    // Determine the optimum image size for the current device
    NSInteger optimumSize = [self optimumImageThumbnailSizeForDevice];
    
    // Return name for given thumbnail size
    switch(imageSize) {
        case kPiwigoImageSizeSquare:
            sizeName = NSLocalizedString(@"thumbnailSizeSquare", @"Square");
            if (addInfo) {
                if (optimumSize == kPiwigoImageSizeSquare) {
                    sizeName = [sizeName stringByAppendingString:NSLocalizedString(@"defaultImageSize_recommended", @" (recommended)")];
                } else {
                    sizeName = [sizeName stringByAppendingString:[PiwigoImageData sizeForImageSizeType:imageSize]];
                }
            }
            break;
        case kPiwigoImageSizeThumb:
            sizeName = NSLocalizedString(@"thumbnailSizeThumbnail", @"Thumbnail");
            if (addInfo) {
                if (optimumSize == kPiwigoImageSizeThumb) {
                    sizeName = [sizeName stringByAppendingString:NSLocalizedString(@"defaultImageSize_recommended", @" (recommended)")];
                } else {
                    sizeName = [sizeName stringByAppendingString:[PiwigoImageData sizeForImageSizeType:imageSize]];
                }
            }
            break;
        case kPiwigoImageSizeXXSmall:
            sizeName = NSLocalizedString(@"thumbnailSizeXXSmall", @"Tiny");
            if (addInfo) {
                if (optimumSize == kPiwigoImageSizeXXSmall) {
                    sizeName = [sizeName stringByAppendingString:NSLocalizedString(@"defaultImageSize_recommended", @" (recommended)")];
                } else {
                    sizeName = [sizeName stringByAppendingString:[PiwigoImageData sizeForImageSizeType:imageSize]];
                }
            }
            break;
        case kPiwigoImageSizeXSmall:
            sizeName = NSLocalizedString(@"thumbnailSizeXSmall", @"Extra Small");
            if (addInfo) {
                if (optimumSize == kPiwigoImageSizeXSmall) {
                    sizeName = [sizeName stringByAppendingString:NSLocalizedString(@"defaultImageSize_recommended", @" (recommended)")];
                } else {
                    sizeName = [sizeName stringByAppendingString:[PiwigoImageData sizeForImageSizeType:imageSize]];
                }
            }
            break;
        case kPiwigoImageSizeSmall:
            sizeName = NSLocalizedString(@"thumbnailSizeSmall", @"Small");
            if (addInfo) {
                if (optimumSize == kPiwigoImageSizeSmall) {
                    sizeName = [sizeName stringByAppendingString:NSLocalizedString(@"defaultImageSize_recommended", @" (recommended)")];
                } else {
                    sizeName = [sizeName stringByAppendingString:[PiwigoImageData sizeForImageSizeType:imageSize]];
                }
            }
            break;
        case kPiwigoImageSizeMedium:
            sizeName = NSLocalizedString(@"thumbnailSizeMedium", @"Medium");
            if (addInfo) {
                if (optimumSize == kPiwigoImageSizeMedium) {
                    sizeName = [sizeName stringByAppendingString:NSLocalizedString(@"defaultImageSize_recommended", @" (recommended)")];
                } else {
                    sizeName = [sizeName stringByAppendingString:[PiwigoImageData sizeForImageSizeType:imageSize]];
                }
            }
            break;
        case kPiwigoImageSizeLarge:
            sizeName = NSLocalizedString(@"thumbnailSizeLarge", @"Large");
            if (addInfo) {
                sizeName = [sizeName stringByAppendingString:[PiwigoImageData sizeForImageSizeType:imageSize]];
            }
            break;
        case kPiwigoImageSizeXLarge:
            sizeName = NSLocalizedString(@"thumbnailSizeXLarge", @"Extra Large");
            if (addInfo) {
                sizeName = [sizeName stringByAppendingString:[PiwigoImageData sizeForImageSizeType:imageSize]];
            }
            break;
        case kPiwigoImageSizeXXLarge:
            sizeName = NSLocalizedString(@"thumbnailSizeXXLarge", @"Huge");
            if (addInfo) {
                sizeName = [sizeName stringByAppendingString:[PiwigoImageData sizeForImageSizeType:imageSize]];
            }
            break;
        case kPiwigoImageSizeFullRes:
            sizeName = NSLocalizedString(@"thumbnailSizexFullRes", @"Full Resolution");
            break;
        default:
            break;
    }
    
    return sizeName;
}


#pragma mark - Images

+(NSInteger)optimumImageSizeForDevice
{
    // Determine the resolution of the screen
    // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
    // See https://www.apple.com/iphone/compare/ and https://www.apple.com/ipad/compare/
    CGRect screen = [[UIScreen mainScreen] bounds];
    NSInteger points = (int)fmax(screen.size.width, screen.size.height);
    
    if (points <= 324) {                            // XS - extra small - 432 x 324 pixels
        return kPiwigoImageSizeXSmall;
    }
    else if ((points > 324) && (points <= 432)) {   // S - small - 576 x 432 pixels
        return kPiwigoImageSizeSmall;
    }
    else if ((points > 432) && (points <= 594)) {   // M - medium - 792 x 594 pixels
        return kPiwigoImageSizeMedium;              // iPhone 2G, 3G, 3GS, 4, 4s, 5, 5s, 5c, SE
    }
    else if ((points > 594) && (points <= 756)) {   // L - large - 1008 x 756 pixels
        return kPiwigoImageSizeLarge;               // iPhone 6, 6s, 7, 8, 6+, 6s+, 7+, 8+
    }
    else if ((points > 756) && (points <= 918)) {   // XL - extra large - 1224 x 918 pixels
        return kPiwigoImageSizeXLarge;              // Iphone X, Xs, Xr, Xs Max
    }
    else if ((points > 918) && (points <= 1242)) {  // XXL - huge - 1656 x 1242 pixels
    return kPiwigoImageSizeXXLarge;                 // Ipad 2, Air, Air 2, Pro 9.7-inch, Pro 10.5-inch
    }
    else {
        return kPiwigoImageSizeFullRes;             // iPad Pro 12.9-inch
    }
}

+(NSString*)nameForImageSizeType:(kPiwigoImageSize)imageSize withInfo:(BOOL)addInfo
{
	NSString *sizeName = @"";
	
    // Determine the optimum image size for the current device
    NSInteger optimumSize = [self optimumImageSizeForDevice];

    // Return name for given image size
	switch(imageSize) {
		case kPiwigoImageSizeSquare:
			sizeName = NSLocalizedString(@"imageSizeSquare", @"Square");
            if (addInfo) {
                sizeName = [sizeName stringByAppendingString:[PiwigoImageData sizeForImageSizeType:imageSize]];
            }
			break;
		case kPiwigoImageSizeThumb:
			sizeName = NSLocalizedString(@"imageSizeThumbnail", @"Thumbnail");
            if (addInfo) {
                sizeName = [sizeName stringByAppendingString:[PiwigoImageData sizeForImageSizeType:imageSize]];
            }
			break;
		case kPiwigoImageSizeXXSmall:
			sizeName = NSLocalizedString(@"imageSizeXXSmall", @"Tiny");
            if (addInfo) {
                sizeName = [sizeName stringByAppendingString:[PiwigoImageData sizeForImageSizeType:imageSize]];
            }
			break;
		case kPiwigoImageSizeXSmall:
			sizeName = NSLocalizedString(@"imageSizeXSmall", @"Extra Small");
            if (addInfo) {
                if (optimumSize == kPiwigoImageSizeXSmall) {
                    sizeName = [sizeName stringByAppendingString:NSLocalizedString(@"defaultImageSize_recommended", @" (recommended)")];
                } else {
                    sizeName = [sizeName stringByAppendingString:[PiwigoImageData sizeForImageSizeType:imageSize]];
                }
            }
			break;
		case kPiwigoImageSizeSmall:
			sizeName = NSLocalizedString(@"imageSizeSmall", @"Small");
            if (addInfo) {
                if (optimumSize == kPiwigoImageSizeSmall) {
                    sizeName = [sizeName stringByAppendingString:NSLocalizedString(@"defaultImageSize_recommended", @" (recommended)")];
                } else {
                    sizeName = [sizeName stringByAppendingString:[PiwigoImageData sizeForImageSizeType:imageSize]];
                }
            }
			break;
		case kPiwigoImageSizeMedium:
			sizeName = NSLocalizedString(@"imageSizeMedium", @"Medium");
            if (addInfo) {
                if (optimumSize == kPiwigoImageSizeMedium) {
                    sizeName = [sizeName stringByAppendingString:NSLocalizedString(@"defaultImageSize_recommended", @" (recommended)")];
                } else {
                    sizeName = [sizeName stringByAppendingString:[PiwigoImageData sizeForImageSizeType:imageSize]];
                }
            }
			break;
		case kPiwigoImageSizeLarge:
			sizeName = NSLocalizedString(@"imageSizeLarge", @"Large");
            if (addInfo) {
                if (optimumSize == kPiwigoImageSizeLarge) {
                    sizeName = [sizeName stringByAppendingString:NSLocalizedString(@"defaultImageSize_recommended", @" (recommended)")];
                } else {
                    sizeName = [sizeName stringByAppendingString:[PiwigoImageData sizeForImageSizeType:imageSize]];
                }
            }
			break;
		case kPiwigoImageSizeXLarge:
			sizeName = NSLocalizedString(@"imageSizeXLarge", @"Extra Large");
            if (addInfo) {
                if (optimumSize == kPiwigoImageSizeXLarge) {
                    sizeName = [sizeName stringByAppendingString:NSLocalizedString(@"defaultImageSize_recommended", @" (recommended)")];
                } else {
                    sizeName = [sizeName stringByAppendingString:[PiwigoImageData sizeForImageSizeType:imageSize]];
                }
            }
			break;
		case kPiwigoImageSizeXXLarge:
			sizeName = NSLocalizedString(@"imageSizeXXLarge", @"Huge");
            if (addInfo) {
                if (optimumSize == kPiwigoImageSizeXXLarge) {
                    sizeName = [sizeName stringByAppendingString:NSLocalizedString(@"defaultImageSize_recommended", @" (recommended)")];
                } else {
                    sizeName = [sizeName stringByAppendingString:[PiwigoImageData sizeForImageSizeType:imageSize]];
                }
            }
			break;
		case kPiwigoImageSizeFullRes:
			sizeName = NSLocalizedString(@"imageSizexFullRes", @"Full Resolution");
            if (addInfo && (optimumSize == kPiwigoImageSizeFullRes)) {
                sizeName = [sizeName stringByAppendingString:NSLocalizedString(@"defaultImageSize_recommended", @" (recommended)")];
            }
			break;
		default:
			break;
	}
	
	return sizeName;
}

@end
