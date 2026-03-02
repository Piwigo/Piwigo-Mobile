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
        
        // Retrieve upload request properties
        guard var uploadData = try? UploadProvider().getPropertiesOfUpload(withID: uploadID, inContext: self.uploadBckgContext)
        else {
            // Process next upload if any
            UploadManager.logger.notice("\(uploadID.uriRepresentation().lastPathComponent) • Could not retrieve upload request for transfer/copy!")
            await UploadManagerActor.shared.processNextUpload()
            return
        }
        
        // Check upload status
        if uploadData.requestState == .uploaded {
            // Finish transfer
            await finishTransferOfUpload(withID: uploadID)
            return
        }
        guard uploadData.requestState == .prepared
        else {
            // Process next upload if any
            UploadManager.logger.notice("\(uploadID.uriRepresentation().lastPathComponent) • Upload in wrong state '\(uploadData.stateLabel)' before transfer/copy")
            await UploadManagerActor.shared.processNextUpload()
            return
        }
        
        // Is this image already stored on the Piwigo server?
        do {
            // Check that the MD5 checksum is known
            if uploadData.md5Sum.isEmpty {
                throw PwgKitError.missingAsset
            }
            
            // Update state of upload request
            uploadData.requestState = .uploading
            UploadManager.logger.notice("\(uploadID.uriRepresentation().lastPathComponent) • Transfer or copy file?")
            try? UploadProvider().updateUpload(withID: uploadID, properties: uploadData, inContext: self.uploadBckgContext)
            
            // Check whether an image with that MD5 checksum exists on the server
            if let imageID = try await JSONManager.shared.getIDofImage(withMD5: uploadData.md5Sum) {
                // Already stored on the Piwigo server ► Copy to Album
                try await copyImageWithID(imageID, for: uploadData)
            }
            else {
                // Upload new image to the Piwigo server
                try await transferInBackground(for: uploadData, withID: uploadID)
            }
        }
        catch let error as PwgKitError {
            if error.failedAuthentication {
                uploadData.requestState = .uploadingFail
                uploadData.requestError = error.localizedDescription
                try? UploadProvider().updateUpload(withID: uploadID, properties: uploadData, inContext: self.uploadBckgContext)
            }
            else {
                switch error {
                case .emptyUsername:
                    uploadData.requestState = .uploadingError
                    uploadData.requestError = error.localizedDescription
                    try? UploadProvider().updateUpload(withID: uploadID, properties: uploadData, inContext: self.uploadBckgContext)
                    
                case .missingAsset, .missingUploadData, .fileOperationFailed,
                     .missingUploadParameter, .wrongServerURL:
                    fallthrough
                default:
                    uploadData.requestState = .uploadingFail
                    uploadData.requestError = error.localizedDescription
                    try? UploadProvider().updateUpload(withID: uploadID, properties: uploadData, inContext: self.uploadBckgContext)
                }
            }
        }
        catch {
            uploadData.requestState = .uploadingFail
            uploadData.requestError = PwgKitError.otherError(innerError: error).localizedDescription
            try? UploadProvider().updateUpload(withID: uploadID, properties: uploadData, inContext: self.uploadBckgContext)
        }

        // Process next upload if any
        await UploadManagerActor.shared.processNextUpload()
    }
    
    func copyImageWithID(_ imageID: Int64, for properties: UploadProperties) async throws(PwgKitError) {
        // Get complete image data from server
//        try await ImageProvider().getInfos(forID: imageID, inCategoryId: properties.category)
//        
//        // Update UploadQueue cell and button shown in root album (or default album)
//        await MainActor.run {
//            let uploadInfo: [String : Any] = ["localIdentifier" : properties.localIdentifier,
//                                              "progressFraction" : 0.5]
//            NotificationCenter.default.post(name: .pwgUploadProgress, object: nil, userInfo: uploadInfo)
//        }
//
//        // Check user entity
//        guard let user = try? UserProvider().getUserAccount(inContext: self.uploadBckgContext)
//        else {
//            // Should never happen
//            // ► The lounge will be emptied later by the server
//            // ► Stop upload task and return an error
//            throw PwgKitError.missingUploadParameter
//        }
//        
//        // Open session before verifying if the image is already on the server
//        try await JSONManager.shared.checkSession(ofUserWithID: user.objectID, lastConnected: user.lastUsed)
        

        // Get image and album objects in cache
//        guard let imageSet = try? ImageProvider().getImages(inContext: self.uploadBckgContext, withIds: Set([imageID])),
//              let imageData = imageSet.first, let albums = imageData.albums, let user = upload.user,
//              let albumData = try? AlbumProvider().getAlbum(ofUser: user, withId: upload.category)
//        else { throw PwgKitError.missingAsset }
//
//        // Append selected category ID to image category list
//        var categoryIds = Set(albums.compactMap({$0.pwgID}))
//        let categoryCount = categoryIds.count
//        categoryIds.insert(upload.category)
//        
//        // Check if the category already contains that image
//        if categoryIds.count == categoryCount {
//            // Update UploadQueue cell and button shown in root album (or default album)
//            await MainActor.run {
//                let uploadInfo: [String : Any] = ["localIdentifier" : properties.localIdentifier,
//                                                  "progressFraction" : 1.0]
//                NotificationCenter.default.post(name: .pwgUploadProgress, object: nil, userInfo: uploadInfo)
//            }
//            
//            // Job done
//            do {
//                try UploadProvider().setUpload(withID: upload.objectID, inContext: self.uploadBckgContext, imageID: imageID, state: .moderated)
//            }
//            catch {
//                throw PwgKitError.CoreDataError(innerError: error as NSError)
//            }
//            return
//        }
//        
//        // Prepare parameters for copying the image/video to the selected category
//        let newImageCategories = categoryIds.compactMap({ String($0) }).joined(separator: ";")
//        let paramsDict: [String : Any] = ["image_id"            : imageData.pwgID,
//                                          "categories"          : newImageCategories,
//                                          "multiple_value_mode" : "replace"]
//        
//        // Copy image
//        try await JSONManager.shared.setInfos(with: paramsDict)
//
//        // Update cache and UI
//        await MainActor.run {
//            // Update UploadQueue cell and button shown in root album (or default album)
//            let uploadInfo: [String : Any] = ["localIdentifier" : localIdentifier,
//                                              "progressFraction" : 1.0]
//            NotificationCenter.default.post(name: .pwgUploadProgress, object: nil, userInfo: uploadInfo)
//        }
//        
//        // Update cache
//        if let album = try? uploadBckgContext.existingObject(with: albumData.objectID) as? Album,
//           let image = try? uploadBckgContext.existingObject(with: imageData.objectID) as? Image {
//
//            // Add image to album
//            album.addToImages(image)
//
//            // Update albums
//            try? AlbumProvider().updateAlbums(addingImages: 1, toAlbum: album)
//        }
//        
//        // Copy complete
//        do {
//            try UploadProvider().setUpload(withID: upload.objectID, inContext: self.uploadBckgContext, imageID: imageID, state: .moderated)
//        }
//        catch {
//            throw PwgKitError.CoreDataError(innerError: error as NSError)
//        }
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
