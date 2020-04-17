//
//  PhotosFetch.swift
//  piwigo
//
//  Created by Spencer Baker on 12/16/14.
//  Copyright (c) 2014 BakerCrew. All rights reserved.
//
//  Converted to Swift 5.1 by Eddy Lelièvre-Berna on 17/04/2020
//

import Foundation
import Photos
import UIKit

@objc
enum kPiwigoSortBy : Int {
    case newest
    case oldest
}

@objc
class PhotosFetch: NSObject {
    
    // Singleton
    @objc static var instance: PhotosFetch = PhotosFetch()

    @objc
    class func sharedInstance() -> PhotosFetch {
        // `dispatch_once()` call was converted to a static variable initializer
        return instance
    }
    
    @objc
    func checkPhotoLibraryAccessForViewController(_ viewController: UIViewController?,
                                                  onAuthorizedAccess doWithAccess: @escaping () -> Void,
                                                  onDeniedAccess doWithoutAccess: @escaping () -> Void) {
        
        // Check autorisation to access Photo Library
        let status = PHPhotoLibrary.authorizationStatus()
        switch status {
            case .notDetermined:
                // Request authorization to access photos
                PHPhotoLibrary.requestAuthorization({ status in
                    // Create "Photos access" in Settings app for Piwigo, return user's choice
                    switch status {
                        case .restricted:
                            // Inform user that he/she cannot access the Photo library
                            if viewController != nil {
                                if Thread.isMainThread {
                                    self.showPhotosLibraryAccessRestricted(in: viewController)
                                } else {
                                    DispatchQueue.main.async(execute: {
                                        self.showPhotosLibraryAccessRestricted(in: viewController)
                                    })
                                }
                            }
                            // Exceute next steps
                            doWithoutAccess()
                        case .denied:
                            // Invite user to provide access to the Photo library
                            if viewController != nil {
                                if Thread.isMainThread {
                                    self.requestPhotoLibraryAccess(in: viewController)
                                } else {
                                    DispatchQueue.main.async(execute: {
                                        self.requestPhotoLibraryAccess(in: viewController)
                                    })
                                }
                            }
                            // Exceute next steps
                            doWithoutAccess()
                        default:
                            // Retry as this should be fine
                            if Thread.isMainThread {
                                doWithAccess()
                            } else {
                                DispatchQueue.main.async(execute: {
                                    doWithAccess()
                                })
                            }
                    }
                })
            case .restricted:
                // Inform user that he/she cannot access the Photo library
                if viewController != nil {
                    if Thread.isMainThread {
                        showPhotosLibraryAccessRestricted(in: viewController)
                    } else {
                        DispatchQueue.main.async(execute: {
                            self.showPhotosLibraryAccessRestricted(in: viewController)
                        })
                    }
                }
                // Exceute next steps
                doWithoutAccess()
            case .denied:
                // Invite user to provide access to the Photo library
                if viewController != nil {
                    if Thread.isMainThread {
                        requestPhotoLibraryAccess(in: viewController)
                    } else {
                        DispatchQueue.main.async(execute: {
                            self.requestPhotoLibraryAccess(in: viewController)
                        })
                    }
                }
                // Exceute next steps
                doWithoutAccess()
            default:
                // Retry as this should be fine
                if Thread.isMainThread {
                    doWithAccess()
                } else {
                    DispatchQueue.main.async(execute: {
                        doWithAccess()
                    })
                }
        }
    }

    func getLocalGroups(onCompletion completion: (Any?, Any?) -> Void) {
        
        // Collect all smart albums created in the Photos app
        // i.e. Camera Roll, Favorites, Recently Deleted, Panoramas, etc.
        let smartAlbums = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: nil)

        // Collect albums created in Photos
        let regularAlbums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: nil)

        // Collect albums synced to the device from iPhoto
        let syncedAlbums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumSyncedAlbum, options: nil)

        // Collect albums imported from a camera or external storage
        let importedAlbums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumImported, options: nil)

        // Collect user’s personal iCloud Photo Stream album
        let iCloudStreamAlbums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumMyPhotoStream, options: nil)

        // Collect iCloud Shared Photo Stream albums.
        let iCloudSharedAlbums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumCloudShared, options: nil)

        // Combine local album collections
        let localCollectionsFetchResults: [PHFetchResult<PHAssetCollection>] = [smartAlbums, regularAlbums, syncedAlbums, importedAlbums].compactMap { $0 }

        // Combine iCloud album collections
        let iCloudCollectionsFetchResults: [PHFetchResult<PHAssetCollection>] = [iCloudStreamAlbums, iCloudSharedAlbums].compactMap { $0 }

        // Add each PHFetchResult to the array
        var localGroupAssets: [PHAssetCollection] = []
        var iCloudGroupAssets: [PHAssetCollection] = []
        var collection: PHAssetCollection?
        var fetchAssets: PHFetchResult<PHAsset>?
        
        // Loop over local albums
        for fetchResult in localCollectionsFetchResults {
            // Keep only non-empty albums
            for x in 0..<fetchResult.count {
                collection = fetchResult[x]
                if let collection = collection {
                    fetchAssets = PHAsset.fetchAssets(in: collection, options: nil)
                    if fetchAssets?.count ?? 0 > 0 {
                        localGroupAssets.append(collection)
                    }
                }
            }
        }

        // Loop over iCloud albums
        for fetchResult in iCloudCollectionsFetchResults {
            // Keep only non-empty albums
            for x in 0..<fetchResult.count {
                collection = fetchResult[x]
                if let collection = collection {
                    fetchAssets = PHAsset.fetchAssets(in: collection, options: nil)
                    if fetchAssets?.count ?? 0 > 0 {
                        iCloudGroupAssets.append(collection)
                    }
                }
            }
        }

        // Sort albums by title
        let localSortedAlbums = localGroupAssets.sorted(by: { $0.localizedTitle! > $1.localizedTitle! })
        let iCloudSortedAlbums = iCloudGroupAssets.sorted(by: { $0.localizedTitle! > $1.localizedTitle! })

        // Return result
        completion(localSortedAlbums, iCloudSortedAlbums)
    }

    @objc
    func getNameForSortType(_ sortType: kPiwigoSortBy) -> String? {
        var name = ""

        switch sortType {
            case .newest:
                name = NSLocalizedString("categorySort_dateCreatedDescending", comment: "Date Created, new → old")
            case .oldest:
                name = NSLocalizedString("categorySort_dateCreatedAscending", comment: "Date Created, old → new")
        }

        return name
    }

    @objc
    func getMomentCollectionsWithSortType(_ sortType: kPiwigoSortBy) -> PHFetchResult<PHAssetCollection>? {
        // Retrieve imageAssets
        let fetchOptions = PHFetchOptions()
        switch sortType {
            case .newest:
                fetchOptions.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]
            case .oldest:
                fetchOptions.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: true)]
        }

        // Retrieve imageAssets
        return PHAssetCollection.fetchAssetCollections(with: .moment, subtype: .smartAlbumUserLibrary, options: fetchOptions)
    }

    @objc
    func getImagesOfAlbumCollection(_ imageCollection: PHAssetCollection?, withSortType sortType: kPiwigoSortBy) -> [[PHAsset]]? {
        let fetchOptions = PHFetchOptions()
        switch sortType {
            case .newest:
                fetchOptions.sortDescriptors = [
                NSSortDescriptor(key: "creationDate", ascending: false)
                ]
            case .oldest:
                fetchOptions.sortDescriptors = [
                NSSortDescriptor(key: "creationDate", ascending: true)
                ]
        }

        // Retrieve imageAssets
        var imagesInCollection: PHFetchResult<PHAsset>? = nil
        if let imageCollection = imageCollection {
            imagesInCollection = PHAsset.fetchAssets(in: imageCollection, options: fetchOptions)
        }

        // Sort images by day
        return SplitLocalImages.splitImages(byDate: imagesInCollection)
    }

    @objc
    func getImagesOfMomentCollections(_ imageCollections: PHFetchResult<PHAssetCollection>?) -> [[PHAsset]]? {
        // Fetch sort option
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [
            NSSortDescriptor(key: "creationDate", ascending: true)
        ]

        // Build array of images split in moments
        var images: [[PHAsset]]? = []
        guard let imageCollections = imageCollections else {
            return images
        }
        for x in 0..<imageCollections.count {
            // Retrieve collection
            let sectionCollection = imageCollections[x]
            // Retrieve imageAssets
            let imagesOfCollection = PHAsset.fetchAssets(in: sectionCollection, options: fetchOptions)
            // Loop over images of moment
            var imagesOfMoment: [PHAsset]? = []
            imagesOfCollection.enumerateObjects({ imageAsset, idx, stop in
                imagesOfMoment?.append(imageAsset)
            })
            // Append images of moment to main arrray
            if let imagesOfMoment = imagesOfMoment {
                images?.append(imagesOfMoment)
            }
        }

        return images
    }

    @objc
    func getFileNameFomImageAsset(_ imageAsset: PHAsset?) -> String? {
        var fileName = ""
        if imageAsset != nil {
            // Get file name from image asset
            var resources: [PHAssetResource]? = nil
            if let imageAsset = imageAsset {
                resources = PHAssetResource.assetResources(for: imageAsset)
            }
            if (resources?.count ?? 0) > 0 {
                for resource in resources ?? [] {
                    //              NSLog(@"=> PHAssetResourceType = %ld — %@", resource.type, resource.originalFilename);
                    if resource.type == .adjustmentData {
                        continue
                    }
                    fileName = resource.originalFilename
                    if (resource.type == .photo) || (resource.type == .video) || (resource.type == .audio) {
                        // We preferably select the original filename
                        break
                    }
                }
            }

            // If no filename…
            if fileName.count == 0 {
                // No filename => Build filename from creation date
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyyMMdd-HHmmssSSSS"
                if let creation = imageAsset?.creationDate {
                    fileName = dateFormatter.string(from: creation)
                }

                // Filename extension required by Piwigo so that it knows how to deal with it
                if imageAsset?.mediaType == .image {
                    // Adopt JPEG photo format by default, will be rechecked
                    fileName = URL(fileURLWithPath: fileName).appendingPathExtension("jpg").absoluteString
                } else if imageAsset?.mediaType == .video {
                    // Videos are exported in MP4 format
                    fileName = URL(fileURLWithPath: fileName).appendingPathExtension("mp4").absoluteString
                } else if imageAsset?.mediaType == .audio {
                    // Arbitrary extension, not managed yet
                    fileName = URL(fileURLWithPath: fileName).appendingPathExtension("m4a").absoluteString
                }
            }
        }

        //    NSLog(@"=> filename = %@", fileName);
        return fileName
    }

    private var library: PHPhotoLibrary?
    private var count = 0

    private func requestPhotoLibraryAccess(in viewController: UIViewController?) {
        // Invite user to provide access to photos
        let alert = UIAlertController(title: NSLocalizedString("localAlbums_photosNotAuthorized_title", comment: "No Access"), message: NSLocalizedString("localAlbums_photosNotAuthorized_msg", comment: "tell user to change settings, how"), preferredStyle: .alert)

        let cancelAction = UIAlertAction(title: NSLocalizedString("alertCancelButton", comment: "Cancel"), style: .destructive, handler: { action in
            })

        let prefsAction = UIAlertAction(title: NSLocalizedString("alertOkButton", comment: "OK"), style: .default, handler: { action in
                // Redirect user to Settings app
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.openURL(url)
                }
            })

        // Add actions
        alert.addAction(cancelAction)
        alert.addAction(prefsAction)

        // Present list of actions
        alert.view.tintColor = UIColor.piwigoColorOrange()
        if #available(iOS 13.0, *) {
            alert.overrideUserInterfaceStyle = Model.sharedInstance().isDarkPaletteActive ? .dark : .light
        } else {
            // Fallback on earlier versions
        }
        viewController?.present(alert, animated: true) {
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            alert.view.tintColor = UIColor.piwigoColorOrange()
        }
    }

    private func showPhotosLibraryAccessRestricted(in viewController: UIViewController?) {
        let alert = UIAlertController(title: NSLocalizedString("localAlbums_photosNiltitle", comment: "Problem Reading Photos"), message: NSLocalizedString("localAlbums_photosNnil_msg", comment: "There is a problem reading your local photo library."), preferredStyle: .alert)

        let dismissAction = UIAlertAction(title: NSLocalizedString("alertDismissButton", comment: "Dismiss"), style: .cancel, handler: { action in
            })

        // Present alert
        alert.addAction(dismissAction)
        alert.view.tintColor = UIColor.piwigoColorOrange()
        if #available(iOS 13.0, *) {
            alert.overrideUserInterfaceStyle = Model.sharedInstance().isDarkPaletteActive ? .dark : .light
        } else {
            // Fallback on earlier versions
        }
        viewController?.present(alert, animated: true) {
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            alert.view.tintColor = UIColor.piwigoColorOrange()
        }
    }
}
