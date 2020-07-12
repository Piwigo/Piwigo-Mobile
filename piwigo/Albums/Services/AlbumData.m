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

@property (nonatomic, strong) NSArray *images;
@property (nonatomic, strong) NSString *sortString;
@property (nonatomic, strong) NSString *lastSortString;
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

-(void)loadMoreImagesOnCompletion:(void (^)(void))completion
{
	NSInteger downloadedImageDataCount = [[CategoriesData sharedInstance] getCategoryById:self.categoryId].imageList.count;
	NSInteger totalImageCount = [[CategoriesData sharedInstance] getCategoryById:self.categoryId].numberOfImages;
	
    // Return if job done
    if (downloadedImageDataCount >= totalImageCount)
	{
        NSLog(@"loadMoreImagesOnCompletion: we have all image data");
        self.images = [[CategoriesData sharedInstance] getCategoryById:self.categoryId].imageList;
		if(completion)
		{
			completion();
		}
		return;
	}
    
    // Set sort string parameter from sort type
	[self updateSortString];
	
    // Load more category image data
	[[[CategoriesData sharedInstance] getCategoryById:self.categoryId] loadCategoryImageDataChunkWithSort:self.sortString forProgress:nil OnCompletion:^(BOOL completed) {
		if(!completed)
		{
			return;
		}
        self.images = [[CategoriesData sharedInstance] getCategoryById:self.categoryId].imageList;
		if(completion)
		{
			completion();
		}
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

-(void)updateSortString
{
	NSString *sort = @"";
	switch (self.sortType)
	{
		case kPiwigoSortNameAscending:          // Photo title, A → Z
			sort = [NSString stringWithFormat:@"%@ %@", kGetImageOrderName, kGetImageOrderAscending];
			break;
		case kPiwigoSortNameDescending:         // Photo title, Z → A
			sort = [NSString stringWithFormat:@"%@ %@", kGetImageOrderName, kGetImageOrderDescending];
			break;

        case kPiwigoSortFileNameAscending:      // File name, A → Z
			sort = [NSString stringWithFormat:@"%@ %@", kGetImageOrderFileName, kGetImageOrderAscending];
			break;
		case kPiwigoSortFileNameDescending:     // File name, Z → A
			sort = [NSString stringWithFormat:@"%@ %@", kGetImageOrderFileName, kGetImageOrderDescending];
			break;
		
        case kPiwigoSortDateCreatedAscending:   // Date created, old → new
            sort = [NSString stringWithFormat:@"%@ %@", kGetImageOrderDateCreated, kGetImageOrderAscending];
            break;
        case kPiwigoSortDateCreatedDescending:  // Date created, new → old
            sort = [NSString stringWithFormat:@"%@ %@", kGetImageOrderDateCreated, kGetImageOrderDescending];
            break;
            
        case kPiwigoSortDatePostedAscending:    // Date posted, new → old
			sort = [NSString stringWithFormat:@"%@ %@", kGetImageOrderDatePosted, kGetImageOrderAscending];
			break;
		case kPiwigoSortDatePostedDescending:   // Date posted, old → new
			sort = [NSString stringWithFormat:@"%@ %@", kGetImageOrderDatePosted, kGetImageOrderDescending];
			break;

        case kPiwigoSortRatingScoreDescending:  // Rating score, high → low
            sort = [NSString stringWithFormat:@"%@ %@", kGetImageOrderRating, kGetImageOrderDescending];
            break;
        case kPiwigoSortRatingScoreAscending:   // Rating score, low → high
            sort = [NSString stringWithFormat:@"%@ %@", kGetImageOrderRating, kGetImageOrderAscending];
            break;

        case kPiwigoSortVisitsAscending:        // Visits, high → low
            sort = [NSString stringWithFormat:@"%@ %@", kGetImageOrderVisits, kGetImageOrderAscending];
            break;
        case kPiwigoSortVisitsDescending:       // Visits, low → high
            sort = [NSString stringWithFormat:@"%@ %@", kGetImageOrderVisits, kGetImageOrderDescending];
            break;
            
        case kPiwigoSortManual:                 // Manual order
            // Empty string
            break;

//		case kPiwigoSortVideoOnly:
//			//			sort = NSLocalizedString(@"categorySort_videosOnly", @"Videos Only");
//			break;
//		case kPiwigoSortImageOnly:
//			//			sort = NSLocalizedString(@"categorySort_imagesOnly", @"Images Only");
//			break;
			
		case kPiwigoSortCount:
			break;
	}
	
	self.sortString = sort;
}

-(void)updateImageSort:(kPiwigoSort)imageSort
          OnCompletion:(void (^)(void))completion
{
	NSInteger downloadedImageDataCount = [[CategoriesData sharedInstance] getCategoryById:self.categoryId].imageList.count;
	NSInteger totalImageCount = [[CategoriesData sharedInstance] getCategoryById:self.categoryId].numberOfImages;
	
    NSLog(@"updateImageSort: catId=%ld, downloaded:%ld, total:%ld", (long)self.categoryId, (long)downloadedImageDataCount, (long)totalImageCount);
	if (downloadedImageDataCount >= totalImageCount)
	{	// We have all the image data, just manually sort it (uploaded images are appended to cache)
        self.images = [CategoryImageSort sortImages:[[CategoriesData sharedInstance] getCategoryById:self.categoryId].imageList for:[Model sharedInstance].defaultSort];
		if(completion)
		{
            NSLog(@"updateImageSort: we have all image data i.e. %ld", (long)self.images.count);
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
