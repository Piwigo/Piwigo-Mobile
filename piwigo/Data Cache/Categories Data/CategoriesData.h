//
//  CategoriesData.h
//  piwigo
//
//  Created by Spencer Baker on 1/29/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PiwigoAlbumData.h"

FOUNDATION_EXPORT NSString * const kPiwigoNotificationChangedCurrentCategory;

@interface CategoriesData : NSObject

+(CategoriesData*)sharedInstance;

@property (nonatomic, readonly) NSArray<PiwigoAlbumData*> *allCategories;
@property (nonatomic, readonly) NSArray<PiwigoAlbumData*> *communityCategoriesForUploadOnly;

-(void)clearCache;
-(void)addCategory:(NSInteger)categoryId withParameters:(NSDictionary *)parameters;
-(void)deleteCategoryWithId:(NSInteger)categoryId;
-(BOOL)replaceAllCategories:(NSArray*)categories;
-(void)updateCategories:(NSArray*)categories;
-(void)addCommunityCategoryWithUploadRights:(PiwigoAlbumData *)category;

-(PiwigoAlbumData*)getCategoryById:(NSInteger)categoryId;
-(NSArray<PiwigoAlbumData *>*)getCategoriesForParentCategory:(NSInteger)parentCategory;
-(NSDate *)getDateLastOfCategoriesInCategory:(NSInteger)parentCategory;

-(BOOL)categoryWithId:(NSInteger)category containsImagesWithId:(NSArray<NSNumber*>*)imageIds;
-(PiwigoImageData*)getImageForCategory:(NSInteger)category andIndex:(NSInteger)index;
-(PiwigoImageData*)getImageForCategory:(NSInteger)category andId:(NSInteger)imageId;

-(void)addImage:(PiwigoImageData*)image;
-(void)addImage:(PiwigoImageData *)image toCategory:(NSString *)category;
-(void)deleteImage:(PiwigoImageData*)image;
-(void)removeImage:(PiwigoImageData*)image fromCategory:(NSString *)category;

@end
