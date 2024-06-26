//
//  EditImageParamsViewController+ShiftPicker.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 31/12/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import Foundation

// MARK: -  EditImageShiftPickerDelegate Methods
extension EditImageParamsViewController: EditImageShiftPickerDelegate
{
    func didSelectDate(withShiftPicker date: Date) {
        // Apply new date
        shouldUpdateDateCreated = true
        commonDateCreated = date

        // Update cell
        let indexPath = IndexPath(row: EditImageParamsOrder.date.rawValue, section: 0)
        editImageParamsTableView.reloadRows(at: [indexPath], with: .automatic)
    }
}
