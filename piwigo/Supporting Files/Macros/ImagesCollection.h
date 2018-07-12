//
//  ImagesCollection.h
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 28/08/2017.
//  Copyright © 2017 Piwigo.org. All rights reserved.
//

extern NSInteger const kCellSpacing;
extern NSInteger const kMarginsSpacing;
extern NSInteger const kThumbnailFileSize;

@interface ImagesCollection : NSObject

+(float)numberOfImagesPerRowForViewInPortrait:(UIView *)view withMaxWidth:(NSInteger)maxWidth;
+(float)imageSizeForView:(UIView *)view andNberOfImagesPerRowInPortrait:(NSInteger)imagesPerRowInPortrait;
+(NSInteger)numberOfImagesPerPageForView:(UIView *)view andNberOfImagesPerRowInPortrait:(NSInteger)imagesPerRowInPortrait;

+(float)numberOfAlbumsPerRowForViewInPortrait:(UIView *)view withMaxWidth:(NSInteger)maxWidth;
+(float)albumSizeForView:(UIView *)view andNberOfAlbumsPerRowInPortrait:(NSInteger)albumsPerRowInPortrait;

@end
