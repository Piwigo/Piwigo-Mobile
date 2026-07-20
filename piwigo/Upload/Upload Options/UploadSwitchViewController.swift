//
//  UploadSwitchViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 15/07/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import UIKit
import CoreData
import PwgKit
import PwgCacheKit
import PwgUIKit
import PwgUploadKit

@objc protocol UploadSwitchDelegate: NSObjectProtocol {
    func didSelectCurrentCounter(value: Int64)
    func uploadOptionsViewDidDisappear(withUploadsQueued: Bool)
}

final class UploadSwitchViewController: UIViewController {
    
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
    var uploadRequests = [UploadProperties]()       // Array of upload requests
    var uploadsQueued = false
    
    
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
        switchViewSegmentedControl.overrideUserInterfaceStyle = UIVars.shared.isDarkPaletteActive ? .dark : .light
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
        super.viewDidDisappear(animated)

        // Update navigation bar of parent view
        delegate?.uploadOptionsViewDidDisappear(withUploadsQueued: uploadsQueued)

        // Delete files copied by the share extension when their upload was not queued,
        // i.e. when the view was dismissed with the Cancel button or a swipe down
        // (the check on isBeingDismissed excludes disappearances due to pushed views)
        if uploadsQueued { return }
        if isBeingDismissed || navigationController?.isBeingDismissed == true {
            let sharedIDs = uploadRequests.map(\.localIdentifier).filter({ $0.hasPrefix(kSharedPrefix) })
            if sharedIDs.isEmpty { return }
            Task(priority: .utility) {
                let fileManager = FileManager.default
                for identifier in sharedIDs {
                    let fileURL = DataDirectories.appUploadsDirectory.appendingPathComponent(identifier)
                    try? fileManager.removeItem(at: fileURL)
                    try? fileManager.removeItem(at: fileURL.appendingPathExtension("json"))
                }
            }
        }
    }
    
    deinit {
        // Unregister all observers
        NotificationCenter.default.removeObserver(self)
    }

    
    // MARK: - Actions
    @MainActor
    @objc func didTapUploadButton() {
        // Show HUD during upload preparation
        self.navigationController?.showHUD(withTitle: Localized.preparingUploads, minWidth: 200)
        
        // Retrieve custom image parameters and upload settings from child views
        children.forEach { (child) in
            
            // Image parameters
            if let paramsCtrl = child as? UploadParametersViewController {
                for index in 0..<uploadRequests.count {
                    // Initialisation
                    var updatedRequest = uploadRequests[index]
                    
                    // Apply choices
                    updatedRequest.imageTitle = paramsCtrl.commonTitle
                    updatedRequest.author = paramsCtrl.commonAuthor
                    updatedRequest.privacyLevel = paramsCtrl.commonPrivacyLevel
                    let tagIDs: String = paramsCtrl.commonTags.map({"\($0.tagId),"}).reduce("", +)
                    updatedRequest.tagIds = String(tagIDs.dropLast(1))
                    updatedRequest.comment = paramsCtrl.commonComment
                    
                    // Store updated upload request
                    uploadRequests[index] = updatedRequest
                }
            }
            
            // Upload settings
            if let settingsCtrl = child as? UploadSettingsViewController {
                for index in 0..<uploadRequests.count {
                    // Initialisation
                    var updatedRequest = uploadRequests[index]
                    
                    // Apply choices: Image file name
                    delegate?.didSelectCurrentCounter(value: settingsCtrl.currentCounter)
                    if settingsCtrl.prefixBeforeUpload {
                        updatedRequest.fileNamePrefixEncodedActions = settingsCtrl.prefixActions.encodedString
                    } else {
                        updatedRequest.fileNamePrefixEncodedActions = ""
                    }
                    if settingsCtrl.replaceBeforeUpload {
                        updatedRequest.fileNameReplaceEncodedActions = settingsCtrl.replaceActions.encodedString
                    } else {
                        updatedRequest.fileNameReplaceEncodedActions = ""
                    }
                    if settingsCtrl.suffixBeforeUpload {
                        updatedRequest.fileNameSuffixEncodedActions = settingsCtrl.suffixActions.encodedString
                    } else {
                        updatedRequest.fileNameSuffixEncodedActions = ""
                    }
                    updatedRequest.fileNameExtensionCase = settingsCtrl.caseOfFileExtension.rawValue
                    
                    // Upload settings
                    updatedRequest.stripGPSdataOnUpload = settingsCtrl.stripGPSdataOnUpload
                    updatedRequest.resizeImageOnUpload = settingsCtrl.resizeImageOnUpload
                    if settingsCtrl.resizeImageOnUpload {
                        updatedRequest.photoMaxSize = settingsCtrl.photoMaxSize
                        updatedRequest.videoMaxSize = settingsCtrl.videoMaxSize
                    } else {    // No downsizing
                        updatedRequest.photoMaxSize = 0
                        updatedRequest.videoMaxSize = 0
                    }
                    updatedRequest.compressImageOnUpload = settingsCtrl.compressImageOnUpload
                    updatedRequest.photoQuality = settingsCtrl.photoQuality
                    updatedRequest.deleteImageAfterUpload = settingsCtrl.deleteImageAfterUpload

                    // Store updated upload request
                    uploadRequests[index] = updatedRequest
                }
            }
        }
        
        // Queue upload requests and start uploads
        Task(priority: .utility) { @UploadManagerActor in
            do {
                // Create upload requests in cache
                /// Cells switch to the "waiting" upload state and are "automatically" deselected visually
                let uploadIDs = try await UploadManager.shared.importUploads(from: self.uploadRequests)
                
                // Add upload requests to queue
                UploadVars.shared.isPaused = false
                #if os(iOS) && !targetEnvironment(macCatalyst)
                if #available(iOS 26.0, *) {
                    // Launch new continued upload task if possible
                    UploadManager.shared.runContinuedUploadTask()
                }
                else {
                    // Queue uploads to prepare
                    await UploadManagerActor.shared.addUploadsToPrepare(withIDs: uploadIDs)
                    
                    // Process next uploads if possible
                    await UploadManagerActor.shared.processNextUpload()
                }
                #elseif targetEnvironment(macCatalyst)
                // Queue uploads to prepare
                await UploadManagerActor.shared.addUploadsToPrepare(withIDs: uploadIDs)
                
                // Process next uploads if possible
                await UploadManagerActor.shared.processNextUpload()
                #endif
                
                // Close HUD and dismiss view, returning to:
                /// - the album of local images if called from the main app
                /// - the destination album if called from the share extension
                await MainActor.run {
                    self.navigationController?.hideHUD {
                        // Dismiss view
                        self.uploadsQueued = true
                        self.dismiss(animated: true)
                    }
                }
            }
            catch {
                await MainActor.run {
                    self.navigationController?.hideHUD {
                        // Inform user
                        let title = PwgKitError.uploadCreationError.localizedDescription
                        self.dismissPiwigoError(withTitle: title, message: error.localizedDescription) {
                            // Resume upload operations in background queue
                            UploadVars.shared.isPaused = false
                            Task(priority: .utility) { @UploadManagerActor in
                                #if os(iOS) && !targetEnvironment(macCatalyst)
                                if #available(iOS 26.0, *) {
                                    // Launch new continued upload task if possible
                                    UploadManager.shared.runContinuedUploadTask()
                                }
                                else {
                                    // Process next uploads if possible
                                    await UploadManagerActor.shared.processNextUpload()
                                }
                                #elseif targetEnvironment(macCatalyst)
                                // Process next uploads if possible
                                await UploadManagerActor.shared.processNextUpload()
                                #endif
                            }
                        }
                        
                        // Dismiss view
                        self.uploadsQueued = false
                        self.dismiss(animated: true)
                    }
                }
            }
        }
    }
    
    @objc func cancelUpload() {
        // Return to:
        /// - the album of local images if called from the main app
        /// - the destination album if called from the share extension
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
