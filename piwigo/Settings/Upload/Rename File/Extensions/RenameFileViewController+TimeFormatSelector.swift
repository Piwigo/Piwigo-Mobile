//
//  RenameFileViewController+TimeFormatSelector.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 28/05/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

// MARK: - SetTimeFormatDelegate Methods
extension RenameFileViewController: SelectTimeFormatDelegate {
    func didSelectTimeFormat(_ format: String) {
        // Look for the time format stored in default settings
        if let index = prefixActions.firstIndex(where: { $0.type == .addTime }) {
            var action = prefixActions[index]
            // Do nothing if the time format is unchanged
            if action.style == format { return }
            // Save new choice
            action.style = format
            prefixActions[index] = action
            UploadVars.shared.prefixFileNameActionList = prefixActions.encodedString
        }
        else if let index = replaceActions.firstIndex(where: { $0.type == .addTime }) {
            var action = replaceActions[index]
            // Do nothing if the time format is unchanged
            if action.style == format { return }
            // Save new choice
            action.style = format
            replaceActions[index] = action
            UploadVars.shared.replaceFileNameActionList = replaceActions.encodedString
        }
        else if let index = suffixActions.firstIndex(where: { $0.type == .addTime }) {
            var action = suffixActions[index]
            // Do nothing if the time format is unchanged
            if action.style == format { return }
            // Save new choice
            action.style = format
            suffixActions[index] = action
            UploadVars.shared.suffixFileNameActionList = suffixActions.encodedString
        }

        // Refresh settings
        exampleLabel.updateExample()
    }
}
