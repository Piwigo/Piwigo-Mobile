//
//  AlbumHeaderReusableView.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 24/06/2018.
//  Copyright © 2018 Piwigo.org. All rights reserved.
//
//  Converted to Swift 5.1 by Eddy Lelièvre-Berna on 14/04/2020
//

import UIKit

class AlbumHeaderReusableView: UICollectionReusableView {

    @IBOutlet weak var albumDesc: UITextView!
    @IBOutlet weak var albumDescHeight: NSLayoutConstraint!

    @MainActor
    func config(withDescription description: NSAttributedString = NSAttributedString(), size: CGSize = CGSize.zero)
    {
        // Set colors
        applyColorPalette()

        // Set album description label
        albumDesc.contentSize = size
        albumDesc.textContainerInset = .zero
        albumDesc.textContainer.widthTracksTextView = false
        albumDesc.textContainer.lineBreakMode = .byWordWrapping
        if size == CGSize.zero {
            albumDesc.text = ""
            albumDescHeight.constant = 0
        } else {
            albumDesc.attributedText = description
            albumDescHeight.constant = size.height
        }
    }
    
    func applyColorPalette() {
        backgroundColor = .piwigoColorBackground().withAlphaComponent(0.75)
        albumDesc.textColor = .piwigoColorHeader()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        
        albumDesc?.attributedText = NSAttributedString()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
