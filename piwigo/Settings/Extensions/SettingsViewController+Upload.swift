//
//  SettingsViewController+Upload.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 20/08/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit
import uploadKit

// MARK: - SelectedPrivacyDelegate Methods
extension SettingsViewController: SelectPrivacyDelegate {
    func didSelectPrivacyLevel(_ privacyLevel: pwgPrivacy) {
        // Do nothing if privacy level is unchanged
        if privacyLevel == pwgPrivacy(rawValue: UploadVars.shared.defaultPrivacyLevel) { return }
        
        // Save new choice
        UploadVars.shared.defaultPrivacyLevel = privacyLevel.rawValue

        // Refresh settings
        let indexPath = IndexPath(row: 1, section: SettingsSection.imageUpload.rawValue)
        if let indexPaths = settingsTableView.indexPathsForVisibleRows, indexPaths.contains(indexPath),
           let cell = settingsTableView.cellForRow(at: indexPath) as? LabelTableViewCell {
            cell.detailLabel.text = pwgPrivacy(rawValue: UploadVars.shared.defaultPrivacyLevel)!.name
        }
    }
}


// MARK: - UploadPhotoSizeDelegate Methods
extension SettingsViewController: UploadPhotoSizeDelegate {
    func didSelectUploadPhotoSize(_ newSize: Int16) {
        // Was the size modified?
        if newSize != UploadVars.shared.photoMaxSize {
            // Save new choice
            UploadVars.shared.photoMaxSize = newSize
            
            // Refresh corresponding row
            let photoAtIndexPath = IndexPath(row: 3 + (user.hasAdminRights ? 1 : 0),
                                             section: SettingsSection.imageUpload.rawValue)
            if let indexPaths = settingsTableView.indexPathsForVisibleRows, indexPaths.contains(photoAtIndexPath),
               let cell = settingsTableView.cellForRow(at: photoAtIndexPath) as? LabelTableViewCell {
                cell.detailLabel.text = pwgPhotoMaxSizes(rawValue: UploadVars.shared.photoMaxSize)?.name ?? pwgPhotoMaxSizes(rawValue: 0)!.name
            }
        }
        
        // Hide rows if needed
        if UploadVars.shared.photoMaxSize == 0, UploadVars.shared.videoMaxSize == 0 {
            UploadVars.shared.resizeImageOnUpload = false
            // Position of the rows which should be removed
            let photoAtIndexPath = IndexPath(row: 3 + (user.hasAdminRights ? 1 : 0),
                                             section: SettingsSection.imageUpload.rawValue)
            let videoAtIndexPath = IndexPath(row: 4 + (user.hasAdminRights ? 1 : 0),
                                             section: SettingsSection.imageUpload.rawValue)
            // Remove row in existing table
            settingsTableView?.deleteRows(at: [photoAtIndexPath, videoAtIndexPath], with: .automatic)

            // Refresh flag
            let indexPath = IndexPath(row: photoAtIndexPath.row - 1,
                                      section: SettingsSection.imageUpload.rawValue)
            settingsTableView?.reloadRows(at: [indexPath], with: .automatic)
        }
    }
}


// MARK: - UploadVideoSizeDelegate Methods
extension SettingsViewController: UploadVideoSizeDelegate {
    func didSelectUploadVideoSize(_ newSize: Int16) {
        // Was the size modified?
        if newSize != UploadVars.shared.videoMaxSize {
            // Save new choice after verification
            UploadVars.shared.videoMaxSize = newSize

            // Refresh corresponding row
            let videoAtIndexPath = IndexPath(row: 4 + (user.hasAdminRights ? 1 : 0),
                                             section: SettingsSection.imageUpload.rawValue)
            if let indexPaths = settingsTableView.indexPathsForVisibleRows, indexPaths.contains(videoAtIndexPath),
               let cell = settingsTableView.cellForRow(at: videoAtIndexPath) as? LabelTableViewCell {
                cell.detailLabel.text = pwgVideoMaxSizes(rawValue: UploadVars.shared.videoMaxSize)?.name ?? pwgVideoMaxSizes(rawValue: 0)!.name
            }
            settingsTableView.reloadRows(at: [videoAtIndexPath], with: .automatic)
        }
        
        // Hide rows if needed
        if UploadVars.shared.photoMaxSize == 0, UploadVars.shared.videoMaxSize == 0 {
            UploadVars.shared.resizeImageOnUpload = false
            // Position of the rows which should be removed
            let photoAtIndexPath = IndexPath(row: 3 + (user.hasAdminRights ? 1 : 0),
                                             section: SettingsSection.imageUpload.rawValue)
            let videoAtIndexPath = IndexPath(row: 4 + (user.hasAdminRights ? 1 : 0),
                                             section: SettingsSection.imageUpload.rawValue)
            // Remove rows in existing table
            settingsTableView?.deleteRows(at: [photoAtIndexPath, videoAtIndexPath], with: .automatic)

            // Refresh flag
            let indexPath = IndexPath(row: photoAtIndexPath.row - 1,
                                      section: SettingsSection.imageUpload.rawValue)
            settingsTableView?.reloadRows(at: [indexPath], with: .automatic)
        }
    }
}
