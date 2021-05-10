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
    func didChangePhotoLibrary()
}

class LocalAlbumsProvider: NSObject, PHPhotoLibraryChangeObserver {
    
    // Singleton
    static var instance: LocalAlbumsProvider = LocalAlbumsProvider()
    class func sharedInstance() -> LocalAlbumsProvider {
        return instance
    }
    
    // MARK: Properties
    let maxNberOfAlbumsInSection = 23
    var hasLimitedNberOfAlbums = [Bool]()
    var localAlbumHeaders = [String]()
    var fetchedLocalAlbums = [[PHAssetCollection]]()
    var localAlbumsFooters = [String]()
    
    // Smart albums
//    var genericAlbum: PHFetchResult<PHAssetCollection>!
    private var panoramasAlbum: PHFetchResult<PHAssetCollection>!
    private var videosAlbum: PHFetchResult<PHAssetCollection>!
    private var favoritesAlbum: PHFetchResult<PHAssetCollection>!
    private var timeLapsesAlbum: PHFetchResult<PHAssetCollection>!
    private var allHiddenAlbum: PHFetchResult<PHAssetCollection>!
//    private var recentlyAddedAlbum: PHFetchResult<PHAssetCollection>!
    private var burstsAlbum: PHFetchResult<PHAssetCollection>!
    private var slowmoAlbum: PHFetchResult<PHAssetCollection>!
    private var userLibraryAlbum: PHFetchResult<PHAssetCollection>!
    private var selfPortraitsAlbum: PHFetchResult<PHAssetCollection>!
    private var screenshotsAlbum: PHFetchResult<PHAssetCollection>!
    private var depthEffectAlbum: PHFetchResult<PHAssetCollection>!
    private var livePhotosAlbum: PHFetchResult<PHAssetCollection>!
    private var animatedAlbum: PHFetchResult<PHAssetCollection>!
    private var longExposuresAlbum:PHFetchResult<PHAssetCollection>!
    
    // Local albums
    private var regularAlbums: PHFetchResult<PHAssetCollection>!
    private var syncedEvent: PHFetchResult<PHAssetCollection>!
    private var syncedFaces: PHFetchResult<PHAssetCollection>!
    private var syncedAlbum: PHFetchResult<PHAssetCollection>!
    private var importedAlbums: PHFetchResult<PHAssetCollection>!
    
    // Cloud alums
//    private var CloudMyPhotoStream: PHFetchResult<PHAssetCollection>!
    private var CloudShared: PHFetchResult<PHAssetCollection>!
    

    // Initialisation
    override init() {
        super.init()
        
        /**
         Smart Album Types
        */
        // Smart albums of no more specific subtype
//        genericAlbum = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumGeneric, options: nil)
        
        // Smart album that groups all panorama photos in the photo library
        panoramasAlbum = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumPanoramas, options: nil)
        
        // Smart album that groups all video assets in the photo library
        videosAlbum = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumVideos, options: nil)
        
        // Smart album that groups all assets that the user has marked as favorites
        favoritesAlbum = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumFavorites, options: nil)
        
        // Smart album that groups all time-lapse videos in the photo library
        timeLapsesAlbum = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumTimelapses, options: nil)
        
        // Smart album that groups all assets hidden from the Moments view in the Photos app
        allHiddenAlbum = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumAllHidden, options: nil)
        
        // Smart album that groups assets that were recently added to the photo library
//        recentlyAddedAlbum = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumRecentlyAdded, options: nil)
        
        // Smart album that groups all burst photo sequences in the photo library
        burstsAlbum = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumBursts, options: nil)
        
        // Smart album that groups all Slow-Mo videos in the photo library
        slowmoAlbum = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumSlomoVideos, options: nil)
        
        // Smart album that groups all assets that originate in the user’s own library
        userLibraryAlbum = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumUserLibrary, options: nil)
        
        // Smart album that groups all photos and videos captured using the device’s front-facing camera
        selfPortraitsAlbum = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumSelfPortraits, options: nil)
        
        // Smart album that groups all images captured using the device’s screenshot function
        screenshotsAlbum = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumScreenshots, options: nil)
        
        if #available(iOS 10.2, *) {
            // Smart album that groups all images captured using the Depth Effect camera mode on compatible devices
            depthEffectAlbum = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumDepthEffect, options: nil)
        }
        
        if #available(iOS 10.3, *) {
            // Smart album that groups all Live Photo assets
            livePhotosAlbum = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumLivePhotos, options: nil)
        }
        
        // Smart album that groups all image animation assets
        if #available(iOS 11, *) {
            // Smart album that groups all image animation assets
            animatedAlbum = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumAnimated, options: nil)

            // Smart album that groups all Live Photo assets where the Long Exposure variation is enabled
            longExposuresAlbum = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumLongExposures, options: nil)
        }
        
        /**
         User Album Types
        */
        // Albums created in Photos
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "localizedTitle", ascending: true)]
        regularAlbums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: fetchOptions)
        
        // Events synced to the device from iPhoto
        syncedEvent = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumSyncedEvent, options: fetchOptions)

        // Faces group synced to the device from iPhoto
        syncedFaces = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumSyncedFaces, options: fetchOptions)

        // Albums synced to the device from iPhoto
        syncedAlbum = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumSyncedAlbum, options: fetchOptions)

        // Albums imported from a camera or external storage
        importedAlbums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumImported, options: fetchOptions)

        /**
         Cloud Album Types
        */
        // User’s personal My Photo Stream album (since iOS 13, limited to low-resolution)
        // See https://github.com/Piwigo/Piwigo/issues/1163
//        CloudMyPhotoStream = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumMyPhotoStream, options: nil)

        // iCloud Shared Photo Stream albums.
        CloudShared = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumCloudShared, options: fetchOptions)

        // Register Photo Library changes
        PHPhotoLibrary.shared().register(self)
    }

    deinit {
        // Unregister Photo Library changes
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }


    // MARK: - Fetch Local Albums
    /**
     Fetches the local albums from the Photo Library
     Empty albums are not presented, left albums are sorted by localized title
    */
    func fetchLocalAlbums(completion: @escaping () -> Void) {
        
        var _hasLimitedNberOfAlbums = [Bool]()
        var _localAlbumHeaders = [String]()
        var _fetchedLocalAlbums = [[PHAssetCollection]]()
        var _localAlbumsFooters = [String]()
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        let albumStr = NSLocalizedString("categorySelection_title", comment: "Album")
        let albumsStr = NSLocalizedString("tabBar_albums", comment: "Albums")

        // Local albums
        // Library, photo stream and favorites at the top
//        var localAlbums = filter(fetchedAssetCollections: [userLibraryAlbum, CloudMyPhotoStream, favoritesAlbum].compactMap { $0 })
        var localAlbums = filter(fetchedAssetCollections: [userLibraryAlbum, favoritesAlbum].compactMap { $0 })
        // Followed by albums created in Photos
        let regular = filter(fetchedAssetCollections: [regularAlbums].compactMap { $0 })
        if regular.count > 0 {
            localAlbums.append(contentsOf: regular)
        }
        if localAlbums.count > 0 {
            _hasLimitedNberOfAlbums.append(localAlbums.count > maxNberOfAlbumsInSection)
            _localAlbumHeaders.append(NSLocalizedString("categoryUpload_LocalAlbums", comment: "Local Albums"))
            _fetchedLocalAlbums.append(localAlbums)
            _localAlbumsFooters.append(String(format: "%@ %@", numberFormatter.string(from: NSNumber(value: localAlbums.count)) ?? "", localAlbums.count > 1 ? albumsStr : albumStr))
        }
        
        // Synced events
        let eventsAlbums = filter(fetchedAssetCollections: [syncedEvent].compactMap { $0 })
        if eventsAlbums.count > 0 {
            _hasLimitedNberOfAlbums.append(eventsAlbums.count > maxNberOfAlbumsInSection)
            _localAlbumHeaders.append(NSLocalizedString("categoryUpload_syncedEvents", comment: "iPhoto Events"))
            _fetchedLocalAlbums.append(eventsAlbums)
            _localAlbumsFooters.append(String(format: "%@ %@", numberFormatter.string(from: NSNumber(value: eventsAlbums.count)) ?? "", eventsAlbums.count > 1 ? albumsStr : albumStr))
        }
        
        // Synced albums
        let syncedAlbums = filter(fetchedAssetCollections: [syncedAlbum].compactMap { $0 })
        if syncedAlbums.count > 0 {
            _hasLimitedNberOfAlbums.append(syncedAlbums.count > maxNberOfAlbumsInSection)
            _localAlbumHeaders.append(NSLocalizedString("categoryUpload_syncedAlbums", comment: "iPhoto Albums"))
            _fetchedLocalAlbums.append(syncedAlbums)
            _localAlbumsFooters.append(String(format: "%@ %@", numberFormatter.string(from: NSNumber(value: syncedAlbums.count)) ?? "", syncedAlbums.count > 1 ? albumsStr : albumStr))
        }
        
        // Synced faces
        let facesAlbums = filter(fetchedAssetCollections: [syncedFaces].compactMap { $0 })
        if facesAlbums.count > 0 {
            _hasLimitedNberOfAlbums.append(facesAlbums.count > maxNberOfAlbumsInSection)
            _localAlbumHeaders.append(NSLocalizedString("categoryUpload_syncedFaces", comment: "iPhoto Faces"))
            _fetchedLocalAlbums.append(facesAlbums)
            _localAlbumsFooters.append(String(format: "%@ %@", numberFormatter.string(from: NSNumber(value: facesAlbums.count)) ?? "", facesAlbums.count > 1 ? albumsStr : albumStr))
        }
        
        // Shared albums
        let sharedAlbums = filter(fetchedAssetCollections: [CloudShared].compactMap { $0 })
        if sharedAlbums.count > 0 {
            _hasLimitedNberOfAlbums.append(sharedAlbums.count > maxNberOfAlbumsInSection)
            _localAlbumHeaders.append(NSLocalizedString("categoryUpload_sharedAlbums", comment: "Shared Albums"))
            _fetchedLocalAlbums.append(sharedAlbums)
            _localAlbumsFooters.append(String(format: "%@ %@", numberFormatter.string(from: NSNumber(value: sharedAlbums.count)) ?? "", sharedAlbums.count > 1 ? albumsStr : albumStr))
        }
        
        // Media types (selection of smart albums)
        let mediaTypes = filter(fetchedAssetCollections: [videosAlbum, selfPortraitsAlbum, livePhotosAlbum, depthEffectAlbum, panoramasAlbum, timeLapsesAlbum, slowmoAlbum, burstsAlbum, longExposuresAlbum, screenshotsAlbum, animatedAlbum].compactMap { $0 })
        if mediaTypes.count > 0 {
            _hasLimitedNberOfAlbums.append(false)
            _localAlbumHeaders.append(NSLocalizedString("categoryUpload_mediaTypes", comment: "Media Types"))
            _fetchedLocalAlbums.append(mediaTypes)
            _localAlbumsFooters.append(String(format: "%@ %@", numberFormatter.string(from: NSNumber(value: mediaTypes.count)) ?? "", mediaTypes.count > 1 ? albumsStr : albumStr))
        }
        
        // Other albums
        let otherAlbums = filter(fetchedAssetCollections: [allHiddenAlbum, importedAlbums].compactMap { $0 })
        if otherAlbums.count > 0 {
            _hasLimitedNberOfAlbums.append(otherAlbums.count > maxNberOfAlbumsInSection)
            _localAlbumHeaders.append(NSLocalizedString("categoryUpload_otherAlbums", comment: "Other Albums"))
            _fetchedLocalAlbums.append(otherAlbums)
            _localAlbumsFooters.append(String(format: "%@ %@", numberFormatter.string(from: NSNumber(value: otherAlbums.count)) ?? "", otherAlbums.count > 1 ? albumsStr : albumStr))
        }

        // Store data in data source
        hasLimitedNberOfAlbums = _hasLimitedNberOfAlbums
        localAlbumHeaders = _localAlbumHeaders
        fetchedLocalAlbums = _fetchedLocalAlbums
        localAlbumsFooters = _localAlbumsFooters
        completion()
    }
    
    private func filter(fetchedAssetCollections: [PHFetchResult<PHAssetCollection>]) -> [PHAssetCollection] {
        // Fetch assets to determine non-empty collections
//        let start = CFAbsoluteTimeGetCurrent()
        var collections = [PHAssetCollection]()

        // Fetch first image in each collection to reject empty collections
        // Concurrent loop is not feasible as the array size depends on the number of left collections
        let fetchOptions = PHFetchOptions()
        fetchOptions.fetchLimit = 1
        for fetchResult in fetchedAssetCollections {
            // Keep only non-empty albums
            fetchResult.enumerateObjects { (collection, idx, stop) in
                if PHAsset.fetchAssets(in: collection, options: fetchOptions).count > 0 {
                    collections.append(collection)
                }
            }
        }
        
//        let diff = (CFAbsoluteTimeGetCurrent() - start)*1000
//        print("==> Took \(diff) ms to filter albums")
        return collections
    }

    // Used when an iOS version does not apply the fetch option as expected
//    private func sort(collections: [PHAssetCollection]) -> [PHAssetCollection] {
//        // Sort collections by title
//        let sortedCollections = collections.sorted { (arg0, arg1) -> Bool in
//            let title0 = arg0.localizedTitle ?? "?"
//            let title1 = arg1.localizedTitle ?? "?"
//            return (title0.compare(title1) == .orderedAscending)
//        }
//        return sortedCollections
//    }
    
    // MARK: - Changes occured in the Photo library
    /**
     A delegate to give consumers a chance to update
     the user interface when content changes.
     */
    @objc weak var fetchedLocalAlbumsDelegate: LocalAlbumsProviderDelegate?
    
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        // Check each of the fetches for changes,
        // and update the cached fetch results, and reload the table sections to match.
//        if let changeDetails = changeInstance.changeDetails(for: genericAlbum) {
//            genericAlbum = changeDetails.fetchResultAfterChanges
//        }

        if let changeDetails = changeInstance.changeDetails(for: panoramasAlbum) {
            panoramasAlbum = changeDetails.fetchResultAfterChanges
        }

        if let changeDetails = changeInstance.changeDetails(for: videosAlbum) {
            videosAlbum = changeDetails.fetchResultAfterChanges
        }

        if let changeDetails = changeInstance.changeDetails(for: favoritesAlbum) {
            favoritesAlbum = changeDetails.fetchResultAfterChanges
        }

        if let changeDetails = changeInstance.changeDetails(for: timeLapsesAlbum) {
            timeLapsesAlbum = changeDetails.fetchResultAfterChanges
        }

        if let changeDetails = changeInstance.changeDetails(for: allHiddenAlbum) {
            allHiddenAlbum = changeDetails.fetchResultAfterChanges
        }

//        if let changeDetails = changeInstance.changeDetails(for: recentlyAddedAlbum) {
//            recentlyAddedAlbum = changeDetails.fetchResultAfterChanges
//        }

        if let changeDetails = changeInstance.changeDetails(for: burstsAlbum) {
            burstsAlbum = changeDetails.fetchResultAfterChanges
        }

        if let changeDetails = changeInstance.changeDetails(for: slowmoAlbum) {
            slowmoAlbum = changeDetails.fetchResultAfterChanges
        }

        if let changeDetails = changeInstance.changeDetails(for: userLibraryAlbum) {
            userLibraryAlbum = changeDetails.fetchResultAfterChanges
        }

        if let changeDetails = changeInstance.changeDetails(for: selfPortraitsAlbum) {
            selfPortraitsAlbum = changeDetails.fetchResultAfterChanges
        }

        if let changeDetails = changeInstance.changeDetails(for: screenshotsAlbum) {
            screenshotsAlbum = changeDetails.fetchResultAfterChanges
        }

        if #available(iOS 10.2, *) {
            if let changeDetails = changeInstance.changeDetails(for: depthEffectAlbum) {
                depthEffectAlbum = changeDetails.fetchResultAfterChanges
            }
        }

        if #available(iOS 10.3, *) {
            if let changeDetails = changeInstance.changeDetails(for: livePhotosAlbum) {
                livePhotosAlbum = changeDetails.fetchResultAfterChanges
            }
        }

        if #available(iOS 11, *) {
            if let changeDetails = changeInstance.changeDetails(for: animatedAlbum) {
                animatedAlbum = changeDetails.fetchResultAfterChanges
            }

            if let changeDetails = changeInstance.changeDetails(for: longExposuresAlbum) {
                longExposuresAlbum = changeDetails.fetchResultAfterChanges
            }
        }

        if let changeDetails = changeInstance.changeDetails(for: regularAlbums) {
            regularAlbums = changeDetails.fetchResultAfterChanges
        }

        if let changeDetails = changeInstance.changeDetails(for: syncedEvent) {
            syncedEvent = changeDetails.fetchResultAfterChanges
        }

        if let changeDetails = changeInstance.changeDetails(for: syncedFaces) {
            syncedFaces = changeDetails.fetchResultAfterChanges
        }

        if let changeDetails = changeInstance.changeDetails(for: syncedAlbum) {
            syncedAlbum = changeDetails.fetchResultAfterChanges
        }

        if let changeDetails = changeInstance.changeDetails(for: importedAlbums) {
            importedAlbums = changeDetails.fetchResultAfterChanges
        }

//        if let changeDetails = changeInstance.changeDetails(for: CloudMyPhotoStream) {
//            CloudMyPhotoStream = changeDetails.fetchResultAfterChanges
//        }

        if let changeDetails = changeInstance.changeDetails(for: CloudShared) {
            CloudShared = changeDetails.fetchResultAfterChanges
        }

        // Update data and reload LocalAlbumsTableView
        fetchLocalAlbums {
            self.fetchedLocalAlbumsDelegate?.didChangePhotoLibrary()
        }
    }
}
