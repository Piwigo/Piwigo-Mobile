//
//  PiwigoAlbumData.h
//  piwigo
//
//  Created by Spencer Baker on 1/24/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PiwigoImageData.h"

typedef enum {
	ImageListOrderId,
	ImageListOrderFileName,
	ImageListOrderName,
	ImageListOrderDate
} ImageListOrder;

@class ImageUpload;

@interface PiwigoAlbumData : NSObject

@property (nonatomic, assign) NSInteger albumId;
@property (nonatomic, assign) NSInteger parentAlbumId;
@property (nonatomic, strong) NSArray *upperCategories;
@property (nonatomic, assign) NSInteger nearestUpperCategory;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *comment;
@property (nonatomic, assign) CGFloat globalRank;
@property (nonatomic, assign) NSInteger numberOfImages;
@property (nonatomic, assign) NSInteger numberOfSubAlbumImages;
@property (nonatomic, assign) NSInteger numberOfSubCategories;
@property (nonatomic, assign) NSInteger albumThumbnailId;
@property (nonatomic, strong) NSString *albumThumbnailUrl;
@property (nonatomic, strong) NSDate *dateLast;
@property (nonatomic, strong) UIImage *categoryImage;
@property (nonatomic, assign) BOOL hasUploadRights;

@property (nonatomic, readonly) NSArray *imageList;
@property (nonatomic, readonly) NSInteger onPage;

-(void)addImages:(NSArray*)images;
-(void)removeImage:(PiwigoImageData*)image;

-(void)loadCategoryImageDataChunkWithSort:(NSString*)sort
							  forProgress:(void (^)(NSInteger onPage, NSInteger outOf))progress
								OnCompletion:(void (^)(BOOL completed))completion;
-(void)loadAllCategoryImageDataForProgress:(void (^)(NSInteger onPage, NSInteger outOf))progress
							  OnCompletion:(void (^)(BOOL completed))completion;
-(void)updateCacheWithImageUploadInfo:(ImageUpload*)imageUpload;
-(NSInteger)getDepthOfCategory;
-(BOOL)containsUpperCategory:(NSInteger)category;
-(void)resetData;
-(void)incrementImageSizeByOne;
-(void)deincrementImageSizeByOne;

@end
