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
                     onCompletion completion: @escaping (_ task: URLSessionTask?, _ response: [AnyHashable : Any]?, _ imageParameters: [String : String]) -> Void,
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
                       onCompletion: { task, response, imageParameters in
                            // Delete uploaded file from Piwigo/Uploads directory
                            do {
                                try FileManager.default.removeItem(at: fileURL)
                            } catch {
                                // define error !!!!
                                completion(task, response, imageParameters)
                                return
                            }
                            // Close upload session
                            Model.sharedInstance().imageUploadManager.invalidateSessionCancelingTasks(true)
                            // Done, return
                            completion(task, response, imageParameters)
                        },
                       onFailure: { task, error in
                            // Close upload session
                            Model.sharedInstance().imageUploadManager.invalidateSessionCancelingTasks(true)
                            // Done, return
                            fail(task, error!)
                        })
    }

    /**
     Sends iteratively chunks of the file.
     */
    func sendChunk(_ imageData: Data?, withInformation imageParameters: [String : String],
                         forOffset offset: Int, onChunk count: Int, forTotalChunks chunks: Int,
                         onProgress: @escaping (_ progress: Progress?, _ currentChunk: Int, _ totalChunks: Int) -> Void,
                         onCompletion completion: @escaping (_ task: URLSessionTask?, _ response: [AnyHashable : Any]?, _ imageParameters: [String : String]) -> Void,
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

        NetworkHandler.postMultiPart(kPiwigoImagesUpload, data: chunk, parameters: imageParameters,
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
                    completion(task, responseObject as! [AnyHashable : Any]?, imageParameters)
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


// MARK: - Codable, kPiwigoImagesUpload
/**
 A struct for decoding JSON with the following structure returned by kPiwigoImagesUpload:

 {"stat":"ok",
  "result":{"image_id":1052,
            "square_src":"https://...-sq.jpg",
            "name":"Delft - 04",
            "src":"https://...-th.jpg",
            "category":{"id":140,"nb_photos":"7","label":"Essai"}
            }
  }
*/
struct ImagesUploadJSON: Decodable {

    private enum RootCodingKeys: String, CodingKey {
        case stat
        case result
        case err
        case message
    }

    // Constants
    var stat: String?
    var errorCode = 0
    var errorMessage = ""
    
    // An UploadProperties array of decoded ImagesUpload data.
    var imagesUpload = ImagesUpload.init(image_id: nil, name: nil, square_src: nil, src: nil)

    init(from decoder: Decoder) throws
    {
        // Root container keyed by RootCodingKeys
        let rootContainer = try decoder.container(keyedBy: RootCodingKeys.self)
        
        // Status returned by Piwigo
        stat = try rootContainer.decodeIfPresent(String.self, forKey: .stat)
        if (stat == "ok")
        {
            // Decodes response from the data and store them in the array
            imagesUpload = try rootContainer.decode(ImagesUpload.self, forKey: .result)
//            dump(imagesUpload)
        }
        else if (stat == "fail")
        {
            // Retrieve Piwigo server error
            errorCode = try rootContainer.decode(Int.self, forKey: .err)
            errorMessage = try rootContainer.decode(String.self, forKey: .message)
        }
        else {
            // Unexpected Piwigo server error
            errorCode = -1
            errorMessage = NSLocalizedString("serverUnknownError_message", comment: "Unexpected error encountered while calling server method with provided parameters.")
        }
    }
}

/**
 A struct for decoding JSON returned by kPiwigoImagesUpload.
 All members are optional in case they are missing from the data.
*/
struct ImagesUpload: Codable
{
    let image_id: Int?              // 1042

    // The following data are not used yet
//    let category: [String]          // {"id":140,"nb_photos":"7","label":"Essai"}
    let name: String?               // "Delft - 01"
    let square_src: String?         // "https://…-sq.jpg"
    let src: String?                // "https://…-th.jpg"
}
