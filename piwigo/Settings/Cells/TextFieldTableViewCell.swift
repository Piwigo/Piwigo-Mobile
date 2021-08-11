//
//  ServerTableViewCell.h
//  piwigo
//
//  Created by Spencer Baker on 2/2/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//
//  Converted to Swift 5 by Eddy Lelièvre-Berna on 12/04/2020.
//

import UIKit

class TextFieldTableViewCell: UITableViewCell {


    @IBOutlet weak var leftLabel: UILabel!
    @IBOutlet weak var rightTextField: UITextField!
    
    func configure(with name:String, input:String, placeHolder:String) {

        // Background color and aspect
        backgroundColor = UIColor.piwigoColorCellBackground()

        // Text field name
        leftLabel.font = UIFont.piwigoFontNormal()
        leftLabel.textColor = UIColor.piwigoColorLeftLabel()
        leftLabel.text = name

        // Text field
        rightTextField.font = UIFont.piwigoFontNormal()
        rightTextField.textColor = UIColor.piwigoColorRightLabel()
        rightTextField.text = input
        rightTextField.keyboardAppearance = AppVars.isDarkPaletteActive ? .dark : .default
        rightTextField.attributedPlaceholder = NSAttributedString(string: placeHolder, attributes: [
            NSAttributedString.Key.foregroundColor: UIColor.piwigoColorPlaceHolder()
        ])
        if AppVars.isAppLanguageRTL {
            rightTextField.textAlignment = .left
        } else {
            rightTextField.textAlignment = .right
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        leftLabel.text = ""
        rightTextField.text = ""
        rightTextField.tag = -1
        rightTextField.delegate = nil
    }
}
