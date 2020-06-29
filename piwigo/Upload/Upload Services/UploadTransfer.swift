//
//  UploadTransfer.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 21/05/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

class UploadTransfer {

    // MARK: - Piwigo API method

    let kPiwigoImagesUpload = "format=json&method=pwg.images.upload"

    
    // MARK: - Upload Images
    /**
     Initialises the transfer of an image or a video with a Piwigo server.
     The file is uploaded by sending chunks whose size is defined on the server.
     */
    func startUpload(with upload: UploadProperties,
                     onProgress: @escaping (_ progress: Progress?, _ currentChunk: Int, _ totalChunks: Int) -> Void,
                     onCompletion completion: @escaping (_ task: URLSessionTask?, _ response: Any?, _ imageParameters: [String : String]) -> Void,
                     onFailure fail: @escaping (_ task: URLSessionTask?, _ error: NSError?) -> Void) {
        
        // Calculate chunk size
        let chunkSize = Model.sharedInstance().uploadChunkSize * 1024

        // Create upload session
        NetworkHandler.createUploadSessionManager() // 60s timeout, 2 connections max

        // Prepare creation date
        var creationDate = ""
        if let date = upload.creationDate {
            let dateFormat = DateFormatter()
            dateFormat.dateFormat = "yyyy-MM-dd HH:mm:ss"
            creationDate = dateFormat.string(from: date)
        }

        // Prepare parameters for uploading image/video (filename key is kPiwigoImagesUploadParamFileName)
        let imageParameters: [String : String] = [
            kPiwigoImagesUploadParamFileName: upload.fileName ?? "Image.jpg",
            kPiwigoImagesUploadParamCreationDate: creationDate,
            kPiwigoImagesUploadParamTitle: upload.imageTitle ?? "",
            kPiwigoImagesUploadParamCategory: "\(NSNumber(value: upload.category))",
            kPiwigoImagesUploadParamPrivacy: "\(NSNumber(value: upload.privacyLevel!.rawValue))",
            kPiwigoImagesUploadParamAuthor: upload.author ?? "",
            kPiwigoImagesUploadParamDescription: upload.comment ?? "",
//            kPiwigoImagesUploadParamTags: upload.tagIds,
            kPiwigoImagesUploadParamMimeType: upload.mimeType ?? ""
        ]

        // Get file to upload
        let fileName = upload.localIdentifier.replacingOccurrences(of: "/", with: "-") + "-" + upload.fileName!
        let fileURL = UploadManager.applicationUploadsDirectory.appendingPathComponent(fileName)
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
                                completion(task, response, updatedParameters)
                                return
                            }
                            // Done, return
                            completion(task, response, updatedParameters)
                            // Close upload session
                            Model.sharedInstance().imageUploadManager.invalidateSessionCancelingTasks(true)
                        },
                       onFailure: { task, error in
                            // Close upload session
                            Model.sharedInstance().imageUploadManager.invalidateSessionCancelingTasks(true)
                            // Done, return
                        fail(task, error as NSError?)
                        })
    }

    /**
     Sends iteratively chunks of the file.
     */
    func sendChunk(_ imageData: Data?, withInformation imageParameters: [String:String],
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
}
