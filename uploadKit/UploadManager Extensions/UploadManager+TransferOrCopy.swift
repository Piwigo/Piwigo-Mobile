//
//  UploadManager+TransferOrCopy.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 21/05/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import BackgroundTasks
import CoreData
import piwigoKit

@UploadManagerActor
extension UploadManager {
    
    // MARK: - Transfer or Copy Image/Video
    public func transferOrCopyFileOfUpload(withID uploadID: NSManagedObjectID) async {
        
        // Retrieve upload request in context of actor
        guard let upload = try? self.uploadBckgContext.existingObject(with: uploadID) as? Upload
        else {
            debugPrint("!!!! Could not retrieve upload for ID: \(uploadID.uriRepresentation().lastPathComponent) !!!!")
            return
        }
        
        // Check upload status
        if upload.state == .uploaded {
            // Finish transfer
            await finishTransferOfUpload(withID: uploadID)
            return
        }
        guard upload.state == .prepared
        else {
            UploadManager.logger.notice("\(upload.objectID.uriRepresentation().lastPathComponent) • Upload in wrong state '\(upload.stateLabel)' before transfer/copy")
            return
        }
        
        // Is this image already stored on the Piwigo server?
        do {
            // Check user entity
            guard let user = upload.user else {
                // Should never happen
                // ► The lounge will be emptied later by the server
                // ► Stop upload task and return an error
                throw PwgKitError.missingUploadParameter
            }

            // Check that the MD5 checksum is known
            if upload.md5Sum.isEmpty {
                throw PwgKitError.missingAsset
            }
            
            // Update state of upload request
            UploadManager.logger.notice("\(uploadID.uriRepresentation().lastPathComponent) • Transfer or copy file?")
            upload.setState(.uploading)
            upload.managedObjectContext?.saveIfNeeded()
            
            // Open session before verifying if the image is already on the server
            try await JSONManager.shared.checkSession(ofUserWithID: user.objectID, lastConnected: user.lastUsed)
            
            // Check whether an image with that MD5 checksum exists on the server
            if let imageID = try await JSONManager.shared.getIDofImage(withMD5: upload.md5Sum) {
                // Already stored on the Piwigo server ► Copy to Album
                try await copyImageWithID(imageID, for: upload)
            }
            else {
                // Upload new image to the Piwigo server
                try await transferInBackground(for: upload)
            }
        }
        catch let error as PwgKitError {
            if error.failedAuthentication {
                upload.setState(.uploadingFail, error: error)
                upload.managedObjectContext?.saveIfNeeded()
            }
            else {
                switch error {
                case .emptyUsername:
                    upload.setState(.uploadingError, error: error)
                    
                case .missingAsset, .missingUploadData, .fileOperationFailed,
                     .missingUploadParameter, .wrongServerURL:
                    fallthrough
                default:
                    upload.setState(.uploadingFail, error: error)
                }
                upload.managedObjectContext?.saveIfNeeded()
            }
        }
        catch {
            let pwgError = PwgKitError.otherError(innerError: error)
            upload.setState(.uploadingFail, error: pwgError)
            upload.managedObjectContext?.saveIfNeeded()
        }
    }
    
    func copyImageWithID(_ imageID: Int64, for upload: Upload) async throws(PwgKitError) {
        // Get complete image data
        try await ImageProvider().getInfos(forID: imageID, inCategoryId: upload.category)
        
        // Update UploadQueue cell and button shown in root album (or default album)
        let localIdentifier = upload.localIdentifier
        await MainActor.run {
            let uploadInfo: [String : Any] = ["localIdentifier" : localIdentifier,
                                              "progressFraction" : 0.5]
            NotificationCenter.default.post(name: .pwgUploadProgress, object: nil, userInfo: uploadInfo)
        }
        
        // Get image and album objects in cache
        guard let imageSet = try? ImageProvider().getImages(inContext: self.uploadBckgContext, withIds: Set([imageID])),
              let imageData = imageSet.first, let albums = imageData.albums, let user = upload.user,
              let albumData = try? AlbumProvider().getAlbum(ofUser: user, withId: upload.category)
        else { throw PwgKitError.missingAsset }

        // Append selected category ID to image category list
        var categoryIds = Set(albums.compactMap({$0.pwgID}))
        let categoryCount = categoryIds.count
        categoryIds.insert(upload.category)
        
        // Check if the category already contains that image
        if categoryIds.count == categoryCount {
            // Update UploadQueue cell and button shown in root album (or default album)
            await MainActor.run {
                let uploadInfo: [String : Any] = ["localIdentifier" : localIdentifier,
                                                  "progressFraction" : 1.0]
                NotificationCenter.default.post(name: .pwgUploadProgress, object: nil, userInfo: uploadInfo)
            }
            
            // Job done
            upload.imageId = imageID
            upload.setState(.moderated)
            upload.managedObjectContext?.saveIfNeeded()
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
        await MainActor.run {
            // Update UploadQueue cell and button shown in root album (or default album)
            let uploadInfo: [String : Any] = ["localIdentifier" : localIdentifier,
                                              "progressFraction" : 1.0]
            NotificationCenter.default.post(name: .pwgUploadProgress, object: nil, userInfo: uploadInfo)
        }
        
        // Update cache
        if let album = try? uploadBckgContext.existingObject(with: albumData.objectID) as? Album,
           let image = try? uploadBckgContext.existingObject(with: imageData.objectID) as? Image {

            // Add image to album
            album.addToImages(image)

            // Update albums
            try? AlbumProvider().updateAlbums(addingImages: 1, toAlbum: album)
        }
        
        // Copy complete
        upload.imageId = imageID
        upload.setState(.moderated)
        upload.managedObjectContext?.saveIfNeeded()
    }
    
    
    // MARK: - Utilities
    nonisolated func createBoundary(from identifier: String) -> String {
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

    nonisolated func convertFormField(named name: String, value: String, using boundary: String) -> String {
      var fieldString = "--\(boundary)\r\n"
      fieldString += "Content-Disposition: form-data; name=\"\(name)\"\r\n"
      fieldString += "\r\n"
      fieldString += "\(value)\r\n"

      return fieldString
    }
    
    nonisolated func convertFileData(fieldName: String, fileName: String, mimeType: String,
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
