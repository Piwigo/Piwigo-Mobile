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
        debugPrint("\(dbg()) finish transfers of \(upload.objectID.uriRepresentation())")

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
                debugPrint("\(dbg()) didEndTransfer | STOP (\(countOfBytesToUpload) transferred)")
            }
        } else if !isPreparing, isUploading.count <= maxNberOfTransfers {
            findNextImageToUpload()
        }
    }


    // MARK: - Set Image Title
    /// — Called after having uploaded with pwg.images.upload
    /// — pwg.images.upload does not allow to set the image title
    func setImageParameters(for upload: Upload) {
        debugPrint("\(dbg()) setImageParameters() in", queueName())
        
        // Prepare creation date
        let creationDate = DateUtilities.string(from: upload.creationDate)

        // Prepare parameters for setting the image/video data
        let imageTitle = PwgSession.utf8mb3String(from: upload.imageName)
        let author = PwgSession.utf8mb3String(from: upload.author)
        let comment = PwgSession.utf8mb3String(from: upload.comment)
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
                                countOfBytesClientExpectsToReceive: 1000) { [self] jsonData in
            debugPrint("\(self.dbg()) setImageParameters() in", queueName())
            // Decode the JSON object
            do {
                // Decode the JSON into codable type ImagesSetInfoJSON.
                let pwgData = try self.decoder.decode(ImagesSetInfoJSON.self, from: jsonData)

                // Piwigo error?
                if pwgData.errorCode != 0 {
                    let error = PwgSessionError.otherError(code: pwgData.errorCode, msg: pwgData.errorMessage)
                    self.didFinishTransfer(for: upload, error: error)
                    return
                }

                // Successful?
                if pwgData.success {
                    // Image successfully uploaded and set
                    self.didFinishTransfer(for: upload, error: nil)
                }
                else {
                    // Could not set image parameters, upload still ready for finish
                    self.didFinishTransfer(for: upload, error: PwgSessionError.unexpectedError)
                    return
                }
            } catch {
                // Data cannot be digested, upload still ready for finish
                self.didFinishTransfer(for: upload, error: error)
                return
            }
        } failure: { error in
            /// - Network communication errors
            /// - Returned JSON data is empty
            /// - Cannot decode data returned by Piwigo server
            self.didFinishTransfer(for: upload, error: error)
        }
    }


    // MARK: - Empty Lounge
    /**
     Since Piwigo server 12.0, uploaded images are gathered in a lounge
     and one must trigger manually their addition to the database.
     If not, they will be visible after some delay (12 minutes).
     */
    func emptyLounge(for upload: Upload) {
        debugPrint("\(dbg()) emptyLounge() in", queueName())
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
                       completionHandler: @escaping (Error?) -> Void) -> (Void) {
        // Launch request
        let JSONsession = PwgSession.shared
        let paramDict: [String : Any] = ["image_id": imageIds,
                                         "pwg_token": NetworkVars.shared.pwgToken,
                                         "category_id": "\(NSNumber(value: categoryId))"]
        JSONsession.postRequest(withMethod: pwgImagesUploadCompleted, paramDict: paramDict,
                                jsonObjectClientExpectsToReceive: ImagesUploadCompletedJSON.self,
                                countOfBytesClientExpectsToReceive: 2500) { [self] jsonData in
            debugPrint("\(self.dbg()) moderateImages() in", queueName())
            do {
                // Decode the JSON into codable type CommunityUploadCompletedJSON.
                let pwgData = try self.decoder.decode(ImagesUploadCompletedJSON.self, from: jsonData)

                // Piwigo error?
                if pwgData.errorCode != 0 {
                    // Will retry later
                    let error = PwgSessionError.otherError(code: pwgData.errorCode, msg: pwgData.errorMessage)
                    completionHandler(error)
                    return
                }

                if pwgData.success {
                    completionHandler(nil)
                } else {
                    completionHandler(UploadError.wrongJSONobject)
                }
            }
            catch {
                // Will retry later
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
            self.uploadProvider.bckgContext.saveIfNeeded()
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
        debugPrint("\(dbg()) moderateImages() in", queueName())
        let JSONsession = PwgSession.shared
        let paramDict: [String : Any] = ["image_id": imageIds,
                                         "pwg_token": NetworkVars.shared.pwgToken,
                                         "category_id": "\(NSNumber(value: categoryId))"]
        JSONsession.postRequest(withMethod: kCommunityImagesUploadCompleted, paramDict: paramDict,
                                jsonObjectClientExpectsToReceive: CommunityImagesUploadCompletedJSON.self,
                                countOfBytesClientExpectsToReceive: 1000) { [self] jsonData in
            debugPrint("\(self.dbg()) moderateImages() in", queueName())
            do {
                // Decode the JSON into codable type CommunityUploadCompletedJSON.
                let pwgData = try self.decoder.decode(CommunityImagesUploadCompletedJSON.self, from: jsonData)

                // Piwigo error?
                if pwgData.errorCode != 0 {
                    // Will retry later
                    let error = PwgSessionError.otherError(code: pwgData.errorCode, msg: pwgData.errorMessage)
                    debugPrint("••> moderateImages(): \(error.localizedDescription)")
                    completionHandler(false, [])
                    return
                }

                // Return validated image IDs
                var validatedIDs = [Int64]()
                pwgData.data.forEach { (pendingData) in
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
