//
//  TextViewTableViewCell.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 22 September 2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import UIKit

class TextViewTableViewCell: UITableViewCell {
    
    @IBOutlet private weak var label: UILabel!
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var textViewHeight: NSLayoutConstraint!
    
    override func awakeFromNib() {
        // Initialization code
        super.awakeFromNib()

        label.text = NSLocalizedString("editImageDetails_description", comment: "Description")
        textView.layer.cornerRadius = 8.0
    }

    func config(withText description: String?, inColor color: UIColor?) {
        // Cell background
        backgroundColor = PwgColor.background

        // Cell label
        label.textColor = PwgColor.leftLabel

        // Cell text view
        textView.text = description
        textView.textColor = color
        textView.backgroundColor = PwgColor.background
        textView.keyboardAppearance = AppVars.shared.isDarkPaletteActive ? .dark : .default
        textViewHeight.constant = UIFont.preferredFont(forTextStyle: .body).lineHeight * 23.0
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        textView.delegate = nil
        textView.text = ""
    }
}
