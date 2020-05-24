//
//  ImageUploadTransfer.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 21/05/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

class ImageUploadTransfer: NetworkHandler {

    class func uploadImage(_ imageData: Data?, with upload: UploadProperties, mimeType: String,
                           onProgress: @escaping (_ progress: Progress?, _ currentChunk: Int, _ totalChunks: Int) -> Void,
                           onCompletion completion: @escaping (_ task: URLSessionTask?, _ response: [AnyHashable : Any]?) -> Void,
                           onFailure fail: @escaping (_ task: URLSessionTask?, _ error: Error?) -> Void) {
        
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
//            kPiwigoImagesUploadParamTitle: upload.imageTitle() ?? "",
            kPiwigoImagesUploadParamCategory: "\(NSNumber(value: upload.category))",
            kPiwigoImagesUploadParamPrivacy: "\(NSNumber(value: upload.privacyLevel!.rawValue))",
            kPiwigoImagesUploadParamAuthor: upload.author ?? "",
            kPiwigoImagesUploadParamDescription: upload.comment ?? "",
//            kPiwigoImagesUploadParamTags: upload.tagIds,
            kPiwigoImagesUploadParamMimeType: mimeType
        ]

        // Calculate number of chunks
        var chunks = (imageData?.count ?? 0) / chunkSize
        if (imageData?.count ?? 0) % chunkSize != 0 {
            chunks += 1
        }

        // Start sending data to server
        self.sendChunk(imageData, withInformation: imageParameters,
                       forOffset: 0, onChunk: 0, forTotalChunks: chunks,
                       onProgress: onProgress,
                       onCompletion: { task, response in
                            // Close upload session
                            Model.sharedInstance().imageUploadManager.invalidateSessionCancelingTasks(true)
                            // Done, return
                            completion(task, response ?? [:])
                        },
                       onFailure: { task, error in
                            // Close upload session
                            Model.sharedInstance().imageUploadManager.invalidateSessionCancelingTasks(true)
                            // Done, return
                            fail(task, error!)
                        })
    }

    class func getUploadedImageStatus(byId imageId: String?, inCategory categoryId: Int,
                                      onProgress progress: @escaping (Progress?) -> Void,
                                      onCompletion completion: @escaping (_ task: URLSessionTask?, _ response: Any?) -> Void,
                                      onFailure fail: @escaping (_ task: URLSessionTask?, _ error: Error?) -> Void) -> URLSessionTask? {
        
        let request = self.post(kCommunityImagesUploadCompleted,
                                urlParameters: nil,
                                parameters: [
                                    "pwg_token": Model.sharedInstance().pwgToken!,
                                    "image_id": imageId ?? "",
                                    "category_id": NSNumber(value: categoryId)
                                    ],
                                progress: progress,
                                success: completion,
                                failure: fail)

        return request
    }

    class func sendChunk(_ imageData: Data?, withInformation imageParameters: [String : String],
                         forOffset offset: Int, onChunk count: Int, forTotalChunks chunks: Int,
                         onProgress: @escaping (_ progress: Progress?, _ currentChunk: Int, _ totalChunks: Int) -> Void,
                         onCompletion completion: @escaping (_ task: URLSessionTask?, _ response: [AnyHashable : Any]?) -> Void,
                         onFailure fail: @escaping (_ task: URLSessionTask?, _ error: Error?) -> Void) {
        
        var imageParameters = imageParameters
        var offset = offset
        
        // Calculate this chunk size
        let chunkSize = Model.sharedInstance().uploadChunkSize * 1024
        let length = imageData?.count ?? 0
        let thisChunkSize = length - offset > chunkSize ? chunkSize : length - offset
        let chunk = imageData?.subdata(in: offset..<offset + thisChunkSize)

        imageParameters[kPiwigoImagesUploadParamChunk] = "\(NSNumber(value: count))"
        imageParameters[kPiwigoImagesUploadParamChunks] = "\(NSNumber(value: chunks))"

        let nextChunkNumber = count + 1
        offset += thisChunkSize

        self.postMultiPart(kPiwigoImagesUpload, data: chunk, parameters: imageParameters,
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
                    completion(task, responseObject as! [AnyHashable : Any]?)
                } else {
                    // Keep going!
                    self.sendChunk(imageData, withInformation: imageParameters,
                                   forOffset: offset, onChunk: nextChunkNumber, forTotalChunks: chunks,
                                   onProgress: onProgress, onCompletion: completion, onFailure: fail)
                }
            },
           failure: { task, error in
                // failed!
                fail(task, error!)
            })
    }
}
