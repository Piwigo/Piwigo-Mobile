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

        var tableViewCell = UITableViewCell()
        switch EditImageDetailsOrder(rawValue: row) {
        case .imageName:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "title", for: indexPath) as? EditImageTextFieldTableViewCell
            else { preconditionFailure("Could not load a EditImageTextFieldTableViewCell!") }
            cell.config(withLabel: NSAttributedString(string: NSLocalizedString("editImageDetails_title", comment: "Title:")),
                        placeHolder: NSLocalizedString("editImageDetails_titlePlaceholder", comment: "Title"),
                        andImageDetail: NSAttributedString(string: commonTitle))
            cell.cellTextField.textColor = shouldUpdateTitle ? PwgColor.orange : PwgColor.rightLabel
            cell.cellTextField.tag = EditImageDetailsOrder.imageName.rawValue
            cell.cellTextField.delegate = self
            tableViewCell = cell

        case .author:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "author", for: indexPath) as? EditImageTextFieldTableViewCell
            else { preconditionFailure("Could not load a EditImageTextFieldTableViewCell!") }
            cell.config(withLabel: NSAttributedString(string: NSLocalizedString("editImageDetails_author", comment: "Author:")),
                        placeHolder: NSLocalizedString("settings_defaultAuthorPlaceholder", comment: "Author Name"),
                        andImageDetail: NSAttributedString(string: commonAuthor))
            cell.cellTextField.textColor = shouldUpdateAuthor ? PwgColor.orange : PwgColor.rightLabel
            cell.cellTextField.tag = EditImageDetailsOrder.author.rawValue
            cell.cellTextField.delegate = self
            tableViewCell = cell

        case .privacy:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "privacy", for: indexPath) as? EditImagePrivacyTableViewCell
            else { preconditionFailure("Could not load a EditImagePrivacyTableViewCell!") }
            cell.setLeftLabel(withText: NSLocalizedString("editImageDetails_privacyLevel", comment: "Who can see this photo?"))
            cell.setPrivacyLevel(with: commonPrivacyLevel,
                                 inColor: shouldUpdatePrivacyLevel ? PwgColor.orange : PwgColor.rightLabel)
            tableViewCell = cell

        case .tags:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "tags", for: indexPath) as? EditImageTagsTableViewCell
            else { preconditionFailure("Could not load a EditImageTagsTableViewCell!") }
            cell.config(withList: commonTags,
                        inColor: shouldUpdateTags ? PwgColor.orange : PwgColor.rightLabel)
            cell.accessibilityIdentifier = "setTags"
            tableViewCell = cell

        case .comment:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "comment", for: indexPath) as? EditImageTextViewTableViewCell
            else { preconditionFailure("Could not load a EditImageTextViewTableViewCell!") }
            cell.config(withText: NSAttributedString(string: commonComment),
                        inColor: shouldUpdateComment ? PwgColor.orange : PwgColor.rightLabel)
            cell.textView.delegate = self
            tableViewCell = cell

        default:
            break
        }

        tableViewCell.backgroundColor = PwgColor.cellBackground
        tableViewCell.tintColor = PwgColor.tintColor
        return tableViewCell
    }
}
