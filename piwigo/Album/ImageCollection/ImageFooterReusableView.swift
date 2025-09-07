//
//  ImageFooterReusableView.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 02/04/2018.
//  Copyright © 2018 Piwigo.org. All rights reserved.
//
//  Converted to Swift 5.1 by Eddy Lelièvre-Berna on 14/04/2020
//

import UIKit

class ImageFooterReusableView: UICollectionReusableView {
    var nberImagesLabel: UILabel?

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.backgroundColor = UIColor.clear        
        nberImagesLabel = UILabel()
        nberImagesLabel?.backgroundColor = UIColor.clear
        nberImagesLabel?.translatesAutoresizingMaskIntoConstraints = false
        nberImagesLabel?.numberOfLines = 0
        nberImagesLabel?.adjustsFontSizeToFitWidth = false
        nberImagesLabel?.lineBreakMode = .byWordWrapping
        nberImagesLabel?.textAlignment = .center
        nberImagesLabel?.font = .preferredFont(forTextStyle: .footnote)
        nberImagesLabel?.adjustsFontForContentSizeCategory = true
        nberImagesLabel?.text = NSLocalizedString("categoryMainEmtpy", comment: "No albums in your Piwigo yet.\rYou may pull down to refresh or re-login.")

        if let nberImagesLabel = nberImagesLabel {
            addSubview(nberImagesLabel)
            addConstraint(NSLayoutConstraint.constraintCenterHorizontalView(nberImagesLabel)!)
            addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|-16-[header]-16-|",
                    options: [], metrics: nil, views: ["header": nberImagesLabel
            ]))
        }
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        nberImagesLabel?.text = NSLocalizedString("categoryMainEmtpy", comment: "No albums in your Piwigo yet.\rYou may pull down to refresh or re-login.")
    }
}
