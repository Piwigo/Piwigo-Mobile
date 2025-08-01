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
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "title", for: indexPath) as? EditImageTextFieldTableViewCell
            else { preconditionFailure("Could not load a EditImageTextFieldTableViewCell") }
            let titleLength: Int = commonTitle.string.count
            let wholeRange = NSRange(location: 0, length: titleLength)
            let style = NSMutableParagraphStyle()
            style.alignment = NSTextAlignment.right
            let attributes = [
                NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17),
                NSAttributedString.Key.paragraphStyle: style
            ]
            let detail = NSMutableAttributedString(attributedString: commonTitle)
            detail.addAttributes(attributes, range: wholeRange)
            cell.config(withLabel: NSAttributedString(string: NSLocalizedString("editImageDetails_title", comment: "Title")), placeHolder: NSLocalizedString("editImageDetails_titlePlaceholder", comment: "Title"), andImageDetail: detail)
            if shouldUpdateTitle {
                cell.cellTextField.textColor = .piwigoColorOrange()
            }
            cell.cellTextField.tag = indexPath.row
            cell.cellTextField.delegate = self
            tableViewCell = cell
            
        case .author:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "author", for: indexPath) as? EditImageTextFieldTableViewCell
            else { preconditionFailure("Could not load a EditImageTextFieldTableViewCell") }
            cell.config(withLabel: NSAttributedString(string: NSLocalizedString("editImageDetails_author", comment: "Author")), placeHolder: NSLocalizedString("settings_defaultAuthorPlaceholder", comment: "Author Name"), andImageDetail: NSAttributedString(string: commonAuthor))
            if shouldUpdateAuthor {
                cell.cellTextField.textColor = .piwigoColorOrange()
            }
            cell.cellTextField.tag = indexPath.row
            cell.cellTextField.delegate = self
            tableViewCell = cell
            
        case .date:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "dateCreation", for: indexPath) as? EditImageTextFieldTableViewCell
            else { preconditionFailure("Could not load a EditImageTextFieldTableViewCell") }
            cell.config(withLabel: NSAttributedString(string: NSLocalizedString("editImageDetails_dateCreation", comment: "Creation Date")), placeHolder: "", andImageDetail: NSAttributedString(string: getStringFrom(commonDateCreated)))
            if shouldUpdateDateCreated {
                cell.cellTextField.textColor = .piwigoColorOrange()
            }
            cell.cellTextField.tag = row
            cell.cellTextField.delegate = self
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
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "tags", for: indexPath) as? EditImageTagsTableViewCell 
            else { preconditionFailure("Could not load a EditImageTagsTableViewCell") }
            cell.config(withList: commonTags,
                        inColor: shouldUpdateTags ? UIColor.piwigoColorOrange() : UIColor.piwigoColorRightLabel())
            tableViewCell = cell
            
        case .privacy:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "privacy", for: indexPath) as? EditImagePrivacyTableViewCell
            else { preconditionFailure("Could not load a EditImagePrivacyTableViewCell") }
            cell.setLeftLabel(withText: NSLocalizedString("editImageDetails_privacyLevel", comment: "Who can see this photo?"))
            cell.setPrivacyLevel(with: pwgPrivacy(rawValue: commonPrivacyLevel) ?? .everybody,
                                 inColor: shouldUpdatePrivacyLevel ? .piwigoColorOrange() : .piwigoColorRightLabel())
            tableViewCell = cell

        case .desc:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "description", for: indexPath) as? EditImageTextViewTableViewCell
            else { preconditionFailure("Could not load a EditImageTextViewTableViewCell") }
            let wholeRange = NSRange(location: 0, length: commonComment.string.count)
            let style = NSMutableParagraphStyle()
            style.alignment = NSTextAlignment.left
            let attributes = [
                NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17),
                NSAttributedString.Key.paragraphStyle: style
            ]
            let detail = NSMutableAttributedString(attributedString: commonComment)
            detail.addAttributes(attributes, range: wholeRange)
            cell.config(withText: detail,
                        inColor: shouldUpdateTags ? .piwigoColorOrange() : .piwigoColorRightLabel())
            cell.textView.tag = indexPath.row
            cell.textView.delegate = self
            tableViewCell = cell
            
        default:
            break
        }

        tableViewCell.backgroundColor = .piwigoColorCellBackground()
        tableViewCell.tintColor = .piwigoColorOrange()
        return tableViewCell
    }

    private func getStringFrom(_ date: Date?) -> String {
        var dateStr = ""
        var timeStr = ""
        if let date = date, date > DateUtilities.weekAfter {
            let dateFormatter = DateUtilities.dateFormatter()
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
