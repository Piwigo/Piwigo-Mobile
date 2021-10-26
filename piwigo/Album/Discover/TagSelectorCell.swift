//
//  TagSelectorCell.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 09/02/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import UIKit
import piwigoKit

class TagSelectorCell: UITableViewCell {
    
    @IBOutlet weak private var tagLabel: UILabel!
    
    // Configures the cell with a tag instance
    func configure(with tag: Tag) {
        
        // General settings
        backgroundColor = .piwigoColorCellBackground()
        tintColor = .piwigoColorOrange()
        tagLabel.font = .piwigoFontNormal()
        tagLabel.textColor = .piwigoColorLeftLabel()

        // => pwg.tags.getList returns in addition: counter, url
        let nber = tag.numberOfImagesUnderTag
        if (nber == 0) || (nber == Int64.max) {
            // Unknown number of images
            tagLabel.text = tag.tagName
        } else {
            let numberFormatter = NumberFormatter()
            numberFormatter.numberStyle = .decimal
            let nberPhotos = (numberFormatter.string(from: NSNumber(value: nber)) ?? "0") as String
            let nberImages = nber > 1 ?
                String(format: NSLocalizedString("severalImagesCount", comment: "%@ photos"), nberPhotos) :
                String(format: NSLocalizedString("singleImageCount", comment: "%@ photo"), nberPhotos)
            tagLabel.text = "\(tag.tagName) (\(nberImages))"
        }
    }
    
    override func prepareForReuse() {
        tagLabel.text = ""
    }
}

