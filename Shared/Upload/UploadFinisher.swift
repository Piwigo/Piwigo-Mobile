//
//  UploadFinisher.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 01/06/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import CoreData
import Photos

extension UploadManager {
    
    // MARK: - Set Image Info
    func setImageParameters(for uploadID: NSManagedObjectID) {
        print("\(UploadUtilities.debugFormatter.string(from: Date())) > setImageParameters() in", queueName())
        // Retrieve upload request parameters
        let taskContext = DataController.privateManagedObjectContext
        let upload = taskContext.object(with: uploadID) as! Upload
        print("\(UploadUtilities.debugFormatter.string(from: Date())) > finishing transfer of \(upload.fileName)…")

        // Prepare creation date
        let dateFormat = DateFormatter()
        dateFormat.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let date = Date(timeIntervalSinceReferenceDate: upload.creationDate)
        let creationDate = dateFormat.string(from: date)

        // Prepare parameters for uploading image/video (filename key is kPiwigoImagesUploadParamFileName)
        let imageTitle = NetworkUtilities.utf8mb3String(from: upload.imageName)
        let author = NetworkUtilities.utf8mb3String(from: upload.author)
        let comment = NetworkUtilities.utf8mb3String(from: upload.comment)
        let paramsDict: [String : Any] = ["image_id"            : "\(NSNumber(value: upload.imageId))",
                                          "file"                : upload.fileName,
                                          "name"                : imageTitle,
                                          "author"              : author == "NSNotFound" ? "" : author,
                                          "date_creation"       : creationDate,
                                          "level"               : "\(NSNumber(value: upload.privacyLevel))",
                                          "comment"             : comment,
                                          "tag_ids"             : upload.tagIds,
                                          "single_value_mode"   : "replace",
                                          "multiple_value_mode" : "replace"]
        
//        @"image_id" : @(imageId),
//        @"file" : [imageInfo objectForKey:kPiwigoImagesUploadParamFileName],
//        @"name" : [imageInfo objectForKey:kPiwigoImagesUploadParamTitle],
//        @"author" : author,
//        @"date_creation" : [imageInfo objectForKey:kPiwigoImagesUploadParamCreationDate],
//        @"level" : [imageInfo objectForKey:kPiwigoImagesUploadParamPrivacy],
//        @"comment" : [imageInfo objectForKey:kPiwigoImagesUploadParamDescription],
//        @"single_value_mode" : @"replace",
//        @"tag_ids" : [imageInfo objectForKey:kPiwigoImagesUploadParamTags],
//        @"multiple_value_mode" : @"replace"

        // Launch request
        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: kPiwigoImagesSetInfo, paramDict: paramsDict,
                                countOfBytesClientExpectsToReceive: 1000) { jsonData, error in
            print("\(UploadUtilities.debugFormatter.string(from: Date())) > setImageParameters() in", queueName())
            // Any error?
            /// - Network communication errors
            /// - Returned JSON data is empty
            /// - Cannot decode data returned by Piwigo server
            if let error = error {
                self.didSetParameters(for: uploadID, error: error)
                return
            }
            
            // Decode the JSON and import it into Core Data.
            do {
                // Decode the JSON into codable type TagJSON.
                let decoder = JSONDecoder()
                let uploadJSON = try decoder.decode(ImagesSetInfoJSON.self, from: jsonData)

                // Piwigo error?
                let error: NSError
                if (uploadJSON.errorCode != 0) {
                    error = NSError(domain: "Piwigo", code: uploadJSON.errorCode,
                                    userInfo: [NSLocalizedDescriptionKey : uploadJSON.errorMessage])
                    self.didSetParameters(for: uploadID, error: error)
                    return
                }

                // Successful?
                if uploadJSON.success {
                    // Image successfully uploaded and set
                    self.didSetParameters(for: uploadID, error: nil)
                }
                else {
                    // Could not set image parameters, upload still ready for finish
                    print("••>> setImageInfoForImageWithId(): no successful")
                    let error = NSError(domain: "Piwigo", code: -1, userInfo: [NSLocalizedDescriptionKey : NSLocalizedString("serverUnknownError_message", comment: "Unexpected error encountered while calling server method with provided parameters.")])
                    self.didSetParameters(for: uploadID, error: error)
                    return
                }
            } catch {
                // Data cannot be digested, upload still ready for finish
                let error = NSError(domain: "Piwigo", code: 0, userInfo: [NSLocalizedDescriptionKey : UploadError.wrongJSONobject.localizedDescription])
                self.didSetParameters(for: uploadID, error: error)
                return
            }
        }
//        let imageParameters: [String : String] = [
//            kPiwigoImagesUploadParamFileName: upload.fileName,
//            kPiwigoImagesUploadParamTitle: imageTitle,
//            kPiwigoImagesUploadParamAuthor: author,
//            kPiwigoImagesUploadParamCreationDate: creationDate,
//            kPiwigoImagesUploadParamPrivacy: "\(NSNumber(value: upload.privacyLevel))",
//            kPiwigoImagesUploadParamDescription: comment,
//            kPiwigoImagesUploadParamTags: upload.tagIds,
//        ]
//
//        ImageService.setImageInfoForImageWithId(Int(upload.imageId),
//                                                information: imageParameters,
//                                                sessionManager: sessionManager,
//            onProgress:nil,
//            onCompletion: { (task, jsonData) in
//                // Continue in background queue!
//                self.backgroundQueue.async {
//                    // Check returned data
//                    guard let data = try? JSONSerialization.data(withJSONObject:jsonData ?? "") else {
//                        // Upload still ready for finish
//                        let error = NSError(domain: "Piwigo", code: JsonError.invalidJSONobject.hashValue, userInfo: [NSLocalizedDescriptionKey : JsonError.invalidJSONobject.localizedDescription])
//                        self.didSetParameters(for: uploadID, error: error)
//                        return
//                    }
//
//                    // Decode the JSON.
//                    do {
//                        // Decode the JSON into codable type ImageSetInfoJSON.
//                        let uploadJSON = try self.decoder.decode(ImagesSetInfoJSON.self, from: data)
//
//                        // Piwigo error?
//                        if (uploadJSON.errorCode != 0) {
//                            let error = NSError(domain: "Piwigo", code: uploadJSON.errorCode, userInfo: [NSLocalizedDescriptionKey : uploadJSON.errorMessage])
//                            self.didSetParameters(for: uploadID, error: error)
//                            return
//                        }
//
//                        // Successful?
//                        if uploadJSON.success {
//                            // Image successfully uploaded
//                            self.didSetParameters(for: uploadID, error: nil)
//                        }
//                        else {
//                            // Could not set image parameters, upload still ready for finish
//                            print("••>> setImageInfoForImageWithId(): no successful")
//                            let error = NSError(domain: "Piwigo", code: -1, userInfo: [NSLocalizedDescriptionKey : NSLocalizedString("serverUnknownError_message", comment: "Unexpected error encountered while calling server method with provided parameters.")])
//                            self.didSetParameters(for: uploadID, error: error)
//                            return
//                        }
//                    } catch {
//                        // Data cannot be digested, upload still ready for finish
//                        let error = NSError(domain: "Piwigo", code: 0, userInfo: [NSLocalizedDescriptionKey : UploadError.wrongJSONobject.localizedDescription])
//                        self.didSetParameters(for: uploadID, error: error)
//                        return
//                    }
//                }
//            },
//            onFailure: { (task, error) in
//                // Continue in background queue!
//                self.backgroundQueue.async {
//                    if let error = error as NSError? {
//                        // Try relogin if unauthorized
//                        if let response = error.userInfo[AFNetworkingOperationFailingURLResponseErrorKey] as? HTTPURLResponse,
//                           response.statusCode == 401 {
//                            // Try relogin
//                            DispatchQueue.main.async {
//                                let appDelegate = UIApplication.shared.delegate as? AppDelegate
//                                appDelegate?.reloginAndRetry {        // Upload still ready for finish
//                                    self.backgroundQueue.async {
//                                        self.didSetParameters(for: uploadID, error: error)
//                                    }
//                                }
//                            }
//                        } else {
//                            // Upload still ready for finish
//                            self.didSetParameters(for: uploadID, error: error)
//                        }
//                    }
//                }
//            })
    }

    private func didSetParameters(for uploadID: NSManagedObjectID, error: Error?) {

        // Initialisation
        var newState: kPiwigoUploadState = .finished
        var errorMsg = ""
        
        // Error?
        if let error = error {
            newState = .finishingError
            errorMsg = error.localizedDescription
        }

        // Update state of finished upload
        print("\(UploadUtilities.debugFormatter.string(from: Date())) > finished with \(uploadID) \(errorMsg)")
        uploadsProvider.updateStatusOfUpload(with: uploadID, to: newState, error: errorMsg) { [unowned self] (_) in
            // Consider next image
            self.didSetParameters()
        }
    }


    // MARK: - Community Moderation
    /**
     When the Community plugin is installed (v2.9+) on the server,
     one must inform the moderator that a number of images were uploaded.
     */
    func moderateImages(withIds imageIds: String,
                        inCategory categoryId: Int,
                        completionHandler: @escaping (Bool) -> Void) -> (Void) {
        
        print("\(UploadUtilities.debugFormatter.string(from: Date())) > moderateImages() in", queueName())
        // Check that we have a token
        guard !NetworkVars.pwgToken.isEmpty else {
            // // We shall retry later —> Continue in background queue!
            self.backgroundQueue.async {
                // Will retry later
                completionHandler(false)
                return
            }
            return
        }
        
        // Launch request
        let JSONsession = PwgSession.shared
        let paramDict: [String : Any] = ["image_id": imageIds,
                                         "pwg_token": NetworkVars.pwgToken,
                                         "category_id": "\(NSNumber(value: categoryId))"]
        JSONsession.postRequest(withMethod: kCommunityImagesUploadCompleted, paramDict: paramDict,
                                countOfBytesClientExpectsToReceive: 1000) { jsonData, error in
            print("\(UploadUtilities.debugFormatter.string(from: Date())) > moderateImages() in", queueName())
            // Any error?
            /// - Network communication errors
            /// - Returned JSON data is empty
            /// - Cannot decode data returned by Piwigo server
            if let _ = error {
                completionHandler(false)
                return
            }
            
            // Decode the JSON.
            do {
                // Decode the JSON into codable type CommunityUploadCompletedJSON.
                let decoder = JSONDecoder()
                let uploadJSON = try decoder.decode(CommunityImagesUploadCompletedJSON.self, from: jsonData)

                // Piwigo error?
                if (uploadJSON.errorCode != 0) {
                    // Will retry later
                    print("••>> moderateUploadedImages(): Piwigo error \(uploadJSON.errorCode) - \(uploadJSON.errorMessage)")
                    completionHandler(false)
                    return
                }

                // Successful?
                if uploadJSON.success {
                    // Images successfully moderated, delete them if wanted by users
                    completionHandler(true)
                }
                else {
                    // Will retry later
                    completionHandler(false)
                    return
                }
            } catch {
                // Will retry later
                completionHandler(false)
                return
            }
        }
    }
        

//        getUploadedImageStatus(byId: imageIds, inCategory: categoryId,
//            onCompletion: { (task, jsonData) in
//                // Continue in background queue!
//                self.backgroundQueue.async {
//                    // Check returned data
//                    guard let data = try? JSONSerialization.data(withJSONObject:jsonData ?? "") else {
//                        // Will retry later
//                        return
//                    }
//                    // Decode the JSON.
//                    do {
//                        // Decode the JSON into codable type CommunityUploadCompletedJSON.
//                        let decoder = JSONDecoder()
//                        let uploadJSON = try decoder.decode(CommunityImagesUploadCompletedJSON.self, from: data)
//
//                        // Piwigo error?
//                        if (uploadJSON.errorCode != 0) {
//                            // Will retry later
//                            print("••>> moderateUploadedImages(): Piwigo error \(uploadJSON.errorCode) - \(uploadJSON.errorMessage)")
//                            completionHandler(false)
//                            return
//                        }
//
//                        // Successful?
//                        if uploadJSON.success {
//                            // Images successfully moderated, delete them if wanted by users
//                            completionHandler(true)
//                        } else {
//                            // Will retry later
//                            completionHandler(false)
//                            return
//                        }
//                    } catch {
//                        // Will retry later
//                        completionHandler(false)
//                        return
//                    }
//                }
//        }, onFailure: { (task, error) in
//            // Continue in background queue!
//            self.backgroundQueue.async {
//                // Will retry later
//                completionHandler(false)
//                return
//            }
//        })
//    }

//    private func getUploadedImageStatus(byId imageId: String?, inCategory categoryId: Int,
//            onCompletion completion: @escaping (_ task: URLSessionTask?, _ response: Any?) -> Void,
//            onFailure fail: @escaping (_ task: URLSessionTask?, _ error: Error?) -> Void) -> (Void) {
//        
//        // Check that we have a token
//        guard !NetworkVars.pwgToken.isEmpty else {
//            fail(nil, JsonError.networkUnavailable)
//            return
//        }
//        
//        // Post request
//        NetworkHandler.post(kCommunityImagesUploadCompleted,
//                urlParameters: nil,
//                parameters: [
//                    "pwg_token": NetworkVars.pwgToken,
//                    "image_id": imageId ?? "",
//                    "category_id": NSNumber(value: categoryId)
//                    ],
//                sessionManager: sessionManager,
//                progress: nil,
//                success: completion,
//                failure: fail)
//    }
}
