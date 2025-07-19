//
//  SettingsViewController+UITableViewDataSource.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 01/01/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import MessageUI
import piwigoKit
import uploadKit

// MARK: UITableViewDataSource Methods
extension SettingsViewController: UITableViewDataSource
{
    // MARK: - Sections
    func hasUploadRights() -> Bool {
        /// User can upload images/videos if he/she is logged in and has:
        /// — admin rights
        /// — normal rights with upload access to some categories with Community
        return user.hasAdminRights || (user.role == .normal && NetworkVars.shared.usesCommunityPluginV29)
    }
    
    func activeSection(_ section: Int) -> SettingsSection {
        // User can upload images/videos if he/she is logged in and has:
        // — admin rights
        // — normal rights with upload access to some categories with Community
        var rawSection = section
        if !hasUploadRights(), rawSection > SettingsSection.videos.rawValue {
            rawSection += 1
        }
        guard let activeSection = SettingsSection(rawValue: rawSection)
        else { fatalError("Unknown Section index!") }
        return activeSection
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        var nberSections = SettingsSection.count.rawValue
        nberSections -= (hasUploadRights() ? 0 : 1)
        return nberSections
    }
        
    
    // MARK: - Rows
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var nberOfRows = 0
        switch activeSection(section) {
        case .server:
            nberOfRows = 2
        case .logout:
            nberOfRows = 1
        case .albums:
            nberOfRows = 4
            // Present album description option before iOS 14.0
            nberOfRows += showOptions ? 1 : 0
        case .images:
            // Present default image sort option only when Piwigo server version < 14.0
            // Present image title option before iOS 14.0
            nberOfRows = 3 + (defaultSortUnknown ? 1 : 0)
            nberOfRows += showOptions ? 1 : 0
        case .videos:
            nberOfRows = 2
        case .imageUpload:
            nberOfRows = 6 + (user.hasAdminRights ? 1 : 0)
            nberOfRows += (UploadVars.shared.resizeImageOnUpload ? 2 : 0)
            nberOfRows += (UploadVars.shared.compressImageOnUpload ? 1 : 0)
            nberOfRows += UIDevice.current.hasCellular ? 1 : 0
            nberOfRows += (NetworkVars.shared.usesUploadAsync ? 1 : 0)
        case .privacy:
            nberOfRows = 3
        case .appearance:
            nberOfRows = 1
        case .cache:
            nberOfRows = 4 + (hasUploadRights() ? 1 : 0)
        case .clear:
            nberOfRows = 1
        case .about:
            nberOfRows = 6
        case .troubleshoot:
            // LogStore requires iOS 15.0+
            if #available(iOS 15, *) {
                nberOfRows = 3
            } else {
                nberOfRows = 2
            }
        default:
            break
        }
        return nberOfRows
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var tableViewCell = UITableViewCell()
        switch activeSection(indexPath.section) {
        // MARK: Server
        case .server /* Piwigo Server */:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell
            else { preconditionFailure("Could not load LabelTableViewCell") }
            switch indexPath.row {
            case 0:
                // See https://iosref.com/res
                let title = NSLocalizedString("settings_server", comment: "Address")
                cell.configure(with: title, detail: NetworkVars.shared.service)
                cell.accessoryType = UITableViewCell.AccessoryType.none
                cell.accessibilityIdentifier = "server"
            
            case 1:
                let title = NSLocalizedString("settings_username", comment: "Username")
                let detail = NetworkVars.shared.username.isEmpty ? NSLocalizedString("settings_notLoggedIn", comment: " - Not Logged In - ") : NetworkVars.shared.username
                cell.configure(with: title, detail: detail)
                cell.accessoryType = UITableViewCell.AccessoryType.none
                cell.accessibilityIdentifier = "user"
            
            default:
                break
            }
            tableViewCell = cell

        case .logout /* Login/Logout Button */:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "ButtonTableViewCell", for: indexPath) as? ButtonTableViewCell
            else { preconditionFailure("Could not load ButtonTableViewCell") }
            if NetworkVars.shared.username.isEmpty {
                cell.configure(with: NSLocalizedString("login", comment: "Login"))
            } else {
                cell.configure(with: NSLocalizedString("settings_logout", comment: "Logout"))
            }
            cell.accessibilityIdentifier = "logout"
            tableViewCell = cell
        
        // MARK: Albums
        case .albums /* Albums */:
            var row = indexPath.row
            row += (!showOptions && (row > 1)) ? 1 : 0
            switch row {
            case 0 /* Default album */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell
                else { preconditionFailure("Could not load LabelTableViewCell") }
                let title = NSLocalizedString("setDefaultCategory_title", comment: "Default Album")
                cell.configure(with: title, detail: defaultAlbumName())
                cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                cell.accessibilityIdentifier = "defaultAlbum"
                tableViewCell = cell

            case 1 /* Thumbnail file */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell
                else { preconditionFailure("Could not load LabelTableViewCell") }
                // See https://iosref.com/res
                var title: String
                if view.bounds.size.width > 375 {
                    // i.e. larger than iPhones 6,7 screen width
                    title = NSLocalizedString("defaultAlbumThumbnailFile>414px", comment: "Album Thumbnail File")
                } else if view.bounds.size.width > 375 {
                    // i.e. larger than iPhone SE, 11 Pro screen width
                    title = NSLocalizedString("defaultThumbnailFile>320px", comment: "Thumbnail File")
                } else {
                    title = NSLocalizedString("defaultThumbnailFile", comment: "Thumbnail")
                }
                let albumImageSize = pwgImageSize(rawValue: AlbumVars.shared.defaultAlbumThumbnailSize) ?? .medium
                cell.configure(with: title, detail: albumImageSize.name)
                cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                cell.accessibilityIdentifier = "defaultAlbumThumbnailFile"
                tableViewCell = cell

            case 2 /* Display Descriptions — iOS 12-13 only */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchTableViewCell", for: indexPath) as? SwitchTableViewCell
                else { preconditionFailure("Could not load SwitchTableViewCell") }
                // See https://iosref.com/res
                if view.bounds.size.width > 320 {
                    cell.configure(with: NSLocalizedString("settings_displayDescriptions>320px", comment: "Display Album Descriptions"))
                } else {
                    cell.configure(with: NSLocalizedString("settings_displayDescriptions", comment: "Display Descriptions"))
                }
                
                // Switch status
                cell.cellSwitch.setOn(AlbumVars.shared.displayAlbumDescriptions, animated: true)
                cell.cellSwitch.accessibilityIdentifier = "switchAlbumDescriptions"
                cell.cellSwitchBlock = { [self] switchState in
                    // Only called when running on iOS 12 - 13
                    AlbumVars.shared.displayAlbumDescriptions = switchState
                    if let navController = presentingViewController as? AlbumNavigationController,
                       let albumVC = navController.viewControllers.first as? AlbumViewController {
                        albumVC.collectionView?.reloadData()
                    }
                }
                cell.accessibilityIdentifier = "displayAlbumDescriptions"
                tableViewCell = cell
                
            case 3 /* Number of recent albums */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "SliderTableViewCell", for: indexPath) as? SliderTableViewCell
                else { preconditionFailure("Could not load SliderTableViewCell") }
                // Slider value
                let value = Float(AlbumVars.shared.maxNberRecentCategories)

                // Slider configuration
                // See https://iosref.com/res
                var title: String = ""
                if view.bounds.size.width > 414 {
                    // i.e. larger than iPhones 8+, 11 screen width
                    title = NSLocalizedString("maxNberOfRecentAlbums>414px", comment: "Number of Recent Albums")
                } else if view.bounds.size.width > 320 {
                    // i.e. larger than iPhone 6, 7 screen width
                    title = NSLocalizedString("maxNberOfRecentAlbums>320px", comment: "Recent Albums")
                } else {
                    title = NSLocalizedString("maxNberOfRecentAlbums", comment: "Recent")
                }
                cell.configure(with: title, value: value, increment: 1, minValue: 3, maxValue: 10, prefix: "", suffix: "/10")
                cell.cellSliderBlock = { newValue in
                    // Update settings
                    AlbumVars.shared.maxNberRecentCategories = Int(newValue)
                }
                cell.accessibilityIdentifier = "maxNberRecentAlbums"
                tableViewCell = cell

            case 4 /* Recent period */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "SliderTableViewCell", for: indexPath) as? SliderTableViewCell
                else { preconditionFailure("Could not load SliderTableViewCell") }
                // Slider value is the index of kRecentPeriods
                var value:Float = Float(CacheVars.shared.recentPeriodIndex)
                value = min(value, Float(CacheVars.shared.recentPeriodList.count - 1))
                value = max(0.0, value)

                // Slider configuration
                let title = NSLocalizedString("recentPeriod_title", comment: "Recent Period")
                cell.configure(with: title, value: value, increment: Float(CacheVars.shared.recentPeriodKey),
                               minValue: 0.0, maxValue: Float(CacheVars.shared.recentPeriodList.count - 1),
                               prefix: "", suffix: NSLocalizedString("recentPeriod_days", comment: "%@ days"))
                cell.cellSliderBlock = { newValue in
                    // Update settings in cache
                    // Server settings will be updated when the view will disappear
                    let index = Int(newValue)
                    if index >= 0, index < CacheVars.shared.recentPeriodList.count {
                        CacheVars.shared.recentPeriodIndex = index
                    }
                }
                cell.accessibilityIdentifier = "recentPeriod"
                tableViewCell = cell

            default:
                break
            }
        
        // MARK: Images
        case .images /* Images */:
            var row = indexPath.row
            row += defaultSortUnknown ? 0 : 1
            row += (!showOptions && (row > 2)) ? 1 : 0
            switch row {
            case 0 /* Default Sort */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell
                else { preconditionFailure("Could not load LabelTableViewCell") }
                // See https://iosref.com/res
                var title: String
                if view.bounds.size.width > 414 {
                    // i.e. larger than iPhone 14 Pro Max screen width
                    title = NSLocalizedString("defaultImageSort>414px", comment: "Default Sort of Images")
                } else if view.bounds.size.width > 320 {
                    // i.e. larger than iPhone 5 screen width
                    title = NSLocalizedString("defaultImageSort>320px", comment: "Default Sort")
                } else {
                    title = NSLocalizedString("defaultImageSort", comment: "Sort")
                }
                cell.configure(with: title, detail: AlbumVars.shared.defaultSort.name)
                cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                cell.accessibilityIdentifier = "defaultSort"
                tableViewCell = cell
 
            case 1 /* Thumbnail file */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell
                else { preconditionFailure("Could not load LabelTableViewCell") }
                // See https://iosref.com/res
                var title: String
                if view.bounds.size.width > 375 {
                    // i.e. larger than iPhones 6,7 screen width
                    title = NSLocalizedString("defaultThumbnailFile>414px", comment: "Image Thumbnail File")
                } else if view.bounds.size.width > 320 {
                    // i.e. larger than iPhone 5 screen width
                    title = NSLocalizedString("defaultThumbnailFile>320px", comment: "Thumbnail File")
                } else {
                    title = NSLocalizedString("defaultThumbnailFile", comment: "Thumbnail")
                }
                let thumbnailSize = pwgImageSize(rawValue: AlbumVars.shared.defaultThumbnailSize) ?? .thumb
                cell.configure(with: title, detail: thumbnailSize.name)
                cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                cell.accessibilityIdentifier = "defaultImageThumbnailFile"
                tableViewCell = cell

            case 2 /* Number of thumbnails */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "SliderTableViewCell", for: indexPath) as? SliderTableViewCell
                else { preconditionFailure("Could not load SliderTableViewCell") }
                // Min/max number of thumbnails per row depends on selected file
                let thumbnailSize = pwgImageSize(rawValue: AlbumVars.shared.defaultThumbnailSize) ?? .thumb
                let defaultWidth = thumbnailSize.minPoints
                let minNberOfImages = Float(AlbumUtilities.imagesPerRowInPortrait(forMaxWidth: defaultWidth))

                // Slider value, chek that default number fits inside selected range
                if Float(AlbumVars.shared.thumbnailsPerRowInPortrait) > (2 * minNberOfImages) {
                    AlbumVars.shared.thumbnailsPerRowInPortrait = Int(2 * minNberOfImages)
                }
                if Float(AlbumVars.shared.thumbnailsPerRowInPortrait) < minNberOfImages {
                    AlbumVars.shared.thumbnailsPerRowInPortrait = Int(minNberOfImages)
                }
                let value = Float(AlbumVars.shared.thumbnailsPerRowInPortrait)

                // Slider configuration
                // See https://iosref.com/res
                var title: String
                if view.bounds.size.width > 375 {
                    // i.e. larger than iPhones 6,7 screen width
                    title = NSLocalizedString("defaultNberOfThumbnails>414px", comment: "Number per Row")
                } else if view.bounds.size.width > 320 {
                    // i.e. larger than iPhone 5 screen width
                    title = NSLocalizedString("defaultNberOfThumbnails>320px", comment: "Number/Row")
                } else {
                    title = NSLocalizedString("defaultNberOfThumbnails", comment: "Number")
                }
                cell.configure(with: title, value: value, increment: 1, minValue: minNberOfImages, maxValue: minNberOfImages * 2, prefix: "", suffix: "/\(Int(minNberOfImages * 2))")
                cell.cellSliderBlock = { newValue in
                    // Update settings
                    AlbumVars.shared.thumbnailsPerRowInPortrait = Int(newValue)
                }
                cell.accessibilityIdentifier = "nberThumbnailFiles"
                tableViewCell = cell
                
            case 3 /* Display titles on thumbnails — iOS 12-13 only */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchTableViewCell", for: indexPath) as? SwitchTableViewCell
                else { preconditionFailure("Could not load SwitchTableViewCell") }
                // See https://iosref.com/res
                if view.bounds.size.width > 320 {
                    cell.configure(with: NSLocalizedString("settings_displayTitles>320px", comment: "Display Titles on Thumbnails"))
                } else {
                    cell.configure(with: NSLocalizedString("settings_displayTitles", comment: "Titles on Thumbnails"))
                }
                
                // Switch status
                cell.cellSwitch.setOn(AlbumVars.shared.displayImageTitles, animated: true)
                cell.cellSwitch.accessibilityIdentifier = "switchImageTitles"
                cell.cellSwitchBlock = { switchState in
                    AlbumVars.shared.displayImageTitles = switchState
                }
                cell.accessibilityIdentifier = "displayImageTitles"
                tableViewCell = cell
                
            case 4 /* Default Size of Previewed Images */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell
                else { preconditionFailure("Could not load LabelTableViewCell") }
                // See https://iosref.com/res
                var title: String
                if view.bounds.size.width > 430 {
                    // i.e. larger than iPhone 14 Pro Max screen width
                    title = NSLocalizedString("defaultPreviewFile>414px", comment: "Preview Image File")
                } else if view.bounds.size.width > 320 {
                    // i.e. larger than iPhone 5 screen width
                    title = NSLocalizedString("defaultPreviewFile>320px", comment: "Preview File")
                } else {
                    title = NSLocalizedString("defaultPreviewFile", comment: "Preview")
                }
                let imageSize = pwgImageSize(rawValue: ImageVars.shared.defaultImagePreviewSize) ?? .fullRes
                cell.configure(with: title, detail: imageSize.name)
                cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                cell.accessibilityIdentifier = "defaultImagePreviewSize"
                tableViewCell = cell
                    
            default:
                break
            }
        
        // MARK: Videos
        case .videos /* Videos */:
            switch indexPath.row {
            case 0:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchTableViewCell", for: indexPath) as? SwitchTableViewCell
                else { preconditionFailure("Could not load SwitchTableViewCell") }
                cell.configure(with: NSLocalizedString("settings_videoAutoPlay", comment: "Auto-Play"))
                
                // Switch status
                cell.cellSwitch.setOn(VideoVars.shared.autoPlayOnDevice, animated: true)
                cell.cellSwitch.accessibilityIdentifier = "switchAutoPlayOnDevice"
                cell.cellSwitchBlock = { switchState in
                    VideoVars.shared.autoPlayOnDevice = switchState
                }
                cell.accessibilityIdentifier = "switchAutoPlayOnDevice"
                tableViewCell = cell

            case 1:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchTableViewCell", for: indexPath) as? SwitchTableViewCell
                else { preconditionFailure("Could not load SwitchTableViewCell") }
                cell.configure(with: NSLocalizedString("settings_videoLoop", comment: "Loop Videos"))
                
                // Switch status
                cell.cellSwitch.setOn(VideoVars.shared.loopVideosOnDevice, animated: true)
                cell.cellSwitch.accessibilityIdentifier = "switchLoopVideosOnDevice"
                cell.cellSwitchBlock = { switchState in
                    VideoVars.shared.loopVideosOnDevice = switchState
                }
                cell.accessibilityIdentifier = "switchLoopVideosOnDevice"
                tableViewCell = cell

            default:
                break
            }

        // MARK: Upload Settings
        case .imageUpload /* Default Upload Settings */:
            var row = indexPath.row
            row += (!user.hasAdminRights && (row > 0)) ? 1 : 0
            row += (!UploadVars.shared.resizeImageOnUpload && (row > 3)) ? 2 : 0
            row += (!UploadVars.shared.compressImageOnUpload && (row > 6)) ? 1 : 0
            row += (!UIDevice.current.hasCellular && (row > 8)) ? 1 : 0
            row += (!NetworkVars.shared.usesUploadAsync && (row > 9)) ? 1 : 0
            switch row {
            case 0 /* Author Name? */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "TextFieldTableViewCell", for: indexPath) as? TextFieldTableViewCell
                else { preconditionFailure("Could not load TextFieldTableViewCell") }
                // See https://iosref.com/res
                var title: String
                let input: String = UploadVars.shared.defaultAuthor
                let placeHolder: String = NSLocalizedString("settings_defaultAuthorPlaceholder", comment: "Author Name")
                if view.bounds.size.width > 375 {
                    title = NSLocalizedString("settings_defaultAuthorLong", comment: "Author Name")
                } else {
                    title = NSLocalizedString("settings_defaultAuthor", comment: "Author")
                }
                cell.configure(with: title, input: input, placeHolder: placeHolder)
                cell.rightTextField.delegate = self
                cell.rightTextField.tag = TextFieldTag.author.rawValue
                cell.accessibilityIdentifier = "defaultAuthorName"
                tableViewCell = cell
                
            case 1 /* Privacy Level? */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell
                else { preconditionFailure("Could not load LabelTableViewCell")}
                let defaultLevel = pwgPrivacy(rawValue: UploadVars.shared.defaultPrivacyLevel)!.name
                // See https://iosref.com/res
                if view.bounds.size.width > 440 {
                    cell.configure(with: NSLocalizedString("privacyLevel", comment: "Privacy Level"), detail: defaultLevel)
                } else {
                    cell.configure(with: NSLocalizedString("settings_defaultPrivacy", comment: "Privacy"), detail: defaultLevel)
                }
                cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                cell.accessibilityIdentifier = "defaultPrivacyLevel"
                tableViewCell = cell
                
            case 2 /* Strip private Metadata? */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchTableViewCell", for: indexPath) as? SwitchTableViewCell
                else { preconditionFailure("Could not load SwitchTableViewCell") }
                // See https://iosref.com/res
                if view.bounds.size.width > 440 {
                    cell.configure(with: NSLocalizedString("settings_stripGPSdataLong", comment: "Strip Private Metadata"))
                } else {
                    cell.configure(with: NSLocalizedString("settings_stripGPSdata", comment: "Strip Metadata"))
                }
                cell.cellSwitch.setOn(UploadVars.shared.stripGPSdataOnUpload, animated: true)
                cell.cellSwitchBlock = { switchState in
                    UploadVars.shared.stripGPSdataOnUpload = switchState
                }
                cell.accessibilityIdentifier = "stripMetadataBeforeUpload"
                tableViewCell = cell
                
            case 3 /* Resize Before Upload? */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchTableViewCell", for: indexPath) as? SwitchTableViewCell
                else { preconditionFailure("Could not load SwitchTableViewCell") }
                if view.bounds.size.width > 440 {
                    cell.configure(with: NSLocalizedString("settings_photoResizeLong", comment: "Downsize Photo"))
                } else {
                    cell.configure(with: NSLocalizedString("settings_photoResize", comment: "Downsize"))
                }
                cell.cellSwitch.setOn(UploadVars.shared.resizeImageOnUpload, animated: true)
                cell.cellSwitchBlock = { switchState in
                    // Number of rows will change accordingly
                    UploadVars.shared.resizeImageOnUpload = switchState
                    // Position of the row that should be added/removed
                    let photoAtIndexPath = IndexPath(row: 3 + (self.user.hasAdminRights ? 1 : 0),
                                                   section: SettingsSection.imageUpload.rawValue)
                    let videoAtIndexPath = IndexPath(row: 4 + (self.user.hasAdminRights ? 1 : 0),
                                                   section: SettingsSection.imageUpload.rawValue)
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
                
            case 4 /* Upload Photo Size */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell
                else { preconditionFailure("Could not load LabelTableViewCell") }
                cell.configure(with: "… " + NSLocalizedString("severalImages", comment: "Photos"),
                               detail: pwgPhotoMaxSizes(rawValue: UploadVars.shared.photoMaxSize)?.name ?? pwgPhotoMaxSizes(rawValue: 0)!.name)
                cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                cell.accessibilityIdentifier = "defaultUploadPhotoSize"
                tableViewCell = cell
                
            case 5 /* Upload Video Size */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell
                else { preconditionFailure("Could not load LabelTableViewCell") }
                cell.configure(with: "… " + NSLocalizedString("severalVideos", comment: "Videos"),
                               detail: pwgVideoMaxSizes(rawValue: UploadVars.shared.videoMaxSize)?.name ?? pwgVideoMaxSizes(rawValue: 0)!.name)
                cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                cell.accessibilityIdentifier = "defaultUploadVideoSize"
                tableViewCell = cell
                
            case 6 /* Compress before Upload? */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchTableViewCell", for: indexPath) as? SwitchTableViewCell
                else { preconditionFailure("Could not load SwitchTableViewCell") }
                // See https://iosref.com/res
                if view.bounds.size.width > 440 {
                    cell.configure(with: NSLocalizedString("settings_photoCompressLong", comment: "Compress Photo"))
                } else {
                    cell.configure(with: NSLocalizedString("settings_photoCompress", comment: "Compress"))
                }
                cell.cellSwitch.setOn(UploadVars.shared.compressImageOnUpload, animated: true)
                cell.cellSwitchBlock = { switchState in
                    // Number of rows will change accordingly
                    UploadVars.shared.compressImageOnUpload = switchState
                    // Position of the row that should be added/removed
                    let rowAtIndexPath = IndexPath(row: 4 + (self.user.hasAdminRights ? 1 : 0)
                                                          + (UploadVars.shared.resizeImageOnUpload ? 2 : 0),
                                                   section: SettingsSection.imageUpload.rawValue)
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
                
            case 7 /* Image Quality slider */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "SliderTableViewCell", for: indexPath) as? SliderTableViewCell
                else { preconditionFailure("Could not load SliderTableViewCell") }
                // Slider value
                let value = Float(UploadVars.shared.photoQuality)

                // Slider configuration
                let title = String(format: "… %@", NSLocalizedString("settings_photoQuality", comment: "Quality"))
                cell.configure(with: title, value: value, increment: 1, minValue: 50, maxValue: 98, prefix: "", suffix: "%")
                cell.cellSliderBlock = { newValue in
                    // Update settings
                    UploadVars.shared.photoQuality = Int16(newValue)
                }
                cell.accessibilityIdentifier = "compressionRatio"
                tableViewCell = cell
                
            case 8 /* Rename Filename Before Upload */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell
                else { preconditionFailure("Could not load LabelTableViewCell") }
                let title: String
                // See https://iosref.com/res
                if view.bounds.size.width > 440 {
                    title = NSLocalizedString("settings_renameFileLong", comment: "Rename File")
                } else {
                    title = NSLocalizedString("settings_renameFile", comment: "Rename")
                }
                let detail: String
                if isRenameFileAtiveByDefault == true {
                    detail = NSLocalizedString("settings_autoUploadEnabled", comment: "On")
                } else {
                    detail = NSLocalizedString("settings_autoUploadDisabled", comment: "Off")
                }
                cell.configure(with: title, detail: detail)
                cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                cell.accessibilityIdentifier = "modifyFilename"
                tableViewCell = cell

            case 9 /* Wi-Fi Only? */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchTableViewCell", for: indexPath) as? SwitchTableViewCell
                else { preconditionFailure("Could not load SwitchTableViewCell") }
                cell.configure(with: NSLocalizedString("settings_wifiOnly", comment: "Wi-Fi Only"))
                cell.cellSwitch.setOn(UploadVars.shared.wifiOnlyUploading, animated: true)
                cell.cellSwitchBlock = { switchState in
                    // Change option
                    UploadVars.shared.wifiOnlyUploading = switchState
                    // Relaunch uploads in background queue if disabled
                    if switchState == false {
                        // Update upload tasks in background queue
                        // May not restart the uploads
                        UploadManager.shared.backgroundQueue.async {
                            UploadManager.shared.findNextImageToUpload()
                        }
                    }
                }
                cell.accessibilityIdentifier = "wifiOnly"
                tableViewCell = cell

            case 10 /* Auto-upload */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell
                else { preconditionFailure("Could not load LabelTableViewCell") }
                let title: String
                if view.bounds.size.width > 440 {
                    title = NSLocalizedString("settings_autoUploadLong", comment: "Auto Upload Photos")
                } else {
                    title = NSLocalizedString("settings_autoUpload", comment: "Auto Upload")
                }
                let detail: String
                if UploadVars.shared.isAutoUploadActive == true {
                    detail = NSLocalizedString("settings_autoUploadEnabled", comment: "On")
                } else {
                    detail = NSLocalizedString("settings_autoUploadDisabled", comment: "Off")
                }
                cell.configure(with: title, detail: detail)
                cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                cell.accessibilityIdentifier = "autoUpload"
                tableViewCell = cell

            case 11 /* Delete image after upload? */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchTableViewCell", for: indexPath) as? SwitchTableViewCell
                else { preconditionFailure("Could not load SwitchTableViewCell") }
                // See https://iosref.com/res
                if view.bounds.size.width > 430 {
                    cell.configure(with: NSLocalizedString("settings_deleteImageLong", comment: "Delete Image After"))
                } else {
                    cell.configure(with: NSLocalizedString("settings_deleteImage", comment: "Delete After"))
                }
                cell.cellSwitch.setOn(UploadVars.shared.deleteImageAfterUpload, animated: true)
                cell.cellSwitchBlock = { switchState in
                    UploadVars.shared.deleteImageAfterUpload = switchState
                }
                cell.accessibilityIdentifier = "deleteAfterUpload"
                tableViewCell = cell
                
            default:
                break
        }
        
        // MARK: Privacy
        case .privacy   /* Privacy */:
            switch indexPath.row {
            case 0 /* App Lock */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell
                else { preconditionFailure("Could not load LabelTableViewCell") }
                let title = NSLocalizedString("settings_appLock", comment: "App Lock")
                let detail: String
                if AppVars.shared.isAppLockActive == true {
                    detail = NSLocalizedString("settings_autoUploadEnabled", comment: "On")
                } else {
                    detail = NSLocalizedString("settings_autoUploadDisabled", comment: "Off")
                }
                cell.configure(with: title, detail: detail)
                cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                cell.accessibilityIdentifier = "appLock"
                tableViewCell = cell
            
            case 1 /* Clear Clipboard */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell
                else { preconditionFailure("Could not load LabelTableViewCell") }
                let title = NSLocalizedString("settings_clearClipboard", comment: "Clear Clipboard")
                let detail = pwgClearClipboard(rawValue: AppVars.shared.clearClipboardDelay)?.delayUnit ?? ""
                cell.configure(with: title, detail: detail)
                cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                cell.accessibilityIdentifier = "clearClipboard"
                tableViewCell = cell
                
            case 2 /* Share Image Metadata Options */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell
                else { preconditionFailure("Could not load LabelTableViewCell") }
                // See https://iosref.com/res
                if view.bounds.size.width > 430 {
                    // i.e. larger than iPhone 14 Pro Max screen width
                    cell.configure(with: NSLocalizedString("settings_shareGPSdata>375px", comment: "Share with Private Metadata"), detail: "")
                } else {
                    cell.configure(with: NSLocalizedString("settings_shareGPSdata", comment: "Share Private Metadata"), detail: "")
                }
                cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                cell.accessibilityIdentifier = "defaultShareOptions"
                tableViewCell = cell

            default:
                break
            }

        // MARK: Appearance
        case .appearance /* Appearance */:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell
            else { preconditionFailure("Could not load LabelTableViewCell") }
            let title = NSLocalizedString("settingsHeader_colorPalette", comment: "Color Palette")
            let detail: String
            if AppVars.shared.isLightPaletteModeActive == true {
                detail = NSLocalizedString("settings_lightColor", comment: "Light")
            } else if AppVars.shared.isDarkPaletteModeActive == true {
                detail = NSLocalizedString("settings_darkColor", comment: "Dark")
            } else {
                detail = NSLocalizedString("settings_switchPalette", comment: "Automatic")
            }
            cell.configure(with: title, detail: detail)
            cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
            cell.accessibilityIdentifier = "colorPalette"
            tableViewCell = cell

        // MARK: Cache
        case .cache /* Cache Settings */:
            switch indexPath.row {
            case 0 /* Core Data store */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell
                else { preconditionFailure("Could not load LabelTableViewCell") }
                let title = NSLocalizedString("settings_database", comment: "Data")
                cell.configure(with: title, detail: self.dataCacheSize)
                cell.accessoryType = UITableViewCell.AccessoryType.none
                cell.accessibilityIdentifier = "dataCache"
                tableViewCell = cell
                
            case 1 /* Album and Photo Thumbnails */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell
                else { preconditionFailure("Could not load LabelTableViewCell") }
                let title = NSLocalizedString("settingsHeader_thumbnails", comment: "Thumbnails")
                cell.configure(with: title, detail: self.thumbCacheSize)
                cell.accessoryType = UITableViewCell.AccessoryType.none
                cell.accessibilityIdentifier = "thumbnailCache"
                tableViewCell = cell
                
            case 2 /* Photos */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell
                else { preconditionFailure("Could not load LabelTableViewCell") }
                let title = NSLocalizedString("severalImages", comment: "Photos")
                cell.configure(with: title, detail: self.photoCacheSize)
                cell.accessoryType = UITableViewCell.AccessoryType.none
                cell.accessibilityIdentifier = "photoCache"
                tableViewCell = cell
                
            case 3 /* Videos */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell
                else { preconditionFailure("Could not load LabelTableViewCell!") }
                let title = NSLocalizedString("severalVideos", comment: "Videos")
                cell.configure(with: title, detail: self.videoCacheSize)
                cell.accessoryType = UITableViewCell.AccessoryType.none
                cell.accessibilityIdentifier = "videoCache"
                tableViewCell = cell
                
            case 4 /* Upload Requests */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell
                else { preconditionFailure("Could not load LabelTableViewCell") }
                let title = NSLocalizedString("UploadRequests_cache", comment: "Uploads")
                cell.configure(with: title, detail: self.uploadCacheSize)
                cell.accessoryType = UITableViewCell.AccessoryType.none
                cell.accessibilityIdentifier = "uploadCache"
                tableViewCell = cell
                
            default:
                break
            }

        case .clear /* Clear Cache Button */:
            switch indexPath.row {
            case 0 /* Clear */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "ButtonTableViewCell", for: indexPath) as? ButtonTableViewCell
                else { preconditionFailure("Could not load ButtonTableViewCell") }
                cell.configure(with: NSLocalizedString("settings_cacheClear", comment: "Clear Cache"))
                cell.accessibilityIdentifier = "clearCache"
                tableViewCell = cell
                
            default:
                break
            }

        // MARK: Information
        case .about /* Information */:
            switch indexPath.row {
            case 0 /* Piwigo.org website */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell
                else { preconditionFailure("Could not load LabelTableViewCell") }
                cell.configure(with: "Piwigo", detail: "")
                cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                cell.accessibilityIdentifier = "piwigoWebsite"
                tableViewCell = cell
                
            case 1 /* Rate Piwigo Mobile */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell
                else { preconditionFailure("Could not load LabelTableViewCell") }
                if let object = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") {
                    cell.configure(with: "\(NSLocalizedString("settings_rateInAppStore", comment: "Rate Piwigo Mobile")) \(object)", detail: "")
                }
                cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                cell.accessibilityIdentifier = "ratePiwigo"
                tableViewCell = cell
                
            case 2 /* Translate Piwigo Mobile */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell
                else { preconditionFailure("Could not load LabelTableViewCell") }
                cell.configure(with: NSLocalizedString("settings_translateWithCrowdin", comment: "Translate Piwigo Mobile"), detail: "")
                cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                tableViewCell = cell
                
            case 3 /* Release Notes */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell
                else { preconditionFailure("Could not load LabelTableViewCell") }
                cell.configure(with: NSLocalizedString("settings_releaseNotes", comment: "Release Notes"), detail: "")
                cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                cell.accessibilityIdentifier = "releaseNotes"
                tableViewCell = cell
                
            case 4 /* Acknowledgements */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell
                else { preconditionFailure("Could not load LabelTableViewCell") }
                cell.configure(with: NSLocalizedString("settings_acknowledgements", comment: "Acknowledgements"), detail: "")
                cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                cell.accessibilityIdentifier = "acknowledgements"
                tableViewCell = cell
                
            case 5 /* Privacy Policy */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell
                else { preconditionFailure("Could not load LabelTableViewCell") }
                cell.configure(with: NSLocalizedString("settings_privacy", comment: "Privacy Policy"), detail: "")
                cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                cell.accessibilityIdentifier = "privacyPolicy"
                tableViewCell = cell
                
            default:
                break
            }

        // MARK: Troubleshoot
        case .troubleshoot /* Troubleshoot */:
            var row = indexPath.row
            if #available(iOS 15, *) {
                // LogStore available
            } else {
                row += 1
            }
            switch row {
            case 0 /* Logs */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell
                else { preconditionFailure("Could not load LabelTableViewCell")}
                cell.configure(with: NSLocalizedString("settings_logs", comment: "Logs"), detail: "")
                cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                cell.accessibilityIdentifier = "errorLogs"
                tableViewCell = cell

            case 1 /* Support Forum */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell
                else { preconditionFailure("Could not load LabelTableViewCell") }
                cell.configure(with: NSLocalizedString("settings_supportForum", comment: "Support Forum"), detail: "")
                cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                cell.accessibilityIdentifier = "supportForum"
                tableViewCell = cell
                
            case 2 /* Contact Us */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell
                else { preconditionFailure("Could not load LabelTableViewCell") }
                cell.configure(with: NSLocalizedString("settings_contactUs", comment: "Contact Us"), detail: "")
                cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                if !MFMailComposeViewController.canSendMail() {
                    cell.titleLabel.textColor = .piwigoColorRightLabel()
                }
                cell.accessibilityIdentifier = "mailContact"
                tableViewCell = cell
                
            default:
                break
            }

        default:
            break
        }

        tableViewCell.isAccessibilityElement = true
        return tableViewCell
    }
}
