//
//  EditImageTextViewTableViewCell.swift
//  piwigo
//
//  Created by Spencer Baker on 2/8/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//
//  Converted to Swift 5.3 by Eddy Lelièvre-Berna on 29/08/2021.
//

import UIKit

class EditImageTextViewTableViewCell: UITableViewCell {
    
    @IBOutlet weak var textView: UITextView!
    @IBOutlet private weak var label: UILabel!

    override func awakeFromNib() {
        // Initialization code
        super.awakeFromNib()

        label.text = NSLocalizedString("editImageDetails_description", comment: "Description")
        textView.layer.cornerRadius = 5.0
    }

    func config(withText imageDetail: NSAttributedString?, inColor color: UIColor?) {
        // Cell background
        backgroundColor = .piwigoColorBackground()

        // Cell label
        label.textColor = .piwigoColorLeftLabel()

        // Cell text view
        textView.attributedText = imageDetail
        textView.textColor = color
        textView.backgroundColor = .piwigoColorBackground()
        textView.keyboardAppearance = AppVars.shared.isDarkPaletteActive ? .dark : .default
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        textView.delegate = nil
        textView.text = ""
    }
}
