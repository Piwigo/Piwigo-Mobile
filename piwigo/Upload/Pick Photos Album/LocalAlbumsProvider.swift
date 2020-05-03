//
//  LocalAlbumsProvider.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 26/04/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import Foundation
import Photos

@objc
protocol LocalAlbumsProviderDelegate: NSObjectProtocol {
    func didChangePhotoLibrary(section: Int)
}

class LocalAlbumsProvider: NSObject, PHPhotoLibraryChangeObserver {
    
    // Singleton
    static var instance: LocalAlbumsProvider = LocalAlbumsProvider()
    class func sharedInstance() -> LocalAlbumsProvider {
        return instance
    }
    
    // MARK: Properties
    var fetchedLocalAlbums = [[PHAssetCollection]]()
    
    // Local albums
    var smartAlbums: PHFetchResult<PHAssetCollection>!
    var regularAlbums: PHFetchResult<PHAssetCollection>!
    var syncedEvent: PHFetchResult<PHAssetCollection>!
    var syncedFaces: PHFetchResult<PHAssetCollection>!
    var syncedAlbums: PHFetchResult<PHAssetCollection>!
    var importedAlbums: PHFetchResult<PHAssetCollection>!
    
    // Cloud alums
    var CloudMyPhotoStream: PHFetchResult<PHAssetCollection>!
    var CloudShared: PHFetchResult<PHAssetCollection>!
    

    // Initialisation
    override init() {
        super.init()
        
        // Collect all smart albums created in the Photos app
        // i.e. Camera Roll, Favorites, Recently Deleted, Panoramas, etc.
        smartAlbums = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: nil)

        // Collect albums created in Photos
        regularAlbums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: nil)
        
        // Collect event synced to the device from iPhoto
        syncedEvent = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumSyncedEvent, options: nil)

        // Collect albums synced to the device from iPhoto
        syncedAlbums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumSyncedAlbum, options: nil)

        // Collect faces groups synced to the device from iPhoto
        syncedFaces = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumSyncedFaces, options: nil)

        // Collect albums imported from a camera or external storage
        importedAlbums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumImported, options: nil)

        // Collect user’s personal iCloud Photo Stream album
        CloudMyPhotoStream = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumMyPhotoStream, options: nil)

        // Collect iCloud Shared Photo Stream albums.
        CloudShared = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumCloudShared, options: nil)

        // Register Photo Library changes
        PHPhotoLibrary.shared().register(self)
    }

    deinit {
        // Unregister Photo Library changes
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }


    // MARK: - Fetch Local Albums
    /**
     Fetches the local albums from the Photos library
     Empty albums are not presented, left albums are sorted by localized title
    */
    func fetchLocalAlbums(completion: @escaping () -> Void) {
        
        fetchedLocalAlbums = [[PHAssetCollection]]()

        // Local albums
        let localCollectionsFetchResults: [PHFetchResult<PHAssetCollection>] = [smartAlbums, regularAlbums, syncedEvent, syncedAlbums, syncedFaces, importedAlbums].compactMap { $0 }
        let localAlbums = filter(fetchedAssetCollections: localCollectionsFetchResults)
        if localAlbums.count > 0 {
            fetchedLocalAlbums.append(localAlbums)
        }
        
        // iCloud albums
        let iCloudCollectionsFetchResults: [PHFetchResult<PHAssetCollection>] = [CloudMyPhotoStream, CloudShared].compactMap { $0 }
        let iCloudAlbums = filter(fetchedAssetCollections: iCloudCollectionsFetchResults)
        if iCloudAlbums.count > 0 {
            fetchedLocalAlbums.append(iCloudAlbums)
        }
        
//        print("==> ", localAlbums.count, "albums and ", iCloudAlbums.count, "iCloud albums")
        completion()
    }
    
    private func filter(fetchedAssetCollections: [PHFetchResult<PHAssetCollection>]) -> [PHAssetCollection] {
        // Fetch assets to determine non-empty collections
//        let start = CFAbsoluteTimeGetCurrent()
        var collections = [PHAssetCollection]()

        // Fetch all images in selected collection and sort them
        // iPod - iOS 9.3.5: 1.548 ms for 2.185 photos in 55 local albums
        // iPhone 11 Pro - iOS 13.5ß: 72 ms for 89.215 photos in 5 local albums
        let fetchOptions = PHFetchOptions()
        fetchOptions.fetchLimit = 1
        for fetchResult in fetchedAssetCollections {
            // Keep only non-empty albums
            fetchResult.enumerateObjects(options: .concurrent) { (collection, idx, stop) in
                if PHAsset.fetchAssets(in: collection, options: fetchOptions).count > 0 {
                    collections.append(collection)
                }
            }
        }

        // Sort collections by title
        let sortedCollections = collections.sorted { (arg0, arg1) -> Bool in
            let title0 = arg0.localizedTitle ?? "?"
            let title1 = arg1.localizedTitle ?? "?"
            return (title0.compare(title1) == .orderedAscending)
        }
        
//        let diff = (CFAbsoluteTimeGetCurrent() - start)*1000
//        print("==> Took \(diff) ms to filter albums")
        return sortedCollections
    }

    
    // MARK: - Changes occured in the Photo library
    /**
     A delegate to give consumers a chance to update
     the user interface when content changes.
     */
    weak var fetchedLocalAlbumsDelegate: LocalAlbumsProviderDelegate?
    
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        // Check each of the fetches for changes,
        // and update the cached fetch results, and reload the table sections to match.
        if let changeDetails = changeInstance.changeDetails(for: smartAlbums) {
            smartAlbums = changeDetails.fetchResultAfterChanges
            fetchLocalAlbums {
                if self.fetchedLocalAlbumsDelegate?.responds(to: #selector(LocalAlbumsProviderDelegate.didChangePhotoLibrary(section:))) ?? false {
                    self.fetchedLocalAlbumsDelegate?.didChangePhotoLibrary(section: 0)
                }
            }
        }

        if let changeDetails = changeInstance.changeDetails(for: regularAlbums) {
            regularAlbums = changeDetails.fetchResultAfterChanges
            fetchLocalAlbums {
                if self.fetchedLocalAlbumsDelegate?.responds(to: #selector(LocalAlbumsProviderDelegate.didChangePhotoLibrary(section:))) ?? false {
                    self.fetchedLocalAlbumsDelegate?.didChangePhotoLibrary(section: 0)
                }
            }
        }

        if let changeDetails = changeInstance.changeDetails(for: syncedEvent) {
            syncedEvent = changeDetails.fetchResultAfterChanges
            fetchLocalAlbums {
                if self.fetchedLocalAlbumsDelegate?.responds(to: #selector(LocalAlbumsProviderDelegate.didChangePhotoLibrary(section:))) ?? false {
                    self.fetchedLocalAlbumsDelegate?.didChangePhotoLibrary(section: 0)
                }
            }
        }

        if let changeDetails = changeInstance.changeDetails(for: syncedFaces) {
            syncedFaces = changeDetails.fetchResultAfterChanges
            fetchLocalAlbums {
                if self.fetchedLocalAlbumsDelegate?.responds(to: #selector(LocalAlbumsProviderDelegate.didChangePhotoLibrary(section:))) ?? false {
                    self.fetchedLocalAlbumsDelegate?.didChangePhotoLibrary(section: 0)
                }
            }
        }

        if let changeDetails = changeInstance.changeDetails(for: syncedAlbums) {
            syncedAlbums = changeDetails.fetchResultAfterChanges
            fetchLocalAlbums {
                if self.fetchedLocalAlbumsDelegate?.responds(to: #selector(LocalAlbumsProviderDelegate.didChangePhotoLibrary(section:))) ?? false {
                    self.fetchedLocalAlbumsDelegate?.didChangePhotoLibrary(section: 0)
                }
            }
        }

        if let changeDetails = changeInstance.changeDetails(for: importedAlbums) {
            importedAlbums = changeDetails.fetchResultAfterChanges
            fetchLocalAlbums {
                if self.fetchedLocalAlbumsDelegate?.responds(to: #selector(LocalAlbumsProviderDelegate.didChangePhotoLibrary(section:))) ?? false {
                    self.fetchedLocalAlbumsDelegate?.didChangePhotoLibrary(section: 0)
                }
            }
        }

        if let changeDetails = changeInstance.changeDetails(for: CloudMyPhotoStream) {
            CloudMyPhotoStream = changeDetails.fetchResultAfterChanges
            fetchLocalAlbums {
                if self.fetchedLocalAlbumsDelegate?.responds(to: #selector(LocalAlbumsProviderDelegate.didChangePhotoLibrary(section:))) ?? false {
                    self.fetchedLocalAlbumsDelegate?.didChangePhotoLibrary(section: 1)
                }
            }
        }

        if let changeDetails = changeInstance.changeDetails(for: CloudShared) {
            CloudShared = changeDetails.fetchResultAfterChanges
            fetchLocalAlbums {
                if self.fetchedLocalAlbumsDelegate?.responds(to: #selector(LocalAlbumsProviderDelegate.didChangePhotoLibrary(section:))) ?? false {
                    self.fetchedLocalAlbumsDelegate?.didChangePhotoLibrary(section: 1)
                }
            }
        }
    }
}
