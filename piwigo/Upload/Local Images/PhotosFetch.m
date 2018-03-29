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
    if (status != PHAuthorizationStatusAuthorized) {

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
                        completion(@(-1),@(-1));
                    }
                }];
        
        [alert addAction:defaultAction];
        [topViewController presentViewController:alert animated:YES completion:nil];        
	}
    
    // Collect all smart albums created in the Photos app
    // i.e. Camera Roll, Favorites, Recently Deleted, Panoramas, etc.
    PHFetchResult *smartAlbums = [PHAssetCollection
                                  fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum
                                  subtype:PHAssetCollectionSubtypeAny options:nil];
    
    // Collect albums created in Photos
    PHFetchResult *regularAlbums = [PHAssetCollection
                                    fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum
                                    subtype:PHAssetCollectionSubtypeAlbumRegular options:nil];
    
    // Collect albums synced to the device from iPhoto
    PHFetchResult *syncedAlbums = [PHAssetCollection
                                   fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum
                                   subtype:PHAssetCollectionSubtypeAlbumSyncedAlbum options:nil];
    
    // Collect albums imported from a camera or external storage
    PHFetchResult *importedAlbums = [PHAssetCollection
                                     fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum
                                     subtype:PHAssetCollectionSubtypeAlbumImported options:nil];
    
    // Collect user’s personal iCloud Photo Stream album
    PHFetchResult *iCloudStreamAlbums = [PHAssetCollection
                                     fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum
                                     subtype:PHAssetCollectionSubtypeAlbumMyPhotoStream options:nil];
    
    // Collect iCloud Shared Photo Stream albums.
    PHFetchResult *iCloudSharedAlbums = [PHAssetCollection
                                         fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum
                                         subtype:PHAssetCollectionSubtypeAlbumCloudShared options:nil];
    
    // Combine local album collections
    NSArray<PHFetchResult *> *localCollectionsFetchResults = @[smartAlbums, regularAlbums, syncedAlbums, importedAlbums];

    // Combine iCloud album collections
    NSArray<PHFetchResult *> *iCloudCollectionsFetchResults = @[iCloudStreamAlbums, iCloudSharedAlbums];

    // Add each PHFetchResult to the array
    NSMutableArray *localGroupAssets = [NSMutableArray new];
    NSMutableArray *iCloudGroupAssets = [NSMutableArray new];
    PHFetchResult *fetchResult;
    PHAssetCollection *collection;
    PHFetchResult<PHAsset *> *fetchAssets;
    for (int i = 0; i < localCollectionsFetchResults.count; i ++) {

        // Check each fetch result
        fetchResult = localCollectionsFetchResults[i];

        // Keep only non-empty albums
        for (int x = 0; x < fetchResult.count; x++) {
            collection = fetchResult[x];
            fetchAssets = [PHAsset fetchAssetsInAssetCollection:collection options:nil];
            if ([fetchAssets count] > 0) [localGroupAssets addObject:collection];
        }
    }
    for (int i = 0; i < iCloudCollectionsFetchResults.count; i ++) {
        
        // Check each fetch result
        fetchResult = iCloudCollectionsFetchResults[i];
        
        // Keep only non-empty albums
        for (int x = 0; x < fetchResult.count; x++) {
            collection = fetchResult[x];
            fetchAssets = [PHAsset fetchAssetsInAssetCollection:collection options:nil];
            if ([fetchAssets count] > 0) [iCloudGroupAssets addObject:collection];
        }
    }

    // Sort albums by title
    NSArray *localSortedAlbums = [localGroupAssets
                sortedArrayUsingComparator:^NSComparisonResult(PHAssetCollection *obj1, PHAssetCollection *obj2) {
        return [obj1.localizedTitle compare:obj2.localizedTitle] != NSOrderedAscending;
    }];
    NSArray *iCloudSortedAlbums = [iCloudGroupAssets
                sortedArrayUsingComparator:^NSComparisonResult(PHAssetCollection *obj1, PHAssetCollection *obj2) {
                                      return [obj1.localizedTitle compare:obj2.localizedTitle] != NSOrderedAscending;
                                  }];

    // Return result
    if (!localSortedAlbums) {       // Should never happen
        if (completion) {
            completion(nil, nil);
        }
    } else {
        if (completion) {
            completion(localSortedAlbums, iCloudSortedAlbums);
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

        // Append image
        [imageAssets addObject:obj];
    }];
	
	return imageAssets;
}

@end
