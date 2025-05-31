//
//  CounterFormatSelectorViewController+UITableViewDelegate.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 30/05/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

extension CounterFormatSelectorViewController: UITableViewDelegate {
    
    // MARK: - Rows
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44.0
    }

    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return false
    }

    
    // MARK: - Footers
    private func getContentOfFooter(forSection section: Int) -> String {
        var text: String = ""
        switch CounterSection(rawValue: section) {
        case .start:
            text = NSLocalizedString("settings_renameCounterStartFooter", comment: "The counter is saved and incremented by one for each file processed.")
        case .prefix:
            break
        case .digits:
            text = NSLocalizedString("settings_renameCounterDigitsFooter", comment: "When the counter needs more digits than specified, the number of digits is automatically increased.")
        case .suffix:
            break
        default:
            preconditionFailure("Invalid section \(section)")
        }
        return text
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        let text = getContentOfFooter(forSection: section)
        return TableViewUtilities.shared.heightOfFooter(withText: text, width: tableView.frame.size.width)
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let text = getContentOfFooter(forSection: section)
        return TableViewUtilities.shared.viewOfFooter(withText: text)
    }
}
