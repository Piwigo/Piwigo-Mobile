//
//  UploadQueueHeaderView.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 09/08/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import Foundation

class UploadQueueHeaderView: UIView {

    let label = UILabel(frame: .zero)

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = UIColor.piwigoColorOrange()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 1
        label.font = UIFont.piwigoFontSemiBold()
        label.baselineAdjustment = .alignCenters

        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor, constant: 0.0),
            label.topAnchor.constraint(equalTo: topAnchor),
            label.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])
    }

    func configure(text: String) {
        label.text = text
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
