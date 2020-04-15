//
//  PhotosFetch.m
//
//  Created by Spencer Baker on 12/16/14.
//  Copyright (c) 2014 BakerCrew. All rights reserved.
//

#import <Photos/Photos.h>
#import <UIKit/UIKit.h>

#import "Model.h"
#import "PhotosFetch.h"

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
    alert.view.tintColor = UIColor.piwigoColorOrange;
    if (@available(iOS 13.0, *)) {
        alert.overrideUserInterfaceStyle = [Model sharedInstance].isDarkPaletteActive ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    } else {
        // Fallback on earlier versions
    }
    [viewController presentViewController:alert animated:YES completion:^{
        // Bugfix: iOS9 - Tint not fully Applied without Reapplying
        alert.view.tintColor = UIColor.piwigoColorOrange;
    }];
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
    alert.view.tintColor = UIColor.piwigoColorOrange;
    if (@available(iOS 13.0, *)) {
        alert.overrideUserInterfaceStyle = [Model sharedInstance].isDarkPaletteActive ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    } else {
        // Fallback on earlier versions
    }
    [viewController presentViewController:alert animated:YES completion:^{
        // Bugfix: iOS9 - Tint not fully Applied without Reapplying
        alert.view.tintColor = UIColor.piwigoColorOrange;
    }];
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

+(NSString*)getNameForSortType:(kPiwigoSortBy)sortType
{
    NSString *name = @"";
    
    switch(sortType)
    {
        case kPiwigoSortByNewest:
            name = NSLocalizedString(@"categorySort_dateCreatedDescending", @"Date Created, new → old");
            break;
        case kPiwigoSortByOldest:
            name = NSLocalizedString(@"categorySort_dateCreatedAscending", @"Date Created, old → new");
            break;
            
        default:
            name = NSLocalizedString(@"localImageSort_undefined", @"Undefined");
            break;
    }
    
    return name;
}

+(PHFetchResult *)getMomentCollectionsWithSortType:(kPiwigoSortBy)sortType
{
    // Retrieve imageAssets
    PHFetchOptions *fetchOptions = [PHFetchOptions new];
    switch (sortType) {
        case kPiwigoSortByNewest:
            fetchOptions.sortDescriptors = @[
                                             [NSSortDescriptor sortDescriptorWithKey:@"startDate"
                                                                           ascending:NO],
                                             ];
            break;
            
        case kPiwigoSortByOldest:
            fetchOptions.sortDescriptors = @[
                                             [NSSortDescriptor sortDescriptorWithKey:@"startDate"
                                                                           ascending:YES],
                                             ];
            break;
            
        default:
            fetchOptions = nil;
            break;
    }

    // Retrieve imageAssets
    return [PHAssetCollection
            fetchAssetCollectionsWithType:PHAssetCollectionTypeMoment
            subtype:PHAssetCollectionSubtypeSmartAlbumUserLibrary options:fetchOptions];
}

-(NSArray<NSArray<PHAsset *> *> *)getImagesOfAlbumCollection:(PHAssetCollection*)imageCollection
                                                withSortType:(kPiwigoSortBy)sortType
{
    PHFetchOptions *fetchOptions = [PHFetchOptions new];
    switch (sortType) {
        case kPiwigoSortByNewest:
            fetchOptions.sortDescriptors = @[
                                             [NSSortDescriptor sortDescriptorWithKey:@"creationDate"
                                                                           ascending:NO],
                                             ];
            break;
            
        case kPiwigoSortByOldest:
            fetchOptions.sortDescriptors = @[
                                             [NSSortDescriptor sortDescriptorWithKey:@"creationDate"
                                                                           ascending:YES],
                                             ];
            break;
            
        default:
            fetchOptions = nil;
            break;
    }
    
    // Retrieve imageAssets
    PHFetchResult<PHAsset *> *imagesInCollection = [PHAsset fetchAssetsInAssetCollection:imageCollection options:fetchOptions];
    
    // Sort images by day
    return [SplitLocalImages splitImagesByDate:imagesInCollection];
}

-(NSArray<NSArray<PHAsset *> *> *)getImagesOfMomentCollections:(PHFetchResult *)imageCollections
{
    // Fetch sort option
    PHFetchOptions *fetchOptions = [PHFetchOptions new];
    fetchOptions.sortDescriptors = @[
                                     [NSSortDescriptor sortDescriptorWithKey:@"creationDate"
                                                                   ascending:YES],
                                     ];

    // Build array of images split in moments
    NSMutableArray *images = [NSMutableArray new];
    for (PHAssetCollection *sectionCollection in imageCollections) {
        // Retrieve imageAssets
        [images addObject:[PHAsset fetchAssetsInAssetCollection:sectionCollection options:fetchOptions]];
    }
    return images;
}

-(NSString *)getFileNameFomImageAsset:(PHAsset *)imageAsset
{
    NSString *fileName = @"";
    if (imageAsset)
    {
        // Get file name from image asset
        if (@available(iOS 9, *))
        {
            NSArray *resources = [PHAssetResource assetResourcesForAsset:imageAsset];
            if ([resources count] > 0) {
                for (PHAssetResource *resource in resources) {
//                    NSLog(@"=> PHAssetResourceType = %ld — %@", resource.type, resource.originalFilename);
                    if (resource.type == PHAssetResourceTypeAdjustmentData) {
                        continue;
                    }
                    fileName = [resource originalFilename];
                    if ((resource.type == PHAssetResourceTypePhoto) ||
                        (resource.type == PHAssetResourceTypeVideo) ||
                        (resource.type == PHAssetResourceTypeAudio) )  {
                        // We preferably select the original filename
                        break;
                    }
                }
            }
        }
        
        // If no filename…
        if (fileName.length == 0)
        {
            // No filename => Build filename from creation date
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            [dateFormatter setDateFormat:@"yyyyMMdd-HHmmssSSSS"];
            fileName = [dateFormatter stringFromDate:[imageAsset creationDate]];

            // Filename extension required by Piwigo so that it knows how to deal with it
            if (imageAsset.mediaType == PHAssetMediaTypeImage) {
                // Adopt JPEG photo format by default, will be rechecked
                fileName = [fileName stringByAppendingPathExtension:@"jpg"];
            } else if (imageAsset.mediaType == PHAssetMediaTypeVideo) {
                // Videos are exported in MP4 format
                fileName = [fileName stringByAppendingPathExtension:@"mp4"];
            } else if (imageAsset.mediaType == PHAssetMediaTypeAudio) {
                // Arbitrary extension, not managed yet
                fileName = [fileName stringByAppendingPathExtension:@"m4a"];
            }
        }
    }
    
//    NSLog(@"=> filename = %@", fileName);
    return fileName;
}

@end
