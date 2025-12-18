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
import piwigoKit

class AlbumHeaderReusableView: UICollectionReusableView {

    @IBOutlet weak var albumDesc: UITextView!
    @IBOutlet weak var albumDescHeight: NSLayoutConstraint!

    @MainActor
    func config(withDescription description: NSAttributedString = NSAttributedString(), size: CGSize = CGSize.zero)
    {
        // Set album description label
        albumDesc.contentSize = size
        albumDesc.textContainerInset = .zero
        albumDesc.textContainer.widthTracksTextView = false
        albumDesc.textContainer.lineBreakMode = .byWordWrapping
        if size == CGSize.zero {
            albumDesc.text = ""
            albumDescHeight.constant = 0
        } else {
            albumDescHeight.constant = size.height
        }
        
        // Set colors
        applyColorPalette(withDescription: description)
    }
    
    func applyColorPalette(withDescription description: NSAttributedString) {
        if #available(iOS 26.0, *) {
            backgroundColor = .clear
        } else {
            backgroundColor = PwgColor.background.withAlphaComponent(0.75)
        }
        albumDesc.attributedText = description.adaptingTextColorPreservingHue(to: PwgColor.background, defaultColor: PwgColor.header)
        albumDesc.linkTextAttributes = [NSAttributedString.Key.foregroundColor: PwgColor.orange]
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        
        albumDesc?.attributedText = NSAttributedString()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
