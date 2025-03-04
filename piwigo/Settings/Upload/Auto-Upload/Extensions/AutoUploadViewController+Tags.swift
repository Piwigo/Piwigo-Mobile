//
//  AutoUploadViewController+Tags.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 02/01/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import UIKit
import piwigoKit

// MARK: - TagsViewControllerDelegate Methods
extension AutoUploadViewController: TagsViewControllerDelegate {
    // Collect selected tags
    func didSelectTags(_ selectedTags: Set<Tag>) {
        // Store selected tags
        let tagIDs: String = selectedTags.map({"\($0.tagId),"}).reduce("", +)
        UploadVars.shared.autoUploadTagIds = String(tagIDs.dropLast(1))

        // Update cell
        autoUploadTableView.reloadRows(at: [IndexPath(row: 0, section: 2)], with: .automatic)
    }
}
