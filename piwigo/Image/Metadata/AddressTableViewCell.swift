//
//  AddressTableViewCell.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 28/10/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//
//  Cell of the metadata table presenting the address of the location.
//

import UIKit
import PwgUIKit

final class AddressTableViewCell: UITableViewCell
{
    static let reuseIdentifier = "AddressTableViewCell"

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var spinner: UIActivityIndicatorView!

    func configure(title: String, subtitle: String, isLoading: Bool) {
        titleLabel.text = title
        titleLabel.textColor = PwgColor.leftLabel
        subtitleLabel.text = subtitle
        subtitleLabel.textColor = PwgColor.rightLabel
        subtitleLabel.isHidden = subtitle.isEmpty
        spinner.color = PwgColor.rightLabel
        if isLoading { spinner.startAnimating() } else { spinner.stopAnimating() }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
        subtitleLabel.text = nil
        spinner.stopAnimating()
    }
}
