//
//  UIFont+AppFonts.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 22/02/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import UIKit

@objc
extension UIFont {

    class func piwigoFontLight() -> UIFont {
        return UIFont(name: "OpenSans-Light", size: 17.0) ?? UIFont.systemFont(ofSize: 17.0)
    }

    class func piwigoFontNormal() -> UIFont {
        return UIFont(name: "OpenSans", size: 17.0) ?? UIFont.systemFont(ofSize: 17.0)
    }

    class func piwigoFontSemiBold() -> UIFont {
        return UIFont(name: "OpenSans-Semibold", size: 17.0) ?? UIFont.boldSystemFont(ofSize: 17.0)
    }

    class func piwigoFontBold() -> UIFont {
        return UIFont(name: "OpenSans-Bold", size: 17.0) ?? UIFont.boldSystemFont(ofSize: 17.0)
    }

    class func piwigoFontExtraBold() -> UIFont {
        return UIFont(name: "OpenSans-Extrabold", size: 17.0) ?? UIFont.boldSystemFont(ofSize: 17.0)
    }

    class func piwigoFontSmall() -> UIFont {
        return UIFont(name: "OpenSans", size: 13.0) ?? UIFont.systemFont(ofSize: 13.0)
    }

    class func piwigoFontSmallLight() -> UIFont {
        return UIFont(name: "OpenSans-Light", size: 13.0) ?? UIFont.systemFont(ofSize: 13.0)
    }

    class func piwigoFontSmallSemiBold() -> UIFont {
        return UIFont(name: "OpenSans-Semibold", size: 13.0) ?? UIFont.boldSystemFont(ofSize: 13.0)
    }

    class func piwigoFontTiny() -> UIFont {
        return UIFont(name: "OpenSans", size: 10.0) ?? UIFont.systemFont(ofSize: 10.0)
    }

    class func piwigoFontLarge() -> UIFont {
        return UIFont(name: "OpenSans", size: 28.0) ?? UIFont.systemFont(ofSize: 28.0)
    }

    class func piwigoFontLargeTitle() -> UIFont {
        return UIFont(name: "OpenSans-Extrabold", size: 28.0) ?? UIFont.boldSystemFont(ofSize: 28.0)
    }

    class func piwigoFontButton() -> UIFont {
        return UIFont(name: "OpenSans", size: 21.0) ?? UIFont.systemFont(ofSize: 21.0)
    }

    class func fontSizeFor(label: UILabel?, nberLines: Int) -> CGFloat {
        
        if label?.adjustsFontSizeToFitWidth == false || (label?.minimumScaleFactor ?? 1.0) >= 1.0 {
            // font adjustment is disabled
            return label?.font.pointSize ?? 17.0
        }

        var unadjustedSize: CGSize? = nil
        if let font = label?.font {
            unadjustedSize = label?.text?.size(withAttributes: [
            NSAttributedString.Key.font: font
        ])
        }
        var scaleFactor:CGFloat = (label?.frame.size.width ?? 0.0) / ((unadjustedSize?.width ?? 1.0) / CGFloat(nberLines))

        if scaleFactor >= 1.0 {
            // the text already fits at full font size
            return label?.font.pointSize ?? 17.0
        }

        // Respect minimumScaleFactor
        scaleFactor = fmax(scaleFactor, label?.minimumScaleFactor ?? 0.4)
        let newFontSize = (label?.font.pointSize ?? 0.0) * scaleFactor

        // Uncomment this if you insist on integer font sizes
        //newFontSize = floor(newFontSize);

        return newFontSize
    }
}

// Code for determining font name, e.g. LacunaRegular, OpenSans

//for familyName in UIFont.familyNames {
//    print("Family \(familyName)")
//    print("Names = \(UIFont.fontNames(forFamilyName: familyName))")
//}
