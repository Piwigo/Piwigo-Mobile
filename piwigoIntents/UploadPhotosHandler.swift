//
//  AutoUploadPhotosHandler.swift
//  piwigoIntents
//
//  Created by Eddy Lelièvre-Berna on 03/06/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import CoreData
import Foundation
import piwigoKit
import uploadKit

@available(iOSApplicationExtension 13.0, *)
class UploadPhotosHandler: NSObject, UploadPhotosIntentHandling {
    
    // MARK: - Core Data Object Contexts
    @MainActor
    private lazy var mainContext: NSManagedObjectContext = {
        return DataController.shared.mainContext
    }()
    

    // MARK: - Core Data Providers
    lazy var uploadProvider: UploadProvider = {
        let provider = UploadProvider.shared
        return provider
    }()

    
    // MARK: - Handle Intent
    func handle(intent: UploadPhotosIntent, completion: @escaping (UploadPhotosIntentResponse) -> Void)
    {
        // Collect photos
        let files = intent.files ?? []
        if files.count == 0 {
            completion(UploadPhotosIntentResponse.success(nberPhotos: NSNumber(value: 0)))
        }
        
        // Check files compatibility with server
        var selectedFiles = [URL]()
        let fileTypes = NetworkVars.shared.serverFileTypes
        for index in 0..<files.count {
            guard let fileUrl = files[index].fileURL else { continue }
            debugPrint("••> \(String(describing: files[index].typeIdentifier))")
            if fileTypes.contains(fileUrl.pathExtension.lowercased()) {

                // Delete file of same name in Uploads directory if it already exists (incomplete previous attempt?)
                let fileUploadsUrl = UploadManager.shared.uploadsDirectory
                    .appendingPathComponent(fileUrl.lastPathComponent)
                do { try FileManager.default.removeItem(at: fileUploadsUrl) } catch { }

                // Copy file content to Uploads directory (forbidden copy/move file)
                if FileManager.default.createFile(atPath: fileUploadsUrl.path, contents: files[index].data, attributes: nil) {
                    selectedFiles.append(fileUploadsUrl)
                }
            }
        }
        if selectedFiles.count == 0 {
            completion(UploadPhotosIntentResponse.failure(error: "All files were rejected because their formats are not accepted by the Piwigo server."))
            return
        }
        
        // We collect the list of images in the upload queue
        // so that we can check which ones are already in the upload queue.
        let uploadsInQueue: [String] = uploadProvider.getAllMd5sum()

        // Get date of action for preparing identifier
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd-HHmmssSSSS"
        let actionDateTime = dateFormatter.string(from: Date())

        // Loop over all provided objects
        /// Intents images are identified with identifiers of the type "Intent-yyyyMMdd-HHmmssSSSS-typ-#" where:
        /// - "Intent" is a header telling that the image/video comes from the intent
        /// - "yyyyMMdd-HHmmssSSSS" is the date at which the objects were retrieved
        /// - "typ" is "img" for this intent
        /// - "#" is the index of the object in the pasteboard
        var selectedImages = [UploadProperties]()      // Array of images to upload
        for idx in 0..<selectedFiles.count {
            // Determine MD5 checksum
            let error: Error?, md5Sum: String!
            (md5Sum, error) = selectedFiles[idx].MD5checksum()
            if let error = error {
                // Could not determine the MD5 checksum
                completion(UploadPhotosIntentResponse.failure(error: error.localizedDescription))
                return
            }

            // Check if this file is already in the upload queue (might be slow)
            if let _ = uploadsInQueue.first(where: { $0 == md5Sum }) {
                // This file is already in the upload queue -> next file
                continue
            }
            
            // Set file URL in Uploads directory
            let identifier = String(format: "%@%@%@%ld", UploadManager.shared.kIntentPrefix,
                                    actionDateTime, UploadManager.shared.kImageSuffix, idx)
            let fileUploadsUrl = UploadManager.shared.uploadsDirectory
                .appendingPathComponent(identifier)

            // Delete file if it already exists (incomplete previous attempt?)
            do { try FileManager.default.removeItem(at: fileUploadsUrl) } catch { }

            // Copy file to Uploads directory
            do {
                try FileManager.default.copyItem(at: selectedFiles[idx], to: fileUploadsUrl)
            } catch {
                // The file could not be copied -> abandon it; next file
                continue
            }
            
            // Create the upload request
            let categoryId = UploadVars.shared.autoUploadCategoryId
            var uploadProperties = UploadProperties(localIdentifier: identifier, category: categoryId)
            uploadProperties.md5Sum = md5Sum
            uploadProperties.fileName = selectedFiles[idx].lastPathComponent
            uploadProperties.resizeImageOnUpload = false
            uploadProperties.compressImageOnUpload = false
            if let title = intent.title {
                uploadProperties.imageTitle = title
            }
            selectedImages.append(uploadProperties)
        }

        // Any image left for uploading?
        if selectedImages.count == 0 {
            completion(UploadPhotosIntentResponse.success(nberPhotos: NSNumber(value: 0)))
            return
        }

        // Add selected images to upload queue
        uploadProvider.importUploads(from: selectedImages) { error in
            // Show an alert if there was an error.
            guard let error = error else {
                // Create the operation queue
                let uploadQueue = OperationQueue()
                uploadQueue.maxConcurrentOperationCount = 1
                
                // Add operation setting flag and selecting upload requests
                let initOperation = BlockOperation {
                    // Initialse variables and determine upload requests to prepare and transfer
                    UploadManager.shared.initialiseBckgTask(triggeredByExtension: true)
                }

                // Initialise list of operations
                var uploadOperations = [BlockOperation]()
                uploadOperations.append(initOperation)

                // Resume transfers
                let resumeOperation = BlockOperation {
                    // Transfer image
                    UploadManager.shared.resumeTransfers()
                }
                resumeOperation.addDependency(uploadOperations.last!)
                uploadOperations.append(resumeOperation)

                // Add image preparation which will be followed by transfer operations
                for _ in 0..<UploadVars.shared.maxNberOfUploadsPerBckgTask {
                    let uploadOperation = BlockOperation {
                        // Transfer image
                        UploadManager.shared.appendUploadRequestsToPrepareToBckgTask()
                    }
                    uploadOperation.addDependency(uploadOperations.last!)
                    uploadOperations.append(uploadOperation)
                }
                
                // Inform the system that the background task is complete
                // when the operation completes
                let lastOperation = uploadOperations.last!
                lastOperation.completionBlock = {
                    debugPrint("••> Task completed with success.")
                    // Save cached data in the main thread
                    DispatchQueue.main.async {
                        self.mainContext.saveIfNeeded()
                    }
                }

                // Start the operations
                debugPrint("••> Start upload operations in background task...");
                uploadQueue.addOperations(uploadOperations, waitUntilFinished: false)

                // Inform user that the shortcut was excuted with success
                completion(UploadPhotosIntentResponse.success(nberPhotos: NSNumber(value: selectedImages.count)))
                return
            }
            
            // Error encountered…
            DispatchQueue.main.async {
                let errorMsg = String(format: "%@: %@", NSLocalizedString("CoreDataFetch_UploadCreateFailed", comment: "Failed to create a new Upload object."), error.localizedDescription)
                completion(UploadPhotosIntentResponse.failure(error: errorMsg))
            }
        }
    }
}
