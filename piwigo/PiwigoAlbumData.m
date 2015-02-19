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

-(void)loadAllCategoryImageDataOnCompletion:(void (^)(BOOL completed))completion
{
	[self loopLoadImages:^(BOOL completed) {
		if(completion)
		{
			completion(YES);
		}
	}];
}

-(void)loopLoadImages:(void (^)(BOOL completed))completion
{
	[self loadCategoryImageDataChunkOnCompletion:^(BOOL completed) {
		if(self.imageList.count != self.numberOfImages)
		{
			[self loopLoadImages:completion];
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

-(void)loadCategoryImageDataChunkOnCompletion:(void (^)(BOOL completed))completion
{
	if(self.isLoadingMoreImages) return;
	
	self.isLoadingMoreImages = YES;
	
	[ImageService loadImageChunkForLastChunkCount:self.lastImageBulkCount
									  forCategory:self.albumId
										   onPage:self.onPage
								 ListOnCompletion:^(AFHTTPRequestOperation *operation, NSInteger count) {
									 
									 self.lastImageBulkCount = count;
									 self.onPage++;
									 self.isLoadingMoreImages = NO;
									 if(completion)
									 {
										 completion(YES);
									 }
								 } onFailure:^(AFHTTPRequestOperation *operation, NSError *error) {
									 
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
	[images enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		PiwigoImageData *image = (PiwigoImageData*)obj;
		if(![self.imageIds objectForKey:image.imageId]) {
			[newImages addObject:image];
		}
	}];
	
	if(newImages.count <= 0) return;
	
	NSMutableArray *newImageList = [[NSMutableArray alloc] initWithArray:self.imageList];
	for(PiwigoImageData *imageData in newImages)
	{
		[newImageList addObject:imageData];
		[self.imageIds setValue:@(0) forKey:imageData.imageId];
	}
	self.imageList = newImageList;
}

-(void)sortImageList:(ImageListOrder)order
{
	// @TODO: change sort based on enum
	self.imageList = [self.imageList sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
		PiwigoImageData *imgData1 = (PiwigoImageData*)obj1;
		PiwigoImageData *imgData2 = (PiwigoImageData*)obj2;
		
		return [imgData1.imageId integerValue] < [imgData2.imageId integerValue];
	}];
}

-(void)removeImage:(PiwigoImageData*)image
{
	NSMutableArray *newImageArray = [[NSMutableArray alloc] initWithArray:self.imageList];
	[newImageArray removeObject:image];
	self.imageList = newImageArray;
	
	[self.imageIds removeObjectForKey:image.imageId];
}

@end
