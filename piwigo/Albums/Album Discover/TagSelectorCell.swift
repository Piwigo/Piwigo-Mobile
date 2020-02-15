//
//  TagSelectorCell.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 09/02/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import UIKit
 
class TagSelectorCell: UITableViewCell {
    
    @IBOutlet weak private var tagLabel: UILabel!
    
    // Configures the cell with a tag instance
    func configure(with tag: Tag) {
        
        // General settings
        backgroundColor = UIColor.piwigoCellBackground()
        tintColor = UIColor.piwigoOrange()
        tagLabel.font = UIFont.piwigoFontNormal()
        tagLabel.textColor = UIColor.piwigoLeftLabel()

        // => pwg.tags.getList returns in addition: counter, url
        let nber = tag.numberOfImagesUnderTag
        if (nber == 0) || (nber == Int.max) {
            // Unknown number of images
            tagLabel.text = tag.tagName
        } else {
            // Known number of images
            tagLabel.text = String(format: "%@ (%ld %@)", tag.tagName, nber, nber > 1 ? NSLocalizedString("categoryTableView_photosCount", comment: "photos") : NSLocalizedString("categoryTableView_photoCount", comment: "photo"))
        }
    }
    
    override func prepareForReuse() {
        tagLabel.text = ""
    }
}

