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
    
    // MARK: - Headers
    // Returns the height of a header containing a title and/or a subtitle
    class func heightOfHeader(withTitle title: String, text: String = "",
                              width: CGFloat = CGFloat.zero) -> CGFloat {
        // Initialise drawing context
        let context = NSStringDrawingContext()
        context.minimumScaleFactor = 1.0

        // Initialise variables and width constraint
        /// The minimum width of a screen is of 320 pixels.
        /// See https://developer.apple.com/design/human-interface-guidelines/ios/visual-design/adaptivity-and-layout/
        var height: CGFloat = CGFloat.zero
        let margin: CGFloat =  15.0, minWidth: CGFloat = 320.0 - 2 * margin, minHeight: CGFloat = 44.0
        let maxWidth = CGFloat(fmax(width - 2.0*margin, minWidth))
        let widthConstraint: CGSize = CGSize(width: maxWidth, height: CGFloat.greatestFiniteMagnitude)

        // Add title height
        if title.isEmpty == false {
            let titleAttributes = [NSAttributedString.Key.font: UIFont.piwigoFontBold()]
            height += title.boundingRect(with: widthConstraint, options: .usesLineFragmentOrigin,
                                         attributes: titleAttributes, context: context).height
        }

        // Add text height
        if text.isEmpty == false {
            let textAttributes = [NSAttributedString.Key.font: UIFont.piwigoFontSmall()]
            height += text.boundingRect(with: widthConstraint, options: .usesLineFragmentOrigin,
                                           attributes: textAttributes, context: context).height
        }

        return CGFloat(fmax(minHeight, ceil(height)))
    }
    
    class func viewOfHeader(withTitle title: String, text: String = "") -> UIView? {
        // Check header content
        if title.isEmpty, text.isEmpty { return nil }

        // Initialisation
        let headerAttributedString = NSMutableAttributedString(string: "")

        // Add title attributed string
        if title.isEmpty == false {
            let titleAttributedString = NSMutableAttributedString(string: title)
            titleAttributedString.addAttribute(.font, value: UIFont.piwigoFontBold(),
                                               range: NSRange(location: 0, length: title.count))
            headerAttributedString.append(titleAttributedString)
        }
        
        // Add text attributed string
        if text.isEmpty == false {
            let textAttributedString = NSMutableAttributedString(string: text)
            textAttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall(),
                                              range: NSRange(location: 0, length: text.count))
            headerAttributedString.append(textAttributedString)
        }
                
        // Create header label
        let headerLabel = UILabel()
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        headerLabel.textColor = .piwigoColorHeader()
        headerLabel.numberOfLines = 0
        headerLabel.adjustsFontSizeToFitWidth = false
        headerLabel.lineBreakMode = .byWordWrapping
        headerLabel.attributedText = headerAttributedString

        // Create header view
        let header = UIView()
        header.addSubview(headerLabel)
        header.addConstraint(NSLayoutConstraint.constraintView(fromBottom: headerLabel, amount: 4)!)
        if #available(iOS 11, *) {
            header.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|-[header]-|",
                                                                 options: [], metrics: nil, views: [
                                                                    "header": headerLabel
                                                                 ]))
        } else {
            header.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|-15-[header]-15-|",
                                                                 options: [], metrics: nil, views: [
                                                                    "header": headerLabel
                                                                 ]))
        }
        return header
    }


    // MARK: - Footers
    // Returns the height of a footer containing some text
    class func heightOfFooter(withText text: String,
                              width: CGFloat = CGFloat.zero) -> CGFloat {

        // Check header content
        if text.isEmpty { return CGFloat.zero }

        // Initialise drawing context
        let context = NSStringDrawingContext()
        context.minimumScaleFactor = 1.0

        // Initialise variables and width constraint
        /// The minimum width of a screen is of 320 pixels.
        /// See https://developer.apple.com/design/human-interface-guidelines/ios/visual-design/adaptivity-and-layout/
        let margin: CGFloat =  15.0, minWidth: CGFloat = 320.0 - 2 * margin
        let maxWidth = CGFloat(fmax(width - 2.0*margin, minWidth))
        let widthConstraint: CGSize = CGSize(width: maxWidth, height: CGFloat.greatestFiniteMagnitude)

        // Add title height
        let titleAttributes = [NSAttributedString.Key.font: UIFont.piwigoFontSmall()]
        let height: CGFloat = text.boundingRect(with: widthConstraint, options: .usesLineFragmentOrigin,
                                                attributes: titleAttributes, context: context).height

        return CGFloat(ceil(height) + 10.0)
    }
    
    class func viewOfFooter(withText text: String = "") -> UIView? {
        // Check header content
        if text.isEmpty { return nil }

        // Initialisation
        let footerAttributedString = NSMutableAttributedString(string: "")
        
        // Add text attributed string
        let textAttributedString = NSMutableAttributedString(string: text)
        textAttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall(),
                                          range: NSRange(location: 0, length: text.count))
        footerAttributedString.append(textAttributedString)
                
        // Create header label
        let footerLabel = UILabel()
        footerLabel.translatesAutoresizingMaskIntoConstraints = false
        footerLabel.textColor = .piwigoColorHeader()
        footerLabel.numberOfLines = 0
        footerLabel.adjustsFontSizeToFitWidth = false
        footerLabel.lineBreakMode = .byWordWrapping
        footerLabel.attributedText = footerAttributedString

        // Create header view
        let footer = UIView()
        footer.addSubview(footerLabel)
        footer.addConstraint(NSLayoutConstraint.constraintView(fromBottom: footerLabel, amount: 4)!)
        if #available(iOS 11, *) {
            footer.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|-[header]-|",
                                                                 options: [], metrics: nil, views: [
                                                                    "header": footerLabel
                                                                 ]))
        } else {
            footer.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|-15-[header]-15-|",
                                                                 options: [], metrics: nil, views: [
                                                                    "header": footerLabel
                                                                 ]))
        }
        return footer
    }
}
