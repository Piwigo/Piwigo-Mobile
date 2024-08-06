//
//  PasteboardImagesViewController+UploadSwitchDelegate.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 16/03/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
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
            if let prefixFileNameBeforeUpload = uploadParameters["prefixFileNameBeforeUpload"] as? Bool {
                updatedRequest.prefixFileNameBeforeUpload = prefixFileNameBeforeUpload
            }
            if let defaultPrefix = uploadParameters["defaultPrefix"] as? String {
                updatedRequest.defaultPrefix = defaultPrefix
            }
            if let deleteImageAfterUpload = uploadParameters["deleteImageAfterUpload"] as? Bool {
                updatedRequest.deleteImageAfterUpload = deleteImageAfterUpload
            }

            uploadRequests[index] = updatedRequest
        }
        
        // Add selected images to upload queue
        UploadManager.shared.backgroundQueue.async {
            self.uploadProvider.importUploads(from: self.uploadRequests) { error in
                // Deselect cells and reset upload queue
                self.cancelSelect()
                self.uploadRequests = []
                
                // Error encountered?
                guard let error = error else {
                    // Restart UploadManager activities
                    UploadManager.shared.backgroundQueue.async {
                        UploadManager.shared.isPaused = false
                        UploadManager.shared.findNextImageToUpload()
                    }
                    return
                }
                DispatchQueue.main.async {
                    self.dismissPiwigoError(withTitle: NSLocalizedString("CoreDataFetch_UploadCreateFailed", comment: "Failed to create a new Upload object."), message: error.localizedDescription) {
                        // Restart UploadManager activities
                        UploadManager.shared.backgroundQueue.async {
                            UploadManager.shared.isPaused = false
                            UploadManager.shared.findNextImageToUpload()
                        }
                    }
                }
            }
        }
    }
    
    @objc func uploadSettingsDidDisappear() {
        // Update the navigation bar
        updateNavBar()
    }
}
