//
//  UploadFinisher.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 01/06/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import CoreData
import Photos

extension UploadManager {
    
    // MARK: - Tasks Executed after Uploading
    func finishTransfer(of upload: Upload) {
        print("\(dbg()) finish transfers of \(upload.objectID.uriRepresentation())")

        // Update upload status
        isFinishing = true
        
        // Update state of upload resquest and finish upload
        upload.setState(.finishing, save: true)
        
        // Work depends on Piwigo server version
        if "12.0.0".compare(NetworkVars.pwgVersion, options: .numeric) != .orderedDescending {
            // Uploaded with pwg.images.uploadAsync -> Empty the lounge
            emptyLounge(for: upload)
        } else {
            // Uploaded with pwg.images.upload -> Set image title.
            setImageParameters(for: upload)
        }
    }

    func didFinishTransfer() {
        // Update counter and app badge
        self.updateNberOfUploadsToComplete()

        isFinishing = false
        if !isPreparing, isUploading.count <= maxNberOfTransfers {
            findNextImageToUpload()
        }
    }


    // MARK: - Set Image Title
    /// — Called after having uploaded with pwg.images.upload
    /// — pwg.images.upload does not allow to set the image title
    func setImageParameters(for upload: Upload) {
        print("\(dbg()) setImageParameters() in", queueName())
        
        // Prepare creation date
        let dateFormat = DateFormatter()
        dateFormat.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let date = Date(timeIntervalSinceReferenceDate: upload.creationDate)
        let creationDate = dateFormat.string(from: date)

        // Prepare parameters for setting the image/video data
        let imageTitle = NetworkUtilities.utf8mb3String(from: upload.imageName)
        let author = NetworkUtilities.utf8mb3String(from: upload.author)
        let comment = NetworkUtilities.utf8mb3String(from: upload.comment)
        let tagIDs = String((upload.tags ?? Set<Tag>()).map({"\($0.tagId),"}).reduce("", +).dropLast(1))
        let paramsDict: [String : Any] = [
            "image_id"            : "\(NSNumber(value: upload.imageId))",
            "file"                : upload.fileName,
            "name"                : imageTitle,
            "author"              : author,
            "date_creation"       : creationDate,
            "level"               : "\(NSNumber(value: upload.privacyLevel))",
            "comment"             : comment,
            "tag_ids"             : tagIDs,
            "single_value_mode"   : "replace",
            "multiple_value_mode" : "replace"]
        
        // Launch request
        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: pwgImagesSetInfo, paramDict: paramsDict,
                                jsonObjectClientExpectsToReceive: ImagesSetInfoJSON.self,
                                countOfBytesClientExpectsToReceive: 1000) { jsonData in
            print("\(self.dbg()) setImageParameters() in", queueName())
            // Decode the JSON object
            do {
                // Decode the JSON into codable type ImagesSetInfoJSON.
                let decoder = JSONDecoder()
                let uploadJSON = try decoder.decode(ImagesSetInfoJSON.self, from: jsonData)

                // Piwigo error?
                if uploadJSON.errorCode != 0 {
                    let error = PwgSession.shared.localizedError(for: uploadJSON.errorCode,
                                                                    errorMessage: uploadJSON.errorMessage)
                    self.backgroundQueue.async {
                        self.didFinishTransfer(for: upload, error: error)
                    }
                    return
                }

                // Successful?
                if uploadJSON.success {
                    // Image successfully uploaded and set
                    self.backgroundQueue.async {
                        self.didFinishTransfer(for: upload, error: nil)
                    }
                }
                else {
                    // Could not set image parameters, upload still ready for finish
                    let error = NSError(domain: "Piwigo", code: -1, userInfo: [NSLocalizedDescriptionKey : NSLocalizedString("serverUnknownError_message", comment: "Unexpected error encountered while calling server method with provided parameters.")])
                    self.backgroundQueue.async {
                        self.didFinishTransfer(for: upload, error: error)
                    }
                    return
                }
            } catch {
                // Data cannot be digested, upload still ready for finish
                let error = error as NSError
                self.backgroundQueue.async {
                    self.didFinishTransfer(for: upload, error: error)
                }
                return
            }
        } failure: { error in
            /// - Network communication errors
            /// - Returned JSON data is empty
            /// - Cannot decode data returned by Piwigo server
            self.backgroundQueue.async {
                self.didFinishTransfer(for: upload, error: error)
            }
        }
    }


    // MARK: - Empty Lounge
    /**
     Since Piwigo server 12.0, uploaded images are gathered in a lounge
     and one must trigger manually their addition to the database.
     If not, they will be visible after some delay (12 minutes).
     */
    func emptyLounge(for upload: Upload) {
        print("\(dbg()) emptyLounge() in", queueName())
        
        processImages(withIds: "\(upload.imageId)",
                      inCategory: upload.category) { [unowned self] error in
            self.backgroundQueue.async {
                self.didFinishTransfer(for: upload, error: error)
            }
        }
    }

    func processImages(withIds imageIds: String,
                       inCategory categoryId: Int32,
                       completionHandler: @escaping (Error?) -> Void) -> (Void) {
        // Launch request
        let JSONsession = PwgSession.shared
        let paramDict: [String : Any] = ["image_id": imageIds,
                                         "pwg_token": NetworkVars.pwgToken,
                                         "category_id": "\(NSNumber(value: categoryId))"]
        JSONsession.postRequest(withMethod: pwgImagesUploadCompleted, paramDict: paramDict,
                                jsonObjectClientExpectsToReceive: ImagesUploadCompletedJSON.self,
                                countOfBytesClientExpectsToReceive: 2500) { jsonData in
            print("\(self.dbg()) moderateImages() in", queueName())
            do {
                // Decode the JSON into codable type CommunityUploadCompletedJSON.
                let decoder = JSONDecoder()
                let uploadJSON = try decoder.decode(ImagesUploadCompletedJSON.self, from: jsonData)

                // Piwigo error?
                if uploadJSON.errorCode != 0 {
                    // Will retry later
                    let error = PwgSession.shared.localizedError(for: uploadJSON.errorCode,
                                                                    errorMessage: uploadJSON.errorMessage)
                    completionHandler(error)
                    return
                }

                if uploadJSON.success {
                    completionHandler(nil)
                } else {
                    completionHandler(UploadError.wrongJSONobject as NSError)
                }
            }
            catch {
                // Will retry later
                let error = error as NSError
                completionHandler(error)
                return
            }
        } failure: { error in
            /// - Network communication errors
            /// - Returned JSON data is empty
            /// - Cannot decode data returned by Piwigo server
            completionHandler(error)
        }
    }

    private func didFinishTransfer(for upload: Upload, error: Error?) {
        // Error?
        if let error = error {
            upload.setState(.finishingError, error: error, save: false)
        } else {
            upload.setState(.finished, save: false)
        }

        // Consider next image
        backgroundQueue.async {
            try? self.bckgContext.save()
            self.didFinishTransfer()
        }
    }


    // MARK: - Community Moderation
    /**
     When the Community plugin is installed (v2.9+) on the server,
     one must inform the moderator that a number of images have been uploaded.
     This informs the moderator that uploaded images are waiting for a validation.
     */
    func moderateImages(withIds imageIds: String,
                        inCategory categoryId: Int32,
                        completionHandler: @escaping (Bool, [Int64]) -> Void) -> (Void) {
        // Launch request
        print("\(dbg()) moderateImages() in", queueName())
        let JSONsession = PwgSession.shared
        let paramDict: [String : Any] = ["image_id": imageIds,
                                         "pwg_token": NetworkVars.pwgToken,
                                         "category_id": "\(NSNumber(value: categoryId))"]
        JSONsession.postRequest(withMethod: kCommunityImagesUploadCompleted, paramDict: paramDict,
                                jsonObjectClientExpectsToReceive: CommunityImagesUploadCompletedJSON.self,
                                countOfBytesClientExpectsToReceive: 1000) { jsonData in
            print("\(self.dbg()) moderateImages() in", queueName())
            do {
                // Decode the JSON into codable type CommunityUploadCompletedJSON.
                let decoder = JSONDecoder()
                let uploadJSON = try decoder.decode(CommunityImagesUploadCompletedJSON.self, from: jsonData)

                // Piwigo error?
                if uploadJSON.errorCode != 0 {
                    // Will retry later
                    print("••> moderateImages(): Piwigo error \(uploadJSON.errorCode) - \(uploadJSON.errorMessage)")
                    completionHandler(false, [])
                    return
                }

                // Return validated image IDs
                var validatedIDs = [Int64]()
                uploadJSON.data.forEach { (pendingData) in
                    if let imageIDstr = pendingData.id, let imageID = Int64(imageIDstr),
                       let pendingState = pendingData.state, pendingState == "validated" {
                        validatedIDs.append(imageID)
                    }
                }
                completionHandler(true, validatedIDs)
            }
            catch {
                // Will retry later
                completionHandler(false, [])
                return
            }
        } failure: { error in
            /// - Network communication errors
            /// - Returned JSON data is empty
            /// - Cannot decode data returned by Piwigo server
            completionHandler(false, [])
        }
    }
}
