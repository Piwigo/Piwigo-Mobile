//
//  UploadManager+TransferOrCopy.swift
//  PwgUploadKit
//
//  Created by Eddy Lelièvre-Berna on 21/05/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import BackgroundTasks
import CoreData
import PwgKit
import PwgAPIKit
import PwgCacheKit

@UploadManagerActor
extension UploadManager {
    
    // MARK: - Transfer or Copy Image/Video
    public func transferOrCopyFileOfUpload(withID uploadID: NSManagedObjectID,
                                           inTaskType taskType: UploadTaskType) async {

        // A background task owns the requests it handles, see prepareUpload()
        if taskType.isBackground {
            await UploadManagerActor.shared.removeUploads(withIDs: [uploadID])
        }

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
            guard uploadData.md5Sum.isEmpty == false
            else { throw PwgKitError.missingAsset }
            
            // Check session
            var userData = try UserProvider().getPropertiesOfUser(withURIstr: uploadData.userURIstr,
                                                                  inContext: self.uploadBckgContext)
            try await checkSession(ofUser: &userData)
            
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
                await UploadManagerActor.shared.forgetRetries(ofUploadWithID: uploadID)
                
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
                
            case .authenticationFailed, .invalidCredentials,
                 .invalidStatusCode(statusCode: 401),
                 .invalidStatusCode(statusCode: 403):
                /// The server refused the session, which happens when it was closed on its side
                /// or invalidated by another login. Logging in again usually restores it, so the
                /// request is worth retrying instead of being failed for good.
                uploadData.requestState = .uploadingError
                uploadData.requestError = error.localizedDescription
                
            case .invalidStatusCode(let statusCode) where (500...599).contains(statusCode):
                /// The server failed to answer this request, e.g. a PHP error while a chunk was
                /// being stored. Such failures are transient: the chunk tasks already retry them
                /// and the requests which complete during the same run prove the server recovers.
                uploadData.requestState = .uploadingError
                uploadData.requestError = error.localizedDescription
                
            case .decodingFailed, .invalidJSONobject, .emptyJSONobject, .invalidResponse:
                /// The server answered with something which is not the expected JSON, e.g. a PHP
                /// warning or a fatal error page emitted before the payload. The request itself is
                /// sound — the very same one usually succeeds on the next attempt — so it is worth
                /// retrying instead of being failed for good. A server which answers badly for good
                /// exhausts the retries and the request is then presented to the user as failed.
                uploadData.requestState = .uploadingError
                uploadData.requestError = error.localizedDescription
                
            case .missingAsset, .missingUploadData, .fileOperationFailed,
                 .missingUploadParameter, .wrongServerURL:
                fallthrough
            default:
                uploadData.requestState = .uploadingFail
                uploadData.requestError = error.localizedDescription
            }
            /// The state is logged by its name: 'Uploading… Error' labels both the state which
            /// is retried and the one which is not.
            UploadManager.logger.notice("\(uploadID.uriRepresentation().lastPathComponent) • Transfer/copy failed with \(String(describing: error)) —> state '\(String(describing: uploadData.requestState))'")
            try? UploadProvider().updateUpload(withID: uploadID, properties: uploadData, inContext: self.uploadBckgContext)
            
            // Try again when the failure is worth retrying
            if uploadData.requestState == .uploadingError,
               await retryTransferOfUpload(withID: uploadID, inTaskType: taskType) {
                return
            }
        }
        catch {
            uploadData.requestState = .uploadingFail
            uploadData.requestError = PwgKitError.otherError(innerError: error).localizedDescription
            UploadManager.logger.notice("\(uploadID.uriRepresentation().lastPathComponent) • Transfer/copy failed with \(String(describing: error)) —> state '\(String(describing: uploadData.requestState))'")
            try? UploadProvider().updateUpload(withID: uploadID, properties: uploadData, inContext: self.uploadBckgContext)
        }
        
        // In foreground, process next upload if any
        if taskType.isForeground {
            await UploadManagerActor.shared.processNextUpload()
        }
    }
    
    /// Re-attempts the transfer of a request which failed in a way worth retrying — a 5xx, a
    /// session refused, an answer which is not the expected JSON.
    ///
    /// The queue is driven differently in the foreground and inside a background task, and
    /// neither re-queues a request which failed: it waits for the next launch of the app or of
    /// a background task, or for the user to resume it by hand. The retry is therefore performed
    /// here, where the failure is known, after a pause which grows with the number of attempts
    /// so that a server under pressure is given time to recover.
    ///
    /// Returns false when the request exhausted its retries, leaving it in its error state for
    /// the user to resume, and true when the transfer was attempted again.
    ///
    /// Requests which are not in the '.uploadingError' state are left alone, so that the callers
    /// which report a failure without knowing whether it is worth retrying — the background
    /// session delegate — may call this unconditionally.
    @discardableResult
    func retryTransferOfUpload(withID uploadID: NSManagedObjectID,
                               inTaskType taskType: UploadTaskType) async -> Bool {
        // Did the request exhaust its retries?
        guard let nberOfRetries = await UploadManagerActor.shared.grantRetry(toUploadWithID: uploadID)
        else { return false }
        
        // Let the server recover before trying again
        try? await Task.sleep(nanoseconds: UInt64(nberOfRetries) * 2_000_000_000)
        guard Task.isCancelled == false else { return false }
        
        // Re-arm the request, unless something else changed its state in the meantime
        guard var uploadData = try? UploadProvider().getPropertiesOfUpload(withID: uploadID,
                                                                           inContext: self.uploadBckgContext),
              uploadData.requestState == .uploadingError
        else { return false }
        uploadData.requestState = .prepared
        uploadData.requestError = ""
        try? UploadProvider().updateUpload(withID: uploadID, properties: uploadData, inContext: self.uploadBckgContext)
        UploadManager.logger.notice("\(uploadID.uriRepresentation().lastPathComponent) • Retrying the transfer (attempt \(nberOfRetries + 1))")
        
        // Transfer it again the way the current task does
        if taskType.isBackgroundAndActive {
            await transferOrCopyFileOfUpload(withID: uploadID, inTaskType: taskType)
        }
        else {
            await UploadManagerActor.shared.addUploadsToTransfer(withIDs: [uploadID])
            await UploadManagerActor.shared.processNextUpload()
        }
        return true
    }
    
    /// The type of task which drives the queue at this moment.
    /// The background session reports the outcome of its chunks outside the loops which launched
    /// them, so its delegate has no task type at hand and derives it from the tasks in progress.
    var currentTaskType: UploadTaskType {
        if UploadVars.shared.isContinuedProcessingTaskActive { return .bckgContinuedProcessingTask }
        if UploadVars.shared.isProcessingTaskActive { return .bckgProcessingTask }
        return .foreground
    }
    
    func copyImageWithID(_ imageID: Int64, for properties: UploadProperties,
                         withID uploadID: NSManagedObjectID) async throws(PwgKitError)
    {
        // Update UploadQueue cell and button shown in root album (or default album)
        await MainActor.run {
            let uploadInfo: [String : Any] = ["fileKey" : properties.fileKey,
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
            let uploadInfo: [String : Any] = ["fileKey" : properties.fileKey,
                                              "progressFraction" : 0.67]
            NotificationCenter.default.post(name: .pwgUploadProgress, object: nil, userInfo: uploadInfo)
        }
        
        // Associate the image to the album if needed
        if inserted {
            // Append selected category ID to image category list
            if ServerVars.shared.usesSetCategory {
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
            let pwgData = try await JSONManager.shared.getInfos(forID: imageID)
            
            // Update image data in cache
            // The provided sort option will not change the rankManual/rankRandom values.
            try? await ImageProvider().importImages([pwgData], inAlbum: properties.category, sort: .albumDefault)
            
            // Update displayed albums which are concerned
            try? AlbumProvider().updateAlbums(addingImages: 1, toAlbumWithID: properties.category,
                                              belongingToUser: properties.userURIstr,
                                              inContext: self.uploadBckgContext)
        }
        
        // Update UploadQueue cell and button shown in root album (or default album)
        await MainActor.run {
            let uploadInfo: [String : Any] = ["fileKey" : properties.fileKey,
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
