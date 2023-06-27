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
        backgroundColor = .piwigoColorCellBackground()

        // Text field name
        leftLabel.font = .systemFont(ofSize: 17)
        leftLabel.textColor = .piwigoColorLeftLabel()
        leftLabel.text = name

        // Text field
        rightTextField.font = .systemFont(ofSize: 17)
        rightTextField.textColor = .piwigoColorRightLabel()
        rightTextField.text = input
        rightTextField.keyboardAppearance = AppVars.shared.isDarkPaletteActive ? .dark : .default
        rightTextField.attributedPlaceholder = NSAttributedString(string: placeHolder, attributes: [
            NSAttributedString.Key.foregroundColor: UIColor.piwigoColorPlaceHolder()
        ])
        if AppVars.shared.isAppLanguageRTL {
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
