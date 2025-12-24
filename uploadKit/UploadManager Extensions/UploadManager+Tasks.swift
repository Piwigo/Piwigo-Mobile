//
//  UploadManager+Tasks.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 23/02/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import CoreData
import Foundation
import piwigoKit

extension UploadManager
{
    // MARK: - Foreground Task Manager
    // Images are uploaded as follows:
    /// - Photos are prepared with appropriate metadata in a format accepted by the server
    /// - Videos are exported in MP4 fomat and uploaded if the VideoJS plugin is installed
    /// - Images are uploaded with one of the following methods:
    ///      - pwg.images.upload: old method unable to set the image title
    ///        This requires a call to pwg.images.setInfo to set the title after the transfer.
    ///      - pwg.images.uploadAsync: new method accepting asynchroneous calls
    ///        and setting all parameters like pwg.images.setInfo.
    ///
    /// - Uploads can also be performed in the background with the method pwg.images.uploadAsync
    ///   and the BackgroundTasks farmework
//    @available(iOS, introduced: 13.0, obsoleted: 26.0, message:  "Use the BGContinuedProcessingTask instead")
    public func findNextImageToUpload() -> Void {
        // Perform fetches
        do {
            try uploads.performFetch()
            try completed.performFetch()
        }
        catch {
            debugPrint("••> Could not fetch pending uploads: \(error.localizedDescription)")
        }

        // Update counter and app badge
        self.updateNberOfUploadsToComplete()

        // Pause upload manager if:
        /// - app not in the foreground anymore
        /// - executing a background task
        /// - in Low Power mode
        /// - Wi-Fi required but unavailable
        if UploadVars.shared.isPaused ||
            UploadVars.shared.isExecutingBGUploadTask ||
//            UploadVars.shared.isExecutingBGContinuedUploadTask ||
            ProcessInfo.processInfo.isLowPowerModeEnabled ||
            (UploadVars.shared.wifiOnlyUploading && !NetworkVars.shared.isConnectedToWiFi) {
            return
        }
        
        // Check current queue
        let fetchedUploads = uploads.fetchedObjects ?? []
        UploadManager.logger.notice("findNextImageToUpload() in \(queueName(), privacy: .public), \(fetchedUploads.count, privacy: .public) pending and \((self.completed.fetchedObjects ?? []).count, privacy: .public) completed upload requests, preparing:\(self.isPreparing ? "Yes" : "No", privacy: .public), uploading: \(self.isUploading.count, privacy: .public), finishing:\(self.isFinishing ? "Yes" : "No", privacy: .public)")
        
        // for debugging background tasks
//        return

        // Interrupted work should be set as if an error was encountered
        /// - case of finishing uploads
        let finishing = fetchedUploads.filter({$0.state == .finishing})
        if !isFinishing, finishing.count > 0 {
            // Transfers encountered an error
            finishing.forEach({ upload in
                upload.setState(.finishingError, error: .networkUnavailable, save: false)
            })
            uploadBckgContext.saveIfNeeded()
            findNextImageToUpload()
            return
        }
        /// - case of transfers (a few transfers may be running in parallel)
        let uploading = fetchedUploads.filter({$0.state == .uploading})
        if isUploading.isEmpty == false, uploading.count > 0 {
            for upload in uploading {
                if isUploading.contains(upload.objectID) == false {
                    // Transfer encountered an error
                    upload.setState(.uploadingError, error: .networkUnavailable, save: true)
                    findNextImageToUpload()
                }
            }
            return
        }
        /// - case of upload preparation
        let preparing = fetchedUploads.filter({$0.state == .preparing})
        if isPreparing == false, preparing.count > 0 {
            // Preparations encountered an error
            preparing.forEach { upload in
                upload.setState(.preparingError, error: .missingAsset, save: false)
            }
            uploadBckgContext.saveIfNeeded()
            findNextImageToUpload()
            return
        }
        
        // How many upload requests did fail?
        let failedUploads = fetchedUploads
            .filter({[.preparingError, .preparingFail,
                      .uploadingError, .uploadingFail].contains($0.state)}).count
        
        // Too many failures?
        if failedUploads >= maxNberOfFailedUploads {
            return
        }
        
        // Not finishing and upload request to finish?
        /// Called when:
        /// - uploading with pwg.images.upload because the title cannot be set during the upload.
        /// - uploading with pwg.images.uploadAsync to empty the lounge as from the version 12 of the Piwigo server.
        if !isFinishing,
           let uploaded = fetchedUploads.first(where: {$0.state == .uploaded}) {
            
            // Pause upload manager if the app is not in the foreground anymore
            if UploadVars.shared.isPaused {
                return
            }
            
            // Upload file ready, so we start the transfer
            self.finishTransfer(of: uploaded)
            return
        }
        
        // Not transferring and file ready for transfer?
        if isUploading.count < maxNberOfTransfers,
           let prepared = fetchedUploads.first(where: {$0.state == .prepared}) {
            
            // Pause upload manager if the app is not in the foreground anymore
            if UploadVars.shared.isPaused {
                return
            }
            
            // Upload file ready, so we start the transfer
            Task { @UploadManagement in
                launchTransfer(of: prepared)
            }
            return
        }
        
        // Not preparing and upload request waiting?
        let nberPrepared = fetchedUploads.filter({$0.state == .prepared}).count
        if !isPreparing, nberPrepared < maxNberPreparedUploads,
           let waiting = fetchedUploads.first(where: {$0.state == .waiting}) {
            
            // Pause upload manager if the app is not in the foreground anymore
            if UploadVars.shared.isPaused {
                return
            }
            
            // Prepare the next upload
            Task { @UploadManagement in
                await prepare(waiting)
            }
            return
        }
        
        // No more image to transfer ;-)
        // Moderate images uploaded by Community regular user
        // Considers only uploads to the server to which the user is logged in
        let finished = fetchedUploads.filter({$0.state == .finished})
        if NetworkVars.shared.userStatus == .normal,
           NetworkVars.shared.usesCommunityPluginV29, finished.count > 0 {
            
            // Pause upload manager if the app is not in the foreground anymore
            if UploadVars.shared.isPaused {
                return
            }
            
            // Moderate uploaded images
            self.moderateCompletedUploads(finished)
            return
        }
        
        // Suggest to delete images from the Photo Library if the user wanted it.
        // The deletion is suggested when there is no more upload to perform.
        // Note that some uploads may have failed and wait a user decision.
        let states: [pwgUploadState] = [.waiting, .preparing, .prepared,
                                        .uploading, .uploaded, .finishing]
        if fetchedUploads.filter({states.contains($0.state)}).count > 0 { return }
        
        // Upload requests are completed
        // Considers only uploads to the server to which the user is logged in
        // Are there images to delete from the Photo Library?
        let uploadsToDelete = (completed.fetchedObjects ?? [])
            .filter({$0.deleteImageAfterUpload == true})
            .filter({isDeleting.contains($0.objectID) == false})
        let uploadIDs = uploadsToDelete.map(\.objectID)
        let uploadLocalIDs = uploadsToDelete.map(\.localIdentifier)
        deleteAssets(associatedToUploads: uploadIDs, uploadLocalIDs)
    }
    
    func moderateCompletedUploads(_ uploads: [Upload]) -> Void
    {
        // Get list of categories
        let categories: Set<Int32> = Set(uploads.map({$0.category}))
        if categories.isEmpty { return }

        // Check user entity
        guard let user = uploads.first?.user else {
            // Should never happen
            // ► The moderator will be informed later
            return
        }

        // Moderate images by category
        JSONManager.shared.checkSession(ofUser: user) {
            for categoryId in categories {
                // Set list of images to moderate in that category
                let categoryImages = uploads.filter({$0.category == categoryId})
                let imageIds = String(categoryImages.map({ "\($0.imageId)," }).reduce("", +).dropLast())
                
                // Moderate uploaded images
                self.moderateImages(withIds: imageIds, inCategory: categoryId) { (success, validatedIDs) in
                    if !success { return }    // Will retry later
                    
                    // Update state of upload requests
                    categoryImages.forEach({$0.setState(.moderated, save: true)})
                    
                    // Delete image in Photo Library if wanted
                    let uploadsToDelete = categoryImages.filter({$0.deleteImageAfterUpload == true})
                        .filter({validatedIDs.contains($0.imageId)})
                    let uploadIDs = uploadsToDelete.map(\.objectID)
                    let uploadLocalIDs = uploadsToDelete.map(\.localIdentifier)
                    self.deleteAssets(associatedToUploads: uploadIDs, uploadLocalIDs)
                }
            }
        } failure: { _ in }
    }
    
    
    // MARK: - Background Upload Task Manager
    /* Images are uploaded sequentially with BackgroundTasks.
     - getUploadRequests() returns a series of upload requests to deal with
     - photos and videos are prepared sequentially to reduce the memory needs
     - uploads are launched in the background with the method pwg.images.uploadAsync
       and the BackgroundTasks farmework
     - The number of bytes to be transferred is calculated and limited.
     - A delay is set between series of upload tasks to prevent server overloads
     - Failing tasks are automatically retried by iOS
     For testing the background task:
     - Uncomment the 'return' line at the beginning of findNextImageToUpload()
     - Build and run the app, then background it to schedule the task.
     - Bring the app to the foreground again. Then in Xcode, hit the pause button in the debugger and type one of the commands
     - e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"org.piwigo.uploadManager"]
     - e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateExpirationForTaskWithIdentifier:@"org.piwigo.uploadManager"]
     */
    public func initialiseBckgTask(autoUploadOnly: Bool = false,
                                   triggeredByExtension: Bool = false) async -> Void {
        // Perform fetch
        do {
            try uploads.performFetch()
        }
        catch {
            debugPrint("Error: \(error.localizedDescription)")
        }
        
        // Update counter and app badge
        self.updateNberOfUploadsToComplete()
        
        // Append auto-upload requests if not called by In-App intent or Extension
        if UploadVars.shared.isAutoUploadActive && !triggeredByExtension {
            appendAutoUploadRequests()
        }
        
        // Reset flags and requests to prepare and transfer
        isUploading = Set<NSManagedObjectID>()
        uploadRequestsToPrepare = Set<NSManagedObjectID>()
        uploadRequestsToTransfer = Set<NSManagedObjectID>()
        
        // First, find upload requests whose transfer did fail
        let states: [pwgUploadState] = [.preparingError, .preparingFail,
                                        .uploadingError, .uploadingFail]
        let failedUploads = (uploads.fetchedObjects ?? [])
            .filter({states.contains($0.state) && $0.markedForAutoUpload == autoUploadOnly})
        
        // Too many failures?
        if failedUploads.count >= maxNberOfFailedUploads { return }
        
        // Will retry a few…
        if failedUploads.count > 0 {
            // Will relaunch transfers with one which failed
            uploadRequestsToTransfer = Set(failedUploads.map({$0.objectID}))
            UploadManager.logger.notice("initialiseBckgTask() collected \(self.uploadRequestsToTransfer.count, privacy: .public) failed uploads")
        }
        
        // Second, find upload requests ready for transfer
        let preparedUploads = (uploads.fetchedObjects ?? [])
            .filter({$0.state == .prepared && $0.markedForAutoUpload == autoUploadOnly})
        if preparedUploads.count > 0 {
            // Will then launch transfers of prepared uploads
            let prepared = preparedUploads.map({$0.objectID})
            uploadRequestsToTransfer = uploadRequestsToTransfer
                .union(Set(prepared[..<min(UploadVars.shared.maxNberOfUploadsPerBckgTask,prepared.count)]))
            UploadManager.logger.notice("initialiseBckgTask() collected \(min(UploadVars.shared.maxNberOfUploadsPerBckgTask, prepared.count), privacy: .public) prepared uploads")
        }
        
        // Finally, get list of upload requests to prepare
        let diff = maxNberPreparedUploads - uploadRequestsToTransfer.count
        if diff <= 0 { return }
        let requestsToPrepare = (uploads.fetchedObjects ?? [])
            .filter({$0.state == .waiting && $0.markedForAutoUpload == autoUploadOnly})
        UploadManager.logger.notice("initialiseBckgTask() collected \(min(diff, requestsToPrepare.count), privacy: .public) uploads to prepare")
        let toPrepare = requestsToPrepare.map({$0.objectID})
        uploadRequestsToPrepare = Set(toPrepare[..<min(diff, toPrepare.count)])
    }
    
    public func resumeTransfers() async -> Void {
        // Get active upload tasks and initialise isUploading
        frgdSession.getAllTasks { [unowned self] uploadTasks in
            // Loop over the tasks launched in the foreground
            Task { @UploadManagement in
                for task in uploadTasks {
                    switch task.state {
                    case .running:
                        // Retrieve upload request properties
                        guard let objectURIstr = task.originalRequest?.value(forHTTPHeaderField: pwgHTTPuploadID),
                              let objectURI = URL(string: objectURIstr),
                              let uploadID = UploadManager.shared.uploadBckgContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: objectURI)
                        else {
                            UploadManager.logger.notice("resumeTransfers(): Foreground task \(task.taskIdentifier) not associated to an upload!")
                            continue
                        }
                        
                        // Remembers that this upload request is being dealt with
                        UploadManager.logger.notice("resumeTransfers(): Foreground task \(task.taskIdentifier, privacy: .public) is uploading: \(uploadID)")
                        UploadManager.shared.isUploading.insert(uploadID)
                        
                        // Avoids duplicates
                        UploadManager.shared.uploadRequestsToTransfer.remove(uploadID)
                        UploadManager.shared.uploadRequestsToPrepare.remove(uploadID)
                        
                    default:
                        continue
                    }
                }
            }
            
            // Continue with background tasks
            bckgSession.getAllTasks { [unowned self] uploadTasks in
                // Loop over the tasks
                Task { @UploadManagement in
                    for task in uploadTasks {
                        switch task.state {
                        case .running:
                            // Retrieve upload request properties
                            guard let objectURIstr = task.originalRequest?.value(forHTTPHeaderField: pwgHTTPuploadID),
                                  let objectURI = URL(string: objectURIstr),
                                  let uploadID = UploadManager.shared.uploadBckgContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: objectURI)
                            else {
                                UploadManager.logger.notice("resumeTransfers(): Background task \(task.taskIdentifier) not associated to an upload!")
                                continue
                            }
                            
                            // Remembers that this upload request is being dealt with
                            UploadManager.logger.notice("resumeTransfers(): Background task \(task.taskIdentifier, privacy: .public) is uploading: \(uploadID)")
                            self.isUploading.insert(uploadID)
                            
                            // Avoids duplicates
                            UploadManager.shared.uploadRequestsToTransfer.remove(uploadID)
                            UploadManager.shared.uploadRequestsToPrepare.remove(uploadID)
                            
                        default:
                            continue
                        }
                    }
                    
                    // Relaunch transfers if necessary and possible
                    if self.isUploading.count < maxNberOfTransfers,
                       let uploadID = self.uploadRequestsToTransfer.first,
                       let upload = (uploads.fetchedObjects ?? []).first(where: {$0.objectID == uploadID}) {
                        // Launch transfer
                        launchTransfer(of: upload)
                    }
                }
            }
        }
    }
    
    public func appendUploadRequestsToPrepareToBckgTask() async -> Void {
        // Add image preparation followed by transfer operations
        if UploadVars.shared.isExecutingBGUploadTask {
            // Fallback on previous version
            if countOfBytesPrepared < UInt64(maxCountOfBytesToUpload),
               let uploadID = uploadRequestsToPrepare.first,
               let upload = (uploads.fetchedObjects ?? []).first(where: {$0.objectID == uploadID}) {
                // Prepare image for transfer
                await prepare(upload)
            }
//        } else if UploadVars.shared.isExecutingBGContinuedUploadTask {
//            if let uploadID = uploadRequestsToPrepare.first,
//               let upload = (uploads.fetchedObjects ?? []).first(where: {$0.objectID == uploadID}) {
//                // Prepare image for transfer
//                await prepare(upload)
//            }
        }
        if uploadRequestsToPrepare.isEmpty == false {
            // Remove objectID
            uploadRequestsToPrepare.removeFirst()
        }
    }
    

    // MARK: - Delete Upload Requests
    public func deleteUploadsOfDeletedImages(withIDs imageIDs: [Int64]) {
        if imageIDs.isEmpty { return }
        // Collect upload requests of deleted images
        var toDelete = (uploads.fetchedObjects ?? []).filter({imageIDs.contains($0.imageId)})
        toDelete.append(contentsOf: (completed.fetchedObjects ?? []).filter({imageIDs.contains($0.imageId)}))
        // Keep auto-upload requests so that they are not re-uploaded
        toDelete.removeAll(where: {$0.markedForAutoUpload == true})
        let uploadIDsToDelete = Set(toDelete.map(\.objectID))
        UploadProvider().delete(uploadsWithID: Array(uploadIDsToDelete)) { _ in }
    }
    
    public func deleteImpossibleUploads() {
        let states: [pwgUploadState] = [.preparingFail, .formatError,
                                        .uploadingFail, .finishingFail]
        let toDelete = (uploads.fetchedObjects ?? []).filter({states.contains($0.state)})
        let uploadIDsToDelete = Set(toDelete.map(\.objectID))
        UploadProvider().delete(uploadsWithID: Array(uploadIDsToDelete)) { _ in
            self.updateNberOfUploadsToComplete()
        }
    }
}
