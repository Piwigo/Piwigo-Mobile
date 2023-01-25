//
//  UploadTransfer.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 21/05/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import BackgroundTasks
import CoreData

extension UploadManager {
    
    // MARK: - Transfer Image in Foreground
    func transferImage(for uploadID: NSManagedObjectID,
                       with uploadProperties: UploadProperties) {
        // Get URL of file to upload
        /// This file will be deleted once the transfer is completed successfully
        let fileName = uploadProperties.localIdentifier.replacingOccurrences(of: "/", with: "-")
        let fileURL = applicationUploadsDirectory.appendingPathComponent(fileName)
        
        // Get content of file to upload
        /// https://developer.apple.com/forums/thread/115401
        var imageData: Data = Data()
        do {
            try imageData = NSData(contentsOf: fileURL, options: .alwaysMapped) as Data
//            try imageData = Data(contentsOf: fileURL, options: .alwaysMapped) as Data
        }
        catch let error as NSError {
            // Could not find the file to upload!
            debugPrint(error.localizedDescription)
            var properties = uploadProperties
            properties.requestState = .preparingFail
            properties.requestError = error.localizedDescription.replacingOccurrences(of: fileName, with: "…")
            didEndTransfer(for: uploadID, with: properties)
            return
        }

        // Calculate number of chunks
        let chunkSize = UploadVars.uploadChunkSize * 1024
        let chunksDiv: Float = Float(imageData.count) / Float(chunkSize)
        let chunks = Int(chunksDiv.rounded(.up))
        if chunks == 0, uploadProperties.fileName.isEmpty,
           uploadProperties.md5Sum.isEmpty, uploadProperties.category == 0 {
            var properties = uploadProperties
            properties.requestState = .preparingFail
            properties.requestError = UploadError.missingFile.localizedDescription
            didEndTransfer(for: uploadID, with: properties)
        }

        // Prepare first chunk
        send(chunk: 0, of: chunks, for: uploadID, with: uploadProperties)
    }

    func send(chunk:Int, of chunks:Int,
              for uploadID: NSManagedObjectID, with uploadProperties:UploadProperties) {
        // Get URL of file to upload
        /// This file will be deleted once the transfer is completed successfully
        let fileName = uploadProperties.localIdentifier.replacingOccurrences(of: "/", with: "-")
        let fileURL = applicationUploadsDirectory.appendingPathComponent(fileName)
        
        // Get content of file to upload
        /// https://developer.apple.com/forums/thread/115401
        var imageData: Data = Data()
        do {
            try imageData = NSData(contentsOf: fileURL, options: .alwaysMapped) as Data
//            try imageData = Data(contentsOf: fileURL, options: .alwaysMapped) as Data
        }
        catch let error as NSError {
            // Could not find the file to upload!
            print(error.localizedDescription)
            var properties = uploadProperties
            properties.requestState = .preparingFail
            properties.requestError = error.localizedDescription.replacingOccurrences(of: fileName, with: "…")
            didEndTransfer(for: uploadID, with: properties)
            return
        }

        // Prepare chunk
        let chunkSize = UploadVars.uploadChunkSize * 1024
        let length = imageData.count
        let offset = chunkSize * chunk
        let thisChunkSize = length - offset > chunkSize ? chunkSize : length - offset
        var chunkData = imageData.subdata(in: offset..<offset + thisChunkSize)
        print("\(debugFormatter.string(from: Date())) > #\(chunk+1) with chunkSize:", chunkSize, "thisChunkSize:", thisChunkSize, "total:", length)

        // Prepare URL
        let urlStr = "\(NetworkVars.serverProtocol)\(NetworkVars.serverPath)"
        let url = URL(string: urlStr + "/ws.php?\(pwgImagesUpload)")
        guard let validUrl = url else { fatalError() }
        
        // Initialise boundary of upload request
        let boundary = createBoundary(from: uploadProperties.md5Sum)

        // HTTP request body
        var httpBody = Data()
        httpBody.append(convertFormField(named: "chunk", value: String(chunk), using: boundary).data(using: .utf8)!)
        httpBody.append(convertFormField(named: "chunks", value: String(chunks), using: boundary).data(using: .utf8)!)
        httpBody.append(convertFormField(named: "name", value: uploadProperties.fileName, using: boundary).data(using: .utf8)!)
        httpBody.append(convertFormField(named: "category", value: "\(uploadProperties.category)", using: boundary).data(using: .utf8)!)
        httpBody.append(convertFormField(named: "level", value: "\(NSNumber(value: uploadProperties.privacyLevel.rawValue))", using: boundary).data(using: .utf8)!)
        httpBody.append(convertFormField(named: "pwg_token", value: NetworkVars.pwgToken, using: boundary).data(using: .utf8)!)

        // Chunk of data
        httpBody.append(convertFileData(fieldName: "file",
                                        fileName: uploadProperties.fileName,
                                        mimeType: uploadProperties.mimeType,
                                        fileData: chunkData,
                                        using: boundary))

        httpBody.append("--\(boundary)--".data(using: .utf8)!)

        // Prepare URL Request Object
        var request = URLRequest(url: validUrl)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue(uploadID.uriRepresentation().absoluteString, forHTTPHeaderField: UploadVars.HTTPuploadID)
        request.setValue(uploadProperties.fileName, forHTTPHeaderField: "filename")
        request.addValue(uploadProperties.localIdentifier, forHTTPHeaderField: UploadVars.HTTPimageID)
        request.addValue(String(chunk), forHTTPHeaderField: UploadVars.HTTPchunk)
        request.addValue(String(chunks), forHTTPHeaderField: UploadVars.HTTPchunks)
        request.addValue(uploadProperties.md5Sum, forHTTPHeaderField: UploadVars.HTTPmd5sum)
        request.addValue(String(imageData.count + chunks * 2170), forHTTPHeaderField: UploadVars.HTTPfileSize)

        // As soon as a task is created, the timeout counter starts
        let uploadSession: URLSession = UploadSessions.shared.frgdSession
        let task = uploadSession.uploadTask(with: request, from: httpBody)
        task.taskDescription = UploadSessions.shared.uploadSessionIdentifier

        // Tell the system how many bytes are expected to be exchanged
        task.countOfBytesClientExpectsToSend = Int64(httpBody.count + (request.allHTTPHeaderFields ?? [:]).count)
        task.countOfBytesClientExpectsToReceive = 600
        
        // Resume task
        print("\(debugFormatter.string(from: Date())) > \(uploadProperties.md5Sum) upload task \(task.taskIdentifier) resumed (\(chunk+1)/\(chunks))")
        task.resume()

        // Task now resumed -> Update upload request status
        if chunk == 0 {
            uploadProvider.updateStatusOfUpload(with: uploadID, to: .uploading, error: "") { (_) in }
        }
        
        // Release memory
        httpBody.removeAll()
        chunkData.removeAll()
    }

    func didCompleteUploadTask(_ task: URLSessionTask, withError error: Error?) {
        
        // Retrieve task parameters
        guard let objectURIstr = task.originalRequest?.value(forHTTPHeaderField: UploadVars.HTTPuploadID),
              let identifier = task.originalRequest?.value(forHTTPHeaderField: UploadVars.HTTPimageID),
              let chunkStr = task.originalRequest?.value(forHTTPHeaderField: UploadVars.HTTPchunk), let chunk = Int(chunkStr),
              let chunksStr = task.originalRequest?.value(forHTTPHeaderField: UploadVars.HTTPchunks), let chunks = Int(chunksStr),
              let md5sum = task.originalRequest?.value(forHTTPHeaderField: UploadVars.HTTPmd5sum) else {
            print("\(debugFormatter.string(from: Date())) > Could not extract HTTP header fields !!!!!!")
            return
        }

        // Handle the response here
        guard let httpResponse = task.response as? HTTPURLResponse,
            (200...299).contains(httpResponse.statusCode) else {
            
            // Retrieve upload request properties
            guard let objectURI = URL(string: objectURIstr) else {
                print("\(debugFormatter.string(from: Date())) > \(md5sum) | no object URI!")
                return
            }
            let taskContext = DataController.shared.bckgContext
            guard let uploadID = taskContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: objectURI) else {
                print("\(debugFormatter.string(from: Date())) > \(md5sum) | no objectID!")
                return
            }
            var uploadProperties: UploadProperties
            do {
                let upload = try taskContext.existingObject(with: uploadID)
                if upload.isFault {
                    // The upload request is not fired yet.
                    upload.willAccessValue(forKey: nil)
                    uploadProperties = (upload as! Upload).getProperties()
                    upload.didAccessValue(forKey: nil)
                } else {
                    uploadProperties = (upload as! Upload).getProperties()
                }
            }
            catch {
                print("\(debugFormatter.string(from: Date())) > \(md5sum) | missing Core Data object!")
                // In foreground, consider next image
                self.findNextImageToUpload()
                return
            }

            // Update upload request status
            if let error = error as NSError? {
                uploadProperties.requestState = .uploadingError
                uploadProperties.requestError = error.localizedDescription
                self.didEndTransfer(for: uploadID, with: uploadProperties, taskID: task.taskIdentifier)
            }
            else if let httpResponse = task.response as? HTTPURLResponse {
                if (400...499).contains(httpResponse.statusCode) {
                    uploadProperties.requestState = .uploadingFail
                } else {
                    uploadProperties.requestState = .uploadingError
                }
                if uploadProperties.requestError.isEmpty {
                    // The Piwigo server did not return an error message -> catch the one from the response
                    uploadProperties.requestError = HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
                }
                self.didEndTransfer(for: uploadID, with: uploadProperties, taskID: task.taskIdentifier)
            }
            else {
                uploadProperties.requestState = .uploadingError
                uploadProperties.requestError = JsonError.networkUnavailable.localizedDescription
                self.didEndTransfer(for: uploadID, with: uploadProperties, taskID: task.taskIdentifier)
            }
            return
        }
        
        // Upload completed?
        if chunk + 1 < chunks { return }

        // Delete uploaded files from Piwigo/Uploads directory
        print("\(debugFormatter.string(from: Date())) > \(md5sum) | delete left files")
        let imageFile = identifier.replacingOccurrences(of: "/", with: "-")
        deleteFilesInUploadsDirectory(withPrefix: imageFile)
    }

    func didCompleteUploadTask(_ task: URLSessionTask, withData data: Data) {
        // Retrieve task parameters
        guard let objectURIstr = task.originalRequest?.value(forHTTPHeaderField: UploadVars.HTTPuploadID),
              let chunkStr = task.originalRequest?.value(forHTTPHeaderField: UploadVars.HTTPchunk), let chunk = Int(chunkStr),
              let chunksStr = task.originalRequest?.value(forHTTPHeaderField: UploadVars.HTTPchunks), let chunks = Int(chunksStr),
              let md5sum = task.originalRequest?.value(forHTTPHeaderField: UploadVars.HTTPmd5sum) else {
            return
        }
        
        // Retrieve upload request properties
        guard let objectURI = URL(string: objectURIstr) else {
            print("\(debugFormatter.string(from: Date())) > \(md5sum) | no object URI!")
            return
        }
        let taskContext = DataController.shared.bckgContext
        guard let uploadID = taskContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: objectURI) else {
            print("\(debugFormatter.string(from: Date())) > \(md5sum) | no objectID!")
            return
        }
        var uploadProperties: UploadProperties
        do {
            let upload = try taskContext.existingObject(with: uploadID)
            if upload.isFault {
                // The upload request is not fired yet.
                upload.willAccessValue(forKey: nil)
                uploadProperties = (upload as! Upload).getProperties()
                upload.didAccessValue(forKey: nil)
            } else {
                uploadProperties = (upload as! Upload).getProperties()
            }
        }
        catch {
            // In foreground, consider next image
            print("\(debugFormatter.string(from: Date())) > \(md5sum) | missing Core Data object!")
            var properties = UploadProperties(localIdentifier: "Unknown", category: 0)
            properties.requestState = .uploadingFail
            properties.requestError = UploadError.missingAsset.localizedDescription
            self.didEndTransfer(for: uploadID, with: properties, taskID: task.taskIdentifier)
            return
        }

        // Check returned data
        if data.isEmpty {
            // Update upload request status
            #if DEBUG
            print("\(debugFormatter.string(from: Date())) > Empty JSON object!")
            #endif
            uploadProperties.requestState = .uploadingError
            uploadProperties.requestError = JsonError.emptyJSONobject.localizedDescription
            self.didEndTransfer(for: uploadID, with: uploadProperties, taskID: task.taskIdentifier)
            return
        }
        var jsonData = data
        guard jsonData.isPiwigoResponseValid(for: ImagesUploadJSON.self) else {
            // Update upload request status
            #if DEBUG
            let dataStr = String(decoding: data, as: UTF8.self)
            print("\(debugFormatter.string(from: Date())) > Invalid JSON object: \(dataStr)")
            #endif
            uploadProperties.requestState = .uploadingError
            uploadProperties.requestError = JsonError.invalidJSONobject.localizedDescription
            self.didEndTransfer(for: uploadID, with: uploadProperties, taskID: task.taskIdentifier)
            return
        }
        
        // Decode the JSON.
        do {
            // Decode the JSON into codable type ImagesUploadJSON.
            let uploadJSON = try self.decoder.decode(ImagesUploadJSON.self, from: jsonData)

            // Piwigo error?
            if (uploadJSON.errorCode != 0) {
                if (400...499).contains(uploadJSON.errorCode) {
                    uploadProperties.requestState = .uploadingFail
                } else {
                    uploadProperties.requestState = .uploadingError
                }
                uploadProperties.requestError = uploadJSON.errorMessage
                self.didEndTransfer(for: uploadID, with: uploadProperties)
                return
            }

            // Upload completed?
            if chunk + 1 < chunks {
                send(chunk: chunk + 1, of: chunks, for: uploadID, with: uploadProperties)
                return
            }

            // Add image to cache when uploaded by admin users
            if NetworkVars.hasAdminRights,
               let imageID = uploadJSON.data.image_id {
                // Create ImageGetInfo object
                let created = Date(timeIntervalSinceReferenceDate: uploadProperties.creationDate)
                let square = Derivative(url: uploadJSON.data.square_src, width: nil, height: nil)
                let thumb = Derivative(url: uploadJSON.data.src, width: nil, height: nil)
                let newImage = ImagesGetInfo(id: imageID, title: uploadProperties.imageTitle,
                                             fileName: uploadProperties.fileName,
                                             datePosted: Date(), dateCreated: created,
                                             author: uploadProperties.author,
                                             privacyLevel: String(uploadProperties.privacyLevel.rawValue),
                                             squareImage: square, thumbImage: thumb)
                // Add image to cache
                imageProvider.didUploadImage(newImage, asVideo: uploadProperties.isVideo,
                                             inCategoryId: uploadProperties.category)
            }

            // Update state of upload
            var newUploadProperties = uploadProperties
            newUploadProperties.imageId = uploadJSON.data.image_id!
            newUploadProperties.requestState = .uploaded
            newUploadProperties.requestError = ""
            self.didEndTransfer(for: uploadID, with: newUploadProperties)
            return
        } catch {
            // Data cannot be digested, image still ready for upload
            uploadProperties.requestState = .uploadingError
            uploadProperties.requestError = UploadError.wrongJSONobject.localizedDescription
            self.didEndTransfer(for: uploadID, with: uploadProperties)
            return
        }
    }

    
    // MARK: - Transfer Image in Background
    // See https://tools.ietf.org/html/rfc7578
    func transferInBackgroundImage(for uploadID: NSManagedObjectID,
                                   with uploadProperties: UploadProperties) {

        // Get URL of file to upload
        /// This file will be deleted once the transfer is completed successfully
        let fileName = uploadProperties.localIdentifier.replacingOccurrences(of: "/", with: "-")
        let fileURL = applicationUploadsDirectory.appendingPathComponent(fileName)
        
        // Get content of file to upload
        /// https://developer.apple.com/forums/thread/115401
        var imageData = Data()
        do {
            try imageData = Data(contentsOf: fileURL, options: .alwaysMapped)
//            try imageData = NSData(contentsOf: fileURL, options: .alwaysMapped) as Data
        }
        catch let error as NSError {
            // Could not find the file to upload!
            print(error.localizedDescription)
            var properties = uploadProperties
            properties.requestState = .preparingFail
            properties.requestError = error.localizedDescription.replacingOccurrences(of: fileName, with: "…")
            didEndTransfer(for: uploadID, with: properties)
            return
        }

        // Calculate number of chunks
        let chunkSize = UploadVars.uploadChunkSize * 1024
        let chunksDiv : Float = Float(imageData.count) / Float(chunkSize)
        let chunks = Int(chunksDiv.rounded(.up))
        let chunksStr = String(format: "%ld", chunks)
        if chunks == 0, uploadProperties.fileName.isEmpty,
           uploadProperties.md5Sum.isEmpty, uploadProperties.category == 0 {
            var properties = uploadProperties
            properties.requestState = .preparingFail
            properties.requestError = UploadError.missingFile.localizedDescription
            didEndTransfer(for: uploadID, with: properties)
        }
        
        // For producing filename suffixes
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .none
        numberFormatter.minimumIntegerDigits = 5

        // Prepare URL
        let urlStr = "\(NetworkVars.serverProtocol)\(NetworkVars.serverPath)"
        let url = URL(string: urlStr + "/ws.php?\(pwgImagesUploadAsync)")
        guard let validUrl = url else { fatalError() }
        
        // Prepare creation date
        let dateFormat = DateFormatter()
        dateFormat.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let date = Date(timeIntervalSinceReferenceDate: uploadProperties.creationDate)
        let creationDate = dateFormat.string(from: date)

        // Initialise credentials, boundary and upload session
        let uploadSession: URLSession = UploadSessions.shared.bckgSession
        let username = NetworkVars.username
        let password = KeychainUtilities.password(forService: uploadProperties.serverPath, account: username) 
        let boundary = createBoundary(from: uploadProperties.md5Sum)

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
                httpBody.append(convertFormField(named: "original_sum", value: uploadProperties.md5Sum, using: boundary).data(using: .utf8)!)
                httpBody.append(convertFormField(named: "category", value: "\(uploadProperties.category)", using: boundary).data(using: .utf8)!)
                httpBody.append(convertFormField(named: "filename", value: uploadProperties.fileName, using: boundary).data(using: .utf8)!)
                let imageTitle = NetworkUtilities.utf8mb3String(from: uploadProperties.imageTitle)
                httpBody.append(convertFormField(named: "name", value: imageTitle, using: boundary).data(using: .utf8)!)
                let author = NetworkUtilities.utf8mb3String(from: uploadProperties.author)
                httpBody.append(convertFormField(named: "author", value: author, using: boundary).data(using: .utf8)!)
                let comment = NetworkUtilities.utf8mb3String(from: uploadProperties.comment)
                httpBody.append(convertFormField(named: "comment", value: comment, using: boundary).data(using: .utf8)!)
                httpBody.append(convertFormField(named: "date_creation", value: creationDate, using: boundary).data(using: .utf8)!)
                httpBody.append(convertFormField(named: "level", value: "\(NSNumber(value: uploadProperties.privacyLevel.rawValue))", using: boundary).data(using: .utf8)!)
                httpBody.append(convertFormField(named: "tag_ids", value: uploadProperties.tagIds, using: boundary).data(using: .utf8)!)

                // Chunk of data
                let chunkOfData = imageData.subdata(in: chunk * chunkSize..<min((chunk+1)*chunkSize, imageData.count))
                let md5Checksum = chunkOfData.MD5checksum()
                httpBody.append(convertFormField(named: "chunk_sum", value: md5Checksum, using: boundary).data(using: .utf8)!)
                httpBody.append(self.convertFileData(fieldName: "file",
                                                fileName: uploadProperties.fileName,
                                                mimeType: uploadProperties.mimeType,
                                                fileData: chunkOfData,
                                                using: boundary))

                httpBody.append("--\(boundary)--".data(using: .utf8)!)

                // File name of chunk data stored into Piwigo/Uploads directory
                // This file will be deleted after a successful upload of the chunk
                let chunkFileName = fileName + "." + numberFormatter.string(from: NSNumber(value: chunk))!
                let fileURL = self.applicationUploadsDirectory.appendingPathComponent(chunkFileName)
                
                // Deletes temporary image file if exists (incomplete previous attempt?)
                do { try FileManager.default.removeItem(at: fileURL) } catch { }

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
                request.setValue(uploadID.uriRepresentation().absoluteString, forHTTPHeaderField: UploadVars.HTTPuploadID)
                request.setValue(uploadProperties.fileName, forHTTPHeaderField: "filename")
                request.setValue(uploadProperties.localIdentifier, forHTTPHeaderField: UploadVars.HTTPimageID)
                request.setValue(chunkStr, forHTTPHeaderField: UploadVars.HTTPchunk)
                request.setValue(chunksStr, forHTTPHeaderField: UploadVars.HTTPchunks)
                request.setValue("1", forHTTPHeaderField: "tries")
                request.setValue(uploadProperties.md5Sum, forHTTPHeaderField: UploadVars.HTTPmd5sum)
                request.setValue(String(imageData.count + chunks * 2170), forHTTPHeaderField: UploadVars.HTTPfileSize)

                // As soon as tasks are created, the timeout counter starts
                let task = uploadSession.uploadTask(with: request, fromFile: fileURL)
                task.taskDescription = UploadSessions.shared.uploadBckgSessionIdentifier

                // Tell the system how many bytes are expected to be exchanged
                task.countOfBytesClientExpectsToSend = Int64(httpBody.count + (request.allHTTPHeaderFields ?? [:]).count)
                task.countOfBytesClientExpectsToReceive = 600
                
                // Adds bytes expected to be sent to counter
                if isExecutingBackgroundUploadTask {
                    countOfBytesToUpload += httpBody.count
                    print("\(debugFormatter.string(from: Date())) >•• countOfBytesToUpload: \(countOfBytesToUpload)")
                }
                
                // Resume task
                print("\(debugFormatter.string(from: Date())) > \(uploadProperties.md5Sum) upload task \(task.taskIdentifier) resumed (\(chunk)/\(chunks))")
                task.resume()
            }
        }

        // All tasks are now resumed -> Update upload request status
        uploadProvider.updateStatusOfUpload(with: uploadID, to: .uploading, error: "") { (_) in }
        
        // Release memory
        imageData.removeAll()
    }

    func didCompleteBckgUploadTask(_ task: URLSessionTask, withError error: Error?) {
        
        // Retrieve task parameters
        guard let objectURIstr = task.originalRequest?.value(forHTTPHeaderField: UploadVars.HTTPuploadID),
              let identifier = task.originalRequest?.value(forHTTPHeaderField: UploadVars.HTTPimageID),
              let md5sum = task.originalRequest?.value(forHTTPHeaderField: UploadVars.HTTPmd5sum),
              let chunkStr = task.originalRequest?.value(forHTTPHeaderField: UploadVars.HTTPchunk),
              let chunk = Int(chunkStr) else {
            print("\(debugFormatter.string(from: Date())) > Could not extract HTTP header fields !!!!!!")
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
                print("\(debugFormatter.string(from: Date())) > \(md5sum) | no object URI!")
                return
            }
            let taskContext = DataController.shared.bckgContext
            guard let uploadID = taskContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: objectURI) else {
                print("\(debugFormatter.string(from: Date())) > \(md5sum) | no objectID!")
                return
            }
            var uploadProperties: UploadProperties
            do {
                let upload = try taskContext.existingObject(with: uploadID)
                if upload.isFault {
                    // The upload request is not fired yet.
                    upload.willAccessValue(forKey: nil)
                    uploadProperties = (upload as! Upload).getProperties()
                    upload.didAccessValue(forKey: nil)
                } else {
                    uploadProperties = (upload as! Upload).getProperties()
                }
            }
            catch {
                print("\(debugFormatter.string(from: Date())) > \(md5sum) | missing Core Data object!")
                // Investigate next upload request?
                if self.isExecutingBackgroundUploadTask {
                    // In background task — stop here
                    var properties = UploadProperties(localIdentifier: "Unknown", category: 0)
                    properties.requestState = .uploadingError
                    properties.requestError = UploadError.missingAsset.localizedDescription
                    self.didEndTransfer(for: uploadID, with: properties, taskID: task.taskIdentifier)
                } else {
                    // In foreground, consider next image
                    self.findNextImageToUpload()
                }
                return
            }

            // Update upload request status
            if let error = error as NSError? {
                uploadProperties.requestState = .uploadingError
                uploadProperties.requestError = error.localizedDescription
                self.didEndTransfer(for: uploadID, with: uploadProperties, taskID: task.taskIdentifier)
            }
            else if let httpResponse = task.response as? HTTPURLResponse {
                if (400...499).contains(httpResponse.statusCode) {
                    uploadProperties.requestState = .uploadingFail
                } else {
                    uploadProperties.requestState = .uploadingError
                }
                if uploadProperties.requestError.isEmpty {
                    // The Piwigo server did not return an error message -> catch the one from the response
                    uploadProperties.requestError = HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
                }
                self.didEndTransfer(for: uploadID, with: uploadProperties, taskID: task.taskIdentifier)
            }
            else {
                uploadProperties.requestState = .uploadingError
                uploadProperties.requestError = JsonError.networkUnavailable.localizedDescription
                self.didEndTransfer(for: uploadID, with: uploadProperties, taskID: task.taskIdentifier)
            }
            return
        }

        // Delete chunk file uploaded successfully from Piwigo/Uploads directory
        print("\(debugFormatter.string(from: Date())) > \(md5sum) | delete chunk \(chunk)")
        let imageFile = identifier.replacingOccurrences(of: "/", with: "-")
        let chunkFileName = imageFile + "." + numberFormatter.string(from: NSNumber(value: chunk))!
        deleteFilesInUploadsDirectory(withPrefix: chunkFileName)
    }

    func didCompleteBckgUploadTask(_ task: URLSessionTask, withData data: Data) {
        // Retrieve task parameters
        guard let objectURIstr = task.originalRequest?.value(forHTTPHeaderField: UploadVars.HTTPuploadID),
              let identifier = task.originalRequest?.value(forHTTPHeaderField: UploadVars.HTTPimageID),
              let md5sum = task.originalRequest?.value(forHTTPHeaderField: UploadVars.HTTPmd5sum) else {
            return
        }
        
        // Retrieve upload request properties
        guard let objectURI = URL(string: objectURIstr) else {
            print("\(debugFormatter.string(from: Date())) > \(md5sum) | no object URI!")
            return
        }
        let taskContext = DataController.shared.bckgContext
        guard let uploadID = taskContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: objectURI) else {
            print("\(debugFormatter.string(from: Date())) > \(md5sum) | no objectID!")
            return
        }
        var uploadProperties: UploadProperties
        do {
            let upload = try taskContext.existingObject(with: uploadID)
            if upload.isFault {
                // The upload request is not fired yet.
                upload.willAccessValue(forKey: nil)
                uploadProperties = (upload as! Upload).getProperties()
                upload.didAccessValue(forKey: nil)
            } else {
                uploadProperties = (upload as! Upload).getProperties()
            }
        }
        catch {
            print("\(debugFormatter.string(from: Date())) > \(md5sum) | missing Core Data object!")
            var properties = UploadProperties(localIdentifier: "Unknown", category: 0)
            properties.requestState = .uploadingFail
            properties.requestError = UploadError.missingAsset.localizedDescription
            self.didEndTransfer(for: uploadID, with: properties, taskID: task.taskIdentifier)
            return
        }

        // Check returned data
        if data.isEmpty {
            // Update upload request status
            #if DEBUG
            print("\(debugFormatter.string(from: Date())) > Empty JSON object!")
            #endif
            uploadProperties.requestState = .uploadingError
            uploadProperties.requestError = JsonError.emptyJSONobject.localizedDescription
            self.didEndTransfer(for: uploadID, with: uploadProperties, taskID: task.taskIdentifier)
            return
        }
        var jsonData = data
        guard jsonData.isPiwigoResponseValid(for: ImagesUploadAsyncJSON.self) else {
            // Update upload request status
            #if DEBUG
            let dataStr = String(decoding: data, as: UTF8.self)
            print("\(debugFormatter.string(from: Date())) > Invalid JSON object: \(dataStr)")
            #endif
            uploadProperties.requestState = .uploadingError
            uploadProperties.requestError = JsonError.invalidJSONobject.localizedDescription
            self.didEndTransfer(for: uploadID, with: uploadProperties, taskID: task.taskIdentifier)
            return
        }

        // Decode the JSON.
        do {
            // Decode the JSON into codable type ImagesUploadAsyncJSON.
            let uploadJSON = try self.decoder.decode(ImagesUploadAsyncJSON.self, from: jsonData)

            // Piwigo error?
            if (uploadJSON.errorCode != 0) {
                print("\(debugFormatter.string(from: Date())) > \(md5sum) | Piwigo error \(uploadJSON.errorCode)")
                if (400...499).contains(uploadJSON.errorCode) {
                    uploadProperties.requestState = .uploadingFail
                } else {
                    uploadProperties.requestState = .uploadingError
                }
                uploadProperties.requestError = uploadJSON.errorMessage
                self.didEndTransfer(for: uploadID, with: uploadProperties, taskID: task.taskIdentifier)
               return
            }
            
            // Upload completed?
            if let chunks = uploadJSON.chunks, let message = chunks.message {
                // Upload not completed
                let chunkList = message.dropFirst(18).components(separatedBy: ",")
                debugPrint("\(debugFormatter.string(from: Date())) > \(md5sum) | \(chunkList.count) chunks downloaded")
                // Cancel tasks of chunks already uploaded
//                UploadSessions.shared.cancelTasksOfUpload(witID: objectURIstr,
//                                                          alreadyUploadedChunks: chunkList,
//                                                          exceptedTaskID: task.taskIdentifier)
                return
            }
            
            // Upload completed
            // Cancel other tasks related with this request if any
            UploadSessions.shared.cancelTasksOfUpload(withID: objectURIstr,
                                                      exceptedTaskID: task.taskIdentifier)

            // Clear byte counter of progress bars
            UploadSessions.shared.removeCounter(withID: identifier)

            // Collect image data
            if var getInfos = uploadJSON.data, let imageId = getInfos.id,
               imageId != Int64.zero {

                // Update UI (fill progress bar)
                if !isExecutingBackgroundUploadTask {
                    updateCell(with: identifier,
                               stateLabel: kPiwigoUploadState.uploading.stateInfo,
                               photoMaxSize: nil, progress: Float(1), errorMsg: nil)
                }

                // Get data returned by the server
                uploadProperties.imageId    = imageId
                uploadProperties.imageTitle = NetworkUtilities.utf8mb4String(from: getInfos.title ?? "")
                uploadProperties.author     = NetworkUtilities.utf8mb4String(from: getInfos.author ?? "")
                if let privacyLevelStr = getInfos.privacyLevel {
                    let privacyLevelRaw = Int16(privacyLevelStr) ?? pwgPrivacy.unknown.rawValue
                    uploadProperties.privacyLevel = pwgPrivacy(rawValue: privacyLevelRaw) ?? pwgPrivacy.unknown
                }
                uploadProperties.comment    = NetworkUtilities.utf8mb4String(from: getInfos.comment ?? "")
                if let tags = getInfos.tags {
                    uploadProperties.tagIds = String(tags.compactMap({$0.id}).map({"\($0),"})
                                                        .reduce("", +).dropLast())
                }
                
                // Add uploaded image to cache and update UI if needed
                if NetworkVars.hasAdminRights {
                    getInfos.fixingUnknowns()
                    imageProvider.didUploadImage(getInfos, asVideo: uploadProperties.isVideo,
                                                 inCategoryId: uploadProperties.category)
                }
            }

            // Delete uploaded file
            let imageFile = identifier.replacingOccurrences(of: "/", with: "-")
            deleteFilesInUploadsDirectory(withPrefix: imageFile)

            // Update state of upload
            /// Since version 12, one must empty the lounge.
            var newUploadProperties = uploadProperties
            if "12.0.0".compare(NetworkVars.pwgVersion, options: .numeric) != .orderedDescending {
                // Uploading with pwg.images.uploadAsync since version 12
                newUploadProperties.requestState = .uploaded
            } else {
                // Uploading with pwg.images.uploadAsync before version 12
                newUploadProperties.requestState = .finished
            }
            newUploadProperties.requestError = ""
            self.didEndTransfer(for: uploadID, with: newUploadProperties)
            return
        } catch {
            // JSON object cannot be digested, image still ready for upload
            print("\(debugFormatter.string(from: Date())) > \(md5sum) | wrong JSON object!")
            uploadProperties.requestState = .uploadingError
            uploadProperties.requestError = UploadError.wrongJSONobject.localizedDescription
            self.didEndTransfer(for: uploadID, with: uploadProperties, taskID: task.taskIdentifier)
            return
        }
    }

    
    // MARK: - Transfer Failed/Completed
    private func didEndTransfer(for uploadID: NSManagedObjectID,
                                with properties: UploadProperties, taskID: Int = Int.max) {
        print("\(debugFormatter.string(from: Date())) > didEndTransfer in", queueName())
        
        // Error?
        if properties.requestError.isEmpty == false {
            print("\(debugFormatter.string(from: Date())) > task \(taskID) returned \(properties.requestError)")
            // Cancel related tasks
            if taskID != Int.max {
                let objectURIstr = uploadID.uriRepresentation().absoluteString
                UploadSessions.shared.cancelTasksOfUpload(withID: objectURIstr,
                                                          exceptedTaskID: taskID
                )
            }

            // Update state of upload request
            uploadProvider.updateStatusOfUpload(with: uploadID, to: properties.requestState,
                                                error: properties.requestError) { [unowned self] (_) in
                // Update UI
                let uploadInfo: [String : Any] = ["localIdentifier" : properties.localIdentifier,
                                                  "stateLabel" : properties.requestState.stateInfo,
                                                  "progressFraction" : Float(0.0),
                                                  "Error" : properties.requestError]
                DispatchQueue.main.async {
                    // Update UploadQueue cell and button shown in root album (or default album)
                    NotificationCenter.default.post(name: .pwgUploadProgress, object: nil, userInfo: uploadInfo)
                }

                // Consider next image?
                self.didEndTransfer(for: uploadID)
            }
            return
        }

        // Update state of upload request
        print("\(debugFormatter.string(from: Date())) > transferred \(uploadID.uriRepresentation())")
        uploadProvider.updatePropertiesOfUpload(with: uploadID, properties: properties) { [unowned self] (_) in
            // Get uploads to complete in queue
            // Considers only uploads to the server to which the user is logged in
            let states: [kPiwigoUploadState] = [.waiting, .preparing, .preparingError,
                                                .preparingFail, .formatError, .prepared,
                                                .uploading, .uploadingError, .uploadingFail, .uploaded,
                                                .finishing, .finishingError]
            // Update app badge and Upload button in root/default album
            self.nberOfUploadsToComplete = self.uploadProvider.getRequests(inStates: states).0.count

            // Consider next image?
            self.didEndTransfer(for: uploadID)
        }
    }

    
    // MARK: - Utilities
    func createBoundary(from identifier: String) -> String {
        /// We don't use the UUID to be able to test uploads with a simulator.
        let suffix = identifier.replacingOccurrences(of: "/", with: "").map { $0.lowercased() }.joined()
        let boundary = String(repeating: "-", count: 68 - suffix.count) + suffix
//        print("\(debugFormatter.string(from: Date())) > \(boundary)")
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
