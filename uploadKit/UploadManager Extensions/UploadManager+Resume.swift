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
        debugPrint("In resumeAll() ► Thread priority: \(Task.currentPriority)")
        // Wait until fix completed
        guard NetworkVars.shared.fixUserIsAPIKeyV412 == false
        else { return }
        
        // Wait until continued background task finishes
//        guard UploadVars.shared.isExecutingBGContinuedUploadTask == false
//        else { return }
        
        // Reset flags
        UploadVars.shared.isPaused = false
        UploadVars.shared.isExecutingBGUploadTask = false
        
        // Store number, update badge and default album view button
        let nberOfPendingUploads = UploadProvider().getCountOfPendingUploads(inContext: self.uploadBckgContext)
        DispatchQueue.main.async {
            // Update app badge and button of root album (or default album)
            let uploadInfo: [String : Any] = ["nberOfUploadsToComplete" : nberOfPendingUploads]
            NotificationCenter.default.post(name: .pwgLeftUploads, object: nil, userInfo: uploadInfo)
        }
        
        // Delete upload requests of assets that have become unavailable,
        // except non-completed requests from intent and clipboard
        let states: [pwgUploadState] = [.waiting, .preparingError]
        let (objectIDs, localIDs) = UploadProvider().getIDsOfPendingUploads(onlyInStates: states, inContext: self.uploadBckgContext)
        var toDeleteIDs: [NSManagedObjectID] = objectIDs, assetIDsToDelete: [String] = localIDs
        for (index, localID) in localIDs.enumerated() {
            // Remove upload requests from intent and clipboard
            if localID.hasPrefix(kIntentPrefix) || localID.hasPrefix(kClipboardPrefix) {
                toDeleteIDs.remove(at: index)
                assetIDsToDelete.remove(at: index)
            }
        }
        let options = PHFetchOptions()  // Fetch assets which are still available
        options.includeHiddenAssets = false
        options.sortDescriptors = [NSSortDescriptor(key: #keyPath(PHAsset.creationDate), ascending: true)]
        let availableAssets = PHAsset.fetchAssets(withLocalIdentifiers: assetIDsToDelete, options: options)
        availableAssets.enumerateObjects { asset, _ , _ in
            // Don't delete upload requests of available asset
            if let index = assetIDsToDelete.firstIndex(where: {$0 == asset.localIdentifier}) {
                toDeleteIDs.remove(at: index)
                assetIDsToDelete.remove(at: index)
            }
        }
        try? UploadProvider().deleteUploads(withID: toDeleteIDs)
        
        // Resume failed uploads
        await clearAllFailedUploads()
        
        // Append transfers to complete
        let (uploadedUploadIDs, _) = UploadProvider().getIDsOfPendingUploads(onlyInStates: [.uploaded], inContext: self.uploadBckgContext)
        await UploadManagerActor.shared.addUploadsToTransfer(withIDs: uploadedUploadIDs)
        let (preparedUploadIDs, _) = UploadProvider().getIDsOfPendingUploads(onlyInStates: [.prepared], inContext: self.uploadBckgContext)
        await UploadManagerActor.shared.addUploadsToTransfer(withIDs: preparedUploadIDs)
        
        // Append uploads to prepare
        let (waitingUploadIDs, _) = UploadProvider().getIDsOfPendingUploads(onlyInStates: [.waiting], inContext: self.uploadBckgContext)
        await UploadManagerActor.shared.addUploadsToPrepare(withIDs: waitingUploadIDs)
        UploadManager.logger.notice("Resuming uploads: \(uploadedUploadIDs.count, privacy: .public) transfer(s) to finish, \(preparedUploadIDs.count, privacy: .public) file(s) to transfer, \(waitingUploadIDs.count, privacy: .public) uploads to prepare")
        
        // Propose to delete uploaded images of the photo Library once a day
        // or immediately if there is no pending upload request, if any
        let (uploadIDs, localIdentifiers) = UploadProvider().getIDsOfCompletedUploads(onlyDeletable: true, inContext: self.uploadBckgContext)
        UploadManager.logger.notice("Resuming uploads: \(uploadIDs.count) assets for deletion in the Photo Library")
        let deadline = DateUtilities.nextDayAt4AM(after: UploadVars.shared.dateOfLastPhotoLibraryDeletion)
        if uploadIDs.isEmpty == false && (nberOfPendingUploads == 0 || Date.now > deadline) {
            // Store date of proposed deletion
            UploadVars.shared.dateOfLastPhotoLibraryDeletion = Date().timeIntervalSinceReferenceDate
            
            // Suggest to delete assets from the Photo Library
            let objectURIs = uploadIDs.map({ $0.uriRepresentation().absoluteString + "," }).reduce("",+)
            let localIDs = localIdentifiers.map({ $0 + "," }).reduce ("",+)
            let userInfo: [String : Any] = ["objectURIs" : objectURIs,
                                            "localIDs"   : localIDs];
            NotificationCenter.default.post(name: .pwgDeleteUploadRequestsAndAssets,
                                            object: nil, userInfo: userInfo)
            // Code below crashes with Xcode 26.2 (17C52)
//            Task { @MainActor in
//                await self.deleteAssets(associatedToUploads: uploadIDs, localIdentifiers)
//            }
        }
        
        // Append auto-upload requests if requested and restart activities
        if UploadVars.shared.isAutoUploadActive {
            await self.appendAutoUploadRequests()
        } else {
            await self.disableAutoUpload()
        }
        
        // Launch upload activities if needed
        await UploadManagerActor.shared.processNextUpload()
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
    public func clearAllFailedUploads() async {
        // Get active upload tasks
        var activeUploadIDs: Set<String> = []
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
            activeUploadIDs.insert(objectURIstr)
            let objectIDstr = URL(string: objectURIstr)?.lastPathComponent ?? objectURIstr
            UploadManager.logger.notice("\(objectIDstr) • Detected task \(task.taskIdentifier) uploading chunk \(chunk)/\(chunks)")
            self.initIfNeededCounter(withID: objectIDstr, chunk: chunk, chunks: chunks)
        }
        
        // Will retry inactive uploads marked "uploading", and those which returned an error
        let states: [pwgUploadState] = [.preparingError, .uploading, .uploadingError, .finishing, .finishingError]
        let (uploadIDs, _) = UploadProvider().getIDsOfPendingUploads(onlyInStates: states, inContext: self.uploadBckgContext)
        let toResumeUploadIDs = uploadIDs.filter({ !activeUploadIDs.contains($0.uriRepresentation().absoluteString) })
        let (toPrepare, toTransfer) = UploadProvider().clearFailedUploads(toResumeUploadIDs, inContext: self.uploadBckgContext)
        
        // First retry transfers
        if toTransfer.isEmpty == false {
            await UploadManagerActor.shared.addUploadsToTransfer(withIDs: toTransfer)
            UploadManager.logger.notice("Resuming uploads: \(toTransfer.count, privacy: .public) failed uploads to rety")
        }

        // Next retry preparations
        if toPrepare.isEmpty == false {
            await UploadManagerActor.shared.addUploadsToPrepare(withIDs: toPrepare)
            UploadManager.logger.notice("Resuming uploads: \(toPrepare.count, privacy: .public) failed uploads to rety")
        }
    }
    
    public func clearFailedUpload(withID uploadID: NSManagedObjectID) async {
        // Clear failed upload
        let (toPrepare, toTransfer) = UploadProvider().clearFailedUploads([uploadID], inContext: self.uploadBckgContext)

        // First retry transfers
        if toTransfer.isEmpty == false {
            await UploadManagerActor.shared.addUploadsToTransfer(withIDs: toTransfer, beforeOthers: true)
            UploadManager.logger.notice("Resuming uploads: \(toTransfer.count, privacy: .public) failed uploads to rety")
        }

        // Next retry preparations
        if toPrepare.isEmpty == false {
            await UploadManagerActor.shared.addUploadsToPrepare(withIDs: toPrepare, beforeOthers: true)
            UploadManager.logger.notice("Resuming uploads: \(toPrepare.count, privacy: .public) failed uploads to rety")
        }
    }
    
    
    // MARK: - Delete Upload Requests
    public func deleteUploadsOfDeletedImages(withIDs imageIDs: [Int64]) {
        if imageIDs.isEmpty { return }
        
        // Collect upload requests of deleted images
        // but keep auto-upload requests so that they are not re-uploaded
        var toDeleteIDs: Set<NSManagedObjectID> = Set( UploadProvider().getIDsOfPendingUploads(onlyImages: imageIDs, inContext: self.uploadBckgContext).0 )
        toDeleteIDs.formUnion(UploadProvider().getIDsOfCompletedUploads(onlyImages: imageIDs, onlyDeletable: true, inContext: self.uploadBckgContext).0)
                
        // Delete uploads
        try? UploadProvider().deleteUploads(withID: Array(toDeleteIDs))
        
        // Update counter and app badge
        self.updateNberOfUploadsToComplete()
    }
    
    public func deleteImpossibleUploads() {
        // Collect failed uploads
        let states: [pwgUploadState] = [.preparingFail, .formatError,
                                        .uploadingFail, .finishingFail]
        let toDeleteUploadIDs = UploadProvider().getIDsOfPendingUploads(onlyInStates: states, inContext: self.uploadBckgContext).0
        
        // Delete uploads
        try? UploadProvider().deleteUploads(withID: Array(toDeleteUploadIDs))
        
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

