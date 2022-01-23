//
//  TableViewUtilities.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 23/01/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import UIKit

@objc
class TableViewUtilities: NSObject {
    
    class func heightOfHeader(withTitle title:String, text:String = "",
                               width: CGFloat = 0.0) -> CGFloat {
        // Initialise drawing context
        let context = NSStringDrawingContext()
        context.minimumScaleFactor = 1.0

        // Initialise variables and witdth constraint
        var height = CGFloat.zero
        let margin =  CGFloat(15); let minHeight = CGFloat(44)
        let maxWidth = CGFloat(fmax(width - 2*margin, CGFloat(200)))
        let widthConstraint = CGSize(width: maxWidth, height: CGFloat.greatestFiniteMagnitude)

        // Add title size
        if !title.isEmpty {
            let titleAttributes = [NSAttributedString.Key.font: UIFont.piwigoFontBold()]
            height += title.boundingRect(with: widthConstraint, options: .usesLineFragmentOrigin,
                                         attributes: titleAttributes, context: context).height
        }

        // Add text size
        if !text.isEmpty {
            let textAttributes = [NSAttributedString.Key.font: UIFont.piwigoFontSmall()]
            height += text.boundingRect(with: widthConstraint, options: .usesLineFragmentOrigin,
                                           attributes: textAttributes, context: context).height
        }

        return fmax(minHeight, CGFloat(ceil(height)))
    }
}
