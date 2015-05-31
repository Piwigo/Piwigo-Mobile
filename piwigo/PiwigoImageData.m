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

-(NSString *)stringFor:(NSString *)aString {
    NSString *objectIsNil = @"<nil>";
    return (nil == aString ? objectIsNil : (0 == [aString length] ? @"''" : aString));
 }
-(NSString *)description {
    
    NSMutableArray * descriptionArray = [[NSMutableArray alloc] init];
    [descriptionArray addObject:[NSString stringWithFormat:@"<%@: 0x%lx> = {", [self class], (unsigned long)self]];
    
    [descriptionArray addObject:[NSString stringWithFormat:@"name               = %@", [self stringFor:self.name]]];
    if ([self.imageId isKindOfClass:[NSNumber class]]){
    [descriptionArray addObject:[NSString stringWithFormat:@"imageId (number)   = %@", [self imageId]]];
        
    } else {
    [descriptionArray addObject:[NSString stringWithFormat:@"imageId (String)   = %@", [self stringFor:self.imageId]]];
    }
    [descriptionArray addObject:[NSString stringWithFormat:@"fileName           = %@", [self stringFor:self.fileName]]];
    [descriptionArray addObject:[NSString stringWithFormat:@"author             = %@", [self stringFor:self.author]]];
    [descriptionArray addObject:[NSString stringWithFormat:@"privacyLevel       = %@", kPiwigoPrivacyString(self.privacyLevel)]];
    [descriptionArray addObject:[NSString stringWithFormat:@"imageDescription   = %@", [self stringFor:self.imageDescription]]];
    
    [descriptionArray addObject:[NSString stringWithFormat:@"isVideo            = %@", (self.isVideo ? @"Yes":@"NO")]];

    [descriptionArray addObject:[NSString stringWithFormat:@"fullResPath        = %@", [self stringFor:self.fullResPath]]];

    [descriptionArray addObject:[NSString stringWithFormat:@"tags [%ld]         = %@", (long)self.tags.count, self.tags]];
    [descriptionArray addObject:[NSString stringWithFormat:@"categoryIds [%ld]  = %@", (long)self.categoryIds.count, self.categoryIds]];

    [descriptionArray addObject:[NSString stringWithFormat:@"squarePath         = %@", [self stringFor:self.squarePath]]];
    [descriptionArray addObject:[NSString stringWithFormat:@"thumbPath          = %@", [self stringFor:self.thumbPath]]];
    [descriptionArray addObject:[NSString stringWithFormat:@"mediumPath         = %@", [self stringFor:self.mediumPath]]];
    [descriptionArray addObject:[NSString stringWithFormat:@"xxSmall            = %@", [self stringFor:self.xxSmall]]];
    [descriptionArray addObject:[NSString stringWithFormat:@"xSmall             = %@", [self stringFor:self.xSmall]]];
    [descriptionArray addObject:[NSString stringWithFormat:@"small              = %@", [self stringFor:self.small]]];
    [descriptionArray addObject:[NSString stringWithFormat:@"large              = %@", [self stringFor:self.large]]];
    [descriptionArray addObject:[NSString stringWithFormat:@"xLarge             = %@", [self stringFor:self.xLarge]]];
    [descriptionArray addObject:[NSString stringWithFormat:@"xxLarge            = %@", [self stringFor:self.xxLarge]]];


    [descriptionArray addObject:@"}"];
    
    return [descriptionArray componentsJoinedByString:@"\n"];
}

@end
