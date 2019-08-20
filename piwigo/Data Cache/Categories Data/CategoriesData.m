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
NSString * const kPiwigoNotificationChangedCurrentCategory = @"kPiwigoNotificationChangedCurrentCategory";

@interface CategoriesData()

@property (nonatomic, strong) NSArray *allCategories;
@property (nonatomic, strong) NSArray *communityCategoriesForUploadOnly;

@end

@implementation CategoriesData

+(CategoriesData*)sharedInstance
{
	static CategoriesData *instance = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		instance = [[self alloc] init];
		
		instance.allCategories = [NSArray new];
        instance.communityCategoriesForUploadOnly = [NSArray new];
		
	});
	return instance;
}


# pragma mark - Update cache

-(void)clearCache
{
	self.allCategories = [NSArray new];
    self.communityCategoriesForUploadOnly = [NSArray new];
}

-(void)addCategory:(NSInteger)categoryId withParameters:(NSDictionary *)parameters
{
    // Create category in cache
    PiwigoAlbumData *newCategory = [[PiwigoAlbumData alloc] initWithId:categoryId andParameters:parameters];
    
    // Add new category to cache
    [[CategoriesData sharedInstance] updateCategories:@[newCategory]];
    
    // Get list of parent categories
    NSMutableArray *upperCategories = [newCategory.upperCategories mutableCopy];
    NSString *categoryIdStr = [NSString stringWithFormat:@"%ld", newCategory.albumId];
    if ([upperCategories containsObject:categoryIdStr]) {
        [upperCategories removeObject:categoryIdStr];
    }

    // Create new list of categories
    NSMutableArray *newCategories = [[NSMutableArray alloc] initWithArray:self.allCategories];

    // Look for parent categories and update them
    for (NSString *upperCategoryId in upperCategories)
    {
        // Look for the index of upper category to update
        NSInteger indexOfUpperCategory = [self indexOfCategoryWithId:[upperCategoryId integerValue] inArray:newCategories];
        
        // Update upper category
        if (indexOfUpperCategory != NSNotFound)
        {
            // Parent category
            PiwigoAlbumData *parentCategory = [newCategories objectAtIndex:indexOfUpperCategory];
            
            // Decrement number of sub-categories for that upper category
            parentCategory.numberOfSubCategories++;

            // Update parent category
            [newCategories replaceObjectAtIndex:indexOfUpperCategory withObject:parentCategory];
        }
    }
    
    // Update cache
    self.allCategories = newCategories;

    // Post to the app that category data have changed
    [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationCategoryDataUpdated object:nil];
}

-(void)deleteCategory:(NSInteger)categoryId
{
	// Look for index of category to delete
    NSInteger index = [self indexOfCategoryWithId:categoryId inArray:self.allCategories];
    
    if (index != NSNotFound)
    {
        // Get list of parent categories
        PiwigoAlbumData *catagoryToDelete = [self.allCategories objectAtIndex:index];
        NSMutableArray *upperCategories = [catagoryToDelete.upperCategories mutableCopy];
        NSString *categoryIdStr = [NSString stringWithFormat:@"%ld", catagoryToDelete.albumId];
        if ([upperCategories containsObject:categoryIdStr]) {
            [upperCategories removeObject:categoryIdStr];
        }

        // Create new list of categories
        NSMutableArray *newCategories = [[NSMutableArray alloc] initWithArray:self.allCategories];

        // Remove deleted category
        [newCategories removeObjectAtIndex:index];

        // Look for parent categories and update them
        for (NSString *upperCategoryId in upperCategories)
        {
            // Look for the index of upper category to update
            NSInteger indexOfUpperCategory = [self indexOfCategoryWithId:[upperCategoryId integerValue] inArray:newCategories];
            
            // Update upper category
            if (indexOfUpperCategory != NSNotFound)
            {
                // Parent category
                PiwigoAlbumData *parentCategory = [newCategories objectAtIndex:indexOfUpperCategory];
                
                // Subtract deleted images
                parentCategory.totalNumberOfImages -= catagoryToDelete.totalNumberOfImages;
                
                // Subtract deleted sub-categories
                parentCategory.numberOfSubCategories -= catagoryToDelete.numberOfSubCategories;
                
                // Subtract deleted category
                parentCategory.numberOfSubCategories--;
                
                // Update parent category
                [newCategories replaceObjectAtIndex:indexOfUpperCategory withObject:parentCategory];
            }
        }
        
        // Update cache
        self.allCategories = newCategories;

        // Post to the app that category data have changed
        [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationCategoryDataUpdated object:nil];
    }
}

-(void)replaceAllCategories:(NSArray*)categories
{
    // Create new list of categories
    NSMutableArray *newCategories = [[NSMutableArray alloc] init];

    // Loop on freshly retrieved categories
    for(PiwigoAlbumData *categoryData in categories)
    {
        // Is this a known category?
        NSInteger index = [self indexOfCategoryWithId:categoryData.albumId inArray:self.allCategories];
        
        // Reuse some data if possible
        if (index != NSNotFound)
        {
            // Retrieve existing data
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

-(void)updateCategories:(NSArray*)categories
{
    // Create new list of categories
    NSMutableArray *newCategories = [[NSMutableArray alloc] init];
    
    // First add freshly retrieved categories
    for(PiwigoAlbumData *categoryData in categories)
    {
        // Is this a known category?
        NSInteger index = [self indexOfCategoryWithId:categoryData.albumId inArray:self.allCategories];

        // Update exisiting data with new ones
        if (index != NSNotFound)
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
    
    // Second, keep other known categories
    for(PiwigoAlbumData *categoryData in self.allCategories)
    {
        // Look for updated categories
        NSInteger index = [self indexOfCategoryWithId:categoryData.albumId inArray:newCategories];
        
        // Add category which was not updated
        if (index == NSNotFound) {
            [newCategories addObject:categoryData];
        }
    }
    
    // Update list of displayed categories
    self.allCategories = newCategories;
    
    // Post to the app that the category data has been updated (if necessary)
    if (self.allCategories.count > 0)
        [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationCategoryDataUpdated object:nil];
}

-(void)addCommunityCategoryWithUploadRights:(PiwigoAlbumData *)category;
{
    NSMutableArray *existingCategories = [[NSMutableArray alloc] initWithArray:self.allCategories];
    NSMutableArray *existingComCategories = [[NSMutableArray alloc] initWithArray:self.communityCategoriesForUploadOnly];
    NSInteger index = -1;
    NSInteger curr = 0;
    for(PiwigoAlbumData *existingCategory in existingCategories)
    {
        if(existingCategory.albumId == category.albumId)
        {
            index = curr;
            break;
        }
        curr++;
    }
    
    if(index != -1)
    {
        PiwigoAlbumData *categoryData = [existingCategories objectAtIndex:index];
        categoryData.hasUploadRights = YES;
        [existingCategories setObject:categoryData atIndexedSubscript:index];
    } else {
        // This album was not returned by pwg.categories.getList
        category.hasUploadRights = YES;

        NSInteger indexCom = -1;
        NSInteger currCom = 0;
        for(PiwigoAlbumData *existingComCategory in existingComCategories)
        {
            if(existingComCategory.albumId == category.albumId)
            {
                indexCom = currCom;
                break;
            }
            currCom++;
        }

        if(indexCom != -1)
        {
            PiwigoAlbumData *categoryComData = [existingComCategories objectAtIndex:indexCom];
            categoryComData.hasUploadRights = YES;
            [existingComCategories setObject:categoryComData atIndexedSubscript:indexCom];
        } else {
            [existingComCategories addObject:category];
        }
    }
    
    self.allCategories = existingCategories;
    self.communityCategoriesForUploadOnly = existingComCategories;

    // Post to the app that the category data has been updated
    [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationCategoryDataUpdated object:nil];
}


# pragma mark - Get categories from cache

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


# pragma mark - Get and remove images from cache

-(PiwigoImageData*)getImageForCategory:(NSInteger)category andIndex:(NSInteger)index
{
	PiwigoAlbumData *selectedCategory = [self getCategoryById:category];
	if(selectedCategory && index < selectedCategory.imageList.count)
	{
		return [selectedCategory.imageList objectAtIndex:index];
	}
	return nil;
}

-(PiwigoImageData*)getImageForCategory:(NSInteger)category andId:(NSInteger)imageId
{
	PiwigoAlbumData *selectedCategory = [self getCategoryById:category];
		
	for(PiwigoImageData *img in selectedCategory.imageList)
	{
		if (imageId == img.imageId)
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
		[imageCategory removeImages:@[image]];
	}
}


#pragma mark - Utilities

-(NSInteger)indexOfCategoryWithId:(NSInteger)categoryId inArray:(NSArray *)categoryList
{
    NSInteger index = [categoryList indexOfObjectPassingTest:^BOOL(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        PiwigoAlbumData *category = (PiwigoAlbumData *)obj;
        if(category.albumId == categoryId)
            return YES;
        else
            return NO;
    }];
    
    return index;
}

@end
