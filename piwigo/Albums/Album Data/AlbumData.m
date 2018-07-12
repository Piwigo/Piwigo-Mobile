//
//  AlbumData.m
//  piwigo
//
//  Created by Spencer Baker on 4/2/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "AlbumData.h"
#import "PiwigoAlbumData.h"
#import "ImageService.h"
#import "CategoriesData.h"
#import "CategoryImageSort.h"

@interface AlbumData()

@property (nonatomic, strong) NSArray *images;
@property (nonatomic, strong) NSString *sortString;
@property (nonatomic, strong) NSString *lastSortString;
@property (nonatomic, assign) NSInteger categoryId;
@property (nonatomic, assign) kPiwigoSortCategory sortType;

@end

@implementation AlbumData

-(instancetype)initWithCategoryId:(NSInteger)categoryId
{
	self = [super init];
	if(self)
	{
		self.images = [NSArray new];
		self.categoryId = categoryId;
		self.sortType = -1;
	}
	return self;
}

-(void)loadMoreImagesOnCompletion:(void (^)(void))completion
{
	NSInteger downloadedImageDataCount = [[CategoriesData sharedInstance] getCategoryById:self.categoryId].imageList.count;
	NSInteger totalImageCount = [[CategoriesData sharedInstance] getCategoryById:self.categoryId].numberOfImages;
	
	if(downloadedImageDataCount == totalImageCount)
	{
		self.images = [CategoryImageSort sortImages:[[CategoriesData sharedInstance] getCategoryById:self.categoryId].imageList forSortOrder:self.sortType];
		if(completion)
		{
			completion();
		}
		return;
	}
		
	[self updateSortString];
	
	[[[CategoriesData sharedInstance] getCategoryById:self.categoryId] loadCategoryImageDataChunkWithSort:self.sortString forProgress:nil OnCompletion:^(BOOL completed) {
		if(!completed)
		{
			return;
		}
		self.images = [CategoryImageSort sortImages:[[CategoriesData sharedInstance] getCategoryById:self.categoryId].imageList forSortOrder:self.sortType];
		if(completion)
		{
			completion();
		}
	}];
}

-(void)updateSortString
{
	NSString *sort = @"";
	switch(self.sortType)
	{
		case kPiwigoSortCategoryNameAscending:
			sort = [NSString stringWithFormat:@"%@ %@", kGetImageOrderName, kGetImageOrderAscending];
			break;
		case kPiwigoSortCategoryNameDescending:
			sort = [NSString stringWithFormat:@"%@ %@", kGetImageOrderName, kGetImageOrderDescending];
			break;

        case kPiwigoSortCategoryFileNameAscending:
			sort = [NSString stringWithFormat:@"%@ %@", kGetImageOrderFileName, kGetImageOrderAscending];
			break;
		case kPiwigoSortCategoryFileNameDescending:
			sort = [NSString stringWithFormat:@"%@ %@", kGetImageOrderFileName, kGetImageOrderDescending];
			break;
		
        case kPiwigoSortCategoryDateCreatedAscending:
            sort = [NSString stringWithFormat:@"%@ %@", kGetImageOrderDateCreated, kGetImageOrderAscending];
            break;
        case kPiwigoSortCategoryDateCreatedDescending:
            sort = [NSString stringWithFormat:@"%@ %@", kGetImageOrderDateCreated, kGetImageOrderDescending];
            break;
            
        case kPiwigoSortCategoryDatePostedAscending:
			sort = [NSString stringWithFormat:@"%@ %@", kGetImageOrderDateCreated, kGetImageOrderAscending];
			break;
		case kPiwigoSortCategoryDatePostedDescending:
			sort = [NSString stringWithFormat:@"%@ %@", kGetImageOrderDateCreated, kGetImageOrderDescending];
			break;

//		case kPiwigoSortCategoryVideoOnly:
//			//			sort = NSLocalizedString(@"categorySort_videosOnly", @"Videos Only");
//			break;
//		case kPiwigoSortCategoryImageOnly:
//			//			sort = NSLocalizedString(@"categorySort_imagesOnly", @"Images Only");
//			break;
			
		case kPiwigoSortCategoryCount:
			break;
	}
	
	self.sortString = sort;
}

-(void)updateImageSort:(kPiwigoSortCategory)imageSort
          OnCompletion:(void (^)(void))completion
{
//    if(imageSort == self.sortType)
//    {    // nothing changed, return
//        return;
//    }
	self.sortType = imageSort;
	
	NSInteger downloadedImageDataCount = [[CategoriesData sharedInstance] getCategoryById:self.categoryId].imageList.count;
	NSInteger totalImageCount = [[CategoriesData sharedInstance] getCategoryById:self.categoryId].numberOfImages;
	
	if(downloadedImageDataCount == totalImageCount)
	{	// we have all the image data, just manually sort it
		self.images = [CategoryImageSort sortImages:[[CategoriesData sharedInstance] getCategoryById:self.categoryId].imageList forSortOrder:self.sortType];
		if(completion)
		{
			completion();
		}
		return;
	}
	
	self.images = [NSArray new];
	[[[CategoriesData sharedInstance] getCategoryById:self.categoryId] resetData];
	[self loadMoreImagesOnCompletion:completion];
}

-(void)loadAllImagesOnCompletion:(void (^)(void))completion
{
	[[[CategoriesData sharedInstance] getCategoryById:self.categoryId]
     loadAllCategoryImageDataForProgress:nil OnCompletion:^(BOOL completed) {
            self.images = [[CategoriesData sharedInstance] getCategoryById:self.categoryId].imageList;
            if(completion)
            {
                completion();
            }
	}];
}

-(void)reloadAlbumOnCompletion:(void (^)(void))completion
{
	NSInteger currentPage = [[CategoriesData sharedInstance] getCategoryById:self.categoryId].onPage;
	[[[CategoriesData sharedInstance] getCategoryById:self.categoryId] resetData];
	
	[self loadImagePageUntil:currentPage onPage:0 onCompletion:completion];
}

-(void)loadImagePageUntil:(NSInteger)page onPage:(NSInteger)onPage onCompletion:(void (^)(void))completion
{
	if((onPage != 0) && (onPage >= page))
	{
		if(completion)
		{
			completion();
		}
		return;
	}
	
	[self loadMoreImagesOnCompletion:^{
		[self loadImagePageUntil:page onPage:onPage + 1 onCompletion:completion];
	}];
}

-(void)removeImage:(PiwigoImageData*)image
{
	[self removeImageWithId:[image.imageId integerValue]];
}

-(void)removeImageWithId:(NSInteger)imageId
{
	NSIndexSet *set = [self.images indexesOfObjectsPassingTest:^BOOL(PiwigoImageData *obj, NSUInteger idx, BOOL *stop) {
		return [obj.imageId integerValue] != imageId;
	}];
	self.images = [self.images objectsAtIndexes:set];
}


@end
