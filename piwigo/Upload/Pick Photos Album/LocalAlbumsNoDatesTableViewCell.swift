//
//  LocalAlbumsNoDatesTableViewCell.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 28/05/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import UIKit

class LocalAlbumsNoDatesTableViewCell: UITableViewCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var numberLabel: UILabel!
    
    func configure(with title: String, nberPhotos: Int64) -> Void {

        // Background color and aspect
        backgroundColor = PwgColor.cellBackground
        tintColor = PwgColor.tintColor

        // Title
        titleLabel.textColor = PwgColor.leftLabel
        titleLabel.text = title
        
        // Number of photos
        numberLabel.textColor = PwgColor.rightLabel
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        if [Int64.min, Int64.max].contains(nberPhotos) {
            numberLabel.text = ""
        } else {
            numberLabel.text = numberFormatter.string(from: NSNumber(value: nberPhotos))
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = ""
        numberLabel.text = ""
    }
}
