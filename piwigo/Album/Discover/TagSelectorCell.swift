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
        backgroundColor = UIColor.piwigoColorCellBackground()
        tintColor = UIColor.piwigoColorOrange()
        tagLabel.font = UIFont.piwigoFontNormal()
        tagLabel.textColor = UIColor.piwigoColorLeftLabel()

        // => pwg.tags.getList returns in addition: counter, url
        let nber = tag.numberOfImagesUnderTag
        if (nber == 0) || (nber == Int64.max) {
            // Unknown number of images
            tagLabel.text = tag.tagName
        } else if nber > 1 {
            // Known number of images
            tagLabel.text = String(format: "%@ (%lld %@)", tag.tagName, nber,  NSLocalizedString("categoryTableView_photosCount", comment: "photos"))
        } else {
            tagLabel.text = String(format: "%@ (%lld %@)", tag.tagName, nber, NSLocalizedString("categoryTableView_photoCount", comment: "photo"))
        }
    }
    
    override func prepareForReuse() {
        tagLabel.text = ""
    }
}

