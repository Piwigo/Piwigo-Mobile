//
//  CategoriesData.h
//  piwigo
//
//  Created by Spencer Baker on 1/29/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PiwigoAlbumData.h"

FOUNDATION_EXPORT NSString * const kPiwigoNotificationCategoryDataUpdated;
FOUNDATION_EXPORT NSString * const kPiwigoNotificationCategoryImageUpdated;

@interface CategoriesData : NSObject

+(CategoriesData*)sharedInstance;

@property (nonatomic, readonly) NSArray *allCategories;

-(void)addAllCategories:(NSArray*)categories;
-(void)setCategoryWithId:(NSInteger)categoryId hasUploadRight:(BOOL)canUpload;
-(PiwigoAlbumData*)getCategoryById:(NSInteger)categoryId;
-(PiwigoImageData*)getImageForCategory:(NSInteger)category andIndex:(NSInteger)index;
-(PiwigoImageData*)getImageForCategory:(NSInteger)category andId:(NSString*)imageId;
-(void)removeImage:(PiwigoImageData*)image;

-(NSArray*)getCategoriesForParentCategory:(NSInteger)parentCategory;

-(void)deleteCategory:(NSInteger)categoryId;
-(void)clearCache;

@end
