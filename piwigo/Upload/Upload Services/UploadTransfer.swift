//
//  UploadTransfer.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 21/05/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

class UploadTransfer {
    
    // MARK: - Shared instances
    /// The UploadsProvider that collects upload data, saves it to Core Data, and serves it to the uploader.
    private lazy var uploadsProvider: UploadsProvider = {
        let provider : UploadsProvider = UploadsProvider()
        return provider
    }()
    /// The UploadManager that prepares and transfers images
    var uploadManager: UploadManager?


    // MARK: - Transfer Image in Foreground
    func imageOfRequest(_ upload: UploadProperties) {
        print("    > imageOfRequest...")

        // Prepare creation date
//        var creationDate = ""
//        if let date = upload.creationDate {
//            let dateFormat = DateFormatter()
//            dateFormat.dateFormat = "yyyy-MM-dd HH:mm:ss"
//            creationDate = dateFormat.string(from: date)
//        }
        
        let imageParameters: [String : String] = [
            kPiwigoImagesUploadParamFileName: upload.fileName ?? "Image.jpg",
//            kPiwigoImagesUploadParamCreationDate: creationDate,
//            kPiwigoImagesUploadParamTitle: upload.imageTitle ?? "",
            kPiwigoImagesUploadParamCategory: "\(NSNumber(value: upload.category))",
            kPiwigoImagesUploadParamPrivacy: "\(NSNumber(value: upload.privacyLevel!.rawValue))",
//            kPiwigoImagesUploadParamAuthor: upload.author ?? "",
//            kPiwigoImagesUploadParamDescription: upload.comment ?? "",
//            kPiwigoImagesUploadParamTags: upload.tagIds ?? "",
            kPiwigoImagesUploadParamMimeType: upload.mimeType ?? ""
        ]

        // Get URL of file to upload
        let fileName = upload.localIdentifier.replacingOccurrences(of: "/", with: "-") + "-" + upload.fileName!
        guard let fileURL = uploadManager?.applicationUploadsDirectory.appendingPathComponent(fileName) else {
            let error = NSError.init(domain: "Piwigo", code: 0, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
            updateUploadRequestWith(upload, error: error)
            return
        }

        // Launch transfer
        startUploading(fileURL: fileURL, with: imageParameters,
            onProgress: { (progress, currentChunk, totalChunks) in
                let chunkProgress: Float = Float(currentChunk) / Float(totalChunks)
                let uploadInfo: [String : Any] = ["localIndentifier" : upload.localIdentifier,
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

                // Case where we uploaded a PNG file… (JSONDecoder() crashes !!)
                let fileExt = (URL(fileURLWithPath: upload.fileName!).pathExtension).lowercased()
                if fileExt == "png" {
                    guard let jsonTypeResponse = jsonData as! [String:Any]?,
                        let stat: String = jsonTypeResponse["stat"] as! String? else {
                        // Upload to be re-started?
                        let error = UploadError.networkUnavailable
                        self.updateUploadRequestWith(upload, error: error)
                        return
                    }
                    if stat == "fail"
                    {
                        // Retrieve Piwigo server error
                        if let errorCode = jsonTypeResponse["err"] as! Int?,
                            let errorMessage = jsonTypeResponse["message"] as! String? {
                            let error = NSError.init(domain: "Piwigo", code: errorCode, userInfo: [NSLocalizedDescriptionKey : errorMessage])
                            self.updateUploadRequestWith(upload, error: error)
                        } else {
                            // Unexpected Piwigo server error
                            let error = NSError.init(domain: "Piwigo", code: -1, userInfo: [NSLocalizedDescriptionKey : "Unexpected error encountered while calling server method with provided parameters."])
                            self.updateUploadRequestWith(upload, error: error)
                        }
                        return
                    }
                    if stat != "ok" {
                        // Data cannot be digested, image still ready for upload
                        let error = NSError.init(domain: "Piwigo", code: -1, userInfo: [NSLocalizedDescriptionKey : UploadError.wrongDataFormat.localizedDescription])
                        self.updateUploadRequestWith(upload, error: error)
                        return
                    }

                    // Get data from server response
                    let result: [String:Any] = jsonTypeResponse["result"] as! [String:Any]
                    imageData.imageId = result["image_id"] as! Int
                    imageData.squarePath = result["square_src"] as? String
                    imageData.thumbPath = result["src"] as? String
                }
                else {
                    // Decode the JSON.
                    do {
                        // Decode the JSON into codable type ImagesUploadJSON.
                        let decoder = JSONDecoder()
                        let uploadJSON = try decoder.decode(ImagesUploadJSON.self, from: data)

                        // Piwigo error?
                        if (uploadJSON.errorCode != 0) {
                            let error = NSError.init(domain: "Piwigo", code: uploadJSON.errorCode, userInfo: [NSLocalizedDescriptionKey : uploadJSON.errorMessage])
                            self.updateUploadRequestWith(upload, error: error)
                            return
                        }
                        
                        // Get data from server response
                        imageData.imageId = uploadJSON.imagesUpload.image_id!
                        imageData.squarePath = uploadJSON.imagesUpload.square_src
                        imageData.thumbPath = uploadJSON.imagesUpload.src
                    } catch {
                        // Data cannot be digested, image still ready for upload
                        let error = NSError.init(domain: "Piwigo", code: 0, userInfo: [NSLocalizedDescriptionKey : UploadError.wrongDataFormat.localizedDescription])
                        self.updateUploadRequestWith(upload, error: error)
                        return
                    }
                }

                // Add uploaded image to cache and update UI if needed
                CategoriesData.sharedInstance()?.addImage(imageData)

                // Update state of upload
                var uploadProperties = upload
                uploadProperties.imageId = imageData.imageId
                self.updateUploadRequestWith(uploadProperties, error: nil)
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
            let uploadProperties = UploadProperties.init(localIdentifier: upload.localIdentifier, category: upload.category,
                requestDate: upload.requestDate, requestState: .uploadingError,
                requestDelete: upload.requestDelete, requestError: error.localizedDescription,
                creationDate: upload.creationDate, fileName: upload.fileName, mimeType: upload.mimeType,
                isVideo: upload.isVideo, author: upload.author, privacyLevel: upload.privacyLevel,
                imageTitle: upload.imageTitle, comment: upload.comment, tagIds: upload.tagIds,
                imageId: upload.imageId)
            
            // Update request with error description
            print("    >", error.localizedDescription)
            uploadsProvider.updateRecord(with: uploadProperties, completionHandler: { _ in
                // Consider next image
                self.uploadManager?.setIsUploading(status: false)
            })
            return
        }

        // Update state of upload
        let uploadProperties = UploadProperties.init(localIdentifier: upload.localIdentifier, category: upload.category,
            requestDate: upload.requestDate, requestState: .uploaded,
            requestDelete: upload.requestDelete, requestError: "",
            creationDate: upload.creationDate, fileName: upload.fileName, mimeType: upload.mimeType,
            isVideo: upload.isVideo, author: upload.author, privacyLevel: upload.privacyLevel,
            imageTitle: upload.imageTitle, comment: upload.comment, tagIds: upload.tagIds, imageId: upload.imageId)

        // Update request ready for finish
        print("    > transferred file \(uploadProperties.fileName!)")
        uploadsProvider.updateRecord(with: uploadProperties, completionHandler: { _ in
            // Upload ready for transfer
            self.uploadManager?.setIsUploading(status: false)
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

        // Create upload session
        NetworkHandler.createUploadSessionManager() // 60s timeout, 2 connections max

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
                            Model.sharedInstance().imageUploadManager.invalidateSessionCancelingTasks(true, resetSession: true)
                        },
                       onFailure: { task, error in
                            // Close upload session
                            Model.sharedInstance().imageUploadManager.invalidateSessionCancelingTasks(true, resetSession: true)
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

        parameters[kPiwigoImagesUploadParamChunk] = "\(NSNumber(value: count))"
        parameters[kPiwigoImagesUploadParamChunks] = "\(NSNumber(value: chunks))"

        let nextChunkNumber = count + 1
        offset += thisChunkSize

        NetworkHandler.postMultiPart(kPiwigoImagesUpload, data: chunk, parameters: parameters,
           progress: { progress in
                DispatchQueue.main.async(execute: {
                    if progress != nil {
                        onProgress(progress, count + 1, chunks)
                    }
                })
            },
           success: { task, responseObject in
                // Continue?
                if count >= chunks - 1 {
                    // Done, return
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
    func imageInBackgroundForRequest(_ upload: UploadProperties) {
        print("    > imageInBackgroundForRequest...")
        
        // Prepare creation date
//        var creationDate = ""
//        if let date = upload.creationDate {
//            let dateFormat = DateFormatter()
//            dateFormat.dateFormat = "yyyy-MM-dd HH:mm:ss"
//            creationDate = dateFormat.string(from: date)
//        }

        // Prepare parameters for uploading image/video
        let imageParameters: [String : String] = [
            kPiwigoImagesUploadParamFileName: upload.fileName ?? "Image.jpg",
//            kPiwigoImagesUploadParamCreationDate: creationDate,
//            kPiwigoImagesUploadParamTitle: upload.imageTitle ?? "",
            kPiwigoImagesUploadParamCategory: "\(NSNumber(value: upload.category))",
            kPiwigoImagesUploadParamPrivacy: "\(NSNumber(value: upload.privacyLevel!.rawValue))",
//            kPiwigoImagesUploadParamAuthor: upload.author ?? "",
//            kPiwigoImagesUploadParamDescription: upload.comment ?? "",
//            kPiwigoImagesUploadParamTags: upload.tagIds ?? Set<String>(),
            kPiwigoImagesUploadParamMimeType: upload.mimeType ?? ""
        ]

        // Get URL of file to upload
        let fileName = upload.localIdentifier.replacingOccurrences(of: "/", with: "-") + "-" + upload.fileName!
        guard let fileURL = uploadManager?.applicationUploadsDirectory.appendingPathComponent(fileName) else {
            let error = NSError.init(domain: "Piwigo", code: 0, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
            updateUploadRequestWith(upload, error: error)
            return
        }
        
        // Prepare URL
//        let url = URL(string: NetworkHandler.getURLWithPath("format=json&method=pwg.images.addSimple&category=142", withURLParams: nil))
        let url = URL(string: NetworkHandler.getURLWithPath("method=pwg.images.addSimple&category=142", withURLParams: nil))
        guard let validUrl = url else { fatalError() }

        // JSON data
//        struct PwgImagesAddSimple: Codable {
//            let category: Int
//        }
//        let order = PwgImagesAddSimple(category: 142)
//        guard let uploadData = try? JSONEncoder().encode(order) else {
//            return
//        }

        // Prepare URL Request Object
        var urlRequest = URLRequest(url: validUrl)
        urlRequest.httpMethod = "POST"
//        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(upload.fileName!, forHTTPHeaderField: "filename")
//        urlRequest.setValue(upload.fileName!, forHTTPHeaderField: "image")

//        let boundary = createBoundary()
        
        // Create upload session
//        NetworkHandler.createUploadSessionManager() // 60s timeout, 2 connections max
//        Model.sharedInstance().imageUploadManager.uploadTask(with: URLRequest(url: validUrl),
//                                                             fromFile: fileURL,
//        progress: { (progress) in
//            print("\(progress.debugDescription)")
//
//        }) { (responseData, response, error) in
//
//            if(error != nil){
//                print("\(error!.localizedDescription)")
//            }
//
//            print("\(responseData.debugDescription)")
//            print("\(response.debugDescription)")
//        }.resume()
//        return

        // Set Content-Type Header to multipart/form-data
//        urlRequest.setValue("multipart/form-data", forHTTPHeaderField: "Content-Type")
//        urlRequest.setValue("file", forHTTPHeaderField: "Content-Type")
//        urlRequest.setValue(upload.mimeType, forHTTPHeaderField: "Content-Type")

//        var mutableHeaders: [AnyHashable : Any] = [:]
//        mutableHeaders["Content-Disposition"] = "form-data; name=\"\(name)\"; filename=\"\(fileName)\""
//        mutableHeaders["Content-Type"] = mimeType

        // Create session
//        let config = URLSessionConfiguration.background(withIdentifier: "org.piwigo.backgroundSession")
//        let session = URLSession(configuration: config, delegate: (UIApplication.shared.delegate as! URLSessionDelegate), delegateQueue: nil)
        
//        let task = session.uploadTask(with: urlRequest, fromFile: fileURL)
        URLSession.shared.uploadTask(with: urlRequest, fromFile: fileURL) { (responseData, response, error) in
            
            if(error != nil){
                print("\(error!.localizedDescription)")
            }
            
            guard let responseData = responseData else {
                print("no response data")
                return
            }
            
            if let responseString = String(data: responseData, encoding: .utf8) {
                print("uploaded to: \(responseString)")
            }

        }.resume()
    }

    private func createBoundary() -> String {
        var uuid = UUID().uuidString
        uuid = uuid.replacingOccurrences(of: "-", with: "")
        uuid = uuid.map { $0.lowercased() }.joined()
     
        let boundary = String(repeating: "-", count: 20) + uuid + "\(Int(Date.timeIntervalSinceReferenceDate))"
     
        return boundary
    }
}
