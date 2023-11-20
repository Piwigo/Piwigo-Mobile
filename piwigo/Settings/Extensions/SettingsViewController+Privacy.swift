//
//  SettingsViewController+Privacy.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 20/08/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit

// MARK: - LockOptionsDelegate Methods
extension SettingsViewController: LockOptionsDelegate {
    func didSetAppLock(toState isLocked: Bool) {
        // Refresh corresponding row
        let appLockAtIndexPath = IndexPath(row: 0, section: SettingsSection.privacy.rawValue)
        if let indexPaths = settingsTableView.indexPathsForVisibleRows, indexPaths.contains(appLockAtIndexPath),
           let cell = settingsTableView.cellForRow(at: appLockAtIndexPath) as? LabelTableViewCell {
            if isLocked {
                cell.detailLabel.text = NSLocalizedString("settings_autoUploadEnabled", comment: "On")
            } else {
                cell.detailLabel.text = NSLocalizedString("settings_autoUploadDisabled", comment: "Off")
            }
        }
    }
}


// MARK: - ClearClipboardDelegate Methods
extension SettingsViewController: ClearClipboardDelegate {
    func didSelectClearClipboardDelay(_ delay: pwgClearClipboard) {
        // Refresh corresponding row
        let delayAtIndexPath = IndexPath(row: 1, section: SettingsSection.privacy.rawValue)
        if let indexPaths = settingsTableView.indexPathsForVisibleRows, indexPaths.contains(delayAtIndexPath),
           let cell = settingsTableView.cellForRow(at: delayAtIndexPath) as? LabelTableViewCell {
            cell.detailLabel.text = delay.delayUnit
        }
    }
}
