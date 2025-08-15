//
//  Help08ViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 17/07/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import UIKit
import piwigoKit

class Help08ViewController: UIViewController {
    
    @IBOutlet weak var legendTop: UILabel!
    @IBOutlet weak var imageViewTop: UIImageView!
    @IBOutlet weak var legendBot: UILabel!
    @IBOutlet weak var imageViewBot: UIImageView!
    private let helpID: UInt16 = 0b00000000_10000000

    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialisation
        let hasLargeWidth = view.bounds.size.width > 320.0
        let titleFont: UIFont = hasLargeWidth ? .systemFont(ofSize: 17, weight: .bold) : .systemFont(ofSize: 13, weight: .bold)
        let textFont: UIFont = hasLargeWidth ? .systemFont(ofSize: 17) : .systemFont(ofSize: 13)
        let legendTopAttributedString = NSMutableAttributedString(string: "")
        let legendBotAttributedString = NSMutableAttributedString(string: "")

        // Title of legend above images
        let titleString = NSLocalizedString("help08_header", comment: "Parent Albums") + "\n"
        let titleAttributedString = NSMutableAttributedString(string: titleString)
        let titleRange = NSRange(location: 0, length: titleString.count)
        titleAttributedString.addAttribute(.font, value: titleFont, range: titleRange)
        legendTopAttributedString.append(titleAttributedString)

        // Text of legend above images
        let aboveString = NSLocalizedString("help08_text", comment: "Long-press back button")
        let aboveAttributedString = NSMutableAttributedString(string: aboveString)
        let aboveRange = NSRange(location: 0, length: aboveString.count)
        aboveAttributedString.addAttribute(.font, value: textFont, range: aboveRange)
        legendTopAttributedString.append(aboveAttributedString)

        // Set legend at top of screen
        legendTop.attributedText = legendTopAttributedString

        // Text of legend between images
        let betweenString = NSLocalizedString("help08_text2", comment: "Tap parent album")
        let betweenAttributedString = NSMutableAttributedString(string: betweenString)
        let betweenRange = NSRange(location: 0, length: betweenString.count)
        betweenAttributedString.addAttribute(.font, value: textFont, range: betweenRange)
        legendBotAttributedString.append(betweenAttributedString)

        // Set legend
        legendBot.attributedText = legendBotAttributedString
        
        // Set top image view
        guard let topImageUrl = Bundle.main.url(forResource: "help08-top", withExtension: "png") else {
            fatalError("!!! Could not find help08-top image !!!")
        }
        imageViewTop.layoutIfNeeded() // Ensure imageView is in its final size.
        var scale = max(imageViewTop.traitCollection.displayScale, 1.0)
        var imageSize = CGSizeMake(imageViewTop.bounds.size.width * scale, imageViewTop.bounds.size.height * scale)
        imageViewTop.image = ImageUtilities.downsample(imageAt: topImageUrl, to: imageSize, for: .album)
        
        // Set bottom image view
        guard let botImageUrl = Bundle.main.url(forResource: "help08-bot", withExtension: "png") else {
            fatalError("!!! Could not find help08-bot image !!!")
        }
        imageViewBot.layoutIfNeeded() // Ensure imageView is in its final size.
        scale = max(imageViewBot.traitCollection.displayScale, 1.0)
        imageSize = CGSizeMake(imageViewBot.bounds.size.width * scale, imageViewBot.bounds.size.height * scale)
        imageViewBot.image = ImageUtilities.downsample(imageAt: botImageUrl, to: imageSize, for: .album)
        
        // Remember that this view was watched and when
        AppVars.shared.didWatchHelpViews = AppVars.shared.didWatchHelpViews | helpID
        AppVars.shared.dateOfLastHelpView = Date().timeIntervalSinceReferenceDate
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Set colors, fonts, etc.
        applyColorPalette()

        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: Notification.Name.pwgPaletteChanged, object: nil)
    }

    @MainActor
    @objc func applyColorPalette() {
        // Background color of the view
        view.backgroundColor = PwgColor.background
        
        // Legend color
        legendTop.textColor = PwgColor.text
        legendBot.textColor = PwgColor.text
    }
    
    deinit {
        // Unregister all observers
        NotificationCenter.default.removeObserver(self)
    }
}
