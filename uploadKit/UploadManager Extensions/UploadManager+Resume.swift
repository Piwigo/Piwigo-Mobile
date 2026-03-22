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
        guard NetworkVars.shared.fixUserIsAPIKeyV412 == false,
              UploadVars.shared.didResumeAll == false
        else { return }
        
        // Wait until continued background task finishes
//        guard UploadVars.shared.isExecutingBGContinuedUploadTask == false
//        else { return }
        
        // Reset flags
        UploadVars.shared.isPaused = false
        UploadVars.shared.didResumeAll = true
        
        // Delete upload requests of assets that have become unavailable,
        // except non-completed requests from intent and clipboard
        deleteUploadsOfAssetsThatAreNoLongerAvailable()
        
        // Get Upload URI strings of active transfers
        let activeUploadsURIstr = await getUploadURIsOfTransfers()
        
        // Clear upload requests which encountered an error
        let (_,_) = await clearFailedUploads(except: activeUploadsURIstr)
        
        // Store number, update badge and default album view button
        let nberOfPendingUploads = UploadProvider().getCountOfPendingUploads(inContext: self.uploadBckgContext)
        DispatchQueue.main.async {
            // Update app badge and button of root album (or default album)
            let uploadInfo: [String : Any] = ["nberOfUploadsToComplete" : nberOfPendingUploads]
            NotificationCenter.default.post(name: .pwgLeftUploads, object: nil, userInfo: uploadInfo)
        }
        
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
        suggestToDeleteUploadedImages(withPendingUploads: nberOfPendingUploads)
        
        // Append auto-upload requests if requested and restart activities
        if UploadVars.shared.isAutoUploadActive {
            await self.appendAutoUploadRequests()
        } else {
            await self.disableAutoUpload()
        }
        
        // Launch upload activities if needed
        await UploadManagerActor.shared.processNextUpload()
    }
    
    public func getUploadURIsOfTransfers() async -> Set<String> {
        // Get active upload tasks
        var activeUploadsURIstr: Set<String> = []
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
        let states: [pwgUploadState] = [.preparingError, .uploading, .uploadingError, .finishing, .finishingError]
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
            UploadManager.logger.notice("Resuming uploads: \(toTransfer.count, privacy: .public) failed uploads to rety")
        }

        // Next retry preparations
        if toPrepare.isEmpty == false {
            await UploadManagerActor.shared.addUploadsToPrepare(withIDs: toPrepare, beforeOthers: true)
            UploadManager.logger.notice("Resuming uploads: \(toPrepare.count, privacy: .public) failed uploads to rety")
        }

        // Process next uploads if possible
        await UploadManagerActor.shared.processNextUpload()
    }
    
    
    // MARK: - Delete Upload Requests
    private func deleteUploadsOfAssetsThatAreNoLongerAvailable() {
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
    
    public func deleteImpossibleUploads() {
        // Collect failed uploads
        let states: [pwgUploadState] = [.preparingFail, .formatError,
                                        .uploadingFail, .finishingFail]
        let toDeleteUploadIDs = UploadProvider().getIDsOfPendingUploads(onlyInStates: states, inContext: self.uploadBckgContext).0
        
        // Delete uploads
        try? UploadProvider().deleteUploads(withID: Array(toDeleteUploadIDs), inContext: self.uploadBckgContext)
        
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
