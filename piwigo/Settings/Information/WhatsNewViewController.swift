//
//  WhatsNewViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 15/06/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import UIKit

final class WhatsNewViewController: UIViewController {
    
    @IBOutlet weak var titleLabel: UILabel!
    
    @IBOutlet weak var scrollView: UIScrollView!
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
        if #available(iOS 18.0, *) {
            secondNewsImage.image = UIImage(systemName: "photo.badge.plus")
        } else {
            // Fallback on ealier version
            secondNewsImage.image = UIImage(named: "photo.badge.plus")
        }
        firstNewsTitle.text = String(localized: "UploadRequests_cache", comment: "Uploads")
        firstNewsDescription.text = String(localized: "whatsNew_uploads", comment: "Faster uploads, new advanced options, and the ability to resume uploads in the background on iOS 26.")
        
        // What's new — 2nd annoucement
        if #available(iOS 18.0, *) {
            secondNewsImage.image = UIImage(systemName: "ladybug.slash")
        } else {
            // Fallback on ealier version
            secondNewsImage.image = UIImage(named: "ladybug.slash")
        }
        secondNewsTitle.text = String(localized: "whatsNew_improvements", comment: "Improvements")
        secondNewsDescription.text = String(localized: "whatsNew_bugFixes", comment: "Bug fixes and improvement of the interface.")
        
        // Continue button
        continueButton.setTitle(String(localized: "whatsNew_continue", comment: "Continue"), for: .normal)
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
    
    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        self.dismiss(animated: true)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        let diff = scrollView.contentSize.height - scrollView.bounds.height
        if diff > 0 {
            animateScrollView(by: diff)
        }
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
    
    
    // MARK: ScrollView Animation
    private func animateScrollView(by height: CGFloat) {
        Task {
            let scrollDuration = 0.5 + max(0, (height - 20) / 100)
            await animate(duration: scrollDuration) {
                let bottomOffset = CGPoint( x: 0, y: max(0, height))
                self.scrollView.setContentOffset(bottomOffset, animated: false)
            }
            try await Task.sleep(nanoseconds: 300_000_000)

            await animate(duration: scrollDuration) {
                self.scrollView.setContentOffset(.zero, animated: false)
            }
        }
    }
    
    private func animate(duration: TimeInterval, animations: @escaping () -> Void) async {
        await withCheckedContinuation { continuation in
            UIView.animate(withDuration: duration, animations: animations) { _ in
                continuation.resume()
            }
        }
    }
}
