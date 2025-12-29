//
//  UploadManager+TransferForeground.swift
//  uploadKit
//
//  Created by Eddy Lelièvre-Berna on 29/12/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit

// MARK: Transfer in Foreground
extension UploadManager {
    func transferInForeground(for upload: Upload) async {
        // Get URL of file to upload
        /// This file will be deleted once the transfer is completed successfully
        let fileURL = getUploadFileURL(from: upload)
        
        // Get content of file to upload
        /// https://developer.apple.com/forums/thread/115401
        var imageData: Data = Data()
        do {
            try imageData = NSData(contentsOf: fileURL, options: .alwaysMapped) as Data
            //            try imageData = Data(contentsOf: fileURL, options: .alwaysMapped) as Data
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
        if chunks == 0 || upload.fileName.isEmpty ||
            upload.md5Sum.isEmpty || upload.category == 0 {
            upload.setState(.preparingFail, error: .missingUploadParameter, save: true)
            self.didEndTransfer(for: upload)
            return
        }
        
        // Prepare first chunk
        guard let userID = upload.user?.objectID,
              let lastUsed = upload.user?.lastUsed else {
            upload.setState(.preparingFail, error: .missingUploadParameter, save: true)
            self.didEndTransfer(for: upload)
            return
        }
        do {
            // Check session
            try await JSONManager.shared.checkSession(ofUserWithID: userID,
                                                      lastConnected: lastUsed)
            
            Task { @UploadManagerActor in
                // Set total number of bytes to upload
                self.setTotalBytes(Int64(imageData.count), forCounterWithID: upload.localIdentifier)
                
                // Start uploading
                self.sendInForeground(chunk: 0, of: chunks, for: upload)
            }
        }
        catch let error {
            Task { @UploadManagerActor in
                // Report error
                upload.setState(.preparingFail, error: error, save: true)
                self.didEndTransfer(for: upload)
            }
        }
    }
    
    private func sendInForeground(chunk:Int, of chunks:Int, for upload: Upload) {
        // Get URL of file to upload
        /// This file will be deleted once the transfer is completed successfully
        let fileURL = getUploadFileURL(from: upload)
        
        // Get content of file to upload
        /// https://developer.apple.com/forums/thread/115401
        var imageData: Data = Data()
        do {
            try imageData = NSData(contentsOf: fileURL, options: .alwaysMapped) as Data
            //            try imageData = Data(contentsOf: fileURL, options: .alwaysMapped) as Data
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
        
        // Prepare chunk
        let chunkSize = UploadVars.shared.uploadChunkSize * 1024
        let length = imageData.count
        let offset = chunkSize * chunk
        let thisChunkSize = length - offset > chunkSize ? chunkSize : length - offset
        var chunkData = imageData.subdata(in: offset..<offset + thisChunkSize)
        UploadManager.logger.notice("\(upload.objectID.uriRepresentation().absoluteString) • sendInForeground() chunk #\(chunk+1, privacy: .public) with chunkSize:\(chunkSize, privacy: .public), thisChunkSize:\(thisChunkSize, privacy: .public), total:\(length, privacy: .public)")
        
        // Prepare URL
        let url = URL(string: NetworkVars.shared.service + "/ws.php?\(pwgImagesUpload)")
        guard let validUrl = url else { fatalError() }
        
        // Initialise boundary of upload request
        let boundary = createBoundary(from: upload.md5Sum)
        
        // HTTP request body
        var httpBody = Data()
        httpBody.append(convertFormField(named: "chunk", value: String(chunk), using: boundary).data(using: .utf8)!)
        httpBody.append(convertFormField(named: "chunks", value: String(chunks), using: boundary).data(using: .utf8)!)
        httpBody.append(convertFormField(named: "name", value: upload.fileName, using: boundary).data(using: .utf8)!)
        httpBody.append(convertFormField(named: "category", value: "\(upload.category)", using: boundary).data(using: .utf8)!)
        httpBody.append(convertFormField(named: "level", value: "\(NSNumber(value: upload.privacyLevel))", using: boundary).data(using: .utf8)!)
        httpBody.append(convertFormField(named: "pwg_token", value: NetworkVars.shared.pwgToken, using: boundary).data(using: .utf8)!)
        
        // Chunk of data
        httpBody.append(convertFileData(fieldName: "file",
                                        fileName: upload.fileName,
                                        mimeType: upload.mimeType,
                                        fileData: chunkData,
                                        using: boundary))
        
        httpBody.append("--\(boundary)--".data(using: .utf8)!)
        
        // Prepare URL Request Object
        var request = URLRequest(url: validUrl)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue(upload.objectID.uriRepresentation().absoluteString, forHTTPHeaderField: pwgHTTPuploadID)
        request.setValue(upload.fileName, forHTTPHeaderField: "filename")
        request.setValue(upload.localIdentifier, forHTTPHeaderField: pwgHTTPimageID)
        request.setValue(String(chunk), forHTTPHeaderField: pwgHTTPchunk)
        request.setValue(String(chunks), forHTTPHeaderField: pwgHTTPchunks)
        request.setValue(upload.md5Sum, forHTTPHeaderField: pwgHTTPmd5sum)
        
        // Set HTTP header when API keys are used
        request.setAPIKeyHTTPHeader(for: pwgImagesUpload)
        
        // As soon as a task is created, the timeout counter starts
        let task = frgdSession.uploadTask(with: request, from: httpBody)
        task.taskDescription = uploadSessionIdentifier
        
        // Tell the system how many bytes are expected to be exchanged
        let bytesToSend = Int64(httpBody.count + (request.allHTTPHeaderFields ?? [:]).count)
        task.countOfBytesClientExpectsToSend = bytesToSend
        task.countOfBytesClientExpectsToReceive = 600
        
        // Update the total number of bytes to upload if needed
        if chunk+1 < chunks {
            let totalBytes = Int64(imageData.count) + (bytesToSend - Int64(chunkSize)) * Int64(chunks)
            self.setTotalBytes(totalBytes, forCounterWithID: upload.objectID.uriRepresentation().absoluteString)
        }
        
        // Resume task
        UploadManager.logger.notice("\(upload.objectID.uriRepresentation().absoluteString) • Task \(task.taskIdentifier) resumed (\(chunk+1)/\(chunks))")
        task.resume()
        
        // Release memory
        httpBody.removeAll()
        chunkData.removeAll()
    }
    
    func didCompleteUploadTask(_ task: URLSessionTask, withError error: PwgKitError?) {
        // Retrieve task parameters
        guard let objectURIstr = task.originalRequest?.value(forHTTPHeaderField: pwgHTTPuploadID),
              let identifier = task.originalRequest?.value(forHTTPHeaderField: pwgHTTPimageID),
              let chunkStr = task.originalRequest?.value(forHTTPHeaderField: pwgHTTPchunk), let chunk = Int(chunkStr),
              let chunksStr = task.originalRequest?.value(forHTTPHeaderField: pwgHTTPchunks), let chunks = Int(chunksStr)
        else {
            UploadManager.logger.notice("Could not extract HTTP header fields !!!!!!")
            return
        }
        
        // Handle the response here
        guard let httpResponse = task.response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            
            // Retrieve upload request properties
            guard let objectURI = URL(string: objectURIstr),
                  let uploadID = uploadBckgContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: objectURI)
            else {
                UploadManager.logger.notice("\(objectURIstr) • Task \(task.taskIdentifier, privacy: .public) not associated to an upload!")
                return
            }
            
            // Retrieve upload request
            do {
                let upload = try uploadBckgContext.existingObject(with: uploadID) as! Upload
                if upload.isFault {
                    // The upload request is not fired yet.
                    upload.willAccessValue(forKey: nil)
                    upload.didAccessValue(forKey: nil)
                }
                
                // Update upload request status
                if let error = error {
                    Task { @UploadManagerActor in
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
            catch {
                UploadManager.logger.notice("\(objectURIstr) • Failed to retrieve Core Data object from task \(task.taskIdentifier, privacy: .public)")
                // In foreground, consider next image
                Task { @UploadManagerActor in
                    //                    if #unavailable(iOS 26.0) {
                    self.findNextImageToUpload()
                    //                    }
                }
                return
            }
        }
        
        // Upload completed?
        if chunk + 1 < chunks { return }
        
        // Delete uploaded files from Piwigo/Uploads directory
        UploadManager.logger.notice("\(objectURIstr) • Did complete task \(task.taskIdentifier, privacy: .public), delete files…")
        var imageFile = ""
        if #available(iOS 16.0, *) {
            imageFile = identifier.replacing("/", with: "-")
        } else {
            // Fallback on earlier versions
            imageFile = identifier.replacingOccurrences(of: "/", with: "-")
        }
        deleteFilesInUploadsDirectory(withPrefix: imageFile)
    }
    
    func didCompleteUploadTask(_ task: URLSessionTask, withData data: Data) {
        // Retrieve task parameters
        guard let objectURIstr = task.originalRequest?.value(forHTTPHeaderField: pwgHTTPuploadID),
              let chunkStr = task.originalRequest?.value(forHTTPHeaderField: pwgHTTPchunk), let chunk = Int(chunkStr),
              let chunksStr = task.originalRequest?.value(forHTTPHeaderField: pwgHTTPchunks), let chunks = Int(chunksStr)
        else {
            UploadManager.logger.notice("Could not extract HTTP header fields !!!!!!")
            return
        }
        
        // Retrieve upload request properties
        guard let objectURI = URL(string: objectURIstr),
              let uploadID = uploadBckgContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: objectURI)
        else {
            UploadManager.logger.notice("\(objectURIstr) • Task \(task.taskIdentifier, privacy: .public) not associated to an upload!")
            return
        }
        
        // Retrieve upload request
        do {
            let upload = try uploadBckgContext.existingObject(with: uploadID) as! Upload
            if upload.isFault {
                // The upload request is not fired yet.
                upload.willAccessValue(forKey: nil)
                upload.didAccessValue(forKey: nil)
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
            
            // Filter returned data
            var jsonData = data
            guard jsonData.extractingBalancedBraces() else {
                // Update upload request status
                let dataStr = String(decoding: data, as: UTF8.self)
                UploadManager.logger.notice("\(objectURIstr) • Task \(task.taskIdentifier, privacy: .public) returned the invalid JSON object: \(dataStr, privacy: .public)")
                upload.setState(.uploadingError, error: .invalidJSONobject, save: false)
                Task { @UploadManagerActor in
                    uploadBckgContext.saveIfNeeded()
                    didEndTransfer(for: upload, taskID: task.taskIdentifier)
                }
                return
            }
            
            // Decode the JSON.
            do {
                // Decode the JSON into codable type ImagesUploadJSON.
                let uploadJSON = try self.decoder.decode(ImagesUploadJSON.self, from: jsonData)
                
                // Upload completed?
                if chunk + 1 < chunks {
                    Task { @UploadManagerActor in
                        self.sendInForeground(chunk: chunk + 1, of: chunks, for: upload)
                    }
                    return
                }
                
                // Add image to cache when uploaded by admin users
                if let user = upload.user, user.hasAdminRights,
                   let imageID = uploadJSON.data.image_id {
                    // Create ImageGetInfo object
                    let created = Date(timeIntervalSinceReferenceDate: upload.creationDate)
                    let square = Derivative(url: uploadJSON.data.square_src)
                    let thumb = Derivative(url: uploadJSON.data.src)
                    let newImage = ImagesGetInfo(id: imageID, title: upload.imageName,
                                                 fileName: upload.fileName,
                                                 datePosted: Date(), dateCreated: created,
                                                 author: upload.author,
                                                 privacyLevel: String(upload.privacyLevel),
                                                 squareImage: square, thumbImage: thumb)
                    // Add image to cache
                    ImageProvider().didUploadImage(newImage, asVideo: upload.isVideo,
                                                   inAlbumId: upload.category)
                }
                
                // Update state of upload
                upload.imageId = uploadJSON.data.image_id!
                upload.setState(.uploaded, save: false)
                Task { @UploadManagerActor in
                    uploadBckgContext.saveIfNeeded()
                    didEndTransfer(for: upload)
                }
            } catch {
                // Error type?
                if let error = error as? PwgKitError {
                    if error.failedAuthentication {
                        upload.setState(.uploadingFail, error: error, save: false)
                    } else {
                        upload.setState(.uploadingError, error: error, save: false)
                    }
                } else {
                    // Data cannot be digested, image still ready for upload
                    upload.setState(.uploadingError, error: .wrongJSONobject, save: false)
                }
                Task { @UploadManagerActor in
                    uploadBckgContext.saveIfNeeded()
                    didEndTransfer(for: upload)
                }
            }
        }
        catch {
            UploadManager.logger.notice("\(objectURIstr) • Failed to retrieve Core Data object from task \(task.taskIdentifier, privacy: .public)")
            // In foreground, consider next image
            Task { @UploadManagerActor in
                //                if #unavailable(iOS 26.0) {
                findNextImageToUpload()
                //                }
            }
        }
    }
}
