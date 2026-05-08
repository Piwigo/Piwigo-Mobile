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
    public func transferOrCopyFileOfUpload(withID uploadID: NSManagedObjectID,
                                           inTaskType taskType: UploadTaskType) async {
        
        // Retrieve upload request properties
        guard var uploadData = try? UploadProvider().getPropertiesOfUpload(withID: uploadID, inContext: self.uploadBckgContext)
        else {
            UploadManager.logger.notice("\(uploadID.uriRepresentation().lastPathComponent) • Could not retrieve upload request for transfer/copy!")
            // Should we process a next upload?
            if taskType.isForeground {
                await UploadManagerActor.shared.processNextUpload()
            }
            return
        }
        
        // Check upload status (should never happen)
        guard uploadData.requestState == .prepared
        else {
            UploadManager.logger.notice("\(uploadID.uriRepresentation().lastPathComponent) • Upload in wrong state '\(uploadData.stateLabel)' before transfer/copy")
            // In foreground, process next upload if any
            if taskType.isForeground {
                if uploadData.requestState == .uploaded {
                    await UploadManagerActor.shared.addUploadsToFinish(withIDs: [uploadID])
                }
                await UploadManagerActor.shared.processNextUpload()
            }
            return
        }
        
        // Is this image already stored on the Piwigo server?
        do {
            // Check that the MD5 checksum and user are known
            guard uploadData.md5Sum.isEmpty == false,
                  let userURI = URL(string: uploadData.userURIstr),
                  let userID = uploadBckgContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: userURI)
            else {
                throw PwgKitError.missingAsset
            }
            
            // Check session
            let userData = try UserProvider().getPropertiesOfUser(withURIstr: uploadData.userURIstr, inContext: self.uploadBckgContext)
            try await JSONManager.shared.checkSession(ofUserWithID: userID, lastConnected: userData.lastUsed)
            
            // Update state of upload request
            uploadData.requestState = .uploading
            uploadData.requestError = ""
            try? UploadProvider().updateUpload(withID: uploadID, properties: uploadData, inContext: self.uploadBckgContext)
            
            // Check whether an image with that MD5 checksum exists on the server
            if let imageID = try await JSONManager.shared.getIDofImage(withMD5: uploadData.md5Sum) {
                // Already stored on the Piwigo server ► Copy to Album
                UploadManager.logger.notice("\(uploadID.uriRepresentation().lastPathComponent) • Start copying file…")
                try await copyImageWithID(imageID, for: uploadData, withID: uploadID)
                
                // Copy completed
                uploadData.imageId = imageID
                uploadData.requestState = .moderated
                uploadData.requestError = ""
                try? UploadProvider().updateUpload(withID: uploadID, properties: uploadData, inContext: self.uploadBckgContext)
                
                // Update number of uploads to complete, badge and default album view button
                self.updateNberOfUploadsToComplete()
            }
            else {
                // Upload new image to the Piwigo server
                UploadManager.logger.notice("\(uploadID.uriRepresentation().lastPathComponent) • File transfer starting…")
                try await transferInBackground(for: uploadData, withID: uploadID, inTaskType: taskType)
            }
        }
        catch let error as PwgKitError {
            switch error {
            case .emptyUsername:
                uploadData.requestState = .uploadingError
                uploadData.requestError = error.localizedDescription
                try? UploadProvider().updateUpload(withID: uploadID, properties: uploadData, inContext: self.uploadBckgContext)
                
            case .authenticationFailed, .invalidCredentials,
                 .invalidStatusCode(statusCode: 401),
                 .invalidStatusCode(statusCode: 403):
                fallthrough
            case .missingAsset, .missingUploadData, .fileOperationFailed,
                 .missingUploadParameter, .wrongServerURL:
                fallthrough
            default:
                uploadData.requestState = .uploadingFail
                uploadData.requestError = error.localizedDescription
                try? UploadProvider().updateUpload(withID: uploadID, properties: uploadData, inContext: self.uploadBckgContext)
            }
        }
        catch {
            uploadData.requestState = .uploadingFail
            uploadData.requestError = PwgKitError.otherError(innerError: error).localizedDescription
            try? UploadProvider().updateUpload(withID: uploadID, properties: uploadData, inContext: self.uploadBckgContext)
        }
        
        // In foreground, process next upload if any
        if taskType.isForeground {
            await UploadManagerActor.shared.processNextUpload()
        }
    }
    
    func copyImageWithID(_ imageID: Int64, for properties: UploadProperties,
                         withID uploadID: NSManagedObjectID) async throws(PwgKitError)
    {
        // Update UploadQueue cell and button shown in root album (or default album)
        await MainActor.run {
            let uploadInfo: [String : Any] = ["localIdentifier" : properties.localIdentifier,
                                              "progressFraction" : 0.33]
            NotificationCenter.default.post(name: .pwgUploadProgress, object: nil, userInfo: uploadInfo)
        }
        
        // Retrieve complete image data from server
        let imageData = try await JSONManager.shared.getInfos(forID: imageID)
        
        // Should we associate the image to the album?
        var categoryIds = Set( (imageData.categories ?? []).compactMap({ $0.id }) )
        let (inserted, _) = categoryIds.insert(properties.category)
        
        // Update UploadQueue cell and button shown in root album (or default album)
        await MainActor.run {
            let uploadInfo: [String : Any] = ["localIdentifier" : properties.localIdentifier,
                                              "progressFraction" : 0.67]
            NotificationCenter.default.post(name: .pwgUploadProgress, object: nil, userInfo: uploadInfo)
        }
        
        // Associate the image to the album if needed
        if inserted {
            // Append selected category ID to image category list
            if NetworkVars.shared.usesSetCategory {
                // Associate images (since Piwigo 14)
                try await JSONManager.shared.setCategory(properties.category, forImageIDs: [imageID], withAction: .associate)
            }
            else {
                // Associate image "manually" (before Piwigo 14)
                // Prepare parameters for copying the image/video to the selected category
                let newImageCategories = categoryIds.compactMap({ String($0) }).joined(separator: ";")
                let paramsDict: [String : Any] = ["image_id"            : imageID,
                                                  "categories"          : newImageCategories,
                                                  "multiple_value_mode" : "replace"]
                
                // Copy image
                try await JSONManager.shared.setInfos(with: paramsDict)
            }
            
            // Retrieve image data from server and update cache
            try await ImageProvider().getInfos(forID: imageID, inCategoryId: properties.category)
            
            // Update displayed albums which are concerned
            try? AlbumProvider().updateAlbums(addingImages: 1, toAlbumWithID: properties.category,
                                             belongingToUser: properties.userURIstr,
                                             inContext: self.uploadBckgContext)
        }
        
        // Update UploadQueue cell and button shown in root album (or default album)
        await MainActor.run {
            let uploadInfo: [String : Any] = ["localIdentifier" : properties.localIdentifier,
                                              "progressFraction" : 1.0]
            NotificationCenter.default.post(name: .pwgUploadProgress, object: nil, userInfo: uploadInfo)
        }
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
