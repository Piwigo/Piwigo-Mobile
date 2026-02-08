//
//  UploadManager+Resume.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 20/02/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import CoreData
import Foundation
import Photos
import piwigoKit

@UploadManagerActor
extension UploadManager
{
    // MARK: - Resume Uploads
    public func resumeAll() async {
        // Wait until fix completed
        guard NetworkVars.shared.fixUserIsAPIKeyV412 == false
        else { return }
        
        // Wait until continued background task finishes
//        guard UploadVars.shared.isExecutingBGContinuedUploadTask == false
//        else { return }
        
        // Reset flags
        UploadVars.shared.isPaused = false
        UploadVars.shared.isExecutingBGUploadTask = false
        
        // Reset predicates in case user switched to another Piwigo
        let variables = ["serverPath" : NetworkVars.shared.serverPath,
                         "userName"   : NetworkVars.shared.user]
        fetchPendingRequest.predicate = pendingPredicate.withSubstitutionVariables(variables)
        fetchCompletedRequest.predicate = completedPredicate.withSubstitutionVariables(variables)
        
        // Perform fetches
        let pending = (try? self.uploadBckgContext.fetch(fetchPendingRequest)) ?? []
        let completed = (try? self.uploadBckgContext.fetch(fetchCompletedRequest)) ?? []
        
        // Store number, update badge and default album view button
        let nberOfUploadsToComplete = pending.count
        DispatchQueue.main.async {
            // Update app badge and button of root album (or default album)
            let uploadInfo: [String : Any] = ["nberOfUploadsToComplete" : nberOfUploadsToComplete]
            NotificationCenter.default.post(name: .pwgLeftUploads, object: nil, userInfo: uploadInfo)
        }
        
        // Get active upload tasks
        let allTasks = await bckgSession.allTasks
        allTasks.filter({ $0.state == .running }).forEach {task in
            // Retrieve upload request properties
            guard let objectURIstr = task.originalRequest?.value(forHTTPHeaderField: pwgHTTPuploadID),
                  let chunkStr = task.originalRequest?.value(forHTTPHeaderField: pwgHTTPchunk), let chunk = Int(chunkStr),
                  let chunksStr = task.originalRequest?.value(forHTTPHeaderField: pwgHTTPchunks), let chunks = Int(chunksStr)
            else {
                UploadManager.logger.notice("Found task \(task.taskIdentifier) not associated to an upload!")
                return
            }
            
            // Task associated to an upload
            let objectIDstr = URL(string: objectURIstr)?.lastPathComponent ?? objectURIstr
            UploadManager.logger.notice("\(objectIDstr) • Detected task \(task.taskIdentifier) uploading chunk \(chunk)/\(chunks)")
            self.initIfNeededCounter(withID: objectIDstr, chunk: chunk, chunks: chunks)
        }
        
        // Logs
        UploadManager.logger.notice("Found \(pending.count) pending and \(completed.count) completed upload requests in cache.")
        
        // Clear failed uploads which can be retried
        self.clearAllFailedUploads()
        
        // Propose to delete uploaded images of the photo Library once a day
        if Date().timeIntervalSinceReferenceDate > UploadVars.shared.dateOfLastPhotoLibraryDeletion + TimeInterval(86400) {
            // Are there images to delete from the Photo Library?
            let uploadsToDelete = completed
                .filter({$0.deleteImageAfterUpload == true})
//                .filter({isDeleting.contains($0.objectID) == false})
            if uploadsToDelete.count > 0 {
                // Store date of deletion
                UploadVars.shared.dateOfLastPhotoLibraryDeletion = Date().timeIntervalSinceReferenceDate
                
                // Suggest to delete assets from the Photo Library
                UploadManager.logger.notice("Identified \(uploadsToDelete.count) assets for deletion from the Photo Library.")
                let objectURIs = uploadsToDelete.map({ $0.objectID.uriRepresentation().absoluteString + "," }).reduce("",+)
                let localIDs = uploadsToDelete.map({ $0.localIdentifier + "," }).reduce ("",+)
                let userInfo: [String : Any] = ["objectURIs" : objectURIs,
                                                "localIDs" : localIDs];
                NotificationCenter.default.post(name: .pwgDeleteUploadRequestsAndAssets,
                                                object: nil, userInfo: userInfo)
                // Code below crashes with Xcode 26.2 (17C52)
//                let uploadIDs = uploadsToDelete.map(\.objectID)
//                let uploadLocalIDs = uploadsToDelete.map(\.localIdentifier)
//                Task { @MainActor in
//                    await self.deleteAssets(associatedToUploads: uploadIDs, uploadLocalIDs)
//                }
            }
        }
        
        // Delete upload requests of assets that have become unavailable,
        // except non-completed requests from intent and clipboard
        var toDelete = pending
            .filter({!$0.localIdentifier.hasPrefix(kIntentPrefix)})
            .filter({!$0.localIdentifier.hasPrefix(kClipboardPrefix)})
        toDelete.append(contentsOf: completed)
        
        // Fetch assets which are still available
        let options = PHFetchOptions()
        options.includeHiddenAssets = false
        options.sortDescriptors = [NSSortDescriptor(key: #keyPath(PHAsset.creationDate), ascending: true)]
        let assetIDsToDelete = toDelete.map({$0.localIdentifier})
        let availableAssets = PHAsset.fetchAssets(withLocalIdentifiers: assetIDsToDelete, options: options)
        
        // Keep uploads only if assets are still available
        availableAssets.enumerateObjects { asset, _, _ in
            if let index = toDelete.firstIndex(where: {$0.localIdentifier == asset.localIdentifier}) {
                toDelete.remove(at: index)
            }
        }
        
        // Delete upload requests of images deleted from the Piwigo server
        toDelete.append(contentsOf: pending.filter({$0.requestState == 13}))
        
        // Delete upload requests
        let uploadsToDate = Set(toDelete).map({$0.objectID})
        try? UploadProvider().deleteUploads(withID: Array(uploadsToDate))
        
        // Append auto-upload requests if requested and restart activities
        if UploadVars.shared.isAutoUploadActive {
            await self.appendAutoUploadRequests()
        } else {
            await self.disableAutoUpload()
        }
        
        // Launch upload activities if needed
        let allPending = (try? self.uploadBckgContext.fetch(fetchPendingRequest)) ?? []
        await UploadManagerActor.shared.addUploads(withIDs: allPending.map(\.objectID))
    }
    
//    public func launchUploadsIfNeeded() async {
//        // Perform a fetch
//        let pending = (try? self.uploadBckgContext.fetch(fetchPendingRequest)) ?? []
//        
//        // Update counter and app badge
//        self.updateNberOfUploadsToComplete()
//
//        // Should we postpone uploads?
//        if UploadVars.shared.isPaused ||
//            UploadVars.shared.isExecutingBGUploadTask ||
////            UploadVars.shared.isExecutingBGContinuedUploadTask ||
//            ProcessInfo.processInfo.isLowPowerModeEnabled ||
//            (UploadVars.shared.wifiOnlyUploading && !NetworkVars.shared.isConnectedToWiFi) {
//            return
//        }
//        
//        // Check whether too many transfers failed
//        var states: [pwgUploadState] = [.preparingFail, .formatError, .uploadingFail, .finishingFail]
//        let failedUploads = pending.filter({ states.contains($0.state) })
//        if failedUploads.count >= maxNberOfFailedUploads { return }
//                
//        // Relaunch transfers if necessary and possible
//        let transfersToRetry = pending.filter({ $0.state == .prepared }).map(\.objectID)
//        if transfersToRetry.isEmpty == false {
//            for uploadID in transfersToRetry {
//                await transferOrCopyFileOfUpload(withID: uploadID)
//            }
//        }
//        
//        // Determine how many images are prepared or being prepared
//        states = [.preparing, .prepared]
//        let nberOfPreparations = pending.filter({ states.contains($0.state) }).count
//        
//        // Launch image preparations if necessary and possible
//        if nberOfPreparations < maxNberOfPreparedUploads {
//            let waitingImages = pending.filter({ $0.state == .waiting }).map(\.objectID)
//            if waitingImages.isEmpty == false {
//                let maxToLaunch = min(waitingImages.count, maxNberOfPreparedUploads - nberOfPreparations)
//                for uploadID in waitingImages[0..<maxToLaunch] {
//                    await prepareUpload(withID: uploadID)
//                }
//            }
//        }
//        
//        // Empty Lounge?
//        
//        // No more image to transfer
//        // Moderate images uploaded by Community regular user
//        // Considers only uploads to the server to which the user is logged in
//
//        // Suggest to delete images from the Photo Library if the user wanted it.
//        // The deletion is suggested when there is no more upload to perform.
//        // Note that some uploads may have failed and wait a user decision.
//    }
    
    
    // MARK: - Clear Failed Uploads
    public func clearAllFailedUploads() {
        // Perform fetches
        let pending = (try? self.uploadBckgContext.fetch(fetchPendingRequest)) ?? []
        
        // Considers all failed uploads to the server to which the user is logged in
        let states: [pwgUploadState] = [.preparingError, .uploadingError, .finishingError]
        let toResume = pending.filter({states.contains($0.state)})
        clearFailedUploads(toResume)
    }
    
    public func clearFailedUpload(withID uploadID: NSManagedObjectID) {
        // Get upload request
        if let upload = try? uploadBckgContext.existingObject(with: uploadID) as? Upload {
            clearFailedUploads([upload])
        }
    }
    
    public func clearFailedUploads(_ toResume: [Upload]) {
        // Loop over the failed uploads
        for failedUpload in toResume {
            switch failedUpload.state {
            case .uploading, .uploadingError, .uploaded:
                // -> Will retry to transfer the image
                failedUpload.setState(.prepared)

            case .finishing, .finishingError:
                // -> Will retry to finish the upload
                failedUpload.setState(.uploaded)
                
            default:
                // —> Will retry from scratch
                failedUpload.setState(.waiting)
            }
        }
    }

    
    // MARK: - Delete Upload Requests
    public func deleteUploadsOfDeletedImages(withIDs imageIDs: [Int64]) {
        if imageIDs.isEmpty { return }
        
        // Collect upload requests of deleted images
        let pending = (try? self.uploadBckgContext.fetch(fetchPendingRequest)) ?? []
        var toDelete = pending.filter({imageIDs.contains($0.imageId)})
        let completed = (try? self.uploadBckgContext.fetch(fetchCompletedRequest)) ?? []
        toDelete.append(contentsOf: completed.filter({imageIDs.contains($0.imageId)}))
        
        // Keep auto-upload requests so that they are not re-uploaded
        toDelete.removeAll(where: {$0.markedForAutoUpload == true})
        
        // Delete uploads
        let uploadIDsToDelete = Set(toDelete.map(\.objectID))
        try? UploadProvider().deleteUploads(withID: Array(uploadIDsToDelete))
        
        // Update counter and app badge
        self.updateNberOfUploadsToComplete()
    }
    
    public func deleteImpossibleUploads() {
        // Collect failed uploads
        let pending = (try? self.uploadBckgContext.fetch(fetchPendingRequest)) ?? []
        let states: [pwgUploadState] = [.preparingFail, .formatError,
                                        .uploadingFail, .finishingFail]
        let toDelete = pending.filter({states.contains($0.state)})
        
        // Delete uploads
        let uploadIDsToDelete = Set(toDelete.map(\.objectID))
        try? UploadProvider().deleteUploads(withID: Array(uploadIDsToDelete))

        // Update counter and app badge
        self.updateNberOfUploadsToComplete()
    }
    
    
    // MARK: - Clean Photo Library
//    @MainActor
//    func deleteAssets(associatedToUploads uploadIDs: [NSManagedObjectID], _ uploadLocalIDs: [String]) async -> Void {
//        // Remember which uploads are concerned to avoid duplicate deletions
//        Task { @UploadManagerActor in
//            willDeleteAsssets(associatedToUploads: uploadIDs)
//        }
//        
//        // Delete assets in the main thread
//        do {
//            // Delete image from Photo Library
//            let assetsToDelete = PHAsset.fetchAssets(withLocalIdentifiers: Array(uploadLocalIDs), options: nil)
//            try await PHPhotoLibrary.shared().performChanges {
//                PHAssetChangeRequest.deleteAssets(assetsToDelete as (any NSFastEnumeration))
//            }
//            
//            // Delete associated upload request if any
//            Task { @UploadManagerActor in
//                deleteUploads(uploadIDs)
//            }
//        }
//        catch {
//            Task { @UploadManagerActor in
//                disableDeleteAfterUpload(uploadIDs)
//            }
//        }
//    }
    
    public func willDeleteAsssets(associatedToUploads uploadIDs: [NSManagedObjectID]) {
        // Remember which uploads are concerned to avoid duplicate deletions
        isDeleting = Set(uploadIDs)
    }
    
    public func deleteUploads(_ uploadIDs: [NSManagedObjectID]) {
        // Empty array?
        if uploadIDs.isEmpty {
            self.isDeleting = Set()
            return
        }
        
        // Delete upload requests w/o reporting potential error
        try? UploadProvider().deleteUploads(withID: uploadIDs)
        self.isDeleting = Set()
    }
    
    public func disableDeleteAfterUpload(_ uploadIDs: [NSManagedObjectID]) {
        // Empty array?
        if uploadIDs.isEmpty {
            self.isDeleting = Set()
            return
        }
        
        // Update upload requests
        uploadIDs.forEach { id in
            if let upload = try? self.uploadBckgContext.existingObject(with: id) as? Upload {
                upload.deleteImageAfterUpload = false
            }
        }
        uploadBckgContext.saveIfNeeded()
        isDeleting = Set()
    }
}
