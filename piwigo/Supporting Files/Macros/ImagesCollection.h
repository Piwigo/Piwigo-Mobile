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

extern CGFloat const kAlbumCellSpacing;
extern CGFloat const kAlbumMarginsSpacing;

extern CGFloat const kImageCellSpacing4iPhone;
extern CGFloat const kImageCellHorSpacing4iPad;
extern CGFloat const kImageCellHorSpacing4iPadPopup;
extern CGFloat const kImageCellVertSpacing4iPad;
extern CGFloat const kImageCellVertSpacing4iPadPopup;
extern CGFloat const kImageMarginsSpacing;
extern CGFloat const kThumbnailFileSize;

extern CGFloat const kImageDetailsCellSpacing;
extern CGFloat const kImageDetailsMarginsSpacing;

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

+(CGFloat)imageDetailsSizeForView:(UIView *)view;

+(float)numberOfAlbumsPerRowForViewInPortrait:(UIView *)view withMaxWidth:(float)maxWidth;
+(float)albumSizeForView:(UIView *)view andNberOfAlbumsPerRowInPortrait:(NSInteger)albumsPerRowInPortrait;

@end
