//
//  UploadManager+Foreground.swift
//  PwgUploadKit
//
//  Created by Eddy Lelièvre-Berna on 20/02/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import CoreData
import Foundation
import Photos
import PwgKit
import PwgCacheKit

@UploadManagerActor
extension UploadManager
{
    // MARK: - Resume in the Foreground
    public func resumeInForeground() async
    {
        // Wait until fix and background tasks are completed
        guard ServerVars.shared.fixUserIsAPIKeyV412 == false,
              UploadVars.shared.didResumeUploads == false,
              UploadVars.shared.isProcessingTaskActive == false,
              UploadVars.shared.isContinuedProcessingTaskActive == false
        else {
            UploadManager.logger.notice("Will not resume uploads (\(UploadVars.shared.didResumeUploads), \(UploadVars.shared.isProcessingTaskActive), \(UploadVars.shared.isContinuedProcessingTaskActive))")
            return
        }
        
        /// Uncomment below line to debug BGProcessingTask
//        return
        
        // Reset flags
        UploadVars.shared.isPaused = false
        UploadVars.shared.didResumeUploads = true
        
        // Logs
        if #available(iOS 17.0, *) {
            UploadManager.logger.notice("Resuming uploads: with priority \(Task.currentPriority)")
        }
        
        // Delete upload requests of assets that have become unavailable,
        // except non-completed requests from intent, clipboard and share extension
        deleteUploadsOfAssetsThatAreNoLongerAvailable()
        
        // Get Upload URI strings of active transfers
        let activeUploadsURIstr = await getUploadURIsOfTransfers()
        
        // Clear upload requests which encountered an error
        let (_,_) = await clearFailedUploads(except: activeUploadsURIstr)
        
        // Store number, update badge and default album view button
        self.updateNberOfUploadsToComplete()
        
        // Get IDs of uploads to finish
        let toFinish = UploadProvider().getIDsOfPendingUploads(onlyInStates: [.uploaded], inContext: self.uploadBckgContext).0
        await UploadManagerActor.shared.addUploadsToFinish(withIDs: toFinish)
        
        // Get IDs of uploads to transfer
        let toTransfer = UploadProvider().getIDsOfPendingUploads(onlyInStates: [.prepared], inContext: self.uploadBckgContext).0
        await UploadManagerActor.shared.addUploadsToTransfer(withIDs: toTransfer)
        
        // Append auto-upload requests if requested
        if UploadVars.shared.isAutoUploadActive {
            await self.appendAutoUploadRequests(inBckgTask: false)
        } else {
            await self.disableAutoUpload(inBckgTask: false)
        }
        
        // Append uploads to prepare
        let toPrepare = UploadProvider().getIDsOfPendingUploads(onlyInStates: [.waiting], inContext: self.uploadBckgContext).0
        await UploadManagerActor.shared.addUploadsToPrepare(withIDs: toPrepare)
        UploadManager.logger.notice("Resuming uploads: \(toFinish.count) transfer(s) to finish, \(toTransfer.count) file(s) to transfer, \(toPrepare.count) upload(s) to prepare")
        
        // Propose to delete uploaded images of the photo Library once a day
        // or immediately if there is no pending upload request, if any
        suggestToDeleteUploadedImages(withPendingUploads: UploadVars.shared.nberOfUploadsToComplete)
        
        // Launch upload activities if needed
        await UploadManagerActor.shared.processNextUpload()
    }
    
    public func getUploadURIsOfTransfers() async -> Set<String> {
        // Get active upload tasks
        var activeUploadsURIstr: Set<String> = []
        let allTasks = await UploadSessionManager.shared.allTasks()
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
            activeUploadsURIstr.insert(objectURIstr)
            let objectIDstr = URL(string: objectURIstr)?.lastPathComponent ?? objectURIstr
            UploadManager.logger.notice("\(objectIDstr) • Detected task \(task.taskIdentifier) uploading chunk \(chunk)/\(chunks)")
            self.initIfNeededCounter(withID: objectIDstr, chunk: chunk, chunks: chunks)
        }
        return activeUploadsURIstr
    }
    
    
    // MARK: - Clear Failed Uploads
    func suggestToDeleteUploadedImages(withPendingUploads nberOfPendingUploads: Int) {
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
    }
        
    public func clearFailedUploads(except activeUploadsURIstr: Set<String>) async -> ([NSManagedObjectID], [NSManagedObjectID]) {
        // Will retry inactive uploads marked "uploading", and those which returned an error
        let states: [pwgUploadState] = [.preparing, .preparingError, .uploading, .uploadingError, .finishing, .finishingError]
        let (uploadIDs, _) = UploadProvider().getIDsOfPendingUploads(onlyInStates: states, inContext: self.uploadBckgContext)
        let toResumeUploadIDs = uploadIDs.filter({ !activeUploadsURIstr.contains($0.uriRepresentation().absoluteString) })
        return UploadProvider().clearFailedUploads(toResumeUploadIDs, inContext: self.uploadBckgContext)
    }
    
    public func clearFailedUpload(withID uploadID: NSManagedObjectID) async -> ([NSManagedObjectID], [NSManagedObjectID]) {
        // Clear upload request error
        return UploadProvider().clearFailedUploads([uploadID], inContext: self.uploadBckgContext)
    }
    
    public func resumeUploads(toTransfer: [NSManagedObjectID], andToPrepare toPrepare: [NSManagedObjectID]) async {
        // First retry transfers
        if toTransfer.isEmpty == false {
            await UploadManagerActor.shared.addUploadsToTransfer(withIDs: toTransfer, beforeOthers: true)
            UploadManager.logger.notice("Resuming uploads: \(toTransfer.count) failed uploads to retry")
        }

        // Next retry preparations
        if toPrepare.isEmpty == false {
            await UploadManagerActor.shared.addUploadsToPrepare(withIDs: toPrepare, beforeOthers: true)
            UploadManager.logger.notice("Resuming uploads: \(toPrepare.count) failed uploads to retry")
        }

        // Process next uploads if possible
        #if os(iOS) && !targetEnvironment(macCatalyst)
        if #available(iOS 26.0, *) {
            // Launch new continued upload task if possible
            if UploadVars.shared.isContinuedProcessingTaskActive == false {
                UploadManager.shared.runContinuedUploadTask()
            }
        }
        else {
            // Process next uploads if possible
            await UploadManagerActor.shared.processNextUpload()
        }
        #elseif targetEnvironment(macCatalyst)
        // Process next uploads if possible
        await UploadManagerActor.shared.processNextUpload()
        #endif
    }
    
    
    // MARK: - Delete Upload Requests
    private func deleteUploadsOfAssetsThatAreNoLongerAvailable() {
        let states: [pwgUploadState] = [.waiting, .preparingError]
        let (objectIDs, localIDs) = UploadProvider().getIDsOfPendingUploads(onlyInStates: states, inContext: self.uploadBckgContext)

        // Only uploads of Photo Library assets can become unavailable. Requests created by
        // the intent, the pasteboard or the share extension refer to files stored in the
        // Uploads directory, not to PHAssets, and must be left untouched.
        let candidates = zip(objectIDs, localIDs).filter { _, localID in
            localID.hasPrefix(kIntentPrefix) == false &&
            localID.hasPrefix(kClipboardPrefix) == false &&
            localID.hasPrefix(kSharedPrefix) == false
        }
        if candidates.isEmpty { return }

        // Fetch assets which are still available
        let options = PHFetchOptions()
        options.includeHiddenAssets = false
        let availableAssets = PHAsset.fetchAssets(withLocalIdentifiers: candidates.map(\.1), options: options)
        var availableIDs = Set<String>()
        availableAssets.enumerateObjects { asset, _, _ in
            availableIDs.insert(asset.localIdentifier)
        }

        // Delete upload requests whose asset is not available anymore
        let toDeleteIDs = candidates.filter { availableIDs.contains($0.1) == false }.map(\.0)
        if toDeleteIDs.isEmpty { return }
        try? UploadProvider().deleteUploads(withID: toDeleteIDs, inContext: self.uploadBckgContext)
    }
    
    public func deleteUploadsOfDeletedImages(withIDs imageIDs: [Int64]) {
        // Collect upload requests of deleted images
        // but keep auto-upload requests so that they are not re-uploaded
        let toDeleteIDs = UploadProvider().getIDsOfCompletedUploads(onlyImages: imageIDs, notAutoUploaded: true, inContext: self.uploadBckgContext).0
        
        // Delete uploads
        try? UploadProvider().deleteUploads(withID: toDeleteIDs, inContext: self.uploadBckgContext)
        
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
    
    public func disableDeleteAfterUpload(_ uploadIDs: [NSManagedObjectID]) {
        // Empty array?
        guard uploadIDs.isEmpty == false
        else { return }
        
        // Update upload requests
        var uploadDataToUpdate: [(NSManagedObjectID,UploadProperties)] = []
        uploadIDs.forEach { uploadID in
            if var uploadData = try? UploadProvider().getPropertiesOfUpload(withID: uploadID, inContext: self.uploadBckgContext) {
                uploadData.deleteImageAfterUpload = false
                uploadDataToUpdate.append((uploadID, uploadData))
            }
        }
        uploadDataToUpdate.forEach { (uploadID, uploadData) in
            try? UploadProvider().updateUpload(withID: uploadID, properties: uploadData, inContext: self.uploadBckgContext)
        }
    }
}
