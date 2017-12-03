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
            sizeName = NSLocalizedString(@"thumbnailSizeThumbnail", @"Thumbnail (default)");
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

+(NSString*)nameForImageSizeType:(kPiwigoImageSize)imageSize
{
	NSString *sizeName = @"";
	
    // Determine the resolution of the screen
    // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
    // See https://www.apple.com/iphone/compare/ and https://www.apple.com/ipad/compare/
    CGRect screen = [[UIScreen mainScreen] bounds];
    NSInteger points = (int)fmax(screen.size.width, screen.size.height);
    
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
            if ((points <= 324) && [Model sharedInstance].hasXSmallSizeImages) {
                sizeName = [sizeName stringByAppendingString:NSLocalizedString(@"defaultImageSize_recommended", @" (recommended)")];
            }
			break;
		case kPiwigoImageSizeSmall:
			sizeName = NSLocalizedString(@"imageSizeSmall", @"Small");
            if ((points > 324) && (points <= 432) && [Model sharedInstance].hasSmallSizeImages) {
                sizeName = [sizeName stringByAppendingString:NSLocalizedString(@"defaultImageSize_recommended", @" (recommended)")];
            }
			break;
		case kPiwigoImageSizeMedium:
			sizeName = NSLocalizedString(@"imageSizeMedium", @"Medium");
            if ((points > 432) && (points <= 594) && [Model sharedInstance].hasMediumSizeImages) {
                sizeName = [sizeName stringByAppendingString:NSLocalizedString(@"defaultImageSize_recommended", @" (recommended)")];
            }
			break;
		case kPiwigoImageSizeLarge:
			sizeName = NSLocalizedString(@"imageSizeLarge", @"Large");
            if ((points > 594) && (points <= 756) && [Model sharedInstance].hasLargeSizeImages) {
                sizeName = [sizeName stringByAppendingString:NSLocalizedString(@"defaultImageSize_recommended", @" (recommended)")];
            }
			break;
		case kPiwigoImageSizeXLarge:
			sizeName = NSLocalizedString(@"imageSizeXLarge", @"Extra Large");
            if ((points > 756) && (points <= 918) &&[Model sharedInstance].hasXLargeSizeImages) {
                sizeName = [sizeName stringByAppendingString:NSLocalizedString(@"defaultImageSize_recommended", @" (recommended)")];
            }
			break;
		case kPiwigoImageSizeXXLarge:
			sizeName = NSLocalizedString(@"imageSizeXXLarge", @"Huge");
            if ((points > 918) && (points <= 1242) && [Model sharedInstance].hasXXLargeSizeImages) {
                sizeName = [sizeName stringByAppendingString:NSLocalizedString(@"defaultImageSize_recommended", @" (recommended)")];
            }
			break;
		case kPiwigoImageSizeFullRes:
			sizeName = NSLocalizedString(@"imageSizexFullRes", @"Full Resolution");
            if (points > 1242) {
                sizeName = [sizeName stringByAppendingString:NSLocalizedString(@"defaultImageSize_recommended", @" (recommended)")];
            }
			break;
		default:
			break;
	}
	
	return sizeName;
}

@end
