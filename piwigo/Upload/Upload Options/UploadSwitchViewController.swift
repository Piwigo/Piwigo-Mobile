//
//  UploadSwitchViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 15/07/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import UIKit
import piwigoKit

@objc
protocol UploadSwitchDelegate: NSObjectProtocol {
    func uploadSettingsDidDisappear()
    func didValidateUploadSettings(with imageParameters:[String:Any], _ uploadParameters:[String:Any])
}

@objc
class UploadSwitchViewController: UIViewController {
    
    @objc weak var delegate: UploadSwitchDelegate?

    private var cancelBarButton: UIBarButtonItem?
    private var uploadBarButton: UIBarButtonItem?
    private var switchViewSegmentedControl = UISegmentedControl(items: [UIImage(named: "imageAll")!,
                                                                        UIImage(named: "settings")!])
    @IBOutlet weak var parametersView: UIView!
    @IBOutlet weak var settingsView: UIView!

    private var _canDeleteImages = false
    @objc var canDeleteImages: Bool {
        get {
            _canDeleteImages
        }
        set(canDeleteImages) {
            _canDeleteImages = canDeleteImages
        }
    }

    private var _hasTagCreationRights = false
    @objc var hasTagCreationRights: Bool {
        get {
            _hasTagCreationRights
        }
        set(canCreateTags) {
            _hasTagCreationRights = canCreateTags
        }
    }

    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Remove space between navigation bar and first cell
        if #available(iOS 12.0, *) {
        } else {
            automaticallyAdjustsScrollViewInsets = false
        }

        // Bar buttons
        cancelBarButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelUpload))
        cancelBarButton?.accessibilityIdentifier = "Cancel"
        uploadBarButton = UIBarButtonItem(title: NSLocalizedString("tabBar_upload", comment: "Upload"), style: .done, target: self, action: #selector(didTapUploadButton))
        
        // Segmented control (choice for presenting common image parameters or upload settings)
        switchViewSegmentedControl = UISegmentedControl(items: [UIImage(named: "imageAll")!,
                                                                UIImage(named: "settings")!])
        if #available(iOS 13.0, *) {
            switchViewSegmentedControl.selectedSegmentTintColor = .piwigoColorOrange()
        } else {
            switchViewSegmentedControl.tintColor = .piwigoColorOrange()
        }
        switchViewSegmentedControl.selectedSegmentIndex = 0
        switchViewSegmentedControl.addTarget(self, action: #selector(didSwitchView), for: .valueChanged)
        switchViewSegmentedControl.superview?.layer.cornerRadius = switchViewSegmentedControl.layer.cornerRadius
        
        // Navigation bar
        navigationController?.navigationBar.accessibilityIdentifier = "UploadSwitchView"
        navigationItem.leftBarButtonItems = [cancelBarButton].compactMap { $0 }
        navigationItem.rightBarButtonItems = [uploadBarButton].compactMap { $0 }
        navigationItem.titleView = switchViewSegmentedControl
        
        // iOS 9 & 10 fix
        if #available(iOS 11, *) {
            parametersView.translatesAutoresizingMaskIntoConstraints = false
        }
    }

    @objc func applyColorPalette() {
        // Background color of the views
        view.backgroundColor = .piwigoColorBackground()

        // Navigation bar
        let attributes = [
            NSAttributedString.Key.foregroundColor: UIColor.piwigoColorWhiteCream(),
            NSAttributedString.Key.font: UIFont.piwigoFontNormal()
        ]
        navigationController?.navigationBar.titleTextAttributes = attributes
        if #available(iOS 11.0, *) {
            navigationController?.navigationBar.prefersLargeTitles = false
        }
        navigationController?.navigationBar.barStyle = AppVars.shared.isDarkPaletteActive ? .black : .default
        navigationController?.navigationBar.tintColor = .piwigoColorOrange()
        navigationController?.navigationBar.barTintColor = .piwigoColorBackground()
        navigationController?.navigationBar.backgroundColor = .piwigoColorBackground()

        if #available(iOS 15.0, *) {
            /// In iOS 15, UIKit has extended the usage of the scrollEdgeAppearance,
            /// which by default produces a transparent background, to all navigation bars.
            let barAppearance = UINavigationBarAppearance()
            barAppearance.configureWithOpaqueBackground()
            barAppearance.backgroundColor = .piwigoColorBackground()
            navigationController?.navigationBar.standardAppearance = barAppearance
            navigationController?.navigationBar.scrollEdgeAppearance = navigationController?.navigationBar.standardAppearance
        }

        // Segmented control
        switchViewSegmentedControl.superview?.backgroundColor = .piwigoColorBackground().withAlphaComponent(0.8)
        if #available(iOS 13.0, *) {
            // Keep standard background color
            switchViewSegmentedControl.overrideUserInterfaceStyle = AppVars.shared.isDarkPaletteActive ? .dark : .light
        } else {
            switchViewSegmentedControl.backgroundColor = UIColor(red: 0.0, green: 0.0, blue: 0.08, alpha: 0.06666)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Set colors, fonts, etc.
        applyColorPalette()

        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: PwgNotifications.paletteChanged, object: nil)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        // Update navigation bar of parent view
        delegate?.uploadSettingsDidDisappear()
    }
    
    deinit {
        // Unregister palette changes
        NotificationCenter.default.removeObserver(self, name: PwgNotifications.paletteChanged, object: nil)
    }

    
    // MARK: - Actions
    @objc func didTapUploadButton() {
        // Pause UploadManager while adding upload requests
        UploadManager.shared.isPaused = true

        // Retrieve custom image parameters and upload settings from child views
        var imageParameters = [String:Any](minimumCapacity: 5)
        var uploadParameters = [String:Any](minimumCapacity: 9)
        children.forEach { (child) in
            
            // Image parameters
            if let paramsCtrl = child as? UploadParametersViewController {
                imageParameters["title"] = paramsCtrl.commonTitle
                imageParameters["author"] = paramsCtrl.commonAuthor
                imageParameters["privacy"] = paramsCtrl.commonPrivacyLevel
                imageParameters["tagIds"] = String(paramsCtrl.commonTags.map({"\($0.tagId),"}).reduce("", +).dropLast(1))
                imageParameters["comment"] = paramsCtrl.commonComment
            }
            
            // Upload settings
            if let settingsCtrl = child as? UploadSettingsViewController {
                uploadParameters["stripGPSdataOnUpload"] = settingsCtrl.stripGPSdataOnUpload
                uploadParameters["resizeImageOnUpload"] = settingsCtrl.resizeImageOnUpload
                uploadParameters["photoMaxSize"] = settingsCtrl.photoMaxSize
                uploadParameters["videoMaxSize"] = settingsCtrl.videoMaxSize
                uploadParameters["compressImageOnUpload"] = settingsCtrl.compressImageOnUpload
                uploadParameters["photoQuality"] = settingsCtrl.photoQuality
                uploadParameters["prefixFileNameBeforeUpload"] = settingsCtrl.prefixFileNameBeforeUpload
                uploadParameters["defaultPrefix"] = settingsCtrl.defaultPrefix
                uploadParameters["deleteImageAfterUpload"] = settingsCtrl.deleteImageAfterUpload
            }
        }

        // Updload images
        delegate?.didValidateUploadSettings(with: imageParameters, uploadParameters)
        dismiss(animated: true)
    }
    
    @objc func cancelUpload() {
        // Return to local images view
        delegate?.uploadSettingsDidDisappear()
        dismiss(animated: true)
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
