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

class UploadSettingsViewController: UITableViewController, UITextFieldDelegate {
    
    private enum TextFieldTag : Int {
        case prefix
    }

    @IBOutlet var settingsTableView: UITableView!
    
    var stripGPSdataOnUpload = UploadVars.shared.stripGPSdataOnUpload
    var resizeImageOnUpload = UploadVars.shared.resizeImageOnUpload
    var photoMaxSize: Int16 = UploadVars.shared.photoMaxSize
    var videoMaxSize: Int16 = UploadVars.shared.videoMaxSize
    var compressImageOnUpload = UploadVars.shared.compressImageOnUpload
    var photoQuality: Int16 = UploadVars.shared.photoQuality
    var prefixFileNameBeforeUpload = UploadVars.shared.prefixFileNameBeforeUpload
    var prefixActions = UploadVars.shared.prefixFileNameActionList.actions
    var replaceFileNameBeforeUpload = UploadVars.shared.replaceFileNameBeforeUpload
    var replaceActions = UploadVars.shared.replaceFileNameActionList.actions
    var suffixFileNameBeforeUpload = UploadVars.shared.suffixFileNameBeforeUpload
    var suffixActions = UploadVars.shared.suffixFileNameActionList.actions
    var changeCaseOfFileExtension = UploadVars.shared.changeCaseOfFileExtension
    var shouldUpdateDefaultPrefix = false
    var canDeleteImages = false
    var deleteImageAfterUpload = false

    func isRenameFileAtive() -> Bool {
        let hasPrefix = UploadVars.shared.prefixFileNameBeforeUpload
        let hasReplace = UploadVars.shared.replaceFileNameBeforeUpload
        let hasSuffix = UploadVars.shared.suffixFileNameBeforeUpload
        let changeCase = UploadVars.shared.changeCaseOfFileExtension
        return hasPrefix || hasReplace || hasSuffix || changeCase
    }
    
    
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


    // MARK: - UITextFieldDelegate Methods
    func textFieldDidBeginEditing(_ textField: UITextField) {
        switch TextFieldTag(rawValue: textField.tag) {
        case .prefix:
            shouldUpdateDefaultPrefix = true
        default:
            break
        }
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // Piwigo 2.10.2 supports the 3-byte UTF-8, not the standard UTF-8 (4 bytes)
        let newString = PwgSession.utf8mb3String(from: string)
        guard let finalString = (textField.text as NSString?)?.replacingCharacters(in: range, with: newString) else {
            return true
        }
        switch TextFieldTag(rawValue: textField.tag) {
        case .prefix:
//            defaultPrefix = finalString
            break
        default:
            break
        }
        return true
    }

    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        switch TextFieldTag(rawValue: textField.tag) {
        case .prefix:
//            defaultPrefix = ""
            break
        default:
            break
        }
        return true
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        settingsTableView?.endEditing(true)
        return true
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        switch TextFieldTag(rawValue: textField.tag) {
        case .prefix:
            // Piwigo 2.10.2 supports the 3-byte UTF-8, not the standard UTF-8 (4 bytes)
//            defaultPrefix = PwgSession.utf8mb3String(from: textField.text)
//            if defaultPrefix == UploadVars.shared.defaultPrefix {
//                shouldUpdateDefaultPrefix = false
//            }

            // Update cell
            let indexPath = IndexPath(row: 3 + (resizeImageOnUpload ? 1 : 0)
                                             + (compressImageOnUpload ? 1 : 0)
                                             + (prefixFileNameBeforeUpload ? 1 : 0),
                                      section: 0)
            settingsTableView.reloadRows(at: [indexPath], with: .automatic)
        default:
            break
        }
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
