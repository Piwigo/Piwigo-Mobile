//
//  Help04ViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 28/12/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import UIKit

class Help04ViewController: UIViewController {
    
    @IBOutlet weak var legend: UILabel!
    private let helpID: UInt16 = 0b00000000_00001000

    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialise mutable attributed string
        let legendAttributedString = NSMutableAttributedString(string: "")

        // Title
        let titleString = "\(NSLocalizedString("localImages_deleteTitle", comment: "Remove from Camera Roll"))\n"
        let titleAttributedString = NSMutableAttributedString(string: titleString)
        titleAttributedString.addAttribute(.font, value: view.bounds.size.width > 320 ? UIFont.piwigoFontBold() : UIFont.piwigoFontSemiBold(), range: NSRange(location: 0, length: titleString.count))
        legendAttributedString.append(titleAttributedString)

        // Text
        let textString = NSLocalizedString("help04_text", comment: "Message explaining what happens")
        let textAttributedString = NSMutableAttributedString(string: textString)
        textAttributedString.addAttribute(.font, value: view.bounds.size.width > 320 ? UIFont.piwigoFontNormal() : UIFont.piwigoFontSmall(), range: NSRange(location: 0, length: textString.count))
        legendAttributedString.append(textAttributedString)

        // Set legend
        legend.attributedText = legendAttributedString
        
        // Remember that this view was watched
        AppVars.shared.didWatchHelpViews = AppVars.shared.didWatchHelpViews | helpID
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
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        // Unregister palette changes
        NotificationCenter.default.removeObserver(self, name: PwgNotifications.paletteChanged, object: nil)
    }
}
