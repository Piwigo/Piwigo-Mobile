//
//  LocalImagesViewController+UploadSwitchDelegate.swift
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
extension LocalImagesViewController: UploadSwitchDelegate
{
    @objc func didValidateUploadSettings(with imageParameters: [String : Any], _ uploadParameters: [String:Any]) {
        // Retrieve common image parameters and upload settings
        for index in 0..<uploadRequests.count {
            autoreleasepool {
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
        }
        
        // Disable sleep mode if needed
        UIApplication.shared.isIdleTimerDisabled = (uploadRequests.isEmpty == false)
        
        // Add selected images to upload queue
        UploadManager.shared.backgroundQueue.async {
            self.uploadProvider.importUploads(from: self.uploadRequests) { error in
                // Deselect cells and reset upload queue
                DispatchQueue.main.async {
                    self.cancelSelect()
                }
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
        
        // Display help views only when uploads are launched
        if (self.uploads.fetchedObjects ?? []).isEmpty { return }
        
        // Display help views less than once a day
        let dateOfLastHelpView = AppVars.shared.dateOfLastHelpView
        let diff = Date().timeIntervalSinceReferenceDate - dateOfLastHelpView
        if diff > TimeInterval(86400) { return }
            
        // Determine which help pages should be presented
        var displayHelpPagesWithID: [UInt16] = []
        if (AppVars.shared.didWatchHelpViews & 0b00000000_00010000) == 0 {
            displayHelpPagesWithID.append(5)     // i.e. submit upload requests and let it go
        }
        if (AppVars.shared.didWatchHelpViews & 0b00000000_00001000) == 0 {
            displayHelpPagesWithID.append(4)     // i.e. remove images from camera roll
        }
        if (AppVars.shared.didWatchHelpViews & 0b00000000_00100000) == 0 {
            displayHelpPagesWithID.append(6)     // i.e. manage upload requests in queue
        }
        if #available(iOS 13, *),
           NetworkVars.shared.usesUploadAsync,
           (AppVars.shared.didWatchHelpViews & 0b00000000_00000010) == 0 {
            displayHelpPagesWithID.append(2)     // i.e. use background uploading
        }
        if #available(iOS 14, *),
           NetworkVars.shared.usesUploadAsync,
           (AppVars.shared.didWatchHelpViews & 0b00000000_01000000) == 0 {
            displayHelpPagesWithID.append(7)     // i.e. use auto-uploading
        }
        if displayHelpPagesWithID.count > 0 {
            // Present unseen upload management help views
            let helpSB = UIStoryboard(name: "HelpViewController", bundle: nil)
            let helpVC = helpSB.instantiateViewController(withIdentifier: "HelpViewController") as? HelpViewController
            if let helpVC = helpVC {
                helpVC.displayHelpPagesWithID = displayHelpPagesWithID
                if UIDevice.current.userInterfaceIdiom == .phone {
                    helpVC.popoverPresentationController?.permittedArrowDirections = .up
                    navigationController?.present(helpVC, animated:true)
                } else {
                    helpVC.modalPresentationStyle = .formSheet
                    helpVC.modalTransitionStyle = .coverVertical
                    helpVC.popoverPresentationController?.sourceView = view
                    navigationController?.present(helpVC, animated: true)
                }
            }
        }
    }
}
