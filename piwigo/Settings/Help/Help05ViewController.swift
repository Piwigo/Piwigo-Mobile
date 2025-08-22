//
//  Help05ViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 30/12/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import UIKit
import piwigoKit

class Help05ViewController: UIViewController {
    
    @IBOutlet weak var legendTop: UILabel!
    @IBOutlet weak var imageViewTop: UIImageView!
    @IBOutlet weak var legendBot: UILabel!
    @IBOutlet weak var imageViewBot: UIImageView!
    private let helpID: UInt16 = 0b00000000_00010000

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
        let titleString = NSLocalizedString("help05_header", comment: "Uploading Photos") + "\n"
        let titleAttributedString = NSMutableAttributedString(string: titleString)
        let titleRange = NSRange(location: 0, length: titleString.count)
        titleAttributedString.addAttribute(.font, value: titleFont, range: titleRange)
        legendTopAttributedString.append(titleAttributedString)

        // Text of legend above images
        let aboveString = NSLocalizedString("help05_text", comment: "Submit requests and let go")
        let aboveAttributedString = NSMutableAttributedString(string: aboveString)
        let aboveRange = NSRange(location: 0, length: aboveString.count)
        aboveAttributedString.addAttribute(.font, value: textFont, range: aboveRange)
        legendTopAttributedString.append(aboveAttributedString)

        // Set legend at top of screen
        legendTop.attributedText = legendTopAttributedString

        // Text of legend between images
        let betweenString = NSLocalizedString("help05_text2", comment: "Access the UploadQueue.")
        let betweenAttributedString = NSMutableAttributedString(string: betweenString)
        let betweenRange: NSRange = NSRange(location: 0, length: betweenString.count)
        betweenAttributedString.addAttribute(.font, value: textFont, range: betweenRange)
        legendBotAttributedString.append(betweenAttributedString)

        // Set legend
        legendBot.attributedText = legendBotAttributedString
        
        // Set top image view
        guard let topImageUrl = Bundle.main.url(forResource: "help05-top", withExtension: "png") else {
            fatalError("!!! Could not find help05-top image !!!")
        }
        imageViewTop.layoutIfNeeded() // Ensure imageView is in its final size.
        var scale = max(imageViewTop.traitCollection.displayScale, 1.0)
        var imageSize = CGSizeMake(imageViewTop.bounds.size.width * scale, imageViewTop.bounds.size.height * scale)
        imageViewTop.image = ImageUtilities.downsample(imageAt: topImageUrl, to: imageSize, for: .album)
        
        // Set bottom image view
        guard let botImageUrl = Bundle.main.url(forResource: "help05-bot", withExtension: "png") else {
            fatalError("!!! Could not find help05-bot image !!!")
        }
        imageViewBot.layoutIfNeeded() // Ensure imageView is in its final size.
        scale = max(imageViewBot.traitCollection.displayScale, 1.0)
        imageSize = CGSizeMake(imageViewBot.bounds.size.width * scale, imageViewBot.bounds.size.height * scale)
        imageViewBot.image = ImageUtilities.downsample(imageAt: botImageUrl, to: imageSize, for: .album)
        
        // Remember that this view was watched and when
        AppVars.shared.didWatchHelpViews = AppVars.shared.didWatchHelpViews | helpID
        AppVars.shared.dateOfLastHelpView = Date().timeIntervalSinceReferenceDate
    }

    @MainActor
    @objc func applyColorPalette() {
        // Background color of the view
        view.backgroundColor = PwgColor.background
        
        // Legend color
        legendTop.textColor = PwgColor.text
        legendBot.textColor = PwgColor.text
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
