//
//  UploadTransfer.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 21/05/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import BackgroundTasks

extension UploadManager {
    
    // MARK: - Transfer Image in Foreground
    func transferImage(of upload: UploadProperties) {
        // Prepare image parameters
        let imageParameters: [String : String] = [
            kPiwigoImagesUploadParamFileName: upload.fileName ?? "Image.jpg",
            kPiwigoImagesUploadParamCategory: "\(NSNumber(value: upload.category))",
            kPiwigoImagesUploadParamPrivacy: "\(NSNumber(value: upload.privacyLevel!.rawValue))",
            kPiwigoImagesUploadParamMimeType: upload.mimeType ?? ""
        ]

        // Get URL of file to upload
        let fileName = upload.localIdentifier.replacingOccurrences(of: "/", with: "-")
        let fileURL = applicationUploadsDirectory.appendingPathComponent(fileName)

        // Launch transfer
        startUploading(fileURL: fileURL, with: imageParameters,
            onProgress: { (progress, currentChunk, totalChunks) in
                let chunkProgress: Float = Float(currentChunk) / Float(totalChunks)
                let uploadInfo: [String : Any] = ["localIndentifier" : upload.localIdentifier,
                                                  "stateLabel" : kPiwigoUploadState.uploading.stateInfo,
                                                  "Error" : upload.requestError ?? "",
                                                  "progressFraction" : chunkProgress]
                DispatchQueue.main.async {
                    // Update UploadQueue cell and button shown in root album (or default album)
                    NotificationCenter.default.post(name: NSNotification.Name(kPiwigoNotificationUploadProgress), object: nil, userInfo: uploadInfo)
                }
            },
            onCompletion: { [unowned self] (task, jsonData) in
//                    print("•••> completion: \(String(describing: jsonData))")
                // Check returned data
                guard let data = try? JSONSerialization.data(withJSONObject:jsonData ?? "") else {
                    // Update upload request status
                    let error = NSError.init(domain: "Piwigo", code: 0, userInfo: [NSLocalizedDescriptionKey : UploadError.invalidJSONobject.localizedDescription])
                    self.updateUploadRequestWith(upload, error: error)
                    return
                }
                
                // Decode the JSON.
                do {
                    // Decode the JSON into codable type ImagesUploadJSON.
                    let uploadJSON = try self.decoder.decode(ImagesUploadJSON.self, from: data)

                    // Piwigo error?
                    if (uploadJSON.errorCode != 0) {
                        let error = NSError.init(domain: "Piwigo", code: uploadJSON.errorCode, userInfo: [NSLocalizedDescriptionKey : uploadJSON.errorMessage])
                        self.updateUploadRequestWith(upload, error: error)
                        return
                    }
                    
                    // Add image to cache when uploaded by admin users
                    if Model.sharedInstance()?.hasAdminRights ?? false {
                        // Prepare image for cache
                        let imageData = PiwigoImageData.init()
                        imageData.datePosted = Date.init()
                        imageData.fileSize = NSNotFound // will trigger pwg.images.getInfo
                        imageData.imageTitle = upload.imageTitle
                        imageData.categoryIds = [upload.category]
                        imageData.fileName = upload.fileName
                        imageData.isVideo = upload.isVideo
                        imageData.dateCreated = upload.creationDate
                        imageData.author = upload.author
                        imageData.privacyLevel = upload.privacyLevel ?? kPiwigoPrivacy(rawValue: 0)

                        // Add data returned by server
                        imageData.imageId = uploadJSON.data.image_id!
                        imageData.squarePath = uploadJSON.data.square_src
                        imageData.thumbPath = uploadJSON.data.src

                        // Add uploaded image to cache and update UI if needed
                        DispatchQueue.main.async {
                            CategoriesData.sharedInstance()?.addImage(imageData)
                        }
                    }

                    // Update state of upload
                    var uploadProperties = upload
                    uploadProperties.imageId = uploadJSON.data.image_id!
                    self.updateUploadRequestWith(uploadProperties, error: nil)
                    return
                } catch {
                    // Data cannot be digested, image still ready for upload
                    let error = NSError.init(domain: "Piwigo", code: 0, userInfo: [NSLocalizedDescriptionKey : UploadError.wrongJSONobject.localizedDescription])
                    self.updateUploadRequestWith(upload, error: error)
                    return
                }
            },
            onFailure: { (task, error) in
                if let error = error {
                    if ((error.code == 401) ||        // Unauthorized
                        (error.code == 403) ||        // Forbidden
                        (error.code == 404))          // Not Found
                    {
                        print("…notify kPiwigoNotificationNetworkErrorEncountered!")
                        NotificationCenter.default.post(name: NSNotification.Name(kPiwigoNotificationNetworkErrorEncountered), object: nil, userInfo: nil)
                    }
                    // Image still ready for upload
                    self.updateUploadRequestWith(upload, error: error)
                }
            })
    }

    private func updateUploadRequestWith(_ upload: UploadProperties, error: Error?) {

        // Error?
        if let error = error {
            // Could not transfer image
            let uploadProperties = upload.update(with: .uploadingError, error: error.localizedDescription)
            
            // Update request with error description
            print("    >", error.localizedDescription)
            uploadsProvider.updateRecord(with: uploadProperties, completionHandler: { [unowned self] _ in
                // Consider next image
                if self.isExecutingBackgroundUploadTask {
                    // Background operation will stop here
                } else {
                    // In foreground, consider next video
                    self.didEndTransfer()
                }
            })
            return
        }

        // Update state of upload
        let uploadProperties: UploadProperties
        if Model.sharedInstance().usesUploadAsync {
            uploadProperties = upload.update(with: .finished, error: "")
        } else {
            uploadProperties = upload.update(with: .uploaded, error: "")
        }
        
        // Update request ready for finish
        print("    > transferred file \(uploadProperties.fileName!)\r")
        uploadsProvider.updateRecord(with: uploadProperties, completionHandler: { [unowned self] _ in
            // Job done if performed in background
            if self.isExecutingBackgroundUploadTask {
                // Background operation completed successfully
            } else {
                // In foreground, upload ready for next step: finishing or next image
                self.didEndTransfer()
            }
        })
    }

    /**
     Initialises the transfer of an image or a video with a Piwigo server.
     The file is uploaded by sending chunks whose size is defined on the server.
     */
    func startUploading(fileURL: URL, with imageParameters: [String : String],
                        onProgress: @escaping (_ progress: Progress?, _ currentChunk: Int, _ totalChunks: Int) -> Void,
                        onCompletion completion: @escaping (_ task: URLSessionTask?, _ response: Any?) -> Void,
                        onFailure fail: @escaping (_ task: URLSessionTask?, _ error: NSError?) -> Void) {
        
        // Calculate chunk size
        let chunkSize = (Model.sharedInstance()?.uploadChunkSize ?? 512) * 1024

        // Get file to upload
        var imageData: Data? = nil
        do {
            try imageData = NSData (contentsOf: fileURL) as Data
            // Swift bug - https://forums.developer.apple.com/thread/115401
//                    try imageData = Data(contentsOf: exportSession.outputURL!)
        } catch let error as NSError {
            // define error !!!!
            fail(nil, error)
            return
        }

        // Calculate number of chunks
        var chunks = (imageData?.count ?? 0) / chunkSize
        if (imageData?.count ?? 0) % chunkSize != 0 {
            chunks += 1
        }

        // Start sending data to server
        self.sendChunk(imageData, withInformation: imageParameters,
                       forOffset: 0, onChunk: 0, forTotalChunks: chunks,
                       onProgress: onProgress,
                       onCompletion: { task, response, updatedParameters in
                            // Delete uploaded file from Piwigo/Uploads directory
                            do {
                                try FileManager.default.removeItem(at: fileURL)
                            } catch {
                                // Not a big issue, will clean up the directory later
                                completion(task, response)
                                return
                            }
                            // Done, return
                            completion(task, response)
                            // Close upload session
//                            imageUploadManager.invalidateSessionCancelingTasks(true, resetSession: true)
                        },
                       onFailure: { task, error in
                            // Close upload session
//                            imageUploadManager.invalidateSessionCancelingTasks(true, resetSession: true)
                            // Done, return
                            fail(task, error as NSError?)
                        })
    }

    /**
     Sends iteratively chunks of the file.
     */
    private func sendChunk(_ imageData: Data?, withInformation imageParameters: [String:String],
                           forOffset offset: Int, onChunk count: Int, forTotalChunks chunks: Int,
                           onProgress: @escaping (_ progress: Progress?, _ currentChunk: Int, _ totalChunks: Int) -> Void,
                           onCompletion completion: @escaping (_ task: URLSessionTask?, _ response: Any?, _ updatedParameters: [String:String]) -> Void,
                           onFailure fail: @escaping (_ task: URLSessionTask?, _ error: NSError?) -> Void) {
        
        var parameters = imageParameters
        var offset = offset
        
        // Calculate this chunk size
        let chunkSize = (Model.sharedInstance()?.uploadChunkSize ?? 512) * 1024
        let length = imageData?.count ?? 0
        let thisChunkSize = length - offset > chunkSize ? chunkSize : length - offset
        let chunk = imageData?.subdata(in: offset..<offset + thisChunkSize)
        print("    > #\(count) with chunkSize:", chunkSize, "thisChunkSize:", thisChunkSize, "total:", imageData?.count ?? 0)

        parameters[kPiwigoImagesUploadParamChunk] = "\(NSNumber(value: count))"
        parameters[kPiwigoImagesUploadParamChunks] = "\(NSNumber(value: chunks))"

        let nextChunkNumber = count + 1
        offset += thisChunkSize

        // Check current queue
        print("•••>> sendChunk() before portMultipart •••>>", queueName())
        NetworkHandler.postMultiPart(kPiwigoImagesUpload, data: chunk, parameters: parameters,
                                     sessionManager: sessionManager,
           progress: { progress in
                if progress != nil {
                    onProgress(progress, count + 1, chunks)
                }
            },
           success: { task, responseObject in
                // Continue in background queue!
                DispatchQueue.global(qos: .background).async {
                    // Continue?
                    print("    > #\(count) done:", responseObject.debugDescription)
                    if count >= chunks - 1 {
                        // Done, return
                        print("=>> MimeType:", task?.response?.mimeType as Any)
                        completion(task, responseObject, parameters)
                    } else {
                        // Keep going!
                        self.sendChunk(imageData, withInformation: parameters,
                                       forOffset: offset, onChunk: nextChunkNumber, forTotalChunks: chunks,
                                       onProgress: onProgress, onCompletion: completion, onFailure: fail)
                    }
                }
            },
           failure: { task, error in
                // Continue in background queue!
                DispatchQueue.global(qos: .background).async {
                    // failed!
                    fail(task, error as NSError?)
                }
            })
    }

    
    // MARK: - Transfer Image in Background
    // See https://tools.ietf.org/html/rfc7578
    func transferInBackgroundImage(of upload: UploadProperties) {
        print("    > imageInBackgroundForRequest: prepare files...")
        
        // Get URL of file to upload
        /// This file will be deleted once the transfer completed successfully
        let fileName = upload.localIdentifier.replacingOccurrences(of: "/", with: "-")
        let fileURL = applicationUploadsDirectory.appendingPathComponent(fileName)
        
        // Get content of file to upload
        var imageData: Data = Data()
        do {
            try imageData = NSData (contentsOf: fileURL) as Data
        }
        catch let error as NSError {
            // define error !!!!
            print(error.localizedDescription)
            return
        }

        // Calculate number of chunks
        let fileSize = imageData.count
        let chunkSize = (Model.sharedInstance()?.uploadChunkSize ?? 512) * 1024
        let chunks = Int((Float(imageData.count) / Float(chunkSize)).rounded(.up))
        let chunksStr = String(format: "%ld", chunks)
        
        // For producing filename suffixes
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .none
        numberFormatter.minimumIntegerDigits = 5

        // Prepare URL
        let url = URL(string: NetworkHandler.getURLWithPath(kPiwigoImagesUploadAsync, withURLParams: nil))
        guard let validUrl = url else { fatalError() }
        
        // Prepare creation date
        var creationDate = ""
        if let date = upload.creationDate {
            let dateFormat = DateFormatter()
            dateFormat.dateFormat = "yyyy-MM-dd HH:mm:ss"
            creationDate = dateFormat.string(from: date)
        }

        // Prepare files, requests and resume tasks
        let username = Model.sharedInstance()?.username ?? ""
        let password = SAMKeychain.password(forService: Model.sharedInstance().serverPath, account: username) ?? ""
        let boundary = createBoundary(from: upload.localIdentifier)
        for chunk in 0..<chunks {
            // Current chunk
            let chunkStr = String(format: "%ld", chunk)
            
            // HTTP request body
            let httpBody = NSMutableData()
            httpBody.appendString(convertFormField(named: "username", value: username, using: boundary))
            httpBody.appendString(convertFormField(named: "password", value: password, using: boundary))
            httpBody.appendString(convertFormField(named: "chunk", value: chunkStr, using: boundary))
            httpBody.appendString(convertFormField(named: "chunks", value: chunksStr, using: boundary))
            httpBody.appendString(convertFormField(named: "original_sum", value: upload.md5Sum!, using: boundary))
            httpBody.appendString(convertFormField(named: "category", value: "\(upload.category)", using: boundary))
            httpBody.appendString(convertFormField(named: "filename", value: upload.fileName ?? "Image.jpg", using: boundary))
            httpBody.appendString(convertFormField(named: "name", value: upload.imageTitle ?? "", using: boundary))
            httpBody.appendString(convertFormField(named: "author", value: upload.author ?? "", using: boundary))
            httpBody.appendString(convertFormField(named: "comment", value: upload.comment ?? "", using: boundary))
            httpBody.appendString(convertFormField(named: "date_creation", value: creationDate, using: boundary))
            httpBody.appendString(convertFormField(named: "level", value: "\(NSNumber(value: upload.privacyLevel!.rawValue))", using: boundary))
            httpBody.appendString(convertFormField(named: "tag_ids", value: upload.tagIds ?? "", using: boundary))

            let chunkOfData = imageData.subdata(in: chunk * chunkSize..<min((chunk+1)*chunkSize, imageData.count))
            httpBody.append(convertFileData(fieldName: "file",
                                            fileName: upload.fileName!,
                                            mimeType: upload.mimeType ?? "image/jpg",
                                            fileData: chunkOfData,
                                            using: boundary))

            httpBody.appendString("--\(boundary)--")

            // File name of chunk data stored into Piwigo/Uploads directory
            // This file will be deleted after a successful upload of the chunk
            let chunkFileName = fileName + "." + numberFormatter.string(from: NSNumber(value: chunk))!
            let fileURL = applicationUploadsDirectory.appendingPathComponent(chunkFileName)
            
            // Deletes temporary image file if exists (incomplete previous attempt?)
            do {
                try FileManager.default.removeItem(at: fileURL)
            } catch {
            }

            // Store chunk of image data into Piwigo/Uploads directory
            do {
                try httpBody.write(to: fileURL)
            } catch let error as NSError {
                // Disk full? —> to be managed…
                print(error)
                return
            }
            
            // Prepare URL Request Object
            var request = URLRequest(url: validUrl)
            request.httpMethod = "POST"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            request.setValue(upload.fileName!, forHTTPHeaderField: "filename")
            request.addValue(upload.localIdentifier, forHTTPHeaderField: "identifier")
            request.addValue(String(fileSize), forHTTPHeaderField: "size")
            request.addValue(upload.md5Sum!, forHTTPHeaderField: "md5sum")
            request.addValue(chunkStr, forHTTPHeaderField: "chunk")
            request.addValue(chunksStr, forHTTPHeaderField: "chunks")
            request.addValue("1", forHTTPHeaderField: "tries")

            // As soon as tasks are created, the timeout counter starts
            let uploadSession: URLSession = UploadSessionDelegate.shared.uploadSession
            uploadSession.configuration.isDiscretionary = false
            uploadSession.configuration.allowsCellularAccess = !(Model.sharedInstance()?.wifiOnlyUploading ?? false)
            let task = uploadSession.uploadTask(with: request, fromFile: fileURL)
            if #available(iOS 11.0, *) {
                // Tell the system how many bytes are expected to be exchanged
                print("    > Upload task \(task.taskIdentifier) will send \(httpBody.count) bytes")
                task.countOfBytesClientExpectsToSend = Int64(httpBody.count)
                task.countOfBytesClientExpectsToReceive = 600
            }
            print("    > Upload task \(task.taskIdentifier) resumed at \(DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium))")
            task.resume()
        }
    }

    func didCompleteUploadTask(_ task: URLSessionTask, withError error: Error?) {
        
        // Get upload info from task
        guard let identifier = task.originalRequest?.value(forHTTPHeaderField: "identifier"),
            let chunk = Int((task.originalRequest?.value(forHTTPHeaderField: "chunk"))!),
            let tries = Int((task.originalRequest?.value(forHTTPHeaderField: "tries"))!) else {
            print("   > Could not extract HTTP header fields !!!!!!")
            return
        }

        // For producing the chunk filename
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .none
        numberFormatter.minimumIntegerDigits = 5

        // Handle the response here
        guard let httpResponse = task.response as? HTTPURLResponse,
            (200...299).contains(httpResponse.statusCode) else {
            if let _ = error {
                print("\(error!.localizedDescription)")
            }

            // Retry if failed less than twice
            if tries < 3 {
                // Prepare URL Request Object
                var request = task.originalRequest!
                let triesStr = String(format: "%ld", tries + 1)
                request.setValue(triesStr, forHTTPHeaderField: "tries")

                // File name of chunk data stored into Piwigo/Uploads directory
                // This file will be deleted after a successful upload so that we can reuse it in case of error.
                let fileName = identifier.replacingOccurrences(of: "/", with: "-")
                let chunkFileName = fileName + "." + numberFormatter.string(from: NSNumber(value: chunk))!
                let fileURL = applicationUploadsDirectory.appendingPathComponent(chunkFileName)
                if !FileManager.default.fileExists(atPath: fileURL.path) {
                    // The file does not exist - upload succeeded with reloaded previous chunk
                    return
                }
                
                // As soon as tasks are created, the timeout counter starts
                let uploadSession: URLSession = UploadSessionDelegate.shared.uploadSession
                uploadSession.configuration.isDiscretionary = false
                uploadSession.configuration.allowsCellularAccess = !(Model.sharedInstance()?.wifiOnlyUploading ?? false)
                let repeatedTask = uploadSession.uploadTask(with: request, fromFile: fileURL)
                if #available(iOS 11.0, *) {
                    // Tell the system how many bytes are expected to be exchanged
                    let fileSize = (try! FileManager.default.attributesOfItem(atPath: fileURL.path)[FileAttributeKey.size] as! NSNumber).uint64Value
                    print("    > Upload repeated task \(repeatedTask.taskIdentifier) will send \(fileSize) bytes")
                    repeatedTask.countOfBytesClientExpectsToSend = Int64(fileSize)
                    repeatedTask.countOfBytesClientExpectsToReceive = 600
                }
                print("    > Upload repeated task \(repeatedTask.taskIdentifier) resumed at \(DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium))")
                repeatedTask.resume()
            } else {
                // Delete chunk file uploaded successfully from Piwigo/Uploads directory
                let imageFile = identifier.replacingOccurrences(of: "/", with: "-")
                let chunkFileName = imageFile + "." + numberFormatter.string(from: NSNumber(value: chunk))!
                deleteFilesInUploadsDirectory(with: chunkFileName)
            }
            return
        }

        // Delete chunk file uploaded successfully from Piwigo/Uploads directory
        let imageFile = identifier.replacingOccurrences(of: "/", with: "-")
        let chunkFileName = imageFile + "." + numberFormatter.string(from: NSNumber(value: chunk))!
        deleteFilesInUploadsDirectory(with: chunkFileName)
    }

    func didCompleteUploadTask(_ task: URLSessionTask, withData data: Data) {
        // Retrieve task parameters
        guard let identifier = task.originalRequest?.value(forHTTPHeaderField: "identifier") else {
            return
        }
        
        // Retrieve corresponding upload properties
        // Considers only uploads to the server to which the user is logged in
        let states: [kPiwigoUploadState] = [.waiting, .preparing, .preparingError,
                                            .prepared, .uploading, .uploadingError,
                                            .uploaded, .finishing, .finishingError,
                                            .finished, .moderated]
        guard let uploadObject = uploadsProvider.getRequestsIn(states: states)?.filter({$0.localIdentifier == identifier}).first else {
            print("    > Did not find upload object in didCompleteUploadTask() !!!!!!!")
            return
        }

        // Set upload properties
        var upload: UploadProperties
        if uploadObject.isFault {
            // The upload request is not fired yet.
            // Happens after a crash during an upload for example
            uploadObject.willAccessValue(forKey: nil)
            upload = uploadObject.getUploadProperties(with: .uploading, error: "")
            uploadObject.didAccessValue(forKey: nil)
        } else {
            upload = uploadObject.getUploadProperties(with: uploadObject.state, error: uploadObject.requestError)
        }
        upload = uploadObject.getUploadProperties(with: .uploading, error: "")

        // Check returned data
        guard let _ = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: AnyObject] else {
            // Check if this transfer is already known to be failed
            // because a previous chunk transfer may have already reported the error
            if upload.requestState == .uploadingError { return }
            // Update upload request status
            let error = NSError.init(domain: "Piwigo", code: 0, userInfo: [NSLocalizedDescriptionKey : UploadError.invalidJSONobject.localizedDescription])
            self.updateUploadRequestWith(upload, error: error)
            return
        }

        // Decode the JSON.
        do {
            // Decode the JSON into codable type ImagesUploadJSON.
            let uploadJSON = try self.decoder.decode(ImagesUploadAsyncJSON.self, from: data)

            // Piwigo error?
            if (uploadJSON.errorCode != 0) {
               let error = NSError.init(domain: "Piwigo", code: uploadJSON.errorCode, userInfo: [NSLocalizedDescriptionKey : uploadJSON.errorMessage])
               self.updateUploadRequestWith(upload, error: error)
               return
            }

            // Add image to cache when uploaded by admin users
            if let getInfos = uploadJSON.data, let imageId = getInfos.imageId, imageId != NSNotFound,
                Model.sharedInstance()?.hasAdminRights ?? false {
                // Prepare image for cache
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

                let imageData = PiwigoImageData.init()
                imageData.imageId = uploadJSON.data.imageId!
                imageData.categoryIds = [upload.category]
                imageData.imageTitle = NetworkHandler.utf8EncodedString(from: uploadJSON.data.imageTitle ?? "")
                imageData.comment = NetworkHandler.utf8EncodedString(from: uploadJSON.data.comment ?? "")
                imageData.visits = uploadJSON.data.visits ?? 0
                imageData.fileName = uploadJSON.data.fileName ?? upload.fileName
                imageData.isVideo = upload.isVideo
                imageData.datePosted = dateFormatter.date(from: uploadJSON.data.datePosted ?? "") ?? Date.init()
                imageData.dateCreated = dateFormatter.date(from: uploadJSON.data.dateCreated ?? "") ?? upload.creationDate

                imageData.fullResPath = NetworkHandler.encodedImageURL(uploadJSON.data.fullResPath)
                imageData.fullResWidth = uploadJSON.data.fullResWidth ?? 1
                imageData.fullResHeight = uploadJSON.data.fullResHeight ?? 1
                imageData.squarePath = NetworkHandler.encodedImageURL(uploadJSON.derivatives?.squareImage?.url)
                imageData.squareWidth = uploadJSON.derivatives?.squareImage?.width ?? 1
                imageData.squareHeight = uploadJSON.derivatives?.squareImage?.height ?? 1
                imageData.thumbPath = NetworkHandler.encodedImageURL(uploadJSON.derivatives?.thumbImage?.url)
                imageData.thumbWidth = uploadJSON.derivatives?.thumbImage?.width ?? 1
                imageData.thumbHeight = uploadJSON.derivatives?.thumbImage?.height ?? 1
                imageData.mediumPath = NetworkHandler.encodedImageURL(uploadJSON.derivatives?.mediumImage?.url)
                imageData.mediumWidth = uploadJSON.derivatives?.mediumImage?.width ?? 1
                imageData.mediumHeight = uploadJSON.derivatives?.mediumImage?.height ?? 1
                imageData.xxSmallPath = NetworkHandler.encodedImageURL(uploadJSON.derivatives?.xxSmallImage?.url)
                imageData.xxSmallWidth = uploadJSON.derivatives?.xxSmallImage?.width ?? 1
                imageData.xxSmallHeight = uploadJSON.derivatives?.xxSmallImage?.height ?? 1
                imageData.xSmallPath = NetworkHandler.encodedImageURL(uploadJSON.derivatives?.xSmallImage?.url)
                imageData.xSmallWidth = uploadJSON.derivatives?.xSmallImage?.width ?? 1
                imageData.xSmallHeight = uploadJSON.derivatives?.xSmallImage?.height ?? 1
                imageData.smallPath = NetworkHandler.encodedImageURL(uploadJSON.derivatives?.smallImage?.url)
                imageData.smallWidth = uploadJSON.derivatives?.smallImage?.width ?? 1
                imageData.smallHeight = uploadJSON.derivatives?.smallImage?.height ?? 1
                imageData.largePath = NetworkHandler.encodedImageURL(uploadJSON.derivatives?.largeImage?.url)
                imageData.largeWidth = uploadJSON.derivatives?.largeImage?.width ?? 1
                imageData.largeHeight = uploadJSON.derivatives?.largeImage?.height ?? 1
                imageData.xLargePath = NetworkHandler.encodedImageURL(uploadJSON.derivatives?.xLargeImage?.url)
                imageData.xLargeWidth = uploadJSON.derivatives?.xLargeImage?.width ?? 1
                imageData.xLargeHeight = uploadJSON.derivatives?.xLargeImage?.height ?? 1
                imageData.xxLargePath = NetworkHandler.encodedImageURL(uploadJSON.derivatives?.xxLargeImage?.url)
                imageData.xxLargeWidth = uploadJSON.derivatives?.xxLargeImage?.width ?? 1
                imageData.xxLargeHeight = uploadJSON.derivatives?.xxLargeImage?.height ?? 1

                imageData.author = uploadJSON.data.author ?? "NSNotFound"
                if let privacyLevel = uploadJSON.data.privacyLevel {
                    imageData.privacyLevel = kPiwigoPrivacy(rawValue: UInt32(privacyLevel) ?? kPiwigoPrivacyUnknown.rawValue)
                }

                // Switch to old cache data format
                var tagList = [PiwigoTagData]()
                if let tags: [TagProperties] = uploadJSON.data?.tags {
                    tags.forEach { (tag) in
                        let newTag = PiwigoTagData.init()
                        newTag.tagId = Int(tag.id!)
                        newTag.tagName = tag.name
                        newTag.lastModified = dateFormatter.date(from: tag.lastmodified ?? "")
                        newTag.numberOfImagesUnderTag = tag.counter ?? 0
                        tagList.append(newTag)
                    }
                }
                imageData.tags = tagList
                imageData.ratingScore = uploadJSON.data.ratingScore  ?? 0.0
                imageData.fileSize = uploadJSON.data.fileSize ?? NSNotFound // will trigger pwg.images.getInfo
                imageData.md5checksum = uploadJSON.data.md5checksum ?? upload.md5Sum
                
                // Add uploaded image to cache and update UI if needed
                DispatchQueue.main.async {
                    CategoriesData.sharedInstance()?.addImage(imageData)
                }

                // Delete main file
                let fileName = upload.localIdentifier.replacingOccurrences(of: "/", with: "-")
                let fileURL = applicationUploadsDirectory.appendingPathComponent(fileName)
                do {
                    try FileManager.default.removeItem(at: fileURL)
                } catch {
                    print("Could not delete upload file: \(error)")
                }

                // Update state of upload
                var uploadProperties = upload
                uploadProperties.imageId = uploadJSON.data.imageId!
                self.updateUploadRequestWith(uploadProperties, error: nil)
            }
            return
        } catch {
           // JSON object cannot be digested, image still ready for upload
           let error = NSError.init(domain: "Piwigo", code: 0, userInfo: [NSLocalizedDescriptionKey : UploadError.wrongJSONobject.localizedDescription])
           self.updateUploadRequestWith(upload, error: error)
           return
        }
    }

    func createBoundary(from identifier: String) -> String {
        /// We don't use the UUID to be able to test uploads with a simulator.
        let suffix = identifier.replacingOccurrences(of: "/", with: "").map { $0.lowercased() }.joined()
        let boundary = String(repeating: "-", count: 68 - suffix.count) + suffix
        print("    > \(boundary)")
        return boundary
    }

    func convertFormField(named name: String, value: String, using boundary: String) -> String {
      var fieldString = "--\(boundary)\r\n"
      fieldString += "Content-Disposition: form-data; name=\"\(name)\"\r\n"
      fieldString += "\r\n"
      fieldString += "\(value)\r\n"

      return fieldString
    }
    
    func convertFileData(fieldName: String, fileName: String, mimeType: String, fileData: Data, using boundary: String) -> Data {
      let data = NSMutableData()

      data.appendString("--\(boundary)\r\n")
      data.appendString("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n")
      data.appendString("Content-Type: \(mimeType)\r\n\r\n")
      data.append(fileData)
      data.appendString("\r\n")

      return data as Data
    }
    
    func essai() {
        let url = URL(string: "https://lelievre-berna.net/Piwigo/ws.php?format=json&method=pwg.session.getStatus")

        var request = URLRequest(url: url!)
        request.httpMethod = "post"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("utf-8", forHTTPHeaderField: "Accept-Charset")

//        let jsonDict: [String:Any] = [:]
//        let jsonData = try! JSONSerialization.data(withJSONObject: jsonDict, options: [])
//        request.httpBody = jsonData

        URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                print("error:", error)
                return
            }

            do {
                guard let data = data else { return }
                guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: AnyObject] else { return }
                print("json:", json)
            } catch {
                print("error:", error)
            }
        }.resume()
    }

    func essai2() {
        let url = URL(string: "https://lelievre-berna.net/Piwigo/ws.php?format=json&method=pwg.images.getInfo&image_id=236")

        var request = URLRequest(url: url!)
        request.httpMethod = "get"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("utf-8", forHTTPHeaderField: "Accept-Charset")

        URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                print("error:", error)
                return
            }

            do {
                guard let data = data else { return }
                guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: AnyObject] else { return }
                print("json:", json)
            } catch {
                print("error:", error)
            }
        }.resume()
    }

}

extension NSMutableData {
  func appendString(_ string: String) {
    if let data = string.data(using: .utf8) {
      self.append(data)
    }
  }
}
