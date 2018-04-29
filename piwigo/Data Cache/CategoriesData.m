//
//  CategoriesData.m
//  piwigo
//
//  Created by Spencer Baker on 1/29/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "CategoriesData.h"

NSString * const kPiwigoNotificationGetCategoryData = @"kPiwigoNotificationGetCategoryData";
NSString * const kPiwigoNotificationCategoryDataUpdated = @"kPiwigoNotificationCategoryDataUpdated";
NSString * const kPiwigoNotificationCategoryImageUpdated = @"kPiwigoNotificationCategoryImageUpdated";

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
    // Create new list of categories
    NSMutableArray *newCategories = [[NSMutableArray alloc] init];

    // Loop on freshly retrieved categories
    for(PiwigoAlbumData *categoryData in categories)
    {
        // Is this a known category?
        NSInteger index = -1;
        NSInteger curr = 0;
        for(PiwigoAlbumData *knownCategory in self.allCategories)
        {
            if(knownCategory.albumId == categoryData.albumId)
            {
                index = curr;
                break;
            }
            curr++;
        }
        
        // Retrieve exisiting data if found
        if(index != -1)
        {
            // Retrieve exisiting data
            PiwigoAlbumData *existingData = [self.allCategories objectAtIndex:index];
            categoryData.hasUploadRights = existingData.hasUploadRights;
            
            // Reuse the image if the URL is identical
            if(existingData.albumThumbnailId == categoryData.albumThumbnailId)
            {
                categoryData.categoryImage = existingData.categoryImage;
            }
        }

        // Append category to new list
        [newCategories addObject:categoryData];
    }
    
    // Update list of displayed categories
	self.allCategories = newCategories;
	
    // Post to the app that the category data has been updated (if necessary)
    if (self.allCategories.count > 0)
        [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationCategoryDataUpdated object:nil];
}

-(void)setCategoryWithId:(NSInteger)categoryId hasUploadRight:(BOOL)canUpload
{
    NSMutableArray *existingCategories = [[NSMutableArray alloc] initWithArray:self.allCategories];
    NSInteger index = -1;
    for(PiwigoAlbumData *existingCategory in existingCategories)
    {
        index++;
        if(existingCategory.albumId == categoryId)
        {
            break;
        }
    }
    
    if(index != -1)
    {
        PiwigoAlbumData *categoryData = [existingCategories objectAtIndex:index];
        categoryData.hasUploadRights = canUpload;
        [existingCategories setObject:categoryData atIndexedSubscript:index];
    }
    
    self.allCategories = existingCategories;

    // Post to the app that the category data has been updated
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
	if(selectedCategory && index < selectedCategory.imageList.count)
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
		[imageCategory deincrementImageSizeByOne];
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
