//
//  EditImageParamsViewController+Privacy.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 31/12/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import UIKit
import piwigoKit

// MARK: - SelectPrivacyDelegate Methods
extension EditImageParamsViewController: SelectPrivacyDelegate
{
    func didSelectPrivacyLevel(_ privacyLevel: pwgPrivacy) {
        // Check if the user decided to leave the Edit mode
        if !(navigationController?.visibleViewController is EditImageParamsViewController) {
            // Returned to image
            delegate?.didFinishEditingParameters()
            return
        }

        // Update image parameter?
        if privacyLevel.rawValue != commonPrivacyLevel {
            // Remember to update image info
            shouldUpdatePrivacyLevel = true
            commonPrivacyLevel = privacyLevel.rawValue

            // Refresh table row
            let row = EditImageParamsOrder.privacy.rawValue - (hasDatePicker == false ? 1 : 0)
            let indexPath = IndexPath(row: row, section: 0)
            editImageParamsTableView.reloadRows(at: [indexPath], with: .automatic)
        }
    }
}
