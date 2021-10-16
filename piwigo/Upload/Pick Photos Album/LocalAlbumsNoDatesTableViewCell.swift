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
    
    func configure(with title: String, nberPhotos: Int) -> Void {

        // Background color and aspect
        backgroundColor = .piwigoColorCellBackground()
        tintColor = .piwigoColorOrange()

        // Title
        titleLabel.font = UIFont.piwigoFontNormal()
        titleLabel.textColor = .piwigoColorLeftLabel()
        titleLabel.text = title
        
        // Number of photos
        numberLabel.font = UIFont.piwigoFontSmall()
        numberLabel.textColor = .piwigoColorRightLabel()
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        if nberPhotos != NSNotFound {
            numberLabel.text = numberFormatter.string(from: NSNumber(value: nberPhotos))
        } else {
            numberLabel.text = ""
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = ""
        numberLabel.text = ""
    }
}
