//
//  EditImageParamsViewController+Tags.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 31/12/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import UIKit
import piwigoKit

// MARK: - TagsViewControllerDelegate Methods
extension EditImageParamsViewController: TagsViewControllerDelegate
{
    func didSelectTags(_ selectedTags: Set<Tag>) {
        // Check if the user decided to leave the Edit mode
        if !(navigationController?.visibleViewController is EditImageParamsViewController) {
            // Returned to image
            delegate?.didFinishEditingParameters()
            return
        }

        // Build list of added tags
        addedTags = []
        for tag in selectedTags {
            if commonTags.contains(where: { $0.tagId == tag.tagId }) == false {
                addedTags.insert(tag)
            }
        }

        // Build list of removed tags
        removedTags = []
        for tag in commonTags {
            if !selectedTags.contains(where: { $0.tagId == tag.tagId }) {
                removedTags.insert(tag)
            }
        }

        // Do we need to update images?
        if (addedTags.isEmpty == false) || (removedTags.isEmpty == false) {
            // Update common tag list and remember to update image info
            shouldUpdateTags = true
            commonTags = Set(selectedTags)

            // Refresh table row
            var row: Int = EditImageParamsOrder.tags.rawValue
            row -= !hasDatePicker ? 1 : 0
            let indexPath = IndexPath(row: row, section: 0)
            editImageParamsTableView.reloadRows(at: [indexPath], with: .automatic)
        }
    }
}
