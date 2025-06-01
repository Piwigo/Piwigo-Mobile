//
//  UploadSettingsViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 15/07/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import UIKit
import piwigoKit
import uploadKit

class UploadSettingsViewController: UITableViewController {
    
    @IBOutlet var settingsTableView: UITableView!
    
    lazy var stripGPSdataOnUpload = UploadVars.shared.stripGPSdataOnUpload
    lazy var resizeImageOnUpload = UploadVars.shared.resizeImageOnUpload
    lazy var photoMaxSize: Int16 = UploadVars.shared.photoMaxSize
    lazy var videoMaxSize: Int16 = UploadVars.shared.videoMaxSize
    lazy var compressImageOnUpload = UploadVars.shared.compressImageOnUpload
    lazy var photoQuality: Int16 = UploadVars.shared.photoQuality
    
    lazy var startValue: Int = UploadVars.shared.counterStartValue
    lazy var prefixBeforeUpload = UploadVars.shared.prefixFileNameBeforeUpload
    lazy var prefixActions: RenameActionList = UploadVars.shared.prefixFileNameActionList.actions
    lazy var replaceBeforeUpload = UploadVars.shared.replaceFileNameBeforeUpload
    lazy var replaceActions: RenameActionList = UploadVars.shared.replaceFileNameActionList.actions
    lazy var suffixBeforeUpload = UploadVars.shared.suffixFileNameBeforeUpload
    lazy var suffixActions: RenameActionList = UploadVars.shared.suffixFileNameActionList.actions
    lazy var changeCaseBeforeUpload: Bool = UploadVars.shared.changeCaseOfFileExtension
    lazy var caseOfFileExtension: FileExtCase = FileExtCase(rawValue: UploadVars.shared.caseOfFileExtension) ?? .uppercase

    var canDeleteImages = false
    var deleteImageAfterUpload = false
    
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Collection view identifier
        settingsTableView.accessibilityIdentifier = "Settings"
    }

    @objc func applyColorPalette() {
        // Background color of the views
        view.backgroundColor = .piwigoColorBackground()

        // Table view
        settingsTableView.separatorColor = .piwigoColorSeparator()
        settingsTableView.indicatorStyle = AppVars.shared.isDarkPaletteActive ? .white : .black
        settingsTableView.reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Set colors, fonts, etc.
        applyColorPalette()

        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: Notification.Name.pwgPaletteChanged, object: nil)
        
        // Can we propose to delete images after upload?
        if let switchVC = parent as? UploadSwitchViewController {
            canDeleteImages = switchVC.canDeleteImages
            if canDeleteImages {
                deleteImageAfterUpload = UploadVars.shared.deleteImageAfterUpload
            }
        }
    }

    deinit {
        // Unregister all observers
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - UploadPhotoSizeDelegate Methods
extension UploadSettingsViewController: UploadPhotoSizeDelegate {
    func didSelectUploadPhotoSize(_ selectedSize: Int16) {
        // Was the size modified?
        if selectedSize != photoMaxSize {
            // Save new choice
            photoMaxSize = selectedSize
            
            // Refresh corresponding row
            let indexPath = IndexPath(row: 2, section: 0)
            settingsTableView.reloadRows(at: [indexPath], with: .automatic)
        }
        
        // Hide rows if needed
        if photoMaxSize == 0, videoMaxSize == 0 {
            resizeImageOnUpload = false
            // Position of the rows which should be removed
            let photoAtIndexPath = IndexPath(row: 2, section: 0)
            let videoAtIndexPath = IndexPath(row: 3, section: 0)
            
            // Remove row in existing table
            settingsTableView?.deleteRows(at: [photoAtIndexPath, videoAtIndexPath], with: .automatic)

            // Refresh flag
            let indexPath = IndexPath(row: 1, section: 0)
            settingsTableView?.reloadRows(at: [indexPath], with: .automatic)
        }
    }
}

// MARK: - UploadVideoSizeDelegate Methods
extension UploadSettingsViewController: UploadVideoSizeDelegate {
    func didSelectUploadVideoSize(_ selectedSize: Int16) {
        // Was the size modified?
        if selectedSize != videoMaxSize {
            // Save new choice
            videoMaxSize = selectedSize
            
            // Refresh corresponding row
            let indexPath = IndexPath(row: 3, section: 0)
            settingsTableView.reloadRows(at: [indexPath], with: .automatic)
        }
        
        // Hide rows if needed
        if photoMaxSize == 0, videoMaxSize == 0 {
            resizeImageOnUpload = false
            // Position of the rows which should be removed
            let photoAtIndexPath = IndexPath(row: 2, section: 0)
            let videoAtIndexPath = IndexPath(row: 3, section: 0)
            
            // Remove row in existing table
            settingsTableView?.deleteRows(at: [photoAtIndexPath, videoAtIndexPath], with: .automatic)

            // Refresh flag
            let indexPath = IndexPath(row: 1, section: 0)
            settingsTableView?.reloadRows(at: [indexPath], with: .automatic)
        }
    }
}

// MARK: - MofifyFilenameDelegate Methods
extension UploadSettingsViewController: MofifyFilenameDelegate {
    func didChangeRenameFileSettings(prefix: Bool, prefixActions: RenameActionList,
                                     replace: Bool, replaceActions: RenameActionList,
                                     suffix: Bool, suffixActions: RenameActionList,
                                     changeCase: Bool, caseOfExtension: FileExtCase,
                                     startValue: Int) {
        // Save settings
        self.startValue = startValue
        self.prefixBeforeUpload = prefix
        self.prefixActions = prefixActions
        self.replaceBeforeUpload = replace
        self.replaceActions = replaceActions
        self.suffixBeforeUpload = suffix
        self.suffixActions = suffixActions
        self.changeCaseBeforeUpload = changeCase
        self.caseOfFileExtension = caseOfExtension
        
        // Update cell
        let indexPath = IndexPath(row: 3 + (resizeImageOnUpload ? 1 : 0)
                                         + (compressImageOnUpload ? 1 : 0),
                                  section: 0)
        if let indexPaths = settingsTableView.indexPathsForVisibleRows, indexPaths.contains(indexPath),
           let cell = settingsTableView.cellForRow(at: indexPath) as? LabelTableViewCell {
            if prefix || replace || suffix || changeCase {
                cell.detailLabel.text = NSLocalizedString("settings_autoUploadEnabled", comment: "On")
            } else {
                cell.detailLabel.text = NSLocalizedString("settings_autoUploadDisabled", comment: "Off")
            }
        }
    }
}
