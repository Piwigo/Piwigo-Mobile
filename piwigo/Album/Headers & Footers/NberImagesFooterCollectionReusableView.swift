//
//  NberImagesFooterCollectionReusableView.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 02/04/2018.
//  Copyright © 2018 Piwigo.org. All rights reserved.
//
//  Converted to Swift 5.1 by Eddy Lelièvre-Berna on 14/04/2020
//

import UIKit

class NberImagesFooterCollectionReusableView: UICollectionReusableView {
    @objc var noImagesLabel: UILabel?

    override init(frame: CGRect) {
        super.init(frame: frame)
        noImagesLabel = UILabel()
        noImagesLabel?.backgroundColor = UIColor.clear
        noImagesLabel?.translatesAutoresizingMaskIntoConstraints = false
        noImagesLabel?.numberOfLines = 0
        noImagesLabel?.adjustsFontSizeToFitWidth = false
        noImagesLabel?.lineBreakMode = .byWordWrapping
        noImagesLabel?.textAlignment = .center
        noImagesLabel?.font = .piwigoFontLight()
        noImagesLabel?.text = NSLocalizedString("categoryMainEmtpy", comment: "No albums in your Piwigo yet.\rYou may pull down to refresh or re-login.")

        if let noImagesLabel = noImagesLabel {
            addSubview(noImagesLabel)
        }
        addConstraints(NSLayoutConstraint.constraintCenter(noImagesLabel)!)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}
