//
//  Help11ViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 08/05/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//

import UIKit
import piwigoKit

class Help11ViewController: UIViewController {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var text1Label: UILabel!
    @IBOutlet weak var text2Label: UILabel!
    @IBOutlet weak var text3Label: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var text4Label: UILabel!
    private let helpID: UInt16 = 0b00000100_00000000

    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialisation
        let hasLargeWidth = view.bounds.size.width > 320.0
        let titleFont: UIFont = hasLargeWidth ? .systemFont(ofSize: 17, weight: .bold) : .systemFont(ofSize: 13, weight: .bold)
        let textFont: UIFont = hasLargeWidth ? .systemFont(ofSize: 17) : .systemFont(ofSize: 13)
        let textStyle = NSMutableParagraphStyle()
        textStyle.alignment = NSTextAlignment.left
        let textAttributes = [
            NSAttributedString.Key.foregroundColor: PwgColor.text,
            NSAttributedString.Key.font: textFont,
            NSAttributedString.Key.paragraphStyle: textStyle
        ]
        
        // Title
        let titleString = NSLocalizedString("help11_header", comment: "Show your photos and videos on a TV or Mac")
        let titleAttributedString = NSMutableAttributedString(string: titleString)
        let titleRange = NSRange(location: 0, length: titleString.count)
        titleAttributedString.addAttribute(.font, value: titleFont, range: titleRange)
        titleLabel.attributedText = titleAttributedString
        
        // Text step #1
        let text1String = NSLocalizedString("help11_text", comment: "Connect your iPhone or iPad to the same Wi-Fi network…")
        let text1AttributedString = NSMutableAttributedString(string: text1String)
        let text1Range = NSRange(location: 0, length: text1String.count)
        text1AttributedString.addAttributes(textAttributes, range: text1Range)
        text1Label.attributedText = text1AttributedString
        
        // Text step #2
        let text2String = NSLocalizedString("help11_text2", comment: "Open Control Center.")
        let text2AttributedString = NSMutableAttributedString(string: text2String)
        let text2Range = NSRange(location: 0, length: text2String.count)
        text2AttributedString.addAttributes(textAttributes, range: text2Range)
        text2Label.attributedText = text2AttributedString

        // Text step #3
        let text3String = NSLocalizedString("help11_text3", comment: "Tap the Screen Mirroring button:")
        let text3AttributedString = NSMutableAttributedString(string: text3String)
        let text3Range = NSRange(location: 0, length: text3String.count)
        text3AttributedString.addAttributes(textAttributes, range: text3Range)
        text3Label.attributedText = text3AttributedString

        // Text step #4
        let text4String = NSLocalizedString("help11_text4", comment: "Select your TV or Mac from the list.")
        let text4AttributedString = NSMutableAttributedString(string: text4String)
        let text4Range = NSRange(location: 0, length: text4String.count)
        text4AttributedString.addAttributes(textAttributes, range: text4Range)
        text4Label.attributedText = text4AttributedString

        // Set image view
        var fileName: String = "help11"
        if #unavailable(iOS 26.0) { fileName += "-iOS18" }
        guard let imageUrl = Bundle.main.url(forResource: fileName, withExtension: "png")
        else { preconditionFailure("!!! Could not find help11 image !!!") }
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
        titleLabel.textColor = PwgColor.text
        text1Label.textColor = PwgColor.text
        text2Label.textColor = PwgColor.text
        text3Label.textColor = PwgColor.text
        text4Label.textColor = PwgColor.text
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
