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

-(instancetype)initWithCategoryId:(NSInteger)categoryId;
-(void)loadMoreImagesOnCompletion:(void (^)())completion;
-(void)updateImageSort:(kPiwigoSortCategory)imageSort OnCompletion:(void (^)())completion;
-(void)loadAllImagesOnCompletion:(void (^)())completion;
-(void)removeImage:(PiwigoImageData*)image;
-(void)removeImageWithId:(NSInteger)imageId;
-(void)reloadAlbumOnCompletion:(void (^)())completion;

@end
