//
//  AlbumData.h
//  piwigo
//
//  Created by Spencer Baker on 4/2/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CategorySortViewController.h"

@class PiwigoImageData;

@interface AlbumData : NSObject

@property (nonatomic, readonly) NSArray *images;
@property (nonatomic, strong) NSString *searchQuery;

-(instancetype)initWithCategoryId:(NSInteger)categoryId andQuery:(NSString *)query;

-(void)loadMoreImagesOnCompletion:(void (^)(void))completion;
-(void)updateImageSort:(kPiwigoSortCategory)imageSort OnCompletion:(void (^)(void))completion;
-(void)loadAllImagesOnCompletion:(void (^)(void))completion;
-(void)removeImage:(PiwigoImageData*)image;
-(void)removeImageWithId:(NSInteger)imageId;
-(void)reloadAlbumOnCompletion:(void (^)(void))completion;

@end
