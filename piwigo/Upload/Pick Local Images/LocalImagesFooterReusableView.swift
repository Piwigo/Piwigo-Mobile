//
//  LocalImagesFooterReusableView.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 19/04/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import UIKit
import PwgKit
import PwgAPIKit
import PwgUIKit

class LocalImagesFooterReusableView: UICollectionReusableView {

    @IBOutlet weak var nberOfImagesLabel: UILabel!
    
    func configure(with nberOfImages: Int) -> Void {
        
        // Appearance
        nberOfImagesLabel.textColor = PwgColor.header
        nberOfImagesLabel.font = .systemFont(ofSize: 17, weight: .light)
        
        // Number of images
        if nberOfImages == 0 {
            // Display "No images"
            nberOfImagesLabel.text = String(localized: "noImages", comment: "No Images")
        } else {
            // Display number of images…
            nberOfImagesLabel.text = Localized.imageCount(Int(nberOfImages))
        }
    }
}
