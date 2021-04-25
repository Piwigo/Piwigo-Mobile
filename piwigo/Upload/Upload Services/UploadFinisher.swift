//
//  UploadFinisher.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 01/06/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import Photos

extension UploadManager{
    
    // MARK: - Set Image Info
    func setImageParameters(for uploadID: NSManagedObjectID) {
        // Retrieve upload request parameters
        let taskContext = DataController.getPrivateContext()
        let upload = taskContext.object(with: uploadID) as! Upload
        print("\(debugFormatter.string(from: Date())) > finishing transfer of \(upload.fileName)…")

        // Prepare creation date
        let dateFormat = DateFormatter()
        dateFormat.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let date = Date(timeIntervalSinceReferenceDate: upload.creationDate)
        let creationDate = dateFormat.string(from: date)

        // Prepare parameters for uploading image/video (filename key is kPiwigoImagesUploadParamFileName)
        let imageTitle = NetworkUtilities.utf8mb3String(from: upload.imageName)
        let author = NetworkUtilities.utf8mb3String(from: upload.author)
        let comment = NetworkUtilities.utf8mb3String(from: upload.comment)
        let imageParameters: [String : String] = [
            kPiwigoImagesUploadParamFileName: upload.fileName,
            kPiwigoImagesUploadParamTitle: imageTitle ?? "",
            kPiwigoImagesUploadParamAuthor: author ?? "",
            kPiwigoImagesUploadParamCreationDate: creationDate,
            kPiwigoImagesUploadParamPrivacy: "\(NSNumber(value: upload.privacyLevel))",
            kPiwigoImagesUploadParamDescription: comment ?? "",
            kPiwigoImagesUploadParamTags: upload.tagIds,
        ]

        ImageService.setImageInfoForImageWithId(Int(upload.imageId),
                                                information: imageParameters,
                                                sessionManager: sessionManager,
            onProgress:nil,
            onCompletion: { (task, jsonData) in
                // Continue in background queue!
                DispatchQueue.global(qos: .background).async {
                    // Check returned data
                    guard let data = try? JSONSerialization.data(withJSONObject:jsonData ?? "") else {
                        // Upload still ready for finish
                        let error = NSError.init(domain: "Piwigo", code: 0, userInfo: [NSLocalizedDescriptionKey : UploadError.invalidJSONobject.localizedDescription])
                        self.didSetParameters(for: uploadID, error: error)
                        return
                    }
                    
                    // Decode the JSON.
                    do {
                        // Decode the JSON into codable type ImageSetInfoJSON.
                        let uploadJSON = try self.decoder.decode(ImagesSetInfoJSON.self, from: data)
                        
                        // Piwigo error?
                        if (uploadJSON.errorCode != 0) {
                            let error = NSError.init(domain: "Piwigo", code: uploadJSON.errorCode, userInfo: [NSLocalizedDescriptionKey : uploadJSON.errorMessage])
                            self.didSetParameters(for: uploadID, error: error)
                            return
                        }

                        // Successful?
                        if uploadJSON.success {
                            // Image successfully uploaded
                            self.didSetParameters(for: uploadID, error: nil)
                        }
                        else {
                            // Could not set image parameters, upload still ready for finish
                            print("••>> setImageInfoForImageWithId(): no successful")
                            let error = NSError.init(domain: "Piwigo", code: -1, userInfo: [NSLocalizedDescriptionKey : NSLocalizedString("serverUnknownError_message", comment: "Unexpected error encountered while calling server method with provided parameters.")])
                            self.didSetParameters(for: uploadID, error: error)
                            return
                        }
                    } catch {
                        // Data cannot be digested, upload still ready for finish
                        let error = NSError.init(domain: "Piwigo", code: 0, userInfo: [NSLocalizedDescriptionKey : UploadError.wrongJSONobject.localizedDescription])
                        self.didSetParameters(for: uploadID, error: error)
                        return
                    }
                }
            },
            onFailure: { (task, error) in
                // Continue in background queue!
                DispatchQueue.global(qos: .background).async {
                    if let error = error as NSError? {
                        // Try relogin if unauthorized
                        if let response = error.userInfo[AFNetworkingOperationFailingURLResponseErrorKey] as? HTTPURLResponse,
                           response.statusCode == 401 {
                            // Try relogin
                            let appDelegate = UIApplication.shared.delegate as? AppDelegate
                            appDelegate?.reloginAndRetry {
                                // Upload still ready for finish
                                self.didSetParameters(for: uploadID, error: error)
                            }
                        } else {
                            // Upload still ready for finish
                            self.didSetParameters(for: uploadID, error: error)
                        }
                    }
                }
            })
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
        print("\(debugFormatter.string(from: Date())) > finished with \(uploadID) \(errorMsg)")
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
        
        getUploadedImageStatus(byId: imageIds, inCategory: categoryId,
            onCompletion: { (task, jsonData) in
                // Continue in background queue!
                DispatchQueue.global(qos: .background).async {
                    // Check returned data
                    guard let data = try? JSONSerialization.data(withJSONObject:jsonData ?? "") else {
                        // Will retry later
                        return
                    }
                    // Decode the JSON.
                    do {
                        // Decode the JSON into codable type CommunityUploadCompletedJSON.
                        let decoder = JSONDecoder()
                        let uploadJSON = try decoder.decode(CommunityImagesUploadCompletedJSON.self, from: data)

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
                        } else {
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
        }, onFailure: { (task, error) in
            // Continue in background queue!
            DispatchQueue.global(qos: .background).async {
                // Will retry later
                completionHandler(false)
                return
            }
        })
    }

    private func getUploadedImageStatus(byId imageId: String?, inCategory categoryId: Int,
            onCompletion completion: @escaping (_ task: URLSessionTask?, _ response: Any?) -> Void,
            onFailure fail: @escaping (_ task: URLSessionTask?, _ error: Error?) -> Void) -> (Void) {
        
        // Check that we have a token
        guard let pwgToken = Model.sharedInstance()?.pwgToken else {
            fail(nil, UploadError.networkUnavailable)
            return
        }
        
        // Post request
        NetworkHandler.post(kCommunityImagesUploadCompleted,
                urlParameters: nil,
                parameters: [
                    "pwg_token": pwgToken,
                    "image_id": imageId ?? "",
                    "category_id": NSNumber(value: categoryId)
                    ],
                sessionManager: sessionManager,
                progress: nil,
                success: completion,
                failure: fail)
    }
}
