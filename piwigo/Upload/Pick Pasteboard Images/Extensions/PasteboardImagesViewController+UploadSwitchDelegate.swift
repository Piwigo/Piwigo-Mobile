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

extension PasteboardImagesViewController: UploadSwitchDelegate
{
    // MARK: - UploadSwitchDelegate Methods
    @objc func didValidateUploadSettings(with imageParameters: [String : Any], _ uploadParameters: [String:Any]) {
        // Retrieve common image parameters and upload settings
        for index in 0..<selectedImages.count {
            guard var updatedRequest = selectedImages[index] else { continue }
                
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
                } else {
                    updatedRequest.photoMaxSize = 5 // i.e. 4K
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

            selectedImages[index] = updatedRequest
        }
        
        // Add selected images to upload queue
        UploadManager.shared.backgroundQueue.async {
            self.uploadProvider.importUploads(from: self.selectedImages.compactMap({$0})) { error in
                guard let error = error else {
                    // Restart UploadManager activities
                    UploadManager.shared.backgroundQueue.async {
                        UploadManager.shared.isPaused = false
                        UploadManager.shared.findNextImageToUpload()
                    }
                    return
                }
                DispatchQueue.main.async {
                    self.dismissPiwigoError(withTitle: NSLocalizedString("CoreDataFetch_UploadCreateFailed", comment: "Failed to create a new Upload object."), message: error.localizedDescription) { }
                }
            }
        }
    }
    
    @objc func uploadSettingsDidDisappear() {
        // Update the navigation bar
        updateNavBar()
    }
}
