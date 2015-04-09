//
//  PhotosFetch.h
//  ftptest
//
//  Created by Spencer Baker on 12/16/14.
//  Copyright (c) 2014 BakerCrew. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^CompletionBlock)(id responseObject);
@class ALAsset;
@class ALAssetsGroup;

@interface PhotosFetch : NSObject

@property (nonatomic, strong) NSArray *assetGroups;
@property (nonatomic, strong) NSArray *sortedImageKeys;

+(PhotosFetch*)sharedInstance;
-(void)getLocalGroupsOnCompletion:(CompletionBlock)completion;
-(NSArray*)getImagesForAssetGroup:(ALAssetsGroup*)assetGroup;
-(ALAsset*)getImageAssetInAlbum:(NSURL*)albumURL withImageName:(NSString*)imageName;
-(NSDictionary*)getImagesInAlbum:(NSURL*)albumURL;

@end
