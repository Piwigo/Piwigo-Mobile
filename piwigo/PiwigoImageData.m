//
//  PiwigoImageData.m
//  piwigo
//
//  Created by Spencer Baker on 1/15/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "PiwigoImageData.h"

@implementation PiwigoImageData

-(NSString*)getURLFromImageSizeType:(kPiwigoImageSize)imageSize
{
	NSString *url = @"";
	
	switch(imageSize) {
		case kPiwigoImageSizeSquare:
			url = self.squarePath;
			break;
		case kPiwigoImageSizeThumb:
			url = self.thumbPath;
			break;
		case kPiwigoImageSizexxSmall:
			url = self.xxSmall;
			break;
		case kPiwigoImageSizexSmall:
			url = self.xSmall;
			break;
		case kPiwigoImageSizeSmall:
			url = self.small;
			break;
		case kPiwigoImageSizeMedium:
			url = self.mediumPath;
			break;
		case kPiwigoImageSizeLarge:
			url = self.large;
			break;
		case kPiwigoImageSizexLarge:
			url = self.xLarge;
			break;
		case kPiwigoImageSizexxLarge:
			url = self.xxLarge;
			break;
		case kPiwigoImageSizeFullRes:
			url = self.fullResPath;
			break;
		default:
			break;
	}
	
	return url;
}

+(NSString*)nameForImageSizeType:(kPiwigoImageSize)imageSize
{
	NSString *sizeName = @"";
	
	switch(imageSize) {
		case kPiwigoImageSizeSquare:
			sizeName = NSLocalizedString(@"imageSizeSquare", @"Square");
			break;
		case kPiwigoImageSizeThumb:
			sizeName = NSLocalizedString(@"imageSizeThumbnail", @"Thumbnail");
			break;
		case kPiwigoImageSizexxSmall:
			sizeName = NSLocalizedString(@"imageSizexxSmall", @"Tiny");
			break;
		case kPiwigoImageSizexSmall:
			sizeName = NSLocalizedString(@"imageSizexSmall", @"Extra Small");
			break;
		case kPiwigoImageSizeSmall:
			sizeName = NSLocalizedString(@"imageSizeSmall", @"Small");
			break;
		case kPiwigoImageSizeMedium:
			sizeName = NSLocalizedString(@"imageSizeMedium", @"Medium (default)");
			break;
		case kPiwigoImageSizeLarge:
			sizeName = NSLocalizedString(@"imageSizeLarge", @"Large");
			break;
		case kPiwigoImageSizexLarge:
			sizeName = NSLocalizedString(@"imageSizexLarge", @"Extra Large");
			break;
		case kPiwigoImageSizexxLarge:
			sizeName = NSLocalizedString(@"imageSizexxLarge", @"Huge");
			break;
		case kPiwigoImageSizeFullRes:
			sizeName = NSLocalizedString(@"imageSizexFullRes", @"Full Resolution");
			break;
		default:
			break;
	}
	
	return sizeName;
}

@end
