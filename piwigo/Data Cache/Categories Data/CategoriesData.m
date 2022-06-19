//
//  CategoriesData.m
//  piwigo
//
//  Created by Spencer Baker on 1/29/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "AlbumData.h"
#import "CategoriesData.h"

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
    PiwigoAlbumData *newCategory = [[PiwigoAlbumData alloc] initWithId:categoryId andQuery:nil];
    
    // Parent album
    newCategory.parentAlbumId = [[parameters objectForKey:@"parent"] integerValue];
    PiwigoAlbumData *parentAlbumData = [[CategoriesData sharedInstance] getCategoryById:newCategory.parentAlbumId];
    NSMutableArray *upperCategories = [NSMutableArray new];
    if (parentAlbumData.upperCategories.count != 0) {
        [upperCategories addObjectsFromArray:parentAlbumData.upperCategories];
    }
    [upperCategories addObject:[NSString stringWithFormat:@"%ld", (long)categoryId]];
    newCategory.upperCategories = [NSArray arrayWithArray:upperCategories];

    // Name, description, upload rights, number of images
    newCategory.name = [parameters objectForKey:@"name"];
    newCategory.comment = [parameters objectForKey:@"comment"];
    newCategory.hasUploadRights = parentAlbumData.hasUploadRights;
    newCategory.numberOfImages = 0;
    newCategory.totalNumberOfImages = 0;

    // Add new category to cache
    [[CategoriesData sharedInstance] updateCategories:@[newCategory]];
    
    // Get list of parent categories
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
    NSMutableArray<NSString *> *upperCategories = [catagoryToDelete.upperCategories mutableCopy];
    NSString *categoryIdStr = [NSString stringWithFormat:@"%ld", (long)catagoryToDelete.albumId];
    if ([upperCategories containsObject:categoryIdStr]) {
        [upperCategories removeObject:categoryIdStr];
    }

    // Create new list of categories
    NSMutableArray<PiwigoAlbumData*> *newCategories = [[NSMutableArray alloc] initWithArray:self.allCategories];

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
}


# pragma mark - Update cache

-(BOOL)replaceAllCategories:(NSArray<PiwigoAlbumData *>*)categories
{
    // Create new list of categories
    BOOL didChange = NO;
    NSMutableArray *newCategories = [[NSMutableArray alloc] init];

    // Loop on freshly retrieved categories
    for (PiwigoAlbumData *categoryData in categories)
    {
        // Is this a smart album?
        if (categoryData.albumId < 0) {
            // Keep smart albums in cache (favorites loaded at start or refresh requested)
            [newCategories addObject:categoryData];
            continue;
        }
        
        // Is this a known category?
        NSInteger index = [self indexOfCategoryWithId:categoryData.albumId
                                              inArray:self.allCategories];
        // Reuse some data if possible
        if (index != NSNotFound)
        {
            // Retrieve existing data
            PiwigoAlbumData *existingData = [self.allCategories objectAtIndex:index];
            
            // Reuse the image if the URL is identical
            if (categoryData.albumThumbnailUrl == existingData.albumThumbnailUrl) {
                categoryData.categoryImage = existingData.categoryImage;
            }

            // Can we assume that the image list did not change?
            /// - 'nb_images' is the number of images associated with the album
            /// - 'date_last' is the maximum 'date_available' of the images associated to an album.
            if ((categoryData.numberOfImages == existingData.numberOfImages) &&
                ([categoryData.dateLast timeIntervalSinceDate:existingData.dateLast] < 10.0)) {
                // We assume that the image list did not change
                [categoryData addImages:existingData.imageList];
            }
        }
        else {
            // Category added
            didChange = YES;
        }
        
        // Append category to new list
        [newCategories addObject:categoryData];
    }
        
    // Some categories may have only been suppressed
    if (!didChange && (newCategories.count < self.allCategories.count)) {
        didChange = YES;
    }

    // Update list of displayed categories
    self.allCategories = newCategories;
    return didChange;
}

-(void)updateCategories:(NSArray<PiwigoAlbumData *>*)categories
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
            if (updatedCategory.albumThumbnailUrl == category.albumThumbnailUrl) {
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
}

// Add Community albums at launch
-(void)addCommunityCategoryWithUploadRights:(PiwigoAlbumData *)category;
{
    NSMutableArray *existingCategories = [[NSMutableArray alloc] initWithArray:self.allCategories];
    NSMutableArray *existingComCategories = [[NSMutableArray alloc] initWithArray:self.communityCategoriesForUploadOnly];
    
    // Is this a category to update?
    NSInteger index = [self indexOfCategoryWithId:category.albumId inArray:existingCategories];
    if (index != NSNotFound)
    {
        // Update existing category
        PiwigoAlbumData *categoryData = [existingCategories objectAtIndex:index];
        categoryData.hasUploadRights = YES;
        [existingCategories setObject:categoryData atIndexedSubscript:index];
    }
    else
    {
        // This album was not returned by pwg.categories.getList
        category.hasUploadRights = YES;

        // Is this a category to update?
        NSInteger indexCom = [self indexOfCategoryWithId:category.albumId inArray:existingComCategories];
        if (indexCom != NSNotFound)
        {
            // Update existing Community category
            PiwigoAlbumData *categoryComData = [existingComCategories objectAtIndex:indexCom];
            categoryComData.hasUploadRights = YES;
            [existingComCategories setObject:categoryComData atIndexedSubscript:indexCom];
        }
        else
        {
            [existingComCategories addObject:category];
        }
    }
        
    self.allCategories = existingCategories;
    self.communityCategoriesForUploadOnly = existingComCategories;
}


# pragma mark - Get categories from cache

-(PiwigoAlbumData*)getCategoryById:(NSInteger)categoryId
{
    if ((categoryId == 0) || (categoryId == NSNotFound)) return nil;
    
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

-(NSDate *)getDateLastOfCategoriesInCategory:(NSInteger)parentCategory
{
    NSDate *dateLast = [NSDate distantPast];
    NSString *catId = [NSString stringWithFormat:@"%ld", (long)parentCategory];
    for(PiwigoAlbumData *category in self.allCategories)
    {
        if ([category.upperCategories containsObject:catId] &&
            category.dateLast != nil)
        {
            dateLast = [category.dateLast laterDate:dateLast];
        }
    }

    return dateLast;
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
    
    // Keep 'date_last' set as expected by the server
    NSTimeZone *tz = [NSTimeZone defaultTimeZone];
    NSInteger seconds = -[tz secondsFromGMTForDate: [NSDate date]];
    imageCategory.dateLast = MAX([NSDate dateWithTimeInterval: seconds sinceDate: [NSDate date]], imageCategory.dateLast);
    
    // Set album thumbnail if necessary
    if ((imageCategory.albumThumbnailId == 0) || (imageCategory.albumThumbnailUrl == nil) ||
        (imageCategory.albumThumbnailUrl.length == 0)) {
        imageCategory.albumThumbnailId = image.imageId;
        
        // Album thumbnail size
        switch ((kPiwigoImageSize)AlbumVars.shared.defaultAlbumThumbnailSize) {
            case kPiwigoImageSizeSquare:
                if (AlbumVars.shared.hasSquareSizeImages) {
                    imageCategory.albumThumbnailUrl = image.SquarePath;
                }
                break;
            case kPiwigoImageSizeXXSmall:
                if (AlbumVars.shared.hasXXSmallSizeImages) {
                    imageCategory.albumThumbnailUrl = image.XXSmallPath;
                }
                break;
            case kPiwigoImageSizeXSmall:
                if (AlbumVars.shared.hasXSmallSizeImages) {
                    imageCategory.albumThumbnailUrl = image.XSmallPath;
                }
                break;
            case kPiwigoImageSizeSmall:
                if (AlbumVars.shared.hasSmallSizeImages) {
                    imageCategory.albumThumbnailUrl = image.SmallPath;
                }
                break;
            case kPiwigoImageSizeMedium:
                if (AlbumVars.shared.hasMediumSizeImages) {
                    imageCategory.albumThumbnailUrl = image.MediumPath;
                }
                break;
            case kPiwigoImageSizeLarge:
                if (AlbumVars.shared.hasLargeSizeImages) {
                    imageCategory.albumThumbnailUrl = image.LargePath;
                }
                break;
            case kPiwigoImageSizeXLarge:
                if (AlbumVars.shared.hasXLargeSizeImages) {
                    imageCategory.albumThumbnailUrl = image.XLargePath;
                }
                break;
            case kPiwigoImageSizeXXLarge:
                if (AlbumVars.shared.hasXXLargeSizeImages) {
                    imageCategory.albumThumbnailUrl = image.XXLargePath;
                }
                break;

            case kPiwigoImageSizeThumb:
            case kPiwigoImageSizeFullRes:
            default:
                imageCategory.albumThumbnailUrl = image.ThumbPath;
                break;
        }
    }
    
    // Update category in cache
    NSInteger index = [self indexOfCategoryWithId:category.integerValue inArray:self.allCategories];
    if (index != NSNotFound) {
        NSMutableArray<PiwigoAlbumData *> *newCatList = [self.allCategories mutableCopy];
        [newCatList replaceObjectAtIndex:index withObject:imageCategory];
        self.allCategories = newCatList;
    }

    // Add image to album/images collection
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *viewController = [UIApplication sharedApplication].keyWindow.rootViewController.childViewControllers.lastObject;
        if ([viewController isKindOfClass:[AlbumViewController class]]) {
            AlbumViewController *vc = (AlbumViewController *)viewController;
            if (vc.categoryId == category.integerValue) {
                // Add image to category into which then image was uploaded
                [vc addImageWithId:image.imageId];
            } else if ((imageCategory.parentAlbumId == 0) ||
                       ([imageCategory.upperCategories containsObject:[NSString stringWithFormat:@"%ld", (long)vc.categoryId]])) {
                // Increment number of images in parent album cell
                [vc updateSubCategoryWithId:imageCategory.albumId];
            }
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

    // Notify the Upload database that the image was deleted
    dispatch_async(dispatch_get_main_queue(), ^{
        AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        [appDelegate didDeletePiwigoImageWithID: image.imageId];
    });
}

-(void)removeImage:(PiwigoImageData*)image fromCategory:(NSString *)category
{
    // Check the existence of the image
    NSInteger catId = category.integerValue;
    PiwigoImageData *imageInCategory = [self getImageForCategory:catId andId:image.imageId];
    if (imageInCategory == nil) { return; }
    
    // Remove image from category
    PiwigoAlbumData *imageCategory = [self getCategoryById:catId];
    [imageCategory deincrementImageSizeByOne];
    [imageCategory removeImages:@[image]];

    // Keep 'date_last' set as expected by the server
    NSDate *dateLast = [[NSDate alloc] initWithTimeIntervalSince1970:0];
    for (PiwigoImageData *keptImage in imageCategory.imageList) {
        if ([dateLast compare:keptImage.datePosted] == NSOrderedAscending) {
            dateLast = keptImage.datePosted;
        }
    }
    imageCategory.dateLast = dateLast;

    // Reset album thumbnail if the album is now empty
    if (imageCategory.totalNumberOfImages == 0) {
        imageCategory.albumThumbnailId = 0;
        imageCategory.albumThumbnailUrl = @"";
    }

    // Update categories in cache
    NSMutableArray<PiwigoAlbumData *> *newCatList = [self.allCategories mutableCopy];
    NSInteger index = [self indexOfCategoryWithId:catId inArray:newCatList];
    if (index != NSNotFound) {
        [newCatList replaceObjectAtIndex:index withObject:imageCategory];
    }
    
    // Update image data in the other categories
    // unless the user did remove the image from a smart album
    if (catId < 0) {
        // Remove category from the list of categories
        NSMutableArray<NSNumber *> *imageCatIds = [imageInCategory.categoryIds mutableCopy];
        NSNumber *catIdToRemove = [NSNumber numberWithInteger:catId];
        if ([imageCatIds containsObject:catIdToRemove]) { [imageCatIds removeObject:catIdToRemove]; }
        
        // Update concerned categories
        for (NSNumber *catIdNber in imageCatIds) {
            NSInteger catId = catIdNber.integerValue;
            
            // Retrieve the index of the category
            NSInteger catIndex = [self indexOfCategoryWithId:catId inArray:newCatList];
            if (catIndex == NSNotFound) { continue; }
            
            // Retrieve the category data
            PiwigoAlbumData *albumData = newCatList[catIndex];
            
            // Retrieve the index of the image in this category
            NSInteger imgIndex = [self indexOfImageWithId:image.imageId inArray:albumData.imageList];
            if (imgIndex == NSNotFound) { continue; }
            
            // Update the image data in that category
            albumData.imageList[imgIndex].categoryIds = imageCatIds;
            
            // Replace album
            [newCatList replaceObjectAtIndex:catIndex withObject:albumData];
        }
    }
    
    // Update list of cached categories
    self.allCategories = newCatList;

    // Remove image from album/images collection
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *viewController = [UIApplication sharedApplication].keyWindow.rootViewController.childViewControllers.lastObject;
        if ([viewController isKindOfClass:[AlbumViewController class]]) {
            AlbumViewController *vc = (AlbumViewController *)viewController;
            if (vc.categoryId == category.integerValue) {
                [vc removeImageWithId:image.imageId];
            }
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

-(NSInteger)indexOfImageWithId:(NSInteger)imageId inArray:(NSArray *)imageList
{
    NSInteger index = [imageList indexOfObjectPassingTest:^BOOL(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        PiwigoImageData *image = (PiwigoImageData *)obj;
        if(image.imageId == imageId)
            return YES;
        else
            return NO;
    }];
    
    return index;
}


@end
