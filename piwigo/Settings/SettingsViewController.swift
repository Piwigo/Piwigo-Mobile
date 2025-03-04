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
import uploadKit

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
    case troubleshoot
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

class SettingsViewController: UIViewController {
    
    weak var settingsDelegate: ChangedSettingsDelegate?
    
    @IBOutlet var settingsTableView: UITableView!
    
    private var tableViewBottomConstraint: NSLayoutConstraint?
    private var doneBarButton: UIBarButtonItem?
    private var helpBarButton: UIBarButtonItem?
    
    // Tell which cell triggered the keyboard appearance
    var editedRow: IndexPath?
    
    // The image sort type is returned with album data since Piwigo 14.0.
    lazy var defaultSortUnknown: Bool = NetworkVars.shared.pwgVersion
        .compare("14.0", options: .numeric) == .orderedAscending
    
    // Present image title and album description options on iOS 12.0 - 13.x
    lazy var showOptions: Bool = {
        if #available(iOS 14, *) {
            return false
        } else {
            return true
        }
    }()
    
    // For displaying cache sizes
    var dataCacheSize: String = NSLocalizedString("loadingHUD_label", comment: "Loading…") {
        didSet {
            DispatchQueue.main.async {
                self.updateDataCacheCell()
            }
        }
    }
    var thumbCacheSize: String = NSLocalizedString("loadingHUD_label", comment: "Loading…") {
        didSet {
            DispatchQueue.main.async {
                self.updateThumbCacheCell()
            }
        }
    }
    var photoCacheSize: String = NSLocalizedString("loadingHUD_label", comment: "Loading…") {
        didSet {
            DispatchQueue.main.async {
                self.updatePhotoCacheCell()
            }
        }
    }
    var videoCacheSize: String = NSLocalizedString("loadingHUD_label", comment: "Loading…") {
        didSet {
            DispatchQueue.main.async {
                self.updateVideoCacheCell()
            }
        }
    }
    var uploadCacheSize: String = NSLocalizedString("loadingHUD_label", comment: "Loading…") {
        didSet {
            DispatchQueue.main.async {
                self.updateUploadCacheCell()
            }
        }
    }
    
    
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
        
        // Launch tasks in the background
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            // Calculate cache sizes in the background
            guard let server = self.user.server else {
                assert(self.user.server != nil, "••> User not provided!")
                return
            }
            var sizes = self.getThumbnailSizes()
            self.thumbCacheSize = server.getCacheSize(forImageSizes: sizes)
            sizes = self.getPhotoSizes()
            self.photoCacheSize = server.getCacheSize(forImageSizes: sizes)
            self.videoCacheSize = server.getCacheSizeOfVideos()
            self.dataCacheSize = server.getAlbumImageCount()
            if self.hasUploadRights() {
                self.uploadCacheSize = server.getUploadCount()
                + " | " + UploadManager.shared.getUploadsDirectorySize()
            }
            
            // Update server statistics if possible
            if user.hasAdminRights {
                // Check session before collecting server statistics
                PwgSession.checkSession(ofUser: self.user) {
                    // Collect stats from server and store them in cache
                    PwgSession.shared.getInfos()
                } failure: { _ in
                    /// - Network communication errors
                    /// - Returned JSON data is empty
                    /// - Cannot decode data returned by Piwigo server
                    /// -> nothing presented in the footer
                }
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
        if UploadVars.shared.resizeImageOnUpload,
           UploadVars.shared.photoMaxSize == 0, UploadVars.shared.videoMaxSize == 0 {
            UploadVars.shared.resizeImageOnUpload = false
        }
        
        // Check whether we should show the prefix option
        if UploadVars.shared.prefixFileNameBeforeUpload,
           UploadVars.shared.defaultPrefix.isEmpty {
            UploadVars.shared.prefixFileNameBeforeUpload = false
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
                                               name: Notification.Name.pwgPaletteChanged, object: nil)
        
        // Register auto-upload option enabled/disabled
        NotificationCenter.default.addObserver(self, selector: #selector(updateAutoUpload),
                                               name: Notification.Name.pwgAutoUploadChanged, object: nil)
        
        // Register keyboard appearance/disappearance
        NotificationCenter.default.addObserver(self, selector: #selector(onKeyboardWillShow(_:)),
                                               name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onKeyboardDidShow(_:)),
                                               name: UIResponder.keyboardDidShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onKeyboardWillHide(_:)),
                                               name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Update title of current scene (iPad only)
        if #available(iOS 13.0, *) {
            view.window?.windowScene?.title = title
        }
        
        // Invite user to translate the app
        let langCode: String = NSLocale.current.languageCode ?? "en"
//        debugPrint("=> langCode: ", String(describing: langCode))
//        debugPrint(String(format: "=> now:%.0f > last:%.0f + %.0f", Date().timeIntervalSinceReferenceDate,         AppVars.shared.dateOfLastTranslationRequest, AppVars.shared.pwgOneMonth))
        let now: Double = Date().timeIntervalSinceReferenceDate
        let dueDate: Double = AppVars.shared.dateOfLastTranslationRequest + AppVars.shared.pwgOneMonth
        if (now > dueDate) && (["ar","id","ko","pt-BR","sv","uk"].contains(langCode)) {
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
        coordinator.animate(alongsideTransition: { [self] _ in
            
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
        // Unregister all observers
        NotificationCenter.default.removeObserver(self)
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
        let now = Date.timeIntervalSinceReferenceDate
        user?.lastUsed = now
        user?.server?.lastUsed = now
        if mainContext.hasChanges {
            try? mainContext.save()
        }
        
        // Guest user?
        if NetworkVars.shared.username.isEmpty || NetworkVars.shared.username.lowercased() == "guest" {
            ClearCache.closeSession()
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
                    ClearCache.closeSession()
                }
            } failure: { error in
                // Failed! This may be due to the replacement of a self-signed certificate.
                // So we inform the user that there may be something wrong with the server,
                // or simply a connection drop.
                self.dismissPiwigoError(withTitle: NSLocalizedString("logoutFail_title", comment: "Logout Failed"),
                                        message: error.localizedDescription) {
                    ClearCache.closeSession()
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
}

// MARK: - MFMailComposeViewControllerDelegate
extension SettingsViewController: MFMailComposeViewControllerDelegate {
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        // Check the result or perform other tasks.

        // Dismiss the mail compose view controller.
        dismiss(animated: true)
    }
}
