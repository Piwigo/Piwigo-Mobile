//
//  Help06ViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 31/12/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import UIKit
import piwigoKit

class Help06ViewController: UIViewController {
    
    @IBOutlet weak var legend: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    private let helpID: UInt16 = 0b00000000_00100000

    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialise mutable attributed string
        let legendAttributedString = NSMutableAttributedString(string: "")

        // Title
        let titleString = "\(NSLocalizedString("help06_header", comment: "Upload Management"))\n"
        let titleAttributedString = NSMutableAttributedString(string: titleString)
        titleAttributedString.addAttribute(.font, value: view.bounds.size.width > 320 ? UIFont.piwigoFontBold() : UIFont.piwigoFontSemiBold(), range: NSRange(location: 0, length: titleString.count))
        legendAttributedString.append(titleAttributedString)

        // Text
        let textString = NSLocalizedString("help06_text", comment: "How to manage upload requests")
        let textAttributedString = NSMutableAttributedString(string: textString)
        textAttributedString.addAttribute(.font, value: view.bounds.size.width > 320 ? UIFont.piwigoFontNormal() : UIFont.piwigoFontSmall(), range: NSRange(location: 0, length: textString.count))
        legendAttributedString.append(textAttributedString)

        // Set legend
        legend.attributedText = legendAttributedString
        
        // Set image view
        guard let imageUrl = Bundle.main.url(forResource: "help06", withExtension: "png") else {
            fatalError("!!! Could not find help06 image !!!")
        }
        imageView.layoutIfNeeded() // Ensure imageView is in its final size.
        let size = imageView.bounds.size
        let scale = imageView.traitCollection.displayScale
        imageView.image = ImageUtilities.downsample(imageAt: imageUrl, to: size, scale: scale)
        
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
        legend.textColor = UIColor.piwigoColorText()
    }
    
    deinit {
        // Unregister palette changes
        NotificationCenter.default.removeObserver(self, name: PwgNotifications.paletteChanged, object: nil)
    }
}
