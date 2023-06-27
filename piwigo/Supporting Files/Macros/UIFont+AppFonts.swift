//
//  UIFont+AppFonts.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 22/02/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import UIKit

extension UIFont {

//    class func piwigoFontLight() -> UIFont {
//        return UIFont(name: "OpenSans-Light", size: 17.0) ?? UIFont.systemFont(ofSize: 17.0)
//    }
//
//    class func piwigoFontNormal() -> UIFont {
//        return UIFont(name: "OpenSans", size: 17.0) ?? UIFont.systemFont(ofSize: 17.0)
//    }
//
//    class func piwigoFontSemiBold() -> UIFont {
//        return UIFont(name: "OpenSans-Semibold", size: 17.0) ?? UIFont.boldSystemFont(ofSize: 17.0)
//    }
//
//    class func piwigoFontBold() -> UIFont {
//        return UIFont(name: "OpenSans-Bold", size: 17.0) ?? UIFont.boldSystemFont(ofSize: 17.0)
//    }
//
//    class func piwigoFontExtraBold() -> UIFont {
//        return UIFont(name: "OpenSans-Extrabold", size: 17.0) ?? UIFont.boldSystemFont(ofSize: 17.0)
//    }
//
//    class func piwigoFontSmall() -> UIFont {
//        return UIFont(name: "OpenSans", size: 13.0) ?? UIFont.systemFont(ofSize: 13.0)
//    }
//
//    class func piwigoFontSmallLight() -> UIFont {
//        return UIFont(name: "OpenSans-Light", size: 13.0) ?? UIFont.systemFont(ofSize: 13.0)
//    }
//
//    class func piwigoFontSmallSemiBold() -> UIFont {
//        return UIFont(name: "OpenSans-Semibold", size: 13.0) ?? UIFont.boldSystemFont(ofSize: 13.0)
//    }
//
//    class func piwigoFontTiny() -> UIFont {
//        return UIFont(name: "OpenSans", size: 10.0) ?? UIFont.systemFont(ofSize: 10.0)
//    }
//
//    class func piwigoFontLarge() -> UIFont {
//        return UIFont(name: "OpenSans", size: 28.0) ?? UIFont.systemFont(ofSize: 28.0)
//    }
//
//    class func piwigoFontLargeTitle() -> UIFont {
//        return UIFont(name: "OpenSans-Extrabold", size: 28.0) ?? UIFont.boldSystemFont(ofSize: 28.0)
//    }
//
//    class func piwigoFontButton() -> UIFont {
//        return UIFont(name: "OpenSans", size: 21.0) ?? UIFont.systemFont(ofSize: 21.0)
//    }

    class func fontSizeFor(label: UILabel?, nberLines: Int) -> CGFloat {
        // Check label is not nil
        guard let label = label, let font = label.font else { return 17.0 }
        
        // Check that we can adjust the font
        if (label.adjustsFontSizeToFitWidth == false) ||
            (label.minimumScaleFactor >= 1.0) {
            // Font adjustment is disabled
            return font.pointSize
        }

        // Should we scale the font?
        var unadjustedWidth: CGFloat = 1.0
        if let text = label.text {
            unadjustedWidth = text.size(withAttributes: [NSAttributedString.Key.font: font]).width
        }
        let width: CGFloat = label.frame.size.width
        let height: CGFloat = unadjustedWidth / CGFloat(nberLines)
        var scaleFactor: CGFloat = width / height
        if scaleFactor >= 1.0 {
            // The text already fits at full font size
            return font.pointSize
        }

        // Respect minimumScaleFactor
        scaleFactor = fmax(scaleFactor, label.minimumScaleFactor)
        let newFontSize: CGFloat = font.pointSize * scaleFactor

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
