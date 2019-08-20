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

-(void)deleteCategory:(NSInteger)categoryId
{
	// Look for the category to delete
    NSInteger index = 0;
    NSInteger parentCategoryId = NSNotFound;
	for (PiwigoAlbumData *category in self.allCategories)
	{
		if(category.albumId == categoryId)
		{
            // Store parent category ID
            parentCategoryId = category.parentAlbumId;
            break;
		}
		index++;
	}
	
    // New list of categories
    NSMutableArray *newCategories = [[NSMutableArray alloc] initWithArray:self.allCategories];

    // Delete the category if found
    if ((index >= 0) && (index < newCategories.count))
    {
        // Remove deleted category
        [newCategories removeObjectAtIndex:index];

        // Look for the parent category
        index = 0;
        for (PiwigoAlbumData *category in newCategories)
        {
            if (category.albumId == parentCategoryId)
            {
                PiwigoAlbumData *parentCategory = category;
                
                // Decrement number of sub-categories
                parentCategory.numberOfSubCategories--;
                
                // Update parent category in cache
                [newCategories replaceObjectAtIndex:index withObject:parentCategory];
            }
            index++;
        }
    }

	self.allCategories = newCategories;
}

-(void)replaceAllCategories:(NSArray*)categories
{
    // Create new list of categories
    NSMutableArray *newCategories = [[NSMutableArray alloc] init];

    // Loop on freshly retrieved categories
    for(PiwigoAlbumData *categoryData in categories)
    {
        // Is this a known category?
        NSInteger index = [self.allCategories indexOfObjectPassingTest:^BOOL(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            PiwigoAlbumData *knownCategory = (PiwigoAlbumData *)obj;
            if(knownCategory.albumId == categoryData.albumId)
                return YES;
            else
                return NO;
        }];
        
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
        NSInteger index = [self.allCategories indexOfObjectPassingTest:^BOOL(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            PiwigoAlbumData *knownCategory = (PiwigoAlbumData *)obj;
            if(knownCategory.albumId == categoryData.albumId)
                return YES;
            else
                return NO;
        }];

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
        NSInteger index = [newCategories indexOfObjectPassingTest:^BOOL(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            PiwigoAlbumData *newCategory = (PiwigoAlbumData *)obj;
            if(newCategory.albumId == categoryData.albumId)
                return YES;
            else
                return NO;
        }];
        
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


@end
