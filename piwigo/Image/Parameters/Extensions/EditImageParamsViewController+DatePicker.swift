//
//  EditImageParamsViewController+DatePicker.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 31/12/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit

// MARK: -  EditImageDatePickerDelegate Methods
extension EditImageParamsViewController: EditImageDatePickerDelegate
{
    func didSelectDate(withPicker date: Date) {
        // Apply new date
        shouldUpdateDateCreated = true
        commonDateCreated = date

        // Update cell
        let indexPath = IndexPath(row: EditImageParamsOrder.date.rawValue, section: 0)
        editImageParamsTableView.reloadRows(at: [indexPath], with: .automatic)
    }

    func didUnsetImageCreationDate() {
        commonDateCreated = DateUtilities.unknownDate
        shouldUpdateDateCreated = true

        // Close date picker
        var indexPath = IndexPath(row: EditImageParamsOrder.datePicker.rawValue, section: 0)
        if hasDatePicker {
            hasDatePicker = false
            editImageParamsTableView.beginUpdates()
            editImageParamsTableView.deleteRows(at: [indexPath], with: .fade)
            editImageParamsTableView.endUpdates()
        }

        // Update creation date cell
        indexPath = IndexPath(row: EditImageParamsOrder.date.rawValue, section: 0)
        editImageParamsTableView.reloadRows(at: [indexPath], with: .automatic)
    }
}
