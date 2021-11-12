//
//  CategoriesData.m
//  piwigo
//
//  Created by Spencer Baker on 1/29/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "AlbumData.h"
#import "CategoriesData.h"

NSString * const kPiwigoNotificationGetCategoryData = @"kPiwigoNotificationGetCategoryData";
NSString * const kPiwigoNotificationCategoryDataUpdated = @"kPiwigoNotificationCategoryDataUpdated";
NSString * const kPiwigoNotificationChangedCurrentCategory = @"kPiwigoNotificationChangedCurrentCategory";

@interface CategoriesData()

@property (nonatomic, strong) NSArray<PiwigoAlbumData *> *allCategories;
@property (nonatomic, strong) NSArray<PiwigoAlbumData *> *communityCategoriesForUploadOnly;

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


# pragma mark - Clear cache

-(void)clearCache
{
	self.allCategories = [NSArray new];
    self.communityCategoriesForUploadOnly = [NSArray new];
}


# pragma mark - Add category

-(void)addCategory:(NSInteger)categoryId withParameters:(NSDictionary *)parameters
{
    // Create category in cache
    PiwigoAlbumData *newCategory = [[PiwigoAlbumData alloc] initWithId:categoryId andParameters:parameters];
    
    // Add new category to cache
    [[CategoriesData sharedInstance] updateCategories:@[newCategory] andUpdateUI:NO];
    
    // Get list of parent categories
    NSMutableArray *upperCategories = [newCategory.upperCategories mutableCopy];
    NSString *categoryIdStr = [NSString stringWithFormat:@"%ld", (long)newCategory.albumId];
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


# pragma mark - Delete category

-(void)deleteCategoryWithId:(NSInteger)categoryId
{
    // Look for index of category to delete
    NSInteger index = [self indexOfCategoryWithId:categoryId inArray:self.allCategories];
    if (index == NSNotFound) { return; }
    
    // Get category to delete
    PiwigoAlbumData *catagoryToDelete = [self.allCategories objectAtIndex:index];

    // Get list of parent categories
    NSMutableArray *upperCategories = [catagoryToDelete.upperCategories mutableCopy];
    NSString *categoryIdStr = [NSString stringWithFormat:@"%ld", (long)catagoryToDelete.albumId];
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


# pragma mark - Update cache

-(void)replaceAllCategories:(NSArray<PiwigoAlbumData *>*)categories
{
    // Create new list of categories
    NSMutableArray *newCategories = [[NSMutableArray alloc] init];

    // Did we load favorites at start or did user request a refresh?
    if (!NetworkVarsObjc.hasGuestRights &&
        ([@"2.10.0" compare:NetworkVarsObjc.pwgVersion options:NSNumericSearch] != NSOrderedDescending))
    {
        // Keep cached favorites
        NSInteger indexOfFavorites = [self indexOfCategoryWithId:kPiwigoFavoritesCategoryId
                                                         inArray:self.allCategories];
        if (indexOfFavorites != NSNotFound) {
            [newCategories addObject:[self.allCategories objectAtIndex:indexOfFavorites]];
        }
    }

    // Loop on freshly retrieved categories
    for(PiwigoAlbumData *categoryData in categories)
    {
        // Is this a known category?
        NSInteger index = [self indexOfCategoryWithId:categoryData.albumId
                                              inArray:self.allCategories];
        
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

-(void)updateCategories:(NSArray<PiwigoAlbumData *>*)categories andUpdateUI:(BOOL)updateUI
{
    // Known categories are updated if needed
    NSMutableArray *updatedCategories = [NSMutableArray new];

    // New categories will be added to the top of the list
    NSMutableArray *newCategories = [categories mutableCopy];

    // Loop over all known categories
    for (PiwigoAlbumData *category in self.allCategories)
    {
        // Is this a category to update?
        NSInteger index = [self indexOfCategoryWithId:category.albumId inArray:newCategories];
        if (index != NSNotFound)
        {
            // Retrieve updated data
            PiwigoAlbumData *updatedCategory = [newCategories objectAtIndex:index];
            
            // Keep upload rights
            updatedCategory.hasUploadRights = category.hasUploadRights;
            
            // Reuse the image if the URL is identical
            if (updatedCategory.albumThumbnailId == category.albumThumbnailId)
            {
                updatedCategory.categoryImage = category.categoryImage;
            }
            
            // Append updated category to new list
            [updatedCategories addObject:updatedCategory];
            
            // Remove updated category from top list
            [newCategories removeObjectAtIndex:index];
        }
        else
        {
            [updatedCategories addObject:category];
        }
    }

    // Append new categories
    [newCategories addObjectsFromArray:updatedCategories];
    
    // Update list of displayed categories
    self.allCategories = newCategories;
    
    // Post to the app that the category data has been updated (if necessary)
    if (updateUI && (self.allCategories.count > 0)) {
        dispatch_async(dispatch_get_main_queue(), ^(void){
            [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationCategoryDataUpdated object:nil];
        });
    }
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

-(NSArray<PiwigoAlbumData *>*)getCategoriesForParentCategory:(NSInteger)parentCategory
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

-(BOOL)categoryWithId:(NSInteger)category containsImagesWithId:(NSArray<NSNumber*>*)imageIds
{
    // Empty list of image IDs?
    if (imageIds.count == 0) { return NO; }
    
    // Retrieve the album data
    PiwigoAlbumData *selectedCategory = [self getCategoryById:category];
    if (selectedCategory == nil) { return NO; }
    if (selectedCategory.imageList.count == 0) { return NO;}
    
    // Loop over the provided list of IDs
    for (NSNumber *imageId in imageIds) {
        NSInteger index = [selectedCategory.imageList indexOfObjectPassingTest:^BOOL(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            PiwigoImageData *image = (PiwigoImageData *)obj;
            if (image.imageId == imageId.integerValue)
                return YES;
            else
                return NO;
        }];
        
        // At least an image could not be found.
        if (index == NSNotFound) { return NO; }
    }
    return YES;
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

-(void)addImage:(PiwigoImageData*)image
{
    // Categories to which the image will belong to
    for(NSString *category in image.categoryIds)
    {
        [self addImage:image toCategory:category];
    }

    // Smart albums
    if ([self getCategoryById:kPiwigoRecentCategoryId] != nil) {
        [self addImage:image toCategory:[NSString stringWithFormat:@"%ld", (long)kPiwigoRecentCategoryId]];
    }
}

-(void)addImage:(PiwigoImageData *)image toCategory:(NSString *)category
{
    // Check if the image already belongs to the category
    PiwigoImageData *imageInCategory = [self getImageForCategory:category.integerValue andId:image.imageId];
    if (imageInCategory != nil) { return; }
    
    // Add image to category
    PiwigoAlbumData *imageCategory = [self getCategoryById:[category integerValue]];
    [imageCategory addUploadedImage:image];
    [imageCategory incrementImageSizeByOne];
    
    // Update category in cache
    NSInteger index = [self indexOfCategoryWithId:category.integerValue inArray:self.allCategories];
    if (index != NSNotFound) {
        NSMutableArray<PiwigoAlbumData *> *newCatList = [self.allCategories mutableCopy];
        [newCatList replaceObjectAtIndex:index withObject:imageCategory];
        self.allCategories = newCatList;
    }

    // Notify UI that...
    dispatch_async(dispatch_get_main_queue(), ^{
        // ...an image has been uploaded and appended to cache
        NSDictionary *userInfo = @{@"albumId" : category, @"imageId" : @(image.imageId)};
        [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationUploadedImage object:nil userInfo:userInfo];
        
        // ...the number of images has changed and that the thumbnail may have to be changed
        for (NSString *catStr in imageCategory.upperCategories) {
            userInfo = @{@"albumId" : catStr,
                         @"thumbnailId" : @(image.imageId),
                         @"thumbnailUrl" : image.ThumbPath};
            [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationChangedAlbumData object:nil userInfo:userInfo];
        }
    });
}

-(void)deleteImage:(PiwigoImageData*)image
{
	// Categories to which the image belongs to
    for(NSString *category in image.categoryIds)
	{
        [self removeImage:image fromCategory:category];
	}

    // Smart albums
    if ([self getImageForCategory:kPiwigoSearchCategoryId andId:image.imageId] != nil) {
        [self removeImage:image fromCategory:[NSString stringWithFormat:@"%ld", (long)kPiwigoSearchCategoryId]];
    }
    if ([self getImageForCategory:kPiwigoVisitsCategoryId andId:image.imageId] != nil) {
        [self removeImage:image fromCategory:[NSString stringWithFormat:@"%ld", (long)kPiwigoVisitsCategoryId]];
    }
    if ([self getImageForCategory:kPiwigoBestCategoryId andId:image.imageId] != nil) {
        [self removeImage:image fromCategory:[NSString stringWithFormat:@"%ld", (long)kPiwigoBestCategoryId]];
    }
    if ([self getImageForCategory:kPiwigoRecentCategoryId andId:image.imageId] != nil) {
        [self removeImage:image fromCategory:[NSString stringWithFormat:@"%ld", (long)kPiwigoRecentCategoryId]];
    }
    if ([self getImageForCategory:kPiwigoTagsCategoryId andId:image.imageId] != nil) {
        [self removeImage:image fromCategory:[NSString stringWithFormat:@"%ld", (long)kPiwigoTagsCategoryId]];
    }
    if ([self getImageForCategory:kPiwigoFavoritesCategoryId andId:image.imageId] != nil) {
        [self removeImage:image fromCategory:[NSString stringWithFormat:@"%ld", (long)kPiwigoFavoritesCategoryId]];
    }

    // Notify the Upload database that the image was deleted (background thread)
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    [appDelegate didDeletePiwigoImageWithID: image.imageId];
}

-(void)removeImage:(PiwigoImageData*)image fromCategory:(NSString *)category
{
    // Check the existence of the image
    PiwigoImageData *imageInCategory = [self getImageForCategory:category.integerValue andId:image.imageId];
    if (imageInCategory == nil) { return; }
    
    // Remove image from category
    PiwigoAlbumData *imageCategory = [self getCategoryById:[category integerValue]];
    [imageCategory deincrementImageSizeByOne];
    [imageCategory removeImages:@[image]];

    // Update category in cache
    NSInteger index = [self indexOfCategoryWithId:category.integerValue inArray:self.allCategories];
    if (index != NSNotFound) {
        NSMutableArray<PiwigoAlbumData *> *newImageList = [self.allCategories mutableCopy];
        [newImageList replaceObjectAtIndex:index withObject:imageCategory];
        self.allCategories = newImageList;
    }

    // Notify UI that...
    dispatch_async(dispatch_get_main_queue(), ^{
        // ...an image has been deleted to refresh the collection view
        NSDictionary *userInfo = @{@"albumId" : category, @"imageId" : @(image.imageId)};
        [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationRemovedImage object:nil userInfo:userInfo];

        // ...the number of images has changed and that the thumbnail may have to be changed
        for (NSString *catStr in imageCategory.upperCategories) {
            userInfo = @{@"albumId" : catStr,
                         @"thumbnailId" : @"0",
                         @"thumbnailUrl" : @""};
            [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationChangedAlbumData object:nil userInfo:userInfo];
        }
    });
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
