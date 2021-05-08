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

@interface AlbumData()

@property (nonatomic, assign) NSInteger categoryId;
@property (nonatomic, assign) kPiwigoSort sortType;

@end

@implementation AlbumData

#pragma mark - Initialisation

-(instancetype)initWithCategoryId:(NSInteger)categoryId andQuery:(NSString *)query
{
	self = [super init];
	if(self)
	{
		self.images = [NSArray new];
        self.searchQuery = [NSString stringWithString:query];
		self.categoryId = categoryId;
		self.sortType = -1;
	}
	return self;
}


#pragma mark - Load image data

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
        if (completion) { completion(); }
        return;
    }
    
    [self loadMoreImagesOnCompletion:^{
        [self loadImagePageUntil:page onPage:onPage + 1 onCompletion:completion];
    }];
}

-(void)loadMoreImagesOnCompletion:(void (^)(void))completion
{
	NSInteger downloadedImageDataCount = [[CategoriesData sharedInstance] getCategoryById:self.categoryId].imageList.count;
	NSInteger totalImageCount = [[CategoriesData sharedInstance] getCategoryById:self.categoryId].numberOfImages;
	
    // Return if job done
    if (downloadedImageDataCount >= totalImageCount)
	{
//        NSLog(@"loadMoreImagesOnCompletion: we have all image data");
        // We have all the image data, just manually sort it (uploaded images are appended to cache)
        self.images = [CategoryImageSort sortImages:[[CategoriesData sharedInstance] getCategoryById:self.categoryId].imageList for:[Model sharedInstance].defaultSort];
		if(completion)
		{
			completion();
		}
		return;
	}
    
    // Set sort string parameter from sort type
    NSString *sortDesc = [CategoryImageSort getPiwigoSortDescriptionFor:self.sortType];
	
    // Load more category image data
	[[[CategoriesData sharedInstance] getCategoryById:self.categoryId]
                   loadCategoryImageDataChunkWithSort:sortDesc forProgress:nil
                                         OnCompletion:^(BOOL completed)
    {
		if(!completed) { return; }
        // We have all the image data, just manually sort it (uploaded images are appended to cache)
        self.images = [CategoryImageSort sortImages:[[CategoriesData sharedInstance] getCategoryById:self.categoryId].imageList for:self.sortType];
		if(completion) { completion(); }
	}];
}

-(void)loadAllImagesOnCompletion:(void (^)(void))completion
{
    [[[CategoriesData sharedInstance] getCategoryById:self.categoryId]
     loadAllCategoryImageDataForProgress:nil OnCompletion:^(BOOL completed) {
         if (completed) {
            self.images = [[CategoriesData sharedInstance] getCategoryById:self.categoryId].imageList;
            if(completion)
            {
                completion();
            }
         }
    }];
}


#pragma mark - Image sorting

-(void)updateImageSort:(kPiwigoSort)imageSort
          OnCompletion:(void (^)(void))completion
{
	NSInteger downloadedImageDataCount = [[CategoriesData sharedInstance] getCategoryById:self.categoryId].imageList.count;
	NSInteger totalImageCount = [[CategoriesData sharedInstance] getCategoryById:self.categoryId].numberOfImages;
	
//    NSLog(@"updateImageSort: catId=%ld, downloaded:%ld, total:%ld", (long)self.categoryId, (long)downloadedImageDataCount, (long)totalImageCount);
	if (downloadedImageDataCount >= totalImageCount)
	{	// We have all the image data, just manually sort it (uploaded images are appended to cache)
        self.images = [CategoryImageSort sortImages:[[CategoriesData sharedInstance] getCategoryById:self.categoryId].imageList for:imageSort];
		if(completion)
		{
//            NSLog(@"updateImageSort: we have all image data i.e. %ld", (long)self.images.count);
            completion();
		}
		return;
	}
	
    self.sortType = imageSort;
//	self.images = [NSArray new];
//	[[[CategoriesData sharedInstance] getCategoryById:self.categoryId] resetData];
	[self loadMoreImagesOnCompletion:completion];
}


#pragma mark - Update images

-(void)updateImage:(PiwigoImageData *)params
{
    // Anything to do?
    if (params == nil) return;

    // Initialisation
    NSInteger index = 0;
    NSMutableArray *newImages = [self.images mutableCopy];
    
    // Lopp over current images
    for (PiwigoImageData *image in self.images)
    {
        if (image.imageId == params.imageId)
        {
            // Update image data
            if (params.fileName) image.fileName = params.fileName;
            image.imageTitle = params.imageTitle;
            image.author = params.author;
            image.privacyLevel = params.privacyLevel;
            if (params.comment)
                image.comment = [NSString stringWithString:params.comment];
            else
                image.comment = @"";
            image.tags = [params.tags copy];
            
            // Update list and currently viewed image
            [newImages replaceObjectAtIndex:index withObject:image];
            break;
        }
        index++;
    }
    
    // Update image list
    self.images = [newImages copy];
}


#pragma mark - Remove images

-(void)removeImage:(PiwigoImageData*)image
{
	[self removeImageWithId:image.imageId];
}

-(void)removeImageWithId:(NSInteger)imageId
{
	NSIndexSet *set = [self.images indexesOfObjectsPassingTest:^BOOL(PiwigoImageData *obj, NSUInteger idx, BOOL *stop) {
		return obj.imageId != imageId;
	}];
	self.images = [self.images objectsAtIndexes:set];
}


@end
