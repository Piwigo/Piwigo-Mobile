//
//  UploadSettingsViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 15/07/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//
import piwigoKit

class UploadSettingsViewController: UITableViewController, UITextFieldDelegate {
    
    @IBOutlet var settingsTableView: UITableView!
    
    var stripGPSdataOnUpload = UploadVars.stripGPSdataOnUpload
    var resizeImageOnUpload = UploadVars.resizeImageOnUpload
    var photoMaxSize: Int16 = UploadVars.photoMaxSize
    var videoMaxSize: Int16 = UploadVars.videoMaxSize
    var compressImageOnUpload = UploadVars.compressImageOnUpload
    var photoQuality: Int16 = UploadVars.photoQuality
    var prefixFileNameBeforeUpload = UploadVars.prefixFileNameBeforeUpload
    var defaultPrefix = UploadVars.defaultPrefix
    private var shouldUpdateDefaultPrefix = false
    private var canDeleteImages = false
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
                                               name: PwgNotifications.paletteChanged, object: nil)
        
        // Can we propose to delete images after upload?
        if let switchVC = parent as? UploadSwitchViewController {
            canDeleteImages = switchVC.canDeleteImages
            if canDeleteImages {
                deleteImageAfterUpload = UploadVars.deleteImageAfterUpload
            }
        }
    }

    deinit {
        // Unregister palette changes
        NotificationCenter.default.removeObserver(self, name: PwgNotifications.paletteChanged, object: nil)
    }

    
    // MARK: - UITableView - Header
    private func getContentOfHeader() -> (String, String) {
        let title = String(format: "%@\n", NSLocalizedString("imageUploadHeaderTitle_upload", comment: "Upload Settings"))
        let text = NSLocalizedString("imageUploadHeaderText_upload", comment: "Please set the upload parameters to apply to the selection of photos/videos")
        return (title, text)
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let (title, text) = getContentOfHeader()
        return TableViewUtilities.heightOfHeader(withTitle: title, text: text,
                                                 width: tableView.frame.size.width)
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let (title, text) = getContentOfHeader()
        return TableViewUtilities.viewOfHeader(withTitle: title, text: text)
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.0
    }

    
    // MARK: - UITableView - Rows
    /// Remark: a UIView is added at the bottom of the table view in the storyboard
    /// to eliminate extra separators below the cells.
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 4 + (resizeImageOnUpload ? 2 : 0)
                 + (compressImageOnUpload ? 1 : 0)
                 + (prefixFileNameBeforeUpload ? 1 : 0)
                 + (canDeleteImages ? 1 : 0)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var tableViewCell = UITableViewCell()
        var row = indexPath.row
        row += (!resizeImageOnUpload && (row > 1)) ? 2 : 0
        row += (!compressImageOnUpload && (row > 4)) ? 1 : 0
        row += (!prefixFileNameBeforeUpload && (row > 6)) ? 1 : 0
        switch row {
        case 0 /* Strip private Metadata? */:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchTableViewCell", for: indexPath) as? SwitchTableViewCell else {
                print("Error: tableView.dequeueReusableCell does not return a SwitchTableViewCell!")
                return SwitchTableViewCell()
            }
            // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
            if view.bounds.size.width > 414 {
                // i.e. larger than iPhones 6,7 screen width
                cell.configure(with: NSLocalizedString("settings_stripGPSdata>375px", comment: "Strip Private Metadata Before Upload"))
            } else {
                cell.configure(with: NSLocalizedString("settings_stripGPSdata", comment: "Strip Private Metadata"))
            }
            cell.cellSwitch.setOn(stripGPSdataOnUpload, animated: true)
            cell.cellSwitchBlock = { switchState in
                self.stripGPSdataOnUpload = switchState
            }
            cell.accessibilityIdentifier = "stripMetadataBeforeUpload"
            tableViewCell = cell
            
        case 1 /* Resize Before Upload? */:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchTableViewCell", for: indexPath) as? SwitchTableViewCell else {
                print("Error: tableView.dequeueReusableCell does not return a SwitchTableViewCell!")
                return SwitchTableViewCell()
            }
            cell.configure(with: NSLocalizedString("settings_photoResize", comment: "Resize Before Upload"))
            cell.cellSwitch.setOn(resizeImageOnUpload, animated: true)
            cell.cellSwitchBlock = { switchState in
                // Number of rows will change accordingly
                self.resizeImageOnUpload = switchState
                // Position of the row that should be added/removed
                let photoAtIndexPath = IndexPath(row: 2, section: 0)
                let videoAtIndexPath = IndexPath(row: 3, section: 0)
                if switchState {
                    // Insert row in existing table
                    self.settingsTableView?.insertRows(at: [photoAtIndexPath, videoAtIndexPath], with: .automatic)
                } else {
                    // Remove row in existing table
                    self.settingsTableView?.deleteRows(at: [photoAtIndexPath, videoAtIndexPath], with: .automatic)
                }
            }
            cell.accessibilityIdentifier = "resizeBeforeUpload"
            tableViewCell = cell
            
        case 2 /* Upload Photo Max Size */:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell else {
                print("Error: tableView.dequeueReusableCell does not return a LabelTableViewCell!")
                return LabelTableViewCell()
            }
            cell.configure(with: "… " + NSLocalizedString("severalImages", comment: "Photos"),
                           detail: pwgPhotoMaxSizes(rawValue: photoMaxSize)?.name ?? pwgPhotoMaxSizes(rawValue: 0)!.name)
            cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
            cell.accessibilityIdentifier = "uploadPhotoSize"
            tableViewCell = cell

        case 3 /* Upload Max Video Size */:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell else {
                print("Error: tableView.dequeueReusableCell does not return a LabelTableViewCell!")
                return LabelTableViewCell()
            }
            cell.configure(with: "… " + NSLocalizedString("severalVideos", comment: "Videos"),
                           detail: pwgVideoMaxSizes(rawValue: videoMaxSize)?.name ?? pwgVideoMaxSizes(rawValue: 0)!.name)
            cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
            cell.accessibilityIdentifier = "defaultUploadVideoSize"
            tableViewCell = cell
            
        case 4 /* Compress before Upload? */:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchTableViewCell", for: indexPath) as? SwitchTableViewCell else {
                print("Error: tableView.dequeueReusableCell does not return a SwitchTableViewCell!")
                return SwitchTableViewCell()
            }
            // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
            if view.bounds.size.width > 375 {
                // i.e. larger than iPhones 6,7 screen width
                cell.configure(with: NSLocalizedString("settings_photoCompress>375px", comment: "Compress Image Before Upload"))
            } else {
                cell.configure(with: NSLocalizedString("settings_photoCompress", comment: "Compress Before Upload"))
            }
            cell.cellSwitch.setOn(compressImageOnUpload, animated: true)
            cell.cellSwitchBlock = { switchState in
                // Number of rows will change accordingly
                self.compressImageOnUpload = switchState
                // Position of the row that should be added/removed
                let rowAtIndexPath = IndexPath(row: 3 + (self.resizeImageOnUpload ? 2 : 0), section: 0)
                if switchState {
                    // Insert row in existing table
                    self.settingsTableView?.insertRows(at: [rowAtIndexPath], with: .automatic)
                } else {
                    // Remove row in existing table
                    self.settingsTableView?.deleteRows(at: [rowAtIndexPath], with: .automatic)
                }
            }
            cell.accessibilityIdentifier = "compressBeforeUpload"
            tableViewCell = cell
            
        case 5 /* Image Quality slider */:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "SliderTableViewCell", for: indexPath) as? SliderTableViewCell else {
                print("Error: tableView.dequeueReusableCell does not return a SliderTableViewCell!")
                return SliderTableViewCell()
            }
            // Slider value
            let value = Float(photoQuality)

            // Slider configuration
            let title = String(format: "… %@", NSLocalizedString("settings_photoQuality", comment: "Quality"))
            cell.configure(with: title, value: value, increment: 1, minValue: 50, maxValue: 98, prefix: "", suffix: "%")
            cell.cellSliderBlock = { newValue in
                // Update settings
                self.photoQuality = Int16(newValue)
            }
            cell.accessibilityIdentifier = "compressionRatio"
            tableViewCell = cell
            
        case 6 /* Prefix Filename Before Upload switch */:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchTableViewCell", for: indexPath) as? SwitchTableViewCell else {
                print("Error: tableView.dequeueReusableCell does not return a SwitchTableViewCell!")
                return SwitchTableViewCell()
            }
            // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
            if view.bounds.size.width > 414 {
                // i.e. larger than iPhones 6,7 screen width
                cell.configure(with: NSLocalizedString("settings_prefixFilename>414px", comment: "Prefix Photo Filename Before Upload"))
            } else if view.bounds.size.width > 375 {
                // i.e. larger than iPhones 6,7 screen width
                cell.configure(with: NSLocalizedString("settings_prefixFilename>375px", comment: "Prefix Filename Before Upload"))
            } else {
                cell.configure(with: NSLocalizedString("settings_prefixFilename", comment: "Prefix Filename"))
            }
            cell.cellSwitch.setOn(prefixFileNameBeforeUpload, animated: true)
            cell.cellSwitchBlock = { switchState in
                // Number of rows will change accordingly
                self.prefixFileNameBeforeUpload = switchState
                // Position of the row that should be added/removed
                let rowAtIndexPath = IndexPath(row: 4 + (self.resizeImageOnUpload ? 2 : 0)
                                                      + (self.compressImageOnUpload ? 1 : 0),section: 0)
                if switchState {
                    // Insert row in existing table
                    self.settingsTableView?.insertRows(at: [rowAtIndexPath], with: .automatic)
                } else {
                    // Remove row in existing table
                    self.settingsTableView?.deleteRows(at: [rowAtIndexPath], with: .automatic)
                }
            }
            cell.accessibilityIdentifier = "prefixBeforeUpload"
            tableViewCell = cell
            
        case 7 /* Filename prefix? */:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "TextFieldTableViewCell", for: indexPath) as? TextFieldTableViewCell else {
                print("Error: tableView.dequeueReusableCell does not return a TextFieldTableViewCell!")
                return TextFieldTableViewCell()
            }
            // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
            var title: String
            let input: String = defaultPrefix
            let placeHolder: String = NSLocalizedString("settings_defaultPrefixPlaceholder", comment: "Prefix Filename")
            if view.bounds.size.width > 320 {
                // i.e. larger than iPhone 5 screen width
                title = String(format:"… %@", NSLocalizedString("settings_defaultPrefix>320px", comment: "Filename Prefix"))
            } else {
                title = String(format:"… %@", NSLocalizedString("settings_defaultPrefix", comment: "Prefix"))
            }
            cell.configure(with: title, input: input, placeHolder: placeHolder)
            cell.rightTextField.delegate = self
            cell.rightTextField.tag = kImageUploadSetting.prefix.rawValue
            cell.rightTextField.textColor = shouldUpdateDefaultPrefix ? .piwigoColorOrange() : .piwigoColorRightLabel()
            cell.accessibilityIdentifier = "prefixFileName"
            tableViewCell = cell
            
        case 8 /* Delete image after upload? */:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchTableViewCell", for: indexPath) as? SwitchTableViewCell else {
                print("Error: tableView.dequeueReusableCell does not return a SwitchTableViewCell!")
                return SwitchTableViewCell()
            }
            // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
            if view.bounds.size.width > 414 {
                // i.e. larger than iPhones 6,7 screen width
                cell.configure(with: NSLocalizedString("settings_deleteImage>375px", comment: "Delete Image After Upload"))
            } else {
                cell.configure(with: NSLocalizedString("settings_deleteImage", comment: "Delete After Upload"))
            }
            cell.cellSwitch.setOn(deleteImageAfterUpload, animated: true)
            cell.cellSwitchBlock = { switchState in
                self.deleteImageAfterUpload = switchState
            }
            cell.accessibilityIdentifier = "deleteAfterUpload"
            tableViewCell = cell
            
        default:
            break
        }
    
    tableViewCell.isAccessibilityElement = true
    return tableViewCell
    }

    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        var row = indexPath.row
        row += (!resizeImageOnUpload && (row > 1)) ? 2 : 0
        row += (!compressImageOnUpload && (row > 3)) ? 1 : 0
        row += (!prefixFileNameBeforeUpload && (row > 5)) ? 1 : 0
        switch row {
        case 2 /* Upload Photo Size */,
             3 /* Upload Video Size */:
            return true
        default:
            return false
        }
    }


    // MARK: - UITableViewDelegate Methods
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        var row = indexPath.row
        row += (!resizeImageOnUpload && (row > 1)) ? 2 : 0
        row += (!compressImageOnUpload && (row > 3)) ? 1 : 0
        row += (!prefixFileNameBeforeUpload && (row > 5)) ? 1 : 0
        switch row {
        case 2 /* Upload Photo Size */:
            // Present the Upload Photo Size selector
            let uploadPhotoSizeSB = UIStoryboard(name: "UploadPhotoSizeViewController", bundle: nil)
            guard let uploadPhotoSizeVC = uploadPhotoSizeSB.instantiateViewController(withIdentifier: "UploadPhotoSizeViewController") as? UploadPhotoSizeViewController else { return }
            uploadPhotoSizeVC.delegate = self
            uploadPhotoSizeVC.photoMaxSize = photoMaxSize
            navigationController?.pushViewController(uploadPhotoSizeVC, animated: true)
        case 3 /* Upload Video Size */:
            // Present the Upload Photo Size selector
            let uploadVideoSizeSB = UIStoryboard(name: "UploadVideoSizeViewController", bundle: nil)
            guard let uploadVideoSizeVC = uploadVideoSizeSB.instantiateViewController(withIdentifier: "UploadVideoSizeViewController") as? UploadVideoSizeViewController else { return }
            uploadVideoSizeVC.delegate = self
            uploadVideoSizeVC.videoMaxSize = videoMaxSize
            navigationController?.pushViewController(uploadVideoSizeVC, animated: true)
        default:
            break
        }
    }


    // MARK: - UITextFieldDelegate Methods
    func textFieldDidBeginEditing(_ textField: UITextField) {
        let tag = kImageUploadSetting(rawValue: textField.tag)
        switch tag {
        case .prefix:
            shouldUpdateDefaultPrefix = true
        default:
            break
        }
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // Piwigo 2.10.2 supports the 3-byte UTF-8, not the standard UTF-8 (4 bytes)
        let newString = NetworkUtilities.utf8mb3String(from: string)
        guard let finalString = (textField.text as NSString?)?.replacingCharacters(in: range, with: newString) else {
            return true
        }
        let tag = kImageUploadSetting(rawValue: textField.tag)
        switch tag {
        case .prefix:
            defaultPrefix = finalString
        default:
            break
        }
        return true
    }

    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        let tag = kImageUploadSetting(rawValue: textField.tag)
        switch tag {
        case .prefix:
            defaultPrefix = ""
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
        let tag = kImageUploadSetting(rawValue: textField.tag)
        switch tag {
        case .prefix:
            // Piwigo 2.10.2 supports the 3-byte UTF-8, not the standard UTF-8 (4 bytes)
            defaultPrefix = NetworkUtilities.utf8mb3String(from: textField.text)
            if defaultPrefix == UploadVars.defaultPrefix {
                shouldUpdateDefaultPrefix = false
            }

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
