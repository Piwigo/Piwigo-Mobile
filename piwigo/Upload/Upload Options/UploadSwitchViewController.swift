//
//  UploadSwitchViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 15/07/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import UIKit

@objc
protocol UploadSwitchDelegate: NSObjectProtocol {
    func didValidateUploadSettings(with imageParameters:[String:Any])
}

class UploadSwitchViewController: UIViewController {
    
    @objc weak var delegate: UploadSwitchDelegate?

    private var cancelBarButton: UIBarButtonItem?
    private var uploadBarButton: UIBarButtonItem?
    private var switchViewSegmentedControl = UISegmentedControl.init(items: [UIImage.init(named: "imageAll")!,
                                                                             UIImage.init(named: "settings")!])
    @IBOutlet weak var parametersView: UIView!
    @IBOutlet weak var settingsView: UIView!

    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Bar buttons
        cancelBarButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(quitUpload))
        cancelBarButton?.accessibilityIdentifier = "Cancel"
        uploadBarButton = UIBarButtonItem(title: NSLocalizedString("tabBar_upload", comment: "Upload"), style: .done, target: self, action: #selector(didTapUploadButton))
        
        // Segmented control (choice for presenting common image parameters or upload settings)
        switchViewSegmentedControl = UISegmentedControl.init(items: [UIImage.init(named: "imageAll")!, UIImage.init(named: "settings")!])
        if #available(iOS 13.0, *) {
            switchViewSegmentedControl.selectedSegmentTintColor = UIColor.piwigoColorOrange()
        } else {
            switchViewSegmentedControl.tintColor = UIColor.piwigoColorOrange()
        }
        switchViewSegmentedControl.selectedSegmentIndex = 0
        switchViewSegmentedControl.addTarget(self, action: #selector(didSwitchView), for: .valueChanged)
        switchViewSegmentedControl.superview?.layer.cornerRadius = switchViewSegmentedControl.layer.cornerRadius
        
        // Navigation bar
        navigationController?.navigationBar.accessibilityIdentifier = "UploadSwitchView"
        navigationItem.leftBarButtonItems = [cancelBarButton].compactMap { $0 }
        navigationItem.rightBarButtonItems = [uploadBarButton].compactMap { $0 }
        navigationItem.titleView = switchViewSegmentedControl
    }

    @objc func applyColorPalette() {
        // Background color of the views
        view.backgroundColor = UIColor.piwigoColorBackground()

        // Navigation bar
        let attributes = [
            NSAttributedString.Key.foregroundColor: UIColor.piwigoColorWhiteCream(),
            NSAttributedString.Key.font: UIFont.piwigoFontNormal()
        ]
        navigationController?.navigationBar.titleTextAttributes = attributes
        if #available(iOS 11.0, *) {
            navigationController?.navigationBar.prefersLargeTitles = false
        }
        navigationController?.navigationBar.barStyle = Model.sharedInstance().isDarkPaletteActive ? .black : .default
        navigationController?.navigationBar.tintColor = UIColor.piwigoColorOrange()
        navigationController?.navigationBar.barTintColor = UIColor.piwigoColorBackground()
        navigationController?.navigationBar.backgroundColor = UIColor.piwigoColorBackground()

        // Segmented control
        switchViewSegmentedControl.superview?.backgroundColor = UIColor.piwigoColorBackground().withAlphaComponent(0.8)
        if #available(iOS 13.0, *) {
            // Keep standard background color
            switchViewSegmentedControl.overrideUserInterfaceStyle = Model.sharedInstance().isDarkPaletteActive ? .dark : .light
        } else {
            switchViewSegmentedControl.backgroundColor = UIColor(red: 0.0, green: 0.0, blue: 0.08, alpha: 0.06666)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Set colors, fonts, etc.
        applyColorPalette()

        // Register palette changes
        let name: NSNotification.Name = NSNotification.Name(kPiwigoNotificationPaletteChanged)
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette), name: name, object: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Unregister palette changes
        let name: NSNotification.Name = NSNotification.Name(kPiwigoNotificationPaletteChanged)
        NotificationCenter.default.removeObserver(self, name: name, object: nil)
    }

    
    // MARK: - Actions
    @objc func quitUpload() {
        // Leave popover view
        dismiss(animated: true)
    }

    @objc func didTapUploadButton() {
        print("didTapUpload")
        // Retrieve custom image parameters and upload settings from child views
        var imageParameters = [String:Any].init(minimumCapacity: 5)
        children.forEach { (child) in
            // Image parameters
            if let paramsCtrl = child as? UploadParametersViewController {
                imageParameters["title"] = paramsCtrl.commonTitle
                imageParameters["author"] = paramsCtrl.commonAuthor
                imageParameters["privacy"] = paramsCtrl.commonPrivacyLevel
                imageParameters["tagIds"] = String(paramsCtrl.commonTags.map({"\($0.tagId),"}).reduce("", +).dropLast(1))
                imageParameters["comment"] = paramsCtrl.commonComment
            }
        }

        // Updload images
        if delegate?.responds(to: #selector(LocalImagesViewController.didValidateUploadSettings(with:))) ?? false {
            delegate?.didValidateUploadSettings(with: imageParameters)
        }
    }
    
    @objc func didSwitchView() {
        switch switchViewSegmentedControl.selectedSegmentIndex {
        case 0:
            settingsView.isHidden = true
            parametersView.isHidden = false
        case 1:
            settingsView.isHidden = false
            parametersView.isHidden = true
        default:
            break;
        }
    }
}
