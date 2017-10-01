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
	ALAuthorizationStatus status = [ALAssetsLibrary authorizationStatus];
	if (status != ALAuthorizationStatusAuthorized && status != ALAuthorizationStatusNotDetermined) {

        // Determine the present view controller
        UIViewController *topViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
        while (topViewController.presentedViewController) {
            topViewController = topViewController.presentedViewController;
        }
        
        UIAlertController* alert = [UIAlertController
                alertControllerWithTitle:NSLocalizedString(@"localAlbums_photosNotAuthorized_title", @"No Access")
                message:NSLocalizedString(@"localAlbums_photosNotAuthorized_msg", @"tell user to change settings, how")
                preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction* defaultAction = [UIAlertAction
                actionWithTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
                style:UIAlertActionStyleDefault
                handler:^(UIAlertAction * action) {
                    if(completion)
                    {
                        completion(@(-1));
                    }
                }];
        
        [alert addAction:defaultAction];
        [topViewController presentViewController:alert animated:YES completion:nil];        
	}
	
	NSMutableArray *groupAssets = [NSMutableArray new];
	
	ALAssetsLibrary *assetsLibrary = [Model defaultAssetsLibrary];
	[assetsLibrary enumerateGroupsWithTypes:(ALAssetsGroupSavedPhotos | ALAssetsGroupAlbum | ALAssetsGroupEvent | ALAssetsGroupFaces)
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
									 MyLog(@"error: %@", error);
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

@end
