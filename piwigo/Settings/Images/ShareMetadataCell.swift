//
//  ShareMetadataCell.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 27/01/2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//

import UIKit

enum cellIconType : Int {
    case add, remove
}

class ShareMetadataCell: UITableViewCell {
    
    @IBOutlet weak var leftLabel: UILabel!
    @IBOutlet weak var rightAddImage: UIImageView!
    @IBOutlet weak var rightRemoveImage: UIImageView!
    
    func configure(with activityName: String?, andEditOption option: cellIconType) {
        // General settings
        backgroundColor = UIColor.piwigoColorCellBackground()
        tintColor = UIColor.piwigoColorOrange()
        textLabel?.font = UIFont.piwigoFontNormal()

        // Activity name
        leftLabel.text = activityName ?? "Unknown Activity"
        leftLabel.font = UIFont.piwigoFontNormal()
        leftLabel.textColor = UIColor.piwigoColorLeftLabel()

        // Change image according to state
        switch option {
            case cellIconType.add:
                rightAddImage.isHidden = false
                rightRemoveImage.isHidden = true
            case cellIconType.remove:
                rightAddImage.isHidden = true
                rightRemoveImage.isHidden = false
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        leftLabel.text = ""
    }
}
