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
        
        // Initialise mutable attributed strings
        let legendTopAttributedString = NSMutableAttributedString(string: "")
        let legendBotAttributedString = NSMutableAttributedString(string: "")

        // Title of legend above images
        let titleString = "\(NSLocalizedString("help08_header", comment: "Parent Albums"))\n"
        let titleAttributedString = NSMutableAttributedString(string: titleString)
        titleAttributedString.addAttribute(.font, value: view.bounds.size.width > 320 ? UIFont.piwigoFontBold() : UIFont.piwigoFontSemiBold(), range: NSRange(location: 0, length: titleString.count))
        legendTopAttributedString.append(titleAttributedString)

        // Text of legend above images
        var textString = NSLocalizedString("help08_text", comment: "Long-press back button")
        var textAttributedString = NSMutableAttributedString(string: textString)
        textAttributedString.addAttribute(.font, value: view.bounds.size.width > 320 ? UIFont.piwigoFontNormal() : UIFont.piwigoFontSmall(), range: NSRange(location: 0, length: textString.count))
        legendTopAttributedString.append(textAttributedString)

        // Set legend at top of screen
        legendTop.attributedText = legendTopAttributedString

        // Text of legend between images
        textString = NSLocalizedString("help08_text2", comment: "Tap parent album")
        textAttributedString = NSMutableAttributedString(string: textString)
        textAttributedString.addAttribute(.font, value: view.bounds.size.width > 320 ? UIFont.piwigoFontNormal() : UIFont.piwigoFontSmall(), range: NSRange(location: 0, length: textString.count))
        legendBotAttributedString.append(textAttributedString)

        // Set legend
        legendBot.attributedText = legendBotAttributedString
        
        // Set top image view
        guard let topImageUrl = Bundle.main.url(forResource: "help08-top", withExtension: "png") else {
            fatalError("!!! Could not find help08-top image !!!")
        }
        imageViewTop.layoutIfNeeded() // Ensure imageView is in its final size.
        let topImageSize = imageViewTop.bounds.size
        let topImageScale = imageViewTop.traitCollection.displayScale
        imageViewTop.image = ImageUtilities.downsample(imageAt: topImageUrl, to: topImageSize, scale: topImageScale)
        
        // Set bottom image view
        guard let botImageUrl = Bundle.main.url(forResource: "help08-bot", withExtension: "png") else {
            fatalError("!!! Could not find help08-bot image !!!")
        }
        imageViewBot.layoutIfNeeded() // Ensure imageView is in its final size.
        let botImageSize = imageViewBot.bounds.size
        let botImageScale = imageViewBot.traitCollection.displayScale
        imageViewBot.image = ImageUtilities.downsample(imageAt: botImageUrl, to: botImageSize, scale: botImageScale)
        
        // Remember that this view was watched
        AppVars.shared.didWatchHelpViews = AppVars.shared.didWatchHelpViews | helpID
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Set colors, fonts, etc.
        applyColorPalette()

        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: .pwgPaletteChanged, object: nil)
    }

    @objc func applyColorPalette() {
        // Background color of the view
        view.backgroundColor = .piwigoColorBackground()
        
        // Legend color
        legendTop.textColor = .piwigoColorText()
        legendBot.textColor = .piwigoColorText()
    }
    
    deinit {
        // Unregister palette changes
        NotificationCenter.default.removeObserver(self, name: .pwgPaletteChanged, object: nil)
    }
}
