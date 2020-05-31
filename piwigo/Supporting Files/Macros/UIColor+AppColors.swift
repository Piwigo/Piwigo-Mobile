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
    @objc
    class func piwigoColorText() -> UIColor {
        if Model.sharedInstance().isDarkPaletteActive {
            return UIColor.lightText
        } else {
            return UIColor.darkText
        }
    }

    // Background Color of Views
    @objc
    class func piwigoColorBackground() -> UIColor {
        if Model.sharedInstance().isDarkPaletteActive {
            return UIColor(red: 23 / 255.0, green: 23 / 255.0, blue: 23 / 255.0, alpha: 1.0)
        } else {
            return UIColor(red: 239 / 255.0, green: 239 / 255.0, blue: 244 / 255.0, alpha: 1.0)
        }
    }

    // MARK: - Piwigo Logo Colors
    @objc
    class func piwigoColorBrown() -> UIColor {
        return UIColor(red: 78 / 255.0, green: 78 / 255.0, blue: 78 / 255.0, alpha: 1.0)
    }

    @objc
    class func piwigoColorOrange() -> UIColor {
        return UIColor(red: 255 / 255.0, green: 119 / 255.0, blue: 1 / 255.0, alpha: 1.0)
    }

    @objc
    class func piwigoColorOrangeLight() -> UIColor {
        return UIColor(red: 251 / 255.0, green: 97 / 255.0, blue: 11 / 255.0, alpha: 1.0)
    }

    @objc
    class func piwigoColorOrangeSelected() -> UIColor {
        return UIColor(red: 198 / 255.0, green: 92 / 255.0, blue: 0 / 255.0, alpha: 1.0)
    }

    // MARK: - Colors of HUD Views
    @objc
    class func piwigoColorHudContent() -> UIColor {
        if Model.sharedInstance().isDarkPaletteActive {
            if #available(iOS 10, *) {
                return UIColor(red: 200 / 255.0, green: 200 / 255.0, blue: 200 / 255.0, alpha: 1)
            } else {
                return UIColor(red: 23 / 255.0, green: 23 / 255.0, blue: 23 / 255.0, alpha: 1.0)
            }
        } else if #available(iOS 10, *) {
            return UIColor(red: 239 / 255.0, green: 239 / 255.0, blue: 244 / 255.0, alpha: 1)
        } else {
            return UIColor(red: 23 / 255.0, green: 23 / 255.0, blue: 23 / 255.0, alpha: 1.0)
        }
    }

    @objc
    class func piwigoColorHudBezelView() -> UIColor {
        if Model.sharedInstance().isDarkPaletteActive {
            if #available(iOS 10, *) {
                return UIColor(white: 0.0, alpha: 1.0)
            } else {
                return UIColor(red: 28 / 255.0, green: 28 / 255.0, blue: 30 / 255.0, alpha: 1.0)
            }
        } else if #available(iOS 10, *) {
            return UIColor(white: 0.0, alpha: 1.0)
        } else {
            return UIColor(red: 28 / 255.0, green: 28 / 255.0, blue: 30 / 255.0, alpha: 1.0)
        }
    }

    // MARK: - Color of Table Views
    @objc
    class func piwigoColorHeader() -> UIColor {
        if Model.sharedInstance().isDarkPaletteActive {
            return UIColor(red: 200 / 255.0, green: 200 / 255.0, blue: 200 / 255.0, alpha: 1.0)
        } else if #available(iOS 10, *) {
            return UIColor(red: 28 / 255.0, green: 28 / 255.0, blue: 30 / 255.0, alpha: 1.0)
        } else {
            return UIColor(red: 46 / 255.0, green: 46 / 255.0, blue: 46 / 255.0, alpha: 1.0)
        }
    }

    @objc
    class func piwigoColorSeparator() -> UIColor {
        if Model.sharedInstance().isDarkPaletteActive {
            return UIColor(red: 97 / 255.0, green: 97 / 255.0, blue: 104 / 255.0, alpha: 1.0)
        } else {
            return UIColor(red: 128 / 255.0, green: 128 / 255.0, blue: 128 / 255.0, alpha: 1.0)
        }
    }

    @objc
    class func piwigoColorCellBackground() -> UIColor {
        if Model.sharedInstance().isDarkPaletteActive {
            return UIColor(red: 42 / 255.0, green: 42 / 255.0, blue: 45 / 255.0, alpha: 1.0)
        } else {
            return UIColor(red: 255 / 255.0, green: 255 / 255.0, blue: 255 / 255.0, alpha: 1.0)
        }
    }

    @objc
    class func piwigoColorLeftLabel() -> UIColor {
        if Model.sharedInstance().isDarkPaletteActive {
            return UIColor(red: 200 / 255.0, green: 200 / 255.0, blue: 200 / 255.0, alpha: 1)
        } else {
            return UIColor.darkText
        }
    }

    @objc
    class func piwigoColorRightLabel() -> UIColor {
        if Model.sharedInstance().isDarkPaletteActive {
            return UIColor(red: 128 / 255.0, green: 128 / 255.0, blue: 128 / 255.0, alpha: 1.0)
        } else {
            return UIColor(red: 128 / 255.0, green: 128 / 255.0, blue: 128 / 255.0, alpha: 1.0)
        }
    }

    @objc
    class func piwigoColorPlaceHolder() -> UIColor {
        if Model.sharedInstance().isDarkPaletteActive {
            return UIColor(red: 80 / 255.0, green: 80 / 255.0, blue: 80 / 255.0, alpha: 1.0)
        } else {
            return UIColor(red: 195 / 255.0, green: 195 / 255.0, blue: 195 / 255.0, alpha: 1.0)
        }
    }

    @objc
    class func piwigoColorThumb() -> UIColor {
        if Model.sharedInstance().isDarkPaletteActive {
            return UIColor(red: 200 / 255.0, green: 200 / 255.0, blue: 200 / 255.0, alpha: 1)
        } else {
            return UIColor(red: 239 / 255.0, green: 239 / 255.0, blue: 244 / 255.0, alpha: 1.0)
        }
    }

    // MARK: - Color of lines under fields
    @objc
    class func piwigoColorUnderline() -> UIColor {
        if Model.sharedInstance().isDarkPaletteActive {
            return UIColor(red: 51 / 255.0, green: 51 / 255.0, blue: 53 / 255.0, alpha: 1.0)
        } else {
            return UIColor(red: 239 / 255.0, green: 239 / 255.0, blue: 244 / 255.0, alpha: 1.0)
        }
    }

    // MARK: - Old colors
    @objc
    class func piwigoColorGray() -> UIColor {
        if Model.sharedInstance().isDarkPaletteActive {
            return UIColor(red: 23 / 255.0, green: 23 / 255.0, blue: 23 / 255.0, alpha: 1.0)
        } else {
            return UIColor(red: 23 / 255.0, green: 23 / 255.0, blue: 23 / 255.0, alpha: 1.0)
        }
    }

    @objc
    class func piwigoColorWhiteCream() -> UIColor {
        if Model.sharedInstance().isDarkPaletteActive {
            return UIColor(red: 200 / 255.0, green: 200 / 255.0, blue: 200 / 255.0, alpha: 1)
        } else {
            return UIColor(red: 51 / 255.0, green: 51 / 255.0, blue: 53 / 255.0, alpha: 1.0)
        }
    }
}
