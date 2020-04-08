//
//  CategoriesData.h
//  piwigo
//
//  Created by Spencer Baker on 1/29/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PiwigoAlbumData.h"

FOUNDATION_EXPORT NSString * const kPiwigoNotificationGetCategoryData;
FOUNDATION_EXPORT NSString * const kPiwigoNotificationCategoryDataUpdated;
FOUNDATION_EXPORT NSString * const kPiwigoNotificationChangedCurrentCategory;

@interface CategoriesData : NSObject

+(CategoriesData*)sharedInstance;

@property (nonatomic, readonly) NSArray<PiwigoAlbumData*> *allCategories;
@property (nonatomic, readonly) NSArray<PiwigoAlbumData*> *communityCategoriesForUploadOnly;

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
