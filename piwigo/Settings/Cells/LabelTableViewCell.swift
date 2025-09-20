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
        if title.isEmpty {
            titleLabel.isHidden = true
        } else {
            detailLabel.isHidden = false
            titleLabel.textColor = PwgColor.leftLabel
            titleLabel.text = title
        }
        
        // Right side: detail
        if detail.isEmpty {
            detailLabel.isHidden = true
        } else {
            detailLabel.isHidden = false
            detailLabel.textColor = PwgColor.rightLabel
            detailLabel.text = detail
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = ""
        detailLabel.text = ""
    }
}
