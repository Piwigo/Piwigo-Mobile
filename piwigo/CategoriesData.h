//
//  CategoriesData.h
//  piwigo
//
//  Created by Spencer Baker on 1/29/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PiwigoAlbumData.h"

@interface CategoriesData : NSObject

+(CategoriesData*)sharedInstance;

@property (nonatomic, readonly) NSDictionary *categories;
@property (nonatomic, readonly) NSDictionary *sortedKeys;
-(void)addCategories:(NSArray*)categories;
-(PiwigoImageData*)getImageForCategory:(NSString*)category andIndex:(NSInteger)index;
-(PiwigoImageData*)getImageForCategory:(NSString*)category andId:(NSString*)imageId;
-(void)removeImage:(PiwigoImageData*)image;

@end
