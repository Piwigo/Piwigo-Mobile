//
//  UIColor+AppColors.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 23/02/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import UIKit

@objc
extension UIColor {

    // MARK: - Text Color
    class func piwigoColorText() -> UIColor {
        if AppVars.isDarkPaletteActive {
            return UIColor.lightText
        } else {
            return UIColor.darkText
        }
    }

    // Background Color of Views
    class func piwigoColorBackground() -> UIColor {
        if AppVars.isDarkPaletteActive {
            return UIColor(red: 23 / 255.0, green: 23 / 255.0, blue: 23 / 255.0, alpha: 1.0)
        } else {
            return UIColor(red: 239 / 255.0, green: 239 / 255.0, blue: 244 / 255.0, alpha: 1.0)
        }
    }

    // Shadow Color of Buttons
    class func piwigoColorShadow() -> UIColor {
        if AppVars.isDarkPaletteActive {
            return UIColor.white
        } else {
            return UIColor.black
        }
    }

    // MARK: - Piwigo Logo Colors
    class func piwigoColorBrown() -> UIColor {
        return UIColor(red: 78 / 255.0, green: 78 / 255.0, blue: 78 / 255.0, alpha: 1.0)
    }

    class func piwigoColorOrange() -> UIColor {
        return UIColor(red: 255 / 255.0, green: 119 / 255.0, blue: 1 / 255.0, alpha: 1.0)
    }

    class func piwigoColorOrangeLight() -> UIColor {
        return UIColor(red: 251 / 255.0, green: 97 / 255.0, blue: 11 / 255.0, alpha: 1.0)
    }

    class func piwigoColorOrangeSelected() -> UIColor {
        return UIColor(red: 198 / 255.0, green: 92 / 255.0, blue: 0 / 255.0, alpha: 1.0)
    }


    // MARK: - Color of Table Views
    class func piwigoColorHeader() -> UIColor {
        if AppVars.isDarkPaletteActive {
            return UIColor(red: 200 / 255.0, green: 200 / 255.0, blue: 200 / 255.0, alpha: 1.0)
        } else if #available(iOS 10, *) {
            return UIColor(red: 28 / 255.0, green: 28 / 255.0, blue: 30 / 255.0, alpha: 1.0)
        } else {
            return UIColor(red: 46 / 255.0, green: 46 / 255.0, blue: 46 / 255.0, alpha: 1.0)
        }
    }

    class func piwigoColorSeparator() -> UIColor {
        if AppVars.isDarkPaletteActive {
            return UIColor(red: 62 / 255.0, green: 62 / 255.0, blue: 65 / 255.0, alpha: 1.0)
        } else {
            return UIColor(red: 198 / 255.0, green: 197 / 255.0, blue: 202 / 255.0, alpha: 1.0)
        }
    }

    class func piwigoColorCellBackground() -> UIColor {
        if AppVars.isDarkPaletteActive {
            return UIColor(red: 42 / 255.0, green: 42 / 255.0, blue: 45 / 255.0, alpha: 1.0)
        } else {
            return UIColor(red: 255 / 255.0, green: 255 / 255.0, blue: 255 / 255.0, alpha: 1.0)
        }
    }

    class func piwigoColorLeftLabel() -> UIColor {
        if AppVars.isDarkPaletteActive {
            return UIColor(red: 200 / 255.0, green: 200 / 255.0, blue: 200 / 255.0, alpha: 1)
        } else {
            return UIColor.darkText
        }
    }

    class func piwigoColorRightLabel() -> UIColor {
        if AppVars.isDarkPaletteActive {
            return UIColor(red: 128 / 255.0, green: 128 / 255.0, blue: 128 / 255.0, alpha: 1.0)
        } else {
            return UIColor(red: 128 / 255.0, green: 128 / 255.0, blue: 128 / 255.0, alpha: 1.0)
        }
    }

    class func piwigoColorPlaceHolder() -> UIColor {
        if AppVars.isDarkPaletteActive {
            return UIColor(red: 80 / 255.0, green: 80 / 255.0, blue: 80 / 255.0, alpha: 1.0)
        } else {
            return UIColor(red: 195 / 255.0, green: 195 / 255.0, blue: 195 / 255.0, alpha: 1.0)
        }
    }

    class func piwigoColorThumb() -> UIColor {
        if AppVars.isDarkPaletteActive {
            return UIColor(red: 200 / 255.0, green: 200 / 255.0, blue: 200 / 255.0, alpha: 1)
        } else {
            return UIColor(red: 239 / 255.0, green: 239 / 255.0, blue: 244 / 255.0, alpha: 1.0)
        }
    }

    // MARK: - Color of lines under fields
    class func piwigoColorUnderline() -> UIColor {
        if AppVars.isDarkPaletteActive {
            return UIColor(red: 51 / 255.0, green: 51 / 255.0, blue: 53 / 255.0, alpha: 1.0)
        } else {
            return UIColor(red: 239 / 255.0, green: 239 / 255.0, blue: 244 / 255.0, alpha: 1.0)
        }
    }

    // MARK: - Old colors
    class func piwigoColorGray() -> UIColor {
        if AppVars.isDarkPaletteActive {
            return UIColor(red: 23 / 255.0, green: 23 / 255.0, blue: 23 / 255.0, alpha: 1.0)
        } else {
            return UIColor(red: 23 / 255.0, green: 23 / 255.0, blue: 23 / 255.0, alpha: 1.0)
        }
    }

    class func piwigoColorWhiteCream() -> UIColor {
        if AppVars.isDarkPaletteActive {
            return UIColor(red: 200 / 255.0, green: 200 / 255.0, blue: 200 / 255.0, alpha: 1)
        } else {
            return UIColor(red: 51 / 255.0, green: 51 / 255.0, blue: 53 / 255.0, alpha: 1.0)
        }
    }
}
