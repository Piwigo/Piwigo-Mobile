//
//  ImagesCollection.h
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 28/08/2017.
//  Copyright © 2017 Piwigo.org. All rights reserved.
//

typedef enum {
    kImageCollectionPopup,
    kImageCollectionFull,
} kImageCollectionType;

extern NSInteger const kAlbumCellSpacing;
extern NSInteger const kAlbumMarginsSpacing;

extern NSInteger const kImageCellSpacing4iPhone;
extern NSInteger const kImageCellHorSpacing4iPad;
extern NSInteger const kImageCellHorSpacing4iPadPopup;
extern NSInteger const kImageCellVertSpacing4iPad;
extern NSInteger const kImageCellVertSpacing4iPadPopup;
extern NSInteger const kImageMarginsSpacing;
extern NSInteger const kThumbnailFileSize;

extern NSInteger const kImageDetailsCellSpacing;
extern NSInteger const kImageDetailsMarginsSpacing;

@interface ImagesCollection : NSObject

+(float)minNberOfImagesPerRow;
+(NSInteger)imageCellHorizontalSpacingForCollectionType:(kImageCollectionType)type;
+(NSInteger)imageCellVerticalSpacingForCollectionType:(kImageCollectionType)type;

+(float)imagesPerRowInPortraitForView:(UIView *)view maxWidth:(float)maxWidth;
+(float)imagesPerRowInPortraitForView:(UIView *)view maxWidth:(float)maxWidth collectionType:(kImageCollectionType)type;

+(float)imageSizeForView:(UIView *)view imagesPerRowInPortrait:(NSInteger)imagesPerRowInPortrait;
+(float)imageSizeForView:(UIView *)view imagesPerRowInPortrait:(NSInteger)imagesPerRowInPortrait collectionType:(kImageCollectionType)type;

+(NSInteger)numberOfImagesPerPageForView:(UIView *)view imagesPerRowInPortrait:(NSInteger)imagesPerRowInPortrait;
+(NSInteger)numberOfImagesPerPageForView:(UIView *)view imagesPerRowInPortrait:(NSInteger)imagesPerRowInPortrait collectionType:(kImageCollectionType)type;

+(float)imageDetailsSizeForView:(UIView *)view;

+(float)numberOfAlbumsPerRowForViewInPortrait:(UIView *)view withMaxWidth:(float)maxWidth;
+(float)albumSizeForView:(UIView *)view andNberOfAlbumsPerRowInPortrait:(NSInteger)albumsPerRowInPortrait;

@end
