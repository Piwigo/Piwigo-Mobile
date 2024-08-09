//
//  PasteboardImagesHeaderReusableView.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 06/12/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import UIKit

@objc protocol PasteboardImagesHeaderDelegate: NSObjectProtocol {
    func didSelectImagesOfSection()
}

class PasteboardImagesHeaderReusableView: UICollectionReusableView {
    
    // MARK: - View
    @objc weak var headerDelegate: PasteboardImagesHeaderDelegate?

    @IBOutlet weak var headerLabel: UILabel!
    @IBOutlet weak var selectButton: UIButton!
    
    func configure(with selectState: SelectButtonState) {
        
        // General settings
        backgroundColor = .piwigoColorBackground().withAlphaComponent(0.75)

        // Data label used when place name known
        headerLabel.textColor = .piwigoColorHeader()
        headerLabel.text = NSLocalizedString("categoryUpload_pasteboard", comment: "Clipboard")

        // Select/deselect button
        selectButton.layer.cornerRadius = 13.0
        selectButton.setTitle(forState: selectState)
    }

    @IBAction func tappedSelectButton(_ sender: Any) {
        // Select/deselect images
        headerDelegate?.didSelectImagesOfSection()
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        headerLabel.text = ""
        selectButton.setTitle("", for: .normal)
        selectButton.backgroundColor = .piwigoColorBackground()
    }
}
