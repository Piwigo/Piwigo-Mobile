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
        shouldUpdateDateCreated = (commonDateCreated != date)
        commonDateCreated = date
        
        // Update creation date cell
        let dateIndexPath = IndexPath(row: EditImageParamsOrder.date.rawValue, section: 0)
        editImageParamsTableView.reloadRows(at: [dateIndexPath], with: .automatic)
    }
    
    func didUnsetImageCreationDate() {
        // Apply new date
        shouldUpdateDateCreated = (commonDateCreated != DateUtilities.unknownDate)
        commonDateCreated = DateUtilities.unknownDate
        
        // Close date picker
        if hasDatePicker {
            hasDatePicker = false
            let rowIndex = EditImageParamsOrder.datePicker.rawValue
            removePicker(at: IndexPath(row: rowIndex, section: 0))
        }
        
        // Update creation date and time cells
        let dateIndexPath = IndexPath(row: EditImageParamsOrder.date.rawValue, section: 0)
        let rowIndex = EditImageParamsOrder.time.rawValue - (hasDatePicker ? 0 : 1)
        let timeIndexPath = IndexPath(row: rowIndex, section: 0)
        editImageParamsTableView.reloadRows(at: [dateIndexPath, timeIndexPath], with: .automatic)
    }
}
