//
//  CategoryHeaderReusableView.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 24/06/2018.
//  Copyright © 2018 Piwigo.org. All rights reserved.
//
//  Converted to Swift 5.1 by Eddy Lelièvre-Berna on 14/04/2020
//

import UIKit

class CategoryHeaderReusableView: UICollectionReusableView {
    @objc var commentLabel: UILabel?

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
        commentLabel?.font = .piwigoFontNormal()
        commentLabel?.text = ""

        if let commentLabel = commentLabel {
            addSubview(commentLabel)
        }
        addConstraint(NSLayoutConstraint.constraintView(fromTop: commentLabel, amount: 4)!)
        if #available(iOS 11, *) {
            if let commentLabel = commentLabel {
                addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|-[header]-|", options: [], metrics: nil, views: [
                "header": commentLabel
                ]))
            }
        } else {
            if let commentLabel = commentLabel {
                addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|-15-[header]-15-|", options: [], metrics: nil, views: [
                "header": commentLabel
                ]))
            }
        }
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}
