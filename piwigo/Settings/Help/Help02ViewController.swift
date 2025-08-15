//
//  Help02ViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 30/11/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import UIKit
import piwigoKit

class Help02ViewController: UIViewController {
    
    @IBOutlet weak var legendTop: UILabel!
    @IBOutlet weak var imageViewTop: UIImageView!
    @IBOutlet weak var legendBot: UILabel!
    @IBOutlet weak var imageViewBot: UIImageView!
    private let helpID: UInt16 = 0b00000000_00000010

    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialisation
        let hasLargeWidth = view.bounds.size.width > 320.0
        let titleFont: UIFont = hasLargeWidth ? .systemFont(ofSize: 17, weight: .bold) : .systemFont(ofSize: 13, weight: .bold)
        let textFont: UIFont = hasLargeWidth ? .systemFont(ofSize: 17) : .systemFont(ofSize: 13)
//        let noteFont: UIFont = hasLargeWidth ? .systemFont(ofSize: 13) : .systemFont(ofSize: 10)
        let legendTopAttributedString = NSMutableAttributedString(string: "")
        let legendBotAttributedString = NSMutableAttributedString(string: "")

        // Title of legend above images
        let titleString = NSLocalizedString("help02_header", comment: "Background Uploading") + "\n"
        let titleAttributedString = NSMutableAttributedString(string: titleString)
        let titleRange = NSRange(location: 0, length: titleString.count)
        titleAttributedString.addAttribute(.font, value: titleFont, range: titleRange)
        legendTopAttributedString.append(titleAttributedString)

        // Note below title
//        let noteString = NSLocalizedString("help02_text3", comment: "(requires the uploadAsync extension or Piwigo 11)") + "\n"
//        let noteAttributedString = NSMutableAttributedString(string: noteString)
//        let noteRange = NSRange(location: 0, length: noteString.count)
//        noteAttributedString.addAttribute(.font, value: noteFont, range: noteRange)
//        legendTopAttributedString.append(noteAttributedString)

        // Text of legend above images
        let aboveString = NSLocalizedString("help02_text", comment: "Select photos/videos, tap Upload")
        let aboveAttributedString = NSMutableAttributedString(string: aboveString)
        let aboveRange = NSRange(location: 0, length: aboveString.count)
        aboveAttributedString.addAttribute(.font, value: textFont, range: aboveRange)
        legendTopAttributedString.append(aboveAttributedString)

        // Set legend at top of screen
        legendTop.attributedText = legendTopAttributedString

        // Text of legend between images
        let belowString = NSLocalizedString("help02_text2", comment: "Plug the device to its charger and let iOS…")
        let belowAttributedString = NSMutableAttributedString(string: belowString)
        let belowRange: NSRange = NSRange(location: 0, length: belowString.count)
        belowAttributedString.addAttribute(.font, value: textFont, range: belowRange)
        legendBotAttributedString.append(belowAttributedString)

        // Set legend
        legendBot.attributedText = legendBotAttributedString
        
        // Set top image view
        guard let topImageUrl = Bundle.main.url(forResource: "help02-top", withExtension: "png") else {
            fatalError("!!! Could not find help02-top image !!!")
        }
        imageViewTop.layoutIfNeeded() // Ensure imageView is in its final size.
        var scale = max(imageViewTop.traitCollection.displayScale, 1.0)
        var imageSize = CGSizeMake(imageViewTop.bounds.size.width * scale, imageViewTop.bounds.size.height * scale)
        imageViewTop.image = ImageUtilities.downsample(imageAt: topImageUrl, to: imageSize, for: .album)
        
        // Set bottom image view
        guard let botImageUrl = Bundle.main.url(forResource: "help02-bot", withExtension: "png") else {
            fatalError("!!! Could not find help02-bot image !!!")
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
