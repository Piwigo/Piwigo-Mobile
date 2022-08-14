//
//  ImageDescriptionView.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 22/12/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import UIKit

class ImageDescriptionView: UIVisualEffectView {
    
    @IBOutlet weak var descWidth: NSLayoutConstraint!
    @IBOutlet weak var descHeight: NSLayoutConstraint!
    @IBOutlet weak var descOffset: NSLayoutConstraint!
    @IBOutlet weak var descTextView: UITextView!

    override func awakeFromNib() {
        // Initialization code
        super.awakeFromNib()
    }

    func configDescription(with imageComment:String?,
                           completion: @escaping () -> Void) {
        // Should we present a description?
        guard let comment = imageComment, comment.isEmpty == false else {
            // Hide the description view
            descTextView.text = ""
            self.isHidden = true
            completion()
            return
        }
        
        // Configure the description view
        descTextView.attributedText = comment.htmlToAttributedString
        let navController = topMostController()?.navigationController
        self.isHidden = navController?.isNavigationBarHidden ?? false

        // Calculate the available width
        var safeAreaWidth: CGFloat = UIScreen.main.bounds.size.width
        if let root = navController?.topViewController {
            safeAreaWidth = root.view.frame.size.width
            if #available(iOS 11.0, *) {
                safeAreaWidth -= root.view.safeAreaInsets.left + root.view.safeAreaInsets.right
            }
        }
        
        // Calculate the required number of lines, corners'width deducted
        let context = NSStringDrawingContext()
        context.minimumScaleFactor = 1.0
        let lineHeight = (descTextView.font ?? UIFont.piwigoFontSmall()).lineHeight
        let cornerRadius = descTextView.textContainerInset.top + lineHeight/2
        let rect = descTextView.attributedText.boundingRect(with: CGSize(width: safeAreaWidth - 2*cornerRadius,
                                                                         height: CGFloat.greatestFiniteMagnitude),
                                                            options: .usesLineFragmentOrigin, context: context)
        let textHeight = rect.height
        let nberOfLines = textHeight / lineHeight
        
        // Can the description be presented on 3 lines maximum?
        if nberOfLines < 4 {
            // Calculate the height (the width should be < safeAreaWidth)
            let requiredHeight = ceil(descTextView.textContainerInset.top + textHeight + descTextView.textContainerInset.bottom)
            // Calculate the optimum size
            let size = descTextView.sizeThatFits(CGSize(width: safeAreaWidth - cornerRadius,
                                                        height: requiredHeight))
            descWidth.constant = size.width + cornerRadius   // Add space taken by corners
            descHeight.constant = size.height
            descOffset.constant = 10 - 2 * nberOfLines
            self.layer.cornerRadius = cornerRadius
            self.layer.masksToBounds = true
        }
        else if rect.width < safeAreaWidth - 4*cornerRadius {
            // Several short lines but width much smaller than screen width
            descWidth.constant = rect.width + cornerRadius   // Add space taken by corners
            self.layer.cornerRadius = cornerRadius
            self.layer.masksToBounds = true

            // The maximum height is limited on iPhone
            if UIDevice.current.userInterfaceIdiom == .phone {
                let orientation: UIInterfaceOrientation
                if #available(iOS 14, *) {
                    orientation = UIApplication.shared.windows.first?.windowScene?.interfaceOrientation ?? .portrait
                } else {
                    orientation = UIApplication.shared.statusBarOrientation
                }
                let maxHeight:CGFloat = orientation.isPortrait ? 88 : 52
                descHeight.constant = min(maxHeight, rect.height)
                descOffset.constant = 2
            }
            else {
                descHeight.constant = rect.height
                descOffset.constant = 0
            }
            
            // Scroll text to the top
            descTextView.scrollRangeToVisible(NSRange(location: 0, length: 1))
        }
        else {
            // Several long lines spread over full width for minimising height
            self.layer.cornerRadius = 0            // Disable rounded corner in case user added text
            self.layer.masksToBounds = false
            descWidth.constant = safeAreaWidth
            descOffset.constant = 0
            let height = descTextView.sizeThatFits(CGSize(width: safeAreaWidth,
                                                          height: CGFloat.greatestFiniteMagnitude)).height

            // The maximum height is limited on iPhone
            if UIDevice.current.userInterfaceIdiom == .phone {
                let orientation: UIInterfaceOrientation
                if #available(iOS 14, *) {
                    orientation = UIApplication.shared.windows.first?.windowScene?.interfaceOrientation ?? .portrait
                } else {
                    orientation = UIApplication.shared.statusBarOrientation
                }
                let maxHeight:CGFloat = orientation.isPortrait ? 88 : 52
                descHeight.constant = min(maxHeight, height)
            }
            else {
                descHeight.constant = height
            }
            
            // Scroll text to the top
            descTextView.scrollRangeToVisible(NSRange(location: 0, length: 1))
        }
        completion()
    }
}
