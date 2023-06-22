//
//  LocalAlbumsProvider.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 26/04/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import Foundation
import Photos

enum LocalAlbumType {
    case pasteboard
    case localAlbums, eventsAlbums, syncedAlbums
    case facesAlbums, sharedAlbums, mediaTypes
    case otherAlbums
}

@objc protocol LocalAlbumsProviderDelegate: NSObjectProtocol {
    func didChangePhotoLibrary()
}

class LocalAlbumsProvider: NSObject, PHPhotoLibraryChangeObserver {

    // Singleton
    static let shared = LocalAlbumsProvider()
    
    // MARK: Properties
    var includingEmptyAlbums = false
    var localAlbums  = [PHAssetCollection]()
    var eventsAlbums = [PHAssetCollection]()
    var syncedAlbums = [PHAssetCollection]()
    var facesAlbums = [PHAssetCollection]()
    var sharedAlbums = [PHAssetCollection]()
    var mediaTypes = [PHAssetCollection]()
    var otherAlbums = [PHAssetCollection]()
    
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
        
        // Smart album that groups all images captured using the Depth Effect camera mode on compatible devices
        depthEffectAlbum = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumDepthEffect, options: nil)
        
        // Smart album that groups all Live Photo assets
        livePhotosAlbum = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumLivePhotos, options: nil)
        
        // Smart album that groups all image animation assets
        animatedAlbum = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumAnimated, options: nil)

        // Smart album that groups all Live Photo assets where the Long Exposure variation is enabled
        longExposuresAlbum = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumLongExposures, options: nil)
        
        /**
         User Album Types
        */
        // Albums created in Photos
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: #keyPath(PHAssetCollection.localizedTitle), ascending: true)]
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
        // Local albums
        // Library, photo stream and favorites at the top
//        var localAlbums = filter(fetchedAssetCollections: [userLibraryAlbum, CloudMyPhotoStream, favoritesAlbum].compactMap { $0 })
        let regular = filter(fetchedAssetCollections: [regularAlbums].compactMap { $0 })
        localAlbums = filter(fetchedAssetCollections: [userLibraryAlbum, favoritesAlbum].compactMap { $0 })
        // Followed by albums created in Photos
        if regular.count > 0 { localAlbums.append(contentsOf: regular) }
        
        // Synced events
        eventsAlbums = filter(fetchedAssetCollections: [syncedEvent].compactMap { $0 })

        // Synced albums
        syncedAlbums = filter(fetchedAssetCollections: [syncedAlbum].compactMap { $0 })

        // Synced faces
        facesAlbums = filter(fetchedAssetCollections: [syncedFaces].compactMap { $0 })

        // Shared albums
        sharedAlbums = filter(fetchedAssetCollections: [CloudShared].compactMap { $0 })

        // Media types (selection of smart albums)
        mediaTypes = filter(fetchedAssetCollections: [videosAlbum, selfPortraitsAlbum,
                                                      livePhotosAlbum, depthEffectAlbum,
                                                      panoramasAlbum, timeLapsesAlbum,
                                                      slowmoAlbum, burstsAlbum,
                                                      longExposuresAlbum, screenshotsAlbum,
                                                      animatedAlbum].compactMap { $0 })

        // Other albums
        otherAlbums = filter(fetchedAssetCollections: [allHiddenAlbum, importedAlbums].compactMap { $0 })

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
            fetchResult.enumerateObjects { (collection, _, _) in
                if self.includingEmptyAlbums ||
                    PHAsset.fetchAssets(in: collection, options: fetchOptions).count > 0 {
                    collections.append(collection)
                }
            }
        }
        
//        let diff = (CFAbsoluteTimeGetCurrent() - start)*1000
//        debugPrint("••> Took \(diff) ms to filter albums")
        return collections
    }

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

        if let changeDetails = changeInstance.changeDetails(for: depthEffectAlbum) {
            depthEffectAlbum = changeDetails.fetchResultAfterChanges
        }

        if let changeDetails = changeInstance.changeDetails(for: livePhotosAlbum) {
            livePhotosAlbum = changeDetails.fetchResultAfterChanges
        }

        if let changeDetails = changeInstance.changeDetails(for: animatedAlbum) {
            animatedAlbum = changeDetails.fetchResultAfterChanges
        }

        if let changeDetails = changeInstance.changeDetails(for: longExposuresAlbum) {
            longExposuresAlbum = changeDetails.fetchResultAfterChanges
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


    // MARK: - Data Source Utilities
    func titleForHeaderInSectionOf(albumType: LocalAlbumType) -> String {
        var title: String
        switch albumType {
        case .pasteboard:
            return ""
        case .localAlbums:
            title = NSLocalizedString("categoryUpload_LocalAlbums", comment: "Local Albums")
        case .eventsAlbums:
            title = NSLocalizedString("categoryUpload_syncedEvents", comment: "iPhoto Events")
        case .syncedAlbums:
            title = NSLocalizedString("categoryUpload_syncedAlbums", comment: "iPhoto Albums")
        case .facesAlbums:
            title = NSLocalizedString("categoryUpload_syncedFaces", comment: "iPhoto Faces")
        case .sharedAlbums:
            title = NSLocalizedString("categoryUpload_sharedAlbums", comment: "Shared Albums")
        case .mediaTypes:
            title = NSLocalizedString("categoryUpload_mediaTypes", comment: "Media Types")
        case .otherAlbums:
            title = NSLocalizedString("categoryUpload_otherAlbums", comment: "Other Albums")
        }
        return title
    }

    func titleForFooterInSectionOf(albumType: LocalAlbumType) -> String {
        // Initialisation
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        
        // Set footer
        var count = 0
        switch albumType {
        case .pasteboard:
            return ""
        case .localAlbums:
            count = localAlbums.count
        case .eventsAlbums:
            count = eventsAlbums.count
        case .syncedAlbums:
            count = syncedAlbums.count
        case .facesAlbums:
            count = facesAlbums.count
        case .sharedAlbums:
            count = sharedAlbums.count
        case .mediaTypes:
            count = mediaTypes.count
        case .otherAlbums:
            count = otherAlbums.count
        }
        let nberOfAlbums = numberFormatter.string(from: NSNumber(value: count)) ?? ""
        let footer = count > 1 ?
            String(format: NSLocalizedString("severalAlbumsCount", comment: "%@ albums"), nberOfAlbums) :
            String(format: NSLocalizedString("singleAlbumCount", comment: "%@ album"), nberOfAlbums)
        return footer
    }
}
