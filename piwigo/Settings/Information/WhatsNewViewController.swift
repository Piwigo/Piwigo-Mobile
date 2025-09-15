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
    
    @IBOutlet weak var stackView: UIStackView!
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
        firstNewsImage.image = UIImage(named: "document.pdf")
        firstNewsImage.tintColor = PwgColor.orange
        firstNewsTitle.text = NSLocalizedString("whatsNew_title1", comment: "PDF Files")
        firstNewsDescription.text = NSLocalizedString("whatsNew_desc1", comment: "Read and share PDF files directly")
        
        // What's new — 2nd annoucement
        if #available(iOS 18.0, *) {
            secondNewsImage.image = UIImage(systemName: "ladybug.slash")
        } else {
            // Fallback on ealier version
            secondNewsImage.image = UIImage(named: "ladybug.slash")
        }
        secondNewsImage.tintColor = PwgColor.orange
        secondNewsTitle.text = NSLocalizedString("whatsNew_title2", comment: "Stability")
        secondNewsDescription.text = NSLocalizedString("whatsNew_desc2", comment: "Bug fixes and improvement of the interface")
        
        // Continue button
        continueButton.setTitle(NSLocalizedString("whatsNew_continue", comment: "Continue"), for: .normal)
        continueButton.layer.cornerCurve = .continuous
    }
    
    @MainActor
    @objc func applyColorPalette() {
        // Background color of the view
        view.backgroundColor = PwgColor.background

        // Text color depdends on background color
        titleLabel.textColor = PwgColor.text
        firstNewsTitle.textColor = PwgColor.text
        firstNewsDescription.textColor = PwgColor.text
        secondNewsTitle.textColor = PwgColor.text
        secondNewsDescription.textColor = PwgColor.text
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Set colors, fonts, etc.
        applyColorPalette()
        
        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: Notification.Name.pwgPaletteChanged, object: nil)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        self.dismiss(animated: true)
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
