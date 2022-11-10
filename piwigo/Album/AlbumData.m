//
//  AlbumData.m
//  piwigo
//
//  Created by Spencer Baker on 4/2/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "AlbumData.h"
#import "PiwigoAlbumData.h"
#import "CategoriesData.h"

@interface AlbumData()

@property (nonatomic, assign) NSInteger categoryId;
@property (nonatomic, assign) kPiwigoSortObjc sortType;

@end

@implementation AlbumData

#pragma mark - Initialisation

-(instancetype)initWithCategoryId:(NSInteger)categoryId andQuery:(NSString *)query
{
	self = [super init];
	if(self)
	{
        self.searchQuery = [NSString stringWithString:query];
		self.categoryId = categoryId;
		self.sortType = (kPiwigoSortObjc)2;
                
        // Create empty album in cache if necessary
        if ([[CategoriesData sharedInstance] getCategoryById:categoryId] == nil) {
            PiwigoAlbumData *albumData = [[PiwigoAlbumData alloc] initWithId:categoryId andQuery:query];
            [[CategoriesData sharedInstance] updateCategories:@[albumData]];
        }
        
        // Is image data already in cache?
        NSMutableArray<PiwigoImageData *> *imageList = [NSMutableArray<PiwigoImageData *> new];
        PiwigoAlbumData *album = [[CategoriesData sharedInstance] getCategoryById:categoryId];

        // Do we have images in cache?
        if (album.imageList != nil) {
            // Retrieve images in cache
            [imageList addObjectsFromArray:album.imageList];
        }
        
        // Complete image list if necessary
        if (album.numberOfImages < NSNotFound) {
            for (NSInteger i = album.imageList.count; i < album.numberOfImages; i++) {
                PiwigoImageData *imageData = [PiwigoImageData new];
                imageData.imageId = NSNotFound;
                [imageList addObject:imageData];
            }
        }
        
        // Store images (both dummy and real)
        self.images = [NSArray<PiwigoImageData *> arrayWithArray:imageList];
	}
	return self;
}


#pragma mark - Load image data

-(void)reloadAlbumOnCompletion:(void (^)(void))completion
                     onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
    NSInteger currentPage = [[CategoriesData sharedInstance] getCategoryById:self.categoryId].onPage;
    [[[CategoriesData sharedInstance] getCategoryById:self.categoryId] resetData];
    
    [self loadImagePageUntil:currentPage onPage:0
                onCompletion:completion
                   onFailure:^(NSURLSessionTask *task, NSError *error) {
        if (fail) {
            fail(task, error);
        }
    }];
}

-(void)loadImagePageUntil:(NSInteger)page onPage:(NSInteger)onPage
             onCompletion:(void (^)(void))completion
                onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
    if((onPage != 0) && (onPage >= page))
    {
        if (completion) { completion(); }
        return;
    }
    
    [self loadMoreImagesOnCompletion:^(BOOL hasNewImages){
        [self loadImagePageUntil:page onPage:onPage + 1
                    onCompletion:completion
                       onFailure:^(NSURLSessionTask *task, NSError *error) {
            if (fail) {
                fail(task, error);
            }
        }];
    } onFailure:^(NSURLSessionTask *task, NSError *error) {
        if (fail) {
            fail(task, error);
        }
    }];
}

-(void)loadMoreImagesOnCompletion:(void (^)(BOOL done))completion
                        onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
	NSInteger downloadedImageDataCount = [[CategoriesData sharedInstance] getCategoryById:self.categoryId].imageList.count;
	NSInteger totalImageCount = [[CategoriesData sharedInstance] getCategoryById:self.categoryId].numberOfImages;
	
    // Return if job done
    if ((totalImageCount != NSNotFound) && (downloadedImageDataCount >= totalImageCount))
	{
        NSLog(@"loadMoreImagesOnCompletion: we have all image data");
        // We have all the image data in cache)
        self.images = [[CategoriesData sharedInstance] getCategoryById:self.categoryId].imageList;
		if (completion) { completion(NO); }
		return;
	}
    
    // Set sort string parameter from sort type
    NSString *sortDesc = @"date_creation asc";
	
    // Load more category image data
	[[[CategoriesData sharedInstance] getCategoryById:self.categoryId]
                   loadCategoryImageDataChunkWithSort:sortDesc forProgress:nil
                                         onCompletion:^(BOOL completed)
    {
		if (!completed) {
            if (completion) { completion(NO); }
            return;
        }
        
        // We have new image data, append them to cache and complete list with unknowns
        NSMutableArray<PiwigoImageData *> *images = [[[CategoriesData sharedInstance] getCategoryById:self.categoryId].imageList mutableCopy];
        NSInteger downloadedImageDataCount = [[CategoriesData sharedInstance] getCategoryById:self.categoryId].imageList.count;
        NSInteger totalImageCount = [[CategoriesData sharedInstance] getCategoryById:self.categoryId].numberOfImages;
        for (NSInteger i = downloadedImageDataCount; i < totalImageCount; i++) {
            [images addObject:[PiwigoImageData new]];
        }
        self.images = [NSArray arrayWithArray:images];
		if (completion) { completion(YES); }
    }
     onFailure:^(NSURLSessionTask *task, NSError *error) {
        if (fail) {
            fail(task, error);
        }
    }];
}

-(void)loadAllImagesOnCompletion:(void (^)(void))completion
                       onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
    [[[CategoriesData sharedInstance] getCategoryById:self.categoryId]
                     loadAllCategoryImageDataWithSort:self.sortType forProgress:nil
                                         onCompletion:^(BOOL completed) {
         if (completed) {
            self.images = [[CategoriesData sharedInstance] getCategoryById:self.categoryId].imageList;
            if(completion) {
                completion();
            }
         }
    } onFailure:^(NSURLSessionTask *task, NSError *error) {
        if (fail) {
            fail(task, error);
        }
    }];
}

-(void)updateImageSort:(kPiwigoSortObjc)imageSort
          onCompletion:(void (^)(void))completion
             onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
	NSInteger downloadedImageDataCount = [[CategoriesData sharedInstance] getCategoryById:self.categoryId].imageList.count;
	NSInteger totalImageCount = [[CategoriesData sharedInstance] getCategoryById:self.categoryId].numberOfImages;
	
    NSLog(@"updateImageSort   => catId=%ld, downloaded:%ld, total:%ld", (long)self.categoryId, (long)downloadedImageDataCount, (long)totalImageCount);
	if ((totalImageCount != NSNotFound) && (downloadedImageDataCount >= totalImageCount))
	{	// We have all the image data in cache)
        self.images = [[CategoriesData sharedInstance] getCategoryById:self.categoryId].imageList;
		if (completion)
		{
            NSLog(@"updateImageSort   => We have all image data i.e. %ld", (long)self.images.count);
            completion();
		}
		return;
	}
	
    self.sortType = imageSort;
    [self loadMoreImagesOnCompletion:^(BOOL hasNewImages) {
        if (completion) {
            completion();
        }
    } onFailure:^(NSURLSessionTask *task, NSError *error) {
        if (fail) {
            fail(task, error);
        }
    }];
}


#pragma mark - Update images

-(NSInteger)updateImage:(PiwigoImageData *)updatedImage
{
    // Anything to do?
    if (updatedImage == nil) return NSNotFound;

    // Determine index of updated image
    NSMutableArray<PiwigoImageData *> *newImages = [[NSMutableArray<PiwigoImageData *> alloc] initWithArray:self.images];
    NSInteger indexOfUpdatedImage = [self.images indexOfObjectPassingTest:^BOOL(PiwigoImageData *image, NSUInteger index, BOOL * _Nonnull stop) {
     return image.imageId == updatedImage.imageId;
    }];

    // Image found?
    if (indexOfUpdatedImage == NSNotFound) { return NSNotFound; }
    
    // Update image data
    [newImages replaceObjectAtIndex:indexOfUpdatedImage withObject:updatedImage];
    self.images = newImages;
    
    // Return index of updated image
    return indexOfUpdatedImage;
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
