//
//  UploadLivePhotos.swift
//  PwgUploadKit
//
//  Created by Eddy Lelièvre-Berna on 16/08/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//

import Photos
import PwgKit
import PwgCacheKit

// Logs the expansion of the upload requests of Live Photos
/// UploadManager.logger is isolated to the UploadManagerActor, but requests are expanded
/// before reaching it, i.e. from the picker, the share path or the auto-upload scan.
private let logger = PwgLogger(subsystem: "org.piwigo.uploadKit", category: "LivePhotos")

extension UploadProperties {

    /// Requests created from a file stored in the Uploads directory — shared by another app,
    /// retrieved from the pasteboard or submitted by the shortcut — do not refer to a PHAsset.
    public var isFromPhotoLibrary: Bool {
        return localIdentifier.hasPrefix(kIntentPrefix) == false
            && localIdentifier.hasPrefix(kClipboardPrefix) == false
            && localIdentifier.hasPrefix(kSharedPrefix) == false
    }

    /**
     Expands the requests of Live Photos into one or two requests, according to the wanted
     option: the photo, the video, or both. Requests which do not refer to a Live Photo of
     the Photo Library are returned unchanged.
     Called just before the requests are stored in the cache, so that a picker keeps handling
     one request per asset.
     - Parameter choice: what to upload from a Live Photo. The caller provides it rather than
       reading the settings, so that a selection can be uploaded with another option without
       changing the default.
     */
    public static func expandingLivePhotos(in requests: [UploadProperties],
                                           as choice: pwgUploadLivePhotoAs) -> [UploadProperties] {
        // Nothing to do when the user only wants the photo, which is the default
        if choice == .photo || requests.isEmpty { return requests }

        // Identify the Live Photos among the assets, in a single fetch
        let assetIDs = requests.filter({ $0.assetPart == .original && $0.isFromPhotoLibrary })
                               .map(\.localIdentifier)
        if assetIDs.isEmpty { return requests }

        var livePhotoIDs = Set<String>()
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: assetIDs, options: nil)
        assets.enumerateObjects { asset, _, _ in
            if asset.mediaSubtypes.contains(.photoLive) {
                livePhotoIDs.insert(asset.localIdentifier)
            }
        }
        if livePhotoIDs.isEmpty { return requests }

        // Produce the requests of the wanted halves
        var expanded = [UploadProperties]()
        expanded.reserveCapacity(requests.count + livePhotoIDs.count)
        for request in requests {
            // Leave alone the requests which do not carry the photo half of a Live Photo
            guard request.assetPart == .original,
                  livePhotoIDs.contains(request.localIdentifier)
            else {
                expanded.append(request)
                continue
            }

            // Photo half
            if choice != .movie {
                expanded.append(request)
            }

            // Video half
            /// Both halves are requested at the very same date and the photo is uploaded first,
            /// see the sort descriptors of the UploadProvider.
            var movie = request
            movie.assetPart = .pairedVideo
            movie.fileType = pwgImageFileType.video.rawValue
            expanded.append(movie)
        }
        logger.notice("Live Photos • \(livePhotoIDs.count) Live Photo(s) among \(requests.count) request(s) —> \(expanded.count) upload request(s)")
        return expanded
    }
}
