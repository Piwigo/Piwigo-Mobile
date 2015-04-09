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

-(void)getLocalGroupsOnCompletion:(CompletionBlock)completion
{
	NSMutableArray *groupAssets = [NSMutableArray new];
	
	ALAssetsLibrary *assetsLibrary = [Model defaultAssetsLibrary];
	[assetsLibrary enumerateGroupsWithTypes:ALAssetsGroupAll
								 usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
									 if(!group)
									 {
										 *stop = YES;
										 if(completion)
										 {
											 completion(groupAssets);
										 }
										 return;
									 }
									 
									 [groupAssets addObject:group];
									 
								 } failureBlock:^(NSError *error) {
									 NSLog(@"error: %@", error);
									 
									 // @TODO: display an alert here... fix this one
									 if ([ALAssetsLibrary authorizationStatus] == ALAuthorizationStatusDenied) {
										 NSString *errorMessage = NSLocalizedString(@"This app does not have access to your photos or videos. You can enable access in Privacy Settings.", nil);
										 [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Access Denied", nil) message:errorMessage delegate:nil cancelButtonTitle:NSLocalizedString(@"Ok", nil) otherButtonTitles:nil] show];
										 
									 } else {
										 NSString *errorMessage = [NSString stringWithFormat:@"Album Error: %@ - %@", [error localizedDescription], [error localizedRecoverySuggestion]];
										 [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error", nil) message:errorMessage delegate:nil cancelButtonTitle:NSLocalizedString(@"Ok", nil) otherButtonTitles:nil] show];
									 }
									 
									 if(completion)
									 {
										 completion(nil);
									 }
								 }];
}

-(NSArray*)getImagesForAssetGroup:(ALAssetsGroup*)assetGroup
{
	NSMutableArray *imageAssets = [NSMutableArray new];
	
	[assetGroup enumerateAssetsUsingBlock:^(ALAsset *result, NSUInteger index, BOOL *stop) {
		if(!result)
		{
			return;
		}
		
		[imageAssets addObject:result];
		
	}];
	
	return imageAssets;
}

-(ALAsset*)getImageAssetInAlbum:(NSURL*)albumURL withImageName:(NSString*)imageName
{
	// @TODO: fix this!
	return nil;
//	return [[self.assetGroups objectForKey:albumURL] objectForKey:imageName];
}

-(NSDictionary*)getImagesInAlbum:(NSURL*)albumURL
{
	// @TODO: fix this!
	return nil;
//	return [self.assetGroups objectForKey:albumURL];
}

@end
