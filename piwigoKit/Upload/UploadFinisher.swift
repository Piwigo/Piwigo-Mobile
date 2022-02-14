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
    
    // MARK: - Finish Uploading Image
    func setImageParameters(for uploadID: NSManagedObjectID,
                            with uploadProperties: UploadProperties) {
        print("\(debugFormatter.string(from: Date())) > setImageParameters() in", queueName())
        
        // Prepare creation date
        let dateFormat = DateFormatter()
        dateFormat.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let date = Date(timeIntervalSinceReferenceDate: uploadProperties.creationDate)
        let creationDate = dateFormat.string(from: date)

        // Prepare parameters for setting the image/video data
        let imageTitle = NetworkUtilities.utf8mb3String(from: uploadProperties.imageTitle)
        let author = NetworkUtilities.utf8mb3String(from: uploadProperties.author)
        let comment = NetworkUtilities.utf8mb3String(from: uploadProperties.comment)
        let paramsDict: [String : Any] = [
            "image_id"            : "\(NSNumber(value: uploadProperties.imageId))",
            "file"                : uploadProperties.fileName,
            "name"                : imageTitle,
            "author"              : author == "NSNotFound" ? "" : author,
            "date_creation"       : creationDate,
            "level"               : "\(NSNumber(value: uploadProperties.privacyLevel.rawValue))",
            "comment"             : comment,
            "tag_ids"             : uploadProperties.tagIds,
            "single_value_mode"   : "replace",
            "multiple_value_mode" : "replace"]
        
        // Launch request
        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: kPiwigoImagesSetInfo, paramDict: paramsDict,
                                jsonObjectClientExpectsToReceive: ImagesSetInfoJSON.self,
                                countOfBytesClientExpectsToReceive: 1000) { jsonData, error in
            print("\(self.debugFormatter.string(from: Date())) > setImageParameters() in", queueName())
            // Any error?
            /// - Network communication errors
            /// - Returned JSON data is empty
            /// - Cannot decode data returned by Piwigo server
            if let error = error {
                self.didFinishTransfer(for: uploadID, error: error)
                return
            }
            
            // Decode the JSON and import it into Core Data.
            do {
                // Decode the JSON into codable type TagJSON.
                let decoder = JSONDecoder()
                let uploadJSON = try decoder.decode(ImagesSetInfoJSON.self, from: jsonData)

                // Piwigo error?
                if (uploadJSON.errorCode != 0) {
                    let error = NSError(domain: "Piwigo", code: uploadJSON.errorCode,
                                    userInfo: [NSLocalizedDescriptionKey : uploadJSON.errorMessage])
                    self.didFinishTransfer(for: uploadID, error: error)
                    return
                }

                // Successful?
                if uploadJSON.success {
                    // Image successfully uploaded and set
                    self.didFinishTransfer(for: uploadID, error: nil)
                }
                else {
                    // Could not set image parameters, upload still ready for finish
                    let error = NSError(domain: "Piwigo", code: -1, userInfo: [NSLocalizedDescriptionKey : NSLocalizedString("serverUnknownError_message", comment: "Unexpected error encountered while calling server method with provided parameters.")])
                    self.didFinishTransfer(for: uploadID, error: error)
                    return
                }
            } catch {
                // Data cannot be digested, upload still ready for finish
                let error = NSError(domain: "Piwigo", code: 0, userInfo: [NSLocalizedDescriptionKey : UploadError.wrongJSONobject.localizedDescription])
                self.didFinishTransfer(for: uploadID, error: error)
                return
            }
        }
    }

    /**
     Since Piwigo server 12.0, uploaded images are gathered in a lounge
     and one must trigger manually their addition to the database.
     If not, they will be added after some delay (12 minutes).
     */
    func emptyLounge(for uploadID: NSManagedObjectID,
                     with uploadProperties: UploadProperties) {
        print("\(debugFormatter.string(from: Date())) > emptyLounge() in", queueName())
        
        processImages(withIds: "\(uploadProperties.imageId)",
                      inCategory: uploadProperties.category) { error in
            self.didFinishTransfer(for: uploadID, error: error)
        }
    }

    func processImages(withIds imageIds: String,
                       inCategory categoryId: Int,
                       completionHandler: @escaping (NSError?) -> Void) -> (Void) {
        
        print("\(debugFormatter.string(from: Date())) > processImages() in", queueName())

        // Launch request
        let JSONsession = PwgSession.shared
        let paramDict: [String : Any] = ["image_id": imageIds,
                                         "pwg_token": NetworkVars.pwgToken,
                                         "category_id": "\(NSNumber(value: categoryId))"]
        JSONsession.postRequest(withMethod: kPiwigoImagesUploadCompleted, paramDict: paramDict,
                                jsonObjectClientExpectsToReceive: ImagesUploadCompletedJSON.self,
                                countOfBytesClientExpectsToReceive: 2500) { jsonData, error in
            print("\(self.debugFormatter.string(from: Date())) > moderateImages() in", queueName())
            // Any error?
            /// - Network communication errors
            /// - Returned JSON data is empty
            /// - Cannot decode data returned by Piwigo server
            if let error = error as NSError? {
                completionHandler(error)
                return
            }
            
            // Decode the JSON.
            do {
                // Decode the JSON into codable type CommunityUploadCompletedJSON.
                let decoder = JSONDecoder()
                let uploadJSON = try decoder.decode(ImagesUploadCompletedJSON.self, from: jsonData)

                // Piwigo error?
                if (uploadJSON.errorCode != 0) {
                    // Will retry later
                    debugPrint("••>> processUploadedImages(): Piwigo error \(uploadJSON.errorCode) - \(uploadJSON.errorMessage)")
                    let error = NSError(domain: "Piwigo", code: uploadJSON.errorCode,
                                    userInfo: [NSLocalizedDescriptionKey : uploadJSON.errorMessage])
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
                completionHandler(UploadError.wrongJSONobject as NSError)
                return
            }
        }
    }

    private func didFinishTransfer(for uploadID: NSManagedObjectID, error: Error?) {

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
            self.didFinishTransfer()
        }
    }


    // MARK: - Community Moderation
    /**
     When the Community plugin is installed (v2.9+) on the server,
     one must inform the moderator that a number of images were uploaded.
     */
    func moderateImages(withIds imageIds: String,
                        inCategory categoryId: Int,
                        completionHandler: @escaping (Bool, [String]) -> Void) -> (Void) {
        
        print("\(debugFormatter.string(from: Date())) > moderateImages() in", queueName())
        // Check that we have a token
        guard NetworkVars.pwgToken.isEmpty == false else {
            // We shall retry later —> Continue in background queue!
            self.backgroundQueue.async {
                // Will retry later
                completionHandler(false, [])
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
                                jsonObjectClientExpectsToReceive: CommunityImagesUploadCompletedJSON.self,
                                countOfBytesClientExpectsToReceive: 1000) { jsonData, error in
            print("\(self.debugFormatter.string(from: Date())) > moderateImages() in", queueName())
            // Any error?
            /// - Network communication errors
            /// - Returned JSON data is empty
            /// - Cannot decode data returned by Piwigo server
            if let _ = error {
                completionHandler(false, [])
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
                    debugPrint("••>> moderateUploadedImages(): Piwigo error \(uploadJSON.errorCode) - \(uploadJSON.errorMessage)")
                    completionHandler(false, [])
                    return
                }

                // Return pending images
                var pendingIds = [String]()
                uploadJSON.data.forEach { (pendingData) in
                    if let imageId = pendingData.id {
                        pendingIds.append(imageId)
                    }
                }
                completionHandler(true, pendingIds)
            }
            catch {
                // Will retry later
                completionHandler(false, [])
                return
            }
        }
    }
}
