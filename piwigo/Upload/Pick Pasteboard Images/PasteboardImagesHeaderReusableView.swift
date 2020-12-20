//
//  PasteboardImagesHeaderReusableView.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 06/12/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import UIKit

@objc
class PasteboardImagesHeaderReusableView: UICollectionReusableView {
    
    // MARK: - View
    
    @IBOutlet weak var headerLabel: UILabel!

    @objc
    func configure() {
        
        // General settings
        backgroundColor = UIColor.piwigoColorBackground().withAlphaComponent(0.75)

        // Data label used when place name known
        headerLabel.textColor = UIColor.piwigoColorHeader()
        headerLabel.text = NSLocalizedString("imageUploadPasteboard", comment: "Clipboard")
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        headerLabel.text = ""
    }
}
