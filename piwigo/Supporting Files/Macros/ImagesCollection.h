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

+(NSInteger)minNberOfImagesPerRow;
+(CGFloat)imageCellHorizontalSpacingForCollectionType:(kImageCollectionType)type;
+(CGFloat)imageCellVerticalSpacingForCollectionType:(kImageCollectionType)type;

+(NSInteger)imagesPerRowInPortraitForView:(UIView *)view maxWidth:(CGFloat)maxWidth;
+(NSInteger)imagesPerRowInPortraitForView:(UIView *)view maxWidth:(CGFloat)maxWidth collectionType:(kImageCollectionType)type;

+(CGFloat)imageSizeForView:(UIView *)view imagesPerRowInPortrait:(NSInteger)imagesPerRowInPortrait;
+(CGFloat)imageSizeForView:(UIView *)view imagesPerRowInPortrait:(NSInteger)imagesPerRowInPortrait collectionType:(kImageCollectionType)type;

+(NSInteger)numberOfImagesToDownloadPerPage;
+(NSInteger)numberOfImagesPerPageForView:(UIView *)view imagesPerRowInPortrait:(NSInteger)imagesPerRowInPortrait collectionType:(kImageCollectionType)type;

+(CGFloat)imageDetailsSizeForView:(UIView *)view;

+(NSInteger)numberOfAlbumsPerRowForViewInPortrait:(UIView *)view withMaxWidth:(CGFloat)maxWidth;
+(CGFloat)albumSizeForView:(UIView *)view andNberOfAlbumsPerRowInPortrait:(NSInteger)albumsPerRowInPortrait;

@end
