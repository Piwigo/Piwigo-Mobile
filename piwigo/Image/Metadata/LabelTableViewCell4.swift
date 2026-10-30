//
//  LabelTableViewCell4.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 30/10/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//
//  Cell of the metadata table with a title and two details under it, one above the other:
//  the camera, its lens and the size of the image, or the title of a PDF, its author and its size.
//

import UIKit
import PwgUIKit

final class LabelTableViewCell4: LabelTableViewCell
{
    static let reuseIdentifier = "LabelTableViewCell4"

    @IBOutlet weak var bottomDetailLabel: UILabel!

    func configure(with title: String, detail: String, bottomDetail: String, showsFlash: Bool = false) {
        super.configure(with: title, detail: detail)

        // Both details are under the title, whatever the size of the text
        detailLabel.textAlignment = .natural
        bottomDetailLabel.textColor = PwgColor.rightLabel
        bottomDetailLabel.isHidden = bottomDetail.isEmpty
        if showsFlash {
            /// The bolt follows the text, which tells that the flash fired
            let font = UIFont.preferredFont(forTextStyle: .body)
            let color = PwgColor.rightLabel
            let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
            let text = NSMutableAttributedString(string: bottomDetail + " • ", attributes: attributes)
            let attachment = NSTextAttachment()
            attachment.image = UIImage(systemName: "bolt.circle", withConfiguration: UIImage.SymbolConfiguration(font: font))?
                .withTintColor(color, renderingMode: .alwaysOriginal)
            text.append(NSAttributedString(attachment: attachment))
            bottomDetailLabel.attributedText = text
        } else {
            bottomDetailLabel.attributedText = nil
            bottomDetailLabel.text = bottomDetail
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        bottomDetailLabel.attributedText = nil
        bottomDetailLabel.text = ""
    }
}
