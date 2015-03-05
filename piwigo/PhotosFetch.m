//
//  PhotosFetch.m
//  ftptest
//
//  Created by Spencer Baker on 12/16/14.
//  Copyright (c) 2014 BakerCrew. All rights reserved.
//

#import "PhotosFetch.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <UIKit/UIKit.h>
#import "Model.h"

@interface PhotosFetch()

@property (nonatomic, strong) ALAssetsLibrary *library;
@property (nonatomic, strong) NSDictionary *imageDictionary;
@property (nonatomic, strong) NSMutableDictionary *mutableDictionary;

@property (nonatomic, assign) NSInteger count;

@end

@implementation PhotosFetch

+(PhotosFetch*)sharedInstance
{
	static PhotosFetch *instance = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		instance = [[self alloc] init];
		
	});
	return instance;
}

-(void)updateLocalPhotosDictionary:(CompletionBlock)completion
{
	self.mutableDictionary = [NSMutableDictionary new];
	ALAssetsLibrary *assetsLibrary = [Model defaultAssetsLibrary];
	[assetsLibrary enumerateGroupsWithTypes:ALAssetsGroupAll
								 usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
								 if (nil != group) {
//									 [group setAssetsFilter:[ALAssetsFilter allPhotos]];
									 NSString *groupName = [group valueForProperty:ALAssetsGroupPropertyName];
									 if([groupName isEqualToString:@"Camera Roll"])
									 {
										 NSInteger size = [group numberOfAssets];
										 
										 [group enumerateAssetsUsingBlock:^(ALAsset *result, NSUInteger index, BOOL *stop) {
											 if (nil != result)
											 {
												 [self.mutableDictionary setObject:result forKey:[[result defaultRepresentation] filename]];
												 if(self.mutableDictionary.count == size)
												 {
													 *stop = YES;
													 self.localImages = self.mutableDictionary;
													 self.sortedImageKeys = [self.localImages.allKeys sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
													 if(completion)
													 {
														 completion(self.localImages);
													 }
												 }
											 }
										 }];
									 }
								 }
								 *stop = NO;
							 } failureBlock:^(NSError *error) {
								 NSLog(@"error: %@", error);
							 }];
}

-(ALAsset*)getImageAssetForImageName:(NSString*)imageName
{
	return [self.localImages objectForKey:imageName];
}

@end
