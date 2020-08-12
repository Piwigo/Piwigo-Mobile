//
//  UploadSettingsViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 15/07/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

class UploadSettingsViewController: UITableViewController, UITextFieldDelegate {
    
    @IBOutlet var settingsTableView: UITableView!
    
    var stripGPSdataOnUpload = Model.sharedInstance().stripGPSdataOnUpload
    var resizeImageOnUpload = Model.sharedInstance().resizeImageOnUpload
    var photoResize = Model.sharedInstance().photoResize
    var compressImageOnUpload = Model.sharedInstance().compressImageOnUpload
    var photoQuality = Model.sharedInstance().photoQuality
    var prefixFileNameBeforeUpload = Model.sharedInstance().prefixFileNameBeforeUpload
    var defaultPrefix = Model.sharedInstance().defaultPrefix ?? ""
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
        view.backgroundColor = UIColor.piwigoColorBackground()

        // Table view
        settingsTableView.indicatorStyle = Model.sharedInstance().isDarkPaletteActive ? .white : .black
        settingsTableView.reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Set colors, fonts, etc.
        applyColorPalette()

        // Register palette changes
        let name: NSNotification.Name = NSNotification.Name(kPiwigoNotificationPaletteChanged)
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette), name: name, object: nil)
        
        // Can we propose to delete images after upload?
        if let switchVC = parent as? UploadSwitchViewController {
            canDeleteImages = switchVC.canDeleteImages
            if canDeleteImages {
                deleteImageAfterUpload = Model.sharedInstance().deleteImageAfterUpload
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Unregister palette changes
        let name: NSNotification.Name = NSNotification.Name(kPiwigoNotificationPaletteChanged)
        NotificationCenter.default.removeObserver(self, name: name, object: nil)
    }

    
    // MARK: - UITableView - Header & Footer
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0.0
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
        return 4 + (resizeImageOnUpload ? 1 : 0)
                 + (compressImageOnUpload ? 1 : 0)
                 + (prefixFileNameBeforeUpload ? 1 : 0)
                 + (canDeleteImages ? 1 : 0)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var tableViewCell = UITableViewCell()
        var row = indexPath.row
        row += (!resizeImageOnUpload && (row > 1)) ? 1 : 0
        row += (!compressImageOnUpload && (row > 3)) ? 1 : 0
        row += (!prefixFileNameBeforeUpload && (row > 5)) ? 1 : 0
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
            // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
            if view.bounds.size.width > 375 {
                // i.e. larger than iPhones 6,7 screen width
                cell.configure(with: NSLocalizedString("settings_photoResize>375px", comment: "Resize Image Before Upload"))
            } else {
                cell.configure(with: NSLocalizedString("settings_photoResize", comment: "Resize Before Upload"))
            }
            cell.cellSwitch.setOn(resizeImageOnUpload, animated: true)
            cell.cellSwitchBlock = { switchState in
                // Number of rows will change accordingly
                self.resizeImageOnUpload = switchState
                // Position of the row that should be added/removed
                let rowAtIndexPath = IndexPath(row: 2, section: 0)
                if switchState {
                    // Insert row in existing table
                    self.settingsTableView?.insertRows(at: [rowAtIndexPath], with: .automatic)
                } else {
                    // Remove row in existing table
                    self.settingsTableView?.deleteRows(at: [rowAtIndexPath], with: .automatic)
                }
            }
            cell.accessibilityIdentifier = "resizeBeforeUpload"
            tableViewCell = cell
            
        case 2 /* Image Size slider */:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "SliderTableViewCell", for: indexPath) as? SliderTableViewCell else {
                print("Error: tableView.dequeueReusableCell does not return a SliderTableViewCell!")
                return SliderTableViewCell()
            }
            // Slider value
            let value = Float(photoResize)

            // Slider configuration
            let title = String(format: "… %@", NSLocalizedString("settings_photoSize", comment: "Size"))
            cell.configure(with: title, value: value, increment: 1, minValue: 5, maxValue: 100, prefix: "", suffix: "%")
            cell.cellSliderBlock = { newValue in
                // Update settings
                self.photoResize = Int(newValue)
            }
            cell.accessibilityIdentifier = "maxNberRecentAlbums"
            tableViewCell = cell
            
        case 3 /* Compress before Upload? */:
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
                let rowAtIndexPath = IndexPath(row: 3 + (self.resizeImageOnUpload ? 1 : 0), section: 0)
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
            
        case 4 /* Image Quality slider */:
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
                self.photoQuality = Int(newValue)
            }
            cell.accessibilityIdentifier = "compressionRatio"
            tableViewCell = cell
            
        case 5 /* Prefix Filename Before Upload switch */:
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
                let rowAtIndexPath = IndexPath(row: 4 + (self.resizeImageOnUpload ? 1 : 0)
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
            
        case 6 /* Filename prefix? */:
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
            cell.rightTextField.textColor = shouldUpdateDefaultPrefix ? UIColor.piwigoColorOrange() : UIColor.piwigoColorRightLabel()
            cell.accessibilityIdentifier = "prefixFileName"
            tableViewCell = cell
            
        case 7 /* Delete image after upload? */:
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
        return false
    }


    // MARK: - UITextFieldDelegate Methods
    func textFieldDidBeginEditing(_ textField: UITextField) {
        let tag = kImageUploadSetting(rawValue: textField.tag)
        switch tag {
        case .prefix:
            // Title
            shouldUpdateDefaultPrefix = true
        default:
            break
        }
    }

    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
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
            defaultPrefix = textField.text!
        default:
            break
        }
        // Update cell
        let indexPath = IndexPath.init(row: kImageUploadSetting.prefix.rawValue, section: 0)
        settingsTableView.reloadRows(at: [indexPath], with: .automatic)
    }

}
