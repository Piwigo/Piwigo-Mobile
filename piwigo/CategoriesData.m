//
//  CategoriesData.m
//  piwigo
//
//  Created by Spencer Baker on 1/29/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "CategoriesData.h"

@interface CategoriesData()

@property (nonatomic, strong) NSArray *categories;

@end

@implementation CategoriesData

+(CategoriesData*)sharedInstance
{
	static CategoriesData *instance = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		instance = [[self alloc] init];
		
		instance.categories = [NSArray new];
		
	});
	return instance;
}

-(void)addCategories:(NSArray*)categories
{
	NSMutableArray *newCategories = [[NSMutableArray alloc] initWithArray:self.categories];
	for(PiwigoAlbumData *categoryData in categories)
	{
		BOOL containsAlbum = NO;
		for(PiwigoAlbumData *existingCategory in self.categories)
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
	self.categories = newCategories;
}

-(PiwigoAlbumData*)getCategoryById:(NSInteger)categoryId
{
	for(PiwigoAlbumData *existingCategory in self.categories)
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
		[imageCategory removeImage:image];
	}
}

@end
