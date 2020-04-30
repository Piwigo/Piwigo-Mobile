//
//  LocalImagesFooterReusableView.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 19/04/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import UIKit

class LocalImagesFooterReusableView: UICollectionReusableView {

    @IBOutlet weak var nberOfImagesLabel: UILabel!
    
    func configure(with nberOfImages: Int) -> Void {
        
        // Appearance
        nberOfImagesLabel.textColor = UIColor.piwigoColorHeader()
        nberOfImagesLabel.font = UIFont.piwigoFontLight()
        
        // Number of images
        if nberOfImages == 0 {
            // Display "No images"
            nberOfImagesLabel.text = NSLocalizedString("noImages", comment: "No Images")
        } else {
            // Display number of images…
            nberOfImagesLabel.text = String(format: "%ld %@", nberOfImages,
                                            (nberOfImages > 1 ? NSLocalizedString("categoryTableView_photosCount", comment: "photos") :                 NSLocalizedString("categoryTableView_photoCount", comment: "photo")))
        }
    }
}
