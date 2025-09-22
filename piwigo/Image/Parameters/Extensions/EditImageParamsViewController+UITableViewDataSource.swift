//
//  EditImageParamsViewController+UITableViewDataSource.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 31/12/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

// MARK: - UITableViewDataSource Methods
extension EditImageParamsViewController: UITableViewDataSource
{
    func rowAt(indexPath: IndexPath) -> Int {
        var row = indexPath.row
        row += (!hasDatePicker && (row > EditImageParamsOrder.date.rawValue)) ? 1 : 0
        row += (!user.hasAdminRights && (row > EditImageParamsOrder.tags.rawValue)) ? 1 : 0
        return row
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var nberOfRows = EditImageParamsOrder.count.rawValue
        nberOfRows -= hasDatePicker ? 0 : 1
        nberOfRows -= user.hasAdminRights ? 0 : 1
        return nberOfRows
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var tableViewCell = UITableViewCell()
        let contentSizeCategory = traitCollection.preferredContentSizeCategory
        let row = rowAt(indexPath: indexPath)
        switch EditImageParamsOrder(rawValue: row) {
        case .thumbnails:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "EditImageThumbTableViewCell", for: indexPath) as? EditImageThumbTableViewCell
            else { preconditionFailure("Could not load a EditImageThumbTableViewCell") }
            cell.user = user
            cell.config(withImages: images)
            cell.delegate = self
            tableViewCell = cell
            
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
            cell.rightTextField.tag = indexPath.row
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
            cell.rightTextField.tag = indexPath.row
            cell.rightTextField.delegate = self
            tableViewCell = cell
            
        case .date:
            let cellIdentifier: String = contentSizeCategory < .accessibilityMedium
                ? "TextFieldTableViewCell"
                : "TextFieldTableViewCell2"
            guard let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? TextFieldTableViewCell
            else { preconditionFailure("Could not load TextFieldTableViewCell") }
            let title = RenameAction.ActionType.addDate.name
            let detail = getStringFrom(commonDateCreated)
            cell.configure(with: title, input: detail, placeHolder: "")
            cell.rightTextField.textColor = shouldUpdateDateCreated ? PwgColor.orange : PwgColor.rightLabel
            cell.rightTextField.tag = indexPath.row
            cell.rightTextField.delegate = self
            tableViewCell = cell
            
        case .datePicker:
            // Which picker?
            if images.count > 1 {
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "ShiftPickerTableCell", for: indexPath) as? EditImageShiftPickerTableViewCell 
                else { preconditionFailure("Could not load a EditImageShiftPickerTableViewCell") }
                cell.config(withDate: commonDateCreated, animated: false)
                cell.delegate = self
                tableViewCell = cell
                
            } else {
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "DatePickerTableCell", for: indexPath) as? EditImageDatePickerTableViewCell
                else { preconditionFailure("Could not load a EditImageDatePickerTableViewCell") }
                cell.config(withDate: commonDateCreated, animated: false)
                cell.setDatePickerButtons()
                cell.delegate = self
                tableViewCell = cell
            }
            
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
            tableViewCell = cell
            
        case .privacy:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell2", for: indexPath) as? LabelTableViewCell
            else { preconditionFailure("Could not load LabelTableViewCell")}
            let title = NSLocalizedString("editImageDetails_privacyLevel", comment: "Who can see this photo?")
            let privacy = pwgPrivacy(rawValue: commonPrivacyLevel) ?? .everybody
            cell.configure(with: title, detail: privacy.name)
            cell.detailLabel.textColor = shouldUpdatePrivacyLevel ? PwgColor.orange : PwgColor.rightLabel
            cell.accessoryType = .disclosureIndicator
            tableViewCell = cell
            
        case .desc:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "TextViewTableViewCell", for: indexPath) as? TextViewTableViewCell
            else { preconditionFailure("Could not load a TextViewTableViewCell!") }
            cell.config(withText: commonComment,
                        inColor: shouldUpdateComment ? PwgColor.orange : PwgColor.rightLabel)
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
            tableViewCell = cell
            
        default:
            break
        }

        tableViewCell.backgroundColor = PwgColor.cellBackground
        tableViewCell.tintColor = PwgColor.orange
        return tableViewCell
    }

    private func getStringFrom(_ date: Date?) -> String {
        var dateStr = ""
        var timeStr = ""
        if let date = date, date > DateUtilities.weekAfter {
            let dateFormatter = DateUtilities.dateFormatter
            if view.bounds.size.width > 430 {
                // i.e. larger than iPhone 14 Pro Max screen width
                dateFormatter.dateStyle = .long
                dateFormatter.timeStyle = .none
                dateStr = dateFormatter.string(from: date)
                dateFormatter.dateStyle = .none
                dateFormatter.timeStyle = .medium
                timeStr = dateFormatter.string(from: date)
            } else if view.bounds.size.width > 320 {
                // i.e. larger than iPhone 5 screen width
                dateFormatter.dateStyle = .medium
                dateFormatter.timeStyle = .none
                dateStr = dateFormatter.string(from: date)
                dateFormatter.dateStyle = .none
                dateFormatter.timeStyle = .medium
                timeStr = dateFormatter.string(from: date)
            } else {
                dateFormatter.dateStyle = .short
                dateFormatter.timeStyle = .none
                dateStr = dateFormatter.string(from: date)
                dateFormatter.dateStyle = .none
                dateFormatter.timeStyle = .medium
                timeStr = dateFormatter.string(from: date)
            }
        }
        return "\(dateStr) - \(timeStr)"
    }
}
