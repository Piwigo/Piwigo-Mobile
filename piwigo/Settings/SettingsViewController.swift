//
//  SettingsViewController.swift
//  piwigo
//
//  Created by Spencer Baker on 1/20/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//
//  Converted to Swift 5 by Eddy Lelièvre-Berna on 12/04/2020.
//

import Intents
import MessageUI
import UIKit
import piwigoKit

enum SettingsSection : Int {
    case server
    case logout
    case albums
    case images
    case imageUpload
    case appearance
    case cache
    case clear
    case about
    case count
}

enum kImageUploadSetting : Int {
    case author
    case prefix
}

let kHelpUsTitle: String = "Help Us!"
let kHelpUsTranslatePiwigo: String = "Piwigo is only partially translated in your language. Could you please help us complete the translation?"

@objc protocol ChangedSettingsDelegate: NSObjectProtocol {
    func didChangeDefaultAlbum()
    func didChangeRecentPeriod()
}

@objc
class SettingsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate, MFMailComposeViewControllerDelegate {

    @objc weak var settingsDelegate: ChangedSettingsDelegate?

    @IBOutlet var settingsTableView: UITableView!
    
    private var tableViewBottomConstraint: NSLayoutConstraint?
    private var doneBarButton: UIBarButtonItem?
    private var helpBarButton: UIBarButtonItem?
    private var statistics = ""


    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // Get Server Infos if possible
        if NetworkVars.hasAdminRights {
            DispatchQueue.global(qos: .userInitiated).async {
                self.getInfos()
            }
        }
        
        // Title
        title = NSLocalizedString("tabBar_preferences", comment: "Settings")

        // Button for returning to albums/images
        doneBarButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(quitSettings))
        doneBarButton?.accessibilityIdentifier = "Done"

        // Button for displaying help pages
        let helpButton = UIButton(type: .infoLight)
        helpButton.addTarget(self, action: #selector(displayHelp), for: .touchUpInside)
        helpBarButton = UIBarButtonItem(customView: helpButton)
        helpBarButton?.accessibilityIdentifier = "Help"

        // Table view identifier
        settingsTableView.accessibilityIdentifier = "settings"

        // Set colors, fonts, etc.
        applyColorPalette()
        
        // Check whether we should display the max size options
        if UploadVars.resizeImageOnUpload,
           UploadVars.photoMaxSize == 0, UploadVars.videoMaxSize == 0 {
            UploadVars.resizeImageOnUpload = false
        }
        
        // Check whether we should show the prefix option
        if UploadVars.prefixFileNameBeforeUpload,
           UploadVars.defaultPrefix.isEmpty {
            UploadVars.prefixFileNameBeforeUpload = false
        }
    }

    @objc func applyColorPalette() {
        // Background color of the view
        view.backgroundColor = .piwigoColorBackground()

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
        navigationController?.navigationBar.barStyle = AppVars.isDarkPaletteActive ? .black : .default
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

        // Table view
        settingsTableView?.separatorColor = .piwigoColorSeparator()
        settingsTableView?.indicatorStyle = AppVars.isDarkPaletteActive ? .white : .black
        settingsTableView?.reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Set navigation buttons
        navigationItem.setLeftBarButtonItems([doneBarButton].compactMap { $0 }, animated: true)
        navigationItem.setRightBarButtonItems([helpBarButton].compactMap { $0 }, animated: true)

        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: PwgNotifications.paletteChanged, object: nil)

        // Register auto-upload option enabled
        NotificationCenter.default.addObserver(self, selector: #selector(updateAutoUpload),
                                               name: PwgNotifications.autoUploadEnabled, object: nil)

        // Register auto-upload option disabled
        NotificationCenter.default.addObserver(self, selector: #selector(updateAutoUpload),
                                               name: PwgNotifications.autoUploadDisabled, object: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if #available(iOS 10, *) {
            let langCode: String = NSLocale.current.languageCode ?? "en"
//            print("=> langCode: ", String(describing: langCode))
//            print(String(format: "=> now:%.0f > last:%.0f + %.0f", Date().timeIntervalSinceReferenceDate, AppVars.dateOfLastTranslationRequest, k2WeeksInDays))
            let now: Double = Date().timeIntervalSinceReferenceDate
            let dueDate: Double = AppVars.dateOfLastTranslationRequest + AppVars.kPiwigoOneMonth
            if (now > dueDate) && (["ar","fa","pl","pt-BR","sk"].contains(langCode)) {
                // Store date of last translation request
                AppVars.dateOfLastTranslationRequest = now

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
                alert.view.tintColor = .piwigoColorOrange()
                if #available(iOS 13.0, *) {
                    alert.overrideUserInterfaceStyle = AppVars.isDarkPaletteActive ? .dark : .light
                } else {
                    // Fallback on earlier versions
                }
                present(alert, animated: true, completion: {
                    // Bugfix: iOS9 - Tint not fully Applied without Reapplying
                    alert.view.tintColor = .piwigoColorOrange()
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
                self.popoverPresentationController?.sourceRect = CGRect(x: mainScreenBounds.midX,
                                                                        y: mainScreenBounds.midY,
                                                                        width: 0, height: 0)
                self.preferredContentSize = CGSize(width: kPiwigoPadSettingsWidth,
                                                   height: ceil(mainScreenBounds.height * 2 / 3))
            }

            // Reload table view
            self.settingsTableView?.reloadData()
        })
    }

    deinit {
        // Unregister palette changes
        NotificationCenter.default.removeObserver(self, name: PwgNotifications.paletteChanged, object: nil)
        
        // Unregister auto-upload option enabler
        NotificationCenter.default.removeObserver(self, name: PwgNotifications.autoUploadEnabled, object: nil)

        // Unregister auto-upload option disabler
        NotificationCenter.default.removeObserver(self, name: PwgNotifications.autoUploadDisabled, object: nil)
    }

    @objc func quitSettings() {
        dismiss(animated: true)
    }
    
    @objc func displayHelp() {
        let helpSB = UIStoryboard(name: "HelpViewController", bundle: nil)
        let helpVC = helpSB.instantiateViewController(withIdentifier: "HelpViewController") as? HelpViewController
        if let helpVC = helpVC {
            // Update this list after deleting/creating Help##ViewControllers
            if #available(iOS 14, *) {
                helpVC.displayHelpPagesWithIndex = [0,4,5,1,3,6,2]
            } else if #available(iOS 13, *) {
                helpVC.displayHelpPagesWithIndex = [0,4,5,1,3,2]
            } else {
                helpVC.displayHelpPagesWithIndex = [0,4,5,3,2]
            }
            if UIDevice.current.userInterfaceIdiom == .phone {
                helpVC.popoverPresentationController?.permittedArrowDirections = .up
                navigationController?.present(helpVC, animated:true)
            } else {
                helpVC.modalPresentationStyle = .currentContext
                helpVC.modalTransitionStyle = .flipHorizontal
                helpVC.popoverPresentationController?.sourceView = view
                navigationController?.present(helpVC, animated: true)
            }
        }
    }

    @objc func updateAutoUpload(_ notification: Notification) {
        // NOP if the option is not available
        if !(NetworkVars.hasAdminRights ||
             (NetworkVars.hasNormalRights && NetworkVars.usesCommunityPluginV29)) { return }

        // Reload section instead of row because user's rights may have changed after logout/login
        children.forEach {
            if $0 is SettingsViewController {
                settingsTableView?.reloadSections(IndexSet(integer: SettingsSection.imageUpload.rawValue), with: .automatic)
            }
        }
        
        // Inform user if the AutoUploadViewController is not presented
        children.forEach { if $0 is AutoUploadViewController { return } }
        if let title = notification.userInfo?["title"] as? String, title.isEmpty == false,
           let message = notification.userInfo?["message"] as? String {
            dismissPiwigoError(withTitle: title, message: message) { }
        }
    }

    
    // MARK: - UITableView - Header
    private func getContentOfHeader(inSection section: Int) -> (String, String) {
        // User can upload images/videos if he/she is logged in and has:
        // — admin rights
        // — normal rights with upload access to some categories with Community
        var activeSection = section
        if !(NetworkVars.hasAdminRights || (NetworkVars.hasNormalRights && NetworkVars.usesCommunityPluginV29)) {
            // Bypass the Upload section
            if activeSection > SettingsSection.images.rawValue {
                activeSection += 1
            }
        }

        // Header strings
        var title = "", text = ""
        switch activeSection {
        case SettingsSection.server.rawValue:
            if (NetworkVars.serverProtocol == "https://") {
                title = String(format: "%@ %@",
                               NSLocalizedString("settingsHeader_server", comment: "Piwigo Server"),
                               NetworkVars.pwgVersion)
            } else {
                title = String(format: "%@ %@\n",
                               NSLocalizedString("settingsHeader_server", comment: "Piwigo Server"),
                               NetworkVars.pwgVersion)
                text = NSLocalizedString("settingsHeader_notSecure", comment: "Website Not Secure!")
            }
        case SettingsSection.albums.rawValue:
            title = NSLocalizedString("tabBar_albums", comment: "Albums")
        case SettingsSection.images.rawValue:
            title = NSLocalizedString("settingsHeader_images", comment: "Images")
        case SettingsSection.imageUpload.rawValue:
            title = NSLocalizedString("settingsHeader_upload", comment: "Default Upload Settings")
        case SettingsSection.appearance.rawValue:
            title = NSLocalizedString("settingsHeader_appearance", comment: "Appearance")
        case SettingsSection.cache.rawValue:
            title = NSLocalizedString("settingsHeader_cache", comment: "Cache Settings (Used/Total)")
        case SettingsSection.about.rawValue:
            title = NSLocalizedString("settingsHeader_about", comment: "Information")
        case SettingsSection.logout.rawValue, SettingsSection.clear.rawValue:
            fallthrough
        default:
            break
        }
        return (title, text)
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let (title, text) = getContentOfHeader(inSection: section)
        if title.isEmpty, text.isEmpty {
            return CGFloat(1)
        } else {
            return TableViewUtilities.heightOfHeader(withTitle: title, text: text,
                                                     width: tableView.frame.size.width)
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let (title, text) = getContentOfHeader(inSection: section)
        return TableViewUtilities.viewOfHeader(withTitle: title, text: text)
    }

    
    // MARK: - UITableView - Rows
    func numberOfSections(in tableView: UITableView) -> Int {
        let hasUploadSection = NetworkVars.hasAdminRights ||
                               (NetworkVars.hasNormalRights && NetworkVars.usesCommunityPluginV29)
        return SettingsSection.count.rawValue - (hasUploadSection ? 0 : 1)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // User can upload images/videos if he/she is logged in and has:
        // — admin rights
        // — normal rights with upload access to some categories with Community
        var activeSection = section
        if !(NetworkVars.hasAdminRights ||
             (NetworkVars.hasNormalRights && NetworkVars.usesCommunityPluginV29)) {
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
            nberOfRows = 6
        case SettingsSection.imageUpload.rawValue:
            nberOfRows = 7 + (NetworkVars.hasAdminRights ? 1 : 0)
            nberOfRows += (UploadVars.resizeImageOnUpload ? 2 : 0)
            nberOfRows += (UploadVars.compressImageOnUpload ? 1 : 0)
            nberOfRows += (UploadVars.prefixFileNameBeforeUpload ? 1 : 0)
            nberOfRows += (NetworkVars.usesUploadAsync ? 1 : 0)
        case SettingsSection.appearance.rawValue:
            nberOfRows = 1
        case SettingsSection.cache.rawValue:
            nberOfRows = 2
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
        var activeSection:Int = indexPath.section
        if !(NetworkVars.hasAdminRights ||
             (NetworkVars.hasNormalRights && NetworkVars.usesCommunityPluginV29)) {
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
                let detail = String(format: "%@%@", NetworkVars.serverProtocol, NetworkVars.serverPath)
                cell.configure(with: title, detail: detail)
                cell.accessoryType = UITableViewCell.AccessoryType.none
                cell.accessibilityIdentifier = "server"
            
            case 1:
                let title = NSLocalizedString("settings_username", comment: "Username")
                let detail = NetworkVars.username.isEmpty ? NSLocalizedString("settings_notLoggedIn", comment: " - Not Logged In - ") : NetworkVars.username
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
            if NetworkVars.username.isEmpty {
                cell.configure(with: NSLocalizedString("login", comment: "Login"))
            } else {
                cell.configure(with: NSLocalizedString("settings_logout", comment: "Logout"))
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
                cell.configure(with: title, detail: defaultAlbumName())
                cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                cell.accessibilityIdentifier = "defaultAlbum"
                tableViewCell = cell

            case 1 /* Thumbnail file */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a LabelTableViewCell!")
                    return LabelTableViewCell()
                }
                let albumImageSize = kPiwigoImageSize(AlbumVars.shared.defaultAlbumThumbnailSize)
                let defaultSize = PiwigoImageData.name(forAlbumThumbnailSizeType: albumImageSize, withInfo: false)!
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
                cell.configure(with: title, detail: defaultSize)
                cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                cell.accessibilityIdentifier = "defaultAlbumThumbnailFile"
                tableViewCell = cell

            case 2 /* Number of recent albums */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "SliderTableViewCell", for: indexPath) as? SliderTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a SliderTableViewCell!")
                    return SliderTableViewCell()
                }
                // Slider value
                let value = Float(AlbumVars.shared.maxNberRecentCategories)

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
                    AlbumVars.shared.maxNberRecentCategories = Int(newValue)
                }
                cell.accessibilityIdentifier = "maxNberRecentAlbums"
                tableViewCell = cell

            case 3 /* Recent period */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "SliderTableViewCell", for: indexPath) as? SliderTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a SliderTableViewCell!")
                    return SliderTableViewCell()
                }
                // Slider value is the index of kRecentPeriods
                var value:Float = Float(AlbumVars.shared.recentPeriodIndex)
                value = min(value, Float(AlbumVars.shared.recentPeriodList.count - 1))
                value = max(0.0, value)

                // Slider configuration
                let title = NSLocalizedString("recentPeriod_title", comment: "Recent Period")
                cell.configure(with: title, value: value, increment: Float(AlbumVars.shared.recentPeriodKey),
                               minValue: 0.0, maxValue: Float(AlbumVars.shared.recentPeriodList.count - 1),
                               prefix: "", suffix: NSLocalizedString("recentPeriod_days", comment: "%@ days"))
                cell.cellSliderBlock = { newValue in
                    // Update settings
                    let index = Int(newValue)
                    if index >= 0, index < AlbumVars.shared.recentPeriodList.count {
                        AlbumVars.shared.recentPeriodIndex = index
                    }
                    
                    // Reload root/default album
                    self.settingsDelegate?.didChangeRecentPeriod()
                }
                cell.accessibilityIdentifier = "recentPeriod"
                tableViewCell = cell

            default:
                break
            }
        
        // MARK: Images
        case SettingsSection.images.rawValue /* Images */:
            switch indexPath.row {
            case 0 /* Default Sort */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a LabelTableViewCell!")
                    return LabelTableViewCell()
                }
                let defSort = kPiwigoSort(rawValue: AlbumVars.shared.defaultSort)
                let defaultSort = CategorySortViewController.getNameForCategorySortType(defSort!)
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
 
            case 1 /* Thumbnail file */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a LabelTableViewCell!")
                    return LabelTableViewCell()
                }
                let defaultSize = PiwigoImageData.name(forImageThumbnailSizeType: kPiwigoImageSize(AlbumVars.shared.defaultThumbnailSize), withInfo: false)!
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

            case 2 /* Number of thumbnails */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "SliderTableViewCell", for: indexPath) as? SliderTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a SliderTableViewCell!")
                    return SliderTableViewCell()
                }
                // Min/max number of thumbnails per row depends on selected file
                let defaultWidth = PiwigoImageData.width(forImageSizeType: kPiwigoImageSize(AlbumVars.shared.defaultThumbnailSize))
                let minNberOfImages = Float(ImagesCollection.imagesPerRowInPortrait(for: nil, maxWidth: defaultWidth))

                // Slider value, chek that default number fits inside selected range
                if Float(AlbumVars.shared.thumbnailsPerRowInPortrait) > (2 * minNberOfImages) {
                    AlbumVars.shared.thumbnailsPerRowInPortrait = Int(2 * minNberOfImages)
                }
                if Float(AlbumVars.shared.thumbnailsPerRowInPortrait) < minNberOfImages {
                    AlbumVars.shared.thumbnailsPerRowInPortrait = Int(minNberOfImages)
                }
                let value = Float(AlbumVars.shared.thumbnailsPerRowInPortrait)

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
                    AlbumVars.shared.thumbnailsPerRowInPortrait = Int(newValue)
                }
                cell.accessibilityIdentifier = "nberThumbnailFiles"
                tableViewCell = cell
                
            case 3 /* Display titles on thumbnails */:
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
                cell.cellSwitch.setOn(AlbumVars.shared.displayImageTitles, animated: true)
                cell.cellSwitch.accessibilityIdentifier = "switchImageTitles"
                cell.cellSwitchBlock = { switchState in
                    AlbumVars.shared.displayImageTitles = switchState
                }
                cell.accessibilityIdentifier = "displayImageTitles"
                tableViewCell = cell
                
            case 4 /* Default Size of Previewed Images */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a LabelTableViewCell!")
                    return LabelTableViewCell()
                }
                let defaultSize = PiwigoImageData.name(forImageSizeType: kPiwigoImageSize(ImageVars.shared.defaultImagePreviewSize), withInfo: false)!
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
                
            case 5 /* Share Image Metadata Options */:
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
                    cell.cellSwitch.setOn(ImageVars.shared.shareMetadataTypeAirDrop, animated: true)
                    cell.cellSwitchBlock = { switchState in
                        ImageVars.shared.shareMetadataTypeAirDrop = switchState
                    }
                    cell.accessibilityIdentifier = "shareMetadataOptions"
                    tableViewCell = cell
                    
                }
            default:
                break
            }
        
        // MARK: Upload Settings
        case SettingsSection.imageUpload.rawValue /* Default Upload Settings */:
            var row = indexPath.row
            row += (!NetworkVars.hasAdminRights && (row > 0)) ? 1 : 0
            row += (!UploadVars.resizeImageOnUpload && (row > 3)) ? 2 : 0
            row += (!UploadVars.compressImageOnUpload && (row > 6)) ? 1 : 0
            row += (!UploadVars.prefixFileNameBeforeUpload && (row > 8)) ? 1 : 0
            row += (!NetworkVars.usesUploadAsync && (row > 10)) ? 1 : 0
            switch row {
            case 0 /* Author Name? */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "TextFieldTableViewCell", for: indexPath) as? TextFieldTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a TextFieldTableViewCell!")
                    return TextFieldTableViewCell()
                }
                // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                var title: String
                let input: String = UploadVars.defaultAuthor
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
                let defaultLevel = kPiwigoPrivacy(rawValue: UploadVars.defaultPrivacyLevel)!.name
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
                cell.cellSwitch.setOn(UploadVars.stripGPSdataOnUpload, animated: true)
                cell.cellSwitchBlock = { switchState in
                    UploadVars.stripGPSdataOnUpload = switchState
                }
                cell.accessibilityIdentifier = "stripMetadataBeforeUpload"
                tableViewCell = cell
                
            case 3 /* Resize Before Upload? */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchTableViewCell", for: indexPath) as? SwitchTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a SwitchTableViewCell!")
                    return SwitchTableViewCell()
                }
                cell.configure(with: NSLocalizedString("settings_photoResize", comment: "Resize Before Upload"))
                cell.cellSwitch.setOn(UploadVars.resizeImageOnUpload, animated: true)
                cell.cellSwitchBlock = { switchState in
                    // Number of rows will change accordingly
                    UploadVars.resizeImageOnUpload = switchState
                    // Position of the row that should be added/removed
                    let photoAtIndexPath = IndexPath(row: 3 + (NetworkVars.hasAdminRights ? 1 : 0),
                                                   section: SettingsSection.imageUpload.rawValue)
                    let videoAtIndexPath = IndexPath(row: 4 + (NetworkVars.hasAdminRights ? 1 : 0),
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
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a LabelTableViewCell!")
                    return LabelTableViewCell()
                }
                cell.configure(with: "… " + NSLocalizedString("severalImages", comment: "Photos"),
                               detail: pwgPhotoMaxSizes(rawValue: UploadVars.photoMaxSize)?.name ?? pwgPhotoMaxSizes(rawValue: 0)!.name)
                cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                cell.accessibilityIdentifier = "defaultUploadPhotoSize"
                tableViewCell = cell
                
            case 5 /* Upload Video Size */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a LabelTableViewCell!")
                    return LabelTableViewCell()
                }
                cell.configure(with: "… " + NSLocalizedString("severalVideos", comment: "Videos"),
                               detail: pwgVideoMaxSizes(rawValue: UploadVars.videoMaxSize)?.name ?? pwgVideoMaxSizes(rawValue: 0)!.name)
                cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                cell.accessibilityIdentifier = "defaultUploadVideoSize"
                tableViewCell = cell
                
            case 6 /* Compress before Upload? */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchTableViewCell", for: indexPath) as? SwitchTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a SwitchTableViewCell!")
                    return SwitchTableViewCell()
                }
                // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                if view.bounds.size.width > 375 {
                    // i.e. larger than iPhones 6,7 screen width
                    cell.configure(with: NSLocalizedString("settings_photoCompress>375px", comment: "Compress Photo Before Upload"))
                } else {
                    cell.configure(with: NSLocalizedString("settings_photoCompress", comment: "Compress Before Upload"))
                }
                cell.cellSwitch.setOn(UploadVars.compressImageOnUpload, animated: true)
                cell.cellSwitchBlock = { switchState in
                    // Number of rows will change accordingly
                    UploadVars.compressImageOnUpload = switchState
                    // Position of the row that should be added/removed
                    let rowAtIndexPath = IndexPath(row: 4 + (NetworkVars.hasAdminRights ? 1 : 0)
                                                          + (UploadVars.resizeImageOnUpload ? 2 : 0),
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
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "SliderTableViewCell", for: indexPath) as? SliderTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a SliderTableViewCell!")
                    return SliderTableViewCell()
                }
                // Slider value
                let value = Float(UploadVars.photoQuality)

                // Slider configuration
                let title = String(format: "… %@", NSLocalizedString("settings_photoQuality", comment: "Quality"))
                cell.configure(with: title, value: value, increment: 1, minValue: 50, maxValue: 98, prefix: "", suffix: "%")
                cell.cellSliderBlock = { newValue in
                    // Update settings
                    UploadVars.photoQuality = Int16(newValue)
                }
                cell.accessibilityIdentifier = "compressionRatio"
                tableViewCell = cell
                
            case 8 /* Prefix Filename Before Upload switch */:
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
                cell.cellSwitch.setOn(UploadVars.prefixFileNameBeforeUpload, animated: true)
                cell.cellSwitchBlock = { switchState in
                    // Number of rows will change accordingly
                    UploadVars.prefixFileNameBeforeUpload = switchState
                    // Position of the row that should be added/removed
                    let rowAtIndexPath = IndexPath(row: 5 + (NetworkVars.hasAdminRights ? 1 : 0)
                                                          + (UploadVars.resizeImageOnUpload ? 2 : 0)
                                                          + (UploadVars.compressImageOnUpload ? 1 : 0),
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
                
            case 9 /* Filename prefix? */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "TextFieldTableViewCell", for: indexPath) as? TextFieldTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a TextFieldTableViewCell!")
                    return TextFieldTableViewCell()
                }
                // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                var title: String
                let input: String = UploadVars.defaultPrefix
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
                
            case 10 /* Wi-Fi Only? */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchTableViewCell", for: indexPath) as? SwitchTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a SwitchTableViewCell!")
                    return SwitchTableViewCell()
                }
                cell.configure(with: NSLocalizedString("settings_wifiOnly", comment: "Wi-Fi Only"))
                cell.cellSwitch.setOn(UploadVars.wifiOnlyUploading, animated: true)
                cell.cellSwitchBlock = { switchState in
                    // Change option
                    UploadVars.wifiOnlyUploading = switchState
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

            case 11 /* Auto-upload */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a LabelTableViewCell!")
                    return LabelTableViewCell()
                }
                let title: String
                if view.bounds.size.width > 414 {
                    // i.e. larger than iPhones 6,7 screen width
                    title = NSLocalizedString("settings_autoUpload>414px", comment: "Auto Upload in the Background")
                } else {
                    title = NSLocalizedString("settings_autoUpload", comment: "Auto Upload")
                }
                let detail: String
                if UploadVars.isAutoUploadActive == true {
                    detail = NSLocalizedString("settings_autoUploadEnabled", comment: "On")
                } else {
                    detail = NSLocalizedString("settings_autoUploadDisabled", comment: "Off")
                }
                cell.configure(with: title, detail: detail)
                cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                cell.accessibilityIdentifier = "autoUpload"
                tableViewCell = cell

            case 12 /* Delete image after upload? */:
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
                cell.cellSwitch.setOn(UploadVars.deleteImageAfterUpload, animated: true)
                cell.cellSwitchBlock = { switchState in
                    UploadVars.deleteImageAfterUpload = switchState
                }
                cell.accessibilityIdentifier = "deleteAfterUpload"
                tableViewCell = cell
                
            default:
                break
        }
        
        // MARK: Appearance
        case SettingsSection.appearance.rawValue /* Appearance */:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell else {
                print("Error: tableView.dequeueReusableCell does not return a LabelTableViewCell!")
                return LabelTableViewCell()
            }
            let title = NSLocalizedString("settingsHeader_colorPalette", comment: "Color Palette")
            let detail: String
            if AppVars.isLightPaletteModeActive == true {
                detail = NSLocalizedString("settings_lightColor", comment: "Light")
            } else if AppVars.isDarkPaletteModeActive == true {
                detail = NSLocalizedString("settings_darkColor", comment: "Dark")
            } else {
                detail = NSLocalizedString("settings_switchPalette", comment: "Automatic")
            }
            cell.configure(with: title, detail: detail)
            cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
            cell.accessibilityIdentifier = "colorPalette"
            tableViewCell = cell

        // MARK: Cache Settings
        case SettingsSection.cache.rawValue /* Cache Settings */:
            switch indexPath.row {
            case 0 /* Disk */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "SliderTableViewCell", for: indexPath) as? SliderTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a SliderTableViewCell!")
                    return SliderTableViewCell()
                }
                // Slider value
                let value = Float(AppVars.diskCache)

                // Slider configuration
                let currentDiskSize = Float(NetworkVarsObjc.imageCache?.currentDiskUsage ?? 0)
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
                cell.configure(with: NSLocalizedString("settings_cacheDisk", comment: "Disk"),
                               value: value,
                               increment: Float(AppVars.kPiwigoDiskCacheInc),
                               minValue: Float(AppVars.kPiwigoDiskCacheMin),
                               maxValue: Float(AppVars.kPiwigoDiskCacheMax),
                               prefix: prefix, suffix: suffix)
                cell.cellSliderBlock = { newValue in
                    // Update settings
                    AppVars.diskCache = Int(newValue)
                    // Update disk cache size
                    NetworkVarsObjc.imageCache?.diskCapacity = AppVars.diskCache * 1024 * 1024
                }
                cell.accessibilityIdentifier = "diskCache"
                tableViewCell = cell
                
            case 1 /* Memory */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "SliderTableViewCell", for: indexPath) as? SliderTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a SliderTableViewCell!")
                    return SliderTableViewCell()
                }
                // Slider value
                let value = Float(AppVars.memoryCache)

                // Slider configuration
                let currentMemSize = Float(NetworkVarsObjc.thumbnailCache?.memoryUsage ?? 0)
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
                cell.configure(with: NSLocalizedString("settings_cacheMemory", comment: "Memory"),
                               value: value,
                               increment: Float(AppVars.kPiwigoMemoryCacheInc),
                               minValue: Float(AppVars.kPiwigoMemoryCacheMin),
                               maxValue: Float(AppVars.kPiwigoMemoryCacheMax),
                               prefix: prefix, suffix: suffix)
                cell.cellSliderBlock = { newValue in
                    // Update settings
                    AppVars.memoryCache = Int(newValue)
                    // Update memory cache size
                    NetworkVarsObjc.thumbnailCache?.memoryCapacity = UInt64(AppVars.memoryCache * 1024 * 1024)
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
                    cell.titleLabel.textColor = .piwigoColorRightLabel()
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
        if !(NetworkVars.hasAdminRights ||
             (NetworkVars.hasNormalRights && NetworkVars.usesCommunityPluginV29)) {
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
            case 0 /* Default album */, 1 /* Default Thumbnail File */:
                result = true
            default:
                result = false
            }

        // MARK: Images
        case SettingsSection.images.rawValue /* Images */:
            switch indexPath.row {
            case 0 /* Default Sort */,
                 1 /* Default Thumbnail File */,
                 4 /* Default Size of Previewed Images */,
                 5 /* Share Image Metadata Options */:
                result = true
            default:
                result = false
            }
            
        // MARK: Upload Settings
        case SettingsSection.imageUpload.rawValue /* Default Upload Settings */:
            var row = indexPath.row
            row += (!NetworkVars.hasAdminRights && (row > 0)) ? 1 : 0
            row += (!UploadVars.resizeImageOnUpload && (row > 3)) ? 2 : 0
            row += (!UploadVars.compressImageOnUpload && (row > 6)) ? 1 : 0
            row += (!UploadVars.prefixFileNameBeforeUpload && (row > 8)) ? 1 : 0
            row += (!NetworkVars.usesUploadAsync && (row > 10)) ? 1 : 0
            switch row {
            case 1  /* Privacy Level */,
                 4  /* Upload Photo Size */,
                 5  /* Upload Video Size */,
                 11 /* Auto upload */:
                result = true
            default:
                result = false
            }

        // MARK: Appearance
        case SettingsSection.appearance.rawValue /* Appearance */:
            result = true

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
            case 0 /* Twitter */,
                 2 /* Support Forum */,
                 3 /* Rate Piwigo Mobile */,
                 4 /* Translate Piwigo Mobile */,
                 5 /* Release Notes */,
                 6 /* Acknowledgements */,
                 7 /* Privacy Policy */:
                result = true
            default:
                result = false
            }
        default:
            result = false
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
        if !(NetworkVars.hasAdminRights ||
             (NetworkVars.hasNormalRights && NetworkVars.usesCommunityPluginV29)) {
            // Bypass the Upload section
            if activeSection > SettingsSection.images.rawValue {
                activeSection += 1
            }
        }

        // Any footer text?
        switch activeSection {
        case SettingsSection.logout.rawValue:
            if UploadVars.serverFileTypes.isEmpty == false {
                footer = "\(NSLocalizedString("settingsFooter_formats", comment: "The server accepts the following file formats")): \(UploadVars.serverFileTypes.replacingOccurrences(of: ",", with: ", "))."
            }
        case SettingsSection.about.rawValue:
            footer = statistics
        default:
            return 16.0
        }

        // Footer height?
        let attributes = [
            NSAttributedString.Key.font: UIFont.piwigoFontSmall()
        ]
        let context = NSStringDrawingContext()
        context.minimumScaleFactor = 1.0
        let footerRect = footer.boundingRect(with: CGSize(width: tableView.frame.size.width - CGFloat(30),
                                                          height: CGFloat.greatestFiniteMagnitude),
                                             options: .usesLineFragmentOrigin,
                                             attributes: attributes, context: context)

        return ceil(footerRect.size.height + 10.0)
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        // Footer label
        let footerLabel = UILabel()
        footerLabel.translatesAutoresizingMaskIntoConstraints = false
        footerLabel.font = .piwigoFontSmall()
        footerLabel.textColor = .piwigoColorHeader()
        footerLabel.textAlignment = .center
        footerLabel.numberOfLines = 0
        footerLabel.adjustsFontSizeToFitWidth = false
        footerLabel.lineBreakMode = .byWordWrapping

        // User can upload images/videos if he/she is logged in and has:
        // — admin rights
        // — normal rights with upload access to some categories with Community
        var activeSection = section
        if !(NetworkVars.hasAdminRights ||
             (NetworkVars.hasNormalRights && NetworkVars.usesCommunityPluginV29)) {
            // Bypass the Upload section
            if activeSection > SettingsSection.images.rawValue {
                activeSection += 1
            }
        }

        // Footer text
        switch activeSection {
        case SettingsSection.logout.rawValue:
            if UploadVars.serverFileTypes.isEmpty == false {
                footerLabel.text = "\(NSLocalizedString("settingsFooter_formats", comment: "The server accepts the following file formats")): \(UploadVars.serverFileTypes.replacingOccurrences(of: ",", with: ", "))."
            }
        case SettingsSection.about.rawValue:
            footerLabel.text = statistics
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
    
    private func getInfos() {
        // Initialisation
        statistics = ""
        
        // Collect stats from server
        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: kPiwigoGetInfos, paramDict: [:],
                                jsonObjectClientExpectsToReceive: GetInfosJSON.self,
                                countOfBytesClientExpectsToReceive: 1000) { jsonData in
            // Decode the JSON object and retrieve statistics.
            do {
                // Decode the JSON into codable type TagJSON.
                let decoder = JSONDecoder()
                let uploadJSON = try decoder.decode(GetInfosJSON.self, from: jsonData)

                // Piwigo error?
                if uploadJSON.errorCode != 0 {
                    #if DEBUG
                    let error = PwgSession.shared.localizedError(for: uploadJSON.errorCode,
                                                                    errorMessage: uploadJSON.errorMessage)
                    debugPrint(error)
                    #endif
                    return
                }

                // Collect statistics
                let numberFormatter = NumberFormatter()
                numberFormatter.numberStyle = .decimal
                for info in uploadJSON.data {
                    guard let value = info.value, let nber = Int(value) else { continue }
                    switch info.name ?? "" {
                    case "nb_elements":
                        if let nberPhotos = numberFormatter.string(from: NSNumber(value: nber)) {
                            let nberImages = nber > 1 ?
                                String(format: NSLocalizedString("severalImagesCount", comment: "%@ photos"), nberPhotos) :
                                String(format: NSLocalizedString("singleImageCount", comment: "%@ photo"), nberPhotos)
                            if nberImages.isEmpty == false { self.appendStats(nberImages) }
                        }
                    case "nb_categories":
                        if let nberCats = numberFormatter.string(from: NSNumber(value: nber)) {
                            let nberCategories = nber > 1 ?
                                String(format: NSLocalizedString("severalAlbumsCount", comment: "%@ albums"), nberCats) :
                                String(format: NSLocalizedString("singleAlbumCount", comment: "%@ album"), nberCats)
                            if nberCategories.isEmpty == false { self.appendStats(nberCategories) }
                        }
                    case "nb_tags":
                        if let nberTags = numberFormatter.string(from: NSNumber(value: nber)) {
                            let nberTags = nber > 1 ?
                                String(format: NSLocalizedString("severalTagsCount", comment: "%@ tags"), nberTags) :
                                String(format: NSLocalizedString("singleTagCount", comment: "%@ tag"), nberTags)
                            if nberTags.isEmpty == false { self.appendStats(nberTags) }
                        }
                    case "nb_users":
                        if let nberUsers = numberFormatter.string(from: NSNumber(value: nber)) {
                            let nberUsers = nber > 1 ?
                                String(format: NSLocalizedString("severalUsersCount", comment: "%@ users"), nberUsers) :
                                String(format: NSLocalizedString("singleUserCount", comment: "%@ user"), nberUsers)
                            if nberUsers.isEmpty == false { self.appendStats(nberUsers) }
                        }
                    case "nb_groups":
                        if let nberGroups = numberFormatter.string(from: NSNumber(value: nber)) {
                            let nberGroups = nber > 1 ?
                                String(format: NSLocalizedString("severalGroupsCount", comment: "%@ groups"), nberGroups) :
                                String(format: NSLocalizedString("singleGroupCount", comment: "%@ group"), nberGroups)
                            if nberGroups.isEmpty == false { self.appendStats(nberGroups) }
                        }
                    case "nb_comments":
                        if let nberComments = numberFormatter.string(from: NSNumber(value: nber)) {
                            let nberComments = nber > 1 ?
                                String(format: NSLocalizedString("severalCommentsCount", comment: "%@ comments"), nberComments) :
                                String(format: NSLocalizedString("singleCommentCount", comment: "%@ comment"), nberComments)
                            if nberComments.isEmpty == false { self.appendStats(nberComments) }
                        }
                    default:
                        break
                    }
                }
            } catch let error as NSError {
                // Data cannot be digested
                #if DEBUG
                debugPrint(error)
                #endif
                return
            }
        } failure: { _ in
            /// - Network communication errors
            /// - Returned JSON data is empty
            /// - Cannot decode data returned by Piwigo server
            /// -> nothing presented in the footer
        }
    }

    private func appendStats(_ info: String) {
        if statistics.isEmpty {
            statistics.append(info)
        } else {
            statistics.append(" | " + info)
        }
    }

    
    // MARK: - UITableViewDelegate Methods
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        // User can upload images/videos if he/she is logged in and has:
        // — admin rights
        // — normal rights with upload access to some categories with Community
        var activeSection = indexPath.section
        if !(NetworkVars.hasAdminRights ||
             (NetworkVars.hasNormalRights && NetworkVars.usesCommunityPluginV29)) {
            // Bypass the Upload section
            if activeSection > SettingsSection.images.rawValue {
                activeSection += 1
            }
        }

        switch activeSection {

        // MARK: Server
        case SettingsSection.server.rawValue /* Piwigo Server */:
            break

        // MARK: Logout
        case SettingsSection.logout.rawValue /* Logout */:
            loginLogout()

        // MARK: Albums
        case SettingsSection.albums.rawValue /* Albums */:
            switch indexPath.row {
            case 0 /* Default album */:
                let categorySB = UIStoryboard(name: "SelectCategoryViewControllerGrouped", bundle: nil)
                guard let categoryVC = categorySB.instantiateViewController(withIdentifier: "SelectCategoryViewControllerGrouped") as? SelectCategoryViewController else { return }
                categoryVC.setInput(parameter: AlbumVars.shared.defaultCategory,
                                    for: kPiwigoCategorySelectActionSetDefaultAlbum)
                categoryVC.delegate = self
                navigationController?.pushViewController(categoryVC, animated: true)
            case 1 /* Thumbnail file selection */:
                let defaultThumbnailSizeSB = UIStoryboard(name: "DefaultAlbumThumbnailSizeViewController", bundle: nil)
                guard let defaultThumbnailSizeVC = defaultThumbnailSizeSB.instantiateViewController(withIdentifier: "DefaultAlbumThumbnailSizeViewController") as? DefaultAlbumThumbnailSizeViewController else { return }
                defaultThumbnailSizeVC.delegate = self
                navigationController?.pushViewController(defaultThumbnailSizeVC, animated: true)
            default:
                break
            }

        // MARK: Images
        case SettingsSection.images.rawValue /* Images */:
            switch indexPath.row {
            case 0 /* Sort method selection */:
                let categorySB = UIStoryboard(name: "CategorySortViewController", bundle: nil)
                guard let categoryVC = categorySB.instantiateViewController(withIdentifier: "CategorySortViewController") as? CategorySortViewController else {return }
                categoryVC.sortDelegate = self
                navigationController?.pushViewController(categoryVC, animated: true)
            case 1 /* Thumbnail file selection */:
                let defaultThumbnailSizeSB = UIStoryboard(name: "DefaultImageThumbnailSizeViewController", bundle: nil)
                guard let defaultThumbnailSizeVC = defaultThumbnailSizeSB.instantiateViewController(withIdentifier: "DefaultImageThumbnailSizeViewController") as? DefaultImageThumbnailSizeViewController else { return }
                defaultThumbnailSizeVC.delegate = self
                navigationController?.pushViewController(defaultThumbnailSizeVC, animated: true)
            case 4 /* Image file selection */:
                let defaultImageSizeSB = UIStoryboard(name: "DefaultImageSizeViewController", bundle: nil)
                guard let defaultImageSizeVC = defaultImageSizeSB.instantiateViewController(withIdentifier: "DefaultImageSizeViewController") as? DefaultImageSizeViewController else { return }
                defaultImageSizeVC.delegate = self
                navigationController?.pushViewController(defaultImageSizeVC, animated: true)
            case 5 /* Share image metadata options */:
                let metadataOptionsSB = UIStoryboard(name: "ShareMetadataViewController", bundle: nil)
                guard let metadataOptionsVC = metadataOptionsSB.instantiateViewController(withIdentifier: "ShareMetadataViewController") as? ShareMetadataViewController else { return }
                navigationController?.pushViewController(metadataOptionsVC, animated: true)
            default:
                break
            }

        // MARK: Upload Settings
        case SettingsSection.imageUpload.rawValue /* Default upload Settings */:
            var row = indexPath.row
            row += (!NetworkVars.hasAdminRights && (row > 0)) ? 1 : 0
            row += (!UploadVars.resizeImageOnUpload && (row > 3)) ? 2 : 0
            row += (!UploadVars.compressImageOnUpload && (row > 6)) ? 1 : 0
            row += (!UploadVars.prefixFileNameBeforeUpload && (row > 8)) ? 1 : 0
            row += (!NetworkVars.usesUploadAsync && (row > 10)) ? 1 : 0
            switch row {
            case 1 /* Default privacy selection */:
                let privacySB = UIStoryboard(name: "SelectPrivacyViewController", bundle: nil)
                guard let privacyVC = privacySB.instantiateViewController(withIdentifier: "SelectPrivacyViewController") as? SelectPrivacyViewController else { return }
                privacyVC.delegate = self
                privacyVC.privacy = kPiwigoPrivacy(rawValue: UploadVars.defaultPrivacyLevel) ?? .everybody
                navigationController?.pushViewController(privacyVC, animated: true)
            case 4 /* Upload Photo Size */:
                let uploadPhotoSizeSB = UIStoryboard(name: "UploadPhotoSizeViewController", bundle: nil)
                guard let uploadPhotoSizeVC = uploadPhotoSizeSB.instantiateViewController(withIdentifier: "UploadPhotoSizeViewController") as? UploadPhotoSizeViewController else { return }
                uploadPhotoSizeVC.delegate = self
                uploadPhotoSizeVC.photoMaxSize = UploadVars.photoMaxSize
                navigationController?.pushViewController(uploadPhotoSizeVC, animated: true)
            case 5 /* Upload Video Size */:
                let uploadVideoSizeSB = UIStoryboard(name: "UploadVideoSizeViewController", bundle: nil)
                guard let uploadVideoSizeVC = uploadVideoSizeSB.instantiateViewController(withIdentifier: "UploadVideoSizeViewController") as? UploadVideoSizeViewController else { return }
                uploadVideoSizeVC.delegate = self
                uploadVideoSizeVC.videoMaxSize = UploadVars.videoMaxSize
                navigationController?.pushViewController(uploadVideoSizeVC, animated: true)
            case 11 /* Auto Upload */:
                let autoUploadSB = UIStoryboard(name: "AutoUploadViewController", bundle: nil)
                guard let autoUploadVC = autoUploadSB.instantiateViewController(withIdentifier: "AutoUploadViewController") as? AutoUploadViewController else { return }
                navigationController?.pushViewController(autoUploadVC, animated: true)
            default:
                break
            }

        // MARK: Appearance
        case SettingsSection.appearance.rawValue /* Appearance */:
            if #available(iOS 13.0, *) {
                let colorPaletteSB = UIStoryboard(name: "ColorPaletteViewController", bundle: nil)
                guard let colorPaletteVC = colorPaletteSB.instantiateViewController(withIdentifier: "ColorPaletteViewController") as? ColorPaletteViewController else { return }
                navigationController?.pushViewController(colorPaletteVC, animated: true)
            } else {
                let colorPaletteSB = UIStoryboard(name: "ColorPaletteViewControllerOld", bundle: nil)
                guard let colorPaletteVC = colorPaletteSB.instantiateViewController(withIdentifier: "ColorPaletteViewControllerOld") as? ColorPaletteViewControllerOld else { return }
                navigationController?.pushViewController(colorPaletteVC, animated: true)
            }

        // MARK: Cache Settings
        case SettingsSection.clear.rawValue /* Cache Clear */:
            switch indexPath.row {
            case 0 /* Clear cache */:
                #if DEBUG
                let alert = UIAlertController(title: "", message:NSLocalizedString("settings_cacheClearMsg", comment: "Are you sure you want to clear the cache? This will make albums and images take a while to load again."), preferredStyle: .actionSheet)
                #else
                let alert = UIAlertController(title: NSLocalizedString("settings_cacheClear", comment: "Clear Cache"), message: NSLocalizedString("settings_cacheClearMsg", comment: "Are you sure you want to clear the cache? This will make albums and images take a while to load again."), preferredStyle: .alert)
                #endif

                let dismissAction = UIAlertAction(title: NSLocalizedString("alertDismissButton", comment: "Dismiss"), style: .cancel, handler: nil)

                #if DEBUG
                let clearTagsAction = UIAlertAction(title: "Clear All Tags",
                                                    style: .default, handler: { action in
                    // Delete all tags in background queue
                    TagsProvider().clearTags()
                    TagsData.sharedInstance().clearCache()
                })
                alert.addAction(clearTagsAction)
                
                let titleClearLocations = "Clear All Locations"
                let clearLocationsAction = UIAlertAction(title: titleClearLocations,
                                                         style: .default, handler: { action in
                    // Delete all locations in background queue
                    LocationsProvider().clearLocations()
                })
                alert.addAction(clearLocationsAction)
                
                let clearUploadsAction = UIAlertAction(title: "Clear All Upload Requests",
                                                       style: .default, handler: { action in
                    // Delete all upload requests in the main thread
                    UploadsProvider().clearUploads()
                })
                alert.addAction(clearUploadsAction)
                #endif

                let clearAction = UIAlertAction(title: NSLocalizedString("alertClearButton", comment: "Clear"), style: .destructive, handler: { action in
                    // Delete image cache
                    ClearCache.clearAllCache(exceptCategories: true) {
                        // Reload tableView
                        self.settingsTableView?.reloadData()
                    }
                })

                // Add actions
                alert.addAction(dismissAction)
                alert.addAction(clearAction)

                // Determine position of cell in table view
                let rowAtIndexPath = IndexPath(row: 0, section: SettingsSection.clear.rawValue)
                let rectOfCellInTableView = settingsTableView?.rectForRow(at: rowAtIndexPath)

                // Present list of actions
                alert.view.tintColor = .piwigoColorOrange()
                if #available(iOS 13.0, *) {
                    alert.overrideUserInterfaceStyle = AppVars.isDarkPaletteActive ? .dark : .light
                } else {
                    // Fallback on earlier versions
                }
                alert.popoverPresentationController?.sourceView = settingsTableView
                alert.popoverPresentationController?.permittedArrowDirections = [.up, .down]
                alert.popoverPresentationController?.sourceRect = rectOfCellInTableView ?? CGRect.zero
                present(alert, animated: true, completion: {
                    // Bugfix: iOS9 - Tint not fully Applied without Reapplying
                    alert.view.tintColor = .piwigoColorOrange()
                })
            default:
                break
            }

        // MARK: Information
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
                    dateFormatter.locale = NSLocale(localeIdentifier: NetworkVars.language) as Locale
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
        if NetworkVars.username.isEmpty {
            // Clear caches and display login view
            self.closeSessionAndClearCache()
            return
        }
        
        // Ask user for confirmation
        let alert = UIAlertController(title: "", message: NSLocalizedString("logoutConfirmation_message", comment: "Are you sure you want to logout?"), preferredStyle: .actionSheet)

        let cancelAction = UIAlertAction(title: NSLocalizedString("alertCancelButton", comment: "Cancel"), style: .cancel, handler: { action in
        })

        let logoutAction = UIAlertAction(title: NSLocalizedString("logoutConfirmation_title", comment: "Logout"), style: .destructive, handler: { action in
            LoginUtilities.performLogout {
                // Logout successful
                DispatchQueue.main.async {
                    self.closeSessionAndClearCache()
                }
            } failure: { error in
                // Failed! This may be due to the replacement of a self-signed certificate.
                // So we inform the user that there may be something wrong with the server,
                // or simply a connection drop.
                self.dismissPiwigoError(withTitle: NSLocalizedString("logoutFail_title", comment: "Logout Failed"),
                                        message: error.localizedDescription) {
                    self.closeSessionAndClearCache()
                }
            }
        })

        // Add actions
        alert.addAction(cancelAction)
        alert.addAction(logoutAction)

        // Determine position of cell in table view
        let rowAtIndexPath = IndexPath(row: 0, section: SettingsSection.logout.rawValue)
        let rectOfCellInTableView = settingsTableView?.rectForRow(at: rowAtIndexPath)

        // Present list of actions
        alert.view.tintColor = .piwigoColorOrange()
        if #available(iOS 13.0, *) {
            alert.overrideUserInterfaceStyle = AppVars.isDarkPaletteActive ? .dark : .light
        } else {
            // Fallback on earlier versions
        }
        alert.popoverPresentationController?.sourceView = settingsTableView
        alert.popoverPresentationController?.permittedArrowDirections = [.up, .down]
        alert.popoverPresentationController?.sourceRect = rectOfCellInTableView ?? CGRect.zero
        present(alert, animated: true, completion: {
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            alert.view.tintColor = .piwigoColorOrange()
        })
    }

    func closeSessionAndClearCache() {
        // Session closed
        NetworkVarsObjc.sessionManager?.invalidateSessionCancelingTasks(true, resetSession: true)
        NetworkVarsObjc.imagesSessionManager?.invalidateSessionCancelingTasks(true, resetSession: true)
        NetworkVarsObjc.imageCache?.removeAllCachedResponses()

        // Back to default values
        AlbumVars.shared.defaultCategory = 0
        AlbumVars.shared.recentCategories = "0"
        NetworkVars.usesCommunityPluginV29 = false
        NetworkVars.hasAdminRights = false
        
        // Disable Auto-Uploading and clear settings
        UploadVars.isAutoUploadActive = false
        UploadVars.autoUploadCategoryId = NSNotFound
        UploadVars.autoUploadAlbumId = ""
        UploadVars.autoUploadTagIds = ""
        UploadVars.autoUploadComments = ""

        // Erase cache
        ClearCache.clearAllCache(exceptCategories: false,
                                 completionHandler: {
            if #available(iOS 13.0, *) {
                guard let window = (UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate)?.window else {
                    return
                }

                let loginVC: LoginViewController
                if UIDevice.current.userInterfaceIdiom == .phone {
                    loginVC = LoginViewController_iPhone()
                } else {
                    loginVC = LoginViewController_iPad()
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
        })
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
            UploadVars.defaultAuthor = textField.text ?? ""
        case kImageUploadSetting.prefix.rawValue:
            UploadVars.defaultPrefix = textField.text ?? ""
            if UploadVars.defaultPrefix.isEmpty {
                UploadVars.prefixFileNameBeforeUpload = false
                // Remove row in existing table
                let prefixIndexPath = IndexPath(row: 5 + (NetworkVars.hasAdminRights ? 1 : 0)
                                                       + (UploadVars.resizeImageOnUpload ? 2 : 0)
                                                       + (UploadVars.compressImageOnUpload ? 1 : 0),
                                                section: SettingsSection.imageUpload.rawValue)
                settingsTableView?.deleteRows(at: [prefixIndexPath], with: .automatic)

                // Refresh flag
                let indexPath = IndexPath(row: prefixIndexPath.row - 1,
                                          section: SettingsSection.imageUpload.rawValue)
                settingsTableView?.reloadRows(at: [indexPath], with: .automatic)
            }
        default:
            break
        }
    }
}


// MARK: - SelectCategoryDelegate Methods
extension SettingsViewController: SelectCategoryDelegate {
    func didSelectCategory(withId categoryId: Int) {
        // Do nothing if new default album is unknown or unchanged
        if categoryId == NSNotFound ||
            categoryId == AlbumVars.shared.defaultCategory
        { return }

        // Save new choice
        AlbumVars.shared.defaultCategory = categoryId

        // Change album name in row
        let indexPath = IndexPath(row: 0, section: SettingsSection.albums.rawValue)
        if let indexPaths = settingsTableView.indexPathsForVisibleRows, indexPaths.contains(indexPath),
           let cell = settingsTableView.cellForRow(at: indexPath) as? LabelTableViewCell {
            cell.detailLabel.text = defaultAlbumName()
        }

        // Switch to new default album
        settingsDelegate?.didChangeDefaultAlbum()
    }
    
    private func defaultAlbumName() -> String {
        var rootName: String
        if view.bounds.size.width > 375 {
            rootName = NSLocalizedString("categorySelection_root", comment: "Root Album")
        } else {
            rootName = NSLocalizedString("categorySelection_root<375pt", comment: "Root")
        }

        // Root album?
        if AlbumVars.shared.defaultCategory == 0 {
            return rootName
        }
        
        // Default album…
        if let albumName = CategoriesData.sharedInstance().getCategoryById(AlbumVars.shared.defaultCategory).name {
            return albumName
        } else {
            AlbumVars.shared.defaultCategory = 0
            return rootName
        }
    }
}


// MARK: - DefaultAlbumThumbnailSizeDelegate Methods
extension SettingsViewController: DefaultAlbumThumbnailSizeDelegate {
    func didSelectAlbumDefaultThumbnailSize(_ thumbnailSize: kPiwigoImageSize) {
        // Do nothing if size is unchanged
        if thumbnailSize == kPiwigoImageSize(AlbumVars.shared.defaultAlbumThumbnailSize) { return }
        
        // Save new choice
        AlbumVars.shared.defaultAlbumThumbnailSize = thumbnailSize.rawValue

        // Refresh settings row
        let indexPath = IndexPath(row: 1, section: SettingsSection.albums.rawValue)
        if let indexPaths = settingsTableView.indexPathsForVisibleRows, indexPaths.contains(indexPath),
           let cell = settingsTableView.cellForRow(at: indexPath) as? LabelTableViewCell {
            cell.detailLabel.text = PiwigoImageData.name(forAlbumThumbnailSizeType: thumbnailSize, withInfo: false)!
        }
    }
}


// MARK: - CategorySortDelegate Methods
extension SettingsViewController: CategorySortDelegate {
    func didSelectCategorySortType(_ sortType: kPiwigoSort) {
        // Do nothing if sort type is unchanged
        if sortType == kPiwigoSort(rawValue: AlbumVars.shared.defaultSort) { return }
        
        // Save new choice
        AlbumVars.shared.defaultSort = sortType.rawValue

        // Refresh settings
        let indexPath = IndexPath(row: 0, section: SettingsSection.images.rawValue)
        if let indexPaths = settingsTableView.indexPathsForVisibleRows, indexPaths.contains(indexPath),
           let cell = settingsTableView.cellForRow(at: indexPath) as? LabelTableViewCell {
            cell.detailLabel.text = CategorySortViewController.getNameForCategorySortType(sortType)
        }
        
        // Clear image data in cache
        for category in CategoriesData.sharedInstance().allCategories {
            category.resetData()
        }
    }
}


// MARK: - DefaultImageThumbnailSizeDelegate Methods
extension SettingsViewController: DefaultImageThumbnailSizeDelegate {
    func didSelectImageDefaultThumbnailSize(_ thumbnailSize: kPiwigoImageSize) {
        // Do nothing if size is unchanged
        if thumbnailSize == kPiwigoImageSize(AlbumVars.shared.defaultThumbnailSize) { return }
        
        // Save new choice
        AlbumVars.shared.defaultThumbnailSize = thumbnailSize.rawValue

        // Refresh settings
        let indexPath = IndexPath(row: 1, section: SettingsSection.images.rawValue)
        if let indexPaths = settingsTableView.indexPathsForVisibleRows, indexPaths.contains(indexPath),
           let cell = settingsTableView.cellForRow(at: indexPath) as? LabelTableViewCell {
            cell.detailLabel.text = PiwigoImageData.name(forAlbumThumbnailSizeType: thumbnailSize, withInfo: false)!
        }
    }
}

// MARK: - DefaultImageSizeDelegate Methods
extension SettingsViewController: DefaultImageSizeDelegate {
    func didSelectImageDefaultSize(_ imageSize: kPiwigoImageSize) {
        // Do nothing if size is unchanged
        if imageSize == kPiwigoImageSize(ImageVars.shared.defaultImagePreviewSize) { return }
        
        // Save new choice
        ImageVars.shared.defaultImagePreviewSize = imageSize.rawValue

        // Refresh settings
        let indexPath = IndexPath(row: 4, section: SettingsSection.images.rawValue)
        if let indexPaths = settingsTableView.indexPathsForVisibleRows, indexPaths.contains(indexPath),
           let cell = settingsTableView.cellForRow(at: indexPath) as? LabelTableViewCell {
            cell.detailLabel.text = PiwigoImageData.name(forAlbumThumbnailSizeType: imageSize, withInfo: false)!
        }
    }
}

// MARK: - SelectedPrivacyDelegate Methods
extension SettingsViewController: SelectPrivacyDelegate {
    func didSelectPrivacyLevel(_ privacyLevel: kPiwigoPrivacy) {
        // Do nothing if privacy level is unchanged
        if privacyLevel == kPiwigoPrivacy(rawValue: UploadVars.defaultPrivacyLevel) { return }
        
        // Save new choice
        UploadVars.defaultPrivacyLevel = privacyLevel.rawValue

        // Refresh settings
        let indexPath = IndexPath(row: 1, section: SettingsSection.imageUpload.rawValue)
        if let indexPaths = settingsTableView.indexPathsForVisibleRows, indexPaths.contains(indexPath),
           let cell = settingsTableView.cellForRow(at: indexPath) as? LabelTableViewCell {
            cell.detailLabel.text = kPiwigoPrivacy(rawValue: UploadVars.defaultPrivacyLevel)!.name
        }
    }
}

// MARK: - UploadPhotoSizeDelegate Methods
extension SettingsViewController: UploadPhotoSizeDelegate {
    func didSelectUploadPhotoSize(_ newSize: Int16) {
        // Was the size modified?
        if newSize != UploadVars.photoMaxSize {
            // Save new choice
            UploadVars.photoMaxSize = newSize
            
            // Refresh corresponding row
            let photoAtIndexPath = IndexPath(row: 3 + (NetworkVars.hasAdminRights ? 1 : 0),
                                             section: SettingsSection.imageUpload.rawValue)
            if let indexPaths = settingsTableView.indexPathsForVisibleRows, indexPaths.contains(photoAtIndexPath),
               let cell = settingsTableView.cellForRow(at: photoAtIndexPath) as? LabelTableViewCell {
                cell.detailLabel.text = pwgPhotoMaxSizes(rawValue: UploadVars.photoMaxSize)?.name ?? pwgPhotoMaxSizes(rawValue: 0)!.name
            }
        }
        
        // Hide rows if needed
        if UploadVars.photoMaxSize == 0, UploadVars.videoMaxSize == 0 {
            UploadVars.resizeImageOnUpload = false
            // Position of the rows which should be removed
            let photoAtIndexPath = IndexPath(row: 3 + (NetworkVars.hasAdminRights ? 1 : 0),
                                             section: SettingsSection.imageUpload.rawValue)
            let videoAtIndexPath = IndexPath(row: 4 + (NetworkVars.hasAdminRights ? 1 : 0),
                                             section: SettingsSection.imageUpload.rawValue)
            // Remove row in existing table
            settingsTableView?.deleteRows(at: [photoAtIndexPath, videoAtIndexPath], with: .automatic)

            // Refresh flag
            let indexPath = IndexPath(row: photoAtIndexPath.row - 1,
                                      section: SettingsSection.imageUpload.rawValue)
            settingsTableView?.reloadRows(at: [indexPath], with: .automatic)
        }
    }
}

// MARK: - UploadVideoSizeDelegate Methods
extension SettingsViewController: UploadVideoSizeDelegate {
    func didSelectUploadVideoSize(_ newSize: Int16) {
        // Was the size modified?
        if newSize != UploadVars.videoMaxSize {
            // Save new choice after verification
            UploadVars.videoMaxSize = newSize

            // Refresh corresponding row
            let videoAtIndexPath = IndexPath(row: 4 + (NetworkVars.hasAdminRights ? 1 : 0),
                                             section: SettingsSection.imageUpload.rawValue)
            if let indexPaths = settingsTableView.indexPathsForVisibleRows, indexPaths.contains(videoAtIndexPath),
               let cell = settingsTableView.cellForRow(at: videoAtIndexPath) as? LabelTableViewCell {
                cell.detailLabel.text = pwgVideoMaxSizes(rawValue: UploadVars.videoMaxSize)?.name ?? pwgVideoMaxSizes(rawValue: 0)!.name
            }
            settingsTableView.reloadRows(at: [videoAtIndexPath], with: .automatic)
        }
        
        // Hide rows if needed
        if UploadVars.photoMaxSize == 0, UploadVars.videoMaxSize == 0 {
            UploadVars.resizeImageOnUpload = false
            // Position of the rows which should be removed
            let photoAtIndexPath = IndexPath(row: 3 + (NetworkVars.hasAdminRights ? 1 : 0),
                                           section: SettingsSection.imageUpload.rawValue)
            let videoAtIndexPath = IndexPath(row: 4 + (NetworkVars.hasAdminRights ? 1 : 0),
                                           section: SettingsSection.imageUpload.rawValue)
            // Remove rows in existing table
            settingsTableView?.deleteRows(at: [photoAtIndexPath, videoAtIndexPath], with: .automatic)

            // Refresh flag
            let indexPath = IndexPath(row: photoAtIndexPath.row - 1,
                                      section: SettingsSection.imageUpload.rawValue)
            settingsTableView?.reloadRows(at: [indexPath], with: .automatic)
        }
    }
}
