//
//  PiwigoHUD.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 27/04/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit

enum pwgHudMode {
    case text
    case indeterminate
    case determinate
    case success
}

let pwgTagHUD = 899
let pwgDelayHUD = 500

class PiwigoHUD: UIView
{
    let margin = CGFloat(16)            // See XIB file
    var minWidth = CGFloat.zero         // Calculated when setting label and button titles
    let duration = 0.25                 // Animation duration
    
    @IBOutlet weak var view: UIView!
    @IBOutlet weak var viewWidth: NSLayoutConstraint!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var completedImage: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var titleBottomToIndicatorBottom: NSLayoutConstraint!    // 26 points
    @IBOutlet weak var detailLabel: UILabel!
    @IBOutlet weak var detailBottomToTitleBottom: NSLayoutConstraint!       // 20 points
    @IBOutlet weak var button: UIButton!
    @IBOutlet weak var buttonBottomToDetailBottom: NSLayoutConstraint!      // 36 points
    @IBOutlet weak var progressView: RingProgressView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    // MARK: - Create/Update HUD
    // Create and show HUD
    func show(withTitle title: String, detail: String?, minWidth: CGFloat,
              buttonTitle: String? = nil, buttonTarget: UIViewController? = nil, buttonSelector: Selector? = nil,
              inMode mode: pwgHudMode = .indeterminate, view: UIView)
    {
        // Store wanted minimum width
        self.minWidth = minWidth
        
        // Configure HUD activity indicator
        config(mode: mode)
        
        // Configure HUD title (always shown and non-empty)
        let screenWidth = view.window?.screen.bounds.width ?? view.bounds.width
        if title.isEmpty {
            titleLabel.attributedText = getAttributed(title: NSLocalizedString("loadingHUD_label", comment: "Loading…"),
                                                      forMaxWidth: screenWidth)
        } else {
            titleLabel.attributedText = getAttributed(title: title, forMaxWidth: screenWidth)
        }
        
        // Configure HUD detail
        if let detail = detail, detail.isEmpty == false {
            detailLabel.attributedText = getAttributed(detail: detail, forMaxWidth: screenWidth)
            detailLabel.isHidden = false
            detailBottomToTitleBottom.constant = 20
        } else {
            detailLabel.isHidden = true
            detailBottomToTitleBottom.constant = 0
        }
        
        // Configure HUD button
        if let buttonTitle = buttonTitle, buttonTitle.isEmpty == false,
           let buttonTarget = buttonTarget, let buttonSelector = buttonSelector {
            let attrTitle = getAttributed(button: buttonTitle, forWidth: screenWidth)
            button.setAttributedTitle(attrTitle, for: .normal)
            button.addTarget(buttonTarget, action: buttonSelector, for: .touchDown)
            button.backgroundColor = .piwigoColorCellBackground()
            button.isHidden = false
            buttonBottomToDetailBottom.constant = 36
        } else {
            button.isHidden = true
            buttonBottomToDetailBottom.constant = 0
        }
        
        // Set HUD view width after labels and button configurations
        viewWidth.constant = self.minWidth
        
        // Add HUD to superview
        self.alpha = 0
        self.backgroundColor = UIColor(white: 0, alpha: 0.5)
        self.view.backgroundColor = .piwigoColorBackground()
        view.addSubview(self)
        self.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            self.topAnchor.constraint(equalTo: view.topAnchor),
            self.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            self.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            self.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            self.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            self.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        // Show HUD
        UIView.animate(withDuration: duration) {
            self.alpha = 1
        }
    }
    
    func update(title: String? = nil, detail: String? = nil,
                buttonTitle: String? = nil, buttonTarget: UIViewController? = nil, buttonSelector: Selector? = nil,
                inMode mode: pwgHudMode? = nil) {
        // Configure HUD activity indicator
        if let mode = mode {
            config(mode: mode)
        }
        
        // Update HUD title (always shown and non-empty)
        let screenWidth = view.window?.screen.bounds.width ?? view.bounds.width
        if let title = title, title.isEmpty == false {
            titleLabel.attributedText = getAttributed(title: title,forMaxWidth: screenWidth)
        } else {
            titleLabel.attributedText = getAttributed(title: NSLocalizedString("loadingHUD_label", comment: "Loading…"),
                                                      forMaxWidth: screenWidth)
        }
        
        // Update HUD detail
        if let detail = detail, detail.isEmpty == false {
            let attributedDetail = getAttributed(detail: detail, forMaxWidth: screenWidth)
            detailLabel.attributedText = attributedDetail
            detailLabel.sizeToFit()
            detailLabel.isHidden = false
            let context = NSStringDrawingContext()
            context.minimumScaleFactor = 1.0
            let height = attributedDetail.boundingRect(with: CGSize(width: view.frame.size.width - 32.0,
                                                                  height: CGFloat.greatestFiniteMagnitude),
                                                       options: .usesLineFragmentOrigin, context: context).height
            detailBottomToTitleBottom.constant = ceil(height + 3.5)     // i.e. 20 for a single line
        } else {
            detailLabel.text = ""
            detailLabel.isHidden = true
            detailBottomToTitleBottom.constant = 0
        }
        
        // Add or update button
        if button.isHidden, let buttonTitle = buttonTitle,
           let buttonTarget = buttonTarget, let buttonSelector = buttonSelector {
            let attrTitle = getAttributed(button: buttonTitle, forWidth: screenWidth)
            button.setAttributedTitle(attrTitle, for: .normal)
            button.addTarget(buttonTarget, action: buttonSelector, for: .touchDown)
            button.backgroundColor = .piwigoColorCellBackground()
            button.isHidden = false
            detailBottomToTitleBottom.constant = 36
        } else {
            // Modify button title and/or target/action
            if let buttonTitle = buttonTitle {
                let attrTitle = getAttributed(button: buttonTitle, forWidth: screenWidth)
                button.setAttributedTitle(attrTitle, for: .normal)
            }
            if let buttonTarget = buttonTarget, let buttonSelector = buttonSelector {
                button.allTargets.forEach { target in
                    button.removeTarget(target, action: nil, for: .touchDown)
                }
                button.addTarget(buttonTarget, action: buttonSelector, for: .touchDown)
            }
        }
    }
    
    func hide() {
        // Show HUD
        UIView.animate(withDuration: duration) {
            self.alpha = 0
        } completion: { _ in
            self.removeFromSuperview()
        }
    }
    
    
    // MARK: - HUD Modes
    private func config(mode: pwgHudMode) {
        switch mode {
        case .text:                 // No activity indicator or checkmark
            activityIndicator.isHidden = true
            progressView.isHidden = true
            completedImage.isHidden = true
            titleBottomToIndicatorBottom.constant = 0
        case .indeterminate:        // Activity indicator presented
            activityIndicator.color = UIColor.piwigoColorText()
            activityIndicator.isHidden = false
            progressView.isHidden = true
            completedImage.isHidden = true
            titleBottomToIndicatorBottom.constant = 26
        case .determinate:
            activityIndicator.isHidden = true
            progressView.isHidden = false
            completedImage.isHidden = true
            titleBottomToIndicatorBottom.constant = 26
        case .success:              // Checkmark image presented
            activityIndicator.isHidden = true
            progressView.isHidden = true
            completedImage.tintColor = UIColor.piwigoColorLeftLabel()
            completedImage.isHidden = false
            titleBottomToIndicatorBottom.constant = 26
        }
    }
    
    
    // MARK: - HUD Title
    private func getAttributed(title: String, forMaxWidth screenWidth: CGFloat) -> NSAttributedString {
        // Font size depends on screen size (https://iosref.com/res)
        let fontSize: CGFloat = screenWidth > 370 ? 17 : 13
        
        // Create attributed text
        let wholeRange = NSRange(location: 0, length: title.count)
        let style = NSMutableParagraphStyle()
        style.alignment = NSTextAlignment.center
        let attributes = [
            NSAttributedString.Key.foregroundColor: UIColor.piwigoColorText(),
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: fontSize, weight: .semibold),
            NSAttributedString.Key.paragraphStyle: style
        ]
        let attTitle = NSMutableAttributedString(string: title)
        attTitle.addAttributes(attributes, range: wholeRange)
        
        // Determine size and number of lines
        let context = NSStringDrawingContext()
        context.minimumScaleFactor = 1.0
        let titleLineHeight = (titleLabel.font ?? UIFont.systemFont(ofSize: fontSize, weight: .semibold)).lineHeight
        let titleRect = attTitle.boundingRect(with: CGSize(width: CGFloat.greatestFiniteMagnitude,
                                                           height: titleLineHeight),
                                              options: .usesLineFragmentOrigin, context: context)
        let missing = titleRect.width + 2*margin - minWidth
        if missing < 0 {
            return attTitle
        }
        
        // Increase minWidth to display title on a single line
        minWidth += missing
        return attTitle
    }
    
    
    // MARK: - HUD Detail
    private func getAttributed(detail: String, forMaxWidth screenWidth: CGFloat) -> NSAttributedString {
        // Font size depends on screen size (https://iosref.com/res)
        let fontSize: CGFloat = screenWidth > 370 ? 13 : 10
        
        // Create attributed text
        let wholeRange = NSRange(location: 0, length: detail.count)
        let style = NSMutableParagraphStyle()
        style.alignment = NSTextAlignment.center
        let attributes = [
            NSAttributedString.Key.foregroundColor: UIColor.piwigoColorText(),
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: fontSize, weight: .regular),
            NSAttributedString.Key.paragraphStyle: style
        ]
        let attDetail = NSMutableAttributedString(string: detail)
        attDetail.addAttributes(attributes, range: wholeRange)
        
        // Determine size and number of lines
        let context = NSStringDrawingContext()
        context.minimumScaleFactor = 1.0
        let detailLineHeight = (detailLabel.font ?? UIFont.systemFont(ofSize: 10)).lineHeight
        let detailRect = attDetail.boundingRect(with: CGSize(width: viewWidth.constant - 2*margin,
                                                             height: CGFloat.greatestFiniteMagnitude),
                                                options: .usesLineFragmentOrigin, context: context)
        if detailRect.height / detailLineHeight < 3 {
            // Displayed on 1 or 2 lines
            return attDetail
        }
        
        // Try increasing minWidth to display detail on fewer lines
        minWidth += min(100, screenWidth - minWidth - 40)
        return attDetail
    }
    
    
    // MARK: - HUD Button
    private func getAttributed(button: String, forWidth width: CGFloat) -> NSAttributedString {
        // Font size depends on screen size (https://iosref.com/res)
        let fontSize: CGFloat = width > 370 ? 13 : 10
        
        // Create attributed text
        let wholeRange = NSRange(location: 0, length: button.count)
        let style = NSMutableParagraphStyle()
        style.alignment = NSTextAlignment.center
        let attributes = [
            NSAttributedString.Key.foregroundColor: UIColor.piwigoColorOrange(),
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: fontSize, weight: .semibold),
            NSAttributedString.Key.paragraphStyle: style
        ]
        let attButton = NSMutableAttributedString(string: button)
        attButton.addAttributes(attributes, range: wholeRange)
        return attButton
    }
}
