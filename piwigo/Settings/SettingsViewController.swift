//
//  SettingsViewController.swift
//  piwigo
//
//  Created by Spencer Baker on 1/20/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//
//  Converted to Swift 5 by Eddy Lelièvre-Berna on 12/04/2020.
//

import MessageUI
import UIKit

enum SettingsSection : Int {
    case server
    case logout
    case albums
    case images
    case imageUpload
    case color
    case cache
    case clear
    case about
    case count
}

enum kImageUploadSetting : Int {
    case author
    case prefix
}

let kHelpUsTitle = "Help Us!"
let kHelpUsTranslatePiwigo = "Piwigo is only partially translated in your language. Could you please help us complete the translation?"

@objc protocol ChangedSettingsDelegate: NSObjectProtocol {
    func didChangeDefaultAlbum()
}

@objc
class SettingsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate, MFMailComposeViewControllerDelegate, DefaultCategoryDelegate, CategorySortDelegate, SelectPrivacyDelegate {

    @objc weak var settingsDelegate: ChangedSettingsDelegate?

    @IBOutlet var settingsTableView: UITableView!
    
    private var tableViewBottomConstraint: NSLayoutConstraint?
    private var doneBarButton: UIBarButtonItem?
    private var nberCategories = ""
    private var nberImages = ""
    private var nberTags = ""
    private var nberUsers = ""
    private var nberGroups = ""
    private var nberComments = ""
    private var didChangeDefaultAlbum = false


    #if DEBUG
    // MARK: - Core Data
    /**
     The TagsProvider that fetches tag data, saves it to Core Data,
     and serves it to this table view.
     */
    private lazy var tagsProvider: TagsProvider = {
        let provider : TagsProvider = TagsProvider()
        return provider
    }()
    /**
     The UploadsProvider that collects upload data, saves it to Core Data,
     and serves it to the uploader.
     */
    private lazy var uploadsProvider: UploadsProvider = {
        let provider : UploadsProvider = UploadsProvider()
        return provider
    }()
    #endif

    
    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // Get Server Infos if possible
        if Model.sharedInstance().hasAdminRights {
            getInfos()
        }

        // Title
        title = NSLocalizedString("tabBar_preferences", comment: "Settings")

        // Button for returning to albums/images
        doneBarButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(quitSettings))
        doneBarButton?.accessibilityIdentifier = "Done"
        
        // Table view identifier
        settingsTableView.accessibilityIdentifier = "settings"
    }

    @objc func applyColorPalette() {
        // Background color of the view
        view.backgroundColor = UIColor.piwigoColorBackground()

        // Navigation bar
        let attributes = [
            NSAttributedString.Key.foregroundColor: UIColor.piwigoColorWhiteCream(),
            NSAttributedString.Key.font: UIFont.piwigoFontNormal()
        ]
        navigationController?.navigationBar.titleTextAttributes = attributes
        if #available(iOS 11.0, *) {
            let attributesLarge = [
                NSAttributedString.Key.foregroundColor: UIColor.piwigoColorWhiteCream(),
                NSAttributedString.Key.font: UIFont.piwigoFontLargeTitle()
            ]
            navigationController?.navigationBar.largeTitleTextAttributes = attributesLarge
            navigationController?.navigationBar.prefersLargeTitles = true
        }
        navigationController?.navigationBar.barStyle = Model.sharedInstance().isDarkPaletteActive ? .black : .default
        navigationController?.navigationBar.tintColor = UIColor.piwigoColorOrange()
        navigationController?.navigationBar.barTintColor = UIColor.piwigoColorBackground()
        navigationController?.navigationBar.backgroundColor = UIColor.piwigoColorBackground()

        // Table view
        settingsTableView?.separatorColor = UIColor.piwigoColorSeparator()
        settingsTableView?.indicatorStyle = Model.sharedInstance().isDarkPaletteActive ? .white : .black
        settingsTableView?.reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Set colors, fonts, etc.
        applyColorPalette()

        // Set navigation buttons
        navigationItem.setRightBarButtonItems([doneBarButton].compactMap { $0 }, animated: true)
        
        // Register palette changes
        let name: NSNotification.Name = NSNotification.Name(kPiwigoNotificationPaletteChanged)
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette), name: name, object: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if #available(iOS 10, *) {
            let langCode = NSLocale.current.languageCode
//            print("=> langCode: ", String(describing: langCode))
//            print(String(format: "=> now:%.0f > last:%.0f + %.0f", Date().timeIntervalSinceReferenceDate, Model.sharedInstance().dateOfLastTranslationRequest, k2WeeksInDays))
            if (Date().timeIntervalSinceReferenceDate > Model.sharedInstance().dateOfLastTranslationRequest + k2WeeksInDays) && ((langCode == "ar") || (langCode == "fa") || (langCode == "pl") || (langCode == "pt-BR") || (langCode == "sk")) {
                // Store date of last translation request
                Model.sharedInstance().dateOfLastTranslationRequest = Date().timeIntervalSinceReferenceDate
                Model.sharedInstance().saveToDisk()

                // Request a translation
                let alert = UIAlertController(title: kHelpUsTitle, message: kHelpUsTranslatePiwigo, preferredStyle: .alert)

                let cancelAction = UIAlertAction(title: NSLocalizedString("alertNoButton", comment: "No"), style: .destructive, handler: { action in
                    })

                let defaultAction = UIAlertAction(title: NSLocalizedString("alertYesButton", comment: "Yes"), style: .default, handler: { action in
                        if let url = URL(string: "https://crowdin.com/project/piwigo-mobile") {
                            UIApplication.shared.openURL(url)
                        }
                    })

                alert.addAction(cancelAction)
                alert.addAction(defaultAction)
                alert.view.tintColor = UIColor.piwigoColorOrange()
                if #available(iOS 13.0, *) {
                    alert.overrideUserInterfaceStyle = Model.sharedInstance().isDarkPaletteActive ? .dark : .light
                } else {
                    // Fallback on earlier versions
                }
                present(alert, animated: true, completion: {
                    // Bugfix: iOS9 - Tint not fully Applied without Reapplying
                    alert.view.tintColor = UIColor.piwigoColorOrange()
                })
            }
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        //Reload the tableview on orientation change, to match the new width of the table.
        coordinator.animate(alongsideTransition: { context in

            // On iPad, the Settings section is presented in a centered popover view
            if UIDevice.current.userInterfaceIdiom == .pad {
                let mainScreenBounds = UIScreen.main.bounds
                self.popoverPresentationController?.sourceRect = CGRect(x: mainScreenBounds.midX, y: mainScreenBounds.midY, width: 0, height: 0)
                self.preferredContentSize = CGSize(width: ceil(mainScreenBounds.width * 2 / 3), height: ceil(mainScreenBounds.height * 2 / 3))
            }

            // Reload table view
            self.settingsTableView?.reloadData()
        })
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Load new default album view if necessary
        if didChangeDefaultAlbum {
            settingsDelegate?.didChangeDefaultAlbum()
        }

        // Unregister palette changes
        let name: NSNotification.Name = NSNotification.Name(kPiwigoNotificationPaletteChanged)
        NotificationCenter.default.removeObserver(self, name: name, object: nil)
    }

    @objc func quitSettings() {
        dismiss(animated: true)
    }

    
// MARK: - UITableView - Header
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        // User can upload images/videos if he/she is logged in and has:
        // — admin rights
        // — normal rights with upload access to some categories with Community
        var activeSection = section
        if !(Model.sharedInstance().hasAdminRights ||
             (Model.sharedInstance().hasNormalRights && Model.sharedInstance().usesCommunityPluginV29)) {
            // Bypass the Upload section
            if activeSection > SettingsSection.images.rawValue {
                activeSection += 1
            }
        }

        // Header strings
        var titleString = ""
        var textString = ""
        switch activeSection {
        case SettingsSection.server.rawValue:
            if (Model.sharedInstance().serverProtocol == "https://") {
                titleString = String(format: "%@ %@",
                                     NSLocalizedString("settingsHeader_server", comment: "Piwigo Server"),
                                     Model.sharedInstance().version)
            } else {
                titleString = String(format: "%@ %@\n",
                                     NSLocalizedString("settingsHeader_server", comment: "Piwigo Server"),
                                     Model.sharedInstance().version)
                textString = NSLocalizedString("settingsHeader_notSecure", comment: "Website Not Secure!")
            }
        case SettingsSection.logout.rawValue, SettingsSection.clear.rawValue:
            return 1
        case SettingsSection.albums.rawValue:
            titleString = NSLocalizedString("tabBar_albums", comment: "Albums")
        case SettingsSection.images.rawValue:
            titleString = NSLocalizedString("settingsHeader_images", comment: "Images")
        case SettingsSection.imageUpload.rawValue:
            titleString = NSLocalizedString("settingsHeader_upload", comment: "Default Upload Settings")
        case SettingsSection.color.rawValue:
            titleString = NSLocalizedString("settingsHeader_colors", comment: "Colors")
        case SettingsSection.cache.rawValue:
            titleString = NSLocalizedString("settingsHeader_cache", comment: "Cache Settings (Used/Total)")
        case SettingsSection.about.rawValue:
            titleString = NSLocalizedString("settingsHeader_about", comment: "Information")
        default:
            break
        }

        // Header height
        let context = NSStringDrawingContext()
        context.minimumScaleFactor = 1.0
        let titleAttributes = [
            NSAttributedString.Key.font: UIFont.piwigoFontBold()
        ]
        let titleRect = titleString.boundingRect(with: CGSize(width: tableView.frame.size.width - 30.0, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: titleAttributes, context: context)

        // Header height
        var headerHeight: Int
        if textString.count > 0 {
            let textAttributes = [
                NSAttributedString.Key.font: UIFont.piwigoFontSmall()
            ]
            let textRect = textString.boundingRect(with: CGSize(width: tableView.frame.size.width - 30.0, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: textAttributes, context: context)
            headerHeight = Int(fmax(44.0, ceil(titleRect.size.height + textRect.size.height)))
        } else {
            headerHeight = Int(fmax(44.0, ceil(titleRect.size.height)))
        }

        return CGFloat(headerHeight)
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        // User can upload images/videos if he/she is logged in and has:
        // — admin rights
        // — normal rights with upload access to some categories with Community
        var activeSection = section
        if !(Model.sharedInstance().hasAdminRights || (Model.sharedInstance().hasNormalRights && Model.sharedInstance().usesCommunityPluginV29)) {
            // Bypass the Upload section
            if activeSection > SettingsSection.images.rawValue {
                activeSection += 1
            }
        }

        // Header strings
        var titleString = ""
        var textString = ""
        switch activeSection {
        case SettingsSection.server.rawValue:
            if (Model.sharedInstance().serverProtocol == "https://") {
                titleString = String(format: "%@ %@",
                                     NSLocalizedString("settingsHeader_server", comment: "Piwigo Server"),
                                     Model.sharedInstance().version)
            } else {
                titleString = String(format: "%@ %@\n",
                                     NSLocalizedString("settingsHeader_server", comment: "Piwigo Server"),
                                     Model.sharedInstance().version)
                textString = NSLocalizedString("settingsHeader_notSecure", comment: "Website Not Secure!")
            }
        case SettingsSection.logout.rawValue, SettingsSection.clear.rawValue:
            return nil
        case SettingsSection.albums.rawValue:
            titleString = NSLocalizedString("tabBar_albums", comment: "Albums")
        case SettingsSection.images.rawValue:
            titleString = NSLocalizedString("settingsHeader_images", comment: "Images")
        case SettingsSection.imageUpload.rawValue:
            titleString = NSLocalizedString("settingsHeader_upload", comment: "Default Upload Settings")
        case SettingsSection.color.rawValue:
            titleString = NSLocalizedString("settingsHeader_colors", comment: "Colors")
        case SettingsSection.cache.rawValue:
            titleString = NSLocalizedString("settingsHeader_cache", comment: "Cache Settings (Used/Total)")
        case SettingsSection.about.rawValue:
            titleString = NSLocalizedString("settingsHeader_about", comment: "Information")
        default:
            break
        }

        let headerAttributedString = NSMutableAttributedString(string: "")

        // Title
        let titleAttributedString = NSMutableAttributedString(string: titleString)
        titleAttributedString.addAttribute(.font, value: UIFont.piwigoFontBold(), range: NSRange(location: 0, length: titleString.count))
        headerAttributedString.append(titleAttributedString)

        // Text
        if textString.count > 0 {
            let textAttributedString = NSMutableAttributedString(string: textString)
            textAttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall(), range: NSRange(location: 0, length: textString.count))
            headerAttributedString.append(textAttributedString)
        }

        // Header label
        let headerLabel = UILabel()
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        headerLabel.textColor = UIColor.piwigoColorHeader()
        headerLabel.numberOfLines = 0
        headerLabel.adjustsFontSizeToFitWidth = false
        headerLabel.lineBreakMode = .byWordWrapping
        headerLabel.attributedText = headerAttributedString

        // Header view
        let header = UIView()
        header.backgroundColor = UIColor.clear
        header.addSubview(headerLabel)
        header.addConstraint(NSLayoutConstraint.constraintView(fromBottom: headerLabel, amount: 4)!)
        if #available(iOS 11, *) {
            header.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|-[header]-|", options: [], metrics: nil, views: [
            "header": headerLabel
            ]))
        } else {
            header.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|-15-[header]-15-|", options: [], metrics: nil, views: [
            "header": headerLabel
            ]))
        }
        return header
    }

// MARK: - UITableView - Rows
    func numberOfSections(in tableView: UITableView) -> Int {
        let hasUploadSection = Model.sharedInstance().hasAdminRights ||
                               (Model.sharedInstance().hasNormalRights && Model.sharedInstance().usesCommunityPluginV29)
        return SettingsSection.count.rawValue - (hasUploadSection ? 0 : 1)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // User can upload images/videos if he/she is logged in and has:
        // — admin rights
        // — normal rights with upload access to some categories with Community
        var activeSection = section
        if !(Model.sharedInstance().hasAdminRights ||
             (Model.sharedInstance().hasNormalRights && Model.sharedInstance().usesCommunityPluginV29)) {
            // Bypass the Upload section
            if activeSection > SettingsSection.images.rawValue {
                activeSection += 1
            }
        }

        var nberOfRows = 0
        switch activeSection {
        case SettingsSection.server.rawValue:
            nberOfRows = 2
        case SettingsSection.logout.rawValue:
            nberOfRows = 1
        case SettingsSection.albums.rawValue:
            nberOfRows = 4
        case SettingsSection.images.rawValue:
            nberOfRows = 5
        case SettingsSection.imageUpload.rawValue:
            nberOfRows = 7 + (Model.sharedInstance().hasAdminRights ? 1 : 0)
                           + (Model.sharedInstance().resizeImageOnUpload ? 1 : 0)
                           + (Model.sharedInstance().compressImageOnUpload ? 1 : 0)
                           + (Model.sharedInstance().prefixFileNameBeforeUpload ? 1 : 0)
        case SettingsSection.color.rawValue:
            nberOfRows = 2
        case SettingsSection.cache.rawValue:
            nberOfRows = 3
        case SettingsSection.clear.rawValue:
            nberOfRows = 1
        case SettingsSection.about.rawValue:
            nberOfRows = 8
        default:
            break
        }
        return nberOfRows
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44.0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // User can upload images/videos if he/she is logged in and has:
        // — admin rights
        // — normal rights with upload access to some categories with Community
        var activeSection = indexPath.section
        if !(Model.sharedInstance().hasAdminRights ||
             (Model.sharedInstance().hasNormalRights && Model.sharedInstance().usesCommunityPluginV29)) {
            // Bypass the Upload section
            if activeSection > SettingsSection.images.rawValue {
                activeSection += 1
            }
        }

        var tableViewCell = UITableViewCell()
        switch activeSection {

        // MARK: Server
        case SettingsSection.server.rawValue /* Piwigo Server */:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell else {
                print("Error: tableView.dequeueReusableCell does not return a LabelTableViewCell!")
                return LabelTableViewCell()
            }
            switch indexPath.row {
            case 0:
                // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                let title = NSLocalizedString("settings_server", comment: "Address")
                var detail: String
                detail = String(format: "%@%@", Model.sharedInstance().serverProtocol, Model.sharedInstance().serverPath)
                cell.configure(with: title, detail: detail)
                cell.accessoryType = UITableViewCell.AccessoryType.none
                cell.accessibilityIdentifier = "server"
            
            case 1:
                let title = NSLocalizedString("settings_username", comment: "Username")
                var detail: String
                if Model.sharedInstance().username.count > 0 {
                    detail = Model.sharedInstance().username
                } else {
                    detail = NSLocalizedString("settings_notLoggedIn", comment: " - Not Logged In - ")
                }
                cell.configure(with: title, detail: detail)
                cell.accessoryType = UITableViewCell.AccessoryType.none
                cell.accessibilityIdentifier = "user"
            
            default:
                break
            }
            tableViewCell = cell

        case SettingsSection.logout.rawValue /* Login/Logout Button */:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "ButtonTableViewCell", for: indexPath) as? ButtonTableViewCell else {
                print("Error: tableView.dequeueReusableCell does not return a ButtonTableViewCell!")
                return ButtonTableViewCell()
            }
            if Model.sharedInstance().username.count > 0 {
                cell.configure(with: NSLocalizedString("settings_logout", comment: "Logout"))
            } else {
                cell.configure(with: NSLocalizedString("login", comment: "Login"))
            }
            cell.accessibilityIdentifier = "logout"
            tableViewCell = cell
        
        // MARK: Albums
        case SettingsSection.albums.rawValue /* Albums */:
            switch indexPath.row {
            case 0 /* Default album */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a LabelTableViewCell!")
                    return LabelTableViewCell()
                }
                let title = NSLocalizedString("setDefaultCategory_title", comment: "Default Album")
                var detail: String
                if Model.sharedInstance().defaultCategory == 0 {
                    detail = NSLocalizedString("categorySelection_root", comment: "Root Album")
                } else {
                    detail = CategoriesData.sharedInstance().getCategoryById(Model.sharedInstance().defaultCategory).name
                }
                cell.configure(with: title, detail: detail)
                cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                cell.accessibilityIdentifier = "defaultAlbum"
                tableViewCell = cell

            case 1 /* Thumbnail file */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a LabelTableViewCell!")
                    return LabelTableViewCell()
                }
                let defaultAlbum = PiwigoImageData.name(forAlbumThumbnailSizeType: kPiwigoImageSize(rawValue: kPiwigoImageSize.RawValue(Model.sharedInstance().defaultAlbumThumbnailSize)) as kPiwigoImageSize, withInfo: false)!
                // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                var title: String
                if view.bounds.size.width > 375 {
                    // i.e. larger than iPhones 6,7 screen width
                    title = NSLocalizedString("defaultAlbumThumbnailFile>414px", comment: "Album Thumbnail File")
                } else if view.bounds.size.width > 320 {
                    // i.e. larger than iPhone 5 screen width
                    title = NSLocalizedString("defaultThumbnailFile>320px", comment: "Thumbnail File")
                } else {
                    title = NSLocalizedString("defaultThumbnailFile", comment: "File")
                }
                cell.configure(with: title, detail: defaultAlbum)
                cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                cell.accessibilityIdentifier = "defaultAlbumThumbnailFile"
                tableViewCell = cell

            case 2 /* Default Sort */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a LabelTableViewCell!")
                    return LabelTableViewCell()
                }
                let defaultSort = CategorySortViewController.getNameForCategorySortType(Model.sharedInstance().defaultSort)
                // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                var title: String
                if view.bounds.size.width > 414 {
                    // i.e. larger than iPhones 6,7 Plus screen width
                    title = NSLocalizedString("defaultImageSort>414px", comment: "Default Sort of Images")
                } else if view.bounds.size.width > 320 {
                    // i.e. larger than iPhone 5 screen width
                    title = NSLocalizedString("defaultImageSort>320px", comment: "Default Sort")
                } else {
                    title = NSLocalizedString("defaultImageSort", comment: "Sort")
                }
                cell.configure(with: title, detail: defaultSort)
                cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                cell.accessibilityIdentifier = "defaultSort"
                tableViewCell = cell
 
            case 3 /* Number of recent albums */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "SliderTableViewCell", for: indexPath) as? SliderTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a SliderTableViewCell!")
                    return SliderTableViewCell()
                }
                // Slider value
                let value = Float(Model.sharedInstance().maxNberRecentCategories)

                // Slider configuration
                // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                var title: String = ""
                if view.bounds.size.width > 375 {
                    // i.e. larger than iPhones 6,7 screen width
                    title = NSLocalizedString("maxNberOfRecentAlbums>414px", comment: "Number of Recent Albums")
                } else if view.bounds.size.width > 320 {
                    // i.e. larger than iPhone 5 screen width
                    title = NSLocalizedString("maxNberOfRecentAlbums>320px", comment: "Recent Albums")
                } else {
                    title = NSLocalizedString("maxNberOfRecentAlbums", comment: "Recent")
                }
                cell.configure(with: title, value: value, increment: 1, minValue: 3, maxValue: 10, prefix: "", suffix: "/10")
                cell.cellSliderBlock = { newValue in
                    // Update settings
                    Model.sharedInstance().maxNberRecentCategories = UInt(newValue)
                    Model.sharedInstance().saveToDisk()
                }
                cell.accessibilityIdentifier = "maxNberRecentAlbums"
                tableViewCell = cell

            default:
                break
            }
        
        // MARK: Images
        case SettingsSection.images.rawValue /* Images */:
            switch indexPath.row {
            case 0 /* Thumbnail file */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a LabelTableViewCell!")
                    return LabelTableViewCell()
                }
                let defaultSize = PiwigoImageData.name(forImageThumbnailSizeType: kPiwigoImageSize(rawValue: kPiwigoImageSize.RawValue(Model.sharedInstance().defaultThumbnailSize)) as kPiwigoImageSize, withInfo: false)!
                // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                var title: String
                if view.bounds.size.width > 375 {
                    // i.e. larger than iPhones 6,7 screen width
                    title = NSLocalizedString("defaultThumbnailFile>414px", comment: "Image Thumbnail File")
                } else if view.bounds.size.width > 320 {
                    // i.e. larger than iPhone 5 screen width
                    title = NSLocalizedString("defaultThumbnailFile>320px", comment: "Thumbnail File")
                } else {
                    title = NSLocalizedString("defaultThumbnailFile", comment: "File")
                }
                cell.configure(with: title, detail: defaultSize)
                cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                cell.accessibilityIdentifier = "defaultImageThumbnailFile"
                tableViewCell = cell

            case 1 /* Number of thumbnails */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "SliderTableViewCell", for: indexPath) as? SliderTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a SliderTableViewCell!")
                    return SliderTableViewCell()
                }
                // Min/max number of thumbnails per row depends on selected file
                let defaultWidth = PiwigoImageData.width(forImageSizeType: kPiwigoImageSize(rawValue: kPiwigoImageSize.RawValue(Model.sharedInstance().defaultThumbnailSize)) as kPiwigoImageSize)
                let minNberOfImages = ImagesCollection.imagesPerRowInPortrait(for: nil, maxWidth: defaultWidth)

                // Slider value, chek that default number fits inside selected range
                if Float(Model.sharedInstance().thumbnailsPerRowInPortrait) > (2 * minNberOfImages) {
                    Model.sharedInstance().thumbnailsPerRowInPortrait = Int(2 * minNberOfImages)
                }
                if Float(Model.sharedInstance().thumbnailsPerRowInPortrait) < minNberOfImages {
                    Model.sharedInstance().thumbnailsPerRowInPortrait = Int(minNberOfImages)
                }
                let value = Float(Model.sharedInstance().thumbnailsPerRowInPortrait)

                // Slider configuration
                // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
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
                    Model.sharedInstance().thumbnailsPerRowInPortrait = Int(newValue)
                    Model.sharedInstance().saveToDisk()
                }
                cell.accessibilityIdentifier = "nberThumbnailFiles"
                tableViewCell = cell
                
            case 2 /* Display titles on thumbnails */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchTableViewCell", for: indexPath) as? SwitchTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a SwitchTableViewCell!")
                    return SwitchTableViewCell()
                }
                // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                if view.bounds.size.width > 320 {
                    cell.configure(with: NSLocalizedString("settings_displayTitles>320px", comment: "Display Titles on Thumbnails"))
                } else {
                    cell.configure(with: NSLocalizedString("settings_displayTitles", comment: "Titles on Thumbnails"))
                }
                
                // Switch status
                cell.cellSwitch.setOn(Model.sharedInstance().displayImageTitles, animated: true)
                cell.cellSwitch.accessibilityIdentifier = "switchImageTitles"
                cell.cellSwitchBlock = { switchState in
                    Model.sharedInstance().displayImageTitles = switchState
                    Model.sharedInstance().saveToDisk()
                }
                cell.accessibilityIdentifier = "displayImageTitles"
                tableViewCell = cell
                
            case 3 /* Default Size of Previewed Images */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a LabelTableViewCell!")
                    return LabelTableViewCell()
                }
                let defaultSize = PiwigoImageData.name(forImageSizeType: kPiwigoImageSize(rawValue: kPiwigoImageSize.RawValue(Model.sharedInstance().defaultImagePreviewSize)) as kPiwigoImageSize, withInfo: false)!
                // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                var title: String
                if view.bounds.size.width > 375 {
                    // i.e. larger than iPhones 6,7 screen width
                    title = NSLocalizedString("defaultPreviewFile>414px", comment: "Preview Image File")
                } else if view.bounds.size.width > 320 {
                    // i.e. larger than iPhone 5 screen width
                    title = NSLocalizedString("defaultPreviewFile>320px", comment: "Preview File")
                } else {
                    title = NSLocalizedString("defaultPreviewFile", comment: "Preview")
                }
                cell.configure(with: title, detail: defaultSize)
                cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                cell.accessibilityIdentifier = "defaultImagePreviewSize"
                tableViewCell = cell
                
            case 4 /* Share Image Metadata Options */:
                if #available(iOS 10, *) {
                    guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell else {
                        print("Error: tableView.dequeueReusableCell does not return a LabelTableViewCell!")
                        return LabelTableViewCell()
                    }
                    // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                    if view.bounds.size.width > 414 {
                        // i.e. larger than iPhones 6,7 screen width
                        cell.configure(with: NSLocalizedString("settings_shareGPSdata>375px", comment: "Share with Private Metadata"), detail: "")
                    } else {
                        cell.configure(with: NSLocalizedString("settings_shareGPSdata", comment: "Share Private Metadata"), detail: "")
                    }
                    cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                    cell.accessibilityIdentifier = "defaultShareOptions"
                    tableViewCell = cell
                    
                } else {
                    // Single On/Off share metadata option
                    guard let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchTableViewCell", for: indexPath) as? SwitchTableViewCell else {
                        print("Error: tableView.dequeueReusableCell does not return a SwitchTableViewCell!")
                        return SwitchTableViewCell()
                    }
                    // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                    if view.bounds.size.width > 414 {
                        // i.e. larger than iPhones 6,7 screen width
                        cell.configure(with: NSLocalizedString("settings_shareGPSdata>375px", comment: "Share Private Metadata"))
                    } else {
                        cell.configure(with: NSLocalizedString("settings_shareGPSdata", comment: "Share Metadata"))
                    }
                    cell.cellSwitch.setOn(Model.sharedInstance().shareMetadataTypeAirDrop, animated: true)
                    cell.cellSwitchBlock = { switchState in
                        Model.sharedInstance().shareMetadataTypeAirDrop = switchState
                        Model.sharedInstance().saveToDisk()
                    }
                    cell.accessibilityIdentifier = "shareMetadataOptions"
                    tableViewCell = cell
                    
                }
            default:
                break
            }
        
        // MARK: Default Upload Settings
        case SettingsSection.imageUpload.rawValue /* Default Upload Settings */:
            var row = indexPath.row
            row += (!Model.sharedInstance().hasAdminRights && (row > 0)) ? 1 : 0
            row += (!Model.sharedInstance().resizeImageOnUpload && (row > 3)) ? 1 : 0
            row += (!Model.sharedInstance().compressImageOnUpload && (row > 5)) ? 1 : 0
            row += (!Model.sharedInstance().prefixFileNameBeforeUpload && (row > 7)) ? 1 : 0
            switch row {
            case 0 /* Author Name? */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "TextFieldTableViewCell", for: indexPath) as? TextFieldTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a TextFieldTableViewCell!")
                    return TextFieldTableViewCell()
                }
                // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                var title: String
                let input: String = Model.sharedInstance().defaultAuthor
                let placeHolder: String = NSLocalizedString("settings_defaultAuthorPlaceholder", comment: "Author Name")
                if view.bounds.size.width > 320 {
                    // i.e. larger than iPhone 5 screen width
                    title = NSLocalizedString("settings_defaultAuthor>320px", comment: "Author Name")
                } else {
                    title = NSLocalizedString("settings_defaultAuthor", comment: "Author")
                }
                cell.configure(with: title, input: input, placeHolder: placeHolder)
                cell.rightTextField.delegate = self
                cell.rightTextField.tag = kImageUploadSetting.author.rawValue
                cell.accessibilityIdentifier = "defaultAuthorName"
                tableViewCell = cell
                
            case 1 /* Privacy Level? */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a LabelTableViewCell!")
                    return LabelTableViewCell()
                }
                let defaultLevel = Model.sharedInstance().getNameForPrivacyLevel(Model.sharedInstance().defaultPrivacyLevel)!
                // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                if view.bounds.size.width > 414 {
                    // i.e. larger than iPhones 6,7 Plus screen width
                    cell.configure(with: NSLocalizedString("privacyLevel", comment: "Privacy Level"), detail: defaultLevel)
                } else {
                    cell.configure(with: NSLocalizedString("settings_defaultPrivacy", comment: "Privacy"), detail: defaultLevel)
                }
                cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                cell.accessibilityIdentifier = "defaultPrivacyLevel"
                tableViewCell = cell
                
            case 2 /* Strip private Metadata? */:
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
                cell.cellSwitch.setOn(Model.sharedInstance().stripGPSdataOnUpload, animated: true)
                cell.cellSwitchBlock = { switchState in
                    Model.sharedInstance().stripGPSdataOnUpload = switchState
                    Model.sharedInstance().saveToDisk()
                }
                cell.accessibilityIdentifier = "stripMetadataBeforeUpload"
                tableViewCell = cell
                
            case 3 /* Resize Before Upload? */:
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
                cell.cellSwitch.setOn(Model.sharedInstance().resizeImageOnUpload, animated: true)
                cell.cellSwitchBlock = { switchState in
                    // Number of rows will change accordingly
                    Model.sharedInstance().resizeImageOnUpload = switchState
                    // Store modified setting
                    Model.sharedInstance().saveToDisk()
                    // Position of the row that should be added/removed
                    let rowAtIndexPath = IndexPath(row: 3 + (Model.sharedInstance().hasAdminRights ? 1 : 0),
                                                   section: SettingsSection.imageUpload.rawValue)
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
                
            case 4 /* Image Size slider */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "SliderTableViewCell", for: indexPath) as? SliderTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a SliderTableViewCell!")
                    return SliderTableViewCell()
                }
                // Slider value
                let value = Float(Model.sharedInstance().photoResize)

                // Slider configuration
                let title = String(format: "… %@", NSLocalizedString("settings_photoSize", comment: "Size"))
                cell.configure(with: title, value: value, increment: 1, minValue: 5, maxValue: 100, prefix: "", suffix: "%")
                cell.cellSliderBlock = { newValue in
                    // Update settings
                    Model.sharedInstance().photoResize = Int(newValue)
                    Model.sharedInstance().saveToDisk()
                }
                cell.accessibilityIdentifier = "maxNberRecentAlbums"
                tableViewCell = cell
                
            case 5 /* Compress before Upload? */:
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
                cell.cellSwitch.setOn(Model.sharedInstance().compressImageOnUpload, animated: true)
                cell.cellSwitchBlock = { switchState in
                    // Number of rows will change accordingly
                    Model.sharedInstance().compressImageOnUpload = switchState
                    // Store modified setting
                    Model.sharedInstance().saveToDisk()
                    // Position of the row that should be added/removed
                    let rowAtIndexPath = IndexPath(row: 4 + (Model.sharedInstance().hasAdminRights ? 1 : 0)
                                                          + (Model.sharedInstance().resizeImageOnUpload ? 1 : 0),
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
                
            case 6 /* Image Quality slider */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "SliderTableViewCell", for: indexPath) as? SliderTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a SliderTableViewCell!")
                    return SliderTableViewCell()
                }
                // Slider value
                let value = Float(Model.sharedInstance().photoQuality)

                // Slider configuration
                let title = String(format: "… %@", NSLocalizedString("settings_photoQuality", comment: "Quality"))
                cell.configure(with: title, value: value, increment: 1, minValue: 50, maxValue: 98, prefix: "", suffix: "%")
                cell.cellSliderBlock = { newValue in
                    // Update settings
                    Model.sharedInstance().photoQuality = Int(newValue)
                    Model.sharedInstance().saveToDisk()
                }
                cell.accessibilityIdentifier = "compressionRatio"
                tableViewCell = cell
                
            case 7 /* Prefix Filename Before Upload switch */:
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
                cell.cellSwitch.setOn(Model.sharedInstance().prefixFileNameBeforeUpload, animated: true)
                cell.cellSwitchBlock = { switchState in
                    // Number of rows will change accordingly
                    Model.sharedInstance().prefixFileNameBeforeUpload = switchState
                    // Store modified setting
                    Model.sharedInstance().saveToDisk()
                    // Position of the row that should be added/removed
                    let rowAtIndexPath = IndexPath(row: 5 + (Model.sharedInstance().hasAdminRights ? 1 : 0)
                                                          + (Model.sharedInstance().resizeImageOnUpload ? 1 : 0)
                                                          + (Model.sharedInstance().compressImageOnUpload ? 1 : 0),
                                                   section: SettingsSection.imageUpload.rawValue)
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
                
            case 8 /* Filename prefix? */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "TextFieldTableViewCell", for: indexPath) as? TextFieldTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a TextFieldTableViewCell!")
                    return TextFieldTableViewCell()
                }
                // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                var title: String
                let input: String = Model.sharedInstance().defaultPrefix
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
                cell.accessibilityIdentifier = "prefixFileName"
                tableViewCell = cell
                
            case 9 /* Wi-Fi Only? */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchTableViewCell", for: indexPath) as? SwitchTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a SwitchTableViewCell!")
                    return SwitchTableViewCell()
                }
                cell.configure(with: NSLocalizedString("settings_wifiOnly", comment: "Wi-Fi Only"))
                cell.cellSwitch.setOn(Model.sharedInstance().wifiOnlyUploading, animated: true)
                cell.cellSwitchBlock = { switchState in
                    // Change option
                    Model.sharedInstance().wifiOnlyUploading = switchState
                    Model.sharedInstance().saveToDisk()
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

            case 10 /* Delete image after upload? */:
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
                cell.cellSwitch.setOn(Model.sharedInstance().deleteImageAfterUpload, animated: true)
                cell.cellSwitchBlock = { switchState in
                    Model.sharedInstance().deleteImageAfterUpload = switchState
                    Model.sharedInstance().saveToDisk()
                }
                cell.accessibilityIdentifier = "deleteAfterUpload"
                tableViewCell = cell
                
            default:
                break
        }
        
        // MARK: Colors
        case SettingsSection.color.rawValue /* Colors */:
            let sectionOffset = !(Model.sharedInstance().hasAdminRights ||
                                  Model.sharedInstance().usesCommunityPluginV29) ||
                                !Model.sharedInstance().hadOpenedSession ? 1 : 0
            switch indexPath.row {
            case 0 /* Switch automatically? */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchTableViewCell", for: indexPath) as? SwitchTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a SwitchTableViewCell!")
                    return SwitchTableViewCell()
                }
                cell.configure(with: NSLocalizedString("settings_switchPalette", comment: "Switch Automatically"))
                cell.cellSwitch.setOn(Model.sharedInstance().switchPaletteAutomatically, animated: true)
                cell.cellSwitchBlock = { switchState in

                    // Number of rows will change accordingly
                    Model.sharedInstance().switchPaletteAutomatically = switchState

                    // Switch off Dark Palette mode if dynamic palette mode enabled
                    if switchState {
                        Model.sharedInstance().isDarkPaletteModeActive = false
                    }

                    // Store modified setting
                    Model.sharedInstance().saveToDisk()

                    // Position of the row that should be added/removed
                    let rowAtIndexPath = IndexPath(row: 1, section: SettingsSection.color.rawValue - sectionOffset)
                    self.settingsTableView?.reloadRows(at: [rowAtIndexPath], with: .automatic)

                    // Notify palette change
                    let appDelegate = UIApplication.shared.delegate as? AppDelegate
                    appDelegate?.screenBrightnessChanged()
                }
                cell.accessibilityIdentifier = "switchColourAuto"
                tableViewCell = cell
                
            case 1 /* Switch at Brightness? */:
                if Model.sharedInstance().switchPaletteAutomatically {
                    // Switch at Brightness ?
                    guard let cell = tableView.dequeueReusableCell(withIdentifier: "SliderTableViewCell", for: indexPath) as? SliderTableViewCell else {
                        print("Error: tableView.dequeueReusableCell does not return a SliderTableViewCell!")
                        return SliderTableViewCell()
                    }
                    // Slider value
                    let value = Float(Model.sharedInstance().switchPaletteThreshold)

                    // Slider configuration
                    let currentBrightness = UIScreen.main.brightness * 100
                    let prefix = String(format: "%ld/", lroundf(Float(currentBrightness)))
                    cell.configure(with: NSLocalizedString("settings_brightness", comment: "Brightness"), value: value, increment: 1, minValue: 0, maxValue: 100, prefix: prefix, suffix: "%")
                    cell.cellSliderBlock = { newThreshold in
                        // Update settings
                        Model.sharedInstance().switchPaletteThreshold = Int(newThreshold)
                        Model.sharedInstance().saveToDisk()
                        // Update palette if needed
                        let appDelegate = UIApplication.shared.delegate as? AppDelegate
                        appDelegate?.screenBrightnessChanged()
                    }
                    cell.accessibilityIdentifier = "brightnessLevel"
                    tableViewCell = cell
                    
                } else {
                    // Always use Dark Palette
                    guard let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchTableViewCell", for: indexPath) as? SwitchTableViewCell else {
                        print("Error: tableView.dequeueReusableCell does not return a SwitchTableViewCell!")
                        return SwitchTableViewCell()
                    }
                    cell.configure(with: NSLocalizedString("settings_darkPalette", comment: "Always Dark Palette"))
                    cell.cellSwitch.setOn(Model.sharedInstance().isDarkPaletteModeActive, animated: true)
                    cell.cellSwitchBlock = { switchState in

                        // Number of rows will change accordingly
                        Model.sharedInstance().isDarkPaletteModeActive = switchState

                        // Store modified setting
                        Model.sharedInstance().saveToDisk()

                        // Notify palette change
                        let appDelegate = UIApplication.shared.delegate as? AppDelegate
                        appDelegate?.screenBrightnessChanged()
                    }
                    cell.accessibilityIdentifier = "alwaysDark"
                    tableViewCell = cell
                    
                }
            default:
                break
            }

        // MARK: Cache Settings
        case SettingsSection.cache.rawValue /* Cache Settings */:
            switch indexPath.row {
            case 0 /* Download all Albums at Start */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchTableViewCell", for: indexPath) as? SwitchTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a SwitchTableViewCell!")
                    return SwitchTableViewCell()
                }
                // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                if view.bounds.size.width > 414 {
                    // i.e. larger than iPhones 6, 7 screen width
                    cell.configure(with: NSLocalizedString("settings_loadAllCategories>320px", comment: "Download all Albums at Start (uncheck if troubles)"))
                } else {
                    cell.configure(with: NSLocalizedString("settings_loadAllCategories", comment: "Download all Albums at Start"))
                }
                cell.cellSwitch.setOn(Model.sharedInstance().loadAllCategoryInfo, animated: true)
                cell.cellSwitchBlock = { switchState in
                    if !Model.sharedInstance().loadAllCategoryInfo && switchState {
                        AlbumService.getAlbumList(forCategory: 0, usingCache: false, inRecursiveMode: true, onCompletion: nil, onFailure: nil)
                    }

                    Model.sharedInstance().loadAllCategoryInfo = switchState
                    Model.sharedInstance().saveToDisk()
                }
                cell.accessibilityIdentifier = "loadAllCategories"
                tableViewCell = cell
                
            case 1 /* Disk */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "SliderTableViewCell", for: indexPath) as? SliderTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a SliderTableViewCell!")
                    return SliderTableViewCell()
                }
                // Slider value
                let value = Float(Model.sharedInstance().diskCache)

                // Slider configuration
                let currentDiskSize = Float(Model.sharedInstance().imageCache.currentDiskUsage)
                let currentDiskSizeInMB: Float = currentDiskSize / (1024.0 * 1024.0)
                // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                var prefix:String
                if view.bounds.size.width > 375 {
                    // i.e. larger than iPhones 6,7 screen width
                    prefix = String(format: "%.1f/", currentDiskSizeInMB)
                } else {
                    prefix = String(format: "%ld/", lroundf(currentDiskSizeInMB))
                }
                let suffix = NSLocalizedString("settings_cacheMegabytes", comment: "MB")
                cell.configure(with: NSLocalizedString("settings_cacheDisk", comment: "Disk"), value: value, increment: Float(kPiwigoDiskCacheInc), minValue: Float(kPiwigoDiskCacheMin), maxValue: Float(kPiwigoDiskCacheMax), prefix: prefix, suffix: suffix)
                cell.cellSliderBlock = { newValue in
                    // Update settings
                    Model.sharedInstance().diskCache = Int(newValue)
                    Model.sharedInstance().saveToDisk()
                    // Update disk cache size
                    Model.sharedInstance().imageCache.diskCapacity = Model.sharedInstance().diskCache * 1024 * 1024
                }
                cell.accessibilityIdentifier = "diskCache"
                tableViewCell = cell
                
            case 2 /* Memory */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "SliderTableViewCell", for: indexPath) as? SliderTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a SliderTableViewCell!")
                    return SliderTableViewCell()
                }
                // Slider value
                let value = Float(Model.sharedInstance().memoryCache)

                // Slider configuration
                let currentMemSize = Float(Model.sharedInstance().thumbnailCache.memoryUsage)
                let currentMemSizeInMB: Float = currentMemSize / (1024.0 * 1024.0)
                // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                var prefix:String
                if view.bounds.size.width > 375 {
                    // i.e. larger than iPhone 6,7 screen width
                    prefix = String(format: "%.1f/", currentMemSizeInMB)
                } else {
                    prefix = String(format: "%ld/", lroundf(currentMemSizeInMB))
                }
                let suffix = NSLocalizedString("settings_cacheMegabytes", comment: "MB")
                cell.configure(with: NSLocalizedString("settings_cacheMemory", comment: "Memory"), value: value, increment: Float(kPiwigoMemoryCacheInc), minValue: Float(kPiwigoMemoryCacheMin), maxValue: Float(kPiwigoMemoryCacheMax), prefix: prefix, suffix: suffix)
                cell.cellSliderBlock = { newValue in
                    // Update settings
                    Model.sharedInstance().memoryCache = Int(newValue)
                    Model.sharedInstance().saveToDisk()
                    // Update memory cache size
                    Model.sharedInstance().thumbnailCache.memoryCapacity = UInt64(Model.sharedInstance().memoryCache * 1024 * 1024)
                }
                cell.accessibilityIdentifier = "memoryCache"
                tableViewCell = cell
                
            default:
                break
            }

        case SettingsSection.clear.rawValue /* Clear Cache Button */:
            switch indexPath.row {
            case 0 /* Clear */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "ButtonTableViewCell", for: indexPath) as? ButtonTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a ButtonTableViewCell!")
                    return ButtonTableViewCell()
                }
                // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                if view.bounds.size.width > 414 {
                    // i.e. larger than iPhones 6, 7 screen width
                    cell.configure(with: NSLocalizedString("settings_cacheClearAll", comment: "Clear Photo Cache"))
                } else {
                    cell.configure(with: NSLocalizedString("settings_cacheClear", comment: "Clear Cache"))
                }
                cell.accessibilityIdentifier = "clearCache"
                tableViewCell = cell
                
            default:
                break
            }

        // MARK: Information
        case SettingsSection.about.rawValue /* Information */:
            switch indexPath.row {
            case 0 /* @piwigo (Twitter) */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a LabelTableViewCell!")
                    return LabelTableViewCell()
                }
                cell.configure(with: NSLocalizedString("settings_twitter", comment: "@piwigo"), detail: "")
                cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                cell.accessibilityIdentifier = "piwigoInfo"
                tableViewCell = cell
                
            case 1 /* Contact Us */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a LabelTableViewCell!")
                    return LabelTableViewCell()
                }
                cell.configure(with: NSLocalizedString("settings_contactUs", comment: "Contact Us"), detail: "")
                cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                if !MFMailComposeViewController.canSendMail() {
                    cell.titleLabel.textColor = UIColor.piwigoColorRightLabel()
                }
                cell.accessibilityIdentifier = "mailContact"
                tableViewCell = cell
                
            case 2 /* Support Forum */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a LabelTableViewCell!")
                    return LabelTableViewCell()
                }
                cell.configure(with: NSLocalizedString("settings_supportForum", comment: "Support Forum"), detail: "")
                cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                cell.accessibilityIdentifier = "supportForum"
                tableViewCell = cell
                
            case 3 /* Rate Piwigo Mobile */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a LabelTableViewCell!")
                    return LabelTableViewCell()
                }
                if let object = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") {
                    cell.configure(with: "\(NSLocalizedString("settings_rateInAppStore", comment: "Rate Piwigo Mobile")) \(object)", detail: "")
                }
                cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                cell.accessibilityIdentifier = "ratePiwigo"
                tableViewCell = cell
                
            case 4 /* Translate Piwigo Mobile */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a LabelTableViewCell!")
                    return LabelTableViewCell()
                }
                cell.configure(with: NSLocalizedString("settings_translateWithCrowdin", comment: "Translate Piwigo Mobile"), detail: "")
                cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                tableViewCell = cell
                
            case 5 /* Release Notes */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a LabelTableViewCell!")
                    return LabelTableViewCell()
                }
                cell.configure(with: NSLocalizedString("settings_releaseNotes", comment: "Release Notes"), detail: "")
                cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                cell.accessibilityIdentifier = "releaseNotes"
                tableViewCell = cell
                
            case 6 /* Acknowledgements */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a LabelTableViewCell!")
                    return LabelTableViewCell()
                }
                cell.configure(with: NSLocalizedString("settings_acknowledgements", comment: "Acknowledgements"), detail: "")
                cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                cell.accessibilityIdentifier = "acknowledgements"
                tableViewCell = cell
                
            case 7 /* Privacy Policy */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a LabelTableViewCell!")
                    return LabelTableViewCell()
                }
                cell.configure(with: NSLocalizedString("settings_privacy", comment: "Privacy Policy"), detail: "")
                cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                cell.accessibilityIdentifier = "privacyPolicy"
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

    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        // User can upload images/videos if he/she is logged in and has:
        // — admin rights
        // — normal rights with upload access to some categories with Community
        var activeSection = indexPath.section
        if !(Model.sharedInstance().hasAdminRights ||
             (Model.sharedInstance().hasNormalRights && Model.sharedInstance().usesCommunityPluginV29)) {
            // Bypass the Upload section
            if activeSection > SettingsSection.images.rawValue {
                activeSection += 1
            }
        }

        var result = true
        switch activeSection {

        // MARK: Server
        case SettingsSection.server.rawValue /* Piwigo Server */:
            result = false
        case SettingsSection.logout.rawValue /* Logout Button */:
            result = true
        
        // MARK: Albums
        case SettingsSection.albums.rawValue /* Albums */:
            switch indexPath.row {
            case 0 /* Default album */, 1 /* Default Thumbnail File */, 2 /* Default Sort */:
                result = true
            case 3 /* Nber Rcent albums */:
                result = false
            default:
                break
            }

        // MARK: Images
        case SettingsSection.images.rawValue /* Images */:
            switch indexPath.row {
            case 0 /* Default Thumbnail File */:
                result = true
            case 1 /* Number of thumbnails */, 2 /* Display titles on thumbnails */:
                result = false
            case 3 /* Default Size of Previewed Images */, 4 /* Share Image Metadata Options */:
                result = true
            default:
                break
            }
        // MARK: Default Upload Settings
        case SettingsSection.imageUpload.rawValue /* Default Upload Settings */:
            switch indexPath.row {
            case 0 /* Author Name */,
                 2 /* Strip private Metadata */,
                 3 /* Resize Before Upload */,
                 4 /* Image Size slider */,
                 5 /* Compress Before Upload switch */,
                 6 /* Image Quality slider */,
                 7 /* Prefix Filename Before Upload switch */,
                 8 /* Filename Prefix */,
                 9 /* Wi-Fi Only */,
                 10 /* Delete image after upload */:
                result = false
            case 1 /* Privacy Level */:
                result = true
            default:
                break
            }

        // MARK: Colors
        case SettingsSection.color.rawValue /* Colors */:
            result = false

        // MARK: Cache Settings
        case SettingsSection.cache.rawValue /* Cache Settings */:
            result = false
        case SettingsSection.clear.rawValue /* Cache Settings */:
            result = true

        // MARK: Information
        case SettingsSection.about.rawValue /* Information */:
            switch indexPath.row {
            case 1 /* Contact Us */:
                result = MFMailComposeViewController.canSendMail() ? true : false
            case 0 /* Twitter */, 2 /* Support Forum */, 3 /* Rate Piwigo Mobile */, 4 /* Translate Piwigo Mobile */, 5 /* Release Notes */, 6 /* Acknowledgements */, 7 /* Privacy Policy */:
                result = true
            default:
                break
            }
        default:
            break
        }
        return result
    }

// MARK: - UITableView - Footer
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        // No footer by default (nil => 0 point)
        var footer = ""

        // User can upload images/videos if he/she is logged in and has:
        // — admin rights
        // — normal rights with upload access to some categories with Community
        var activeSection = section
        if !(Model.sharedInstance().hasAdminRights ||
             (Model.sharedInstance().hasNormalRights && Model.sharedInstance().usesCommunityPluginV29)) {
            // Bypass the Upload section
            if activeSection > SettingsSection.images.rawValue {
                activeSection += 1
            }
        }

        // Any footer text?
        switch activeSection {
        case SettingsSection.logout.rawValue:
            if (Model.sharedInstance().serverFileTypes != nil) && (Model.sharedInstance().serverFileTypes.count > 0) {
                footer = "\(NSLocalizedString("settingsFooter_formats", comment: "The server accepts the following file formats")): \(Model.sharedInstance().serverFileTypes.replacingOccurrences(of: ",", with: ", "))."
            }
        case SettingsSection.about.rawValue:
            if nberImages.count > 0 {
                footer = "\(nberImages) \(NSLocalizedString("severalImages", comment: "Photos")), \(nberCategories) \(NSLocalizedString("tabBar_albums", comment: "Albums")), \(nberTags) \(NSLocalizedString("tags", comment: "Tags")), \(nberUsers) \(NSLocalizedString("settings_users", comment: "Users")), \(nberGroups) \(NSLocalizedString("settings_groups", comment: "Groups")), \(nberComments) \(NSLocalizedString("editImageDetails_comments", comment: "Comments"))"
            }
        default:
            return 16.0
        }

        // Footer height?
        let attributes = [
            NSAttributedString.Key.font: UIFont.piwigoFontSmall()
        ]
        let context = NSStringDrawingContext()
        context.minimumScaleFactor = 1.0
        let footerRect = footer.boundingRect(with: CGSize(width: tableView.frame.size.width - 30.0, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: attributes, context: context)

        return ceil(footerRect.size.height + 10.0)
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        // Footer label
        let footerLabel = UILabel()
        footerLabel.translatesAutoresizingMaskIntoConstraints = false
        footerLabel.font = UIFont.piwigoFontSmall()
        footerLabel.textColor = UIColor.piwigoColorHeader()
        footerLabel.textAlignment = .center
        footerLabel.numberOfLines = 0
        footerLabel.adjustsFontSizeToFitWidth = false
        footerLabel.lineBreakMode = .byWordWrapping

        // User can upload images/videos if he/she is logged in and has:
        // — admin rights
        // — normal rights with upload access to some categories with Community
        var activeSection = section
        if !(Model.sharedInstance().hasAdminRights ||
             (Model.sharedInstance().hasNormalRights && Model.sharedInstance().usesCommunityPluginV29)) {
            // Bypass the Upload section
            if activeSection > SettingsSection.images.rawValue {
                activeSection += 1
            }
        }

        // Footer text
        switch activeSection {
        case SettingsSection.logout.rawValue:
            if (Model.sharedInstance().serverFileTypes != nil) && (Model.sharedInstance().serverFileTypes.count > 0) {
                footerLabel.text = "\(NSLocalizedString("settingsFooter_formats", comment: "The server accepts the following file formats")): \(Model.sharedInstance().serverFileTypes.replacingOccurrences(of: ",", with: ", "))."
            }
        case SettingsSection.about.rawValue:
            if nberImages.count > 0 {
                footerLabel.text = "\(nberImages) \(NSLocalizedString("severalImages", comment: "Photos")), \(nberCategories) \(NSLocalizedString("tabBar_albums", comment: "Albums")), \(nberTags) \(NSLocalizedString("tags", comment: "Tags")), \(nberUsers) \(NSLocalizedString("settings_users", comment: "Users")), \(nberGroups) \(NSLocalizedString("settings_groups", comment: "Groups")), \(nberComments) \(NSLocalizedString("editImageDetails_comments", comment: "Comments"))"
            }
        default:
            break
        }

        // Footer view
        let footer = UIView()
        footer.backgroundColor = UIColor.clear
        footer.addSubview(footerLabel)
        footer.addConstraint(NSLayoutConstraint.constraintView(fromTop: footerLabel, amount: 4)!)
        if #available(iOS 11, *) {
            footer.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|-[footer]-|", options: [], metrics: nil, views: [
            "footer": footerLabel
            ]))
        } else {
            footer.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|-15-[footer]-15-|", options: [], metrics: nil, views: [
            "footer": footerLabel
            ]))
        }

        return footer
    }

// MARK: - UITableViewDelegate Methods
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        // User can upload images/videos if he/she is logged in and has:
        // — admin rights
        // — normal rights with upload access to some categories with Community
        var activeSection = indexPath.section
        if !(Model.sharedInstance().hasAdminRights ||
             (Model.sharedInstance().hasNormalRights && Model.sharedInstance().usesCommunityPluginV29)) {
            // Bypass the Upload section
            if activeSection > SettingsSection.images.rawValue {
                activeSection += 1
            }
        }

        switch activeSection {
        case SettingsSection.server.rawValue /* Piwigo Server */:
            break
        case SettingsSection.logout.rawValue /* Logout */:
            loginLogout()
        case SettingsSection.albums.rawValue /* Albums */:
            switch indexPath.row {
            case 0 /* Default album */:
                let categorySB = UIStoryboard(name: "DefaultCategoryViewController", bundle: nil)
                let categoryVC = categorySB.instantiateViewController(withIdentifier: "DefaultCategoryViewController") as? DefaultCategoryViewController
                categoryVC?.setCurrentCategory(Model.sharedInstance().defaultCategory)
                categoryVC?.delegate = self
                if let categoryVC = categoryVC {
                    navigationController?.pushViewController(categoryVC, animated: true)
                }
            case 1 /* Thumbnail file selection */:
                let defaultThumbnailSizeSB = UIStoryboard(name: "DefaultAlbumThumbnailSizeViewController", bundle: nil)
                let defaultThumbnailSizeVC = defaultThumbnailSizeSB.instantiateViewController(withIdentifier: "DefaultAlbumThumbnailSizeViewController") as? DefaultAlbumThumbnailSizeViewController
                if let defaultThumbnailSizeVC = defaultThumbnailSizeVC {
                    navigationController?.pushViewController(defaultThumbnailSizeVC, animated: true)
                }
            case 2 /* Sort method selection */:
                let categorySB = UIStoryboard(name: "CategorySortViewController", bundle: nil)
                let categoryVC = categorySB.instantiateViewController(withIdentifier: "CategorySortViewController") as? CategorySortViewController
                categoryVC?.currentCategorySortType = Model.sharedInstance().defaultSort
                categoryVC?.sortDelegate = self
                if let categoryVC = categoryVC {
                    navigationController?.pushViewController(categoryVC, animated: true)
                }
            default:
                break
            }
        case SettingsSection.images.rawValue /* Images */:
            switch indexPath.row {
            case 0 /* Thumbnail file selection */:
                let defaultThumbnailSizeSB = UIStoryboard(name: "DefaultImageThumbnailSizeViewController", bundle: nil)
                let defaultThumbnailSizeVC = defaultThumbnailSizeSB.instantiateViewController(withIdentifier: "DefaultImageThumbnailSizeViewController") as? DefaultImageThumbnailSizeViewController
                if let defaultThumbnailSizeVC = defaultThumbnailSizeVC {
                    navigationController?.pushViewController(defaultThumbnailSizeVC, animated: true)
                }
            case 3 /* Image file selection */:
                let defaultImageSizeSB = UIStoryboard(name: "DefaultImageSizeViewController", bundle: nil)
                let defaultImageSizeVC = defaultImageSizeSB.instantiateViewController(withIdentifier: "DefaultImageSizeViewController") as? DefaultImageSizeViewController
                if let defaultImageSizeVC = defaultImageSizeVC {
                    navigationController?.pushViewController(defaultImageSizeVC, animated: true)
                }
            case 4 /* Share image metadata options */:
                let metadataOptionsSB = UIStoryboard(name: "ShareMetadataViewController", bundle: nil)
                let metadataOptionsVC = metadataOptionsSB.instantiateViewController(withIdentifier: "ShareMetadataViewController") as? ShareMetadataViewController
                if let metadataOptionsVC = metadataOptionsVC {
                    navigationController?.pushViewController(metadataOptionsVC, animated: true)
                }
            default:
                break
            }
        case SettingsSection.imageUpload.rawValue /* Default upload Settings */:
            switch indexPath.row {
            case 1 /* Default privacy selection */:
                let privacySB = UIStoryboard(name: "SelectPrivacyViewController", bundle: nil)
                let privacyVC = privacySB.instantiateViewController(withIdentifier: "SelectPrivacyViewController") as? SelectPrivacyViewController
                privacyVC?.delegate = self
                privacyVC?.setPrivacy(Model.sharedInstance().defaultPrivacyLevel)
                if let privacyVC = privacyVC {
                    navigationController?.pushViewController(privacyVC, animated: true)
                }
            default:
                break
            }
        case SettingsSection.clear.rawValue /* Cache Clear */:
            switch indexPath.row {
            case 0 /* Clear cache */:
                #if DEBUG
                let alert = UIAlertController(title: "", message:"", preferredStyle: .actionSheet)
                #else
                let alert = UIAlertController(title: NSLocalizedString("settings_cacheClear", comment: "Clear Cache"), message: NSLocalizedString("settings_cacheClearMsg", comment: "Are you sure you want to clear the image cache? This will make albums and images take a while to load again."), preferredStyle: .alert)
                #endif

                let dismissAction = UIAlertAction(title: NSLocalizedString("alertDismissButton", comment: "Dismiss"), style: .cancel, handler: nil)

                #if DEBUG
                let nberOfTags = tagsProvider.fetchedResultsController.fetchedObjects?.count ?? 0
                let titleClearTags = nberOfTags > 1 ? String(format: "Clear %ld Tags", nberOfTags) : "Clear 1 Tag"
                let clearTagsAction = UIAlertAction(title: titleClearTags,
                                                    style: .default, handler: { action in
                    // Delete all tags in background queue
                    self.tagsProvider.clearTags()
                    TagsData.sharedInstance().clearCache()
                })

                let nberOfUploads = uploadsProvider.fetchedResultsController.fetchedObjects?.count ?? 0
                let titleClearUploadRequests = nberOfUploads > 1 ? String(format: "Clear %ld Upload Requests",
                    nberOfUploads) : "Clear 1 Upload Request"
                let clearUploadsAction = UIAlertAction(title: titleClearUploadRequests,
                                                       style: .default, handler: { action in
                    // Get all upload requests
                    guard let allUploads = self.uploadsProvider.fetchedResultsController.fetchedObjects else {
                        return
                    }
                    // Delete all upload requests in a private queue
                    DispatchQueue.global(qos: .userInitiated).async {
                        self.uploadsProvider.delete(uploadRequests: allUploads.map({$0.objectID}))
                    }
                })
                #endif

                let clearAction = UIAlertAction(title: NSLocalizedString("alertClearButton", comment: "Clear"), style: .destructive, handler: { action in
                        Model.sharedInstance().imageCache.removeAllCachedResponses()
                        self.settingsTableView?.reloadData()
                    })

                // Add actions
                alert.addAction(dismissAction)
                #if DEBUG
                alert.addAction(clearUploadsAction)
                alert.addAction(clearTagsAction)
                #endif
                alert.addAction(clearAction)

                // Determine position of cell in table view
                let rowAtIndexPath = IndexPath(row: 0, section: SettingsSection.clear.rawValue)
                let rectOfCellInTableView = settingsTableView?.rectForRow(at: rowAtIndexPath)

                // Present list of actions
                alert.view.tintColor = UIColor.piwigoColorOrange()
                if #available(iOS 13.0, *) {
                    alert.overrideUserInterfaceStyle = Model.sharedInstance().isDarkPaletteActive ? .dark : .light
                } else {
                    // Fallback on earlier versions
                }
                alert.popoverPresentationController?.sourceView = settingsTableView
                alert.popoverPresentationController?.permittedArrowDirections = [.up, .down]
                alert.popoverPresentationController?.sourceRect = rectOfCellInTableView ?? CGRect.zero
                present(alert, animated: true, completion: {
                    // Bugfix: iOS9 - Tint not fully Applied without Reapplying
                    alert.view.tintColor = UIColor.piwigoColorOrange()
                })
            default:
                break
            }
        case SettingsSection.about.rawValue /* About — Informations */:
            switch indexPath.row {
            case 0 /* Open @piwigo on Twitter */:
                if let url = URL(string: NSLocalizedString("settings_twitterURL", comment: "https://twitter.com/piwigo")) {
                    UIApplication.shared.openURL(url)
                }
            case 1 /* Prepare draft email */:
                if MFMailComposeViewController.canSendMail() {
                    let composeVC = MFMailComposeViewController()
                    composeVC.mailComposeDelegate = self

                    // Configure the fields of the interface.
                    composeVC.setToRecipients([
                    NSLocalizedString("contact_email", tableName: "PrivacyPolicy", bundle: Bundle.main, value: "", comment: "Contact email")
                    ])

                    // Collect version and build numbers
                    let appVersionString = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
                    let appBuildString = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

                    // Compile ticket number from current date
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyyMMddHHmm"
                    dateFormatter.locale = NSLocale(localeIdentifier: Model.sharedInstance().language) as Locale
                    let date = Date()
                    let ticketDate = dateFormatter.string(from: date)

                    // Set subject
                    composeVC.setSubject("[Ticket#\(ticketDate)]: \(NSLocalizedString("settings_appName", comment: "Piwigo Mobile")) \(NSLocalizedString("settings_feedback", comment: "Feedback"))")

                    // Collect system and device data
                    var systemInfo = utsname()
                    uname(&systemInfo)
                    let size = Int(_SYS_NAMELEN) // is 32, but posix AND its init is 256....
                    let deviceModel: String = DeviceUtilities.name(forCode: withUnsafeMutablePointer(to: &systemInfo.machine) {p in
                        p.withMemoryRebound(to: CChar.self, capacity: size, {p2 in
                            return String(cString: p2)
                        })
                    })
                    let deviceOS = UIDevice.current.systemName
                    let deviceOSversion = UIDevice.current.systemVersion

                    // Set message body
                    composeVC.setMessageBody("\(NSLocalizedString("settings_appName", comment: "Piwigo Mobile")) \(appVersionString ?? "") (\(appBuildString ?? ""))\n\(deviceModel ) — \(deviceOS) \(deviceOSversion)\n==============>>\n\n", isHTML: false)

                    // Present the view controller modally.
                    present(composeVC, animated: true)
                }
            case 2 /* Open Piwigo support forum webpage with default browser */:
                if let url = URL(string: NSLocalizedString("settings_pwgForumURL", comment: "http://piwigo.org/forum")) {
                    UIApplication.shared.openURL(url)
                }
            case 3 /* Open Piwigo App Store page for rating */:
                // See https://itunes.apple.com/us/app/piwigo/id472225196?ls=1&mt=8
                if let url = URL(string: "itms-apps://itunes.apple.com/app/piwigo/id472225196?action=write-review") {
                    UIApplication.shared.openURL(url)
                }
            case 4 /* Open Piwigo Crowdin page for translating */:
                if let url = URL(string: "https://crowdin.com/project/piwigo-mobile") {
                    UIApplication.shared.openURL(url)
                }
            case 5 /* Open Release Notes page */:
                let releaseNotesSB = UIStoryboard(name: "ReleaseNotesViewController", bundle: nil)
                let releaseNotesVC = releaseNotesSB.instantiateViewController(withIdentifier: "ReleaseNotesViewController") as? ReleaseNotesViewController
                if let releaseNotesVC = releaseNotesVC {
                    navigationController?.pushViewController(releaseNotesVC, animated: true)
                }
            case 6 /* Open Acknowledgements page */:
                let aboutSB = UIStoryboard(name: "AboutViewController", bundle: nil)
                let aboutVC = aboutSB.instantiateViewController(withIdentifier: "AboutViewController") as? AboutViewController
                if let aboutVC = aboutVC {
                    navigationController?.pushViewController(aboutVC, animated: true)
                }
            case 7 /* Open Privacy Policy page */:
                let privacyPolicySB = UIStoryboard(name: "PrivacyPolicyViewController", bundle: nil)
                let privacyPolicyVC = privacyPolicySB.instantiateViewController(withIdentifier: "PrivacyPolicyViewController") as? PrivacyPolicyViewController
                if let privacyPolicyVC = privacyPolicyVC {
                    navigationController?.pushViewController(privacyPolicyVC, animated: true)
                }
            default:
                break
            }
        default:
            break
        }
    }

    
// MARK: - Actions Methods

    func loginLogout() {
        if Model.sharedInstance().username.count > 0 {
            // Ask user for confirmation
            let alert = UIAlertController(title: "", message: NSLocalizedString("logoutConfirmation_message", comment: "Are you sure you want to logout?"), preferredStyle: .actionSheet)

            let cancelAction = UIAlertAction(title: NSLocalizedString("alertCancelButton", comment: "Cancel"), style: .cancel, handler: { action in
                })

            let logoutAction = UIAlertAction(title: NSLocalizedString("logoutConfirmation_title", comment: "Logout"), style: .destructive, handler: { action in
                    SessionService.sessionLogout(onCompletion: { task, success in

                        if success {
                            self.closeSessionAndClearCache()
                        } else {
                            let alert = UIAlertController(title: NSLocalizedString("logoutFail_title", comment: "Logout Failed"), message: NSLocalizedString("internetCancelledConnection_title", comment: "Connection Cancelled"), preferredStyle: .alert)

                            let dismissAction = UIAlertAction(title: NSLocalizedString("alertDismissButton", comment: "Dismiss"), style: .cancel, handler: { action in
                                    self.closeSessionAndClearCache()
                                })

                            // Add action
                            alert.addAction(dismissAction)

                            // Present list of actions
                            alert.view.tintColor = UIColor.piwigoColorOrange()
                            if #available(iOS 13.0, *) {
                                alert.overrideUserInterfaceStyle = Model.sharedInstance().isDarkPaletteActive ? .dark : .light
                            } else {
                                // Fallback on earlier versions
                            }
                            self.present(alert, animated: true, completion: {
                                // Bugfix: iOS9 - Tint not fully Applied without Reapplying
                                alert.view.tintColor = UIColor.piwigoColorOrange()
                            })
                        }

                    }, onFailure: { task, error in
                        // Failed! This may be due to the replacement of a self-signed certificate.
                        // So we inform the user that there may be something wrong with the server,
                        // or simply a connection drop.
                        let alert = UIAlertController(title: NSLocalizedString("logoutFail_title", comment: "Logout Failed"), message: NSLocalizedString("internetCancelledConnection_title", comment: "Connection Cancelled"), preferredStyle: .alert)

                        let dismissAction = UIAlertAction(title: NSLocalizedString("alertDismissButton", comment: "Dismiss"), style: .cancel, handler: { action in
                                self.closeSessionAndClearCache()
                            })

                        // Add action
                        alert.addAction(dismissAction)

                        // Present list of actions
                        alert.view.tintColor = UIColor.piwigoColorOrange()
                        if #available(iOS 13.0, *) {
                            alert.overrideUserInterfaceStyle = Model.sharedInstance().isDarkPaletteActive ? .dark : .light
                        } else {
                            // Fallback on earlier versions
                        }
                        self.present(alert, animated: true, completion: {
                            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
                            alert.view.tintColor = UIColor.piwigoColorOrange()
                        })
                    })
                })

            // Add actions
            alert.addAction(cancelAction)
            alert.addAction(logoutAction)

            // Determine position of cell in table view
            let rowAtIndexPath = IndexPath(row: 0, section: SettingsSection.logout.rawValue)
            let rectOfCellInTableView = settingsTableView?.rectForRow(at: rowAtIndexPath)

            // Present list of actions
            alert.view.tintColor = UIColor.piwigoColorOrange()
            if #available(iOS 13.0, *) {
                alert.overrideUserInterfaceStyle = Model.sharedInstance().isDarkPaletteActive ? .dark : .light
            } else {
                // Fallback on earlier versions
            }
            alert.popoverPresentationController?.sourceView = settingsTableView
            alert.popoverPresentationController?.permittedArrowDirections = [.up, .down]
            alert.popoverPresentationController?.sourceRect = rectOfCellInTableView ?? CGRect.zero
            present(alert, animated: true, completion: {
                // Bugfix: iOS9 - Tint not fully Applied without Reapplying
                alert.view.tintColor = UIColor.piwigoColorOrange()
            })
        } else {
            // Clear caches and display login view
            self.closeSessionAndClearCache()
        }
    }

    func closeSessionAndClearCache() {
        // Session closed
        Model.sharedInstance().sessionManager.invalidateSessionCancelingTasks(true, resetSession: true)
        Model.sharedInstance().imagesSessionManager.invalidateSessionCancelingTasks(true, resetSession: true)
        Model.sharedInstance().imageCache.removeAllCachedResponses()
        Model.sharedInstance().hadOpenedSession = false

        // Back to default values
        Model.sharedInstance().defaultCategory = 0
        Model.sharedInstance().usesCommunityPluginV29 = false
        Model.sharedInstance().hasAdminRights = false
        Model.sharedInstance().recentCategories = "0"
        Model.sharedInstance().saveToDisk()

        // Erase cache
        ClearCache.clearAllCache()
        if #available(iOS 13.0, *) {
            guard let window = (UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate)?.window else {
                return
            }

            let loginVC: LoginViewController
            if UIDevice.current.userInterfaceIdiom == .phone {
                loginVC = LoginViewController_iPhone.init()
            } else {
                loginVC = LoginViewController_iPad.init()
            }
            let nav = LoginNavigationController(rootViewController: loginVC)
            nav.isNavigationBarHidden = true
            window.rootViewController = nav
            UIView.transition(with: window, duration: 0.5,
                              options: .transitionCrossDissolve,
                              animations: nil, completion: nil)
        } else {
            // Fallback on earlier versions
            let appDelegate = UIApplication.shared.delegate as? AppDelegate
            appDelegate?.loadLoginView()
        }
    }

    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        // Check the result or perform other tasks.

        // Dismiss the mail compose view controller.
        dismiss(animated: true)
    }

    
// MARK: - UITextFieldDelegate Methods
    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        return true
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        settingsTableView?.endEditing(true)
        return true
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        switch textField.tag {
        case kImageUploadSetting.author.rawValue:
            Model.sharedInstance().defaultAuthor = textField.text
            Model.sharedInstance().saveToDisk()
        case kImageUploadSetting.prefix.rawValue:
            Model.sharedInstance().defaultPrefix = textField.text
            Model.sharedInstance().saveToDisk()
        default:
            break
        }
    }

    
// MARK: - DefaultCategoryDelegate Methods
    func didChangeDefaultCategory(_ categoryId: Int) {
        // Save new choice
        Model.sharedInstance().defaultCategory = categoryId
        Model.sharedInstance().saveToDisk()

        // Will load default album view when dismissing this view
        didChangeDefaultAlbum = true
    }

    
// MARK: - SelectedPrivacyDelegate Methods
    func didSelectPrivacyLevel(_ privacyLevel: kPiwigoPrivacy) {
        // Save new choice
        Model.sharedInstance().defaultPrivacyLevel = privacyLevel
        Model.sharedInstance().saveToDisk()
    }

    
// MARK: - CategorySortDelegate Methods
    func didSelectCategorySortType(_ sortType: kPiwigoSort) {
        // Save new choice
        Model.sharedInstance().defaultSort = sortType
        Model.sharedInstance().saveToDisk()
    }

    
// MARK: - Get Server Infos
        
    func getInfos() {
        AlbumService.getInfosOnCompletion({ task, infos in

            // Check returned infos
            guard let JSONdata: [Any] = infos else {
                self.nberCategories = ""
                self.nberImages = ""
                return
            }
 
            // Update data
            let numberFormatter = NumberFormatter()
            numberFormatter.numberStyle = .decimal
            for info in JSONdata {
                guard let info = info as? [String : Any] else {
                    continue
                }
                switch info["name"] as? String {
                case "nb_elements":
                    self.nberImages = numberFormatter.string(from: numberFormatter.number(from: info["value"] as! String) ?? 0)!
                case "nb_categories":
                    self.nberCategories = numberFormatter.string(from: numberFormatter.number(from: info["value"] as! String) ?? 0)!
                case "nb_tags":
                    self.nberTags = numberFormatter.string(from: numberFormatter.number(from: info["value"] as! String) ?? 0)!
                case "nb_users":
                    self.nberUsers = numberFormatter.string(from: numberFormatter.number(from: info["value"] as! String) ?? 0)!
                case "nb_groups":
                    self.nberGroups = numberFormatter.string(from: numberFormatter.number(from: info["value"] as! String) ?? 0)!
                case "nb_comments":
                    self.nberComments = numberFormatter.string(from: numberFormatter.number(from: info["value"] as! String) ?? 0)!
                default:
                    break
                }
            }

            // Refresh table with infos
            self.settingsTableView?.reloadData()
        }, onFailure: { task, error in
            self.nberCategories = ""
            self.nberImages = ""
        })
    }
}
