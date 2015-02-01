//
//  CategoriesData.m
//  piwigo
//
//  Created by Spencer Baker on 1/29/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "CategoriesData.h"

@interface CategoriesData()

@property (nonatomic, strong) NSDictionary *categories;
@property (nonatomic, strong) NSDictionary *sortedKeys;

@end

@implementation CategoriesData

+(CategoriesData*)sharedInstance
{
	static CategoriesData *instance = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		instance = [[self alloc] init];
		
		instance.categories = [NSDictionary new];
		instance.sortedKeys = [NSDictionary new];
		
	});
	return instance;
}

-(void)addCategories:(NSArray*)categories
{
	NSMutableDictionary *newCategories = [[NSMutableDictionary alloc] initWithDictionary:self.categories];
	NSMutableDictionary *newSortedKeys = [[NSMutableDictionary alloc] initWithDictionary:self.sortedKeys];
	for(PiwigoAlbumData *categoryData in categories)
	{
		[newCategories setObject:categoryData forKey:categoryData.albumId];
		[newSortedKeys setObject:categoryData.albumId forKey:[NSString stringWithFormat:@"%@", @(categoryData.globalRank)]];
	}
	self.categories = newCategories;
	self.sortedKeys = newSortedKeys;
}

-(PiwigoImageData*)getImageForCategory:(NSString*)category andIndex:(NSInteger)index
{
	if(index > [[[CategoriesData sharedInstance].categories objectForKey:category] imageList].count) return nil;
	return [[[[CategoriesData sharedInstance].categories objectForKey:category] imageList] objectAtIndex:index];
}

-(PiwigoImageData*)getImageForCategory:(NSString*)category andId:(NSString*)imageId
{
	PiwigoAlbumData *selectedCategory = [self.categories objectForKey:category];
	
	[imageId isKindOfClass:[NSString class]];
	
	for(PiwigoImageData *img in selectedCategory.imageList) {
		if([imageId integerValue] == [img.imageId integerValue])
		{
			return img;
		}
	}
	
	return nil;
}

-(void)removeImage:(PiwigoImageData*)image
{
	for(NSString *category in image.categoryIds) {
		PiwigoAlbumData *imageCategory = [self.categories objectForKey:category];
		[imageCategory removeImage:image];
	}
}

@end
