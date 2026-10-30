//
//  VideoSummaryTableViewCell.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 29/10/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//
//  Cell of the metadata table presenting the frame rate and the duration of a video side by side.
//

import UIKit
import PwgUIKit

final class VideoSummaryTableViewCell: UITableViewCell
{
    static let reuseIdentifier = "VideoSummaryTableViewCell"

    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var topMargin: NSLayoutConstraint!
    @IBOutlet weak var bottomMargin: NSLayoutConstraint!
    @IBOutlet var itemLabels: [UILabel]!
    @IBOutlet var separators: [UIView]!

    /// The items are laid out side by side, or one under the other at the largest sizes of text
    func configure(with items: [String]) {
        // Same margins as the label cells of the table
        topMargin.constant = TableViewUtilities.vertMargin
        bottomMargin.constant = TableViewUtilities.vertMargin

        let isLarge = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        stackView.axis = isLarge ? .vertical : .horizontal
        stackView.alignment = isLarge ? .leading : .fill
        /// The two items stay together, centred in the cell
        stackView.distribution = .fill
        stackView.spacing = isLarge ? 8 : 16

        for (index, label) in itemLabels.enumerated() {
            label.text = items.indices.contains(index) ? items[index] : ""
            label.textColor = PwgColor.rightLabel
            label.font = UIFont.preferredFont(forTextStyle: .subheadline)
            label.adjustsFontForContentSizeCategory = true
            label.numberOfLines = isLarge ? 0 : 1
            label.textAlignment = isLarge ? .natural : .center
        }
        for separator in separators {
            separator.backgroundColor = PwgColor.separator
            separator.isHidden = isLarge
        }
    }
}
