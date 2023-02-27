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

extension UploadManager
{
    // MARK: - Resume Uploads
    public func resumeAll() -> Void {
        // Reset flags
        isPaused = false
        isPreparing = false; isFinishing = false
        isExecutingBackgroundUploadTask = false
        isUploading = Set<NSManagedObjectID>()
        print("••> Resume upload operations…")
        
        // Perform fetch
        do {
            try uploads.performFetch()
            try completed.performFetch()
        }
        catch {
            print("••> Could not fetch pending uploads: \(error)")
        }
        
        // Get active upload tasks
        bckgSession.getAllTasks { uploadTasks in
            // Loop over the tasks
            for task in uploadTasks {
                switch task.state {
                case .running:
                    // Retrieve upload request properties
                    guard let objectURIstr = task.originalRequest?
                        .value(forHTTPHeaderField: UploadVars.HTTPuploadID) else { continue }
                    guard let objectURI = URL(string: objectURIstr) else {
                        print("\(self.dbg()) task \(task.taskIdentifier) | no object URI!")
                        continue
                    }
                    guard let uploadID = self.bckgContext.persistentStoreCoordinator?
                        .managedObjectID(forURIRepresentation: objectURI) else {
                        print("\(self.dbg()) task \(task.taskIdentifier) | no objectID!")
                        continue
                    }
                    print("\(self.dbg()) is uploading \(uploadID)")
                    self.isUploading.insert(uploadID)
                    
                default:
                    continue
                }
            }
            
            print("\(self.dbg()) \(self.uploads.fetchedObjects?.count ?? 0) pending upload requests in cache")
            print("\(self.dbg()) \(self.completed.fetchedObjects?.count ?? 0) completed upload requests in cache")
            // Resume operations
            self.resumeOperations()
        }
    }
    
    private func resumeOperations() {
        // Resume failed uploads
        self.resume(failedUploads: nil)

        // Append auto-upload requests if requested
        if UploadVars.isAutoUploadActive {
            self.appendAutoUploadRequests()
        } else {
            self.disableAutoUpload()
        }
        
        // Propose to delete uploaded image of the photo Library once a day
        if Date().timeIntervalSinceReferenceDate > UploadVars.dateOfLastPhotoLibraryDeletion + UploadVars.pwgOneDay {
            // Are there images to delete from the Photo Library?
            let toDelete = completed.fetchedObjects?.filter({$0.deleteImageAfterUpload == true}) ?? []
            if toDelete.count > 0 {
                // Store date of last deletion
                UploadVars.dateOfLastPhotoLibraryDeletion = Date().timeIntervalSinceReferenceDate
                
                // Suggest to delete assets from the Photo Library
                print("\(dbg()) \(toDelete.count) upload requests should be deleted")
                deleteAssets(associatedToUploads: toDelete)
            }
        }
        
        // Delete upload requests of assets that have become unavailable,
        // except non-completed requests from intent and clipboard
        var toDelete = uploads.fetchedObjects?.filter({!$0.localIdentifier.hasPrefix(kIntentPrefix) && !$0.localIdentifier.hasPrefix(kClipboardPrefix)}) ?? []
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
        
        // Delete upload requests
        uploadProvider.delete(uploadRequests: toDelete) { [unowned self] _ in
            self.findNextImageToUpload()
        }
    }
    
    public func resume(failedUploads: [Upload]?) {
        // Resume failed uploads and pursue the work
        var failed: [Upload]
        if failedUploads == nil {
            // Considers all failed uploads to the server to which the user is logged in
            let states: [pwgUploadState] = [.preparingError, .uploadingError, .finishingError]
            failed = self.uploads.fetchedObjects?.filter({states.contains($0.state)}) ?? []
        } else {
            failed = failedUploads!
        }
        
        // Loop over the failed uploads
        for failedUpload in failed {
            switch failedUpload.state {
            case .uploadingError:
                // -> Will retry to transfer the image
                failedUpload.setState(.prepared, save: false)
            case .finishingError:
                // -> Will retry to finish the upload
                failedUpload.setState(.uploaded, save: false)
            default:
                // —> Will retry from scratch
                failedUpload.setState(.waiting, save: false)
            }
        }
        try? bckgContext.save()
    }
    
    
    // MARK: - Clean Photo Library
    public func deleteAssets(associatedToUploads uploads: [Upload]) -> Void {
        // Get image assets of images to delete
        if uploads.isEmpty { return }
        let uploadedImages = uploads.map({$0.localIdentifier})
        let assetsToDelete = PHAsset.fetchAssets(withLocalIdentifiers: uploadedImages, options: nil)
        if assetsToDelete.count == 0 { return }
        
        // Delete images from Photo Library
        print("\(dbg()) \(uploadedImages.count) assets should be deleted.")
        DispatchQueue.main.async {
            PHPhotoLibrary.shared().performChanges({
                // Delete images from the library
                PHAssetChangeRequest.deleteAssets(assetsToDelete as NSFastEnumeration)
            }, completionHandler: { [unowned self] success, error in
                if let taskContext = uploads.first?.managedObjectContext,
                   taskContext == bckgContext {
                    DispatchQueue.global(qos: .background).async { [unowned self] in
                        self.uploadProvider.delete(uploadRequests: uploads) { _ in }
                    }
                } else {
                    DispatchQueue.main.async {
                        self.uploadProvider.delete(uploadRequests: uploads) { _ in }
                    }
                }
            })
        }
    }
}
