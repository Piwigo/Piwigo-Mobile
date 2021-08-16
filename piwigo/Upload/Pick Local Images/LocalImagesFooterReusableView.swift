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
            let numberFormatter = NumberFormatter()
            numberFormatter.numberStyle = .decimal
            let nberPhotos = (numberFormatter.string(from: NSNumber(value: nberOfImages)) ?? "0") as String
            nberOfImagesLabel.text = nberOfImages > 1 ?
                String(format: NSLocalizedString("severalImagesCount", comment: "%@ photos"), nberPhotos) :
                String(format: NSLocalizedString("singleImageCount", comment: "%@ photo"), nberPhotos)
        }
    }
}
