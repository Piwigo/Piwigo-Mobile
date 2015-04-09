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
	NSMutableDictionary *allImages = [NSMutableDictionary new];
	
	ALAssetsLibrary *assetsLibrary = [Model defaultAssetsLibrary];
	[assetsLibrary enumerateGroupsWithTypes:ALAssetsGroupAll
								 usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
									 if (group != nil)
									 {
										 NSString *groupURL = [group valueForProperty:ALAssetsGroupPropertyURL];
										 
										 NSMutableDictionary *images = [NSMutableDictionary new];
										 
										 NSInteger size = [group numberOfAssets];
										 [group enumerateAssetsUsingBlock:^(ALAsset *result, NSUInteger index, BOOL *stop) {
											 if (nil != result)
											 {
												 [images setObject:result forKey:[[result defaultRepresentation] filename]];
												 if(images.count == size)
												 {
													 *stop = YES;
													 [allImages setObject:images forKey:groupURL];
												 }
											 }
										 }];
										 *stop = NO;
									 }
									 else
									 {
										 *stop = YES;
										 self.localImages = allImages;
										 if(completion)
										 {
											 completion(self.localImages);
										 }
									 }
								 } failureBlock:^(NSError *error) {
									 MyLog(@"error: %@", error);
									 if(completion)
									 {
										 completion(nil);
									 }
								 }];
}

-(ALAsset*)getImageAssetInAlbum:(NSURL*)albumURL withImageName:(NSString*)imageName
{
	return [[self.localImages objectForKey:albumURL] objectForKey:imageName];
}

-(NSDictionary*)getImagesInAlbum:(NSURL*)albumURL
{
	return [self.localImages objectForKey:albumURL];
}

@end
