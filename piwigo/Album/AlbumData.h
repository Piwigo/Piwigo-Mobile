//
//  AlbumData.h
//  piwigo
//
//  Created by Spencer Baker on 4/2/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
    kPiwigoSortObjcNameAscending,               // Photo title, A → Z
    kPiwigoSortObjcNameDescending,              // Photo title, Z → A
    
    kPiwigoSortObjcDateCreatedDescending,       // Date created, new → old
    kPiwigoSortObjcDateCreatedAscending,        // Date created, old → new
    
    kPiwigoSortObjcDatePostedDescending,        // Date posted, new → old
    kPiwigoSortObjcDatePostedAscending,         // Date posted, old → new
    
    kPiwigoSortObjcFileNameAscending,           // File name, A → Z
    kPiwigoSortObjcFileNameDescending,          // File name, Z → A
    
    kPiwigoSortObjcRatingScoreDescending,       // Rating score, high → low
    kPiwigoSortObjcRatingScoreAscending,        // Rating score, low → high

    kPiwigoSortObjcVisitsDescending,            // Visits, high → low
    kPiwigoSortObjcVisitsAscending,             // Visits, low → high

    kPiwigoSortObjcManual,                      // Manual order
    kPiwigoSortObjcRandom,                      // Random order
//    kPiwigoSortObjcVideoOnly,
//    kPiwigoSortObjcImageOnly,
    
    kPiwigoSortObjcCount
} kPiwigoSortObjc;

@class PiwigoImageData;

@interface AlbumData : NSObject

@property (nonatomic, strong) NSArray<PiwigoImageData *> *images;
@property (nonatomic, strong) NSString *searchQuery;

-(instancetype)initWithCategoryId:(NSInteger)categoryId andQuery:(NSString *)query;

-(void)reloadAlbumOnCompletion:(void (^)(void))completion
                     onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail;
-(void)loadMoreImagesOnCompletion:(void (^)(BOOL hasNewImages))completion
                        onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail;
-(void)loadAllImagesOnCompletion:(void (^)(void))completion
                       onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail;

-(void)updateImageSort:(kPiwigoSortObjc)imageSort
          onCompletion:(void (^)(void))completion
             onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail;

-(NSInteger)updateImage:(PiwigoImageData *)updatedImage;

-(void)removeImage:(PiwigoImageData*)image;
-(void)removeImageWithId:(NSInteger)imageId;

@end
