//
//  EditImageParamsViewController+UITableViewDelegate.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 31/12/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import piwigoKit
import UIKit

// MARK: - UITableViewDelegate Methods
extension EditImageParamsViewController: UITableViewDelegate
{
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0.0 // To hide the section header
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.0 // To hide the section footer
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let row = rowAt(indexPath: indexPath)
        switch EditImageParamsOrder(rawValue: row) {
        case .privacy:
            // Deselect row
            tableView.deselectRow(at: indexPath, animated: true)

            // Dismiss the keyboard
            view.endEditing(true)

            // Hide picker if necessary
            let indexPath = IndexPath(row: EditImageParamsOrder.datePicker.rawValue, section: 0)
            if hasDatePicker {
                // Found a picker, so remove it
                hasDatePicker = false
                editImageParamsTableView.beginUpdates()
                editImageParamsTableView.deleteRows(at: [indexPath], with: .fade)
                editImageParamsTableView.endUpdates()
            }

            // Create view controller
            let privacySB = UIStoryboard(name: "SelectPrivacyViewController", bundle: nil)
            guard let privacyVC = privacySB.instantiateViewController(withIdentifier: "SelectPrivacyViewController") as? SelectPrivacyViewController
            else { preconditionFailure("Could not load SelectPrivacyViewController") }
            privacyVC.delegate = self
            privacyVC.privacy = pwgPrivacy(rawValue: commonPrivacyLevel) ?? .everybody
            navigationController?.pushViewController(privacyVC, animated: true)
            
        case .tags:
            // Deselect row
            tableView.deselectRow(at: indexPath, animated: true)

            // Dismiss the keyboard
            view.endEditing(true)

            // Hide picker if necessary
            let indexPath = IndexPath(row: EditImageParamsOrder.datePicker.rawValue, section: 0)
            if hasDatePicker {
                // Found a picker, so remove it
                hasDatePicker = false
                editImageParamsTableView.beginUpdates()
                editImageParamsTableView.deleteRows(at: [indexPath], with: .fade)
                editImageParamsTableView.endUpdates()
            }

            // Create view controller
            let tagsSB = UIStoryboard(name: "TagsViewController", bundle: nil)
            guard let tagsVC = tagsSB.instantiateViewController(withIdentifier: "TagsViewController") as? TagsViewController
            else { preconditionFailure("Could not load TagsViewController") }
            tagsVC.delegate = self
            tagsVC.user = user
            let tagList: [Int32] = commonTags.compactMap { Int32($0.tagId) }
            tagsVC.setPreselectedTagIds(Set(tagList))
            navigationController?.pushViewController(tagsVC, animated: true)
            
        default:
            break
        }
    }

    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        var result: Bool
        let row = rowAt(indexPath: indexPath)
        switch EditImageParamsOrder(rawValue: row) {
            case .imageName, .author, .date, .datePicker, .desc:
                result = false
            default:
                result = true
        }

        return result
    }
}
