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
    var commentLabel: UILabel?

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = UIColor.clear
        
        commentLabel = UILabel()
        commentLabel?.backgroundColor = UIColor.clear
        commentLabel?.translatesAutoresizingMaskIntoConstraints = false
        commentLabel?.numberOfLines = 0
        commentLabel?.adjustsFontSizeToFitWidth = false
        commentLabel?.lineBreakMode = .byWordWrapping
        commentLabel?.textAlignment = .center
        commentLabel?.font = .systemFont(ofSize: 17)
        commentLabel?.attributedText = NSAttributedString()

        if let commentLabel = commentLabel {
            addSubview(commentLabel)
            addConstraint(NSLayoutConstraint.constraintView(fromTop: commentLabel, amount: 4)!)
            addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|-[header]-|",
                    options: [], metrics: nil, views: ["header": commentLabel
            ]))
        }
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        commentLabel?.attributedText = NSAttributedString()
    }
}
