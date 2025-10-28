//
//  UploadParametersViewController+UITableViewDataSource.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 31/05/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

extension UploadParametersViewController {
    
    // MARK: - Rows
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Don't present privacy level choice to non-admin users
        var nberOfRows = EditImageDetailsOrder.count.rawValue
        nberOfRows -= (!(user?.hasAdminRights ?? false) ? 1 : 0)
        
        return nberOfRows
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Don't present privacy level choice to non-admin users
        var row = indexPath.row
        row += (!(user?.hasAdminRights ?? false) && (row > 1)) ? 1 : 0
        
        let contentSizeCategory = traitCollection.preferredContentSizeCategory
        var tableViewCell = UITableViewCell()
        switch EditImageDetailsOrder(rawValue: row) {
        case .imageName:
            let cellIdentifier: String = contentSizeCategory < .accessibilityMedium
                ? "TextFieldTableViewCell"
                : "TextFieldTableViewCell2"
            guard let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? TextFieldTableViewCell
            else { preconditionFailure("Could not load TextFieldTableViewCell") }
            let title = NSLocalizedString("editImageDetails_title", comment: "Title")
            let placeholder = NSLocalizedString("editImageDetails_titlePlaceholder", comment: "Title placeholder")
            cell.configure(with: title, input: commonTitle, placeHolder: placeholder)
            cell.rightTextField.textColor = shouldUpdateTitle ? PwgColor.orange : PwgColor.rightLabel
            cell.rightTextField.tag = EditImageDetailsOrder.imageName.rawValue
            cell.rightTextField.delegate = self
            tableViewCell = cell

        case .author:
            let cellIdentifier: String = contentSizeCategory < .accessibilityMedium
                ? "TextFieldTableViewCell"
                : "TextFieldTableViewCell2"
            guard let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? TextFieldTableViewCell
            else { preconditionFailure("Could not load TextFieldTableViewCell") }
            let title = NSLocalizedString("editImageDetails_author", comment: "Author")
            let placeholder = NSLocalizedString("settings_defaultAuthorPlaceholder", comment: "Author Name")
            cell.configure(with: title, input: commonAuthor, placeHolder: placeholder)
            cell.rightTextField.textColor = shouldUpdateAuthor ? PwgColor.orange : PwgColor.rightLabel
            cell.rightTextField.tag = EditImageDetailsOrder.author.rawValue
            cell.rightTextField.delegate = self
            tableViewCell = cell

        case .tags:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell2", for: indexPath) as? LabelTableViewCell
            else { preconditionFailure("Could not load LabelTableViewCell")}
            let title = NSLocalizedString("editImageDetails_tags", comment: "Tags")
            // Retrieve tags and switch to old cache data format
            let tagList: String = commonTags.compactMap({"\($0.tagName), "}).reduce("", +)
            let tagString = String(tagList.dropLast(2))
            let detail = tagString.isEmpty ? NSLocalizedString("none", comment: "none") : tagString
            cell.configure(with: title, detail: detail)
            cell.detailLabel.textColor = shouldUpdateTags ? PwgColor.orange : PwgColor.rightLabel
            cell.accessoryType = .disclosureIndicator
            cell.accessibilityIdentifier = "setTags"
            tableViewCell = cell

        case .privacy:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell2", for: indexPath) as? LabelTableViewCell
            else { preconditionFailure("Could not load LabelTableViewCell")}
            let title = NSLocalizedString("editImageDetails_privacyLevel", comment: "Who can see this photo?")
            cell.configure(with: title, detail: commonPrivacyLevel.name)
            cell.detailLabel.textColor = shouldUpdatePrivacyLevel ? PwgColor.orange : PwgColor.rightLabel
            cell.accessoryType = .disclosureIndicator
            tableViewCell = cell

        case .comment:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "TextViewTableViewCell", for: indexPath) as? TextViewTableViewCell
            else { preconditionFailure("Could not load a TextViewTableViewCell!") }
            cell.config(withText: commonComment,
                        inColor: shouldUpdateComment ? PwgColor.orange : PwgColor.rightLabel)
            cell.textView.tag = EditImageDetailsOrder.comment.rawValue
            cell.textView.delegate = self
            tableViewCell = cell

            // Piwigo does not manage HTML descriptions.
            // So we disable the editor to prevent a mess when the description contains HTML.
            if commonComment.containsHTML {
                cell.textView.isEditable = false
            } else {
                cell.textView.isEditable = true
                cell.textView.tag = indexPath.row
                cell.textView.delegate = self
            }
        default:
            break
        }
        
        tableViewCell.backgroundColor = PwgColor.cellBackground
        tableViewCell.tintColor = PwgColor.tintColor
        return tableViewCell
    }
}
