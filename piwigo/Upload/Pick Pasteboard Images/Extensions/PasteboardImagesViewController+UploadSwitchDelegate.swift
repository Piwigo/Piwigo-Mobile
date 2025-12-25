//
//  PasteboardImagesViewController+UploadSwitchDelegate.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 16/03/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit
import uploadKit

// MARK: - UploadSwitchDelegate Methods
extension PasteboardImagesViewController: UploadSwitchDelegate
{
    @objc func didValidateUploadSettings(with imageParameters: [String : Any], _ uploadParameters: [String:Any]) {
        // Retrieve common image parameters and upload settings
        for index in 0..<uploadRequests.count {
            // Initialisation
            var updatedRequest = uploadRequests[index]

            // Image parameters
            if let imageTitle = imageParameters["title"] as? String {
                updatedRequest.imageTitle = imageTitle
            }
            if let author = imageParameters["author"] as? String {
                updatedRequest.author = author
            }
            if let privacy = imageParameters["privacy"] as? pwgPrivacy {
                updatedRequest.privacyLevel = privacy
            }
            if let tagIds = imageParameters["tagIds"] as? String {
                updatedRequest.tagIds = tagIds
            }
            if let comment = imageParameters["comment"] as? String {
                updatedRequest.comment = comment
            }
            
            // Image file name
            if let currentCounter = uploadParameters["currentCounter"] as? Int64 {
                albumDelegate?.didSelectCurrentCounter(value: currentCounter)
            }
            if let prefixActions = uploadParameters["prefixActions"] as? RenameActionList {
                updatedRequest.fileNamePrefixEncodedActions = prefixActions.encodedString
            }
            if let replaceActions = uploadParameters["replaceActions"] as? RenameActionList {
                updatedRequest.fileNameReplaceEncodedActions = replaceActions.encodedString
            }
            if let suffixActions = uploadParameters["suffixActions"] as? RenameActionList {
                updatedRequest.fileNameSuffixEncodedActions = suffixActions.encodedString
            }
            if let caseOfFileExtension = uploadParameters["caseOfFileExtension"] as? FileExtCase {
                updatedRequest.fileNameExtensionCase = caseOfFileExtension.rawValue
            }

            // Upload settings
            if let stripGPSdataOnUpload = uploadParameters["stripGPSdataOnUpload"] as? Bool {
                updatedRequest.stripGPSdataOnUpload = stripGPSdataOnUpload
            }
            if let resizeImageOnUpload = uploadParameters["resizeImageOnUpload"] as? Bool {
                updatedRequest.resizeImageOnUpload = resizeImageOnUpload
                if resizeImageOnUpload {
                    if let photoMaxSize = uploadParameters["photoMaxSize"] as? Int16 {
                        updatedRequest.photoMaxSize = photoMaxSize
                    }
                    if let videoMaxSize = uploadParameters["videoMaxSize"] as? Int16 {
                        updatedRequest.videoMaxSize = videoMaxSize
                    }
                } else {    // No downsizing
                    updatedRequest.photoMaxSize = 0
                    updatedRequest.videoMaxSize = 0
                }
            }
            if let compressImageOnUpload = uploadParameters["compressImageOnUpload"] as? Bool {
                updatedRequest.compressImageOnUpload = compressImageOnUpload
            }
            if let photoQuality = uploadParameters["photoQuality"] as? Int16 {
                updatedRequest.photoQuality = photoQuality
            }
            if let deleteImageAfterUpload = uploadParameters["deleteImageAfterUpload"] as? Bool {
                updatedRequest.deleteImageAfterUpload = deleteImageAfterUpload
            }

            uploadRequests[index] = updatedRequest
        }
        
        // Add selected images to upload queue
        DispatchQueue.global().async {
            UploadProvider().importUploads(from: self.uploadRequests) { error in
                // Deselect cells and reset upload queue
                DispatchQueue.main.async {
                    self.cancelSelect()
                }
                self.uploadRequests = []
                
                // Error encountered?
                if let error {
                    DispatchQueue.main.async {
                        let title = PwgKitError.uploadCreationError.localizedDescription
                        self.dismissPiwigoError(withTitle: title, message: error.localizedDescription) {
                            // Restart UploadManager activities
                            self.restartUploadManager()
                        }
                    }
                } else {
                    // Restart UploadManager activities
                    self.restartUploadManager()
                }
            }
        }
    }
    
    private func restartUploadManager() {
//        if #available(iOS 26.0, *) {
//            DispatchQueue.main.async {
//                let appDelegate = UIApplication.shared.delegate as! AppDelegate
//                appDelegate.scheduleContinuedUpload()
//            }
//        } else {
            // Fallback on previous version
            Task { @UploadManagerActor in
                UploadVars.shared.isPaused = false
                UploadManager.shared.findNextImageToUpload()
            }
//        }
    }
    
    @objc func uploadSettingsDidDisappear() {
        // Update the navigation bar
        updateNavBar()
    }
}
