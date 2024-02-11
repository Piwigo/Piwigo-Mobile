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
        
        // Initialise mutable attributed strings
        let legendTopAttributedString = NSMutableAttributedString(string: "")
        let legendBotAttributedString = NSMutableAttributedString(string: "")

        // Title of legend above images
        let titleString = "\(NSLocalizedString("help05_header", comment: "Upload Photos"))\n"
        let titleAttributedString = NSMutableAttributedString(string: titleString)
        let titleFont = view.bounds.size.width > 320 ? UIFont.systemFont(ofSize: 17, weight: .bold) : UIFont.systemFont(ofSize: 17, weight: .semibold)
        let titleRange = NSRange(location: 0, length: titleString.count)
        titleAttributedString.addAttribute(.font, value: titleFont, range: titleRange)
        legendTopAttributedString.append(titleAttributedString)

        // Text of legend above images
        var textString = NSLocalizedString("help05_text", comment: "Submit requests and let go")
        var textAttributedString = NSMutableAttributedString(string: textString)
        textAttributedString.addAttribute(.font, value: view.bounds.size.width > 320 ? UIFont.systemFont(ofSize: 17) : UIFont.systemFont(ofSize: 13), range: NSRange(location: 0, length: textString.count))
        legendTopAttributedString.append(textAttributedString)

        // Set legend at top of screen
        legendTop.attributedText = legendTopAttributedString

        // Text of legend between images
        textString = NSLocalizedString("help05_text2", comment: "Access the UploadQueue.")
        textAttributedString = NSMutableAttributedString(string: textString)
        textAttributedString.addAttribute(.font, value: view.bounds.size.width > 320 ? UIFont.systemFont(ofSize: 17) : UIFont.systemFont(ofSize: 13), range: NSRange(location: 0, length: textString.count))
        legendBotAttributedString.append(textAttributedString)

        // Set legend
        legendBot.attributedText = legendBotAttributedString
        
        // Set top image view
        guard let topImageUrl = Bundle.main.url(forResource: "help05-top", withExtension: "png") else {
            fatalError("!!! Could not find help05-top image !!!")
        }
        imageViewTop.layoutIfNeeded() // Ensure imageView is in its final size.
        let topImageSize = imageViewTop.bounds.size
        let topImageScale = imageViewTop.traitCollection.displayScale
        imageViewTop.image = ImageUtilities.downsample(imageAt: topImageUrl, to: topImageSize, scale: topImageScale)
        
        // Set bottom image view
        guard let botImageUrl = Bundle.main.url(forResource: "help05-bot", withExtension: "png") else {
            fatalError("!!! Could not find help05-bot image !!!")
        }
        imageViewBot.layoutIfNeeded() // Ensure imageView is in its final size.
        let botImageSize = imageViewBot.bounds.size
        let botImageScale = imageViewBot.traitCollection.displayScale
        imageViewBot.image = ImageUtilities.downsample(imageAt: botImageUrl, to: botImageSize, scale: botImageScale)
        
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
        // Unregister all observers
        NotificationCenter.default.removeObserver(self)
    }
}
