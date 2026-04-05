//
//  UploadManager+TransferInBackground.swift
//  uploadKit
//
//  Created by Eddy Lelièvre-Berna on 29/12/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import BackgroundTasks
import CoreData
import Foundation
import piwigoKit

// MARK: - Transfer in Background
// See https://tools.ietf.org/html/rfc7578
@UploadManagerActor
extension UploadManager {
    
    func transferInBackground(for uploadData: UploadProperties,
                              withID uploadID: NSManagedObjectID) async throws(PwgKitError) {
        
        // Get URL of file to upload
        /// This file will be deleted once the transfer is completed successfully
        let fileURL = getUploadFileURL(from: uploadData.localIdentifier, creationDate: uploadData.creationDate)
        
        // Get content of file to upload
        /// https://developer.apple.com/forums/thread/115401
        var imageData = Data()
        do {
            try imageData = Data(contentsOf: fileURL, options: .alwaysMapped)
//            try imageData = NSData(contentsOf: fileURL, options: .alwaysMapped) as Data
        }
        catch let error as CocoaError { throw .fileOperationFailed(innerError: error) }
        catch { throw .otherError(innerError: error) }
        
        // Calculate number of chunks
        let chunkSize = UploadVars.shared.customUploadChunkSize * 1000
        let chunksDiv: Float = Float(imageData.count) / Float(chunkSize)
        let chunks = Int(chunksDiv.rounded(.up))
        let chunksStr = String(format: "%ld", chunks)
        if chunks == 0 || uploadData.fileName.isEmpty ||
            uploadData.md5Sum.isEmpty || uploadData.category == 0 {
            throw .missingUploadParameter
        }
        
        // Prepare upload URL
        guard let uploadUrl = URL(string: NetworkVars.shared.service + "/ws.php?format=json&method=\(pwgImagesUploadAsync)")
        else { preconditionFailure("!!! Invalid uploadAsync URL") }
        
        // Get credentials
        var username, password: String
        do {
            (username, password) = try UserProvider().getCredentialsOfUser(withID: uploadData.userURIstr, inContext: uploadBckgContext)
        }
        catch let error as PwgKitError { throw error }
        catch { throw .otherError(innerError: error) }
        
        // Prepare boundary, chunk size, creation date as Piwigo string
        let boundary = createBoundary(from: uploadData.md5Sum)
        let creationDate = DateUtilities.string(from: uploadData.creationDate)

        // Loop over all chunks
        for chunk in 1...chunks {
            autoreleasepool {
                // Get HTTP request body
                let httpBody = getHttpBodyForChunk(chunk, ofSize: chunkSize, chunks: chunksStr,
                                                   ofData: imageData, withDate: creationDate, boundary: boundary,
                                                   for: username, password: password, uploadData: uploadData)
                
                // File name of chunk data stored into Piwigo/Uploads directory
                // This file will be deleted after a successful upload of the chunk
                let suffix = "." + chunkFormatter.string(from: NSNumber(value: chunk))!
                let fileURL = getUploadFileURL(from: uploadData.localIdentifier, withSuffix: suffix,
                                               creationDate: uploadData.creationDate, deleted: true)
                
                // Store chunk of image data into Piwigo/Uploads directory
                do {
                    try httpBody.write(to: fileURL, options: [.atomic])
                }
                catch let error {
                    // Disk full? —> to be managed…
                    debugPrint(error)
                    return
                }
                
                // Prepare URL Request Object
                let chunkStr = String(format: "%ld", chunk)
                let request = getHttpRequestForChunk(chunkStr, ofChunks: chunksStr, with: boundary,
                                                     for: uploadUrl, uploadData: uploadData, withID: uploadID)
                
                // As soon as tasks are created, the timeout counter starts
                let task = bckgSession.uploadTask(with: request, fromFile: fileURL)
                task.taskDescription = uploadBckgSessionIdentifier
                
                // Tell the system how many bytes are expected to be uploaded
                let bytesToSend = Int64(httpBody.count + (request.allHTTPHeaderFields ?? [:]).count)
                task.countOfBytesClientExpectsToSend = bytesToSend
                task.countOfBytesClientExpectsToReceive = 600
                
                // Remember the total number of bytes to upload
                if chunks == 1 {
                    // Only one chunk to upload
                    self.setCounter(withID: uploadID.uriRepresentation().lastPathComponent, chunks: chunks, totalBytes: bytesToSend)
                }
                else if chunk == 1 {
                    // Several chunks to upload
                    let totalBytes = Int64(imageData.count) + (bytesToSend - Int64(chunkSize)) * Int64(chunks)
                    self.setCounter(withID: uploadID.uriRepresentation().lastPathComponent, chunks: chunks, totalBytes: totalBytes)
                }
                
                // Resume task
                task.resume()
                self.removeChunk(chunk, fromCounterWithID: uploadID.uriRepresentation().lastPathComponent)
                UploadManager.logger.notice("\(uploadID.uriRepresentation().lastPathComponent, privacy: .private(mask: .hash)) • Task \(task.taskIdentifier, privacy: .public) resumed (\(chunk, privacy: .public)/\(chunks, privacy: .public))")
            }
        }
        
        // Release memory
        imageData.removeAll()
    }
    
    func didCompleteBckgUploadTask(_ task: URLSessionTask, withError error: PwgKitError?) async {
        // Retrieve task parameters
        guard let objectURIstr = task.originalRequest?.value(forHTTPHeaderField: pwgHTTPuploadID),
              let identifier = task.originalRequest?.value(forHTTPHeaderField: pwgHTTPimageID),
              let chunkStr = task.originalRequest?.value(forHTTPHeaderField: pwgHTTPchunk),
              let chunk = Int(chunkStr)
        else { preconditionFailure("••> Could not extract HTTP header fields !!!!!!") }
        let objectIDstr = URL(string: objectURIstr)?.lastPathComponent ?? objectURIstr

        // Do not report the error if the task was cancelled by the app
        if (task.taskDescription ?? "").contains(pwgHTTPCancelled) {
            // Delete chunk file from Piwigo/Uploads directory
            UploadManager.logger.notice("\(objectIDstr, privacy: .private(mask: .hash)) • Cancelled background upload task \(task.taskIdentifier, privacy: .public), chunk \(chunk, privacy: .public)")
            deleteChunk(chunk, ofImageWith: identifier)
            return
        }
        
        // Retrieve upload request properties
        guard let objectURI = URL(string: objectURIstr),
              let uploadID = uploadBckgContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: objectURI),
              var uploadData = try? UploadProvider().getPropertiesOfUpload(withID: uploadID, inContext: self.uploadBckgContext)
        else {
            UploadManager.logger.notice("\(objectIDstr, privacy: .private(mask: .hash)) • Failed to retrieve Core Data object from task \(task.taskIdentifier, privacy: .public)")
            deleteChunk(chunk, ofImageWith: identifier)
            return
        }
        
        // Communication error?
        if let error {
            uploadData.requestState = .uploadingError
            uploadData.requestError = error.localizedDescription
            try? UploadProvider().updateUpload(withID: uploadID, properties: uploadData, inContext: self.uploadBckgContext)
            await UploadSessionsDelegate.shared.cancelTasksOfUpload(withID: objectURIstr, exceptedTaskID: task.taskIdentifier)
            return
        }
        
        // Valid response?
        guard let response = task.response as? HTTPURLResponse
        else {
            uploadData.requestState = .uploadingError
            uploadData.requestError = PwgKitError.invalidResponse.localizedDescription
            try? UploadProvider().updateUpload(withID: uploadID, properties: uploadData, inContext: self.uploadBckgContext)
            await UploadSessionsDelegate.shared.cancelTasksOfUpload(withID: objectURIstr, exceptedTaskID: task.taskIdentifier)
            return
        }
        
        // Absence of HTTP error?
        guard (200...299).contains(response.statusCode)
        else {
            uploadData.requestState = .uploadingError
            uploadData.requestError = PwgKitError.invalidStatusCode(statusCode: response.statusCode).localizedDescription
            try? UploadProvider().updateUpload(withID: uploadID, properties: uploadData, inContext: self.uploadBckgContext)
            await UploadSessionsDelegate.shared.cancelTasksOfUpload(withID: objectURIstr, exceptedTaskID: task.taskIdentifier)
            return
        }

        // Delete chunk file uploaded successfully from Piwigo/Uploads directory
        UploadManager.logger.notice("\(objectIDstr, privacy: .private(mask: .hash)) • Delete chunk \(chunk, privacy: .public)")
        deleteChunk(chunk, ofImageWith: identifier)
    }
    
    func didCompleteBckgUploadTask(_ task: URLSessionTask, withData data: Data) async {
        // Retrieve task parameters
        guard let objectURIstr = task.originalRequest?.value(forHTTPHeaderField: pwgHTTPuploadID),
              let identifier = task.originalRequest?.value(forHTTPHeaderField: pwgHTTPimageID)
        else { preconditionFailure("••> Could not extract HTTP header fields !!!!!!") }
        let objectIDstr = URL(string: objectURIstr)?.lastPathComponent ?? objectURIstr
        
        // Retrieve upload request properties
        guard let objectURI = URL(string: objectURIstr),
              let uploadID = uploadBckgContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: objectURI),
              var uploadData = try? UploadProvider().getPropertiesOfUpload(withID: uploadID, inContext: self.uploadBckgContext)
        else {
            UploadManager.logger.notice("\(objectIDstr, privacy: .private(mask: .hash)) • Failed to retrieve Core Data object from task \(task.taskIdentifier, privacy: .public)")
            return
        }
        
        // Don't escaladate the issue…
        if [.uploadingError, .uploadingFail].contains(uploadData.requestState) {
            return
        }
        
        // Check returned data
        if data.isEmpty {
            // Update upload request status
            UploadManager.logger.notice("\(objectIDstr, privacy: .private(mask: .hash)) • Task \(task.taskIdentifier, privacy: .public) returned an Empty JSON object")
            uploadData.requestState = .uploadingError
            uploadData.requestError = PwgKitError.emptyJSONobject.localizedDescription
            try? UploadProvider().updateUpload(withID: uploadID, properties: uploadData, inContext: self.uploadBckgContext)
            await UploadSessionsDelegate.shared.cancelTasksOfUpload(withID: objectURIstr, exceptedTaskID: task.taskIdentifier)
            return
        }
        var jsonData = data
        guard jsonData.extractingBalancedBraces() else {
            // Update upload request status
            UploadManager.logger.notice("\(objectIDstr, privacy: .private(mask: .hash)) • Task \(task.taskIdentifier, privacy: .public) returned the invalid JSON object")
            uploadData.requestState = .uploadingError
            uploadData.requestError = PwgKitError.invalidJSONobject.localizedDescription
            try? UploadProvider().updateUpload(withID: uploadID, properties: uploadData, inContext: self.uploadBckgContext)
            await UploadSessionsDelegate.shared.cancelTasksOfUpload(withID: objectURIstr, exceptedTaskID: task.taskIdentifier)
            return
        }
        
        // Decode the JSON.
        do {
            // Decode the JSON into codable type ImagesUploadAsyncJSON.
            let uploadJSON = try JSONDecoder().decode(ImagesUploadAsyncJSON.self, from: jsonData)
            
            // Upload completed?
            if let chunkMsg = uploadJSON.chunks, let message = chunkMsg.message {
                // Upload not completed
                // ► Get list of uploaded chunks
                let uploadedChunks = Set(message.dropFirst(18).components(separatedBy: ",")
                    .compactMap({Int($0)}))
                UploadManager.logger.notice("\(objectIDstr, privacy: .private(mask: .hash)) • \(uploadedChunks, privacy: .public) i.e. \(uploadedChunks.count, privacy: .public) chunk(s) uploaded")
                
                // Select running tasks of chunks already uploaded, if any
                let uploadTasks: [URLSessionTask] = await bckgSession.allTasks
                var tasksToCancel = uploadTasks.filter({ $0.taskIdentifier != task.taskIdentifier})
                    .filter({ $0.originalRequest?.value(forHTTPHeaderField: pwgHTTPuploadID) == objectURIstr })
                    .filter({ uploadedChunks.contains( Int($0.originalRequest?.value(forHTTPHeaderField: pwgHTTPchunk) ?? "") ?? -1) })
                    .filter({ $0.state == .running })
                
                // Cancel tasks of chunks already uploaded, except one so that the upload can be completed normally
                if tasksToCancel.count > 1 {
                    tasksToCancel.removeLast()
                    tasksToCancel.forEach { task in
                        UploadSessionsDelegate.logger.notice("\(objectIDstr) • Task \(task.taskIdentifier) cancelled")
                        // Remember that this task was cancelled
                        task.taskDescription = uploadBckgSessionIdentifier + " " + pwgHTTPCancelled
                        task.cancel()
                    }
                }
                return
            }
            
            // Upload completed
            // Cancel other tasks related to this request if any
            await UploadSessionsDelegate.shared.cancelTasksOfUpload(withID: objectURIstr, exceptedTaskID: task.taskIdentifier)
            
            // Collect image data
            guard var getInfos = uploadJSON.data, let imageId = getInfos.id,
                  imageId != Int64.zero
            else { throw PwgKitError.unexpectedData }
            
            // Get data returned by the server
            uploadData.imageId     = imageId
            uploadData.imageTitle  = getInfos.title?.utf8mb4Encoded ?? ""
            uploadData.author      = getInfos.author?.utf8mb4Encoded ?? ""
            if let privacyLevelStr = getInfos.privacyLevel {
                uploadData.privacyLevel = pwgPrivacy(rawValue: Int16(privacyLevelStr) ?? pwgPrivacy.unknown.rawValue) ?? pwgPrivacy.unknown
            }
            uploadData.comment     = getInfos.comment?.utf8mb4Encoded ?? ""
            if let tags = getInfos.tags {
                let tagIDs: String = tags.compactMap({ $0.id }).map({ $0.stringValue + ","}).reduce("", +)
                uploadData.tagIds  = String(tagIDs.dropLast(1))
            } else {
                uploadData.tagIds = ""
            }
            
            // Update upload request status
            uploadData.requestState = .uploaded
            uploadData.requestError = ""
            try? UploadProvider().updateUpload(withID: uploadID, properties: uploadData, inContext: self.uploadBckgContext)
            
            // Finish transfer if called by background task
            if UploadVars.shared.isProcessingTaskActive || UploadVars.shared.isContinuedProcessingTaskActive {
                await finishTransferOfUpload(withIDs: [uploadID])
            }
            else {
                // Add photo/video to finish transfer queue
                await UploadManagerActor.shared.addUploadsToFinish(withIDs: [uploadID])
                await UploadManagerActor.shared.processNextUpload()
            }
            
            // Add uploaded image to cache and update UI if needed
            if let userURI = URL(string: uploadData.userURIstr),
               let userID = uploadBckgContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: userURI),
               let user = try? uploadBckgContext.existingObject(with: userID) as? User,
               user.hasAdminRights {
                getInfos.fixingUnknowns()
                ImageProvider().didUploadImage(getInfos, inAlbumId: uploadData.category)
            }
            
            // Delete remaining uploaded file
            var imageFile = ""
            if #available(iOS 16.0, *) {
                imageFile = identifier.replacing("/", with: "-")
            } else {
                // Fallback on earlier versions
                imageFile = identifier.replacingOccurrences(of: "/", with: "-")
            }
            deleteFilesInUploadsDirectory(withPrefix: imageFile)
            
            // Clear bytes and chunk counter
            removeCounter(withID: objectIDstr)
        }
        catch {
            // Error type?
            if let error = error as? PwgKitError {
                UploadManager.logger.notice("\(objectIDstr, privacy: .private(mask: .hash)) • Task \(task.taskIdentifier, privacy: .public) returned the error \(error.localizedDescription, privacy: .public)")
                if error.failedAuthentication {
                    uploadData.requestState = .uploadingFail
                    uploadData.requestError = error.localizedDescription
                } else {
                    uploadData.requestState = .uploadingError
                    uploadData.requestError = error.localizedDescription
                }
            } else {
                // JSON object cannot be digested, image still ready for upload
                UploadManager.logger.notice("\(objectIDstr, privacy: .private(mask: .hash)) • Task \(task.taskIdentifier, privacy: .public) returned a wrong JSON object!")
                uploadData.requestState = .uploadingError
                uploadData.requestError = PwgKitError.wrongJSONobject.localizedDescription
            }
            try? UploadProvider().updateUpload(withID: uploadID, properties: uploadData, inContext: self.uploadBckgContext)
        }
    }
    
    
    // MARK: - Utilities
    fileprivate nonisolated func getHttpBodyForChunk(_ chunk: Int, ofSize chunkSize: Int, chunks chunksStr: String, ofData imageData: Data,
                                                     withDate creationDate: String, boundary: String,
                                                     for username: String, password: String,
                                                     uploadData: UploadProperties) -> Data {
        // Current chunk
        let chunkStr = String(format: "%ld", chunk - 1)
        
        // Prepare HTTP request body
        var httpBody = Data()
        
        // Append credentials if not using API keys
        if (NetworkVars.shared.usesAPIkeys && username.isValidPublicKey() &&
             !NetworkVars.shared.apiKeysProhibitedMethods.contains(pwgImagesUploadAsync)) == false {
            httpBody.append(convertFormField(named: "username", value: username, using: boundary).data(using: .utf8)!)
            httpBody.append(convertFormField(named: "password", value: password, using: boundary).data(using: .utf8)!)
        }

        // Append parameters requested by API method
        httpBody.append(convertFormField(named: "chunk", value: chunkStr, using: boundary).data(using: .utf8)!)
        httpBody.append(convertFormField(named: "chunks", value: chunksStr, using: boundary).data(using: .utf8)!)
        httpBody.append(convertFormField(named: "original_sum", value: uploadData.md5Sum, using: boundary).data(using: .utf8)!)
        httpBody.append(convertFormField(named: "category", value: "\(uploadData.category)", using: boundary).data(using: .utf8)!)
        httpBody.append(convertFormField(named: "filename", value: uploadData.fileName, using: boundary).data(using: .utf8)!)
        httpBody.append(convertFormField(named: "name", value: uploadData.imageTitle.utf8mb3Encoded, using: boundary).data(using: .utf8)!)
        httpBody.append(convertFormField(named: "author", value: uploadData.author.utf8mb3Encoded, using: boundary).data(using: .utf8)!)
        httpBody.append(convertFormField(named: "comment", value: uploadData.comment.utf8mb3Encoded, using: boundary).data(using: .utf8)!)
        httpBody.append(convertFormField(named: "date_creation", value: creationDate, using: boundary).data(using: .utf8)!)
        httpBody.append(convertFormField(named: "level", value: "\(NSNumber(value: uploadData.privacyLevel.rawValue))", using: boundary).data(using: .utf8)!)
        httpBody.append(convertFormField(named: "tag_ids", value: uploadData.tagIds, using: boundary).data(using: .utf8)!)
        
        // Chunk of data
        let chunkOfData = imageData.subdata(in: (chunk - 1)*chunkSize..<min(chunk*chunkSize, imageData.count))
        let md5Checksum = chunkOfData.MD5checksum
        httpBody.append(convertFormField(named: "chunk_sum", value: md5Checksum, using: boundary).data(using: .utf8)!)
        httpBody.append(self.convertFileData(fieldName: "file",
                                             fileName: uploadData.fileName,
                                             mimeType: uploadData.mimeType,
                                             fileData: chunkOfData,
                                             using: boundary))

        httpBody.append("--\(boundary)--".data(using: .utf8)!)
        
        return httpBody
    }
    
    fileprivate func getHttpRequestForChunk(_ chunkStr: String, ofChunks chunksStr: String, with boundary: String,
                                            for uploadUrl: URL, uploadData: UploadProperties, withID uploadID: NSManagedObjectID) -> URLRequest {
        // Prepare URL Request Object
        var request = URLRequest(url: uploadUrl)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue(uploadID.uriRepresentation().absoluteString, forHTTPHeaderField: pwgHTTPuploadID)
        request.setValue(uploadData.fileName, forHTTPHeaderField: "filename")
        request.setValue(uploadData.localIdentifier, forHTTPHeaderField: pwgHTTPimageID)
        request.setValue(chunkStr, forHTTPHeaderField: pwgHTTPchunk)
        request.setValue(chunksStr, forHTTPHeaderField: pwgHTTPchunks)
        request.setValue(uploadData.md5Sum, forHTTPHeaderField: pwgHTTPmd5sum)
        
        // Set HTTP header when API keys are used
        request.setAPIKeyHTTPHeader(for: pwgImagesUploadAsync)
        
        return request
    }
    
    fileprivate func deleteChunk(_ chunk: Int, ofImageWith identifier: String) {
        // For producing the chunk filename
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .none
        numberFormatter.minimumIntegerDigits = 5
        
        // Delete chunk file uploaded successfully from Piwigo/Uploads directory
        var imageFile = ""
        if #available(iOS 16.0, *) {
            imageFile = identifier.replacing("/", with: "-")
        } else {
            // Fallback on earlier versions
            imageFile = identifier.replacingOccurrences(of: "/", with: "-")
        }
        let chunkFileName = imageFile + "." + numberFormatter.string(from: NSNumber(value: chunk))!
        deleteFilesInUploadsDirectory(withPrefix: chunkFileName)
    }
}
