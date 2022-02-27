//
//  PiwigoButton.swift
//  piwigo
//
//  Created by Spencer Baker on 1/17/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//
//  Converted to Swift 5.4 by Eddy Lelièvre-Berna on 26/02/2022.
//

import UIKit

class PiwigoButton: UIButton {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 10.0
        titleLabel?.font = UIFont.piwigoFontButton()
        setTitleColor(UIColor.white, for: .normal)
    }

    override var isHighlighted: Bool {
        get {
            return super.isHighlighted
        }
        set(highlighted) {
            super.isHighlighted = highlighted

            if AppVars.shared.isDarkPaletteActive {
                if highlighted {
                    backgroundColor = UIColor.piwigoColorOrange()
                } else {
                    backgroundColor = UIColor.piwigoColorOrangeSelected()
                }
            } else {
                if highlighted {
                    backgroundColor = UIColor.piwigoColorOrangeSelected()
                } else {
                    backgroundColor = UIColor.piwigoColorOrange()
                }
            }
        }
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}
