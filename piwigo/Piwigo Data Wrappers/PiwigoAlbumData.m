//
//  PiwigoAlbumData.m
//  piwigo
//
//  Created by Spencer Baker on 1/24/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "PiwigoAlbumData.h"
#import "ImageService.h"
#import "CategoriesData.h"

NSInteger const kPiwigoSearchCategoryId     = -1;           // Search
NSInteger const kPiwigoVisitsCategoryId     = -2;           // Most visited
NSInteger const kPiwigoBestCategoryId       = -3;           // Best rated
NSInteger const kPiwigoRecentCategoryId     = -4;           // Recent photos
NSInteger const kPiwigoFavoritesCategoryId  = -6;           // Favorites
NSInteger const kPiwigoTagsCategoryId       = -10;          // Tag images (offset)

@interface PiwigoAlbumData()

@property (nonatomic, strong) NSArray<PiwigoImageData*> *imageList;

@property (nonatomic, assign) NSInteger lastImageBulkCount;
@property (nonatomic, assign) NSInteger onPage;

@end

@implementation PiwigoAlbumData

-(instancetype)init
{
	self = [super init];
	if(self)
	{
        self.isLoadingMoreImages = NO;
        self.lastImageBulkCount = 0;
		self.onPage = 0;
        self.imageList = [NSArray<PiwigoImageData *> new];
	}
	return self;
}

// Smart data are stored in a virtual album with special IDs
-(PiwigoAlbumData *)initWithId:(NSInteger)categoryId andQuery:(NSString *)query
{
    PiwigoAlbumData *albumData = [PiwigoAlbumData new];
    albumData.albumId = categoryId;
    if (categoryId > kPiwigoTagsCategoryId) {
        if (query == nil) {
            albumData.query = @"";
        } else {
            albumData.query = [NSString stringWithString:query];
        }
    }
    
    // No parent album
    if (categoryId == kPiwigoSearchCategoryId) {
        albumData.name = [NSString stringWithString:query];
    } else if (categoryId == kPiwigoVisitsCategoryId) {
        albumData.name = NSLocalizedString(@"categoryDiscoverVisits_title", @"Most visited");
    } else if (categoryId == kPiwigoBestCategoryId) {
        albumData.name = NSLocalizedString(@"categoryDiscoverBest_title", @"Best rated");
    } else if (categoryId == kPiwigoRecentCategoryId) {
        albumData.name = NSLocalizedString(@"categoryDiscoverRecent_title", @"Recent photos");
    } else if (categoryId == kPiwigoFavoritesCategoryId) {
        albumData.name = NSLocalizedString(@"categoryDiscoverFavorites_title", @"My Favorites");
    } else if (categoryId < kPiwigoTagsCategoryId) {
        if ((query == nil) || (query.length == 0)) {
            albumData.name = NSLocalizedString(@"categoryDiscoverTagged_title", @"Tagged");
        } else {
            albumData.name = [NSString stringWithString:query];
        }
    } else {
        albumData.name = @"—";
    }
    albumData.parentAlbumId = NSIntegerMin;
    albumData.upperCategories = [NSArray new];
    
    // Empty album at start
    albumData.comment = @"";
    albumData.globalRank = 0.0;
    albumData.numberOfSubCategories = 0;
    albumData.numberOfImages = NSNotFound;
    albumData.totalNumberOfImages = NSNotFound;

    // No album image
    albumData.albumThumbnailId = 0;
    albumData.albumThumbnailUrl = @"";
    
    // Date of creation
    albumData.dateLast = [NSDate date];
    
    // No upload rights
    albumData.hasUploadRights = NO;
    
    return albumData;
}

-(void)loadAllCategoryImageDataWithSort:(kPiwigoSortObjc)sort
                            forProgress:(void (^)(NSInteger onPage, NSInteger outOf))progress
                            onCompletion:(void (^)(BOOL completed))completion
                              onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
	self.onPage = 0;
    self.lastImageBulkCount = 0;
    
    // Set sort string parameter from sort type
    NSString *sortDesc = @"date_creation asc";

    [self loopLoadImagesForSort:sortDesc
				   withProgress:progress
                   onCompletion:^(BOOL completed) {
		if (completion) {
			completion(YES);
		}
    } onFailure:^(NSURLSessionTask *task, NSError *error) {
        if (fail) {
            fail(task, error);
        }
    }];
}

-(void)loopLoadImagesForSort:(NSString*)sort
				withProgress:(void (^)(NSInteger onPage, NSInteger outOf))progress
                onCompletion:(void (^)(BOOL completed))completion
                   onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
	[self loadCategoryImageDataChunkWithSort:sort
								 forProgress:progress
                                onCompletion:^(BOOL completed) {
//        NSLog(@"loop Cat:%ld page:%4ld | last:%04ld, images:%04ld -> nberImages:%04ld [%@]", (long)self.albumId, (long)self.onPage, (long)self.lastImageBulkCount, (long)self.imageList.count, (long)self.numberOfImages, completed ? @"Ok" : @"-!-");
        if (completed && self.lastImageBulkCount && self.imageList.count < self.numberOfImages)
		{
			[self loopLoadImagesForSort:sort
						   withProgress:progress
                           onCompletion:completion
                              onFailure:fail];
		}
		else
        {
			if (completion) {
				completion(YES);
			}
		}
	} onFailure:^(NSURLSessionTask *task, NSError *error) {
        if (fail) {
            fail(task, error);
        }
    }];
}

-(void)loadCategoryImageDataChunkWithSort:(NSString*)sort
							  forProgress:(void (^)(NSInteger onPage, NSInteger outOf))progress
                             onCompletion:(void (^)(BOOL completed))completion
                                onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
    // Bypass if it is already loading image data
    if (self.isLoadingMoreImages) {
        if (completion) { completion(NO); }
        return;
    }
    
    // Load more image data…
	self.isLoadingMoreImages = YES;
	[ImageService loadImageChunkForLastChunkCount:self.lastImageBulkCount
                                      forCategory:self.albumId orQuery:self.query
										   onPage:self.onPage
										  forSort:sort
								 ListOnCompletion:^(NSURLSessionTask *task, NSInteger count) {

        // Remember number of loaded image data in this chunk
        self.lastImageBulkCount = count;

        // Should we increment onPage?
        NSInteger numOfImgs = [[CategoriesData sharedInstance] getCategoryById:self.albumId].numberOfImages;
        NSInteger imagesPerPage = [AlbumUtilities numberOfImagesToDownloadPerPage];
        if (count >= imagesPerPage) { self.onPage++; }
        self.isLoadingMoreImages = NO;

        // Report progress if needed
        if (progress) {
            progress(self.onPage, numOfImgs);
        }

        // Perform completion block
        if(completion) {
            completion(YES);
        }
    } onFailure:^(NSURLSessionTask *task, NSError *error) {
         self.isLoadingMoreImages = NO;
         if (fail) {
             fail(task, error);
         }
    }];
}

-(BOOL)hasAllImagesInCache
{
    // Check that the number of images is the expected one
    if (self.imageList.count < self.numberOfImages) {
        return NO;
    }

    // Check if there are still non-loaded image data
    NSInteger indexOfNonCachedImage = [self.imageList indexOfObjectPassingTest:^BOOL(PiwigoImageData *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        return obj.imageId == NSNotFound;
    }];
    if (indexOfNonCachedImage != NSNotFound) { return NO; }

    return YES;
}

-(NSInteger)addImages:(NSArray<PiwigoImageData*> *)images
{
    // Create new image list
    NSMutableArray<PiwigoImageData*> *newImageList = [NSMutableArray new];
    if (self.imageList.count > 0) {
        [newImageList addObjectsFromArray:self.imageList];
    }
	
    // Append new images
    NSInteger count = 0;
    for(PiwigoImageData *imageData in images)
    {
        // API pwg.categories.getList returns:
        //      id, categories, name, comment, hit
        //      file, date_creation, date_available, width, height
        //      element_url, derivatives, (page_url)
        //
        NSInteger indexOfExistingItem = [newImageList indexOfObjectPassingTest:^BOOL(PiwigoImageData *obj, NSUInteger idx, BOOL * _Nonnull stop) {
            return obj.imageId == imageData.imageId;
        }];
        if (indexOfExistingItem == NSNotFound) {
            count++;
            [newImageList addObject:imageData];
        } else {
            [newImageList replaceObjectAtIndex:indexOfExistingItem withObject:imageData];
        }
    }
    
    // Store updated list
	self.imageList = newImageList;
    return count;
}

-(void)addUploadedImage:(PiwigoImageData*)imageData
{
    // Create new image list
    NSMutableArray<PiwigoImageData*> *newImageList = [NSMutableArray new];
    if (self.imageList.count > 0) {
        [newImageList addObjectsFromArray:self.imageList];
    }
    
    // Append uploaded image (replace it if it exists)
    // API pwg.images.upload only returns:
    //      image_id, square_src, name, src, (category)
    //
    NSInteger indexOfExistingItem = [newImageList indexOfObjectPassingTest:^BOOL(PiwigoImageData *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        return obj.imageId == imageData.imageId;
    }];
    if (indexOfExistingItem == NSNotFound) {
		[newImageList addObject:imageData];
    } else {
        [newImageList replaceObjectAtIndex:indexOfExistingItem withObject:imageData];
    }
    
    // Update image list
    self.imageList = newImageList;
}

-(void)updateImages:(NSArray<PiwigoImageData*> *)updatedImages
{
    // Check that there is something to do
    if (updatedImages == nil) return;
    if (updatedImages.count < 1) return;
    
    // Create new image list
    NSMutableArray<PiwigoImageData*> *newImageList = [NSMutableArray new];
    if (self.imageList.count > 0) {
        [newImageList addObjectsFromArray:self.imageList];
    }
    
    // Update image list
    for(NSInteger index = 0; index < self.imageList.count; index++)
    {
        // Known image data
        PiwigoImageData *existingImage = self.imageList[index];
        
        // Update this image if needed
        for(PiwigoImageData *updatedImage in updatedImages)
        {
            if(updatedImage.imageId == existingImage.imageId)
            {
                // API pwg.images.getInfo returns in addition:
                //      author, level, tags, (added_by), rating_score, (rates), (representative_ext)
                //      filesize, (md5sum), (date_metadata_update), (lastmodified), (rotation)
                //      (latitude), (longitude), (comments), (comments_paging), (coi)
                //
                // New data replaces old once
                [newImageList replaceObjectAtIndex:index withObject:updatedImage];
                break;
            }
        }
    }
    
    // Store updated list
    self.imageList = newImageList;
}

-(void)updateImageAfterEdit:(PiwigoImageData *)updatedImage
{
    // Check that there is something to do
    if (updatedImage == nil) return;
    
    // Create new image list
    NSMutableArray<PiwigoImageData*> *newImageList = [NSMutableArray new];
    if (self.imageList.count > 0) {
        [newImageList addObjectsFromArray:self.imageList];
    }

    // Update image list
    for(NSInteger index = 0; index < self.imageList.count; index++)
    {
        // Known image data
        PiwigoImageData *existingImage = self.imageList[index];
        
        // Update this image
        if(updatedImage.imageId == existingImage.imageId)
        {
            // New data replaces old once
            PiwigoImageData *updatedImage = existingImage;
            updatedImage.fileName = updatedImage.fileName;
            updatedImage.imageTitle = updatedImage.imageTitle;
            updatedImage.author = updatedImage.author;
            updatedImage.privacyLevel = updatedImage.privacyLevel;
            updatedImage.comment = [NSString stringWithString:updatedImage.comment];
            updatedImage.tags = [updatedImage.tags copy];
            [newImageList replaceObjectAtIndex:index withObject:updatedImage];
            break;
        }
    }
    
    // Store updated list
    self.imageList = newImageList;
}

-(void)removeAllImages
{
    self.imageList = [NSArray<PiwigoImageData *> new];
}

-(void)removeImages:(NSArray*)images
{
    NSMutableArray<PiwigoImageData*> *newImageList = [NSMutableArray new];
    if (self.imageList.count > 0) {
        [newImageList addObjectsFromArray:self.imageList];
    }

    for (PiwigoImageData *image in images) {
        NSInteger indexOfItem = [newImageList indexOfObjectPassingTest:^BOOL(PiwigoImageData *obj, NSUInteger idx, BOOL * _Nonnull stop) {
            return obj.imageId == image.imageId;
        }];
        if (indexOfItem == NSNotFound) { continue; }
        [newImageList removeObjectAtIndex:indexOfItem];
    }
    
    self.imageList = newImageList;
}

-(NSInteger)getDepthOfCategory
{
	return self.upperCategories ? [self.upperCategories count] : 0;
}

-(void)resetData
{
	self.isLoadingMoreImages = NO;
    self.lastImageBulkCount = 0;
	self.onPage = 0;
    self.imageList = [NSArray<PiwigoImageData *> new];
}

-(void)incrementImageSizeByOne
{
	// Increment number of images in category
    self.numberOfImages++;
    self.totalNumberOfImages++;
	for(NSString *category in self.upperCategories)
	{
        if (category.integerValue != self.albumId) {
            [[CategoriesData sharedInstance] getCategoryById:[category integerValue]].totalNumberOfImages++;
            NSLog(@"•••> incrementImageSizeByOne: catId=%ld, nber:%ld, total:%ld", (long)[category integerValue], (long)self.numberOfImages, (long)self.totalNumberOfImages);
        }
	}
}

-(void)deincrementImageSizeByOne
{
	// Decrement number of images in category
    self.numberOfImages = MAX(self.numberOfImages - 1, 0);
    self.totalNumberOfImages = MAX(self.totalNumberOfImages - 1, 0);
	for(NSString *category in self.upperCategories)
	{
        if (category.integerValue != self.albumId) {
            [[CategoriesData sharedInstance] getCategoryById:[category integerValue]].totalNumberOfImages--;
            NSLog(@"•••> decrementImageSizeByOne: catId=%ld, nber:%ld, total:%ld", (long)[category integerValue], (long)self.numberOfImages, (long)self.totalNumberOfImages);
        }
	}
}

#pragma mark - debugging support -

-(NSString *)description {
    NSString *objectIsNil = @"<nil>";

    NSMutableArray * descriptionArray = [[NSMutableArray alloc] init];
    [descriptionArray addObject:[NSString stringWithFormat:@"<%@: 0x%lx> = {", [self class], (unsigned long)self]];
    
    [descriptionArray addObject:[NSString stringWithFormat:@"name                   = %@", (nil == self.name ? objectIsNil : (0 == [self.name length] ? @"''" : self.name))]];
    [descriptionArray addObject:[NSString stringWithFormat:@"globalRank             = %ld", (long)self.globalRank]];
    [descriptionArray addObject:[NSString stringWithFormat:@"albumId                = %ld", (long)self.albumId]];
    [descriptionArray addObject:[NSString stringWithFormat:@"parentAlbumId          = %ld", (long)self.parentAlbumId]];
    [descriptionArray addObject:[NSString stringWithFormat:@"upperCategories [%ld]  = %@", (long)self.upperCategories.count, self.upperCategories]];
    [descriptionArray addObject:[NSString stringWithFormat:@"numberOfImages         = %ld", (long)self.numberOfImages]];
    [descriptionArray addObject:[NSString stringWithFormat:@"totalNumberOfImages    = %ld", (long)self.totalNumberOfImages]];
    [descriptionArray addObject:[NSString stringWithFormat:@"numberOfSubCategories  = %ld", (long)self.numberOfSubCategories]];
    [descriptionArray addObject:[NSString stringWithFormat:@"albumThumbnailId       = %ld", (long)self.albumThumbnailId]];
    [descriptionArray addObject:[NSString stringWithFormat:@"albumThumbnailUrl      = %@", (nil == self.albumThumbnailUrl ? objectIsNil :(0 == self.albumThumbnailUrl.length ? @"''" : self.albumThumbnailUrl))]];
    [descriptionArray addObject:[NSString stringWithFormat:@"dateLast               = %@", self.dateLast]];
    [descriptionArray addObject:[NSString stringWithFormat:@"categoryImage          = %@", (nil == self.categoryImage) ? @"Assigned" : objectIsNil]];
    [descriptionArray addObject:[NSString stringWithFormat:@"comment                = %@", (0 == self.comment.length ? @"''" : self.comment)]];
    [descriptionArray addObject:@"}"];
    
    return [descriptionArray componentsJoinedByString:@"\n"];
}

@end
