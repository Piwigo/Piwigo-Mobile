//
//  TagTableViewCell.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 27/01/2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//
//  Converted to Swift 5.1 by Eddy Lelièvre-Berna on 17/07/2020.
//

import UIKit

enum kPiwigoEditOption : Int {
    case none
    case add
    case remove
}

class TagTableViewCell: UITableViewCell {
    @IBOutlet weak var leftLabel: UILabel!
    @IBOutlet weak var rightAddImage: UIImageView!
    @IBOutlet weak var rightRemoveImage: UIImageView!

    func configure(with tag: Tag, andEditOption option: kPiwigoEditOption) {
        // General settings
        backgroundColor = UIColor.piwigoColorCellBackground()
        tintColor = UIColor.piwigoColorOrange()
        textLabel?.font = UIFont.piwigoFontNormal()

        // => pwg.tags.getList returns in addition: counter, url
        let nber = tag.numberOfImagesUnderTag
        if (nber == 0) || (nber == Int64.max) {
            // Unknown number of images
            leftLabel.text = tag.tagName
        } else if nber > 1 {
            // Known number of images
            leftLabel.text = String(format: "%@ (%lld %@)", tag.tagName, nber,  NSLocalizedString("categoryTableView_photosCount", comment: "photos"))
        } else {
            leftLabel.text = String(format: "%@ (%lld %@)", tag.tagName, nber, NSLocalizedString("categoryTableView_photoCount", comment: "photo"))
        }
        leftLabel.font = UIFont.piwigoFontNormal()
        leftLabel.textColor = UIColor.piwigoColorLeftLabel()

        // Change image according to state
        switch option {
        case .none:
            rightAddImage.isHidden = true
            rightRemoveImage.isHidden = true
        case .add:
            rightAddImage.isHidden = false
            rightRemoveImage.isHidden = true
        case .remove:
            rightAddImage.isHidden = true
            rightRemoveImage.isHidden = false
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        leftLabel.text = ""
    }
}
