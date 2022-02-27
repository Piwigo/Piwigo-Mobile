//
//  PiwigoTextField.swift
//  piwigo
//
//  Created by Spencer Baker on 1/17/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//
//  Converted to Swift 5.4 by Eddy Lelièvre-Berna on 26/02/2022.
//

import UIKit

class PiwigoTextField: UITextField {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        layer.cornerRadius = 8.0
        font = UIFont.piwigoFontNormal()
        translatesAutoresizingMaskIntoConstraints = false
        clearButtonMode = UITextField.ViewMode.always
        autocapitalizationType = .none
        autocorrectionType = .no
        keyboardAppearance = AppVars.shared.isDarkPaletteActive ? .dark : .default
    }

    override func textRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.insetBy(dx: 10, dy: 0)
    }

    override func editingRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.insetBy(dx: 10, dy: 0)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}
