//
//  PiwigoImageData.m
//  piwigo
//
//  Created by Spencer Baker on 1/15/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "PiwigoImageData.h"

@implementation PiwigoImageData

//-(NSString*)getURLFromImageSizeType:(kPiwigoImageSize)imageSize
//{
//	// ATTENTION: Some URLs may not be available!
//    // So we go through the list of URLs...
//    NSString *url = @"";
//
//	switch(imageSize) {
//		case kPiwigoImageSizeSquare:
//            if (AlbumVars.shared.hasSquareSizeImages && (self.SquarePath) && (self.SquarePath > 0)) {
//			    url = self.SquarePath;
//            } else if (AlbumVars.shared.hasThumbSizeImages && (self.ThumbPath) && (self.ThumbPath > 0)) {
//                url = self.ThumbPath;
//            } else if (AlbumVars.shared.hasXXSmallSizeImages && (self.XXSmallPath) && (self.XXSmallPath.length > 0)) {
//                url = self.XXSmallPath;
//            } else if (AlbumVars.shared.hasXSmallSizeImages && (self.XSmallPath) && (self.XSmallPath.length > 0)) {
//                url = self.XSmallPath;
//            } else if (AlbumVars.shared.hasSmallSizeImages && (self.SmallPath) && (self.SmallPath.length > 0)) {
//                url = self.SmallPath;
//            } else if (AlbumVars.shared.hasMediumSizeImages && (self.MediumPath) && (self.MediumPath.length > 0)) {
//                url = self.MediumPath;
//            } else if (AlbumVars.shared.hasLargeSizeImages && (self.LargePath) && (self.LargePath.length > 0)) {
//                url = self.LargePath;
//            } else if (AlbumVars.shared.hasXLargeSizeImages && (self.XLargePath) && (self.XLargePath.length > 0)) {
//                url = self.XLargePath;
//            } else if (AlbumVars.shared.hasXXLargeSizeImages && (self.XXLargePath) && (self.XXLargePath.length > 0)) {
//                url = self.XXLargePath;
//            } else if ((self.fullResPath) && (self.fullResPath.length > 0)) {
//                url = self.fullResPath;
//            }
//			break;
//		case kPiwigoImageSizeThumb:
//            if (AlbumVars.shared.hasSquareSizeImages && (self.SquarePath) && (self.SquarePath > 0)) {
//                url = self.SquarePath;
//            }
//            if (AlbumVars.shared.hasThumbSizeImages && (self.ThumbPath) && (self.ThumbPath > 0)) {
//                url = self.ThumbPath;
//            } else if (AlbumVars.shared.hasXXSmallSizeImages && (self.XXSmallPath) && (self.XXSmallPath.length > 0)) {
//                url = self.XXSmallPath;
//            } else if (AlbumVars.shared.hasXSmallSizeImages && (self.XSmallPath) && (self.XSmallPath.length > 0)) {
//                url = self.XSmallPath;
//            } else if (AlbumVars.shared.hasSmallSizeImages && (self.SmallPath) && (self.SmallPath.length > 0)) {
//                url = self.SmallPath;
//            } else if (AlbumVars.shared.hasMediumSizeImages && (self.MediumPath) && (self.MediumPath.length > 0)) {
//                url = self.MediumPath;
//            } else if (AlbumVars.shared.hasLargeSizeImages && (self.LargePath) && (self.LargePath.length > 0)) {
//                url = self.LargePath;
//            } else if (AlbumVars.shared.hasXLargeSizeImages && (self.XLargePath) && (self.XLargePath.length > 0)) {
//                url = self.XLargePath;
//            } else if (AlbumVars.shared.hasXXLargeSizeImages && (self.XXLargePath) && (self.XXLargePath.length > 0)) {
//                url = self.XXLargePath;
//            } else if ((self.fullResPath) && (self.fullResPath.length > 0)) {
//                url = self.fullResPath;
//            }
//			break;
//		case kPiwigoImageSizeXXSmall:
//            if (AlbumVars.shared.hasSquareSizeImages && (self.SquarePath) && (self.SquarePath > 0)) {
//                url = self.SquarePath;
//            }
//            if (AlbumVars.shared.hasThumbSizeImages && (self.ThumbPath) && (self.ThumbPath > 0)) {
//                url = self.ThumbPath;
//            }
//            if (AlbumVars.shared.hasXXSmallSizeImages && (self.XXSmallPath) && (self.XXSmallPath.length > 0)) {
//                url = self.XXSmallPath;
//            } else if (AlbumVars.shared.hasXSmallSizeImages && (self.XSmallPath) && (self.XSmallPath.length > 0)) {
//                url = self.XSmallPath;
//            } else if (AlbumVars.shared.hasSmallSizeImages && (self.SmallPath) && (self.SmallPath.length > 0)) {
//                url = self.SmallPath;
//            } else if (AlbumVars.shared.hasMediumSizeImages && (self.MediumPath) && (self.MediumPath.length > 0)) {
//                url = self.MediumPath;
//            } else if (AlbumVars.shared.hasLargeSizeImages && (self.LargePath) && (self.LargePath.length > 0)) {
//                url = self.LargePath;
//            } else if (AlbumVars.shared.hasXLargeSizeImages && (self.XLargePath) && (self.XLargePath.length > 0)) {
//                url = self.XLargePath;
//            } else if (AlbumVars.shared.hasXXLargeSizeImages && (self.XXLargePath) && (self.XXLargePath.length > 0)) {
//                url = self.XXLargePath;
//            } else if ((self.fullResPath) && (self.fullResPath.length > 0)) {
//                url = self.fullResPath;
//            }
//			break;
//		case kPiwigoImageSizeXSmall:
//            if (AlbumVars.shared.hasSquareSizeImages && (self.SquarePath) && (self.SquarePath > 0)) {
//                url = self.SquarePath;
//            }
//            if (AlbumVars.shared.hasThumbSizeImages && (self.ThumbPath) && (self.ThumbPath > 0)) {
//                url = self.ThumbPath;
//            }
//            if (AlbumVars.shared.hasXXSmallSizeImages && (self.XXSmallPath) && (self.XXSmallPath.length > 0)) {
//                url = self.XXSmallPath;
//            }
//            if (AlbumVars.shared.hasXSmallSizeImages && (self.XSmallPath) && (self.XSmallPath.length > 0)) {
//                url = self.XSmallPath;
//            } else if (AlbumVars.shared.hasSmallSizeImages && (self.SmallPath) && (self.SmallPath.length > 0)) {
//                url = self.SmallPath;
//            } else if (AlbumVars.shared.hasMediumSizeImages && (self.MediumPath) && (self.MediumPath.length > 0)) {
//                url = self.MediumPath;
//            } else if (AlbumVars.shared.hasLargeSizeImages && (self.LargePath) && (self.LargePath.length > 0)) {
//                url = self.LargePath;
//            } else if (AlbumVars.shared.hasXLargeSizeImages && (self.XLargePath) && (self.XLargePath.length > 0)) {
//                url = self.XLargePath;
//            } else if (AlbumVars.shared.hasXXLargeSizeImages && (self.XXLargePath) && (self.XXLargePath.length > 0)) {
//                url = self.XXLargePath;
//            } else if ((self.fullResPath) && (self.fullResPath.length > 0)) {
//                url = self.fullResPath;
//            }
//			break;
//		case kPiwigoImageSizeSmall:
//            if (AlbumVars.shared.hasSquareSizeImages && (self.SquarePath) && (self.SquarePath > 0)) {
//                url = self.SquarePath;
//            }
//            if (AlbumVars.shared.hasThumbSizeImages && (self.ThumbPath) && (self.ThumbPath > 0)) {
//                url = self.ThumbPath;
//            }
//            if (AlbumVars.shared.hasXXSmallSizeImages && (self.XXSmallPath) && (self.XXSmallPath.length > 0)) {
//                url = self.XXSmallPath;
//            }
//            if (AlbumVars.shared.hasXSmallSizeImages && (self.XSmallPath) && (self.XSmallPath.length > 0)) {
//                url = self.XSmallPath;
//            }
//            if (AlbumVars.shared.hasSmallSizeImages && (self.SmallPath) && (self.SmallPath.length > 0)) {
//                url = self.SmallPath;
//            } else if (AlbumVars.shared.hasMediumSizeImages && (self.MediumPath) && (self.MediumPath.length > 0)) {
//                url = self.MediumPath;
//            } else if (AlbumVars.shared.hasLargeSizeImages && (self.LargePath) && (self.LargePath.length > 0)) {
//                url = self.LargePath;
//            } else if (AlbumVars.shared.hasXLargeSizeImages && (self.XLargePath) && (self.XLargePath.length > 0)) {
//                url = self.XLargePath;
//            } else if (AlbumVars.shared.hasXXLargeSizeImages && (self.XXLargePath) && (self.XXLargePath.length > 0)) {
//                url = self.XXLargePath;
//            } else if ((self.fullResPath) && (self.fullResPath.length > 0)) {
//                url = self.fullResPath;
//            }
//			break;
//		case kPiwigoImageSizeMedium:
//            if (AlbumVars.shared.hasSquareSizeImages && (self.SquarePath) && (self.SquarePath > 0)) {
//                url = self.SquarePath;
//            }
//            if (AlbumVars.shared.hasThumbSizeImages && (self.ThumbPath) && (self.ThumbPath > 0)) {
//                url = self.ThumbPath;
//            }
//            if (AlbumVars.shared.hasXXSmallSizeImages && (self.XXSmallPath) && (self.XXSmallPath.length > 0)) {
//                url = self.XXSmallPath;
//            }
//            if (AlbumVars.shared.hasXSmallSizeImages && (self.XSmallPath) && (self.XSmallPath.length > 0)) {
//                url = self.XSmallPath;
//            }
//            if (AlbumVars.shared.hasSmallSizeImages && (self.SmallPath) && (self.SmallPath.length > 0)) {
//                url = self.SmallPath;
//            }
//            if (AlbumVars.shared.hasMediumSizeImages && (self.MediumPath) && (self.MediumPath.length > 0)) {
//                url = self.MediumPath;
//            } else if (AlbumVars.shared.hasLargeSizeImages && (self.LargePath) && (self.LargePath.length > 0)) {
//                url = self.LargePath;
//            } else if (AlbumVars.shared.hasXLargeSizeImages && (self.XLargePath) && (self.XLargePath.length > 0)) {
//                url = self.XLargePath;
//            } else if (AlbumVars.shared.hasXXLargeSizeImages && (self.XXLargePath) && (self.XXLargePath.length > 0)) {
//                url = self.XXLargePath;
//            } else if ((self.fullResPath) && (self.fullResPath.length > 0)) {
//                url = self.fullResPath;
//            }
//			break;
//		case kPiwigoImageSizeLarge:
//            if (AlbumVars.shared.hasSquareSizeImages && (self.SquarePath) && (self.SquarePath > 0)) {
//                url = self.SquarePath;
//            }
//            if (AlbumVars.shared.hasThumbSizeImages && (self.ThumbPath) && (self.ThumbPath > 0)) {
//                url = self.ThumbPath;
//            }
//            if (AlbumVars.shared.hasXXSmallSizeImages && (self.XXSmallPath) && (self.XXSmallPath.length > 0)) {
//                url = self.XXSmallPath;
//            }
//            if (AlbumVars.shared.hasXSmallSizeImages && (self.XSmallPath) && (self.XSmallPath.length > 0)) {
//                url = self.XSmallPath;
//            }
//            if (AlbumVars.shared.hasSmallSizeImages && (self.SmallPath) && (self.SmallPath.length > 0)) {
//                url = self.SmallPath;
//            }
//            if (AlbumVars.shared.hasMediumSizeImages && (self.MediumPath) && (self.MediumPath.length > 0)) {
//                url = self.MediumPath;
//            }
//            if (AlbumVars.shared.hasLargeSizeImages && (self.LargePath) && (self.LargePath.length > 0)) {
//                url = self.LargePath;
//            } else if (AlbumVars.shared.hasXLargeSizeImages && (self.XLargePath) && (self.XLargePath.length > 0)) {
//                url = self.XLargePath;
//            } else if (AlbumVars.shared.hasXXLargeSizeImages && (self.XXLargePath) && (self.XXLargePath.length > 0)) {
//                url = self.XXLargePath;
//            } else if ((self.fullResPath) && (self.fullResPath.length > 0)) {
//                url = self.fullResPath;
//            }
//			break;
//		case kPiwigoImageSizeXLarge:
//            if (AlbumVars.shared.hasSquareSizeImages && (self.SquarePath) && (self.SquarePath > 0)) {
//                url = self.SquarePath;
//            }
//            if (AlbumVars.shared.hasThumbSizeImages && (self.ThumbPath) && (self.ThumbPath > 0)) {
//                url = self.ThumbPath;
//            }
//            if (AlbumVars.shared.hasXXSmallSizeImages && (self.XXSmallPath) && (self.XXSmallPath.length > 0)) {
//                url = self.XXSmallPath;
//            }
//            if (AlbumVars.shared.hasXSmallSizeImages && (self.XSmallPath) && (self.XSmallPath.length > 0)) {
//                url = self.XSmallPath;
//            }
//            if (AlbumVars.shared.hasSmallSizeImages && (self.SmallPath) && (self.SmallPath.length > 0)) {
//                url = self.SmallPath;
//            }
//            if (AlbumVars.shared.hasMediumSizeImages && (self.MediumPath) && (self.MediumPath.length > 0)) {
//                url = self.MediumPath;
//            }
//            if (AlbumVars.shared.hasLargeSizeImages && (self.LargePath) && (self.LargePath.length > 0)) {
//                url = self.LargePath;
//            }
//            if (AlbumVars.shared.hasXLargeSizeImages && (self.XLargePath) && (self.XLargePath.length > 0)) {
//                url = self.XLargePath;
//            } else if (AlbumVars.shared.hasXXLargeSizeImages && (self.XXLargePath) && (self.XXLargePath.length > 0)) {
//                url = self.XXLargePath;
//            } else if ((self.fullResPath) && (self.fullResPath.length > 0)) {
//                url = self.fullResPath;
//            }
//			break;
//		case kPiwigoImageSizeXXLarge:
//            if (AlbumVars.shared.hasSquareSizeImages && (self.SquarePath) && (self.SquarePath > 0)) {
//                url = self.SquarePath;
//            }
//            if (AlbumVars.shared.hasThumbSizeImages && (self.ThumbPath) && (self.ThumbPath > 0)) {
//                url = self.ThumbPath;
//            }
//            if (AlbumVars.shared.hasXXSmallSizeImages && (self.XXSmallPath) && (self.XXSmallPath.length > 0)) {
//                url = self.XXSmallPath;
//            }
//            if (AlbumVars.shared.hasXSmallSizeImages && (self.XSmallPath) && (self.XSmallPath.length > 0)) {
//                url = self.XSmallPath;
//            }
//            if (AlbumVars.shared.hasSmallSizeImages && (self.SmallPath) && (self.SmallPath.length > 0)) {
//                url = self.SmallPath;
//            }
//            if (AlbumVars.shared.hasMediumSizeImages && (self.MediumPath) && (self.MediumPath.length > 0)) {
//                url = self.MediumPath;
//            }
//            if (AlbumVars.shared.hasLargeSizeImages && (self.LargePath) && (self.LargePath.length > 0)) {
//                url = self.LargePath;
//            }
//            if (AlbumVars.shared.hasXLargeSizeImages && (self.XLargePath) && (self.XLargePath.length > 0)) {
//                url = self.XLargePath;
//            }
//            if (AlbumVars.shared.hasXXLargeSizeImages && (self.XXLargePath) && (self.XXLargePath.length > 0)) {
//                url = self.XXLargePath;
//            } else if ((self.fullResPath) && (self.fullResPath.length > 0)) {
//                url = self.fullResPath;
//            }
//			break;
//		case kPiwigoImageSizeFullRes:
//            if (AlbumVars.shared.hasSquareSizeImages && (self.SquarePath) && (self.SquarePath > 0)) {
//                url = self.SquarePath;
//            }
//            if (AlbumVars.shared.hasThumbSizeImages && (self.ThumbPath) && (self.ThumbPath > 0)) {
//                url = self.ThumbPath;
//            }
//            if (AlbumVars.shared.hasXXSmallSizeImages && (self.XXSmallPath) && (self.XXSmallPath.length > 0)) {
//                url = self.XXSmallPath;
//            }
//            if (AlbumVars.shared.hasXSmallSizeImages && (self.XSmallPath) && (self.XSmallPath.length > 0)) {
//                url = self.XSmallPath;
//            }
//            if (AlbumVars.shared.hasSmallSizeImages && (self.SmallPath) && (self.SmallPath.length > 0)) {
//                url = self.SmallPath;
//            }
//            if (AlbumVars.shared.hasMediumSizeImages && (self.MediumPath) && (self.MediumPath.length > 0)) {
//                url = self.MediumPath;
//            }
//            if (AlbumVars.shared.hasLargeSizeImages && (self.LargePath) && (self.LargePath.length > 0)) {
//                url = self.LargePath;
//            }
//            if (AlbumVars.shared.hasXLargeSizeImages && (self.XLargePath) && (self.XLargePath.length > 0)) {
//                url = self.XLargePath;
//            }
//            if (AlbumVars.shared.hasXXLargeSizeImages && (self.XXLargePath) && (self.XXLargePath.length > 0)) {
//                url = self.XXLargePath;
//            }
//            if ((self.fullResPath) && (self.fullResPath.length > 0)) {
//                url = self.fullResPath;
//            }
//			break;
//		default:
//			break;
//	}
//
//	return url;
//}

//+(CGFloat)widthForImageSizeType:(kPiwigoImageSize)imageSize
//{
//    // Get device scale factor
//    CGFloat scale = [[UIScreen mainScreen] scale];
//    
//    // Default width
//    CGFloat width = 120;
//    
//    switch(imageSize) {
//        case kPiwigoImageSizeSquare:
//            width = 120;
//            break;
//        case kPiwigoImageSizeThumb:
//            width = 144;
//            break;
//        case kPiwigoImageSizeXXSmall:
//            width = 240;
//            break;
//        case kPiwigoImageSizeXSmall:
//            width = 324;
//            break;
//        case kPiwigoImageSizeSmall:
//            width = 432;
//            break;
//        case kPiwigoImageSizeMedium:
//            width = 594;
//            break;
//        case kPiwigoImageSizeLarge:
//            width = 756;
//            break;
//        case kPiwigoImageSizeXLarge:
//            width = 918;
//            break;
//        case kPiwigoImageSizeXXLarge:
//            width = 1242;
//            break;
//        case kPiwigoImageSizeFullRes:
//            width = 1242;
//            break;
//        default:
//            break;
//    }
//    
//    return width/scale;
//}

//+(NSString*)sizeForImageSizeType:(kPiwigoImageSize)imageSize
//{
//    // Get device scale factor
//    CGFloat scale = [[UIScreen mainScreen] scale];
//    
//    NSString *sizeName = @"";
//    
//    switch(imageSize) {
//        case kPiwigoImageSizeSquare:
//            sizeName = [NSString stringWithFormat:@" (%ldx%ld@%.0fx)", lroundf(120.0/scale), lroundf(120.0/scale), scale];
//            break;
//        case kPiwigoImageSizeThumb:
//            sizeName = [NSString stringWithFormat:@" (%ldx%ld@%.0fx)", lroundf(144.0/scale), lroundf(144.0/scale), scale];
//            break;
//        case kPiwigoImageSizeXXSmall:
//            sizeName = [NSString stringWithFormat:@" (%ldx%ld@%.0fx)", lroundf(240.0/scale), lroundf(240.0/scale), scale];
//            break;
//        case kPiwigoImageSizeXSmall:
//            sizeName = [NSString stringWithFormat:@" (%ldx%ld@%.0fx)", lroundf(432.0/scale), lroundf(324.0/scale), scale];
//            break;
//        case kPiwigoImageSizeSmall:
//            sizeName = [NSString stringWithFormat:@" (%ldx%ld@%.0fx)", lroundf(576.0/scale), lroundf(432.0/scale), scale];
//            break;
//        case kPiwigoImageSizeMedium:
//            sizeName = [NSString stringWithFormat:@" (%ldx%ld@%.0fx)", lroundf(792.0/scale), lroundf(594.0/scale), scale];
//            break;
//        case kPiwigoImageSizeLarge:
//            sizeName = [NSString stringWithFormat:@" (%ldx%ld@%.0fx)", lroundf(1008.0/scale), lroundf(756.0/scale), scale];
//            break;
//        case kPiwigoImageSizeXLarge:
//            sizeName = [NSString stringWithFormat:@" (%ldx%ld@%.0fx)", lroundf(1224.0/scale), lroundf(918.0/scale), scale];
//            break;
//        case kPiwigoImageSizeXXLarge:
//            sizeName = [NSString stringWithFormat:@" (%ldx%ld@%.0fx)", lroundf(1656.0/scale), lroundf(1242.0/scale), scale];
//            break;
//        case kPiwigoImageSizeFullRes:
//            sizeName = @"";
//            break;
//        default:
//            break;
//    }
//    
//    return sizeName;
//}


#pragma mark - Album thumbnails

//+(kPiwigoImageSize)optimumAlbumThumbnailSizeForDevice
//{
//    // Size of album thumbnails is 144x144 points (see AlbumTableViewCell.xib)
//    float albumThumbnailSize = 144.0;
//    
//    // Square ?
//    if ([self widthForImageSizeType:kPiwigoImageSizeSquare] >= albumThumbnailSize) {
//        return kPiwigoImageSizeSquare;
//    }
//    
//    // Thumbnail ?
//    if ([self widthForImageSizeType:kPiwigoImageSizeThumb] >= albumThumbnailSize) {
//        return kPiwigoImageSizeThumb;
//    }
//    
//    // XXSmall ?
//    if ([self widthForImageSizeType:kPiwigoImageSizeXXSmall] >= albumThumbnailSize) {
//        return kPiwigoImageSizeXXSmall;
//    }
//    
//    // XSmall ?
//    if ([self widthForImageSizeType:kPiwigoImageSizeXSmall] >= albumThumbnailSize) {
//        return kPiwigoImageSizeXSmall;
//    }
//    
//    // Small ?
//    if ([self widthForImageSizeType:kPiwigoImageSizeSmall] >= albumThumbnailSize) {
//        return kPiwigoImageSizeSmall;
//    }
//    
//    // Medium ?
//    if ([self widthForImageSizeType:kPiwigoImageSizeMedium] >= albumThumbnailSize) {
//        return kPiwigoImageSizeMedium;
//    }
//    
//    // Large ?
//    if ([self widthForImageSizeType:kPiwigoImageSizeLarge] >= albumThumbnailSize) {
//        return kPiwigoImageSizeLarge;
//    }
//    
//    // XLarge ?
//    if ([self widthForImageSizeType:kPiwigoImageSizeXLarge] >= albumThumbnailSize) {
//        return kPiwigoImageSizeXLarge;
//    }
//    
//    // XXLarge ?
//    if ([self widthForImageSizeType:kPiwigoImageSizeXXLarge] >= albumThumbnailSize) {
//        return kPiwigoImageSizeXXLarge;
//    }
//
//    return kPiwigoImageSizeMedium;
//}

//+(NSString*)nameForAlbumThumbnailSizeType:(kPiwigoImageSize)imageSize withInfo:(BOOL)addInfo
//{
//    NSString *sizeName = @"";
//
//    // Determine the optimum image size for the current device
//    NSInteger optimumSize = [self optimumAlbumThumbnailSizeForDevice];
//
//    // Return name for given thumbnail size
//    switch(imageSize) {
//        case kPiwigoImageSizeSquare:
//            sizeName = NSLocalizedString(@"thumbnailSizeSquare", @"Square");
//            if (addInfo) {
//                if (optimumSize == kPiwigoImageSizeSquare) {
//                    sizeName = [sizeName stringByAppendingString:NSLocalizedString(@"defaultImageSize_recommended", @" (recommended)")];
//                } else {
//                    sizeName = [sizeName stringByAppendingString:[PiwigoImageData sizeForImageSizeType:imageSize]];
//                }
//            }
//            break;
//        case kPiwigoImageSizeThumb:
//            sizeName = NSLocalizedString(@"thumbnailSizeThumbnail", @"Thumbnail");
//            if (addInfo) {
//                if (optimumSize == kPiwigoImageSizeThumb) {
//                    sizeName = [sizeName stringByAppendingString:NSLocalizedString(@"defaultImageSize_recommended", @" (recommended)")];
//                } else {
//                    sizeName = [sizeName stringByAppendingString:[PiwigoImageData sizeForImageSizeType:imageSize]];
//                }
//            }
//            break;
//        case kPiwigoImageSizeXXSmall:
//            sizeName = NSLocalizedString(@"thumbnailSizeXXSmall", @"Tiny");
//            if (addInfo) {
//                if (optimumSize == kPiwigoImageSizeXXSmall) {
//                    sizeName = [sizeName stringByAppendingString:NSLocalizedString(@"defaultImageSize_recommended", @" (recommended)")];
//                } else {
//                    sizeName = [sizeName stringByAppendingString:[PiwigoImageData sizeForImageSizeType:imageSize]];
//                }
//            }
//            break;
//        case kPiwigoImageSizeXSmall:
//            sizeName = NSLocalizedString(@"thumbnailSizeXSmall", @"Extra Small");
//            if (addInfo) {
//                if (optimumSize == kPiwigoImageSizeXSmall) {
//                    sizeName = [sizeName stringByAppendingString:NSLocalizedString(@"defaultImageSize_recommended", @" (recommended)")];
//                } else {
//                    sizeName = [sizeName stringByAppendingString:[PiwigoImageData sizeForImageSizeType:imageSize]];
//                }
//            }
//            break;
//        case kPiwigoImageSizeSmall:
//            sizeName = NSLocalizedString(@"thumbnailSizeSmall", @"Small");
//            if (addInfo) {
//                if (optimumSize == kPiwigoImageSizeSmall) {
//                    sizeName = [sizeName stringByAppendingString:NSLocalizedString(@"defaultImageSize_recommended", @" (recommended)")];
//                } else {
//                    sizeName = [sizeName stringByAppendingString:[PiwigoImageData sizeForImageSizeType:imageSize]];
//                }
//            }
//            break;
//        case kPiwigoImageSizeMedium:
//            sizeName = NSLocalizedString(@"thumbnailSizeMedium", @"Medium");
//            if (addInfo) {
//                if (optimumSize == kPiwigoImageSizeMedium) {
//                    sizeName = [sizeName stringByAppendingString:NSLocalizedString(@"defaultImageSize_recommended", @" (recommended)")];
//                } else {
//                    sizeName = [sizeName stringByAppendingString:[PiwigoImageData sizeForImageSizeType:imageSize]];
//                }
//            }
//            break;
//        case kPiwigoImageSizeLarge:
//            sizeName = NSLocalizedString(@"thumbnailSizeLarge", @"Large");
//            if (addInfo) {
//                sizeName = [sizeName stringByAppendingString:[PiwigoImageData sizeForImageSizeType:imageSize]];
//            }
//            break;
//        case kPiwigoImageSizeXLarge:
//            sizeName = NSLocalizedString(@"thumbnailSizeXLarge", @"Extra Large");
//            if (addInfo) {
//                sizeName = [sizeName stringByAppendingString:[PiwigoImageData sizeForImageSizeType:imageSize]];
//            }
//            break;
//        case kPiwigoImageSizeXXLarge:
//            sizeName = NSLocalizedString(@"thumbnailSizeXXLarge", @"Huge");
//            if (addInfo) {
//                sizeName = [sizeName stringByAppendingString:[PiwigoImageData sizeForImageSizeType:imageSize]];
//            }
//            break;
//        case kPiwigoImageSizeFullRes:
//            sizeName = NSLocalizedString(@"thumbnailSizexFullRes", @"Full Resolution");
//            break;
//        default:
//            break;
//    }
//
//    return sizeName;
//}


#pragma mark - Image thumbnails

//+(kPiwigoImageSize)optimumImageThumbnailSizeForDevice
//{
//    // Get optimum number of images per row
//    float nberThumbnailsPerRow = [AlbumUtilities minNberOfImagesPerRow];
//
//    // Square ?
//    NSInteger minNberOfImages = [AlbumUtilities imagesPerRowInPortraitForView:nil maxWidth:[self widthForImageSizeType:kPiwigoImageSizeSquare]];
//    if (minNberOfImages <= nberThumbnailsPerRow) {
//        return kPiwigoImageSizeSquare;
//    }
//
//    // Thumbnail ?
//    minNberOfImages = [AlbumUtilities imagesPerRowInPortraitForView:nil maxWidth:[self widthForImageSizeType:kPiwigoImageSizeThumb]];
//    if (minNberOfImages <= nberThumbnailsPerRow) {
//        return kPiwigoImageSizeThumb;
//    }
//
//    // XXSmall ?
//    minNberOfImages = [AlbumUtilities imagesPerRowInPortraitForView:nil maxWidth:[self widthForImageSizeType:kPiwigoImageSizeXXSmall]];
//    if (minNberOfImages <= nberThumbnailsPerRow) {
//        return kPiwigoImageSizeXXSmall;
//    }
//
//    // XSmall ?
//    minNberOfImages = [AlbumUtilities imagesPerRowInPortraitForView:nil maxWidth:[self widthForImageSizeType:kPiwigoImageSizeXSmall]];
//    if (minNberOfImages <= nberThumbnailsPerRow) {
//        return kPiwigoImageSizeXSmall;
//    }
//
//    // Small ?
//    minNberOfImages = [AlbumUtilities imagesPerRowInPortraitForView:nil maxWidth:[self widthForImageSizeType:kPiwigoImageSizeSmall]];
//    if (minNberOfImages <= nberThumbnailsPerRow) {
//        return kPiwigoImageSizeSmall;
//    }
//
//    // Medium ?
//    minNberOfImages = [AlbumUtilities imagesPerRowInPortraitForView:nil maxWidth:[self widthForImageSizeType:kPiwigoImageSizeMedium]];
//    if (minNberOfImages <= nberThumbnailsPerRow) {
//        return kPiwigoImageSizeMedium;
//    }
//
//    // Large ?
//    minNberOfImages = [AlbumUtilities imagesPerRowInPortraitForView:nil maxWidth:[self widthForImageSizeType:kPiwigoImageSizeLarge]];
//    if (minNberOfImages <= nberThumbnailsPerRow) {
//        return kPiwigoImageSizeLarge;
//    }
//
//    // XLarge ?
//    minNberOfImages = [AlbumUtilities imagesPerRowInPortraitForView:nil maxWidth:[self widthForImageSizeType:kPiwigoImageSizeXLarge]];
//    if (minNberOfImages <= nberThumbnailsPerRow) {
//        return kPiwigoImageSizeXLarge;
//    }
//
//    // XXLarge ?
//    minNberOfImages = [AlbumUtilities imagesPerRowInPortraitForView:nil maxWidth:[self widthForImageSizeType:kPiwigoImageSizeXXLarge]];
//    if (minNberOfImages <= nberThumbnailsPerRow) {
//        return kPiwigoImageSizeXXLarge;
//    }
//
//    return kPiwigoImageSizeThumb;
//}

//+(NSString*)nameForImageThumbnailSizeType:(kPiwigoImageSize)imageSize withInfo:(BOOL)addInfo
//{
//    NSString *sizeName = @"";
//
//    // Determine the optimum image size for the current device
//    NSInteger optimumSize = [self optimumImageThumbnailSizeForDevice];
//
//    // Return name for given thumbnail size
//    switch(imageSize) {
//        case kPiwigoImageSizeSquare:
//            sizeName = NSLocalizedString(@"thumbnailSizeSquare", @"Square");
//            if (addInfo) {
//                if (optimumSize == kPiwigoImageSizeSquare) {
//                    sizeName = [sizeName stringByAppendingString:NSLocalizedString(@"defaultImageSize_recommended", @" (recommended)")];
//                } else {
//                    sizeName = [sizeName stringByAppendingString:[PiwigoImageData sizeForImageSizeType:imageSize]];
//                }
//            }
//            break;
//        case kPiwigoImageSizeThumb:
//            sizeName = NSLocalizedString(@"thumbnailSizeThumbnail", @"Thumbnail");
//            if (addInfo) {
//                if (optimumSize == kPiwigoImageSizeThumb) {
//                    sizeName = [sizeName stringByAppendingString:NSLocalizedString(@"defaultImageSize_recommended", @" (recommended)")];
//                } else {
//                    sizeName = [sizeName stringByAppendingString:[PiwigoImageData sizeForImageSizeType:imageSize]];
//                }
//            }
//            break;
//        case kPiwigoImageSizeXXSmall:
//            sizeName = NSLocalizedString(@"thumbnailSizeXXSmall", @"Tiny");
//            if (addInfo) {
//                if (optimumSize == kPiwigoImageSizeXXSmall) {
//                    sizeName = [sizeName stringByAppendingString:NSLocalizedString(@"defaultImageSize_recommended", @" (recommended)")];
//                } else {
//                    sizeName = [sizeName stringByAppendingString:[PiwigoImageData sizeForImageSizeType:imageSize]];
//                }
//            }
//            break;
//        case kPiwigoImageSizeXSmall:
//            sizeName = NSLocalizedString(@"thumbnailSizeXSmall", @"Extra Small");
//            if (addInfo) {
//                if (optimumSize == kPiwigoImageSizeXSmall) {
//                    sizeName = [sizeName stringByAppendingString:NSLocalizedString(@"defaultImageSize_recommended", @" (recommended)")];
//                } else {
//                    sizeName = [sizeName stringByAppendingString:[PiwigoImageData sizeForImageSizeType:imageSize]];
//                }
//            }
//            break;
//        case kPiwigoImageSizeSmall:
//            sizeName = NSLocalizedString(@"thumbnailSizeSmall", @"Small");
//            if (addInfo) {
//                if (optimumSize == kPiwigoImageSizeSmall) {
//                    sizeName = [sizeName stringByAppendingString:NSLocalizedString(@"defaultImageSize_recommended", @" (recommended)")];
//                } else {
//                    sizeName = [sizeName stringByAppendingString:[PiwigoImageData sizeForImageSizeType:imageSize]];
//                }
//            }
//            break;
//        case kPiwigoImageSizeMedium:
//            sizeName = NSLocalizedString(@"thumbnailSizeMedium", @"Medium");
//            if (addInfo) {
//                if (optimumSize == kPiwigoImageSizeMedium) {
//                    sizeName = [sizeName stringByAppendingString:NSLocalizedString(@"defaultImageSize_recommended", @" (recommended)")];
//                } else {
//                    sizeName = [sizeName stringByAppendingString:[PiwigoImageData sizeForImageSizeType:imageSize]];
//                }
//            }
//            break;
//        case kPiwigoImageSizeLarge:
//            sizeName = NSLocalizedString(@"thumbnailSizeLarge", @"Large");
//            if (addInfo) {
//                sizeName = [sizeName stringByAppendingString:[PiwigoImageData sizeForImageSizeType:imageSize]];
//            }
//            break;
//        case kPiwigoImageSizeXLarge:
//            sizeName = NSLocalizedString(@"thumbnailSizeXLarge", @"Extra Large");
//            if (addInfo) {
//                sizeName = [sizeName stringByAppendingString:[PiwigoImageData sizeForImageSizeType:imageSize]];
//            }
//            break;
//        case kPiwigoImageSizeXXLarge:
//            sizeName = NSLocalizedString(@"thumbnailSizeXXLarge", @"Huge");
//            if (addInfo) {
//                sizeName = [sizeName stringByAppendingString:[PiwigoImageData sizeForImageSizeType:imageSize]];
//            }
//            break;
//        case kPiwigoImageSizeFullRes:
//            sizeName = NSLocalizedString(@"thumbnailSizexFullRes", @"Full Resolution");
//            break;
//        default:
//            break;
//    }
//
//    return sizeName;
//}


#pragma mark - Images

//+(kPiwigoImageSize)optimumImageSizeForDevice
//{
//    // Determine the resolution of the screen
//    // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
//    // See https://www.apple.com/iphone/compare/ and https://www.apple.com/ipad/compare/
//    CGRect screen = [[UIScreen mainScreen] bounds];
//    float screenWidth = fmin(screen.size.width, screen.size.height);
//
//    // Square ?
//    if ([self widthForImageSizeType:kPiwigoImageSizeSquare] >= screenWidth) {
//        return kPiwigoImageSizeSquare;
//    }
//
//    // Thumbnail ?
//    if ([self widthForImageSizeType:kPiwigoImageSizeThumb] >= screenWidth) {
//        return kPiwigoImageSizeThumb;
//    }
//
//    // XXSmall ?
//    if ([self widthForImageSizeType:kPiwigoImageSizeXXSmall] >= screenWidth) {
//        return kPiwigoImageSizeXXSmall;
//    }
//
//    // XSmall ?
//    if ([self widthForImageSizeType:kPiwigoImageSizeXSmall] >= screenWidth) {
//        return kPiwigoImageSizeXSmall;
//    }
//
//    // Small ?
//    if ([self widthForImageSizeType:kPiwigoImageSizeSmall] >= screenWidth) {
//        return kPiwigoImageSizeSmall;
//    }
//
//    // Medium ?
//    if ([self widthForImageSizeType:kPiwigoImageSizeMedium] >= screenWidth) {
//        return kPiwigoImageSizeMedium;
//    }
//
//    // Large ?
//    if ([self widthForImageSizeType:kPiwigoImageSizeLarge] >= screenWidth) {
//        return kPiwigoImageSizeLarge;
//    }
//
//    // XLarge ?
//    if ([self widthForImageSizeType:kPiwigoImageSizeXLarge] >= screenWidth) {
//        return kPiwigoImageSizeXLarge;
//    }
//
//    // XXLarge ?
//    if ([self widthForImageSizeType:kPiwigoImageSizeXXLarge] >= screenWidth) {
//        return kPiwigoImageSizeXXLarge;
//    }
//
//    return kPiwigoImageSizeFullRes;
//}

//+(NSString*)nameForImageSizeType:(kPiwigoImageSize)imageSize withInfo:(BOOL)addInfo
//{
//	NSString *sizeName = @"";
//
//    // Determine the optimum image size for the current device
//    NSInteger optimumSize = [self optimumImageSizeForDevice];
//
//    // Return name for given image size
//	switch(imageSize) {
//		case kPiwigoImageSizeSquare:
//			sizeName = NSLocalizedString(@"imageSizeSquare", @"Square");
//            if (addInfo) {
//                sizeName = [sizeName stringByAppendingString:[PiwigoImageData sizeForImageSizeType:imageSize]];
//            }
//			break;
//		case kPiwigoImageSizeThumb:
//			sizeName = NSLocalizedString(@"imageSizeThumbnail", @"Thumbnail");
//            if (addInfo) {
//                sizeName = [sizeName stringByAppendingString:[PiwigoImageData sizeForImageSizeType:imageSize]];
//            }
//			break;
//		case kPiwigoImageSizeXXSmall:
//			sizeName = NSLocalizedString(@"imageSizeXXSmall", @"Tiny");
//            if (addInfo) {
//                sizeName = [sizeName stringByAppendingString:[PiwigoImageData sizeForImageSizeType:imageSize]];
//            }
//			break;
//		case kPiwigoImageSizeXSmall:
//			sizeName = NSLocalizedString(@"imageSizeXSmall", @"Extra Small");
//            if (addInfo) {
//                if (optimumSize == kPiwigoImageSizeXSmall) {
//                    sizeName = [sizeName stringByAppendingString:NSLocalizedString(@"defaultImageSize_recommended", @" (recommended)")];
//                } else {
//                    sizeName = [sizeName stringByAppendingString:[PiwigoImageData sizeForImageSizeType:imageSize]];
//                }
//            }
//			break;
//		case kPiwigoImageSizeSmall:
//			sizeName = NSLocalizedString(@"imageSizeSmall", @"Small");
//            if (addInfo) {
//                if (optimumSize == kPiwigoImageSizeSmall) {
//                    sizeName = [sizeName stringByAppendingString:NSLocalizedString(@"defaultImageSize_recommended", @" (recommended)")];
//                } else {
//                    sizeName = [sizeName stringByAppendingString:[PiwigoImageData sizeForImageSizeType:imageSize]];
//                }
//            }
//			break;
//		case kPiwigoImageSizeMedium:
//			sizeName = NSLocalizedString(@"imageSizeMedium", @"Medium");
//            if (addInfo) {
//                if (optimumSize == kPiwigoImageSizeMedium) {
//                    sizeName = [sizeName stringByAppendingString:NSLocalizedString(@"defaultImageSize_recommended", @" (recommended)")];
//                } else {
//                    sizeName = [sizeName stringByAppendingString:[PiwigoImageData sizeForImageSizeType:imageSize]];
//                }
//            }
//			break;
//		case kPiwigoImageSizeLarge:
//			sizeName = NSLocalizedString(@"imageSizeLarge", @"Large");
//            if (addInfo) {
//                if (optimumSize == kPiwigoImageSizeLarge) {
//                    sizeName = [sizeName stringByAppendingString:NSLocalizedString(@"defaultImageSize_recommended", @" (recommended)")];
//                } else {
//                    sizeName = [sizeName stringByAppendingString:[PiwigoImageData sizeForImageSizeType:imageSize]];
//                }
//            }
//			break;
//		case kPiwigoImageSizeXLarge:
//			sizeName = NSLocalizedString(@"imageSizeXLarge", @"Extra Large");
//            if (addInfo) {
//                if (optimumSize == kPiwigoImageSizeXLarge) {
//                    sizeName = [sizeName stringByAppendingString:NSLocalizedString(@"defaultImageSize_recommended", @" (recommended)")];
//                } else {
//                    sizeName = [sizeName stringByAppendingString:[PiwigoImageData sizeForImageSizeType:imageSize]];
//                }
//            }
//			break;
//		case kPiwigoImageSizeXXLarge:
//			sizeName = NSLocalizedString(@"imageSizeXXLarge", @"Huge");
//            if (addInfo) {
//                if (optimumSize == kPiwigoImageSizeXXLarge) {
//                    sizeName = [sizeName stringByAppendingString:NSLocalizedString(@"defaultImageSize_recommended", @" (recommended)")];
//                } else {
//                    sizeName = [sizeName stringByAppendingString:[PiwigoImageData sizeForImageSizeType:imageSize]];
//                }
//            }
//			break;
//		case kPiwigoImageSizeFullRes:
//			sizeName = NSLocalizedString(@"imageSizexFullRes", @"Full Resolution");
//            if (addInfo && (optimumSize == kPiwigoImageSizeFullRes)) {
//                sizeName = [sizeName stringByAppendingString:NSLocalizedString(@"defaultImageSize_recommended", @" (recommended)")];
//            }
//			break;
//		default:
//			break;
//	}
//
//	return sizeName;
//}

@end
