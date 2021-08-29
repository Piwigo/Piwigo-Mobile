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

@objc
class EditImageTextFieldTableViewCell: UITableViewCell {
    
    @IBOutlet weak var cellTextField: UITextField!
    @IBOutlet private weak var cellLabel: UILabel!

    @objc
    func config(withLabel label: String?, placeHolder: String?,
               andImageDetail imageDetail: String?) {
        // Cell background
        backgroundColor = UIColor.piwigoColorBackground()

        // Cell label
        cellLabel.text = label
        cellLabel.textColor = UIColor.piwigoColorLeftLabel()

        // Cell text field
        if let detail = imageDetail {
            cellTextField.text = detail
        } else {
            cellTextField.text = ""
        }
        cellTextField.textColor = UIColor.piwigoColorRightLabel()
        if (placeHolder?.count ?? 0) > 0 {
            cellTextField.attributedPlaceholder = NSAttributedString(string: placeHolder ?? "", attributes: [
                NSAttributedString.Key.foregroundColor: UIColor.piwigoColorPlaceHolder()
            ])
        }
        cellTextField.keyboardAppearance = AppVars.isDarkPaletteActive ? .dark : .default
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        cellTextField.delegate = nil
        cellTextField.text = ""
    }
}
