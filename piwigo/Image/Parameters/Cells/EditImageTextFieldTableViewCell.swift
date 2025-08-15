//
//  EditImageTextFieldTableViewCell.swift
//  piwigo
//
//  Created by Spencer Baker on 2/8/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//
//  Converted to Swift 5.3 by Eddy Lelièvre-Berna on 29/08/2021.
//

import UIKit

class EditImageTextFieldTableViewCell: UITableViewCell {
    
    @IBOutlet weak var cellTextField: UITextField!
    @IBOutlet private weak var cellLabel: UILabel!

    func config(withLabel label: NSAttributedString?, placeHolder: String?,
                andImageDetail imageDetail: NSAttributedString?) {
        // Cell background
        backgroundColor = PwgColor.background

        // Cell label
        cellLabel.attributedText = label
        cellLabel.textColor = PwgColor.leftLabel

        // Cell text field
        if let detail = imageDetail {
            cellTextField.attributedText = detail
        } else {
            cellTextField.text = ""
        }
        cellTextField.textColor = PwgColor.rightLabel
        if (placeHolder?.count ?? 0) > 0 {
            cellTextField.attributedPlaceholder = NSAttributedString(string: placeHolder ?? "", attributes: [
                NSAttributedString.Key.foregroundColor: PwgColor.placeHolder
            ])
        }
        cellTextField.keyboardAppearance = AppVars.shared.isDarkPaletteActive ? .dark : .default
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        cellTextField.delegate = nil
        cellTextField.text = ""
    }
}
