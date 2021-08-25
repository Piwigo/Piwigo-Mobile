//
//  SelectCategoryHeaderView.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 25/03/2021.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import Foundation

class SelectCategoryHeaderView: UIView {

    private let label = UILabel(frame: .zero)
    private let margin: CGFloat = 32.0

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = UIColor.clear
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.font = UIFont.piwigoFontSmall()
        label.baselineAdjustment = .alignCenters
        label.lineBreakMode = .byWordWrapping
        label.textAlignment = .center

        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: margin),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -margin),
            label.bottomAnchor.constraint(equalTo: bottomAnchor),
            label.topAnchor.constraint(equalTo: topAnchor)
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
        label.textColor = UIColor.piwigoColorLeftLabel()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
