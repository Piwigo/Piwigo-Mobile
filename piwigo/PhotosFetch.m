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

-(void)getLocalPhotosDictionary:(CompletionBlock)completion
{
	self.mutableDictionary = [NSMutableDictionary new];
	ALAssetsLibrary *assetsLibrary = [Model defaultAssetsLibrary];
	[assetsLibrary enumerateGroupsWithTypes:ALAssetsGroupSavedPhotos
								 usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
								 if (nil != group) {
									 
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
													 completion(self.mutableDictionary);
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

@end
