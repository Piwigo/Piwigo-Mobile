//
//  LabelTableViewCell.swift
//  piwigo
//
//  Created by Spencer Baker on 2/15/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//
//  Converted to Swift 5 by Eddy Lelièvre-Berna on 12/04/2020.
//

import UIKit
import PwgUIKit

class LabelTableViewCell: UITableViewCell {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var detailLabel: UILabel!
    @IBOutlet weak var topMargin: NSLayoutConstraint!
    @IBOutlet weak var bottomMargin: NSLayoutConstraint!

    func configure(with title: String, detail: String) -> Void {

        // Background color and aspect
        backgroundColor = PwgColor.cellBackground
        topMargin.constant = TableViewUtilities.vertMargin
        bottomMargin.constant = TableViewUtilities.vertMargin

        // Left side: title
        titleLabel.text = title
        titleLabel.isHidden = title.isEmpty
        titleLabel.textColor = PwgColor.leftLabel
        
        // Right side: detail
        detailLabel.text = detail
        detailLabel.textColor = PwgColor.rightLabel
        detailLabel.isHidden = detail.isEmpty

        // A detail sharing the line with the title belongs against the trailing
        // edge. NSTextAlignment has no trailing case and .natural means leading,
        // so the alignment is derived from the layout direction. Short details are
        // already flush because the label hugs them, but a long one stretches the
        // label and would otherwise be pushed away from that edge.
        // The accessibility variant stacks both labels, where leading is correct.
        if traitCollection.preferredContentSizeCategory < .accessibilityMedium {
            detailLabel.textAlignment =
                effectiveUserInterfaceLayoutDirection == .rightToLeft ? .left : .right
        } else {
            detailLabel.textAlignment = .natural
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = ""
        detailLabel.text = ""
    }
}
