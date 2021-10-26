//
//  UploadQueueHeaderView.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 09/08/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import Foundation

class UploadQueueHeaderView: UIView {

    private let label = UILabel(frame: .zero)
    private let margin: CGFloat = 32.0

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .piwigoColorOrange()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.font = .piwigoFontSemiBold()
        label.baselineAdjustment = .alignCenters
        label.lineBreakMode = .byWordWrapping
        label.textAlignment = .center

        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: margin),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -margin),
            label.topAnchor.constraint(equalTo: topAnchor),
            label.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])
    }

    func configure(width: CGFloat, text: String) {
        let context = NSStringDrawingContext()
        context.minimumScaleFactor = 1.0
        let titleAttributes = [NSAttributedString.Key.font: UIFont.piwigoFontSmall()]
        var titleRect = text.boundingRect(with: CGSize(width: width - 2 * margin,
                                                       height: CGFloat.greatestFiniteMagnitude),
                                          options: .usesLineFragmentOrigin,
                                          attributes: titleAttributes, context: context)
        titleRect.size.height += 16
        self.frame = titleRect
        label.text = text
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
