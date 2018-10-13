//
//  PiwigoImageData.m
//  piwigo
//
//  Created by Spencer Baker on 1/15/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

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

+(NSString*)nameForThumbnailSizeType:(kPiwigoImageSize)imageSize
{
    NSString *sizeName = @"";
    
    switch(imageSize) {
        case kPiwigoImageSizeSquare:
            sizeName = NSLocalizedString(@"thumbnailSizeSquare", @"Square");
            break;
        case kPiwigoImageSizeThumb:
            sizeName = NSLocalizedString(@"thumbnailSizeThumbnail", @"Thumbnail");
            break;
        case kPiwigoImageSizeXXSmall:
            sizeName = NSLocalizedString(@"thumbnailSizeXXSmall", @"Tiny");
            break;
        case kPiwigoImageSizeXSmall:
            sizeName = NSLocalizedString(@"thumbnailSizeXSmall", @"Extra Small");
            break;
        case kPiwigoImageSizeSmall:
            sizeName = NSLocalizedString(@"thumbnailSizeSmall", @"Small");
            break;
        case kPiwigoImageSizeMedium:
            sizeName = NSLocalizedString(@"thumbnailSizeMedium", @"Medium");
            break;
        case kPiwigoImageSizeLarge:
            sizeName = NSLocalizedString(@"thumbnailSizeLarge", @"Large");
            break;
        case kPiwigoImageSizeXLarge:
            sizeName = NSLocalizedString(@"thumbnailSizeXLarge", @"Extra Large");
            break;
        case kPiwigoImageSizeXXLarge:
            sizeName = NSLocalizedString(@"thumbnailSizeXXLarge", @"Huge");
            break;
        case kPiwigoImageSizeFullRes:
            sizeName = NSLocalizedString(@"thumbnailSizexFullRes", @"Full Resolution");
            break;
        default:
            break;
    }
    
    return sizeName;
}

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

+(NSString*)nameForImageSizeType:(kPiwigoImageSize)imageSize withAdvice:(BOOL)advice
{
	NSString *sizeName = @"";
	
    // Determine the optimum image size for the current device
    NSInteger optimumSize = [self optimumImageSizeForDevice];

    // Retrun name for given image size
	switch(imageSize) {
		case kPiwigoImageSizeSquare:
			sizeName = NSLocalizedString(@"imageSizeSquare", @"Square");
			break;
		case kPiwigoImageSizeThumb:
			sizeName = NSLocalizedString(@"imageSizeThumbnail", @"Thumbnail");
			break;
		case kPiwigoImageSizeXXSmall:
			sizeName = NSLocalizedString(@"imageSizeXXSmall", @"Tiny");
			break;
		case kPiwigoImageSizeXSmall:
			sizeName = NSLocalizedString(@"imageSizeXSmall", @"Extra Small");
            if (advice && (optimumSize == kPiwigoImageSizeXSmall)) {
                sizeName = [sizeName stringByAppendingString:NSLocalizedString(@"defaultImageSize_recommended", @" (recommended)")];
            }
			break;
		case kPiwigoImageSizeSmall:
			sizeName = NSLocalizedString(@"imageSizeSmall", @"Small");
            if (advice && (optimumSize == kPiwigoImageSizeSmall)) {
                sizeName = [sizeName stringByAppendingString:NSLocalizedString(@"defaultImageSize_recommended", @" (recommended)")];
            }
			break;
		case kPiwigoImageSizeMedium:
			sizeName = NSLocalizedString(@"imageSizeMedium", @"Medium");
            if (advice && (optimumSize == kPiwigoImageSizeMedium)) {
                sizeName = [sizeName stringByAppendingString:NSLocalizedString(@"defaultImageSize_recommended", @" (recommended)")];
            }
			break;
		case kPiwigoImageSizeLarge:
			sizeName = NSLocalizedString(@"imageSizeLarge", @"Large");
            if (advice && (optimumSize == kPiwigoImageSizeLarge)) {
                sizeName = [sizeName stringByAppendingString:NSLocalizedString(@"defaultImageSize_recommended", @" (recommended)")];
            }
			break;
		case kPiwigoImageSizeXLarge:
			sizeName = NSLocalizedString(@"imageSizeXLarge", @"Extra Large");
            if (advice && (optimumSize == kPiwigoImageSizeXLarge)) {
                sizeName = [sizeName stringByAppendingString:NSLocalizedString(@"defaultImageSize_recommended", @" (recommended)")];
            }
			break;
		case kPiwigoImageSizeXXLarge:
			sizeName = NSLocalizedString(@"imageSizeXXLarge", @"Huge");
            if (advice && (optimumSize == kPiwigoImageSizeXXLarge)) {
                sizeName = [sizeName stringByAppendingString:NSLocalizedString(@"defaultImageSize_recommended", @" (recommended)")];
            }
			break;
		case kPiwigoImageSizeFullRes:
			sizeName = NSLocalizedString(@"imageSizexFullRes", @"Full Resolution");
            if (advice && (optimumSize == kPiwigoImageSizeFullRes)) {
                sizeName = [sizeName stringByAppendingString:NSLocalizedString(@"defaultImageSize_recommended", @" (recommended)")];
            }
			break;
		default:
			break;
	}
	
	return sizeName;
}

@end
