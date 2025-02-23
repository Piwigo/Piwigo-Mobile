//
//  EditImageParamsViewController+ThumbnailCell.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 31/12/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import UIKit
import piwigoKit

// MARK: - EditImageThumbnailCellDelegate Methods
extension EditImageParamsViewController: EditImageThumbnailCellDelegate
{
    func didDeselectImage(withID imageID: Int64) {
        // Hide picker if needed
        let indexPath = IndexPath(row: EditImageParamsOrder.datePicker.rawValue, section: 0)
        if hasDatePicker {
            // Found a picker, so remove it
            hasDatePicker = false
            editImageParamsTableView.beginUpdates()
            editImageParamsTableView.deleteRows(at: [indexPath], with: .fade)
            editImageParamsTableView.endUpdates()
        }

        // Update data source
        let timeInterval = commonDateCreated.timeIntervalSince(oldCreationDate)
        images.removeAll(where: {$0.pwgID == imageID})

        // Update common creation date if needed
        oldCreationDate = Date(timeIntervalSinceReferenceDate: images[0].dateCreated)
        commonDateCreated = oldCreationDate.addingTimeInterval(timeInterval)

        // Refresh table
        editImageParamsTableView.reloadData()

        // Deselect image in album view
        delegate?.didDeselectImage(withID: imageID)
    }

    func didRenameFileOfImage(_ imageData: Image) {
        // Update data source
        do {
            try mainContext.save()
        } catch let error {
            debugPrint("Could not save renamed file, \(error)")
        }

        // Update parent image view
        delegate?.didChangeImageParameters(imageData)
    }
}
