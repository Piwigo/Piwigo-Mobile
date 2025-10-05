//
//  Help01ViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 30/11/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import UIKit
import piwigoKit

class Help01ViewController: UIViewController {
    
    @IBOutlet weak var legend: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    private let helpID: UInt16 = 0b00000000_00000001
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialisation
        let hasLargeWidth = view.bounds.size.width > 320.0
        let titleFont: UIFont = hasLargeWidth ? .systemFont(ofSize: 17, weight: .bold) : .systemFont(ofSize: 13, weight: .bold)
        let textFont: UIFont = hasLargeWidth ? .systemFont(ofSize: 17) : .systemFont(ofSize: 13)
        let legendAttributedString = NSMutableAttributedString(string: "")

        // Title
        let titleString = NSLocalizedString("help01_header", comment: "Multiple Selection") + "\n"
        let titleAttributedString = NSMutableAttributedString(string: titleString)
        let titleRange = NSRange(location: 0, length: titleString.count)
        titleAttributedString.addAttribute(.font, value: titleFont, range: titleRange)
        legendAttributedString.append(titleAttributedString)

        // Text
        let textString = NSLocalizedString("help01_text", comment: "Slide your finger from left to right (or right to left) then down, etc.")
        let textAttributedString = NSMutableAttributedString(string: textString)
        let textRange = NSRange(location: 0, length: textString.count)
        textAttributedString.addAttribute(.font, value: textFont, range: textRange)
        legendAttributedString.append(textAttributedString)

        // Set legend
        legend.attributedText = legendAttributedString
        
        // Set image view
        guard let imageUrl = Bundle.main.url(forResource: "help01", withExtension: "png")
        else { preconditionFailure("!!! Could not find help01 image !!!") }
        imageView.layoutIfNeeded() // Ensure imageView is in its final size.
        let scale = max(imageView.traitCollection.displayScale, 1.0)
        let imageSize = CGSizeMake(imageView.bounds.size.width * scale, imageView.bounds.size.height * scale)
        imageView.image = ImageUtilities.downsample(imageAt: imageUrl, to: imageSize, for: .help)
        
        // Remember that this view was watched and when
        AppVars.shared.didWatchHelpViews = AppVars.shared.didWatchHelpViews | helpID
        AppVars.shared.dateOfLastHelpView = Date().timeIntervalSinceReferenceDate
    }

    @MainActor
    @objc func applyColorPalette() {
        // Background color of the view
        view.backgroundColor = PwgColor.background
        
        // Legend color
        legend.textColor = PwgColor.text
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Set colors, fonts, etc.
        applyColorPalette()

        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: Notification.Name.pwgPaletteChanged, object: nil)
    }
    
    deinit {
        // Unregister all observers
        NotificationCenter.default.removeObserver(self)
    }
}
