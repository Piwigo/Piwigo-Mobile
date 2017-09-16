//
//  PiwigoAlbumData.m
//  piwigo
//
//  Created by Spencer Baker on 1/24/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "PiwigoAlbumData.h"
#import "ImageService.h"
#import "Model.h"
#import "CategoriesData.h"
#import "ImageUpload.h"

@interface PiwigoAlbumData()

@property (nonatomic, strong) NSArray *imageList;
@property (nonatomic, strong) NSMutableDictionary *imageIds;

@property (nonatomic, assign) BOOL isLoadingMoreImages;
@property (nonatomic, assign) NSInteger lastImageBulkCount;
@property (nonatomic, assign) NSInteger onPage;

@end

@implementation PiwigoAlbumData

-(instancetype)init
{
	self = [super init];
	if(self)
	{
		self.imageIds = [NSMutableDictionary new];
		
		self.isLoadingMoreImages = NO;
		self.lastImageBulkCount = [Model sharedInstance].imagesPerPage;
		self.onPage = 0;
	}
	return self;
}

-(void)loadAllCategoryImageDataForProgress:(void (^)(NSInteger onPage, NSInteger outOf))progress
							  OnCompletion:(void (^)(BOOL completed))completion
{
	self.onPage = 0;
	[self loopLoadImagesForSort:@""
				   withProgress:progress
					   onCompletion:^(BOOL completed) {
		if(completion)
		{
			completion(YES);
		}
	}];
}

-(void)loopLoadImagesForSort:(NSString*)sort
				withProgress:(void (^)(NSInteger onPage, NSInteger outOf))progress
					onCompletion:(void (^)(BOOL completed))completion
{
	[self loadCategoryImageDataChunkWithSort:sort
								 forProgress:progress
                                OnCompletion:^(BOOL completed) {
		if(completed && self.lastImageBulkCount && self.imageList.count != self.numberOfImages)
		{
			[self loopLoadImagesForSort:sort
						   withProgress:progress
							   onCompletion:completion];
		}
		else
		{
			if(completion)
			{
				completion(YES);
			}
		}
	}];
}

-(void)loadCategoryImageDataChunkWithSort:(NSString*)sort
							  forProgress:(void (^)(NSInteger onPage, NSInteger outOf))progress
								OnCompletion:(void (^)(BOOL completed))completion
{
	if(self.isLoadingMoreImages) return;
	
	self.isLoadingMoreImages = YES;
	
	[ImageService loadImageChunkForLastChunkCount:self.lastImageBulkCount
									  forCategory:self.albumId
										   onPage:self.onPage
										  forSort:sort
								 ListOnCompletion:^(NSURLSessionTask *task, NSInteger count) {
									 
									 if(progress)
									 {
										 PiwigoAlbumData *downloadingCategory = [[CategoriesData sharedInstance] getCategoryById:self.albumId];
										 NSInteger numOfImgs = downloadingCategory.numberOfImages;
										 progress(self.onPage, numOfImgs);
									 }
									 
									 self.lastImageBulkCount = count;
									 self.onPage++;
									 self.isLoadingMoreImages = NO;
									 
									 if(completion)
									 {
										 completion(YES);
									 }
								 } onFailure:^(NSURLSessionTask *task, NSError *error) {
									 
									 if(error)
									 {
										 [UIAlertView showWithTitle:NSLocalizedString(@"albumPhotoError_title", @"Get Album Photos Error")
															message:[NSString stringWithFormat:@"%@\n%@", NSLocalizedString(@"albumPhotoError_message", @"Failed to get album photos (corrupt image in your album?)"), [error localizedDescription]]
												  cancelButtonTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
												  otherButtonTitles:nil
														   tapBlock:nil];
									 }
									 self.isLoadingMoreImages = NO;
									 if(completion)
									 {
										 completion(NO);
									 }
								 }];
}

-(void)addImages:(NSArray*)images
{
	NSMutableArray *newImages = [NSMutableArray new];
	NSMutableArray *updateImages = [[NSMutableArray alloc] initWithArray:images];
	[images enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		PiwigoImageData *image = (PiwigoImageData*)obj;
		if(![self.imageIds objectForKey:image.imageId]) {
			[newImages addObject:image];
			[updateImages removeObject:image];
		}
	}];
	
	if(updateImages.count > 0)
	{
		NSMutableArray *newImageUpdateList = [[NSMutableArray alloc] initWithArray:self.imageList];
		for(PiwigoImageData *updateImage in updateImages)
		{
			for(PiwigoImageData *existingImage in self.imageList)
			{
				if([existingImage.imageId integerValue] == [updateImage.imageId integerValue])
				{
					[newImageUpdateList removeObject:existingImage];
					break;
				}
			}
		}
		
		// this image has already been added, so update it
		for(PiwigoImageData *updateImage in updateImages)
		{
			for(PiwigoImageData *existingImage in self.imageList)
			{
				if([existingImage.imageId integerValue]  == [updateImage.imageId integerValue])
				{
					[newImageUpdateList addObject:updateImage];
					break;
				}
			}
		}
		
		self.imageList = newImageUpdateList;
	}
	
	NSMutableArray *newImageList = [[NSMutableArray alloc] initWithArray:self.imageList];
	for(PiwigoImageData *imageData in newImages)
	{
		[newImageList addObject:imageData];
		[self.imageIds setValue:@(0) forKey:imageData.imageId];
	}
	self.imageList = newImageList;
}

-(void)removeImage:(PiwigoImageData*)image
{
	NSMutableArray *newImageArray = [[NSMutableArray alloc] initWithArray:self.imageList];
	[newImageArray removeObject:image];
	self.imageList = newImageArray;
	
	[self.imageIds removeObjectForKey:image.imageId];
}

-(void)updateCacheWithImageUploadInfo:(ImageUpload*)imageUpload
{
	PiwigoImageData *newImageData = [[CategoriesData sharedInstance] getImageForCategory:imageUpload.categoryToUploadTo andId:[NSString stringWithFormat:@"%@", @(imageUpload.imageId)]];
	
    newImageData.fileName = imageUpload.image;
    newImageData.name = imageUpload.title;
	newImageData.privacyLevel = imageUpload.privacyLevel;
	newImageData.author = imageUpload.author;
	newImageData.imageDescription = imageUpload.imageDescription;
	newImageData.tags = imageUpload.tags;
	
	[self addImages:@[newImageData]];
}

-(NSInteger)getDepthOfCategory
{
	return self.upperCategories ? [self.upperCategories count] : 0;
}

-(BOOL)containsUpperCategory:(NSInteger)category
{
	return self.nearestUpperCategory == category;
}

-(void)resetData
{
	self.imageIds = [NSMutableDictionary new];
	self.isLoadingMoreImages = NO;
	self.lastImageBulkCount = [Model sharedInstance].imagesPerPage;
	self.onPage = 0;
	self.imageList = [NSArray new];
}

-(void)incrementImageSizeByOne
{
	// Increment number of images in category
    self.numberOfImages++;
	for(NSString *category in self.upperCategories)
	{
		[[CategoriesData sharedInstance] getCategoryById:[category integerValue]].totalNumberOfImages++;
	}
}

-(void)deincrementImageSizeByOne
{
	// Decrement number of images in category
    self.numberOfImages--;
	for(NSString *category in self.upperCategories)
	{
		[[CategoriesData sharedInstance] getCategoryById:[category integerValue]].totalNumberOfImages--;
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
    [descriptionArray addObject:[NSString stringWithFormat:@"nearestUpperCategory   = %ld", (long)self.nearestUpperCategory]];
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
