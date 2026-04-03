//
//  UploadManager+Auto.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 10/04/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Photos
import piwigoKit

@UploadManagerActor
extension UploadManager {
    
    // MARK: - Add Auto-Upload Requests
    public func appendAutoUploadRequests(inBckgTask: Bool) async {
        // Check access to Photo Library album
        let collectionID = UploadVars.shared.autoUploadAlbumId
        guard collectionID.isEmpty == false,
              let collection = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [collectionID], options: nil).firstObject
        else {
            // Cannot access local album -> Reset album ID
            UploadVars.shared.autoUploadAlbumId = ""               // Unknown source Photos album

            // Delete remaining upload requests and inform user
            await disableAutoUpload(withTitle: PwgKitError.autoUploadSourceInvalid.localizedDescription,
                                    message: String(localized: "settings_autoUploadSourceInfo", bundle: .uploadKit,
                                                    comment: "Please select the album…"), inBckgTask: inBckgTask)
            return
        }
        
        // Check existence of Piwigo album
        let categoryId = UploadVars.shared.autoUploadCategoryId
        guard categoryId != Int32.min
        else {
            // Cannot access Piwigo album -> Reset album ID
            UploadVars.shared.autoUploadCategoryId = Int32.min    // Unknown destination Piwigo album

            // Delete remaining upload requests and inform user
            await disableAutoUpload(withTitle: PwgKitError.autoUploadDestinationInvalid.localizedDescription,
                                    message: String(localized: "settings_autoUploadDestinationInfo", bundle: .uploadKit,
                                                    comment: "Please select the album…"), inBckgTask: inBckgTask)
            return
        }
        
        // Get new local images to be uploaded
        let uploadRequestsToAppend = getNewRequests(inCollection: collection, toBeUploadedIn: categoryId)
        if uploadRequestsToAppend.isEmpty { return }
        
        // Add selected images to upload queue
        do {
            // Create upload requests
            let uploadIDs = try await UploadManager.shared.importUploads(from: uploadRequestsToAppend)
            
            // Job done if called by background task
            if inBckgTask { return }

            // Add upload requests to queue
            await UploadManagerActor.shared.addUploadsToPrepare(withIDs: uploadIDs)
            
            // Process next uploads if possible
            await UploadManagerActor.shared.processNextUpload()
        }
        catch {
            // Job done if called by background task
            if inBckgTask { return }

            // Error encountered, inform user
            await MainActor.run {
                let userInfo: [String : Any] = ["message" : PwgKitError.uploadCreationError.localizedDescription,
                                                "errorMsg" : error.localizedDescription];
                NotificationCenter.default.post(name: .pwgAppendAutoUploadRequestsFailed,
                                                object: nil, userInfo: userInfo)
            }
        }
    }
    
    public func getNewRequests(inCollection collection: PHAssetCollection,
                               toBeUploadedIn categoryId: Int32) -> [UploadProperties] {
        // Collect IDs of images to upload
        let fetchOptions = PHFetchOptions()
        fetchOptions.includeHiddenAssets = false
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: #keyPath(PHAsset.creationDate), ascending: false)]
        if NetworkVars.shared.serverFileTypes.contains("mp4") {
            fetchOptions.predicate = NSPredicate(format: "(mediaType == %d) || (mediaType == %d)", PHAssetMediaType.image.rawValue, PHAssetMediaType.video.rawValue)
        } else {
            fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        }
        let fetchedImages = PHAsset.fetchAssets(in: collection, options: fetchOptions)
        if fetchedImages.count == 0 {
            // No new photos - Job done
            return [UploadProperties]()
        }
        
        // Collect localIdentifiers of uploaded and not yet uploaded images in the Upload cache
        var imageIDs = Set( UploadProvider().getIDsOfPendingUploads(inContext: self.uploadBckgContext).1 )
        imageIDs.formUnion(Set( UploadProvider().getIDsOfCompletedUploads(inContext: self.uploadBckgContext).1 ))
        
        // Determine which local images are still not considered for upload
        var uploadRequestsToAppend = [UploadProperties]()
        fetchedImages.enumerateObjects { image, _, stop in
            // Keep images which had never been considered for upload
            if !imageIDs.contains(image.localIdentifier) {
                // Create upload request
                var uploadRequest = UploadProperties(localIdentifier: image.localIdentifier,
                                                     category: categoryId)
                uploadRequest.markedForAutoUpload = true
                uploadRequest.tagIds = UploadVars.shared.autoUploadTagIds
                uploadRequest.comment = UploadVars.shared.autoUploadComments
                uploadRequestsToAppend.append(uploadRequest)
                
                // Check if we have reached the max number of requests to append
                if uploadRequestsToAppend.count >= maxNberOfQueuedAutoUploads {
                    stop.pointee = true
                }
            }
        }
        
        // Return properties of new upload requests
        return uploadRequestsToAppend
    }
    
    
    // MARK: - Delete Auto-Upload Requests
    @objc nonisolated func stopAutoUploader(_ notification: Notification?) async {
        await disableAutoUpload(inBckgTask: false)
    }
    
    public func disableAutoUpload(withTitle title:String = "", message:String = "",
                                  inBckgTask: Bool) async {
        // Something to do?
        if !UploadVars.shared.isAutoUploadActive { return }
        // Disable auto-uploading
        UploadVars.shared.isAutoUploadActive = false
        
        // If the Settings or Settings/AutoUpload view is displayed:
        /// - switch off Auto-Upload control
        /// - inform user in case of error
        if inBckgTask == false {
            DispatchQueue.main.async {
                let userInfo: [String : Any] = ["title"   : title,
                                                "message" : message];
                NotificationCenter.default.post(name: .pwgAutoUploadChanged,
                                                object: nil, userInfo: userInfo)
            }
        }
        
        // Unqueues auto-upload requests
        do {
            // Remove non-completed upload requests marked for auto-upload from the upload queue
            let uploadIDs = UploadProvider().getIDsOfPendingUploads(onlyDeletable: true, markedForAutoUpload: true, inContext: self.uploadBckgContext).0
            await UploadManagerActor.shared.removeUploads(withIDs: uploadIDs)
            try UploadProvider().deleteUploads(withID: uploadIDs, inContext: self.uploadBckgContext)
            
            // Update badge and default album view button
            UploadManager.shared.updateNberOfUploadsToComplete()
        }
        catch {
            // Job done if called by background task
            if inBckgTask { return }

            // Error encountered, inform user
            await MainActor.run {
                let userInfo: [String : Any] = ["message" : error.localizedDescription];
                NotificationCenter.default.post(name: .pwgAppendAutoUploadRequestsFailed,
                                                object: nil, userInfo: userInfo)
            }
        }
    }
}
