//
//  Help03ViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 30/11/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import UIKit

class Help03ViewController: UIViewController {
    
    @IBOutlet weak var legend: UILabel!
    private let helpID: UInt16 = 0b00000000_00000100

    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialise mutable attributed string
        let legendAttributedString = NSMutableAttributedString(string: "")

        // Title
        let titleString = "\(NSLocalizedString("help03_header", comment: "Administrators"))\n"
        let titleAttributedString = NSMutableAttributedString(string: titleString)
        titleAttributedString.addAttribute(.font, value: view.bounds.size.width > 320 ? UIFont.piwigoFontBold() : UIFont.piwigoFontSemiBold(), range: NSRange(location: 0, length: titleString.count))
        legendAttributedString.append(titleAttributedString)

        // Text
        let textString = NSLocalizedString("help03_text", comment: "Create, delete, move and rename albums.")
        let textAttributedString = NSMutableAttributedString(string: textString)
        textAttributedString.addAttribute(.font, value: view.bounds.size.width > 320 ? UIFont.piwigoFontNormal() : UIFont.piwigoFontSmall(), range: NSRange(location: 0, length: textString.count))
        legendAttributedString.append(textAttributedString)

        // Set legend
        legend.attributedText = legendAttributedString
        
        // Remember that this view was watched
        Model.sharedInstance().didWatchHelpViews = Model.sharedInstance().didWatchHelpViews | helpID
        Model.sharedInstance().saveToDisk()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Set colors, fonts, etc.
        applyColorPalette()

        // Register palette changes
        let name: NSNotification.Name = NSNotification.Name(kPiwigoNotificationPaletteChanged)
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette), name: name, object: nil)
    }

    @objc func applyColorPalette() {
        // Background color of the view
        view.backgroundColor = UIColor.piwigoColorBackground()
        
        // Legend color
        legend.textColor = UIColor.piwigoColorText()
    }
}
