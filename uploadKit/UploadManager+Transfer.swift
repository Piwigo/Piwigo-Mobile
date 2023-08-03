//
//  UploadManager+Transfer.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 21/05/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import BackgroundTasks
import CoreData
import piwigoKit

extension UploadManager {
    
    // MARK: - Transfer Image if Necessary
    public func launchTransfer(of upload: Upload) -> Void {
        print("\(dbg()) launch transfer of \(upload.objectID.uriRepresentation())")

        // Update list of transfers
        if isUploading.contains(upload.objectID) { return }
        isUploading.insert(upload.objectID)

        // Check user entity
        guard let user = upload.user else {
            // Should never happen
            // ► The lounge will be emptied later by the server
            // ► Stop upload task and return an error
            upload.setState(.uploadingError, error: UserError.emptyUsername, save: true)
            self.didEndTransfer(for: upload)
            return
        }

        // Check that the MD5 checksum is known
        if upload.md5Sum.isEmpty {
            let error = NSError(domain: "Piwigo", code: UploadError.missingAsset.hashValue,
                                userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
            upload.setState(.uploadingFail, error: error, save: true)
            self.didEndTransfer(for: upload)
            return
        }
        
        // Update state of upload request
        upload.setState(.uploading, save: true)
        
        // Is this image already stored on the Piwigo server?
        NetworkUtilities.checkSession(ofUser: user) {
            PwgSession.shared.getIDofImage(withMD5: upload.md5Sum) { imageID in
                self.backgroundQueue.async {
                    if let imageID = imageID {
                        // Already stored on the Piwigo server ► Copy to Album
                        self.copyImageWithID(imageID, for: upload)
                    } else {
                        // Upload new image to the Piwigo server
                        self.transfertImage(for: upload)
                    }
                }
            } failure: { error in
                upload.setState(.uploadingError, error: error, save: true)
                self.backgroundQueue.async {
                    self.uploadProvider.bckgContext.saveIfNeeded()
                    self.didEndTransfer(for: upload)
                }
            }
        } failure: { error in
            upload.setState(.uploadingError, error: error, save: true)
            self.backgroundQueue.async {
                self.uploadProvider.bckgContext.saveIfNeeded()
                self.didEndTransfer(for: upload)
            }
        }
    }
    
    func copyImageWithID(_ imageID: Int64, for upload: Upload) {
        // Retrieve image data from the Piwigo server, storing in cache
        imageProvider.getInfos(forID: imageID, inCategoryId: upload.category) {
            // Update UploadQueue cell and button shown in root album (or default album)
            DispatchQueue.main.async {
                let uploadInfo: [String : Any] = ["localIdentifier" : upload.localIdentifier,
                                                  "progressFraction" : 0.5]
                NotificationCenter.default.post(name: .pwgUploadProgress, object: nil, userInfo: uploadInfo)
            }

            // Get image and album objects in cache
            let imageSet = self.imageProvider.getImages(inContext: self.uploadProvider.bckgContext, withIds: Set([imageID]))
            guard let imageData = imageSet.first, let albums = imageData.albums,
                  let albumData = self.albumProvider.getAlbum(ofUser: upload.user, withId: upload.category)
            else {
                let error = NSError(domain: "Piwigo", code: UploadError.missingAsset.hashValue,
                                    userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                upload.setState(.uploadingFail, error: error, save: true)
                self.backgroundQueue.async {
                    self.uploadProvider.bckgContext.saveIfNeeded()
                    self.didEndTransfer(for: upload)
                }
                return
            }
            
            // Append selected category ID to image category list
            var categoryIds = Set(albums.compactMap({$0.pwgID}))
            let categoryCount = categoryIds.count
            categoryIds.insert(upload.category)
            
            // Check if the category already contains that image
            if categoryIds.count == categoryCount {
                // Update UploadQueue cell and button shown in root album (or default album)
                DispatchQueue.main.async {
                    let uploadInfo: [String : Any] = ["localIdentifier" : upload.localIdentifier,
                                                      "progressFraction" : 1.0]
                    NotificationCenter.default.post(name: .pwgUploadProgress, object: nil, userInfo: uploadInfo)
                }
                
                // Job done
                upload.imageId = imageID
                upload.setState(.moderated, save: true)
                self.backgroundQueue.async {
                    self.uploadProvider.bckgContext.saveIfNeeded()
                    self.didEndTransfer(for: upload)
                }
                return
            }
            
            // Prepare parameters for copying the image/video to the selected category
            let newImageCategories = categoryIds.compactMap({ String($0) }).joined(separator: ";")
            let paramsDict: [String : Any] = ["image_id"            : imageData.pwgID,
                                              "categories"          : newImageCategories,
                                              "multiple_value_mode" : "replace"]
            
            // Send request to Piwigo server
            PwgSession.shared.setInfos(with: paramsDict) { [self] in
                // Update UploadQueue cell and button shown in root album (or default album)
                DispatchQueue.main.async {
                    let uploadInfo: [String : Any] = ["localIdentifier" : upload.localIdentifier,
                                                      "progressFraction" : 1.0]
                    NotificationCenter.default.post(name: .pwgUploadProgress, object: nil, userInfo: uploadInfo)
                }

                // Update cached data
                self.backgroundQueue.async {
                    // Add image to album
                    albumData.addToImages(imageData)
                    
                    // Update albums
                    self.albumProvider.updateAlbums(addingImages: 1, toAlbum: albumData)
                    
                    // Set album thumbnail with first copied image if necessary
//                    if [nil, Int64.zero].contains(albumData.thumbnailId) || albumData.thumbnailUrl == nil {
//                        albumData.thumbnailId = imageData.pwgID
//                        let thumnailSize = pwgImageSize(rawValue: AlbumVars.shared.defaultAlbumThumbnailSize) ?? .medium
//                        albumData.thumbnailUrl = ImageUtilities.getURL(imageData, ofMinSize: thumnailSize) as NSURL?
//                    }
                    
                    // Copy complete
                    upload.imageId = imageID
                    upload.setState(.moderated, save: true)
                    self.backgroundQueue.async {
                        self.uploadProvider.bckgContext.saveIfNeeded()
                        self.didEndTransfer(for: upload)
                    }
                }
            } failure: { error in
                upload.setState(.uploadingError, error: error, save: true)
                self.backgroundQueue.async {
                    self.uploadProvider.bckgContext.saveIfNeeded()
                    self.didEndTransfer(for: upload)
                }
            }
        } failure: { error in
            upload.setState(.uploadingError, error: error, save: true)
            self.backgroundQueue.async {
                self.uploadProvider.bckgContext.saveIfNeeded()
                self.didEndTransfer(for: upload)
            }
        }
    }
    
    func transfertImage(for upload: Upload) {
        // Initialise or reset counter of progress bar in case we repeat the transfer
        UploadSessions.shared.initCounter(withID: upload.localIdentifier)

        // Choose recent method when called by:
        /// - admins as from Piwigo server 11 or previous versions with the uploadAsync plugin installed.
        /// - Community users as from Piwigo 12.
        if NetworkVars.usesUploadAsync || isExecutingBackgroundUploadTask {
            // Prepare transfer
            self.transferInBackground(for: upload)
        } else {
            // Transfer image
            self.transferInForeground(for: upload)
        }
        
        // Do not prepare next image in background task (already scheduled)
        if self.isExecutingBackgroundUploadTask { return }

        // Stop here if there no image to prepare
        let waiting = (uploads.fetchedObjects ?? []).filter({$0.state == .waiting})
        if waiting.isEmpty { return }

        // Should we prepare the next image in parallel?
        let states: [pwgUploadState] = [.preparingError, .preparingFail,
                                        .uploadingError, .uploadingFail,
                                        .finishingError]
        let failed = (uploads.fetchedObjects ?? []).filter({states.contains($0.state)})
        if !self.isPreparing, failed.count < maxNberOfFailedUploads,
           let upload = waiting.first {

            // Prepare the next upload
            self.isPreparing = true
            self.prepare(upload)
            return
        }
    }

    
    // MARK: - Transfer in Foreground
    func transferInForeground(for upload: Upload) {
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
        catch let error as NSError {
            // Could not find the file to upload!
            let msg = error.localizedDescription
                .replacingOccurrences(of: fileURL.absoluteString, with: fileURL.lastPathComponent)
            let err = NSError(domain: error.domain, code: error.code,
                              userInfo: [NSLocalizedDescriptionKey : msg])
            upload.setState(.preparingFail, error: err, save: true)
            self.didEndTransfer(for: upload)
            return
        }

        // Calculate number of chunks
        let chunkSize = UploadVars.uploadChunkSize * 1024
        let chunksDiv: Float = Float(imageData.count) / Float(chunkSize)
        let chunks = Int(chunksDiv.rounded(.up))
        if chunks == 0, upload.fileName.isEmpty,
           upload.md5Sum.isEmpty, upload.category == 0 {
            let error = NSError(domain: "Piwigo", code: UploadError.missingFile.hashValue,
                                userInfo: [NSLocalizedDescriptionKey : UploadError.missingFile.localizedDescription])
            upload.setState(.preparingFail, error: error, save: true)
            self.didEndTransfer(for: upload)
            return
        }

        // Prepare first chunk
        NetworkUtilities.checkSession(ofUser: upload.user) {
            // Set total number of bytes to upload
            UploadSessions.shared.addBytes(Int64(imageData.count), toCounterWithID: upload.localIdentifier)
            // Start uploading
            self.send(chunk: 0, of: chunks, for: upload)
        } failure: { error in
            upload.requestError = error.localizedDescription
        }
    }

    func send(chunk:Int, of chunks:Int, for upload: Upload) {
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
        catch let error as NSError {
            // Could not find the file to upload!
            let msg = error.localizedDescription
                .replacingOccurrences(of: fileURL.absoluteString, with: fileURL.lastPathComponent)
            let err = NSError(domain: error.domain, code: error.code,
                              userInfo: [NSLocalizedDescriptionKey : msg])
            upload.setState(.preparingFail, error: err, save: true)
            self.didEndTransfer(for: upload)
            return
        }

        // Prepare chunk
        let chunkSize = UploadVars.uploadChunkSize * 1024
        let length = imageData.count
        let offset = chunkSize * chunk
        let thisChunkSize = length - offset > chunkSize ? chunkSize : length - offset
        var chunkData = imageData.subdata(in: offset..<offset + thisChunkSize)
        print("\(dbg()) #\(chunk+1) with chunkSize:", chunkSize, "thisChunkSize:", thisChunkSize, "total:", length)

        // Prepare URL
        let url = URL(string: NetworkVars.service + "/ws.php?\(pwgImagesUpload)")
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
        httpBody.append(convertFormField(named: "pwg_token", value: NetworkVars.pwgToken, using: boundary).data(using: .utf8)!)

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
        request.addValue(upload.localIdentifier, forHTTPHeaderField: pwgHTTPimageID)
        request.addValue(String(chunk), forHTTPHeaderField: pwgHTTPchunk)
        request.addValue(String(chunks), forHTTPHeaderField: pwgHTTPchunks)
        request.addValue(upload.md5Sum, forHTTPHeaderField: pwgHTTPmd5sum)

        // As soon as a task is created, the timeout counter starts
        let task = frgdSession.uploadTask(with: request, from: httpBody)
        task.taskDescription = UploadSessions.shared.uploadSessionIdentifier

        // Tell the system how many bytes are expected to be exchanged
        task.countOfBytesClientExpectsToSend = Int64(httpBody.count + (request.allHTTPHeaderFields ?? [:]).count)
        task.countOfBytesClientExpectsToReceive = 600
        
        // Resume task
        print("\(dbg()) \(upload.md5Sum) upload task \(task.taskIdentifier) resumed (\(chunk+1)/\(chunks))")
        task.resume()

        // Release memory
        httpBody.removeAll()
        chunkData.removeAll()
    }

    func didCompleteUploadTask(_ task: URLSessionTask, withError error: Error?) {
        // Retrieve task parameters
        guard let objectURIstr = task.originalRequest?.value(forHTTPHeaderField: pwgHTTPuploadID),
              let identifier = task.originalRequest?.value(forHTTPHeaderField: pwgHTTPimageID),
              let chunkStr = task.originalRequest?.value(forHTTPHeaderField: pwgHTTPchunk), let chunk = Int(chunkStr),
              let chunksStr = task.originalRequest?.value(forHTTPHeaderField: pwgHTTPchunks), let chunks = Int(chunksStr),
              let md5sum = task.originalRequest?.value(forHTTPHeaderField: pwgHTTPmd5sum) else {
            print("\(dbg()) Could not extract HTTP header fields !!!!!!")
            return
        }

        // Handle the response here
        guard let httpResponse = task.response as? HTTPURLResponse,
            (200...299).contains(httpResponse.statusCode) else {
            
            // Retrieve upload request properties
            guard let objectURI = URL(string: objectURIstr) else {
                print("\(dbg()) \(md5sum) | no object URI!")
                return
            }
            guard let uploadID = uploadProvider.bckgContext
                .persistentStoreCoordinator?.managedObjectID(forURIRepresentation: objectURI) else {
                print("\(dbg()) \(md5sum) | no objectID!")
                return
            }
            do {
                let upload = try uploadProvider.bckgContext.existingObject(with: uploadID) as! Upload

                // Update upload request status
                if let error = error as NSError? {
                    self.backgroundQueue.async {
                        upload.setState(.uploadingError, error: error, save: false)
                        self.backgroundQueue.async {
                            self.uploadProvider.bckgContext.saveIfNeeded()
                            self.didEndTransfer(for: upload, taskID: task.taskIdentifier)
                        }
                    }
                }
                else if let httpResponse = task.response as? HTTPURLResponse {
                    let msg = HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
                    let error = NSError(domain: "Piwigo", code: httpResponse.statusCode,
                                        userInfo: [NSLocalizedDescriptionKey : msg])
                    if (400...499).contains(httpResponse.statusCode) {
                        upload.setState(.uploadingFail, error: error, save: false)
                    } else {
                        upload.setState(.uploadingError, error: error, save: false)
                    }
                    self.backgroundQueue.async {
                        self.uploadProvider.bckgContext.saveIfNeeded()
                        self.didEndTransfer(for: upload, taskID: task.taskIdentifier)
                    }
                }
                else {
                    upload.setState(.uploadingError, error: JsonError.networkUnavailable, save: false)
                    self.backgroundQueue.async {
                        self.uploadProvider.bckgContext.saveIfNeeded()
                        self.didEndTransfer(for: upload, taskID: task.taskIdentifier)
                    }
                }
                return
            }
            catch {
                print("\(dbg()) \(md5sum) | missing Core Data object!")
                // In foreground, consider next image
                self.backgroundQueue.async {
                    self.findNextImageToUpload()
                }
                return
            }
        }
        
        // Upload completed?
        if chunk + 1 < chunks { return }

        // Delete uploaded files from Piwigo/Uploads directory
        print("\(dbg()) \(md5sum) | delete left files")
        let imageFile = identifier.replacingOccurrences(of: "/", with: "-")
        deleteFilesInUploadsDirectory(withPrefix: imageFile)
    }

    func didCompleteUploadTask(_ task: URLSessionTask, withData data: Data) {
        // Retrieve task parameters
        guard let objectURIstr = task.originalRequest?.value(forHTTPHeaderField: pwgHTTPuploadID),
              let chunkStr = task.originalRequest?.value(forHTTPHeaderField: pwgHTTPchunk), let chunk = Int(chunkStr),
              let chunksStr = task.originalRequest?.value(forHTTPHeaderField: pwgHTTPchunks), let chunks = Int(chunksStr),
              let md5sum = task.originalRequest?.value(forHTTPHeaderField: pwgHTTPmd5sum) else {
            return
        }
        
        // Retrieve upload request properties
        guard let objectURI = URL(string: objectURIstr) else {
            print("\(dbg()) \(md5sum) | no object URI!")
            return
        }
        guard let uploadID = uploadProvider.bckgContext
            .persistentStoreCoordinator?.managedObjectID(forURIRepresentation: objectURI) else {
            print("\(dbg()) \(md5sum) | no objectID!")
            return
        }
        do {
            let upload = try uploadProvider.bckgContext.existingObject(with: uploadID) as! Upload
            if upload.isFault {
                // The upload request is not fired yet.
                upload.willAccessValue(forKey: nil)
                upload.didAccessValue(forKey: nil)
            }

            // Check returned data
            if data.isEmpty {
                // Update upload request status
                #if DEBUG
                print("\(dbg()) Empty JSON object!")
                #endif
                upload.setState(.uploadingError, error: JsonError.emptyJSONobject, save: false)
                self.backgroundQueue.async {
                    self.uploadProvider.bckgContext.saveIfNeeded()
                    self.didEndTransfer(for: upload, taskID: task.taskIdentifier)
                }
                return
            }
            var jsonData = data
            guard jsonData.isPiwigoResponseValid(for: ImagesUploadJSON.self) else {
                // Update upload request status
                #if DEBUG
                let dataStr = String(decoding: data, as: UTF8.self)
                print("\(dbg()) Invalid JSON object: \(dataStr)")
                #endif
                upload.setState(.uploadingError, error: JsonError.invalidJSONobject, save: false)
                self.backgroundQueue.async {
                    self.uploadProvider.bckgContext.saveIfNeeded()
                    self.didEndTransfer(for: upload, taskID: task.taskIdentifier)
                }
                return
            }
            
            // Decode the JSON.
            do {
                // Decode the JSON into codable type ImagesUploadJSON.
                let uploadJSON = try self.decoder.decode(ImagesUploadJSON.self, from: jsonData)

                // Piwigo error?
                if (uploadJSON.errorCode != 0) {
                    let error = PwgSession.shared.localizedError(for: uploadJSON.errorCode,
                                                                 errorMessage: uploadJSON.errorMessage)
                    if (400...499).contains(uploadJSON.errorCode) {
                        upload.setState(.uploadingFail, error: error, save: false)
                    } else {
                        upload.setState(.uploadingError, error: error, save: false)
                    }
                    self.backgroundQueue.async {
                        self.uploadProvider.bckgContext.saveIfNeeded()
                        self.didEndTransfer(for: upload)
                    }
                    return
                }

                // Upload completed?
                if chunk + 1 < chunks {
                    self.backgroundQueue.async {
                        self.send(chunk: chunk + 1, of: chunks, for: upload)
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
                    imageProvider.didUploadImage(newImage, asVideo: upload.isVideo,
                                                 inAlbumId: upload.category)
                }

                // Update state of upload
                upload.imageId = uploadJSON.data.image_id!
                upload.setState(.uploaded, save: false)
                backgroundQueue.async {
                    self.uploadProvider.bckgContext.saveIfNeeded()
                    self.didEndTransfer(for: upload)
                }
                return
            } catch {
                // Data cannot be digested, image still ready for upload
                upload.setState(.uploadingError, error: UploadError.wrongJSONobject, save: false)
                backgroundQueue.async {
                    self.uploadProvider.bckgContext.saveIfNeeded()
                    self.didEndTransfer(for: upload)
                }
                return
            }
        }
        catch {
            // In foreground, consider next image
            print("\(dbg()) \(md5sum) | missing Core Data object!")
            // In foreground, consider next image
            self.backgroundQueue.async {
                self.findNextImageToUpload()
            }
            return
        }
    }

    
    // MARK: - Transfer in Background
    // See https://tools.ietf.org/html/rfc7578
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
        catch let error as NSError {
            // Could not find the file to upload!
            let msg = error.localizedDescription
                .replacingOccurrences(of: fileURL.absoluteString, with: fileURL.lastPathComponent)
            let err = NSError(domain: error.domain, code: error.code,
                              userInfo: [NSLocalizedDescriptionKey : msg])
            upload.setState(.preparingFail, error: err, save: true)
            self.didEndTransfer(for: upload)
            return
        }

        // Calculate number of chunks
        let chunkSize = UploadVars.uploadChunkSize * 1024
        let chunksDiv : Float = Float(imageData.count) / Float(chunkSize)
        let chunks = Int(chunksDiv.rounded(.up))
        let chunksStr = String(format: "%ld", chunks)
        if chunks == 0, upload.fileName.isEmpty,
           upload.md5Sum.isEmpty, upload.category == 0 {
            upload.setState(.preparingFail, error: UploadError.missingFile, save: true)
            self.didEndTransfer(for: upload)
        }
        
        // For producing filename suffixes
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .none
        numberFormatter.minimumIntegerDigits = 5

        // Prepare URL
        let url = URL(string: NetworkVars.service + "/ws.php?\(pwgImagesUploadAsync)")
        guard let validUrl = url else { fatalError() }
        
        // Prepare creation date
        let dateFormat = DateFormatter()
        dateFormat.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let date = Date(timeIntervalSinceReferenceDate: upload.creationDate)
        let creationDate = dateFormat.string(from: date)

        // Initialise credentials, boundary and upload session
        let username = NetworkVars.username
        guard let serverPath = upload.user?.server?.path else {
            upload.setState(.preparingFail, error: UploadError.missingData, save: true)
            self.didEndTransfer(for: upload)
            return
        }
        let password = KeychainUtilities.password(forService: serverPath, account: username)
        let boundary = createBoundary(from: upload.md5Sum)

        // Loop over all chunks
        for chunk in 0..<chunks {
            autoreleasepool {
                // Current chunk
                let chunkStr = String(format: "%ld", chunk)
                
                // HTTP request body
                var httpBody = Data()
                httpBody.append(convertFormField(named: "username", value: username, using: boundary).data(using: .utf8)!)
                httpBody.append(convertFormField(named: "password", value: password, using: boundary).data(using: .utf8)!)
                httpBody.append(convertFormField(named: "chunk", value: chunkStr, using: boundary).data(using: .utf8)!)
                httpBody.append(convertFormField(named: "chunks", value: chunksStr, using: boundary).data(using: .utf8)!)
                httpBody.append(convertFormField(named: "original_sum", value: upload.md5Sum, using: boundary).data(using: .utf8)!)
                httpBody.append(convertFormField(named: "category", value: "\(upload.category)", using: boundary).data(using: .utf8)!)
                httpBody.append(convertFormField(named: "filename", value: upload.fileName, using: boundary).data(using: .utf8)!)
                let imageTitle = NetworkUtilities.utf8mb3String(from: upload.imageName)
                httpBody.append(convertFormField(named: "name", value: imageTitle, using: boundary).data(using: .utf8)!)
                let author = NetworkUtilities.utf8mb3String(from: upload.author)
                httpBody.append(convertFormField(named: "author", value: author, using: boundary).data(using: .utf8)!)
                let comment = NetworkUtilities.utf8mb3String(from: upload.comment)
                httpBody.append(convertFormField(named: "comment", value: comment, using: boundary).data(using: .utf8)!)
                httpBody.append(convertFormField(named: "date_creation", value: creationDate, using: boundary).data(using: .utf8)!)
                httpBody.append(convertFormField(named: "level", value: "\(NSNumber(value: upload.privacyLevel))", using: boundary).data(using: .utf8)!)
                let tagIDs = String((upload.tags ?? Set<Tag>()).map({"\($0.tagId),"}).reduce("", +).dropLast(1))
                httpBody.append(convertFormField(named: "tag_ids", value: tagIDs, using: boundary).data(using: .utf8)!)

                // Chunk of data
                let chunkOfData = imageData.subdata(in: chunk * chunkSize..<min((chunk+1)*chunkSize, imageData.count))
                let md5Checksum = chunkOfData.MD5checksum()
                httpBody.append(convertFormField(named: "chunk_sum", value: md5Checksum, using: boundary).data(using: .utf8)!)
                httpBody.append(self.convertFileData(fieldName: "file",
                                                     fileName: upload.fileName,
                                                     mimeType: upload.mimeType,
                                                     fileData: chunkOfData,
                                                     using: boundary))

                httpBody.append("--\(boundary)--".data(using: .utf8)!)

                // File name of chunk data stored into Piwigo/Uploads directory
                // This file will be deleted after a successful upload of the chunk
                let suffix = "." + numberFormatter.string(from: NSNumber(value: chunk))!
                let fileURL = getUploadFileURL(from: upload, withSuffix: suffix, deleted: true)

                // Store chunk of image data into Piwigo/Uploads directory
                do {
                    try httpBody.write(to: fileURL)
                }
                catch let error as NSError {
                    // Disk full? —> to be managed…
                    print(error)
                    return
                }
                
                // Prepare URL Request Object
                var request = URLRequest(url: validUrl)
                request.httpMethod = "POST"
                request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
                request.setValue(upload.objectID.uriRepresentation().absoluteString, forHTTPHeaderField: pwgHTTPuploadID)
                request.setValue(upload.fileName, forHTTPHeaderField: "filename")
                request.setValue(upload.localIdentifier, forHTTPHeaderField: pwgHTTPimageID)
                request.setValue(chunkStr, forHTTPHeaderField: pwgHTTPchunk)
                request.setValue(chunksStr, forHTTPHeaderField: pwgHTTPchunks)
                request.setValue(upload.md5Sum, forHTTPHeaderField: pwgHTTPmd5sum)

                // As soon as tasks are created, the timeout counter starts
                let task = bckgSession.uploadTask(with: request, fromFile: fileURL)
                task.taskDescription = UploadSessions.shared.uploadBckgSessionIdentifier

                // Tell the system how many bytes are expected to be exchanged
                let bytesToSend = Int64(httpBody.count + (request.allHTTPHeaderFields ?? [:]).count)
                UploadSessions.shared.addBytes(bytesToSend, toCounterWithID: upload.localIdentifier)
                task.countOfBytesClientExpectsToSend = bytesToSend
                task.countOfBytesClientExpectsToReceive = 600
                
                // Adds bytes expected to be sent to counter
                if isExecutingBackgroundUploadTask {
                    countOfBytesToUpload += httpBody.count
                    print("\(dbg()) countOfBytesToUpload: \(countOfBytesToUpload)")
                }
                
                // Resume task
                print("\(dbg()) \(upload.md5Sum) upload task \(task.taskIdentifier) resumed (\(chunk+1)/\(chunks))")
                task.resume()
            }
        }

        // Release memory
        imageData.removeAll()
    }

    func didCompleteBckgUploadTask(_ task: URLSessionTask, withError error: Error?) {
        
        // Retrieve task parameters
        guard let objectURIstr = task.originalRequest?.value(forHTTPHeaderField: pwgHTTPuploadID),
              let identifier = task.originalRequest?.value(forHTTPHeaderField: pwgHTTPimageID),
              let md5sum = task.originalRequest?.value(forHTTPHeaderField: pwgHTTPmd5sum),
              let chunkStr = task.originalRequest?.value(forHTTPHeaderField: pwgHTTPchunk),
              let chunk = Int(chunkStr) else {
            print("\(dbg()) Could not extract HTTP header fields !!!!!!")
            return
        }

        // For producing the chunk filename
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .none
        numberFormatter.minimumIntegerDigits = 5

        // Handle the response here
        guard let httpResponse = task.response as? HTTPURLResponse,
            (200...299).contains(httpResponse.statusCode) else {
            
            // Retrieve upload request properties
            guard let objectURI = URL(string: objectURIstr) else {
                print("\(dbg()) \(md5sum) | no object URI!")
                return
            }
            guard let uploadID = uploadProvider.bckgContext
                .persistentStoreCoordinator?.managedObjectID(forURIRepresentation: objectURI) else {
                print("\(dbg()) \(md5sum) | no objectID!")
                return
            }
            guard let upload = (uploads.fetchedObjects ?? []).first(where: {$0.objectID == uploadID}) else {
                print("\(dbg()) \(md5sum) | missing Core Data object!")
                // Investigate next upload request?
                if self.isExecutingBackgroundUploadTask {
                    // In background task — stop here
                } else {
                    // In foreground, consider next image
                    self.backgroundQueue.async {
                        self.findNextImageToUpload()
                    }
                }
                return
            }

            // Update upload request status
            if let error = error as NSError? {
                upload.setState(.uploadingError, error: error, save: false)
                self.backgroundQueue.async {
                    self.uploadProvider.bckgContext.saveIfNeeded()
                    self.didEndTransfer(for: upload, taskID: task.taskIdentifier)
                }
            }
            else if let httpResponse = task.response as? HTTPURLResponse {
                let msg = HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
                let error = NSError(domain: "Piwigo", code: httpResponse.statusCode,
                                    userInfo: [NSLocalizedDescriptionKey : msg])
                if (400...499).contains(httpResponse.statusCode) {
                    upload.setState(.uploadingFail, error: error, save: false)
                } else {
                    upload.setState(.uploadingError, error: error, save: false)
                }
                self.backgroundQueue.async {
                    self.uploadProvider.bckgContext.saveIfNeeded()
                    self.didEndTransfer(for: upload, taskID: task.taskIdentifier)
                }
            }
            else {
                upload.setState(.uploadingError, error: JsonError.networkUnavailable, save: false)
                self.backgroundQueue.async {
                    self.uploadProvider.bckgContext.saveIfNeeded()
                    self.didEndTransfer(for: upload, taskID: task.taskIdentifier)
                }
            }
            return
        }

        // Delete chunk file uploaded successfully from Piwigo/Uploads directory
        print("\(dbg()) \(md5sum) | delete chunk \(chunk+1)")
        let imageFile = identifier.replacingOccurrences(of: "/", with: "-")
        let chunkFileName = imageFile + "." + numberFormatter.string(from: NSNumber(value: chunk))!
        deleteFilesInUploadsDirectory(withPrefix: chunkFileName)
    }

    func didCompleteBckgUploadTask(_ task: URLSessionTask, withData data: Data) {
        // Retrieve task parameters
        guard let objectURIstr = task.originalRequest?.value(forHTTPHeaderField: pwgHTTPuploadID),
              let identifier = task.originalRequest?.value(forHTTPHeaderField: pwgHTTPimageID),
              let md5sum = task.originalRequest?.value(forHTTPHeaderField: pwgHTTPmd5sum) else {
            return
        }
        
        // Retrieve upload request properties
        guard let objectURI = URL(string: objectURIstr) else {
            print("\(dbg()) \(md5sum) | no object URI!")
            return
        }
        guard let uploadID = uploadProvider.bckgContext
            .persistentStoreCoordinator?.managedObjectID(forURIRepresentation: objectURI) else {
            print("\(dbg()) \(md5sum) | no objectID!")
            return
        }
        guard let upload = (uploads.fetchedObjects ?? []).first(where: {$0.objectID == uploadID}) else {
            print("\(dbg()) \(md5sum) | missing Core Data object!")
            // Investigate next upload request?
            if self.isExecutingBackgroundUploadTask {
                // In background task — stop here
            } else {
                // In foreground, consider next image
                self.backgroundQueue.async {
                    self.findNextImageToUpload()
                }
            }
            return
        }

        // Check returned data
        if data.isEmpty {
            // Update upload request status
            #if DEBUG
            print("\(dbg()) Empty JSON object!")
            #endif
            upload.setState(.uploadingError, error: JsonError.emptyJSONobject, save: false)
            self.backgroundQueue.async {
                self.uploadProvider.bckgContext.saveIfNeeded()
                self.didEndTransfer(for: upload, taskID: task.taskIdentifier)
            }
            return
        }
        var jsonData = data
        guard jsonData.isPiwigoResponseValid(for: ImagesUploadAsyncJSON.self) else {
            // Update upload request status
            #if DEBUG
            let dataStr = String(decoding: data, as: UTF8.self)
            print("\(dbg()) Invalid JSON object: \(dataStr)")
            #endif
            upload.setState(.uploadingError, error: JsonError.invalidJSONobject, save: false)
            self.backgroundQueue.async {
                self.uploadProvider.bckgContext.saveIfNeeded()
                self.didEndTransfer(for: upload, taskID: task.taskIdentifier)
            }
            return
        }

        // Decode the JSON.
        do {
            // Decode the JSON into codable type ImagesUploadAsyncJSON.
            let uploadJSON = try self.decoder.decode(ImagesUploadAsyncJSON.self, from: jsonData)

            // Piwigo error?
            if (uploadJSON.errorCode != 0) {
                print("\(dbg()) \(md5sum) | Piwigo error \(uploadJSON.errorCode)")
                let error = PwgSession.shared.localizedError(for: uploadJSON.errorCode,
                                                             errorMessage: uploadJSON.errorMessage)
                if (400...499).contains(uploadJSON.errorCode) {
                    upload.setState(.uploadingFail, error: error, save: false)
                } else {
                    upload.setState(.uploadingError, error: error, save: false)
                }
                self.backgroundQueue.async {
                    self.uploadProvider.bckgContext.saveIfNeeded()
                    self.didEndTransfer(for: upload, taskID: task.taskIdentifier)
                }
                return
            }
            
            // Upload completed?
            if let chunks = uploadJSON.chunks, let message = chunks.message {
                // Upload not completed
                let chunkList = message.dropFirst(18).components(separatedBy: ",")
                print("\(dbg()) \(md5sum) | \(chunkList.count) chunks downloaded")
                // Cancel tasks of chunks already uploaded
//                UploadSessions.shared.cancelTasksOfUpload(witID: objectURIstr,
//                                                          alreadyUploadedChunks: chunkList,
//                                                          exceptedTaskID: task.taskIdentifier)
                return
            }
            
            // Upload completed
            // Cancel other tasks related to this request if any
            UploadSessions.shared.cancelTasksOfUpload(withID: objectURIstr,
                                                      exceptedTaskID: task.taskIdentifier)

            // Clear byte counter of progress bars
            UploadSessions.shared.removeCounter(withID: identifier)

            // Collect image data
            if var getInfos = uploadJSON.data, let imageId = getInfos.id,
               imageId != Int64.zero {

                // Get data returned by the server
                upload.imageId    = imageId
                upload.imageName  = NetworkUtilities.utf8mb4String(from: getInfos.title ?? "")
                upload.author     = NetworkUtilities.utf8mb4String(from: getInfos.author ?? "")
                if let privacyLevelStr = getInfos.privacyLevel {
                    upload.privacyLevel = Int16(privacyLevelStr) ?? pwgPrivacy.unknown.rawValue
                }
                upload.comment    = NetworkUtilities.utf8mb4String(from: getInfos.comment ?? "")
                if let tags = getInfos.tags {
                    let tagIDs = tags.compactMap({$0.id}).map({$0.stringValue + ","}).reduce("", +).dropLast()
                    let newTagIDs = tagProvider.getTags(withIDs: String(tagIDs), taskContext: uploadProvider.bckgContext).map({$0.objectID})
                    var newTags = Set<Tag>()
                    newTagIDs.forEach({
                        if let copy = upload.managedObjectContext?.object(with: $0) as? Tag {
                            newTags.insert(copy)
                        }
                    })
                    upload.tags = newTags
                }
                
                // Add uploaded image to cache and update UI if needed
                if let user = userProvider.getUserAccount(inContext: uploadProvider.bckgContext),
                   user.hasAdminRights {
                    getInfos.fixingUnknowns()
                    imageProvider.didUploadImage(getInfos, asVideo: upload.isVideo,
                                                 inAlbumId: upload.category)
                }
            }

            // Delete uploaded file
            let imageFile = identifier.replacingOccurrences(of: "/", with: "-")
            deleteFilesInUploadsDirectory(withPrefix: imageFile)

            // Update state of upload
            /// Since version 12, one must empty the lounge.
            if "12.0.0".compare(NetworkVars.pwgVersion, options: .numeric) != .orderedDescending {
                // Uploading with pwg.images.uploadAsync since version 12
                upload.setState(.uploaded, save: false)
            } else {
                // Uploading with pwg.images.uploadAsync before version 12
                upload.setState(.finished, save: false)
            }

            self.backgroundQueue.async {
                self.uploadProvider.bckgContext.saveIfNeeded()
                self.didEndTransfer(for: upload)
            }
            return
        } catch {
            // JSON object cannot be digested, image still ready for upload
            print("\(dbg()) \(md5sum) | wrong JSON object!")
            upload.setState(.uploadingError, error: UploadError.wrongJSONobject, save: false)
            self.backgroundQueue.async {
                self.uploadProvider.bckgContext.saveIfNeeded()
                self.didEndTransfer(for: upload, taskID: task.taskIdentifier)
            }
            return
        }
    }

    
    // MARK: - Transfer Failed/Completed
    private func didEndTransfer(for upload: Upload, taskID: Int = Int.max) {
        print("\(dbg()) didEndTransfer in", queueName())
        
        // Error?
        if upload.requestError.isEmpty == false {
            print("\(dbg()) task \(taskID) returned \(upload.requestError)")
            // Cancel related tasks
            if taskID != Int.max {
                let objectURIstr = upload.objectID.uriRepresentation().absoluteString
                UploadSessions.shared.cancelTasksOfUpload(withID: objectURIstr,
                                                          exceptedTaskID: taskID
                )
            }

            // Consider next image?
            self.didEndTransfer(for: upload)
            return
        }

        // Update state of upload request
        print("\(dbg()) transferred \(upload.objectID.uriRepresentation())")

        // Consider next image?
        self.didEndTransfer(for: upload)
    }
    
    func didEndTransfer(for upload: Upload) {
        // Update list of current uploads
        if let index = isUploading.firstIndex(where: {$0 == upload.objectID}) {
            isUploading.remove(at: index)
        }
        
        // Pursue the work…
        if isExecutingBackgroundUploadTask {
            finishTransfer(of: upload)
        } else if !isPreparing, isUploading.count <= maxNberOfTransfers, !isFinishing {
            // In foreground, always consider next file
            findNextImageToUpload()
        }
    }

    
    // MARK: - Utilities
    func createBoundary(from identifier: String) -> String {
        /// We don't use the UUID to be able to test uploads with a simulator.
        let suffix = identifier.replacingOccurrences(of: "/", with: "").map { $0.lowercased() }.joined()
        let boundary = String(repeating: "-", count: 68 - suffix.count) + suffix
//        print("\(dbg()) \(boundary)")
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
