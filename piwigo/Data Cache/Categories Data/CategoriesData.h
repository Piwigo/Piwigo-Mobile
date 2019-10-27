//
//  CategoriesData.h
//  piwigo
//
//  Created by Spencer Baker on 1/29/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PiwigoAlbumData.h"

FOUNDATION_EXPORT NSString * const kPiwigoGetCategoryDataNotification;
FOUNDATION_EXPORT NSString * const kPiwigoCategoryDataUpdatedNotification;
FOUNDATION_EXPORT NSString * const kPiwigoChangedCurrentCategoryNotification;

@interface CategoriesData : NSObject

+(CategoriesData*)sharedInstance;

@property (nonatomic, readonly) NSArray *allCategories;
@property (nonatomic, readonly) NSArray *communityCategoriesForUploadOnly;

-(void)clearCache;
-(void)addCategory:(NSInteger)categoryId withParameters:(NSDictionary *)parameters;
-(void)deleteCategory:(NSInteger)categoryId;
-(void)replaceAllCategories:(NSArray*)categories;
-(void)updateCategories:(NSArray*)categories;
-(void)addCommunityCategoryWithUploadRights:(PiwigoAlbumData *)category;

-(PiwigoAlbumData*)getCategoryById:(NSInteger)categoryId;
-(NSArray*)getCategoriesForParentCategory:(NSInteger)parentCategory;

-(PiwigoImageData*)getImageForCategory:(NSInteger)category andIndex:(NSInteger)index;
-(PiwigoImageData*)getImageForCategory:(NSInteger)category andId:(NSInteger)imageId;
-(void)removeImage:(PiwigoImageData*)image;

@end
