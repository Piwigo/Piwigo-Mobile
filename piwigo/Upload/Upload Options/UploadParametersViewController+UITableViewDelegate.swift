//
//  UploadParametersViewController+UITableViewDelegate.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 31/05/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

extension UploadParametersViewController {
    
    // MARK: - Header
    private func getContentOfHeader() -> (String, String) {
        let title = String(format: "%@\n", NSLocalizedString("imageDetailsView_title", comment: "Properties"))
        let text = NSLocalizedString("imageUploadHeaderText_images", comment: "Please set the parameters to apply to the selection of photos/videos")
        return (title, text)
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let (title, text) = getContentOfHeader()
        return TableViewUtilities.shared.heightOfHeader(withTitle: title, text: text,
                                                        width: tableView.frame.size.width)
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let (title, text) = getContentOfHeader()
        return TableViewUtilities.shared.viewOfHeader(withTitle: title, text: text)
    }


    // MARK: - Rows
    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        // Don't present privacy level choice to non-admin users
        var row = indexPath.row
        row += (!(user?.hasAdminRights ?? false) && (row > 1)) ? 1 : 0

        var result: Bool
        switch EditImageDetailsOrder(rawValue: row) {
        case .imageName, .author, .comment:
            result = false
        default:
            result = true
        }
        return result
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        // Don't present privacy level choice to non-admin users
        var row = indexPath.row
        row += (!(user?.hasAdminRights ?? false) && (row > 1)) ? 1 : 0

        switch EditImageDetailsOrder(rawValue: row) {
        case .author:
            // only update if not yet set, dont overwrite
            if commonAuthor.isEmpty,
               UploadVars.shared.defaultAuthor.isEmpty == false {
                // must know the default author
                commonAuthor = UploadVars.shared.defaultAuthor
                tableView.reloadRows(at: [indexPath], with: .automatic)
            }

        case .privacy:
            // Dismiss the keyboard
            view.endEditing(true)

            // Create view controller
            let privacySB = UIStoryboard(name: "SelectPrivacyViewController", bundle: nil)
            guard let privacyVC = privacySB.instantiateViewController(withIdentifier: "SelectPrivacyViewController") as? SelectPrivacyViewController
            else { preconditionFailure("Could not load SelectPrivacyViewController") }
            privacyVC.delegate = self
            privacyVC.privacy = commonPrivacyLevel
            navigationController?.pushViewController(privacyVC, animated: true)

        case .tags:
            // Dismiss the keyboard
            view.endEditing(true)

            // Create view controller
            let tagsSB = UIStoryboard(name: "TagsViewController", bundle: nil)
            guard let tagsVC = tagsSB.instantiateViewController(withIdentifier: "TagsViewController") as? TagsViewController
            else { preconditionFailure("Could not load TagsViewController") }
            tagsVC.delegate = self
            tagsVC.user = user
            tagsVC.setPreselectedTagIds(Set(commonTags.map({$0.tagId})))
            navigationController?.pushViewController(tagsVC, animated: true)
            
        default:
            return
        }
    }

    
    // MARK: - Footer
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.0 // To hide the section footer
    }
}
