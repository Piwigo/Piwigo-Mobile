//
//  PiwigoImageData.h
//  piwigo
//
//  Created by Spencer Baker on 1/15/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
	kPiwigoImageSizeSquare,
	kPiwigoImageSizeThumb,
	kPiwigoImageSizeXXSmall,
	kPiwigoImageSizeXSmall,
	kPiwigoImageSizeSmall,
	kPiwigoImageSizeMedium,
	kPiwigoImageSizeLarge,
	kPiwigoImageSizeXLarge,
	kPiwigoImageSizeXXLarge,
	kPiwigoImageSizeFullRes,
	kPiwigoImageSizeEnumCount
} kPiwigoImageSize;

@interface PiwigoImageData : NSObject

@property (nonatomic, strong) NSString *imageId;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *fileName;
@property (nonatomic, assign) NSInteger privacyLevel;
@property (nonatomic, strong) NSString *author;
@property (nonatomic, strong) NSString *imageDescription;
@property (nonatomic, strong) NSArray *tags;
@property (nonatomic, strong) NSArray *categoryIds;
@property (nonatomic, strong) NSDate *datePosted;
@property (nonatomic, strong) NSDate *dateCreated;
@property (nonatomic, assign) BOOL isVideo;
@property (nonatomic, strong) NSString *fullResPath;

// image sizes:
@property (nonatomic, strong) NSString *SquarePath;
@property (nonatomic, strong) NSString *ThumbPath;
@property (nonatomic, strong) NSString *XXSmallPath;
@property (nonatomic, strong) NSString *XSmallPath;
@property (nonatomic, strong) NSString *SmallPath;
@property (nonatomic, strong) NSString *MediumPath;
@property (nonatomic, strong) NSString *LargePath;
@property (nonatomic, strong) NSString *XLargePath;
@property (nonatomic, strong) NSString *XXLargePath;


-(NSString*)getURLFromImageSizeType:(kPiwigoImageSize)imageSize;
+(NSString*)nameForThumbnailSizeType:(kPiwigoImageSize)imageSize;
+(NSString*)nameForImageSizeType:(kPiwigoImageSize)imageSize withAdvice:(BOOL)advice;

@end
