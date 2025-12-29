//
//  UploadManager+Transfer.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 21/05/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import BackgroundTasks
import CoreData
@preconcurrency import piwigoKit

extension UploadManager {
    
    // MARK: - Transfer Image if Necessary
    public func launchTransfer(of upload: Upload) -> Void {
        UploadManager.logger.notice("\(upload.objectID.uriRepresentation().absoluteString) • Launch transfer of \(upload.fileName, privacy: .public)")
        
        // Update list of transfers
        if isUploading.contains(upload.objectID) {
            return
        }
        isUploading.insert(upload.objectID)

        // Check user entity
        guard let user = upload.user else {
            // Should never happen
            // ► The lounge will be emptied later by the server
            // ► Stop upload task and return an error
            upload.setState(.uploadingError, error: .emptyUsername, save: true)
            self.didEndTransfer(for: upload)
            return
        }

        // Check that the MD5 checksum is known
        if upload.md5Sum.isEmpty {
            upload.setState(.uploadingFail, error: .missingAsset, save: true)
            self.didEndTransfer(for: upload)
            return
        }
        
        // Update state of upload request
        upload.setState(.uploading, save: true)
        
        // Is this image already stored on the Piwigo server?
        Task {
            do {
                // Check session
                try await JSONManager.shared.checkSession(ofUserWithID: user.objectID, lastConnected: user.lastUsed)
                
                // Check whether an image with that MD5 checksum exists on the server
                let imageID = try await JSONManager.shared.getIDofImage(withMD5: upload.md5Sum)
                Task { @UploadManagerActor in
                    if let imageID {
                        // Already stored on the Piwigo server ► Copy to Album
                        await self.copyImageWithID(imageID, for: upload)
                    } else {
                        // Upload new image to the Piwigo server
                        await self.transfertImage(for: upload)
                    }
                }
            }
            catch let error as PwgKitError {
                Task { @UploadManagerActor in
                    if error.failedAuthentication {
                        upload.setState(.uploadingFail, error: error, save: true)
                    } else {
                        upload.setState(.uploadingError, error: error, save: true)
                    }
                    self.uploadBckgContext.saveIfNeeded()
                    self.didEndTransfer(for: upload)
                }
            }
        }
    }
    
    func copyImageWithID(_ imageID: Int64, for upload: Upload) async {
        // Retrieve image data from the Piwigo server, storing in cache
        do {
            // Check session
            guard let userID = upload.user?.objectID,
                  let lastUsed = upload.user?.lastUsed
            else {
                Task { @UploadManagerActor in
                    upload.setState(.uploadingError, error: .missingUploadData, save: true)
                    self.uploadBckgContext.saveIfNeeded()
                    self.didEndTransfer(for: upload)
                }
                return
            }
            try await JSONManager.shared.checkSession(ofUserWithID: userID, lastConnected: lastUsed)
            
            // Get complete image data
            try await ImageProvider().getInfos(forID: imageID, inCategoryId: upload.category)
            
            // Update UploadQueue cell and button shown in root album (or default album)
            let uploadLocalID = upload.localIdentifier
            await MainActor.run {
                let uploadInfo: [String : Any] = ["localIdentifier" : uploadLocalID,
                                                  "progressFraction" : 0.5]
                NotificationCenter.default.post(name: .pwgUploadProgress, object: nil, userInfo: uploadInfo)
            }

            // Get image and album objects in cache
            Task { @UploadManagerActor in
                guard let imageSet = try? ImageProvider().getImages(inContext: self.uploadBckgContext, withIds: Set([imageID])),
                      let imageData = imageSet.first, let albums = imageData.albums, let user = upload.user,
                      let albumData = try? AlbumProvider().getAlbum(ofUser: user, withId: upload.category)
                else {
                    upload.setState(.uploadingFail, error: .missingAsset, save: true)
                    self.uploadBckgContext.saveIfNeeded()
                    self.didEndTransfer(for: upload)
                    return
                }

                // Append selected category ID to image category list
                var categoryIds = Set(albums.compactMap({$0.pwgID}))
                let categoryCount = categoryIds.count
                categoryIds.insert(upload.category)
                
                // Check if the category already contains that image
                if categoryIds.count == categoryCount {
                    // Update UploadQueue cell and button shown in root album (or default album)
                    let uploadLocalID = upload.localIdentifier
                    DispatchQueue.main.async {
                        let uploadInfo: [String : Any] = ["localIdentifier" : uploadLocalID,
                                                          "progressFraction" : 1.0]
                        NotificationCenter.default.post(name: .pwgUploadProgress, object: nil, userInfo: uploadInfo)
                    }
                    
                    // Job done
                    upload.imageId = imageID
                    upload.setState(.moderated, save: true)
                    self.uploadBckgContext.saveIfNeeded()
                    self.didEndTransfer(for: upload)
                    return
                }

                // Prepare parameters for copying the image/video to the selected category
                let newImageCategories = categoryIds.compactMap({ String($0) }).joined(separator: ";")
                let paramsDict: [String : Any] = ["image_id"            : imageData.pwgID,
                                                  "categories"          : newImageCategories,
                                                  "multiple_value_mode" : "replace"]
                
                // Copy image
                try await JSONManager.shared.setInfos(with: paramsDict)

                // Update cache and UI
                let uploadLocalID = upload.localIdentifier
                let albumDataID = albumData.objectID
                let imageDataID = imageData.objectID
                await MainActor.run {
                    // Update UploadQueue cell and button shown in root album (or default album)
                    let uploadInfo: [String : Any] = ["localIdentifier" : uploadLocalID,
                                                      "progressFraction" : 1.0]
                    NotificationCenter.default.post(name: .pwgUploadProgress, object: nil, userInfo: uploadInfo)
                    
                    // Update cached data
                    Task { @UploadManagerActor in
                        // Update cache
                        if let album = try? uploadBckgContext.existingObject(with: albumDataID) as? Album,
                           let image = try? uploadBckgContext.existingObject(with: imageDataID) as? Image {

                            // Add image to album
                            album.addToImages(image)

                            // Update albums
                            try? AlbumProvider().updateAlbums(addingImages: 1, toAlbum: album)
                        }
                        
                        // Copy complete
                        upload.imageId = imageID
                        upload.setState(.moderated, save: true)
                        self.uploadBckgContext.saveIfNeeded()
                        self.didEndTransfer(for: upload)
                    }
                }
            }
        }
        catch let error {
            Task { @UploadManagerActor in
                upload.setState(.uploadingError, error: error, save: true)
                self.uploadBckgContext.saveIfNeeded()
                self.didEndTransfer(for: upload)
            }
        }
    }
    
    func transfertImage(for upload: Upload) async {
        // Initialise or reset counter of progress bar in case we repeat the transfer
        initCounter(withID: upload.objectID.uriRepresentation().absoluteString)
        
        // Choose recent method when called by:
        /// - admins as from Piwigo server 11 or previous versions with the uploadAsync plugin installed.
        /// - Community users as from Piwigo 12.
        if NetworkVars.shared.usesUploadAsync ||
            UploadVars.shared.isExecutingBGUploadTask /* ||
            UploadVars.shared.isExecutingBGContinuedUploadTask */ {
            // Prepare transfer
            self.transferInBackground(for: upload)
        } else {
            // Transfer image
            await self.transferInForeground(for: upload)
        }
        
        // Do not prepare next image in background tasks (already scheduled)
        if UploadVars.shared.isExecutingBGUploadTask /* ||
            UploadVars.shared.isExecutingBGContinuedUploadTask */ { return }
        
        // Stop here if there no image to prepare
        let waiting = (uploads.fetchedObjects ?? []).filter({$0.state == .waiting})
        if waiting.isEmpty { return }

        // Should we prepare the next image in parallel?
        let states: [pwgUploadState] = [.preparingError, .preparingFail,
                                        .uploadingError, .uploadingFail,
                                        .finishingError]
        let failed = (uploads.fetchedObjects ?? []).filter({states.contains($0.state)})
        if !isPreparing, failed.count < maxNberOfFailedUploads,
           let upload = waiting.first {

            // Prepare the next upload
            isPreparing = true
            Task { @UploadManagerActor in
                await prepare(upload)
            }
        }
    }
    
    
    // MARK: - Transfer Failed/Completed
    func didEndTransfer(for upload: Upload, taskID: Int = Int.max) {
        UploadManager.logger.notice("\(upload.objectID.uriRepresentation().absoluteString) • Did end transfer")
        
        // Error?
        if upload.requestError.isEmpty == false {
            UploadManager.logger.notice("\(upload.objectID.uriRepresentation().absoluteString) • Task \(taskID) returned \(upload.requestError)")
            // Cancel related tasks
            if taskID != Int.max {
                let objectURIstr = upload.objectID.uriRepresentation().absoluteString
                UploadSessionsDelegate.shared.cancelTasksOfUpload(withID: objectURIstr,
                                                                  exceptedTaskID: taskID
                )
            }

            // Consider next image?
            self.didEndTransfer(for: upload)
            return
        }

        // Consider next image?
        self.didEndTransfer(for: upload)
    }
    
    func didEndTransfer(for upload: Upload) {
        // Update list of current uploads
        if let index = isUploading.firstIndex(where: {$0 == upload.objectID}) {
            isUploading.remove(at: index)
        }
        
        // Pursue the work…
        if UploadVars.shared.isExecutingBGUploadTask /* ||
            UploadVars.shared.isExecutingBGContinuedUploadTask */ {
            finishTransfer(of: upload)
        }
        else if !isPreparing, isUploading.count <= maxNberOfTransfers, !isFinishing {
            // In foreground, always consider next file
            findNextImageToUpload()
        }
    }

    
    // MARK: - Utilities
    func createBoundary(from identifier: String) -> String {
        /// We don't use the UUID to be able to test uploads with a simulator.
        var suffix = ""
        if #available(iOS 16.0, *) {
            suffix = identifier.replacing("/", with: "").map { $0.lowercased() }.joined()
        } else {
            // Fallback on earlier versions
            suffix = identifier.replacingOccurrences(of: "/", with: "").map { $0.lowercased() }.joined()
        }
        let boundary = String(repeating: "-", count: 68 - suffix.count) + suffix
//        debugPrint("\(dbg()) \(boundary)")
        return boundary
    }

    func convertFormField(named name: String, value: String, using boundary: String) -> String {
      var fieldString = "--\(boundary)\r\n"
      fieldString += "Content-Disposition: form-data; name=\"\(name)\"\r\n"
      fieldString += "\r\n"
      fieldString += "\(value)\r\n"

      return fieldString
    }
    
    func convertFileData(fieldName: String, fileName: String, mimeType: String,
                         fileData: Data, using boundary: String) -> Data {
        var data = Data()
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        data.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        data.append(fileData)
        data.append("\r\n".data(using: .utf8)!)
        return data
    }
}
