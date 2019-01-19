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

-(void)checkPhotoLibraryAccessForViewController:(UIViewController *)viewController
                             onAuthorizedAccess:(void (^)(void))doWithAccess
                                 onDeniedAccess:(void (^)(void))doWithoutAccess
{
    // Check autorisation to access Photo Library
    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
    switch (status) {
        case PHAuthorizationStatusNotDetermined:
        {
            // Request authorization to access photos
            [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
                // Create "Photos access" in Settings app for Piwigo, return user's choice
                switch (status) {
                    case PHAuthorizationStatusRestricted:
                    {
                        // Inform user that he/she cannot access the Photo library
                        if (viewController) {
                            if ([NSThread isMainThread]) {
                                [self showPhotosLibraryAccessRestrictedInViewController:viewController];
                            }
                            else{
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    [self showPhotosLibraryAccessRestrictedInViewController:viewController];
                                });
                            }
                        }
                        // Exceute next steps
                        if (doWithoutAccess) doWithoutAccess();
                        break;
                    }
                    case PHAuthorizationStatusDenied:
                    {
                        // Invite user to provide access to the Photo library
                        if (viewController) {
                            if ([NSThread isMainThread]) {
                                [self requestPhotoLibraryAccessInViewController:viewController];
                            }
                            else{
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    [self requestPhotoLibraryAccessInViewController:viewController];
                                });
                            }
                        }
                        // Exceute next steps
                        if (doWithoutAccess) doWithoutAccess();
                        break;
                    }
                    default:
                    {
                        // Access Photo Library
                        if (doWithAccess) {
                            // Retry as this should be fine
                            if ([NSThread isMainThread]) {
                                doWithAccess();
                            }
                            else{
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    doWithAccess();
                                });
                            }
                        }
                        break;
                    }
                }
            }];
            break;
        }
            
        case PHAuthorizationStatusRestricted:
        {
            // Inform user that he/she cannot access the Photo library
            if (viewController) {
                if ([NSThread isMainThread]) {
                    [self showPhotosLibraryAccessRestrictedInViewController:viewController];
                }
                else{
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self showPhotosLibraryAccessRestrictedInViewController:viewController];
                    });
                }
            }
            // Exceute next steps
            if (doWithoutAccess) doWithoutAccess();
            break;
        }
            
        case PHAuthorizationStatusDenied:
        {
            // Invite user to provide access to the Photo library
            if (viewController) {
                if ([NSThread isMainThread]) {
                    [self requestPhotoLibraryAccessInViewController:viewController];
                }
                else{
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self requestPhotoLibraryAccessInViewController:viewController];
                    });
                }
            }
            // Exceute next steps
            if (doWithoutAccess) doWithoutAccess();
            break;
        }
            
        default:
        {
            // Access Photo Library
            if (doWithAccess) {
                // Retry as this should be fine
                if ([NSThread isMainThread]) {
                    doWithAccess();
                }
                else{
                    dispatch_async(dispatch_get_main_queue(), ^{
                        doWithAccess();
                    });
                }
            }
            break;
        }
    }
}

-(void)requestPhotoLibraryAccessInViewController:(UIViewController *)viewController
{
    // Invite user to provide access to photos
    UIAlertController* alert = [UIAlertController
        alertControllerWithTitle:NSLocalizedString(@"localAlbums_photosNotAuthorized_title", @"No Access")
        message:NSLocalizedString(@"localAlbums_photosNotAuthorized_msg", @"tell user to change settings, how")
        preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* cancelAction = [UIAlertAction
        actionWithTitle:NSLocalizedString(@"alertCancelButton", @"Cancel")
        style:UIAlertActionStyleDestructive
        handler:^(UIAlertAction * action) { }];
    
    UIAlertAction* prefsAction = [UIAlertAction
        actionWithTitle:NSLocalizedString(@"alertOkButton", @"OK")
        style:UIAlertActionStyleDefault
        handler:^(UIAlertAction * action) {
            // Redirect user to Settings app
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
        }];
    
    // Add actions
    [alert addAction:cancelAction];
    [alert addAction:prefsAction];
    
    // Present list of actions
    [viewController presentViewController:alert animated:YES completion:nil];
}

-(void)showPhotosLibraryAccessRestrictedInViewController:(UIViewController *)viewController
{
    UIAlertController* alert = [UIAlertController
                                alertControllerWithTitle:NSLocalizedString(@"localAlbums_photosNiltitle", @"Problem Reading Photos")
                                message:NSLocalizedString(@"localAlbums_photosNnil_msg", @"There is a problem reading your local photo library.")
                                preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* dismissAction = [UIAlertAction
                                    actionWithTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
                                    style:UIAlertActionStyleCancel
                                    handler:^(UIAlertAction * action) { }];
    
    // Present alert
    [alert addAction:dismissAction];
    [viewController presentViewController:alert animated:YES completion:nil];
}

-(void)getLocalGroupsOnCompletion:(CompletionBlock)completion
{
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
