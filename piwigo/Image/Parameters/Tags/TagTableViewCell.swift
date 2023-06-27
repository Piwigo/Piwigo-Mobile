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
import piwigoKit

enum pwgEditOption : Int {
    case none
    case add
    case remove
}

class TagTableViewCell: UITableViewCell {
    @IBOutlet weak var leftLabel: UILabel!
    @IBOutlet weak var rightAddImage: UIImageView!
    @IBOutlet weak var rightRemoveImage: UIImageView!

    func configure(with tag: Tag, andEditOption option: pwgEditOption) {
        // General settings
        backgroundColor = .piwigoColorCellBackground()
        tintColor = .piwigoColorOrange()
        textLabel?.font = .systemFont(ofSize: 17)

        // => pwg.tags.getList returns in addition: counter, url
        let nber = tag.numberOfImagesUnderTag
        if (nber == 0) || (nber == Int64.max) {
            // Unknown number of images
            leftLabel.text = tag.tagName
        } else {
            // Known number of images
            let numberFormatter = NumberFormatter()
            numberFormatter.numberStyle = .decimal
            let nberPhotos = (numberFormatter.string(from: NSNumber(value: nber)) ?? "0") as String
            let nberImages = nber > 1 ?
                String(format: NSLocalizedString("severalImagesCount", comment: "%@ photos"), nberPhotos) :
                String(format: NSLocalizedString("singleImageCount", comment: "%@ photo"), nberPhotos)
            leftLabel.text = "\(tag.tagName) (\(nberImages))"
        }
        leftLabel.font = .systemFont(ofSize: 17)
        leftLabel.textColor = .piwigoColorLeftLabel()

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
