//
//  RenameFileViewController+CounterFormatSelector.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 30/05/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

// MARK: - SetTimeFormatDelegate Methods
extension RenameFileViewController: SelectCounterFormatDelegate {
    func didSelectCounter(startValue: Int, format: String) {
        // Update counter starting value
        self.startValue = startValue
        
        // Look for the counter format stored in settings
        if let index = prefixActions.firstIndex(where: { $0.type == .addCounter }) {
            // Do nothing if the counter format is unchanged
            var action = prefixActions[index]
            if action.style == format { return }

            // Save new choice
            action.style = format
            prefixActions[index] = action
        }
        else if let index = replaceActions.firstIndex(where: { $0.type == .addCounter }) {
            // Do nothing if the counter format is unchanged
            var action = replaceActions[index]
            if action.style == format { return }

            // Save new choice
            action.style = format
            replaceActions[index] = action
        }
        else if let index = suffixActions.firstIndex(where: { $0.type == .addCounter }) {
            // Do nothing if the counter format is unchanged
            var action = suffixActions[index]
            if action.style == format { return }

            // Save new choice
            action.style = format
            suffixActions[index] = action
        }

        // Update example shown in header
        updateExample()

        // Inform parent view
        delegate?.didChangeRenameFileSettings(prefix: prefixBeforeUpload, prefixActions: prefixActions,
                                              replace: replaceBeforeUpload, replaceActions: replaceActions,
                                              suffix: suffixBeforeUpload, suffixActions: suffixActions,
                                              changeCase: changeCaseBeforeUpload, caseOfExtension: caseOfFileExtension,
                                              startValue: startValue)
    }
}
