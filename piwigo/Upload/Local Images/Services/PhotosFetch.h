//
//  PhotosFetch.h
//  ftptest
//
//  Created by Spencer Baker on 12/16/14.
//  Copyright (c) 2014 BakerCrew. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^CompletionBlock)(id responseObject1, id responseObject2);

@class PHAsset;
@class PHAssetCollection;

@interface PhotosFetch : NSObject

@property (nonatomic, strong) NSArray *assetGroups;
@property (nonatomic, strong) NSArray *sortedImageKeys;

+(PhotosFetch*)sharedInstance;
-(void)checkPhotoLibraryAccessForViewController:(UIViewController *)viewController
                             onAuthorizedAccess:(void (^)(void))doWithAccess
                                 onDeniedAccess:(void (^)(void))doWithoutAccess;
-(void)getLocalGroupsOnCompletion:(CompletionBlock)completion;
-(NSArray*)getImagesForAssetGroup:(PHAssetCollection*)assetGroup;

@end
