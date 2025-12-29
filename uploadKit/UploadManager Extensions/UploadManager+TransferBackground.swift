//
//  UploadManager+TransferBackground.swift
//  uploadKit
//
//  Created by Eddy Lelièvre-Berna on 29/12/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit

// MARK: - Transfer in Background
// See https://tools.ietf.org/html/rfc7578
extension UploadManager {
    func transferInBackground(for upload: Upload) {

        // Get URL of file to upload
        /// This file will be deleted once the transfer is completed successfully
        let fileURL = getUploadFileURL(from: upload)
        
        // Get content of file to upload
        /// https://developer.apple.com/forums/thread/115401
        var imageData = Data()
        do {
            try imageData = Data(contentsOf: fileURL, options: .alwaysMapped)
//            try imageData = NSData(contentsOf: fileURL, options: .alwaysMapped) as Data
        }
        catch let error as CocoaError {
            // Could not find the file to upload!
            upload.setState(.preparingFail, error: .fileOperationFailed(innerError: error), save: true)
            self.didEndTransfer(for: upload)
            return
        }
        catch {
            upload.setState(.preparingFail, error: .otherError(innerError: error), save: true)
            self.didEndTransfer(for: upload)
            return
        }

        // Calculate number of chunks
        let chunkSize = UploadVars.shared.uploadChunkSize * 1024
        let chunksDiv: Float = Float(imageData.count) / Float(chunkSize)
        let chunks = Int(chunksDiv.rounded(.up))
        let chunksStr = String(format: "%ld", chunks)
        if chunks == 0 || upload.fileName.isEmpty ||
           upload.md5Sum.isEmpty || upload.category == 0 {
            upload.setState(.preparingFail, error: .missingUploadParameter, save: true)
            self.didEndTransfer(for: upload)
        }
        
        // Prepare upload URL
        guard let uploadUrl = URL(string: NetworkVars.shared.service + "/ws.php?format=json&method=\(pwgImagesUploadAsync)")
        else { preconditionFailure("!!! Invalid uploadAsync URL") }

        // Prepare creation date as Piwigo string
        let creationDate = DateUtilities.string(from: upload.creationDate)

        // Prepare credentials
        let username = NetworkVars.shared.username
        guard let serverPath = upload.user?.server?.path else {
            upload.setState(.preparingFail, error: .missingUploadData, save: true)
            self.didEndTransfer(for: upload)
            return
        }
        let password = KeychainUtilities.password(forService: serverPath, account: username)
        
        // Prepare boundary
        let boundary = createBoundary(from: upload.md5Sum)

        // Current chunk
        let chunk = 0
        let chunkStr = String(format: "%ld", chunk)
        
        // Get HTTP request body
        let httpBody = getHttpBodyForChunk(chunk, ofSize: chunkSize, chunks: chunksStr,
                                           ofData: imageData, withDate: creationDate, boundary: boundary,
                                           for: username, password: password, upload: upload)

        // File name of chunk data stored into Piwigo/Uploads directory
        // This file will be deleted after a successful upload of the chunk
        let suffix = "." + chunkFormatter.string(from: NSNumber(value: chunk))!
        let chunkURL = getUploadFileURL(from: upload, withSuffix: suffix, deleted: true)

        // Store chunk of image data into Piwigo/Uploads directory
        do {
            try httpBody.write(to: chunkURL, options: [.noFileProtection])
        }
        catch let error {
            // Disk full? —> to be managed…
            debugPrint(error)
            return
        }
        
        // Prepare URL Request Object
        let request = getHttpRequestForChunk(chunkStr, ofChunks: chunksStr, with: boundary,
                                             for: uploadUrl, upload: upload)

        // As soon as tasks are created, the timeout counter starts
        let task = bckgSession.uploadTask(with: request, fromFile: chunkURL)
        task.taskDescription = uploadBckgSessionIdentifier

        // Tell the system how many bytes are expected to be uploaded
        let bytesToSend = Int64(httpBody.count + (request.allHTTPHeaderFields ?? [:]).count)
        task.countOfBytesClientExpectsToSend = bytesToSend
        task.countOfBytesClientExpectsToReceive = 600
        
        // Adds bytes expected to be sent to counter
        if UploadVars.shared.isExecutingBGUploadTask {
            countOfBytesToUpload += httpBody.count
            UploadManager.logger.notice("\(upload.objectID.uriRepresentation().absoluteString) • Added \(self.countOfBytesToUpload) bytes to countOfBytesToUpload")
        }
        
        // Remember the total number of bytes to upload
        if chunks == 1 {
            // Only one chunk to upload
            self.setTotalBytes(bytesToSend, forCounterWithID: upload.objectID.uriRepresentation().absoluteString)
        } else {
            // Several chunks to upload
            let totalBytes = Int64(imageData.count) + (bytesToSend - Int64(chunkSize)) * Int64(chunks)
            self.setTotalBytes(totalBytes, forCounterWithID: upload.objectID.uriRepresentation().absoluteString)
        }
        
        // Resume task of first chunk
        task.resume()
        UploadManager.logger.notice("\(upload.objectID.uriRepresentation().absoluteString) • Task \(task.taskIdentifier) resumed (\(chunk+1)/\(chunks))")
        
        // Release memory
        imageData.removeAll()
    }

    private func sendInBackground(chunkSet: Set<Int>, of chunks: Int, for upload: Upload) {
        // Get URL of file to upload
        /// This file will be deleted once the transfer is completed successfully
        let fileURL = getUploadFileURL(from: upload)
        
        // Get content of file to upload
        /// https://developer.apple.com/forums/thread/115401
        var imageData = Data()
        do {
            try imageData = Data(contentsOf: fileURL, options: .alwaysMapped)
//            try imageData = NSData(contentsOf: fileURL, options: .alwaysMapped) as Data
        }
        catch let error as NSError {
            // Could not find the file to upload!
            var msg = ""
            if #available(iOS 16.0, *) {
                msg = error.localizedDescription
                           .replacing(fileURL.absoluteString, with: fileURL.lastPathComponent)
            } else {
                // Fallback on earlier versions
                msg = error.localizedDescription
                           .replacingOccurrences(of: fileURL.absoluteString, with: fileURL.lastPathComponent)
            }
            let err = PwgKitError.pwgError(code: error.code, msg: msg)
            upload.setState(.preparingFail, error: err, save: true)
            self.didEndTransfer(for: upload)
            return
        }

        // Prepare upload URL
        guard let uploadUrl = URL(string: NetworkVars.shared.service + "/ws.php?format=json&method=\(pwgImagesUploadAsync)")
        else { preconditionFailure("!!! Invalid uploadAsync URL") }

        // Get credentials
        let username = NetworkVars.shared.username
        guard let serverPath = upload.user?.server?.path else {
            upload.setState(.preparingFail, error: .missingUploadData, save: true)
            self.didEndTransfer(for: upload)
            return
        }
        let password = KeychainUtilities.password(forService: serverPath, account: username)
        
        // Prepare boundary, chunk size, creation date as Piwigo string
        let boundary = createBoundary(from: upload.md5Sum)
        let chunkSize = UploadVars.shared.uploadChunkSize * 1024
        let chunksStr = String(format: "%ld", chunks)
        let creationDate = DateUtilities.string(from: upload.creationDate)

        // Loop over all chunks
        for chunk in chunkSet {
            autoreleasepool {
                // Current chunk
                let chunkStr = String(format: "%ld", chunk)
                
                // Get HTTP request body
                let httpBody = getHttpBodyForChunk(chunk, ofSize: chunkSize, chunks: chunksStr,
                                                   ofData: imageData, withDate: creationDate, boundary: boundary,
                                                   for: username, password: password, upload: upload)

                // File name of chunk data stored into Piwigo/Uploads directory
                // This file will be deleted after a successful upload of the chunk
                let suffix = "." + chunkFormatter.string(from: NSNumber(value: chunk))!
                let fileURL = getUploadFileURL(from: upload, withSuffix: suffix, deleted: true)

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
                let request = getHttpRequestForChunk(chunkStr, ofChunks: chunksStr, with: boundary,
                                                     for: uploadUrl, upload: upload)

                // As soon as tasks are created, the timeout counter starts
                let task = bckgSession.uploadTask(with: request, fromFile: fileURL)
                task.taskDescription = uploadBckgSessionIdentifier

                // Tell the system how many bytes are expected to be uploaded
                let bytesToSend = Int64(httpBody.count + (request.allHTTPHeaderFields ?? [:]).count)
                task.countOfBytesClientExpectsToSend = bytesToSend
                task.countOfBytesClientExpectsToReceive = 600
                
                // Adds bytes expected to be sent to counter
                if UploadVars.shared.isExecutingBGUploadTask {
                    countOfBytesToUpload += httpBody.count
                    UploadManager.logger.notice("\(upload.objectID.uriRepresentation().absoluteString) • Added \(self.countOfBytesToUpload) bytes to countOfBytesToUpload")
                }
                
                // Remember the total number of bytes to upload
                if chunk+1 < chunks {
                    let totalBytes = Int64(imageData.count) + (bytesToSend - Int64(chunkSize)) * Int64(chunks)
                    self.setTotalBytes(totalBytes, forCounterWithID: upload.objectID.uriRepresentation().absoluteString)
                }
                
                // Resume task
                task.resume()
                UploadManager.logger.notice("\(upload.objectID.uriRepresentation().absoluteString) • Task \(task.taskIdentifier) resumed (\(chunk+1)/\(chunks))")
            }
        }

        // Release memory
        imageData.removeAll()
    }
    
    private func getHttpBodyForChunk(_ chunk: Int, ofSize chunkSize: Int, chunks chunksStr: String, ofData imageData: Data,
                                     withDate creationDate: String, boundary: String,
                                     for username: String, password: String, upload: Upload) -> Data {
        // Current chunk
        let chunkStr = String(format: "%ld", chunk)
        
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
        httpBody.append(convertFormField(named: "original_sum", value: upload.md5Sum, using: boundary).data(using: .utf8)!)
        httpBody.append(convertFormField(named: "category", value: "\(upload.category)", using: boundary).data(using: .utf8)!)
        httpBody.append(convertFormField(named: "filename", value: upload.fileName, using: boundary).data(using: .utf8)!)
        httpBody.append(convertFormField(named: "name", value: upload.imageName.utf8mb3Encoded, using: boundary).data(using: .utf8)!)
        httpBody.append(convertFormField(named: "author", value: upload.author.utf8mb3Encoded, using: boundary).data(using: .utf8)!)
        httpBody.append(convertFormField(named: "comment", value: upload.comment.utf8mb3Encoded, using: boundary).data(using: .utf8)!)
        httpBody.append(convertFormField(named: "date_creation", value: creationDate, using: boundary).data(using: .utf8)!)
        httpBody.append(convertFormField(named: "level", value: "\(NSNumber(value: upload.privacyLevel))", using: boundary).data(using: .utf8)!)
        let tagIDs = String((upload.tags ?? Set<Tag>()).map({"\($0.tagId),"}).reduce("", +).dropLast(1))
        httpBody.append(convertFormField(named: "tag_ids", value: tagIDs, using: boundary).data(using: .utf8)!)

        // Chunk of data
        let chunkOfData = imageData.subdata(in: chunk*chunkSize..<min((chunk+1)*chunkSize, imageData.count))
        let md5Checksum = chunkOfData.MD5checksum
        httpBody.append(convertFormField(named: "chunk_sum", value: md5Checksum, using: boundary).data(using: .utf8)!)
        httpBody.append(self.convertFileData(fieldName: "file",
                                             fileName: upload.fileName,
                                             mimeType: upload.mimeType,
                                             fileData: chunkOfData,
                                             using: boundary))

        httpBody.append("--\(boundary)--".data(using: .utf8)!)
        
        return httpBody
    }
    
    private func getHttpRequestForChunk(_ chunkStr: String, ofChunks chunksStr: String, with boundary: String,
                                        for uploadUrl: URL, upload: Upload) -> URLRequest {
        // Prepare URL Request Object
        var request = URLRequest(url: uploadUrl)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue(upload.objectID.uriRepresentation().absoluteString, forHTTPHeaderField: pwgHTTPuploadID)
        request.setValue(upload.fileName, forHTTPHeaderField: "filename")
        request.setValue(upload.localIdentifier, forHTTPHeaderField: pwgHTTPimageID)
        request.setValue(chunkStr, forHTTPHeaderField: pwgHTTPchunk)
        request.setValue(chunksStr, forHTTPHeaderField: pwgHTTPchunks)
        request.setValue(upload.md5Sum, forHTTPHeaderField: pwgHTTPmd5sum)
        
        // Set HTTP header when API keys are used
        request.setAPIKeyHTTPHeader(for: pwgImagesUploadAsync)
        
        return request
    }

    func didCompleteBckgUploadTask(_ task: URLSessionTask, withError error: PwgKitError?) {
        // Retrieve task parameters
        guard let objectURIstr = task.originalRequest?.value(forHTTPHeaderField: pwgHTTPuploadID),
              let identifier = task.originalRequest?.value(forHTTPHeaderField: pwgHTTPimageID),
              let chunkStr = task.originalRequest?.value(forHTTPHeaderField: pwgHTTPchunk),
              let chunk = Int(chunkStr)
        else { preconditionFailure("••> Could not extract HTTP header fields !!!!!!") }

        // Do not report the error if the task was cancelled by the app
        if (task.taskDescription ?? "").contains(pwgHTTPCancelled) {
            // Delete chunk file from Piwigo/Uploads directory
            UploadManager.logger.notice("\(objectURIstr) • Cancelled background upload task \(task.taskIdentifier, privacy: .public), chunk \(chunk+1)")
            deleteChunk(chunk, ofImageWith: identifier)
            return
        }
        
        // Handle the response here
        guard let httpResponse = task.response as? HTTPURLResponse,
            (200...299).contains(httpResponse.statusCode)
        else {
            // Retrieve upload request properties
            guard let objectURI = URL(string: objectURIstr),
                  let uploadID = uploadBckgContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: objectURI),
                  let upload = (uploads.fetchedObjects ?? []).first(where: {$0.objectID == uploadID})
            else {
                UploadManager.logger.notice("\(objectURIstr) • Failed to retrieve Core Data object from task \(task.taskIdentifier, privacy: .public)")
                // Investigate next upload request?
                if UploadVars.shared.isExecutingBGUploadTask /* ||
                    UploadVars.shared.isExecutingBGContinuedUploadTask */ {
                    // In background task — stop here
                } else {
                    // In foreground, consider next image
                    Task { @UploadManagerActor in
//                        if #unavailable(iOS 26.0) {
                            self.findNextImageToUpload()
//                        }
                    }
                }
                return
            }

            // Update upload request status
            if let error = error {
                if error.failedAuthentication {
                    upload.setState(.uploadingFail, error: error, save: true)
                } else {
                    upload.setState(.uploadingError, error: error, save: true)
                }
                Task { @UploadManagerActor in
                    self.uploadBckgContext.saveIfNeeded()
                    self.didEndTransfer(for: upload, taskID: task.taskIdentifier)
                }
            }
            else {
                upload.setState(.uploadingError, error: .operationFailed, save: false)
                Task { @UploadManagerActor in
                    self.uploadBckgContext.saveIfNeeded()
                    self.didEndTransfer(for: upload, taskID: task.taskIdentifier)
                }
            }
            return
        }

        // Delete chunk file uploaded successfully from Piwigo/Uploads directory
        UploadManager.logger.notice("\(objectURIstr) • Delete chunk \(chunk+1)")
        deleteChunk(chunk, ofImageWith: identifier)
    }
    
    private func deleteChunk(_ chunk: Int, ofImageWith identifier: String) {
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

    func didCompleteBckgUploadTask(_ task: URLSessionTask, withData data: Data) {
        // Retrieve task parameters
        guard let objectURIstr = task.originalRequest?.value(forHTTPHeaderField: pwgHTTPuploadID),
              let identifier = task.originalRequest?.value(forHTTPHeaderField: pwgHTTPimageID)
        else { preconditionFailure("••> Could not extract HTTP header fields !!!!!!") }

        // Retrieve upload request properties
        guard let objectURI = URL(string: objectURIstr),
              let uploadID = uploadBckgContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: objectURI)
        else {
            UploadManager.logger.notice("\(objectURIstr) • Task \(task.taskIdentifier, privacy: .public) not associated to an upload!")
            return
        }

        guard let upload = (uploads.fetchedObjects ?? []).first(where: {$0.objectID == uploadID}) else {
            UploadManager.logger.notice("\(objectURIstr) • Failed to retrieve Core Data object from task \(task.taskIdentifier, privacy: .public)")
            // Investigate next upload request?
            if UploadVars.shared.isExecutingBGUploadTask /* ||
                UploadVars.shared.isExecutingBGContinuedUploadTask */ {
                // In background task — stop here
            } else {
                // In foreground, consider next image
                Task { @UploadManagerActor in
//                    if #unavailable(iOS 26.0) {
                        self.findNextImageToUpload()
//                    }
                }
            }
            return
        }

        // Don't escaladate the issue…
        if [.uploadingError, .uploadingFail].contains(upload.state) {
            return
        }
        
        // Check returned data
        if data.isEmpty {
            // Update upload request status
            UploadManager.logger.notice("\(objectURIstr) • Task \(task.taskIdentifier, privacy: .public) returned an Empty JSON object")
            upload.setState(.uploadingError, error: .emptyJSONobject, save: false)
            Task { @UploadManagerActor in
                self.uploadBckgContext.saveIfNeeded()
                self.didEndTransfer(for: upload, taskID: task.taskIdentifier)
            }
            return
        }
        var jsonData = data
        guard jsonData.extractingBalancedBraces() else {
            // Update upload request status
            let dataStr = String(decoding: data, as: UTF8.self)
            UploadManager.logger.notice("\(objectURIstr) • Task \(task.taskIdentifier, privacy: .public) returned the invalid JSON object: \(dataStr, privacy: .public)")
            upload.setState(.uploadingError, error: .invalidJSONobject, save: false)
            Task { @UploadManagerActor in
                self.uploadBckgContext.saveIfNeeded()
                self.didEndTransfer(for: upload, taskID: task.taskIdentifier)
            }
            return
        }

        // Decode the JSON.
        do {
            // Decode the JSON into codable type ImagesUploadAsyncJSON.
            let uploadJSON = try self.decoder.decode(ImagesUploadAsyncJSON.self, from: jsonData)
            
            // Upload completed?
            if let chunkMsg = uploadJSON.chunks, let message = chunkMsg.message {
                // Upload not completed ► Get list of uploaded chunks
                let uploadedChunks = Set(message.dropFirst(18).components(separatedBy: ",")
                    .compactMap({Int($0)})).map({$0 - 1})
                UploadManager.logger.notice("\(objectURIstr) • \(uploadedChunks) i.e. \(uploadedChunks.count) chunk(s) uploaded")
                
                // Determine list of remaining chunks to upload from server viewpoint
                guard let chunksStr = task.originalRequest?.value(forHTTPHeaderField: pwgHTTPchunks),
                      let chunks = Int(chunksStr)
                else { preconditionFailure("••> Could not extract HTTP header fields !!!!!!") }
                let chunksToUploadForServer = Set(0..<chunks).subtracting(uploadedChunks)
                UploadManager.logger.notice("\(objectURIstr) • \(chunksToUploadForServer) i.e. \(chunksToUploadForServer.count) chunk(s) to upload")
                
                // Remove chunks being uploaded
                var nberActiveTasks = 0
                var chunksToUploadForClient = [Int]()
                Task {
                    let uploadingTasks = await bckgSession.allTasks.compactMap({ $0.originalRequest })
                        .filter({ $0.value(forHTTPHeaderField: pwgHTTPuploadID) == objectURIstr })
                    let uploadingChunks = Set(uploadingTasks.compactMap({ $0.value(forHTTPHeaderField: pwgHTTPchunk )}).compactMap({ Int($0) }))
                    nberActiveTasks = uploadingChunks.count
                    UploadManager.logger.debug("\(objectURIstr) • \(uploadingChunks) i.e. \(nberActiveTasks) chunk(s) currently being uploaded")
                    chunksToUploadForClient = Array(chunksToUploadForServer.subtracting(uploadingChunks)).sorted()
                    UploadManager.logger.notice("\(objectURIstr) • \(chunksToUploadForClient) i.e. \(chunksToUploadForClient.count) chunk(s) to resume")
                    
                    // Still some chunks to submit?
                    if chunksToUploadForClient.isEmpty == false {
                        let chunksToResume = Set(chunksToUploadForClient[0..<min(chunksToUploadForClient.count, max(0, 4 - nberActiveTasks))])
                        UploadManager.logger.notice("\(objectURIstr) • \(chunksToResume) i.e. \(chunksToResume.count) chunk(s) resuming")
                        if chunksToResume.isEmpty == false {
                            self.sendInBackground(chunkSet: chunksToResume, of: chunks, for: upload)
                        }
                    }
                }
                return
            }
            
            // Upload completed
            // Cancel other tasks related to this request if any
            UploadSessionsDelegate.shared.cancelTasksOfUpload(withID: objectURIstr, exceptedTaskID: task.taskIdentifier)

            // Collect image data
            if var getInfos = uploadJSON.data, let imageId = getInfos.id,
               imageId != Int64.zero {

                // Get data returned by the server
                upload.imageId    = imageId
                upload.imageName  = getInfos.title?.utf8mb4Encoded ?? ""
                upload.author     = getInfos.author?.utf8mb4Encoded ?? ""
                if let privacyLevelStr = getInfos.privacyLevel {
                    upload.privacyLevel = Int16(privacyLevelStr) ?? pwgPrivacy.unknown.rawValue
                }
                upload.comment    = getInfos.comment?.utf8mb4Encoded ?? ""
                if let tags = getInfos.tags {
                    let tagIDs = tags.compactMap({$0.id}).map({$0.stringValue + ","}).reduce("", +).dropLast()
                    let newTagIDs = (try? TagProvider().getTags(withIDs: String(tagIDs), taskContext: uploadBckgContext).map({$0.objectID})) ?? []
                    var newTags = Set<Tag>()
                    newTagIDs.forEach({
                        if let copy = upload.managedObjectContext?.object(with: $0) as? Tag {
                            newTags.insert(copy)
                        }
                    })
                    upload.tags = newTags
                }
                
                // Add uploaded image to cache and update UI if needed
                if let user = try? UserProvider().getUserAccount(inContext: uploadBckgContext),
                   user.hasAdminRights {
                    getInfos.fixingUnknowns()
                    ImageProvider().didUploadImage(getInfos, asVideo: upload.isVideo,
                                                   inAlbumId: upload.category)
                }
            }

            // Update state of upload
            /// Since version 12, one must empty the lounge.
            if "12.0.0".compare(NetworkVars.shared.pwgVersion, options: .numeric) != .orderedDescending {
                // Uploading with pwg.images.uploadAsync since version 12
                upload.setState(.uploaded, save: false)
            } else {
                // Uploading with pwg.images.uploadAsync before version 12
                upload.setState(.finished, save: false)
            }

            Task { @UploadManagerActor in
                uploadBckgContext.saveIfNeeded()
                didEndTransfer(for: upload)
            }
            
            // Delete uploaded file
            var imageFile = ""
            if #available(iOS 16.0, *) {
                imageFile = identifier.replacing("/", with: "-")
            } else {
                // Fallback on earlier versions
                imageFile = identifier.replacingOccurrences(of: "/", with: "-")
            }
            deleteFilesInUploadsDirectory(withPrefix: imageFile)

            // Clear bytes and chunk counter
            removeCounter(withID: upload.md5Sum)
        }
        catch {
            // Error type?
            if let error = error as? PwgKitError {
                UploadManager.logger.notice("\(objectURIstr) • Task \(task.taskIdentifier, privacy: .public) returned the Piwigo error \(error.localizedDescription)")
                if error.failedAuthentication {
                    upload.setState(.uploadingFail, error: error, save: false)
                } else {
                    upload.setState(.uploadingError, error: error, save: false)
                }
            } else {
                // JSON object cannot be digested, image still ready for upload
                UploadManager.logger.notice("\(objectURIstr) • Wrong JSON object!")
                upload.setState(.uploadingError, error: .wrongJSONobject, save: false)
            }
            Task { @UploadManagerActor in
                uploadBckgContext.saveIfNeeded()
                didEndTransfer(for: upload, taskID: task.taskIdentifier)
            }
        }
    }
}
