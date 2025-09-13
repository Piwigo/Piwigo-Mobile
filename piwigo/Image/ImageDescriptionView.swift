//
//  ImageDescriptionView.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 22/12/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import UIKit
import piwigoKit

class ImageDescriptionView: UIVisualEffectView {
    
    @IBOutlet weak var descWidth: NSLayoutConstraint!
    @IBOutlet weak var descHeight: NSLayoutConstraint!
    @IBOutlet weak var descOffset: NSLayoutConstraint!
    @IBOutlet weak var descTextView: UITextView!
    
    override func awakeFromNib() {
        // Initialization code
        super.awakeFromNib()
    }
    
    @MainActor
    func applyColorPalette() {
        descTextView.textColor = PwgColor.text
    }
    
    func config(withImage image: Image,
                inViewController viewController: UIViewController, forVideo: Bool) {
        // Should we present a description?
        if image.commentHTML.string.isEmpty == false {
            descTextView.attributedText = image.commentHTML
        }
        else if image.comment.string.isEmpty == false {
            // Configure the description view
            let wholeRange = NSRange(location: 0, length: image.comment.string.count)
            let style = NSMutableParagraphStyle()
            style.alignment = NSTextAlignment.center
            let footNoteFont = UIFont.preferredFont(forTextStyle: .footnote)
            let attributes: [NSAttributedString.Key : Any] = [
                NSAttributedString.Key.foregroundColor: PwgColor.text,
                NSAttributedString.Key.font: UIFont.systemFont(ofSize: footNoteFont.pointSize, weight: .light),
                NSAttributedString.Key.paragraphStyle: style
            ]
            let desc = NSMutableAttributedString(attributedString: image.comment)
            desc.addAttributes(attributes, range: wholeRange)
            descTextView.linkTextAttributes = [NSAttributedString.Key.foregroundColor: PwgColor.orange]
            descTextView.attributedText = desc
        } else {
            // Hide the description view
            descTextView.text = ""
            self.isHidden = true
            return
        }
        
        // Don't show the description only when the bar is hidden
        let navController = viewController.navigationController
        self.isHidden = navController?.isNavigationBarHidden ?? false
        
        // Calculate the available width
        var safeAreaWidth: CGFloat = UIScreen.main.bounds.size.width
        if let root = navController?.topViewController {
            safeAreaWidth = root.view.frame.size.width
            safeAreaWidth -= root.view.safeAreaInsets.left + root.view.safeAreaInsets.right
        }
        
        // Calc the height required to display the text, corners'width deducted
        let context = NSStringDrawingContext()
        context.minimumScaleFactor = 1.0
        let cornerRadius: CGFloat = 20.0
        let rect = descTextView.attributedText.boundingRect(with: CGSize(width: safeAreaWidth - 2*cornerRadius,
                                                                         height: CGFloat.greatestFiniteMagnitude),
                                                            options: [.usesLineFragmentOrigin, .usesFontLeading],
                                                            context: context)
        let textHeight = rect.height
        
        // Determine the max height according to device and orientation
        let maxHeight: CGFloat!
        let orientation = viewController.view.window?.windowScene?.interfaceOrientation ?? .portrait
        let height = window?.bounds.height ?? UIScreen.main.bounds.height
        if orientation.isLandscape {
            maxHeight = 0.20 * height
        } else {
            maxHeight = 0.23 * height
        }
        
        // Can the description be presented in the provided height?
        if textHeight < maxHeight {
            // Calculate the height (the width should be < safeAreaWidth)
            let requiredHeight = ceil(descTextView.textContainerInset.top + textHeight + descTextView.textContainerInset.bottom)
            // Calculate the optimum size
            let size = descTextView.sizeThatFits(CGSize(width: safeAreaWidth - cornerRadius,
                                                        height: requiredHeight))
            descWidth.constant = size.width + cornerRadius   // Add space taken by corners
            descHeight.constant = size.height
            if #available(iOS 26.0, *) {
                descOffset.constant = forVideo ? 12 : 8
            } else {
                // Fallback on previous version
                descOffset.constant = forVideo ? 12 : 4
            }
            self.layer.cornerRadius = min(cornerRadius, descHeight.constant/2)
            self.layer.masksToBounds = true
        }
        else if rect.width < safeAreaWidth - 4*cornerRadius {
            // Several short lines but the width is smaller than screen width
            descWidth.constant = rect.width + cornerRadius   // Add space taken by corners
            descHeight.constant = min(maxHeight, rect.height)
            if #available(iOS 26.0, *) {
                descOffset.constant = forVideo ? 12 : 8
            } else {
                // Fallback on previous version
                descOffset.constant = forVideo ? 12 : 4
            }
            self.layer.cornerRadius = min(cornerRadius, descHeight.constant/2)
            self.layer.masksToBounds = true
            
            // Scroll text to the top
            descTextView.scrollRangeToVisible(NSRange(location: 0, length: 1))
        }
        else {
            // Several long lines spread over full width for minimising height
            self.layer.cornerRadius = 0            // Disable rounded corner in case user added text
            self.layer.masksToBounds = false
            descWidth.constant = safeAreaWidth
            let height = descTextView.sizeThatFits(CGSize(width: safeAreaWidth,
                                                          height: CGFloat.greatestFiniteMagnitude)).height
            descHeight.constant = min(maxHeight, height)
            descOffset.constant = forVideo ? 12 : 0
            
            // Scroll text to the top
            descTextView.scrollRangeToVisible(NSRange(location: 0, length: 1))
        }
    }
}
