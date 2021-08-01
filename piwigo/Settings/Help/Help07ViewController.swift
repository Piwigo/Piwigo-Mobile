//
//  Help07ViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 27/07/2021.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import UIKit
import piwigoKit

class Help07ViewController: UIViewController {
    
    @IBOutlet weak var legendTop: UILabel!
    @IBOutlet weak var imageViewTop: UIImageView!
    @IBOutlet weak var legendBot: UILabel!
    @IBOutlet weak var imageViewBot: UIImageView!
    private let helpID: UInt16 = 0b00000000_01000000

    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialise mutable attributed strings
        let legendTopAttributedString = NSMutableAttributedString(string: "")
        let legendBotAttributedString = NSMutableAttributedString(string: "")

        // Title of legend above images
        let titleString = "\(NSLocalizedString("help07_header", comment: "Auto-Uploading"))\n"
        let titleAttributedString = NSMutableAttributedString(string: titleString)
        titleAttributedString.addAttribute(.font, value: view.bounds.size.width > 320 ? UIFont.piwigoFontBold() : UIFont.piwigoFontSemiBold(), range: NSRange(location: 0, length: titleString.count))
        legendTopAttributedString.append(titleAttributedString)

        // Comment below title
        var textString = "\(NSLocalizedString("help02_text3", comment: "(requires the uploadAsync extension or Piwigo 11)"))\n"
        var textAttributedString = NSMutableAttributedString(string: textString)
        textAttributedString.addAttribute(.font, value: view.bounds.size.width > 320 ? UIFont.piwigoFontSmall() : UIFont.piwigoFontTiny(), range: NSRange(location: 0, length: textString.count))
        legendTopAttributedString.append(textAttributedString)

        // Text of legend above images
        textString = NSLocalizedString("help07_text", comment: "Select albums in Piwigo and create automations in Shortcuts.")
        textAttributedString = NSMutableAttributedString(string: textString)
        textAttributedString.addAttribute(.font, value: view.bounds.size.width > 320 ? UIFont.piwigoFontNormal() : UIFont.piwigoFontSmall(), range: NSRange(location: 0, length: textString.count))
        legendTopAttributedString.append(textAttributedString)

        // Set legend at top of screen
        legendTop.attributedText = legendTopAttributedString

        // Text of legend between images
        textString = NSLocalizedString("help02_text2", comment: "Plug the device to its charger and let iOS launch the uploads whenever appropriate.")
        textAttributedString = NSMutableAttributedString(string: textString)
        textAttributedString.addAttribute(.font, value: view.bounds.size.width > 320 ? UIFont.piwigoFontNormal() : UIFont.piwigoFontSmall(), range: NSRange(location: 0, length: textString.count))
        legendBotAttributedString.append(textAttributedString)

        // Set top image view
        guard let topImageUrl = Bundle.main.url(forResource: "help07-top", withExtension: "png") else {
            fatalError("!!! Could not find help07-top image !!!")
        }
        imageViewTop.layoutIfNeeded() // Ensure imageView is in its final size.
        let topImageSize = imageViewTop.bounds.size
        let topImageScale = imageViewTop.traitCollection.displayScale
        imageViewTop.image = ImageUtilities.downsample(imageAt: topImageUrl, to: topImageSize, scale: topImageScale)
        
        // Set bottom image view
        guard let botImageUrl = Bundle.main.url(forResource: "help02-bot", withExtension: "png") else {
            fatalError("!!! Could not find help02-bot image !!!")
        }
        imageViewBot.layoutIfNeeded() // Ensure imageView is in its final size.
        let botImageSize = imageViewBot.bounds.size
        let botImageScale = imageViewBot.traitCollection.displayScale
        imageViewBot.image = ImageUtilities.downsample(imageAt: botImageUrl, to: botImageSize, scale: botImageScale)
        
        // Set legend
        legendBot.attributedText = legendBotAttributedString
        
        // Remember that this view was watched
        AppVars.didWatchHelpViews = AppVars.didWatchHelpViews | helpID
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Set colors, fonts, etc.
        applyColorPalette()

        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: PwgNotifications.paletteChanged, object: nil)
    }

    @objc func applyColorPalette() {
        // Background color of the view
        view.backgroundColor = UIColor.piwigoColorBackground()
        
        // Legend color
        legendTop.textColor = UIColor.piwigoColorText()
        legendBot.textColor = UIColor.piwigoColorText()
    }
    
    deinit {
        // Unregister palette changes
        NotificationCenter.default.removeObserver(self, name: PwgNotifications.paletteChanged, object: nil)
    }
}
