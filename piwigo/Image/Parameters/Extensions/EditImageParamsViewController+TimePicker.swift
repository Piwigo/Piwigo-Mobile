//
//  EditImageParamsViewController+TimePicker.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 11/10/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation

// MARK: -  EditImageTimePickerDelegate Methods
extension EditImageParamsViewController: EditImageTimePickerDelegate
{
    func didSelectTime(withPicker date: Date) {
        // Apply new date
        shouldUpdateDateCreated = (commonDateCreated != date)
        commonDateCreated = date

        // Update cell
        let rowIndex = EditImageParamsOrder.time.rawValue - (hasDatePicker ? 0 : 1)
        let indexPath = IndexPath(row: rowIndex, section: 0)
        editImageParamsTableView.reloadRows(at: [indexPath], with: .automatic)
    }
}
