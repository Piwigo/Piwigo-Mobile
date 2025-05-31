//
//  UploadSettingsViewController+UITableViewDataSource.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 31/05/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit
import uploadKit

extension UploadSettingsViewController {
    
    // MARK: - Rows
    /// Remark: a UIView is added at the bottom of the table view in the storyboard
    /// to eliminate extra separators below the cells.
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 4 + (resizeImageOnUpload ? 2 : 0)
                 + (compressImageOnUpload ? 1 : 0)
                 + (canDeleteImages ? 1 : 0)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var tableViewCell = UITableViewCell()
        var row = indexPath.row
        row += (!resizeImageOnUpload && (row > 1)) ? 2 : 0
        row += (!compressImageOnUpload && (row > 4)) ? 1 : 0
        switch row {
        case 0 /* Strip private Metadata? */:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchTableViewCell", for: indexPath) as? SwitchTableViewCell
            else { preconditionFailure("Could not load a SwitchTableViewCell!") }
            // See https://iosref.com/res
            cell.configure(with: NSLocalizedString("settings_stripGPSdata", comment: "Strip Private Metadata"))
            cell.cellSwitch.setOn(stripGPSdataOnUpload, animated: true)
            cell.cellSwitchBlock = { switchState in
                self.stripGPSdataOnUpload = switchState
            }
            cell.accessibilityIdentifier = "stripMetadataBeforeUpload"
            tableViewCell = cell
            
        case 1 /* Resize Before Upload? */:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchTableViewCell", for: indexPath) as? SwitchTableViewCell
            else { preconditionFailure("Could not load a SwitchTableViewCell!") }
            if view.bounds.size.width > 440 {
                cell.configure(with: NSLocalizedString("settings_photoResizeLong", comment: "Downsize Photo"))
            } else {
                cell.configure(with: NSLocalizedString("settings_photoResize", comment: "Downsize"))
            }
            cell.cellSwitch.setOn(resizeImageOnUpload, animated: true)
            cell.cellSwitchBlock = { switchState in
                // Number of rows will change accordingly
                self.resizeImageOnUpload = switchState
                // Position of the row that should be added/removed
                let photoAtIndexPath = IndexPath(row: 2, section: 0)
                let videoAtIndexPath = IndexPath(row: 3, section: 0)
                if switchState {
                    // Insert row in existing table
                    self.settingsTableView?.insertRows(at: [photoAtIndexPath, videoAtIndexPath], with: .automatic)
                } else {
                    // Remove row in existing table
                    self.settingsTableView?.deleteRows(at: [photoAtIndexPath, videoAtIndexPath], with: .automatic)
                }
            }
            cell.accessibilityIdentifier = "resizeBeforeUpload"
            tableViewCell = cell
            
        case 2 /* Upload Photo Max Size */:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell
            else { preconditionFailure("Could not load a LabelTableViewCell!") }
            cell.configure(with: "… " + NSLocalizedString("severalImages", comment: "Photos"),
                           detail: pwgPhotoMaxSizes(rawValue: photoMaxSize)?.name ?? pwgPhotoMaxSizes(rawValue: 0)!.name)
            cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
            cell.accessibilityIdentifier = "uploadPhotoSize"
            tableViewCell = cell

        case 3 /* Upload Max Video Size */:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell
            else { preconditionFailure("Could not load a LabelTableViewCell!") }
            cell.configure(with: "… " + NSLocalizedString("severalVideos", comment: "Videos"),
                           detail: pwgVideoMaxSizes(rawValue: videoMaxSize)?.name ?? pwgVideoMaxSizes(rawValue: 0)!.name)
            cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
            cell.accessibilityIdentifier = "defaultUploadVideoSize"
            tableViewCell = cell
            
        case 4 /* Compress before Upload? */:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchTableViewCell", for: indexPath) as? SwitchTableViewCell
            else { preconditionFailure("Could not load a SwitchTableViewCell!") }
            // See https://iosref.com/res
            if view.bounds.size.width > 440 {
                cell.configure(with: NSLocalizedString("settings_photoCompressLong", comment: "Compress Photo"))
            } else {
                cell.configure(with: NSLocalizedString("settings_photoCompress", comment: "Compress"))
            }
            cell.cellSwitch.setOn(compressImageOnUpload, animated: true)
            cell.cellSwitchBlock = { switchState in
                // Number of rows will change accordingly
                self.compressImageOnUpload = switchState
                // Position of the row that should be added/removed
                let rowAtIndexPath = IndexPath(row: 3 + (self.resizeImageOnUpload ? 2 : 0), section: 0)
                if switchState {
                    // Insert row in existing table
                    self.settingsTableView?.insertRows(at: [rowAtIndexPath], with: .automatic)
                } else {
                    // Remove row in existing table
                    self.settingsTableView?.deleteRows(at: [rowAtIndexPath], with: .automatic)
                }
            }
            cell.accessibilityIdentifier = "compressBeforeUpload"
            tableViewCell = cell
            
        case 5 /* Image Quality slider */:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "SliderTableViewCell", for: indexPath) as? SliderTableViewCell
            else { preconditionFailure("Could not load a SliderTableViewCell!") }
            // Slider value
            let value = Float(photoQuality)

            // Slider configuration
            let title = String(format: "… %@", NSLocalizedString("settings_photoQuality", comment: "Quality"))
            cell.configure(with: title, value: value, increment: 1, minValue: 50, maxValue: 98, prefix: "", suffix: "%")
            cell.cellSliderBlock = { newValue in
                // Update settings
                self.photoQuality = Int16(newValue)
            }
            cell.accessibilityIdentifier = "compressionRatio"
            tableViewCell = cell
            
        case 6 /* Rename Filename Before Upload */:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell
            else { preconditionFailure("Could not load LabelTableViewCell") }
            let title: String
            // See https://iosref.com/res
            if view.bounds.size.width > 440 {
                title = NSLocalizedString("settings_renameFileLong", comment: "Rename File")
            } else {
                title = NSLocalizedString("settings_renameFile", comment: "Rename")
            }
            let detail: String
            if isRenameFileAtive() == true {
                detail = NSLocalizedString("settings_autoUploadEnabled", comment: "On")
            } else {
                detail = NSLocalizedString("settings_autoUploadDisabled", comment: "Off")
            }
            cell.configure(with: title, detail: detail)
            cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
            cell.accessibilityIdentifier = "modifyFilename"
            tableViewCell = cell

        case 7 /* Delete image after upload? */:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchTableViewCell", for: indexPath) as? SwitchTableViewCell
            else { preconditionFailure("Could not load a SwitchTableViewCell!") }
            // See https://iosref.com/res
            if view.bounds.size.width > 430 {
                // i.e. larger than iPhones 14 Pro Max screen width
                cell.configure(with: NSLocalizedString("settings_deleteImage>375px", comment: "Delete Image After Upload"))
            } else {
                cell.configure(with: NSLocalizedString("settings_deleteImage", comment: "Delete After Upload"))
            }
            cell.cellSwitch.setOn(deleteImageAfterUpload, animated: true)
            cell.cellSwitchBlock = { switchState in
                self.deleteImageAfterUpload = switchState
            }
            cell.accessibilityIdentifier = "deleteAfterUpload"
            tableViewCell = cell
            
        default:
            break
        }
    
        tableViewCell.isAccessibilityElement = true
        return tableViewCell
    }
}
