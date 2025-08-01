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
        if #available(iOS 13.0, *) {
            firstNewsImage.image = UIImage(systemName: "play.rectangle")
        } else {
            // Fallback on ealier version
            firstNewsImage.image = UIImage(named: "video")
        }
//        firstNewsTitle.text = NSLocalizedString("whatsNew_title1", comment: "Group Photos")
        firstNewsTitle.text = NSLocalizedString("singleVideo", comment: "Video")
        firstNewsDescription.text = NSLocalizedString("whatsNew_desc1", comment: "Auto-play and loop options")
        
        // What's new — 2nd annoucement
        if #available(iOS 14.5, *) {
            secondNewsImage.image = UIImage(systemName: "character.cursor.ibeam")
        } else {
            // Fallback on ealier version
            secondNewsImage.image = UIImage(named: "character.cursor.ibeam")
        }
        secondNewsTitle.text = NSLocalizedString("whatsNew_title2", comment: "Rename Files")
        secondNewsDescription.text = NSLocalizedString("whatsNew_desc2", comment: "Before uploading with creation date, counter, album ID, text…")
        
        // Continue button
        continueButton.setTitle(NSLocalizedString("whatsNew_continue", comment: "Continue"), for: .normal)
        if #available(iOS 13.0, *) {
            continueButton.layer.cornerCurve = .continuous
        }
    }
    
    override func updateViewConstraints() {
        if #available(iOS 13.0, *) {
            // Distance to top introduced in iOS 13 for modal controllers
            var TOP_CARD_DISTANCE: CGFloat = 40.0
            if #available(iOS 16.0, *) {
                TOP_CARD_DISTANCE += view.safeAreaInsets.bottom
            }
            
            // Calculate width
            var width = titleLabel.frame.width + 120.0
            let orientation = view.window?.windowScene?.interfaceOrientation ?? .portrait
            if UIDevice.current.userInterfaceIdiom == .phone, orientation == .portrait {
                width = view.bounds.width
            }
            view.frame.size.width = min(view.bounds.width, width)

            // Calculate height of everything inside that view
            var height: CGFloat = 50.0
            height += titleLabel.frame.height
            height += 80.0
            stackView.subviews.forEach { subView in
                height += subView.frame.height
            }
            height += 80.0
            height += continueButton.frame.height
            height += 30.0
            view.frame.size.height = min(view.bounds.height, height)
            
            // Reposition the view (if not it will be near the top)
            if UIDevice.current.userInterfaceIdiom == .phone {
                view.frame.origin.x = max(0, (UIScreen.main.bounds.width - width) / 2.0)
                view.frame.origin.y = max(0, UIScreen.main.bounds.height - height - TOP_CARD_DISTANCE)
            }
            
            // Apply corner radius only to top corners
            let mask = CAShapeLayer()
            let path = UIBezierPath(roundedRect: view.bounds, cornerRadius: 40.0)
            mask.path = path.cgPath
            mask.cornerCurve = .continuous
            view.layer.mask = mask
        }
        
        // Update constraints
        super.updateViewConstraints()
    }
    
    @MainActor
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
