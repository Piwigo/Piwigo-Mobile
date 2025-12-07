//
//  UploadManager+Finisher.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 01/06/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import CoreData
import Photos
import piwigoKit

extension UploadManager {
    
    // MARK: - Tasks Executed after Uploading
    func finishTransfer(of upload: Upload) {
        UploadManager.logger.notice("Finish transfers of \(upload.objectID.uriRepresentation())")

        // Update upload status
        isFinishing = true
        
        // Update state of upload resquest and finish upload
        upload.setState(.finishing, save: true)
        
        // Work depends on Piwigo server version
        if "12.0.0".compare(NetworkVars.shared.pwgVersion, options: .numeric) != .orderedDescending {
            // Uploaded with pwg.images.uploadAsync -> Empty the lounge
            emptyLounge(for: upload)
        } else {
            // Uploaded with pwg.images.upload -> Set image title.
            setImageParameters(for: upload)
        }
    }

    func didFinishTransfer() {
        // Update flag
        isFinishing = false
        
        // Foreground or background task?
        if isExecutingBackgroundUploadTask {
            // In background task, launch a transfer if possible
            if countOfBytesToUpload < maxCountOfBytesToUpload {
                let prepared = (uploads.fetchedObjects ?? []).filter({$0.state == .prepared})
                let states: [pwgUploadState] = [.preparingError, .preparingFail,
                                               .uploadingError, .uploadingFail,
                                               .finishingError]
                let failed = (uploads.fetchedObjects ?? []).filter({states.contains($0.state)})
                if isUploading.count < maxNberOfTransfers,
                   failed.count < maxNberOfFailedUploads,
                   let upload = prepared.first {
                    launchTransfer(of: upload)
                }
            } else {
                UploadManager.logger.notice("Background task stopped (\(self.countOfBytesToUpload, privacy: .public) bytes transferred)")
            }
        } else if !isPreparing, isUploading.count <= maxNberOfTransfers {
            findNextImageToUpload()
        }
    }


    // MARK: - Set Image Title
    /// — Called after having uploaded with pwg.images.upload
    /// — pwg.images.upload does not allow to set the image title
    func setImageParameters(for upload: Upload) {
        UploadManager.logger.notice("setImageParameters() in \(queueName(), privacy: .public)")
        
        // Prepare creation date
        let creationDate = DateUtilities.string(from: upload.creationDate)

        // Prepare parameters for setting the image/video data
        let tagIDs = String((upload.tags ?? Set<Tag>()).map({"\($0.tagId),"}).reduce("", +).dropLast(1))
        let paramsDict: [String : Any] = [
            "image_id"            : "\(NSNumber(value: upload.imageId))",
            "file"                : upload.fileName,
            "name"                : upload.imageName.utf8mb3Encoded,
            "author"              : upload.author.utf8mb3Encoded,
            "date_creation"       : creationDate,
            "level"               : "\(NSNumber(value: upload.privacyLevel))",
            "comment"             : upload.comment.utf8mb3Encoded,
            "tag_ids"             : tagIDs,
            "single_value_mode"   : "replace",
            "multiple_value_mode" : "replace"]
        
        // Launch request
        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: pwgImagesSetInfo, paramDict: paramsDict,
                                jsonObjectClientExpectsToReceive: ImagesSetInfoJSON.self,
                                countOfBytesClientExpectsToReceive: 1000) { [self] result in
            UploadManager.logger.notice("setImageParameters() in \(queueName(), privacy: .public) after calling postRequest")
            switch result {
            case .success(let pwgData):
                // Image successfully uploaded and set
                self.didFinishTransfer(for: upload, error: nil)
            
            case .failure(let error):
                /// - Network communication errors
                /// - Returned JSON data is empty
                /// - Cannot decode data returned by Piwigo server
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
        UploadManager.logger.notice("emptyLounge() in \(queueName(), privacy: .public)")
        // Empty lounge without reporting potential error
        guard let user = upload.user else {
            // Should never happen
            // ► The lounge will be emptied later by the server
            // ► Continue upload tasks without returning error
            self.didFinishTransfer(for: upload, error: nil)
            return
        }
        PwgSession.checkSession(ofUser: user) { [self] in
            self.processImages(withIds: "\(upload.imageId)",
                               inCategory: upload.category) { [self] _ in
                self.didFinishTransfer(for: upload, error: nil)
            }
        } failure: { [self] _ in
            // Cannot empty the lounge
            // ► The lounge will be emptied later by the app or the server
            // ► Continue upload tasks
            self.didFinishTransfer(for: upload, error: nil)
        }
    }

    func processImages(withIds imageIds: String,
                       inCategory categoryId: Int32,
                       completion: @escaping (PwgKitError?) -> Void) -> (Void) {
        // Launch request
        let JSONsession = PwgSession.shared
        let paramDict: [String : Any] = ["image_id": imageIds,
                                         "pwg_token": NetworkVars.shared.pwgToken,
                                         "category_id": "\(NSNumber(value: categoryId))"]
        JSONsession.postRequest(withMethod: pwgImagesUploadCompleted, paramDict: paramDict,
                                jsonObjectClientExpectsToReceive: ImagesUploadCompletedJSON.self,
                                countOfBytesClientExpectsToReceive: 2500) { result in
            UploadManager.logger.notice("processImages() in \(queueName(), privacy: .public) after calling postRequest")
            switch result {
            case .success(let pwgData):
                // Successful?
                if pwgData.success {
                    completion(nil)
                } else {
                    completion(.emptyingLoungeFailed)
                }
                
            case .failure(let error):
                /// - Network communication errors
                /// - Returned JSON data is empty
                /// - Cannot decode data returned by Piwigo server
                completion(error)
            }
        }
    }

    private func didFinishTransfer(for upload: Upload, error: PwgKitError?) {
        // Error?
        if let error = error {
            upload.setState(.finishingError, error: error, save: false)
        } else {
            upload.setState(.finished, save: false)
        }

        // Consider next image
        backgroundQueue.async {
            self.uploadBckgContext.saveIfNeeded()
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
        UploadManager.logger.notice("moderateImages() in \(queueName(), privacy: .public)")
        let JSONsession = PwgSession.shared
        let paramDict: [String : Any] = ["image_id": imageIds,
                                         "pwg_token": NetworkVars.shared.pwgToken,
                                         "category_id": "\(NSNumber(value: categoryId))"]
        JSONsession.postRequest(withMethod: kCommunityImagesUploadCompleted, paramDict: paramDict,
                                jsonObjectClientExpectsToReceive: CommunityImagesUploadCompletedJSON.self,
                                countOfBytesClientExpectsToReceive: 1000) { result in
            UploadManager.logger.notice("moderateImages() in \(queueName(), privacy: .public) after calling postRequest")
            switch result {
            case .success(let pwgData):
                // Return validated image IDs
                var validatedIDs = [Int64]()
                pwgData.data.forEach { (pendingData) in
                    if let imageIDstr = pendingData.id, let imageID = Int64(imageIDstr),
                       let pendingState = pendingData.state, pendingState == "validated" {
                        validatedIDs.append(imageID)
                    }
                }
                completionHandler(true, validatedIDs)

            case .failure:
                /// - Network communication errors
                /// - Returned JSON data is empty
                /// - Cannot decode data returned by Piwigo server
                completionHandler(false, [])
            }
        }
    }
}
