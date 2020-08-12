//
//  UploadTransfer.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 21/05/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

extension UploadManager {
    
    // MARK: - Transfer Image in Foreground
    func transferImage(of upload: UploadProperties) {
        print("    > imageOfRequest...")

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
                                                  "photoResize" : Int16(upload.photoResize),
                                                  "stateLabel" : kPiwigoUploadState.uploading.stateInfo,
                                                  "Error" : upload.requestError ?? "",
                                                  "progressFraction" : chunkProgress]
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: NSNotification.Name(kPiwigoNotificationUploadProgress), object: nil, userInfo: uploadInfo)
                }
            },
            onCompletion: { [unowned self] (task, jsonData) in
//                    print("•••> completion: \(String(describing: jsonData))")
                // Check returned data
                guard let data = try? JSONSerialization.data(withJSONObject:jsonData ?? "") else {
                    // Update upload request status
                    let error = NSError.init(domain: "Piwigo", code: 0, userInfo: [NSLocalizedDescriptionKey : UploadError.networkUnavailable.localizedDescription])
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
                    let error = NSError.init(domain: "Piwigo", code: 0, userInfo: [NSLocalizedDescriptionKey : UploadError.wrongDataFormat.localizedDescription])
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
            // Could not prepare image
            let uploadProperties = upload.update(with: .uploadingError, error: error.localizedDescription)
            
            // Update request with error description
            print("    >", error.localizedDescription)
            uploadsProvider.updateRecord(with: uploadProperties, completionHandler: { [unowned self] _ in
                // Consider next image
                self.setIsUploading(status: false)
            })
            return
        }

        // Update state of upload
        let uploadProperties = upload.update(with: .uploaded, error: "")

        // Update request ready for finish
        print("    > transferred file \(uploadProperties.fileName!)")
        uploadsProvider.updateRecord(with: uploadProperties, completionHandler: { [unowned self] _ in
            // Upload ready for transfer
            self.setIsUploading(status: false)
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
        let chunkSize = Model.sharedInstance().uploadChunkSize * 1024

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
        let chunkSize = Model.sharedInstance().uploadChunkSize * 1024
        let length = imageData?.count ?? 0
        let thisChunkSize = length - offset > chunkSize ? chunkSize : length - offset
        let chunk = imageData?.subdata(in: offset..<offset + thisChunkSize)
        print("    > #\(count) with chunkSize:", chunkSize, "thisChunkSize:", thisChunkSize, "total:", imageData?.count ?? 0)

        parameters[kPiwigoImagesUploadParamChunk] = "\(NSNumber(value: count))"
        parameters[kPiwigoImagesUploadParamChunks] = "\(NSNumber(value: chunks))"

        let nextChunkNumber = count + 1
        offset += thisChunkSize

        NetworkHandler.postMultiPart(kPiwigoImagesUpload, data: chunk, parameters: parameters,
                                     sessionManager: sessionManager,
           progress: { progress in
                DispatchQueue.main.async(execute: {
                    if progress != nil {
                        onProgress(progress, count + 1, chunks)
                    }
                })
            },
           success: { task, responseObject in
                // Continue?
                print("    > #\(count) done:", responseObject.debugDescription)
                if count >= chunks - 1 {
                    // Done, return
                    print("=>> MimeType: %@", task?.response?.mimeType as Any)
                    completion(task, responseObject, parameters)
                } else {
                    // Keep going!
                    self.sendChunk(imageData, withInformation: parameters,
                                   forOffset: offset, onChunk: nextChunkNumber, forTotalChunks: chunks,
                                   onProgress: onProgress, onCompletion: completion, onFailure: fail)
                }
            },
           failure: { task, error in
                // failed!
                fail(task, error as NSError?)
            })
    }

    
    // MARK: - Transfer Image in Background
    // See https://tools.ietf.org/html/rfc7578
    func transferInBackgroundImage(of upload: UploadProperties) {
        print("    > imageInBackgroundForRequest: prepare files...")
        
        // Get URL of file to upload
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
        let chunkSize = Model.sharedInstance().uploadChunkSize * 1024
        let chunks = Int((Float(imageData.count) / Float(chunkSize)).rounded(.up))
        let chunksStr = String(format: "%ld", chunks)
        
        // For producing filename suffixes
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .none
        numberFormatter.minimumIntegerDigits = 5

        // Prepare files
        let boundary = createBoundary(from: upload.localIdentifier)
        for chunk in 0..<chunks {
            // Current chunk
            let chunkStr = String(format: "%ld", chunk)
            
            // HTTP request body
            let httpBody = NSMutableData()
            httpBody.appendString(convertFormField(named: "name", value: upload.fileName!, using: boundary))
            httpBody.appendString(convertFormField(named: "chunk", value: chunkStr, using: boundary))
            httpBody.appendString(convertFormField(named: "chunks", value: chunksStr, using: boundary))
            httpBody.appendString(convertFormField(named: "category", value: "\(upload.category)", using: boundary))
            httpBody.appendString(convertFormField(named: "level", value: "\(upload.privacyLevel!.rawValue)", using: boundary))
            httpBody.appendString(convertFormField(named: "pwg_token", value: (Model.sharedInstance()?.pwgToken)!, using: boundary))

            let chunkOfData = imageData.subdata(in: chunk * chunkSize..<min((chunk+1)*chunkSize, imageData.count))
            httpBody.append(convertFileData(fieldName: "file",
                                            fileName: upload.fileName!,
                                            mimeType: upload.mimeType ?? "image/jpg",
                                            fileData: chunkOfData,
                                            using: boundary))

            httpBody.appendString("--\(boundary)--")

            // File name of chunk data to be stored into Piwigo/Uploads directory
            let chunkFileName = fileName + "." + numberFormatter.string(from: NSNumber(value: chunk))!
            let fileURL = applicationUploadsDirectory.appendingPathComponent(chunkFileName)
            
            // Deletes temporary image file if exists (incomplete previous attempt?)
            do {
                try FileManager.default.removeItem(at: fileURL)
            } catch {
            }

            // Store final image data into Piwigo/Uploads directory
            do {
                try httpBody.write(to: fileURL)
            } catch let error as NSError {
                // Disk full? —> to be managed…
                print(error)
                return
            }
        }

        // How many chunks to upload?
//        if chunks == 1 {
            // Upload single chunk
            send(chunk: 0, of: chunks, for: upload.localIdentifier)
//        } else {
//            // Upload all chunks except last one,
//            // because Piwigo expect to have received all chunks when it receives the last one.
//            for chunk in 0..<chunks-1 {
//                send(chunk: chunk, of: chunks, for: upload.localIdentifier)
//            }
//        }
    }
    
    func send(chunk: Int, of chunks:Int, for uploadIdentifier: String) {
        
        // Retrieve corresponding upload properties
        guard let uploadObject = uploadsProvider.getRequestsIn(states: [.finished, .preparingFail, .formatError])?.filter({$0.localIdentifier == uploadIdentifier}).first else {
            return
        }
        let upload: UploadProperties = uploadObject.getUploadProperties(with: .uploading, error: "")
        let boundary = createBoundary(from: uploadIdentifier)

        // Prepare URL
        let url = URL(string: "https://lelievre-berna.net/Piwigo/ws.php?format=json&method=pwg.images.upload")
        guard let validUrl = url else { fatalError() }

        // Prepare URL Request Object
        var request = URLRequest(url: validUrl)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue(upload.fileName!, forHTTPHeaderField: "filename")
        request.addValue(upload.localIdentifier, forHTTPHeaderField: "identifier")
        request.addValue(String(chunk), forHTTPHeaderField: "chunk")
        request.addValue(String(chunks), forHTTPHeaderField: "chunks")

        // For producing filename suffixes
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .none
        numberFormatter.minimumIntegerDigits = 5

        // File name of chunk data to be stored into Piwigo/Uploads directory
        let filenamePrefix = upload.localIdentifier.replacingOccurrences(of: "/", with: "-")
        let chunkFileName = filenamePrefix + "." + numberFormatter.string(from: NSNumber(value: chunk))!
        let fileURL = applicationUploadsDirectory.appendingPathComponent(chunkFileName)

        // Get content of file to upload
//        var httpBody: Data = Data()
//        do {
//            try httpBody = NSData (contentsOf: fileURL) as Data
//        }
//        catch let error as NSError {
//            // define error !!!!
//            print(error.localizedDescription)
//            return
//        }

        // Launch upload task
//        request.httpBody = httpBody
//        let task = URLSession.shared.dataTask(with: request) { data, response, error in
//        let task = URLSession.shared.uploadTask(with: request, from: httpBody as Data) { (data, response, error) in
//        let task = URLSession.shared.uploadTask(with: request, fromFile: fileURL) { (data, response, error) in
            
        // As soon as tasks are created, the timeout counter starts
        let uploadSession: URLSession = UploadSessionDelegate.shared.uploadSession
        let task = uploadSession.uploadTask(with: request, fromFile: fileURL)
//        let task = uploadSession.uploadTask(with: request, fromFile: fileURL) { (data, response, error) in
//            // handle the response here
//            guard let httpResponse = response as? HTTPURLResponse,
//                (200...299).contains(httpResponse.statusCode) else {
//                    if let _ = error {
//                        print("\(error!.localizedDescription)")
//                    }
//                  if let responseString = String(data: data!, encoding: .utf8) {
//                    print("\(responseString)")
//                  }
//              return
//            }
////            print("MimeType: \(String(describing: httpResponse.mimeType))")
//
//            // Check returned data
//            do {
//                guard let data = data else { return }
//                guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: AnyObject] else { return }
//                print(JSONSerialization.isValidJSONObject(json) ? "is Valid JSON Object ;-)" : "is Not Valid JSON Object :=(")
//                print("json:", json)
//
//               // Decode the JSON.
//                do {
//                    // Decode the JSON into codable type ImagesUploadJSON.
//                    let uploadJSON = try self.decoder.decode(ImagesUploadJSON.self, from: data)
//
//                    // Piwigo error?
//                    if (uploadJSON.errorCode != 0) {
//                       let error = NSError.init(domain: "Piwigo", code: uploadJSON.errorCode, userInfo: [NSLocalizedDescriptionKey : uploadJSON.errorMessage])
//                       self.updateUploadRequestWith(upload, error: error)
//                       return
//                    }
//
//                    if uploadJSON.data.image_id == NSNotFound {
//                        // Update UI
//                        let chunkProgress: Float = Float(chunk+1) / Float(chunks)
//                        let uploadInfo: [String : Any] = ["localIndentifier" : upload.localIdentifier,
//                                                          "photoResize" : Int16(upload.photoResize),
//                                                          "stateLabel" : kPiwigoUploadState.uploading.stateInfo,
//                                                          "Error" : upload.requestError ?? "",
//                                                          "progressFraction" : chunkProgress]
//                        DispatchQueue.main.async {
//                            NotificationCenter.default.post(name: NSNotification.Name(kPiwigoNotificationUploadProgress), object: nil, userInfo: uploadInfo)
//                        }
//                        // Continue with next chunk
////                        self.send(chunk: chunk + 1, of: chunks, for: upload.localIdentifier)
//                        return
//                    } else {
//                        // Prepare image for cache
//                        let imageData = PiwigoImageData.init()
//                        imageData.datePosted = Date.init()
//                        imageData.fileSize = NSNotFound // will trigger pwg.images.getInfo
//                        imageData.imageTitle = upload.imageTitle
//                        imageData.categoryIds = [upload.category]
//                        imageData.fileName = upload.fileName
//                        imageData.isVideo = upload.isVideo
//                        imageData.dateCreated = upload.creationDate
//                        imageData.author = upload.author
//                        imageData.privacyLevel = upload.privacyLevel ?? kPiwigoPrivacy(rawValue: 0)
//
//                        // Get data from server response
//                        imageData.imageId = uploadJSON.data.image_id!
//                        imageData.squarePath = uploadJSON.data.square_src
//                        imageData.thumbPath = uploadJSON.data.src
//
//                        // Add uploaded image to cache and update UI if needed
//                        DispatchQueue.main.async {
//                            CategoriesData.sharedInstance()?.addImage(imageData)
//                        }
//
//                        // Delete uploaded files from Piwigo/Uploads directory
//                        let filenamePrefix = upload.localIdentifier.replacingOccurrences(of: "/", with: "-")
//                        self.deleteFilesInUploadsDirectory(with: filenamePrefix)
//
//                        // Update state of upload
//                        var uploadProperties = upload
//                        uploadProperties.imageId = imageData.imageId
//                        self.updateUploadRequestWith(uploadProperties, error: nil)
//                    }
//                    return
//                } catch {
//                   // Data cannot be digested, image still ready for upload
//                   let error = NSError.init(domain: "Piwigo", code: 0, userInfo: [NSLocalizedDescriptionKey : UploadError.wrongDataFormat.localizedDescription])
//                   self.updateUploadRequestWith(upload, error: error)
//                   return
//                }
//            } catch {
//                print("error:", error)
//                print("Not a valid JSON object!!")
//            }
//        }
        
        if #available(iOS 11.0, *) {
            // Determine file size
            var fileSize = Int64(Model.sharedInstance()?.uploadChunkSize ?? 512000)
            if let size = try? FileManager.default.attributesOfItem(atPath: fileURL.absoluteString)[FileAttributeKey.size] as? Int64 {
                fileSize = size
            }
            // Tell the system how many bytes are expected to be exchanged
            print("    > Upload task \(task.taskIdentifier) will send \(fileSize + 500) bytes")
            task.countOfBytesClientExpectsToSend = fileSize + 500
            task.countOfBytesClientExpectsToReceive = 600
        } else {
            // Fallback on earlier versions
        }
        print("    > Upload task \(task.taskIdentifier) resumed at \(DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium))")
        task.resume()
    }

    func didCompleteUploadTask(_ task: URLSessionTask, withError error: Error?) {
        // handle the response here
        guard let httpResponse = task.response as? HTTPURLResponse,
            (200...299).contains(httpResponse.statusCode) else {
            if let _ = error {
                print("\(error!.localizedDescription)")
            }
            return
        }
    }

    func didCompleteUploadTask(_ task: URLSessionTask, withData data: Data) {
        // Check returned data
        do {
            guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: AnyObject] else { return }
            print(JSONSerialization.isValidJSONObject(json) ? "    > returned valid JSON object ;-)" : "    > Did not return valid JSON object :=(")
            print("    > JSON object of", json.count, "bytes")
            
            // Retrieve task parameters
            guard let identifier = task.originalRequest?.value(forHTTPHeaderField: "identifier"),
                let chunk = Int((task.originalRequest?.value(forHTTPHeaderField: "chunk"))!),
                let chunks = Int((task.originalRequest?.value(forHTTPHeaderField: "chunks"))!) else {
                    return
            }
            
            // Retrieve corresponding upload properties
            guard let uploadObject = uploadsProvider.getRequestsIn(states: [.finished, .preparingFail, .formatError])?.filter({$0.localIdentifier == identifier}).first else {
                return
            }
            let upload: UploadProperties = uploadObject.getUploadProperties(with: .uploading, error: "")

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

                if uploadJSON.data.image_id == NSNotFound {
                    // Update UI
                    let chunkProgress: Float = Float(chunk+1) / Float(chunks)
                    let uploadInfo: [String : Any] = ["localIndentifier" : upload.localIdentifier,
                                                      "photoResize" : Int16(upload.photoResize),
                                                      "stateLabel" : kPiwigoUploadState.uploading.stateInfo,
                                                      "Error" : upload.requestError ?? "",
                                                      "progressFraction" : chunkProgress]
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: NSNotification.Name(kPiwigoNotificationUploadProgress), object: nil, userInfo: uploadInfo)
                    }
                    
                    // Are all preliminary chunks uploaded?
//                    if chunk + 1 == chunks - 1 {
                        // Remains to upload the last chunk
                        self.send(chunk: chunk + 1, of: chunks, for: upload.localIdentifier)
//                    }
                } else {
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

                    // Delete uploaded files from Piwigo/Uploads directory
                    let filenamePrefix = upload.localIdentifier.replacingOccurrences(of: "/", with: "-")
                    deleteFilesInUploadsDirectory(with: filenamePrefix)

                    // Update state of upload
                    var uploadProperties = upload
                    uploadProperties.imageId = uploadJSON.data.image_id!
                    self.updateUploadRequestWith(uploadProperties, error: nil)
                }
                return
            } catch {
               // Data cannot be digested, image still ready for upload
               let error = NSError.init(domain: "Piwigo", code: 0, userInfo: [NSLocalizedDescriptionKey : UploadError.wrongDataFormat.localizedDescription])
               self.updateUploadRequestWith(upload, error: error)
               return
            }
        } catch {
            print("error:", error)
            print("Not a valid JSON object!!")
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
//      fieldString += "Content-Type: text/plain; charset=UTF-8\r\n"
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
