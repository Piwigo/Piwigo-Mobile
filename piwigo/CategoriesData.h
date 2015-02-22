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

@interface CategoriesData : NSObject

+(CategoriesData*)sharedInstance;

@property (nonatomic, readonly) NSArray *categories;
-(void)addCategories:(NSArray*)categories;
-(PiwigoAlbumData*)getCategoryById:(NSInteger)categoryId;
-(PiwigoImageData*)getImageForCategory:(NSInteger)category andIndex:(NSInteger)index;
-(PiwigoImageData*)getImageForCategory:(NSInteger)category andId:(NSString*)imageId;
-(void)removeImage:(PiwigoImageData*)image;

-(void)clearCache;

@end
