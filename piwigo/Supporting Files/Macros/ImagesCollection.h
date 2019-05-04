//
//  ImagesCollection.h
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 28/08/2017.
//  Copyright © 2017 Piwigo.org. All rights reserved.
//

extern NSInteger const kAlbumCellSpacing;
extern NSInteger const kAlbumMarginsSpacing;
extern NSInteger const kImageCellSpacing4iPhone;
extern NSInteger const kImageCellHorSpacing4iPad;
extern NSInteger const kImageCellVertSpacing4iPad;
extern NSInteger const kImageMarginsSpacing;
extern NSInteger const kThumbnailFileSize;

@interface ImagesCollection : NSObject

+(float)minNberOfImagesPerRow;
+(NSInteger)imageCellHorizontalSpacing;
+(float)numberOfImagesPerRowForViewInPortrait:(UIView *)view withMaxWidth:(NSInteger)maxWidth;
+(float)imageSizeForView:(UIView *)view andNberOfImagesPerRowInPortrait:(NSInteger)imagesPerRowInPortrait;
+(NSInteger)numberOfImagesPerPageForView:(UIView *)view andNberOfImagesPerRowInPortrait:(NSInteger)imagesPerRowInPortrait;

+(float)numberOfAlbumsPerRowForViewInPortrait:(UIView *)view withMaxWidth:(NSInteger)maxWidth;
+(float)albumSizeForView:(UIView *)view andNberOfAlbumsPerRowInPortrait:(NSInteger)albumsPerRowInPortrait;

@end
