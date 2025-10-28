//
//  EditImageParamsViewController+ShiftTimePicker.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 18/10/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation

// MARK: -  EditImageShiftTimePickerDelegate Methods
extension EditImageParamsViewController: EditImageShiftTimeDelegate
{
    func didShiftTime(withPicker date: Date) {
        // Apply new date
        shouldUpdateDateCreated = (commonDateCreated != date)
        commonDateCreated = date

        // Update cell
        let rowIndex = EditImageParamsOrder.time.rawValue - (hasDatePicker ? 0 : 1)
        let indexPath = IndexPath(row: rowIndex, section: 0)
        editImageParamsTableView.reloadRows(at: [indexPath], with: .automatic)
    }
}
