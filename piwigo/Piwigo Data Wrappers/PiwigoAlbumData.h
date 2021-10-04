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
@property (nonatomic, assign) NSInteger nearestUpperCategory;
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

-(PiwigoAlbumData *)initWithId:(NSInteger)categoryId andParameters:(NSDictionary *)parameters;
-(PiwigoAlbumData *)initSearchAlbumForQuery:(NSString *)query;
-(PiwigoAlbumData *)initDiscoverAlbumForCategory:(NSInteger)categoryId;

-(void)loadAllCategoryImageDataWithSort:(kPiwigoSortObjc)sort
                            forProgress:(void (^)(NSInteger onPage, NSInteger outOf))progress
                           OnCompletion:(void (^)(BOOL completed))completion;
-(void)loadCategoryImageDataChunkWithSort:(NSString*)sort
							  forProgress:(void (^)(NSInteger onPage, NSInteger outOf))progress
                             OnCompletion:(void (^)(BOOL completed))completion;

-(void)addImages:(NSArray<PiwigoImageData*> *)images;
-(void)addUploadedImage:(PiwigoImageData*)imageData;
-(void)updateImages:(NSArray<PiwigoImageData*> *)updatedImages;
-(void)updateImageAfterEdit:(PiwigoImageData *)uploadedImage;
-(void)removeImages:(NSArray<PiwigoImageData*> *)images;
-(NSInteger)getDepthOfCategory;
-(BOOL)containsUpperCategory:(NSInteger)category;
-(void)resetData;
-(void)incrementImageSizeByOne;
-(void)deincrementImageSizeByOne;

@end
