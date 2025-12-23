//
//  UploadSwitchViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 15/07/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import UIKit
import CoreData
import piwigoKit
import uploadKit

@objc protocol UploadSwitchDelegate: NSObjectProtocol {
    func uploadSettingsDidDisappear()
    func didValidateUploadSettings(with imageParameters:[String:Any], _ uploadParameters:[String:Any])
}

class UploadSwitchViewController: UIViewController {
    
    weak var delegate: (any UploadSwitchDelegate)?

    private var cancelBarButton: UIBarButtonItem?
    private var uploadBarButton: UIBarButtonItem?
    private var switchViewSegmentedControl = {
        let segmentedCtrl = UISegmentedControl(items: [UIImage(systemName: "photo.on.rectangle.angled")!,
                                                       UIImage(systemName: "gear")!])
        segmentedCtrl.accessibilityIdentifier = "org.piwigo.upload.switch"
        segmentedCtrl.selectedSegmentIndex = 0
        return segmentedCtrl
    }()
    @IBOutlet weak var parametersView: UIView!
    @IBOutlet weak var settingsView: UIView!

    var categoryId: Int32 = AlbumVars.shared.defaultCategory
    var categoryCurrentCounter: Int64 = UploadVars.shared.categoryCounterInit
    var canDeleteImages = false
    

    // MARK: - Core Data Objects
    var user: User!


    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Bar buttons
        cancelBarButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelUpload))
        cancelBarButton?.accessibilityIdentifier = "Cancel"
        if #available(iOS 17.0, *) {
            uploadBarButton = UIBarButtonItem(image: UIImage(systemName: "arrowshape.up.fill"),
                                              style: .plain, target: self, action: #selector(didTapUploadButton))
        } else {
            // Fallback on previous version
            uploadBarButton = UIBarButtonItem(image: UIImage(named: "arrowshape.up.fill"),
                                              style: .plain, target: self, action: #selector(didTapUploadButton))
        }

        // Segmented control (choice for presenting common image parameters or upload settings)
        switchViewSegmentedControl.addTarget(self, action: #selector(didSwitchView), for: .valueChanged)
        switchViewSegmentedControl.superview?.layer.cornerRadius = switchViewSegmentedControl.layer.cornerRadius
        
        // Navigation bar
        navigationController?.navigationBar.accessibilityIdentifier = "org.piwigo.upload.switchView"
        navigationItem.leftBarButtonItems = [cancelBarButton].compactMap { $0 }
        navigationItem.rightBarButtonItems = [uploadBarButton].compactMap { $0 }
        navigationItem.titleView = switchViewSegmentedControl
        
        parametersView.translatesAutoresizingMaskIntoConstraints = false
    }

    @MainActor
    @objc func applyColorPalette() {
        // Background color of the views
        view.backgroundColor = PwgColor.background

        // Navigation bar
        navigationController?.navigationBar.configAppearance(withLargeTitles: false)

        // Segmented control
        switchViewSegmentedControl.selectedSegmentTintColor = PwgColor.tintColor
        switchViewSegmentedControl.superview?.backgroundColor = PwgColor.background.withAlphaComponent(0.8)
        switchViewSegmentedControl.overrideUserInterfaceStyle = AppVars.shared.isDarkPaletteActive ? .dark : .light
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Set colors, fonts, etc.
        applyColorPalette()

        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: Notification.Name.pwgPaletteChanged, object: nil)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        // Update navigation bar of parent view
        delegate?.uploadSettingsDidDisappear()
    }
    
    deinit {
        // Unregister all observers
        NotificationCenter.default.removeObserver(self)
    }

    
    // MARK: - Actions
    @objc func didTapUploadButton() {
        // Pause UploadManager while adding upload requests
        UploadVars.shared.isPaused = true

        // Retrieve custom image parameters and upload settings from child views
        var imageParameters = [String:Any](minimumCapacity: 5)
        var uploadParameters = [String:Any](minimumCapacity: 12)
        children.forEach { (child) in
            
            // Image parameters
            if let paramsCtrl = child as? UploadParametersViewController {
                imageParameters["title"] = paramsCtrl.commonTitle
                imageParameters["author"] = paramsCtrl.commonAuthor
                imageParameters["privacy"] = paramsCtrl.commonPrivacyLevel
                let tagIDs: String = paramsCtrl.commonTags.map({"\($0.tagId),"}).reduce("", +)
                imageParameters["tagIds"] = String(tagIDs.dropLast(1))
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
                uploadParameters["currentCounter"] = settingsCtrl.currentCounter
                if settingsCtrl.prefixBeforeUpload {
                    uploadParameters["prefixActions"] = settingsCtrl.prefixActions
                } else {
                    uploadParameters["prefixActions"] = []
                }
                if settingsCtrl.replaceBeforeUpload {
                    uploadParameters["replaceActions"] = settingsCtrl.replaceActions
                } else {
                    uploadParameters["replaceActions"] = []
                }
                if settingsCtrl.suffixBeforeUpload {
                    uploadParameters["suffixActions"] = settingsCtrl.suffixActions
                } else {
                    uploadParameters["suffixActions"] = []
                }
                if settingsCtrl.changeCaseBeforeUpload {
                    uploadParameters["caseOfFileExtension"] = settingsCtrl.caseOfFileExtension
                } else {
                    uploadParameters["caseOfFileExtension"] = FileExtCase.keep
                }
                uploadParameters["deleteImageAfterUpload"] = settingsCtrl.deleteImageAfterUpload
            }
        }

        // Updload images
        delegate?.didValidateUploadSettings(with: imageParameters, uploadParameters)
        dismiss(animated: true)
    }
    
    @objc func cancelUpload() {
        // Return to local images view
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
