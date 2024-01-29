//
//  WhatsNewViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 15/06/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import UIKit

class WhatsNewViewController: UIViewController {
    
    @IBOutlet weak var titleLabel: UILabel!
    
    @IBOutlet weak var firstNewsImage: UIImageView!
    @IBOutlet weak var firstNewsTitle: UILabel!
    @IBOutlet weak var firstNewsDescription: UILabel!
    
    @IBOutlet weak var secondNewsImage: UIImageView!
    @IBOutlet weak var secondNewsTitle: UILabel!
    @IBOutlet weak var secondNewsDescription: UILabel!
    
    @IBOutlet weak var continueButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Main title
        titleLabel.text = NSLocalizedString("whatsNew_title", comment: "What's New in Piwigo")
        
        // What's new — 1st annoucement
//        if #available(iOS 14.0, *) {
//            firstNewsImage.image = UIImage(systemName: "server.rack")
//        } else {
            // Fallback on ealier version
            firstNewsImage.image = UIImage(named: "whatsNew1")
//        }
        firstNewsTitle.text = NSLocalizedString("whatsNew_title1", comment: "New Gestures")
        firstNewsDescription.text = NSLocalizedString("whatsNew_desc1", comment: "Swipe down or pinch the image to return to the album when viewing individual photos or videos.")
        
        // What's new — 2nd annoucement
        if #available(iOS 13.0, *) {
            secondNewsImage.image = UIImage(systemName: "pip")
        } else {
            // Fallback on ealier version
            secondNewsImage.image = UIImage(named: "whatsNew2")
        }
        secondNewsTitle.text = NSLocalizedString("whatsNew_title2", comment: "PiP Support")
        secondNewsDescription.text = NSLocalizedString("whatsNew_desc2", comment: "Watch a video stored on your Piwigo while you use other apps.")
        
        // Continue button
        continueButton.setTitle(NSLocalizedString("whatsNew_continue", comment: "Continue"), for: .normal)
    }
    
    @objc func applyColorPalette() {
        // Background color of the view
        view.backgroundColor = .piwigoColorBackground()

        // Text color depdends on background color
        titleLabel.textColor = .piwigoColorText()
        firstNewsTitle.textColor = .piwigoColorText()
        firstNewsDescription.textColor = .piwigoColorText()
        secondNewsTitle.textColor = .piwigoColorText()
        secondNewsDescription.textColor = .piwigoColorText()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Set colors, fonts, etc.
        applyColorPalette()
        
        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: .pwgPaletteChanged, object: nil)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate(alongsideTransition: { (context) in
        }, completion: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Remember that we already presented what's new
        if let appVersionString = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
            AppVars.shared.didShowWhatsNewAppVersion = appVersionString
        }
    }

    @IBAction func didTapContinue(_ sender: Any) {
        dismiss(animated: true)
    }
    
    deinit {
        // Unregister all observers
        NotificationCenter.default.removeObserver(self)
    }
}
