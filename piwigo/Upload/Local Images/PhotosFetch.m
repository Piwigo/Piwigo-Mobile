//
//  PhotosFetch.m
//
//  Created by Spencer Baker on 12/16/14.
//  Copyright (c) 2014 BakerCrew. All rights reserved.
//

#import <Photos/Photos.h>
#import <UIKit/UIKit.h>

#import "PhotosFetch.h"
#import "Model.h"

@interface PhotosFetch()

@property (nonatomic, strong) PHPhotoLibrary *library;
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
    // Check autorisation to access Photo Library
    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
    if (status != PHAuthorizationStatusAuthorized && status != PHAuthorizationStatusNotDetermined) {

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
    
    // Collect smart albums created in the Photos app i.e. Camera Roll, Favorites, Recently Deleted, Panoramas, etc.
    PHFetchResult *smartAlbums = [PHAssetCollection
                                  fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum
                                  subtype:PHAssetCollectionSubtypeAlbumRegular options:nil];
    
    // Collect albums synced to the device from iPhoto
    PHFetchResult *syncedAlbums = [PHAssetCollection
                                   fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum
                                   subtype:PHAssetCollectionSubtypeAlbumSyncedAlbum options:nil];
    
    // Collect collections from the root of the photo library’s hierarchy of user-created albums and folders
    PHFetchResult *userCollections = [PHCollectionList fetchTopLevelUserCollectionsWithOptions:nil];

    // Combine album collections
    NSArray *collectionsFetchResults = @[smartAlbums, userCollections, syncedAlbums];

    // Add each PHFetchResult to the array
    NSMutableArray *groupAssets = [NSMutableArray new];
    for (int i = 0; i < collectionsFetchResults.count; i ++) {

        PHFetchResult *fetchResult = collectionsFetchResults[i];

        // Keep only non-empty albums
        for (int x = 0; x < fetchResult.count; x ++) {
            PHAssetCollection *collection = fetchResult[x];
            if ([[PHAsset fetchAssetsInAssetCollection:collection options:nil] count] > 0) {
                [groupAssets addObject:collection];
            }
        }
    }
    
    // Sort albums by title
    NSArray *sortedAlbums = [groupAssets
                             sortedArrayUsingComparator:^NSComparisonResult(PHAssetCollection *obj1, PHAssetCollection *obj2) {
        return [obj1.localizedTitle compare:obj2.localizedTitle] != NSOrderedAscending;
    }];

    // Return result
    if (!sortedAlbums) {
        if (completion) {
            completion(nil);
        }
    } else {
        if (completion) {
            completion(sortedAlbums);
        }
    }
}

-(NSArray*)getImagesForAssetGroup:(PHAssetCollection*)assetGroup
{
	NSMutableArray *imageAssets = [NSMutableArray new];
	
    PHFetchResult *imagesInCollection = [PHAsset fetchAssetsInAssetCollection:assetGroup options:nil];
    [imagesInCollection enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if(!obj) {
            return;
        }
        [imageAssets addObject:obj];
    }];
	
	return imageAssets;
}

@end
