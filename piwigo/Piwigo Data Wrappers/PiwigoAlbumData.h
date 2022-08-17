//
//  PiwigoAlbumData.h
//  piwigo
//
//  Created by Spencer Baker on 1/24/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PiwigoImageData.h"

FOUNDATION_EXPORT NSInteger const kPiwigoSearchCategoryId;
FOUNDATION_EXPORT NSInteger const kPiwigoVisitsCategoryId;
FOUNDATION_EXPORT NSInteger const kPiwigoBestCategoryId;
FOUNDATION_EXPORT NSInteger const kPiwigoRecentCategoryId;
FOUNDATION_EXPORT NSInteger const kPiwigoTagsCategoryId;
FOUNDATION_EXPORT NSInteger const kPiwigoFavoritesCategoryId;

typedef enum {
	ImageListOrderId,
	ImageListOrderFileName,
	ImageListOrderName,
	ImageListOrderDate
} ImageListOrder;

@class ImageUpload;

@interface PiwigoAlbumData : NSObject

@property (nonatomic, assign) NSInteger albumId;
@property (nonatomic, strong) NSString *query;
@property (nonatomic, assign) NSInteger parentAlbumId;
@property (nonatomic, strong) NSArray<NSString*> *upperCategories;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *comment;
@property (nonatomic, assign) CGFloat globalRank;
@property (nonatomic, assign) NSInteger numberOfImages;
@property (nonatomic, assign) NSInteger totalNumberOfImages;
@property (nonatomic, assign) NSInteger numberOfSubCategories;
@property (nonatomic, assign) NSInteger albumThumbnailId;
@property (nonatomic, strong) NSString *albumThumbnailUrl;
@property (nonatomic, strong) NSDate *dateLast;
@property (nonatomic, strong) UIImage *categoryImage;
@property (nonatomic, assign) BOOL hasUploadRights;

@property (nonatomic, readonly) NSArray<PiwigoImageData *> *imageList;
@property (nonatomic, readonly) NSInteger onPage;
@property (nonatomic, assign) BOOL isLoadingMoreImages;

-(PiwigoAlbumData *)initWithId:(NSInteger)categoryId andQuery:(NSString *)query;

-(void)loadAllCategoryImageDataWithSort:(kPiwigoSortObjc)sort
                            forProgress:(void (^)(NSInteger onPage, NSInteger outOf))progress
                           onCompletion:(void (^)(BOOL completed))completion
                              onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail;
-(void)loadCategoryImageDataChunkWithSort:(NSString*)sort
							  forProgress:(void (^)(NSInteger onPage, NSInteger outOf))progress
                             onCompletion:(void (^)(BOOL completed))completion
                                onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail;

-(BOOL)hasAllImagesInCache;
-(NSInteger)addImages:(NSArray<PiwigoImageData*> *)images;
-(void)addUploadedImage:(PiwigoImageData*)imageData;
-(void)updateImages:(NSArray<PiwigoImageData*> *)updatedImages;
-(void)updateImageAfterEdit:(PiwigoImageData *)uploadedImage;
-(void)removeAllImages;
-(void)removeImages:(NSArray<PiwigoImageData*> *)images;
-(NSInteger)getDepthOfCategory;
-(void)resetData;
-(void)incrementImageSizeByOne;
-(void)deincrementImageSizeByOne;

@end
