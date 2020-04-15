//
//  PhotosFetch.h
//  ftptest
//
//  Created by Spencer Baker on 12/16/14.
//  Copyright (c) 2014 BakerCrew. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
    kPiwigoSortByNewest,
    kPiwigoSortByOldest,
    kPiwigoSortByCount
} kPiwigoSortBy;

typedef void(^CompletionBlock)(id responseObject1, id responseObject2);

@class PHAsset;
@class PHAssetCollection;
@class PHFetchResult;

@interface PhotosFetch : NSObject

@property (nonatomic, strong) NSArray *assetGroups;
@property (nonatomic, strong) NSArray *sortedImageKeys;

+(PhotosFetch *)sharedInstance;
-(void)checkPhotoLibraryAccessForViewController:(UIViewController *)viewController
                             onAuthorizedAccess:(void (^)(void))doWithAccess
                                 onDeniedAccess:(void (^)(void))doWithoutAccess;
-(void)getLocalGroupsOnCompletion:(CompletionBlock)completion;

+(NSString *)getNameForSortType:(kPiwigoSortBy)sortType;
+(PHFetchResult *)getMomentCollectionsWithSortType:(kPiwigoSortBy)sortType;
-(NSArray<NSArray<PHAsset *> *> *)getImagesOfAlbumCollection:(PHAssetCollection*)imageCollection
                                                withSortType:(kPiwigoSortBy)sortType;
-(NSArray<NSArray<PHAsset *> *> *)getImagesOfMomentCollections:(PHFetchResult *)imageCollections;
-(NSString *)getFileNameFomImageAsset:(PHAsset *)imageAsset;

@end
