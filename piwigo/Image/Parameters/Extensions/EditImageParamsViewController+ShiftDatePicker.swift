//
//  EditImageParamsViewController+ShiftDatePicker.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 18/10/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation

// MARK: -  EditImageShiftDatePickerDelegate Methods
extension EditImageParamsViewController: EditImageShiftDateDelegate
{
    func didShiftDate(withPicker date: Date) {
        // Apply new date
        shouldUpdateDateCreated = (commonDateCreated != date)
        commonDateCreated = date

        // Update creation date cell
        let indexPath = IndexPath(row: EditImageParamsOrder.date.rawValue, section: 0)
        editImageParamsTableView.reloadRows(at: [indexPath], with: .automatic)
    }
}
