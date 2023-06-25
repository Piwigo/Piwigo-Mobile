//
//  SettingsViewController.swift
//  piwigo
//
//  Created by Spencer Baker on 1/20/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//
//  Converted to Swift 5 by Eddy Lelièvre-Berna on 12/04/2020.
//

import CoreData
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
    case privacy
    case appearance
    case cache
    case clear
    case about
    case count
}

enum ImageUploadSetting : Int {
    case author
    case prefix
}

let kHelpUsTitle: String = "Help Us!"
let kHelpUsTranslatePiwigo: String = "Piwigo is only partially translated in your language. Could you please help us complete the translation?"

@objc protocol ChangedSettingsDelegate: NSObjectProtocol {
    func didChangeDefaultAlbum()
    func didChangeRecentPeriod()
}

class SettingsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    weak var settingsDelegate: ChangedSettingsDelegate?

    @IBOutlet var settingsTableView: UITableView!

    private var tableViewBottomConstraint: NSLayoutConstraint?
    private var doneBarButton: UIBarButtonItem?
    private var helpBarButton: UIBarButtonItem?
    private var statistics = ""
    var thumbCacheSize = ""
    var photoCacheSize = ""
    var dataCacheSize = ""

    
    // MARK: - Core Data Objects
    var user: User!
    lazy var mainContext: NSManagedObjectContext = {
        guard let context: NSManagedObjectContext = user?.managedObjectContext else {
            fatalError("!!! Missing Managed Object Context !!!")
        }
        return context
    }()

    
    // MARK: - Core Data Providers
    lazy var albumProvider: AlbumProvider = {
        let provider : AlbumProvider = AlbumProvider.shared
        return provider
    }()


    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // Get Server Infos if possible
        if user.hasAdminRights {
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
        if #available(iOS 15.0, *) {
            helpBarButton = UIBarButtonItem(image: UIImage(systemName: "questionmark.circle"),
                                            style: .plain, target: self, action: #selector(displayHelp))
        } else {
            helpBarButton = UIBarButtonItem(image: UIImage(named: "help"), landscapeImagePhone: UIImage(named: "helpCompact"), style: .plain, target: self, action: #selector(displayHelp))
        }
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

        // Calculate cache sizes in the background
        DispatchQueue.global(qos: .userInitiated).async {
            guard let server = self.user.server else {
                fatalError("••> User not provided!")
            }
            var sizes = self.getThumbnailSizes()
            self.thumbCacheSize = server.getCacheSize(forImageSizes: sizes)
            sizes = self.getPhotoSizes()
            self.photoCacheSize = server.getCacheSize(forImageSizes: sizes)
            self.dataCacheSize = server.getCoreDataStoreSize()
            
            // Update cells if needed
            DispatchQueue.main.async {
                self.updateDataCacheCell()
                self.updateThumbCacheCell()
                self.updatePhotoCacheCell()
            }
        }
    }

    @objc func applyColorPalette() {
        // Background color of the view
        view.backgroundColor = .piwigoColorBackground()

        // Navigation bar appearance
        let navigationBar = navigationController?.navigationBar
        navigationController?.view.backgroundColor = UIColor.piwigoColorBackground()
        navigationBar?.barStyle = AppVars.shared.isDarkPaletteActive ? .black : .default
        navigationBar?.tintColor = UIColor.piwigoColorOrange()

        let attributes = [
            NSAttributedString.Key.foregroundColor: UIColor.piwigoColorWhiteCream(),
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17)
        ]
        navigationBar?.titleTextAttributes = attributes
        let attributesLarge = [
            NSAttributedString.Key.foregroundColor: UIColor.piwigoColorWhiteCream(),
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 28, weight: .black)
        ]
        navigationBar?.largeTitleTextAttributes = attributesLarge
        navigationBar?.prefersLargeTitles = true

        if #available(iOS 13.0, *) {
            let barAppearance = UINavigationBarAppearance()
            barAppearance.configureWithTransparentBackground()
            barAppearance.backgroundColor = UIColor.piwigoColorBackground().withAlphaComponent(0.9)
            barAppearance.titleTextAttributes = attributes
            barAppearance.largeTitleTextAttributes = attributesLarge
            navigationItem.standardAppearance = barAppearance
            navigationItem.compactAppearance = barAppearance // For iPhone small navigation bar in landscape.
            navigationItem.scrollEdgeAppearance = barAppearance
            navigationBar?.prefersLargeTitles = true
        }

        // Table view
        settingsTableView?.separatorColor = .piwigoColorSeparator()
        settingsTableView?.indicatorStyle = AppVars.shared.isDarkPaletteActive ? .white : .black
        settingsTableView?.reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Set navigation buttons
        navigationItem.setLeftBarButtonItems([doneBarButton].compactMap { $0 }, animated: true)
        navigationItem.setRightBarButtonItems([helpBarButton].compactMap { $0 }, animated: true)

        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: .pwgPaletteChanged, object: nil)

        // Register auto-upload option enabled/disabled
        NotificationCenter.default.addObserver(self, selector: #selector(updateAutoUpload),
                                               name: .pwgAutoUploadChanged, object: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Update title of current scene (iPad only)
        if #available(iOS 13.0, *) {
            view.window?.windowScene?.title = title
        }

        // Invite user to translate the app
        let langCode: String = NSLocale.current.languageCode ?? "en"
//            print("=> langCode: ", String(describing: langCode))
//            print(String(format: "=> now:%.0f > last:%.0f + %.0f", Date().timeIntervalSinceReferenceDate,         AppVars.shared.dateOfLastTranslationRequest, k2WeeksInDays))
        let now: Double = Date().timeIntervalSinceReferenceDate
        let dueDate: Double = AppVars.shared.dateOfLastTranslationRequest + AppVars.shared.pwgOneMonth
        if (now > dueDate) && (["ar","fa","pl","pt-BR","sk"].contains(langCode)) {
            // Store date of last translation request
            AppVars.shared.dateOfLastTranslationRequest = now

            // Request a translation
            let alert = UIAlertController(title: kHelpUsTitle, message: kHelpUsTranslatePiwigo, preferredStyle: .alert)

            let cancelAction = UIAlertAction(title: NSLocalizedString("alertNoButton", comment: "No"), style: .destructive, handler: { action in
                })

            let defaultAction = UIAlertAction(title: NSLocalizedString("alertYesButton", comment: "Yes"), style: .default, handler: { action in
                    if let url = URL(string: "https://crowdin.com/project/piwigo-mobile") {
                        UIApplication.shared.open(url)
                    }
                })

            alert.addAction(cancelAction)
            alert.addAction(defaultAction)
            alert.view.tintColor = .piwigoColorOrange()
            if #available(iOS 13.0, *) {
                alert.overrideUserInterfaceStyle = AppVars.shared.isDarkPaletteActive ? .dark : .light
            } else {
                // Fallback on earlier versions
            }
            present(alert, animated: true, completion: {
                // Bugfix: iOS9 - Tint not fully Applied without Reapplying
                alert.view.tintColor = .piwigoColorOrange()
            })
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
                self.preferredContentSize = CGSize(width: pwgPadSettingsWidth,
                                                   height: ceil(mainScreenBounds.height * 2 / 3))
            }

            // Reload table view
            self.settingsTableView?.reloadData()
        })
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Update upload counter in case user cleared the cache
        UploadManager.shared.updateNberOfUploadsToComplete()
    }

    deinit {
        // Unregister palette changes
        NotificationCenter.default.removeObserver(self, name: .pwgPaletteChanged, object: nil)
        
        // Unregister auto-upload option enabler
        NotificationCenter.default.removeObserver(self, name: .pwgAutoUploadChanged, object: nil)
    }


    // MARK: - Actions Methods
    @objc func quitSettings() {
        dismiss(animated: true)
    }
    
    @objc func displayHelp() {
        let helpSB = UIStoryboard(name: "HelpViewController", bundle: nil)
        let helpVC = helpSB.instantiateViewController(withIdentifier: "HelpViewController") as? HelpViewController
        if let helpVC = helpVC {
            // Update this list after deleting/creating Help##ViewControllers
            if #available(iOS 14, *) {
                helpVC.displayHelpPagesWithID = [8,1,5,6,2,4,7,3]
            } else if #available(iOS 13, *) {
                helpVC.displayHelpPagesWithID = [1,5,6,2,4,3]
            } else {
                helpVC.displayHelpPagesWithID = [1,5,6,4,1]
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
        if !hasUploadRights() { return }

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

    func loginLogout() {
        // Set date of use of server and user
        let now = Date()
        user?.lastUsed = now
        user?.server?.lastUsed = now
        if mainContext.hasChanges {
            try? mainContext.save()
        }
        
        // Guest user?
        if NetworkVars.username.isEmpty || NetworkVars.username.lowercased() == "guest" {
            ClearCache.closeSession { }
            return
        }
        
        // Ask user for confirmation
        let alert = UIAlertController(title: "", message: NSLocalizedString("logoutConfirmation_message", comment: "Are you sure you want to logout?"), preferredStyle: .actionSheet)

        let cancelAction = UIAlertAction(title: NSLocalizedString("alertCancelButton", comment: "Cancel"), style: .cancel, handler: { action in
        })

        let logoutAction = UIAlertAction(title: NSLocalizedString("logoutConfirmation_title", comment: "Logout"), style: .destructive, handler: { action in
            PwgSession.shared.sessionLogout {
                // Close session
                DispatchQueue.main.async {
                    ClearCache.closeSession { }
                }
            } failure: { error in
                // Failed! This may be due to the replacement of a self-signed certificate.
                // So we inform the user that there may be something wrong with the server,
                // or simply a connection drop.
                self.dismissPiwigoError(withTitle: NSLocalizedString("logoutFail_title", comment: "Logout Failed"),
                                        message: error.localizedDescription) {
                    ClearCache.closeSession { }
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
            alert.overrideUserInterfaceStyle = AppVars.shared.isDarkPaletteActive ? .dark : .light
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

    
    // MARK: - UITableView - Header
    private func getContentOfHeader(inSection section: Int) -> (String, String) {
        // Header strings
        var title = "", text = ""
        switch activeSection(section) {
        case .server:
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
        case .albums:
            title = NSLocalizedString("tabBar_albums", comment: "Albums")
        case .images:
            title = NSLocalizedString("settingsHeader_images", comment: "Images")
        case .imageUpload:
            title = NSLocalizedString("settingsHeader_upload", comment: "Default Upload Settings")
        case .appearance:
            title = NSLocalizedString("settingsHeader_appearance", comment: "Appearance")
        case .privacy:
            title = NSLocalizedString("settingsHeader_privacy", comment: "Privacy")
        case .cache:
            title = NSLocalizedString("settingsHeader_cache", comment: "Cache Settings")
        case .about:
            title = NSLocalizedString("settingsHeader_about", comment: "Information")
        case .logout, .clear:
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
            return TableViewUtilities.shared.heightOfHeader(withTitle: title, text: text,
                                                            width: tableView.frame.size.width)
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let (title, text) = getContentOfHeader(inSection: section)
        return TableViewUtilities.shared.viewOfHeader(withTitle: title, text: text)
    }

    
    // MARK: - UITableView - Sections
    func hasUploadRights() -> Bool {
        /// User can upload images/videos if he/she is logged in and has:
        /// — admin rights
        /// — normal rights with upload access to some categories with Community
        return user.hasAdminRights ||
            (user.role == .normal && NetworkVars.usesCommunityPluginV29)
    }
    
    private func activeSection(_ section: Int) -> SettingsSection {
        // User can upload images/videos if he/she is logged in and has:
        // — admin rights
        // — normal rights with upload access to some categories with Community
        var rawSection = section
        if !hasUploadRights(), rawSection > SettingsSection.images.rawValue {
            rawSection += 1
        }
        guard let activeSection = SettingsSection(rawValue: rawSection) else {
            fatalError("Unknown Section index!")
        }
        return activeSection
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return SettingsSection.count.rawValue - (hasUploadRights() ? 0 : 1)
    }

    // MARK: - UITableView - Rows
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var nberOfRows = 0
        switch activeSection(section) {
        case .server:
            nberOfRows = 2
        case .logout:
            nberOfRows = 1
        case .albums:
            nberOfRows = 4
        case .images:
            nberOfRows = 6
        case .imageUpload:
            nberOfRows = 7 + (user.hasAdminRights ? 1 : 0)
            nberOfRows += (UploadVars.resizeImageOnUpload ? 2 : 0)
            nberOfRows += (UploadVars.compressImageOnUpload ? 1 : 0)
            nberOfRows += (UploadVars.prefixFileNameBeforeUpload ? 1 : 0)
            nberOfRows += (NetworkVars.usesUploadAsync ? 1 : 0)
        case .privacy:
            nberOfRows = 2
        case .appearance:
            nberOfRows = 1
        case .cache:
            nberOfRows = 3
        case .clear:
            nberOfRows = 1
        case .about:
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
        var tableViewCell = UITableViewCell()
        switch activeSection(indexPath.section) {
        // MARK: Server
        case .server /* Piwigo Server */:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell else {
                print("Error: tableView.dequeueReusableCell does not return a LabelTableViewCell!")
                return LabelTableViewCell()
            }
            switch indexPath.row {
            case 0:
                // See https://iosref.com/res
                let title = NSLocalizedString("settings_server", comment: "Address")
                cell.configure(with: title, detail: NetworkVars.service)
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

        case .logout /* Login/Logout Button */:
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
        case .albums /* Albums */:
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
                // See https://iosref.com/res
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
                let albumImageSize = pwgImageSize(rawValue: AlbumVars.shared.defaultAlbumThumbnailSize) ?? .medium
                cell.configure(with: title, detail: albumImageSize.name)
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
                // See https://iosref.com/res
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
        case .images /* Images */:
            switch indexPath.row {
            case 0 /* Default Sort */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a LabelTableViewCell!")
                    return LabelTableViewCell()
                }
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
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a LabelTableViewCell!")
                    return LabelTableViewCell()
                }
                // See https://iosref.com/res
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
                let thumbnailSize = pwgImageSize(rawValue: AlbumVars.shared.defaultThumbnailSize) ?? .thumb
                cell.configure(with: title, detail: thumbnailSize.name)
                cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                cell.accessibilityIdentifier = "defaultImageThumbnailFile"
                tableViewCell = cell

            case 2 /* Number of thumbnails */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "SliderTableViewCell", for: indexPath) as? SliderTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a SliderTableViewCell!")
                    return SliderTableViewCell()
                }
                // Min/max number of thumbnails per row depends on selected file
                let thumbnailSize = pwgImageSize(rawValue: AlbumVars.shared.defaultThumbnailSize) ?? .thumb
                let defaultWidth = thumbnailSize.minPixels
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
                
            case 3 /* Display titles on thumbnails */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchTableViewCell", for: indexPath) as? SwitchTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a SwitchTableViewCell!")
                    return SwitchTableViewCell()
                }
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
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a LabelTableViewCell!")
                    return LabelTableViewCell()
                }
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
                
            case 5 /* Share Image Metadata Options */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a LabelTableViewCell!")
                    return LabelTableViewCell()
                }
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
        
        // MARK: Upload Settings
        case .imageUpload /* Default Upload Settings */:
            var row = indexPath.row
            row += (!user.hasAdminRights && (row > 0)) ? 1 : 0
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
                // See https://iosref.com/res
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
                cell.rightTextField.tag = ImageUploadSetting.author.rawValue
                cell.accessibilityIdentifier = "defaultAuthorName"
                tableViewCell = cell
                
            case 1 /* Privacy Level? */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a LabelTableViewCell!")
                    return LabelTableViewCell()
                }
                let defaultLevel = pwgPrivacy(rawValue: UploadVars.defaultPrivacyLevel)!.name
                // See https://iosref.com/res
                if view.bounds.size.width > 430 {
                    // i.e. larger than iPhone 14 Pro Max screen width
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
                // See https://iosref.com/res
                if view.bounds.size.width > 430 {
                    // i.e. larger than iPhone 14 Pro Max screen width
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
                // See https://iosref.com/res
                if view.bounds.size.width > 375 {
                    // i.e. larger than iPhone 14 Pro Max screen width
                    cell.configure(with: NSLocalizedString("settings_photoCompress>375px", comment: "Compress Photo Before Upload"))
                } else {
                    cell.configure(with: NSLocalizedString("settings_photoCompress", comment: "Compress Before Upload"))
                }
                cell.cellSwitch.setOn(UploadVars.compressImageOnUpload, animated: true)
                cell.cellSwitchBlock = { switchState in
                    // Number of rows will change accordingly
                    UploadVars.compressImageOnUpload = switchState
                    // Position of the row that should be added/removed
                    let rowAtIndexPath = IndexPath(row: 4 + (self.user.hasAdminRights ? 1 : 0)
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
                // See https://iosref.com/res
                if view.bounds.size.width > 430 {
                    // i.e. larger than iPhones 14 Pro Max screen width
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
                    let rowAtIndexPath = IndexPath(row: 5 + (self.user.hasAdminRights ? 1 : 0)
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
                // See https://iosref.com/res
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
                cell.rightTextField.tag = ImageUploadSetting.prefix.rawValue
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
                if view.bounds.size.width > 430 {
                    // i.e. larger than iPhone 14 Pro Max screen width
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
                // See https://iosref.com/res
                if view.bounds.size.width > 430 {
                    // i.e. larger than iPhone 14 Pro Max screen width
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
        
        // MARK: Privacy
        case .privacy   /* Privacy */:
            switch indexPath.row {
            case 0 /* App Lock */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a LabelTableViewCell!")
                    return LabelTableViewCell()
                }
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
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a LabelTableViewCell!")
                    return LabelTableViewCell()
                }
                let title = NSLocalizedString("settings_clearClipboard", comment: "Clear Clipboard")
                let detail = pwgClearClipboard(rawValue: AppVars.shared.clearClipboardDelay)?.delayUnit ?? ""
                cell.configure(with: title, detail: detail)
                cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                cell.accessibilityIdentifier = "clearClipboard"
                tableViewCell = cell

            default:
                break
            }

        // MARK: Appearance
        case .appearance /* Appearance */:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell else {
                print("Error: tableView.dequeueReusableCell does not return a LabelTableViewCell!")
                return LabelTableViewCell()
            }
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
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a LabelTableViewCell!")
                    return LabelTableViewCell()
                }
                let title = NSLocalizedString("settings_database", comment: "Data")
                cell.configure(with: title, detail: self.dataCacheSize)
                cell.accessoryType = UITableViewCell.AccessoryType.none
                cell.accessibilityIdentifier = "dataCache"
                tableViewCell = cell
                
            case 1 /* Album and Photo Thumbnails */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a LabelTableViewCell!")
                    return LabelTableViewCell()
                }
                let title = NSLocalizedString("settingsHeader_thumbnails", comment: "Thumbnails")
                cell.configure(with: title, detail: self.thumbCacheSize)
                cell.accessoryType = UITableViewCell.AccessoryType.none
                cell.accessibilityIdentifier = "thumbnailCache"
                tableViewCell = cell
                
            case 2 /* Photos and Videos */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a LabelTableViewCell!")
                    return LabelTableViewCell()
                }
                let title = NSLocalizedString("severalImages", comment: "Photos")
                cell.configure(with: title, detail: self.photoCacheSize)
                cell.accessoryType = UITableViewCell.AccessoryType.none
                cell.accessibilityIdentifier = "photoCache"
                tableViewCell = cell
                
            default:
                break
            }

        case .clear /* Clear Cache Button */:
            switch indexPath.row {
            case 0 /* Clear */:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "ButtonTableViewCell", for: indexPath) as? ButtonTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a ButtonTableViewCell!")
                    return ButtonTableViewCell()
                }
                cell.configure(with: NSLocalizedString("settings_cacheClear", comment: "Clear Cache"))
                cell.accessibilityIdentifier = "clearCache"
                tableViewCell = cell
                
            default:
                break
            }

        // MARK: Information
        case .about /* Information */:
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
        var result = true
        switch activeSection(indexPath.section) {
        // MARK: Server
        case .server /* Piwigo Server */:
            result = false
        case .logout /* Logout Button */:
            result = true
        
        // MARK: Albums
        case .albums /* Albums */:
            switch indexPath.row {
            case 0 /* Default album */, 1 /* Default Thumbnail File */:
                result = true
            default:
                result = false
            }

        // MARK: Images
        case .images /* Images */:
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
        case .imageUpload /* Default Upload Settings */:
            var row = indexPath.row
            row += (!user.hasAdminRights && (row > 0)) ? 1 : 0
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

        // MARK: Privacy
        case .privacy   /* Privacy */:
            result = true

        // MARK: Appearance
        case .appearance /* Appearance */:
            result = true

        // MARK: Cache Settings
        case .cache /* Cache Settings */:
            result = false
        case .clear /* Cache Settings */:
            result = true

        // MARK: Information
        case .about /* Information */:
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
    private func getContentOfFooter(inSection section: Int) -> String {
        var footer = ""
        switch activeSection(section) {
        case .logout:
            if UploadVars.serverFileTypes.isEmpty == false {
                footer = "\(NSLocalizedString("settingsFooter_formats", comment: "The server accepts the following file formats")): \(UploadVars.serverFileTypes.replacingOccurrences(of: ",", with: ", "))."
            }
        case .about:
            footer = statistics
        default:
            footer = ""
        }
        return footer
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        let text = getContentOfFooter(inSection: section)
        return TableViewUtilities.shared.heightOfFooter(withText: text,
                                                        width: tableView.frame.width)
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let text = getContentOfFooter(inSection: section)
        return TableViewUtilities.shared.viewOfFooter(withText: text, alignment: .center)
    }
    
    private func getInfos() {
        // Initialisation
        statistics = ""
        
        // Collect stats from server
        NetworkUtilities.checkSession(ofUser: user) {
            // Checking session ensures avalaible sizes are known
            let JSONsession = PwgSession.shared
            JSONsession.postRequest(withMethod: pwgGetInfos, paramDict: [:],
                                    jsonObjectClientExpectsToReceive: GetInfosJSON.self,
                                    countOfBytesClientExpectsToReceive: 1000) { jsonData in
                // Decode the JSON object and retrieve statistics.
                do {
                    // Decode the JSON into codable type GetInfosJSON.
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
                        guard let nber = info.value?.intValue else { continue }
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
        switch activeSection(indexPath.section) {
        // MARK: Server
        case .server /* Piwigo Server */:
            break

        // MARK: Logout
        case .logout /* Logout */:
            loginLogout()

        // MARK: Albums
        case .albums /* Albums */:
            switch indexPath.row {
            case 0 /* Default album */:
                let categorySB = UIStoryboard(name: "SelectCategoryViewController", bundle: nil)
                guard let categoryVC = categorySB.instantiateViewController(withIdentifier: "SelectCategoryViewController") as? SelectCategoryViewController else { return }
                categoryVC.user = user
                if categoryVC.setInput(parameter: AlbumVars.shared.defaultCategory,
                                       for: .setDefaultAlbum) {
                    categoryVC.delegate = self
                    navigationController?.pushViewController(categoryVC, animated: true)
                }
            case 1 /* Thumbnail file selection */:
                let defaultThumbnailSizeSB = UIStoryboard(name: "DefaultAlbumThumbnailSizeViewController", bundle: nil)
                guard let defaultThumbnailSizeVC = defaultThumbnailSizeSB.instantiateViewController(withIdentifier: "DefaultAlbumThumbnailSizeViewController") as? DefaultAlbumThumbnailSizeViewController else { return }
                defaultThumbnailSizeVC.delegate = self
                navigationController?.pushViewController(defaultThumbnailSizeVC, animated: true)
            default:
                break
            }

        // MARK: Images
        case .images /* Images */:
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
        case .imageUpload /* Default upload Settings */:
            var row = indexPath.row
            row += (!user.hasAdminRights && (row > 0)) ? 1 : 0
            row += (!UploadVars.resizeImageOnUpload && (row > 3)) ? 2 : 0
            row += (!UploadVars.compressImageOnUpload && (row > 6)) ? 1 : 0
            row += (!UploadVars.prefixFileNameBeforeUpload && (row > 8)) ? 1 : 0
            row += (!NetworkVars.usesUploadAsync && (row > 10)) ? 1 : 0
            switch row {
            case 1 /* Default privacy selection */:
                let privacySB = UIStoryboard(name: "SelectPrivacyViewController", bundle: nil)
                guard let privacyVC = privacySB.instantiateViewController(withIdentifier: "SelectPrivacyViewController") as? SelectPrivacyViewController else { return }
                privacyVC.delegate = self
                privacyVC.privacy = pwgPrivacy(rawValue: UploadVars.defaultPrivacyLevel) ?? .everybody
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
                autoUploadVC.user = user
                navigationController?.pushViewController(autoUploadVC, animated: true)
            default:
                break
            }

        // MARK: Privacy
        case .privacy   /* Privacy */:
            switch indexPath.row {
            case 0 /* Clear cache */:
                // Display numpad for setting up a passcode
                let appLockSB = UIStoryboard(name: "LockOptionsViewController", bundle: nil)
                guard let appLockVC = appLockSB.instantiateViewController(withIdentifier: "LockOptionsViewController") as? LockOptionsViewController else { return }
                appLockVC.delegate = self
                navigationController?.pushViewController(appLockVC, animated: true)
            case 1 /* Clear Clipboard */:
                // Display list of delays
                let delaySB = UIStoryboard(name: "ClearClipboardViewController", bundle: nil)
                guard let delayVC = delaySB.instantiateViewController(withIdentifier: "ClearClipboardViewController") as? ClearClipboardViewController else { return }
                delayVC.delegate = self
                navigationController?.pushViewController(delayVC, animated: true)

            default:
                break
            }

        // MARK: Appearance
        case .appearance /* Appearance */:
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
        case .clear /* Cache Clear */:
            switch indexPath.row {
            case 0 /* Clear cache */:
                // Determine position of cell in table view
                let rowAtIndexPath = IndexPath(row: 0, section: SettingsSection.clear.rawValue)
                let rectOfCellInTableView = settingsTableView?.rectForRow(at: rowAtIndexPath)

                // Present list of actions
                let alert = getClearCacheAlert()
                alert.view.tintColor = .piwigoColorOrange()
                if #available(iOS 13.0, *) {
                    alert.overrideUserInterfaceStyle = AppVars.shared.isDarkPaletteActive ? .dark : .light
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
        case .about /* About — Informations */:
            switch indexPath.row {
            case 0 /* Open @piwigo on Twitter */:
                if let url = URL(string: NSLocalizedString("settings_twitterURL", comment: "https://twitter.com/piwigo")) {
                    UIApplication.shared.open(url)
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
                    let deviceModel = UIDevice.current.modelName
                    let deviceOS = UIDevice.current.systemName
                    let deviceOSversion = UIDevice.current.systemVersion

                    // Set message body
                    composeVC.setMessageBody("\(NSLocalizedString("settings_appName", comment: "Piwigo Mobile")) \(appVersionString ?? "") (\(appBuildString ?? ""))\n\(deviceModel ) — \(deviceOS) \(deviceOSversion)\n==============>>\n\n", isHTML: false)

                    // Present the view controller modally.
                    present(composeVC, animated: true)
                }
            case 2 /* Open Piwigo support forum webpage with default browser */:
                if let url = URL(string: NSLocalizedString("settings_pwgForumURL", comment: "http://piwigo.org/forum")) {
                    UIApplication.shared.open(url)
                }
            case 3 /* Open Piwigo App Store page for rating */:
                // See https://itunes.apple.com/us/app/piwigo/id472225196?ls=1&mt=8
                if let url = URL(string: "itms-apps://itunes.apple.com/app/piwigo/id472225196?action=write-review") {
                    UIApplication.shared.open(url)
                }
            case 4 /* Open Piwigo Crowdin page for translating */:
                if let url = URL(string: "https://crowdin.com/project/piwigo-mobile") {
                    UIApplication.shared.open(url)
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
}


// MARK: - MFMailComposeViewControllerDelegate
extension SettingsViewController: MFMailComposeViewControllerDelegate {
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        // Check the result or perform other tasks.

        // Dismiss the mail compose view controller.
        dismiss(animated: true)
    }
}


// MARK: - UITextFieldDelegate Methods
extension SettingsViewController: UITextFieldDelegate {
    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        return true
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        settingsTableView?.endEditing(true)
        return true
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        switch ImageUploadSetting(rawValue: textField.tag) {
        case .author:
            UploadVars.defaultAuthor = textField.text ?? ""
        case .prefix:
            UploadVars.defaultPrefix = textField.text ?? ""
            if UploadVars.defaultPrefix.isEmpty {
                UploadVars.prefixFileNameBeforeUpload = false
                // Remove row in existing table
                let prefixIndexPath = IndexPath(row: 5 + (user.hasAdminRights ? 1 : 0)
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
    func didSelectCategory(withId categoryId: Int32) {
        // Do nothing if new default album is unknown or unchanged
        guard categoryId != Int32.min,
              categoryId != AlbumVars.shared.defaultCategory else {
            return
        }

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
        if let album = albumProvider.getAlbum(ofUser: user, withId: AlbumVars.shared.defaultCategory),
           album.name.isEmpty == false {
            return album.name
        } else {
            return NSLocalizedString("categorySelection_title", comment: "Album")
        }
    }
}


// MARK: - SelectedPrivacyDelegate Methods
extension SettingsViewController: SelectPrivacyDelegate {
    func didSelectPrivacyLevel(_ privacyLevel: pwgPrivacy) {
        // Do nothing if privacy level is unchanged
        if privacyLevel == pwgPrivacy(rawValue: UploadVars.defaultPrivacyLevel) { return }
        
        // Save new choice
        UploadVars.defaultPrivacyLevel = privacyLevel.rawValue

        // Refresh settings
        let indexPath = IndexPath(row: 1, section: SettingsSection.imageUpload.rawValue)
        if let indexPaths = settingsTableView.indexPathsForVisibleRows, indexPaths.contains(indexPath),
           let cell = settingsTableView.cellForRow(at: indexPath) as? LabelTableViewCell {
            cell.detailLabel.text = pwgPrivacy(rawValue: UploadVars.defaultPrivacyLevel)!.name
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
            let photoAtIndexPath = IndexPath(row: 3 + (user.hasAdminRights ? 1 : 0),
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
            let photoAtIndexPath = IndexPath(row: 3 + (user.hasAdminRights ? 1 : 0),
                                             section: SettingsSection.imageUpload.rawValue)
            let videoAtIndexPath = IndexPath(row: 4 + (user.hasAdminRights ? 1 : 0),
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
            let videoAtIndexPath = IndexPath(row: 4 + (user.hasAdminRights ? 1 : 0),
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
            let photoAtIndexPath = IndexPath(row: 3 + (user.hasAdminRights ? 1 : 0),
                                             section: SettingsSection.imageUpload.rawValue)
            let videoAtIndexPath = IndexPath(row: 4 + (user.hasAdminRights ? 1 : 0),
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

// MARK: - LockOptionsDelegate Methods
extension SettingsViewController: LockOptionsDelegate {
    func didSetAppLock(toState isLocked: Bool) {
        // Refresh corresponding row
        let appLockAtIndexPath = IndexPath(row: 0, section: SettingsSection.privacy.rawValue)
        if let indexPaths = settingsTableView.indexPathsForVisibleRows, indexPaths.contains(appLockAtIndexPath),
           let cell = settingsTableView.cellForRow(at: appLockAtIndexPath) as? LabelTableViewCell {
            if isLocked {
                cell.detailLabel.text = NSLocalizedString("settings_autoUploadEnabled", comment: "On")
            } else {
                cell.detailLabel.text = NSLocalizedString("settings_autoUploadDisabled", comment: "Off")
            }
        }
    }
}

// MARK: - ClearClipboardDelegate Methods
extension SettingsViewController: ClearClipboardDelegate {
    func didSelectClearClipboardDelay(_ delay: pwgClearClipboard) {
        // Refresh corresponding row
        let delayAtIndexPath = IndexPath(row: 1, section: SettingsSection.privacy.rawValue)
        if let indexPaths = settingsTableView.indexPathsForVisibleRows, indexPaths.contains(delayAtIndexPath),
           let cell = settingsTableView.cellForRow(at: delayAtIndexPath) as? LabelTableViewCell {
            cell.detailLabel.text = delay.delayUnit
        }
    }
}
