//
//  Help04ViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 28/12/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import UIKit
import piwigoKit

class Help04ViewController: UIViewController {
    
    @IBOutlet weak var legend: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    private let helpID: UInt16 = 0b00000000_00001000

    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialise mutable attributed string
        let legendAttributedString = NSMutableAttributedString(string: "")

        // Title
        let titleString = NSLocalizedString("localImages_deleteTitle", comment: "Remove from Camera Roll") + "\n"
        let titleAttributedString = NSMutableAttributedString(string: titleString)
        titleAttributedString.addAttribute(.font, value: view.bounds.size.width > 320 ? UIFont.systemFont(ofSize: 17, weight: .bold) : UIFont.systemFont(ofSize: 17, weight: .semibold), range: NSRange(location: 0, length: titleString.count))
        legendAttributedString.append(titleAttributedString)

        // Text
        let textString = NSLocalizedString("help04_text", comment: "Message explaining what happens")
        let textAttributedString = NSMutableAttributedString(string: textString)
        textAttributedString.addAttribute(.font, value: view.bounds.size.width > 320 ? UIFont.systemFont(ofSize: 17) : UIFont.systemFont(ofSize: 13), range: NSRange(location: 0, length: textString.count))
        legendAttributedString.append(textAttributedString)

        // Set legend
        legend.attributedText = legendAttributedString
        
        // Set image view
        guard let imageUrl = Bundle.main.url(forResource: "help04", withExtension: "png") else {
            fatalError("!!! Could not find help04 image !!!")
        }
        imageView.layoutIfNeeded() // Ensure imageView is in its final size.
        let size = imageView.bounds.size
        let scale = imageView.traitCollection.displayScale
        imageView.image = ImageUtilities.downsample(imageAt: imageUrl, to: size, scale: scale)
        
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
        legend.textColor = .piwigoColorText()
    }
    
    deinit {
        // Unregister all observers
        NotificationCenter.default.removeObserver(self)
    }
}
