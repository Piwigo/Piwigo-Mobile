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

@interface PhotosFetch : NSObject

@property (nonatomic, strong) NSArray *assetGroups;
@property (nonatomic, strong) NSDictionary *localImages;
@property (nonatomic, strong) NSArray *sortedImageKeys;

+(PhotosFetch*)sharedInstance;
-(void)updateLocalPhotosDictionary:(CompletionBlock)completion;
-(ALAsset*)getImageAssetInAlbum:(NSString*)albumURL withImageName:(NSString*)imageName;
-(NSDictionary*)getImagesInAlbum:(NSString*)albumURL;

@end
