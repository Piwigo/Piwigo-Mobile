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
@preconcurrency import piwigoKit

extension UploadManager
{
    // MARK: - Resume Uploads
    public func resumeAll() -> Void {
        // Wait until fix completed
        guard NetworkVars.shared.fixUserIsAPIKeyV412 == false
        else { return }
        
        // Wait until continued background task finishes
//        guard UploadVars.shared.isExecutingBGContinuedUploadTask == false
//        else { return }
        
        // Reset flags
        UploadVars.shared.isPaused = false
        isPreparing = false; isFinishing = false
        UploadVars.shared.isExecutingBGUploadTask = false
        isUploading = Set<NSManagedObjectID>()
        
        // Reset predicates in case user switched to another Piwigo
        let variables = ["serverPath" : NetworkVars.shared.serverPath,
                         "userName"   : NetworkVars.shared.user]
        uploads.fetchRequest.predicate = pendingPredicate.withSubstitutionVariables(variables)
        completed.fetchRequest.predicate = completedPredicate.withSubstitutionVariables(variables)

        // Perform fetches
        do {
            try uploads.performFetch()
            try completed.performFetch()
        }
        catch {
            debugPrint("••> Could not fetch pending uploads: \(error.localizedDescription)")
        }

        // Get active upload tasks
        bckgSession.getAllTasks { uploadTasks in
            // Loop over the tasks
            Task { @UploadManagerActor in
                for task in uploadTasks {
                    switch task.state {
                    case .running:
                        // Retrieve upload request properties
                        guard let objectURIstr = task.originalRequest?.value(forHTTPHeaderField: pwgHTTPuploadID),
                              let objectURI = URL(string: objectURIstr),
                              let uploadID = self.uploadBckgContext.persistentStoreCoordinator?
                                .managedObjectID(forURIRepresentation: objectURI)
                        else {
                            UploadManager.logger.notice("Task \(task.taskIdentifier, privacy: .public) not associated to an upload!")
                            continue
                        }
                        
                        // Task associated to an upload
                        UploadManager.logger.notice("Task \(task.taskIdentifier, privacy: .public) is uploading \(uploadID)")
                        self.isUploading.insert(uploadID)
                        
                    default:
                        continue
                    }
                }
                
                // Logs
                if let uploadObjects = self.uploads.fetchedObjects,
                   let completedObjects = self.completed.fetchedObjects {
                    UploadManager.logger.notice("\(uploadObjects.count, privacy: .public) pending and \(completedObjects.count, privacy: .public) completed upload requests in cache.")
                }
                
                // Resume operations
                self.resumeOperations()
            }
        }
    }
    
    private func resumeOperations() {
        // Resume failed uploads
        self.resumeAllFailedUploads()
        
        // Propose to delete uploaded image of the photo Library once a day
        if Date().timeIntervalSinceReferenceDate > UploadVars.shared.dateOfLastPhotoLibraryDeletion + TimeInterval(86400) {
            // Are there images to delete from the Photo Library?
            let uploadsToDelete = (completed.fetchedObjects ?? [])
                .filter({$0.deleteImageAfterUpload == true})
                .filter({isDeleting.contains($0.objectID) == false})
            if uploadsToDelete.count > 0 {
                // Store date of deletion
                UploadVars.shared.dateOfLastPhotoLibraryDeletion = Date().timeIntervalSinceReferenceDate
                
                // Suggest to delete assets from the Photo Library
                UploadManager.logger.notice("\(uploadsToDelete.count, privacy: .public) assets identified for deletion from the Photo Library.")
                let uploadIDs = uploadsToDelete.map(\.objectID)
                let uploadLocalIDs = uploadsToDelete.map(\.localIdentifier)
                deleteAssets(associatedToUploads: uploadIDs, uploadLocalIDs)
            }
        }
        
        // Delete upload requests of assets that have become unavailable,
        // except non-completed requests from intent and clipboard
        var toDelete = (uploads.fetchedObjects ?? [])
            .filter({!$0.localIdentifier.hasPrefix(kIntentPrefix)})
            .filter({!$0.localIdentifier.hasPrefix(kClipboardPrefix)})
        toDelete.append(contentsOf: completed.fetchedObjects ?? [])
        
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
        toDelete.append(contentsOf: (uploads.fetchedObjects ?? []).filter({$0.requestState == 13}))
        
        // Delete upload requests
        let uploadsToDate = Set(toDelete).map({$0.objectID})
        UploadProvider().delete(uploadsWithID: Array(uploadsToDate)) { [self] _ in
            // Restart activities
//            if #unavailable(iOS 26.0) {
                self.findNextImageToUpload()
//            }
            
            // Append auto-upload requests if requested
            if UploadVars.shared.isAutoUploadActive {
                self.appendAutoUploadRequests()
            } else {
                self.disableAutoUpload()
            }
        }
    }
    
    public func resumeAllFailedUploads() {
        // Considers all failed uploads to the server to which the user is logged in
        let states: [pwgUploadState] = [.preparingError, .uploadingError, .finishingError]
        let toResume = (self.uploads.fetchedObjects ?? []).filter({states.contains($0.state)})
        resumeFailedUploads(toResume)
    }
    
    public func resumeFailedUpload(withID localIdentifier: String) {
        // Look for upload request in UploadManager context
        if let upload = (self.uploads.fetchedObjects ?? []).first(where: {$0.localIdentifier == localIdentifier}) {
            resumeFailedUploads([upload])
        }
    }
    
    public func resumeFailedUploads(_ toResume: [Upload]) {
        // Loop over the failed uploads
        for failedUpload in toResume {
            switch failedUpload.state {
            case .uploading, .uploadingError, .uploaded:
                // -> Will retry to transfer the image
                failedUpload.setState(.prepared, save: false)
                // Update list of transfers
                isUploading.remove(failedUpload.objectID)

            case .finishing, .finishingError:
                // -> Will retry to finish the upload
                failedUpload.setState(.uploaded, save: false)
                // Reset finishing flag
                isFinishing = false
                
            default:
                // —> Will retry from scratch
                failedUpload.setState(.waiting, save: false)
                // Reset preparing flag
                isPreparing = false
            }
        }
    }
    
    
    // MARK: - Clean Photo Library
    public func deleteAssets(associatedToUploads uploadIDs: [NSManagedObjectID], _ uploadLocalIDs: [String] = [], and assetIDs: [String] = []) -> Void {
        // Remember which uploads are concerned to avoid duplicate deletions
        isDeleting = Set(uploadIDs)
        
        // Combine unique assets to delete
        var imageIDs = Set(uploadLocalIDs)
        imageIDs.formUnion(assetIDs)
        let assetsToDelete = PHAsset.fetchAssets(withLocalIdentifiers: Array(imageIDs), options: nil)
        if assetsToDelete.count == 0 {
            // Assets already deleted
            self.deleteUploadsInRightQueue(uploadIDs)
            return
        }
        
        // Delete images from Photo Library
        DispatchQueue.main.async {
            PHPhotoLibrary.shared().performChanges {
                // Delete images from the library
                PHAssetChangeRequest.deleteAssets(assetsToDelete as (any NSFastEnumeration))
            }
            completionHandler: { success, error in
                Task { @UploadManagerActor in
                    if success {
                        self.deleteUploadsInRightQueue(uploadIDs)
                    } else {
                        self.disableDeleteAfterUpload(uploadIDs)
                    }
                }
            }
        }
    }
    
    private func deleteUploadsInRightQueue(_ uploadIDs: [NSManagedObjectID]) {
        // Empty array?
        if uploadIDs.isEmpty {
            self.isDeleting = Set()
            return
        }
        
        // Delete upload requests w/o reporting potential error
        UploadProvider().delete(uploadsWithID: uploadIDs) { _ in
            self.isDeleting = Set()
        }
    }
    
    private func disableDeleteAfterUpload(_ uploadIDs: [NSManagedObjectID]) {
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
