//  Converted to Swift 5.1 by Swiftify v5.1.31847 - https://swiftify.com/
//
//  UploadService.swift
//  piwigo
//
//  Created by Spencer Baker on 1/28/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

let kUploadImage: String? = nil

class UploadService: NetworkHandler {

    class func uploadImage(_ imageData: Data?, withInformation imageInformation: [AnyHashable : Any]?, onProgress: @escaping (_ progress: Progress?, _ currentChunk: Int, _ totalChunks: Int) -> Void, onCompletion completion: @escaping (_ task: URLSessionTask?, _ response: [AnyHashable : Any]?) -> Void, onFailure fail: @escaping (_ task: URLSessionTask?, _ error: Error?) -> Void) {
        // Calculate chunk size
        let chunkSize = Model.sharedInstance().uploadChunkSize * 1024

        // Create upload session
        NetworkHandler.createUploadSessionManager() // 60s timeout, 2 connections max

        // Calculate number of chunks
        let chunks = (imageData?.count ?? 0) / chunkSize
        if (imageData?.count ?? 0) % chunkSize != 0 {
            chunks += 1
        }

        // Start sending data to server
        self.sendChunk(imageData, withInformation: &imageInformation, forOffset: 0, onChunk: 0, forTotalChunks: chunks, onProgress: onProgress, onCompletion: { task, response in
            // Close upload session
            Model.sharedInstance().imageUploadManager.invalidateSessionCancelingTasks(true)
            // Done, return
            if completion != nil {
                completion(task, response ?? [:])
            }
        }, onFailure: { task, error in
            // Close upload session
            Model.sharedInstance().imageUploadManager.invalidateSessionCancelingTasks(true)
            // Done, return
            if fail != nil {
                fail(task, error!)
            }
        })
    }

    class func getUploadedImageStatus(byId imageId: String?, inCategory categoryId: Int, onProgress progress: @escaping (Progress?) -> Void, onCompletion completion: @escaping (_ task: URLSessionTask?, _ response: [AnyHashable : Any]?) -> Void, onFailure fail: @escaping (_ task: URLSessionTask?, _ error: Error?) -> Void) -> URLSessionTask? {
        let request = self.post(kCommunityImagesUploadCompleted, urlParameters: nil, parameters: [
            "pwg_token": Model.sharedInstance().pwgToken,
            "image_id": imageId ?? "",
            "category_id": NSNumber(value: categoryId)
        ], progress: progress, success: completion, failure: fail)

        return request
    }

    class func sendChunk(_ imageData: Data?, withInformation imageInformation: inout [AnyHashable : Any], forOffset offset: Int, onChunk count: Int, forTotalChunks chunks: Int, onProgress: @escaping (_ progress: Progress?, _ currentChunk: Int, _ totalChunks: Int) -> Void, onCompletion completion: @escaping (_ task: URLSessionTask?, _ response: [AnyHashable : Any]?) -> Void, onFailure fail: @escaping (_ task: URLSessionTask?, _ error: Error?) -> Void) {
        var imageInformation = imageInformation
        var offset = offset
        // Calculate this chunk size
        let chunkSize = Model.sharedInstance().uploadChunkSize * 1024
        let length = imageData?.count ?? 0
        let thisChunkSize = length - offset > chunkSize ? chunkSize : length - offset
        var chunk = imageData?.subdata(in: NSRange(location: offset, length: thisChunkSize))

        imageInformation[kPiwigoImagesUploadParamChunk] = "\(NSNumber(value: count))"
        imageInformation[kPiwigoImagesUploadParamChunks] = "\(NSNumber(value: chunks))"

        let nextChunkNumber = count + 1
        offset += thisChunkSize

        //    NSLog(@"=> postMultiPart…");
        //    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 5.0, false);
        self.postMultiPart(kPiwigoImagesUpload, data: chunk, parameters: imageInformation, progress: { progress in
            DispatchQueue.main.async(execute: {
                if progress != nil {
                    onProgress(progress, count + 1, chunks)
                }
            })
        }, success: { task, responseObject in
            // Continue?
            if count >= chunks - 1 {
                // Release memory
                chunk = nil
                imageInformation.removeAll()

                // Done, return
                if completion != nil {
                    completion(task, (responseObject as! [AnyHashable : Any]?)))
                }
            } else {
                // Release memory
                chunk = nil
                for k in [kPiwigoImagesUploadParamChunk, kPiwigoImagesUploadParamChunks] { imageInformation.removeValue(forKey: k) }

                // Keep going!
                self.sendChunk(imageData, withInformation: &imageInformation, forOffset: offset, onChunk: nextChunkNumber, forTotalChunks: chunks, onProgress: onProgress, onCompletion: completion, onFailure: fail)
            }

        }, failure: { task, error in
            // Release memory
            chunk = nil
            imageInformation.removeAll()
            // failed!
            if fail != nil {
                fail(task, error!)
            }
        })
    }
}
