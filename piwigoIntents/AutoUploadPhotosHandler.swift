//
//  AutoUploadPhotosHandler.swift
//  piwigoIntents
//
//  Created by Eddy Lelièvre-Berna on 03/06/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import CoreData
import Foundation
import Photos
import piwigoKit

@available(iOSApplicationExtension 13.0, *)
class AutoUploadPhotosHandler: NSObject, AutoUploadPhotosIntentHandling {
    
    // MARK: - Core Data
    /**
     The UploadsProvider that collects upload data, saves it to Core Data,
     and serves it to the uploader.
     */
    lazy var uploadsProvider: UploadsProvider = {
        let provider : UploadsProvider = UploadsProvider()
        return provider
    }()

    let maxNberOfUploadsPerBckgTask = 100             // i.e. 100 requests to be considered
    var isUploading = Set<NSManagedObjectID>()
    var uploadRequestsToPrepare = Set<NSManagedObjectID>()
    var uploadRequestsToTransfer = Set<NSManagedObjectID>()

    func handle(intent: AutoUploadPhotosIntent, completion: @escaping (AutoUploadPhotosIntentResponse) -> Void) {
        print("•••>> handling AutoUploadPhotos shortcut…")
        
        // Is auto-uploading enabled?
        if !UploadVars.isAutoUploadActive {
            let errorMsg = NSLocalizedString("AutoUploadError_Disabled",
                                             comment: "Auto-uploading is disabled in the app settings.")
            completion(AutoUploadPhotosIntentResponse.failure(error: errorMsg))
            return
        }
        
        // Append auto-upload requests
        let errorMsg = appendAutoUploadRequests()
        if !errorMsg.isEmpty {
            completion(AutoUploadPhotosIntentResponse.failure(error: errorMsg))
            return
        }
        
        // Reset flags and requests to prepare and transfer
        isUploading = Set<NSManagedObjectID>()
        uploadRequestsToPrepare = Set<NSManagedObjectID>()
        uploadRequestsToTransfer = Set<NSManagedObjectID>()

        // First, find upload requests whose transfer did fail
        let failedUploads = uploadsProvider.getAutoUploadRequestsIn(states: [.uploadingError]).1
        if failedUploads.count > 0, failedUploads.count < 2 {
            // Will relaunch transfers with one which failed
            uploadRequestsToTransfer = Set(failedUploads[..<min(maxNberOfUploadsPerBckgTask, failedUploads.count)])
            print("\(UploadUtilities.debugFormatter.string(from: Date())) >•• collected \(uploadRequestsToTransfer.count) failed uploads")
        }

        // Second, find upload requests ready for transfer
        let preparedUploads = uploadsProvider.getAutoUploadRequestsIn(states: [.prepared]).1
        if uploadRequestsToTransfer.count == 0, preparedUploads.count > 0 {
            // Will relaunch transfers with a prepared upload
            uploadRequestsToTransfer = uploadRequestsToTransfer
                .union(Set(preparedUploads[..<min(maxNberOfUploadsPerBckgTask,preparedUploads.count)]))
            print("\(UploadUtilities.debugFormatter.string(from: Date())) >•• collected \(min(maxNberOfUploadsPerBckgTask,preparedUploads.count)) prepared uploads)")
        }
        
        // Finally, get list of upload requests to prepare
        let diff = maxNberOfUploadsPerBckgTask - uploadRequestsToTransfer.count
        if diff <= 0 { return }
        let requestsToPrepare = uploadsProvider.getAutoUploadRequestsIn(states: [.waiting]).1
        print("\(UploadUtilities.debugFormatter.string(from: Date())) >•• collected \(min(diff, requestsToPrepare.count)) uploads to prepare")
        uploadRequestsToPrepare = Set(requestsToPrepare[..<min(diff, requestsToPrepare.count)])

        
        
        completion(AutoUploadPhotosIntentResponse.success(nberPhotos: 23))
    }


    // MARK: - Add Auto-Upload Requests
    private func appendAutoUploadRequests() -> String {
        // Check access to Photo Library album
        let collectionID = UploadVars.autoUploadAlbumId
        guard !collectionID.isEmpty,
           let collection = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [collectionID], options: nil).firstObject else {
            // Cannot access local album
            UploadVars.autoUploadAlbumId = ""               // Unknown source Photos album
            disableAutoUpload()
            let message = String(format: "%@: %@", NSLocalizedString("settings_autoUploadSourceInvalid", comment:"Invalid source album"), NSLocalizedString("settings_autoUploadSourceInfo", comment: "Please select the album or sub-album from which photos and videos of your device will be auto-uploaded."))
            return message
        }

        // Check existence of Piwigo album
        let categoryId = UploadVars.autoUploadCategoryId
        guard categoryId != NSNotFound else {
            // Cannot access local album
            UploadVars.autoUploadCategoryId = NSNotFound    // Unknown destination Piwigo album
            disableAutoUpload()
            let message = String(format: "%@: %@", NSLocalizedString("settings_autoUploadDestinationInvalid", comment:"Invalid destination album"), NSLocalizedString("settings_autoUploadSourceInfo", comment: "Please select the album or sub-album into which photos and videos will be auto-uploaded."))
            return message
        }

        // Collect IDs of images to upload
        let fetchOptions = PHFetchOptions()
        fetchOptions.includeHiddenAssets = false
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let fetchedImages = PHAsset.fetchAssets(in: collection, options: fetchOptions)
        if fetchedImages.count == 0 {
            // Nothing to add to the upload queue - Job done
            return ""
        }

        // Collect localIdentifiers of uploaded and not yet uploaded images in the Upload cache
        let states: [kPiwigoUploadState] = [.waiting, .preparing, .preparingError,
                                            .preparingFail, .formatError, .prepared,
                                            .uploading, .uploadingError, .uploaded,
                                            .finishing, .finishingError, .finished,
                                            .moderated, .deleted]
        let (imageIDs, _) = uploadsProvider.getAutoUploadRequestsIn(states: states)

        // Determine which local images are still not considered for upload
        var uploadRequestsToAppend = [UploadProperties]()
        let serverFileTypes = UploadVars.serverFileTypes
        fetchedImages.enumerateObjects { image, idx, stop in
            // Keep images which had never been considered for upload
            if !imageIDs.contains(image.localIdentifier) {
                // Rejects videos if the server cannot accept them
                if image.mediaType == .video {
                    // Retrieve image file extension (slow)
                    let fileName = UploadUtilities.fileName(forImageAsset: image)
                    let fileExt = (URL(fileURLWithPath: fileName).pathExtension).lowercased()
                    // Check file format
                    let unacceptedFileFormat = !serverFileTypes.contains(fileExt)
                    let mp4NotAccepted = !serverFileTypes.contains("mp4")
                    let notConvertible = !UploadUtilities.acceptedMovieFormats.contains(fileExt)
                    if unacceptedFileFormat && (mp4NotAccepted || notConvertible) { return }
                }

                // Format should be acceptable, create upload request
                var uploadRequest = UploadProperties(localIdentifier: image.localIdentifier,
                                                     category: categoryId)
                uploadRequest.markedForAutoUpload = true
                uploadRequest.tagIds = UploadVars.autoUploadTagIds
                uploadRequest.comment = UploadVars.autoUploadComments
                uploadRequestsToAppend.append(uploadRequest)
            }
        }

        // Are there images to upload?
        if uploadRequestsToAppend.count == 0 {
            // Nothing to add to the upload queue - Job done
            return ""
        }

        // Record upload requests in database
        uploadsProvider.importUploads(from: uploadRequestsToAppend.compactMap{ $0 }) {_ in }
        return ""
    }


    // MARK: - Delete Auto-Upload Requests
    private func disableAutoUpload() {
        // Disable auto-uploading
        UploadVars.isAutoUploadActive = false
        
        // Collect objectIDs of images being considered for auto-uploading
        let states: [kPiwigoUploadState] = [.waiting, .preparingError,
                                            .preparingFail, .formatError, .prepared,
                                            .uploadingError, .uploaded,
                                            .finishingError]
        let (_, objectIDs) = uploadsProvider.getAutoUploadRequestsIn(states: states)

        // Remove non-completed upload requests marked for auto-upload from the upload queue
        if !objectIDs.isEmpty {
            uploadsProvider.delete(uploadRequests: objectIDs) { error in
                // Job done
            }
        }
    }

    
    // MARK: Resume 
//    func resumeTransfersOfBckgTask() -> Void {
//        // Get active upload tasks and initialise isUploading
//        let taskContext = DataController.privateManagedObjectContext
//        let uploadSession: URLSession = UploadSessionDelegate.shared.uploadSession
//        uploadSession.getAllTasks { [unowned self] uploadTasks in
//            // Loop over the tasks
//            for task in uploadTasks {
//                switch task.state {
//                case .running:
//                    // Retrieve upload request properties
//                    guard let taskDescription = task.taskDescription else { continue }
//                    guard let objectURI = URL(string: taskDescription) else {
//                        print("\(UploadUtilities.debugFormatter.string(from: Date())) > task \(task.taskIdentifier) | no object URI!")
//                        continue
//                    }
//                    guard let uploadID = taskContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: objectURI) else {
//                        print("\(UploadUtilities.debugFormatter.string(from: Date())) > task \(task.taskIdentifier) | no objectID!")
//                        continue
//                    }
//                    // Remembers that this upload request is being dealt with
//                    print("\(UploadUtilities.debugFormatter.string(from: Date())) >> is uploading: \(uploadID)")
//                    // Remembers that this upload request is being dealt with
//                    self.isUploading.insert(uploadID)
//
//                    // Avoids duplicates
//                    uploadRequestsToTransfer.remove(uploadID)
//                    uploadRequestsToPrepare.remove(uploadID)
//
//                default:
//                    continue
//                }
//            }

            // Relaunch transfers if necessary and possible
//            if self.isUploading.count < maxNberOfTransfers,
//               let uploadID = self.uploadRequestsToTransfer.first {
//                // Launch transfer
//                print("\(UploadUtilities.debugFormatter.string(from: Date())) >•• launch transfer \(uploadID.uriRepresentation())")
//                self.launchTransfer(of: uploadID)
//            } else {
//                print("\(UploadUtilities.debugFormatter.string(from: Date())) >•• no transfer to launch")
//            }
//        }
//    }
}
