//
//  CategoriesData.m
//  piwigo
//
//  Created by Spencer Baker on 1/29/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "CategoriesData.h"

NSString * const kPiwigoNotificationCategoryDataUpdated = @"kPiwigoNotificationCategoryDataUpdated";

@interface CategoriesData()

@property (nonatomic, strong) NSArray *allCategories;

@end

@implementation CategoriesData

+(CategoriesData*)sharedInstance
{
	static CategoriesData *instance = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		instance = [[self alloc] init];
		
		instance.allCategories = [NSArray new];
		
	});
	return instance;
}

-(void)clearCache
{
	self.allCategories = [NSArray new];
}

-(void)deleteCategory:(NSInteger)categoryId
{
	NSInteger index = 0;
	for(PiwigoAlbumData *category in self.allCategories)
	{
		if(category.albumId == categoryId)
		{
			break;
		}
		index++;
	}
	NSMutableArray *newCategories = [[NSMutableArray alloc] initWithArray:self.allCategories];
	[newCategories removeObjectAtIndex:index];
	self.allCategories = newCategories;
}

-(void)addAllCategories:(NSArray*)categories
{
	NSMutableArray *newCategories = [[NSMutableArray alloc] initWithArray:self.allCategories];
	for(PiwigoAlbumData *categoryData in categories)
	{
		BOOL containsAlbum = NO;
		for(PiwigoAlbumData *existingCategory in self.allCategories)
		{
			if(existingCategory.albumId == categoryData.albumId)
			{
				containsAlbum = YES;
				break;
			}
		}
		if(!containsAlbum)
		{
			[newCategories addObject:categoryData];
		}
	}
	
	self.allCategories = newCategories;
	
	
	// post to the app that the category data has been updated
	[[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationCategoryDataUpdated object:nil];
}

-(PiwigoAlbumData*)getCategoryById:(NSInteger)categoryId
{
	for(PiwigoAlbumData *existingCategory in self.allCategories)
	{
		if(existingCategory.albumId == categoryId)
		{
			return existingCategory;
			break;
		}
	}
	return nil;
}

-(PiwigoImageData*)getImageForCategory:(NSInteger)category andIndex:(NSInteger)index
{
	PiwigoAlbumData *selectedCategory = [self getCategoryById:category];
	if(selectedCategory)
	{
		return [selectedCategory.imageList objectAtIndex:index];
	}
	return nil;
}

-(PiwigoImageData*)getImageForCategory:(NSInteger)category andId:(NSString*)imageId
{
	PiwigoAlbumData *selectedCategory = [self getCategoryById:category];
	
	[imageId isKindOfClass:[NSString class]];
	
	for(PiwigoImageData *img in selectedCategory.imageList)
	{
		if([imageId integerValue] == [img.imageId integerValue])
		{
			return img;
		}
	}
	
	return nil;
}

-(void)removeImage:(PiwigoImageData*)image
{
	for(NSString *category in image.categoryIds)
	{
		PiwigoAlbumData *imageCategory = [self getCategoryById:[category integerValue]];
		imageCategory.numberOfImages--;
		[imageCategory removeImage:image];
	}
}

-(NSArray*)getCategoriesForParentCategory:(NSInteger)parentCategory
{
	NSMutableArray *categories = [NSMutableArray new];
	
	for(PiwigoAlbumData *category in self.allCategories)
	{
		if(category.parentAlbumId == parentCategory)
		{
			[categories addObject:category];
		}
	}
	
	return categories;
}

@end
