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

enum SettingsSection: Int {
    case server
    case logout
    case albums
    case images
    case videos
    case imageUpload
    case privacy
    case appearance
    case cache
    case clear
    case about
    case troubleshoot
    case count
}

let kHelpUsTitle: String = "Help Us!"
let kHelpUsTranslatePiwigo: String = "Piwigo is only partially translated in your language. Could you please help us complete or improve the translation?"

@objc protocol ChangedSettingsDelegate: NSObjectProtocol {
    func didChangeDefaultAlbum()
    func didChangeRecentPeriod()
}

class SettingsViewController: UIViewController {
    
    enum TextFieldTag : Int {
        case author
    }
    
    weak var settingsDelegate: (any ChangedSettingsDelegate)?
    
    @IBOutlet var settingsTableView: UITableView!
    
    private var tableViewBottomConstraint: NSLayoutConstraint?
    private var closeBarButton: UIBarButtonItem?
    private var helpBarButton: UIBarButtonItem?
    
    // Remember current user's recent period index
    private var oldRecentPeriodIndex = CacheVars.shared.recentPeriodIndex
    
    // Tell which cell triggered the keyboard appearance
    var editedRow: IndexPath?
    
    // The image sort type is returned with album data since Piwigo 14.0.
    lazy var defaultSortUnknown: Bool = NetworkVars.shared.pwgVersion
        .compare("14.0", options: .numeric) == .orderedAscending
    
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
    
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Launch operations in parallel in the background
        var operations = [BlockOperation]()
        operations.append(BlockOperation { [self] in
            // Calculate cache sizes
            guard let server = self.user.server,
                  server.isFault == false
            else {
                debugPrint("!!! User not provided !!!!")
                return
            }
            var sizes = self.getThumbnailSizes()
            self.thumbCacheSize = server.getCacheSize(forImageSizes: sizes)
            sizes = self.getPhotoSizes()
            self.photoCacheSize = server.getCacheSize(forImageSizes: sizes)
            self.videoCacheSize = server.getCacheSizeOfVideos()
            let bckgContext = DataController.shared.newTaskContext()
            self.dataCacheSize = server.getAlbumImageCount(inContext: bckgContext)
            if self.hasUploadRights() {
                let uploadsDirectory = DataDirectories.appUploadsDirectory
                let uploadsDirectorySize = ByteCountFormatter.string(fromByteCount: Int64(uploadsDirectory.folderSize), countStyle: .file)
                self.uploadCacheSize = server.getUploadCount(inContext: bckgContext) + " | " + uploadsDirectorySize
            }
        })
        
        // Retrieve data from server
        if user.hasAdminRights {
            operations.append(BlockOperation { [self] in
                // Check session before collecting server statistics
                PwgSession.checkSession(ofUser: self.user) {
                    // Collect stats from server and store them in cache
                    PwgSession.shared.getInfos()
                    // Collect recentPeriod chosen by user
                    PwgSession.getUsersInfo(forUserName: self.user.username) { usersData in
                        // Is the retrieved recent period different?
                        guard let nberOfDays = usersData.recentPeriod?.intValue,
                              let index = CacheVars.shared.recentPeriodList.firstIndex(of: nberOfDays),
                              index != self.oldRecentPeriodIndex
                        else { return }
                        
                        // Update current index and reload corresponding cell
                        DispatchQueue.main.async { [self] in
                            self.user.id = usersData.id ?? Int16.zero
                            self.user.managedObjectContext?.saveIfNeeded()
                            self.oldRecentPeriodIndex = index
                            CacheVars.shared.recentPeriodIndex = index
                            let indexPath = IndexPath(row: 3, section: SettingsSection.albums.rawValue)
                            if let cell = self.settingsTableView.cellForRow(at: indexPath) as? SliderTableViewCell {
                                cell.updateDisplayedValue(Float(index))
                            }
                        }
                    } failure: {
                        // No error report
                    }
                } failure: { _ in
                    /// - Network communication errors
                    /// - Returned JSON data is empty
                    /// - Cannot decode data returned by Piwigo server
                    /// -> no error report
                }
            })
        }
        let queue: OperationQueue = OperationQueue()
        queue.maxConcurrentOperationCount = .max
        queue.qualityOfService = .userInitiated
        queue.addOperations(operations, waitUntilFinished: false)
        
        // Title
        title = NSLocalizedString("tabBar_preferences", comment: "Settings")
        
        // Button for returning to albums/images
        closeBarButton = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(quitSettings))
        
        // Button for displaying help pages
        helpBarButton = UIBarButtonItem.helpButton(target: self, action: #selector(displayHelp))
        
        // Table view
        settingsTableView.accessibilityIdentifier = "org.piwigo.settings"
        settingsTableView.rowHeight = UITableView.automaticDimension
        settingsTableView.estimatedRowHeight = TableViewUtilities.rowHeight
        
        // Check whether we should display the max size options
        if UploadVars.shared.resizeImageOnUpload,
           UploadVars.shared.photoMaxSize == 0, UploadVars.shared.videoMaxSize == 0 {
            UploadVars.shared.resizeImageOnUpload = false
        }
    }
    
    @MainActor
    @objc func applyColorPalette() {
        // Background color of the view
        view.backgroundColor = PwgColor.background
        
        // Navigation bar appearance
        navigationController?.navigationBar.configAppearance(withLargeTitles: true)
        
        // Table view
        settingsTableView?.separatorColor = PwgColor.separator
        settingsTableView?.indicatorStyle = AppVars.shared.isDarkPaletteActive ? .white : .black
        settingsTableView?.reloadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Set colors, fonts, etc.
        applyColorPalette()
        
        // Set navigation buttons
        navigationItem.setLeftBarButtonItems([closeBarButton].compactMap { $0 }, animated: true)
        navigationItem.setRightBarButtonItems([helpBarButton].compactMap { $0 }, animated: true)
        
        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: Notification.Name.pwgPaletteChanged, object: nil)
        
        // Register font changes
        NotificationCenter.default.addObserver(self, selector: #selector(didChangeContentSizeCategory),
                                               name: UIContentSizeCategory.didChangeNotification, object: nil)
        
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
        view.window?.windowScene?.title = title
        
        // Invite user to translate the app
        let langCode: String = NSLocale.current.languageCode ?? "en"
        let now: Double = Date().timeIntervalSinceReferenceDate
        // Comment the below line and uncomment the next one for debugging
        let dueDate: Double = AppVars.shared.dateOfLastTranslationRequest + 3 * AppVars.shared.pwgOneMonth
        //        let dueDate: Double = AppVars.shared.dateOfLastTranslationRequest
        if now > dueDate, ["ar","da","hu","id","it","ja","nl","ru","sv"].contains(langCode) {
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
            alert.view.tintColor = PwgColor.tintColor
            alert.overrideUserInterfaceStyle = AppVars.shared.isDarkPaletteActive ? .dark : .light
            present(alert, animated: true, completion: {
                // Bugfix: iOS9 - Tint not fully Applied without Reapplying
                alert.view.tintColor = PwgColor.tintColor
            })
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Update upload counter in case user cleared the cache
        Task { @UploadManagement in
            UploadManager.shared.updateNberOfUploadsToComplete()
        }
        // Did the user change the recent period?
        let recentPeriodIndex = CacheVars.shared.recentPeriodIndex
        if hasUploadRights(), oldRecentPeriodIndex != recentPeriodIndex {
            // Update recent period on Piwigo server
            DispatchQueue.global(qos: .background).async { [self] in
                PwgSession.checkSession(ofUser: user) {
                    let periodInDays = CacheVars.shared.recentPeriodList[recentPeriodIndex]
                    PwgSession.setRecentPeriod(periodInDays, forUserWithID: self.user.id) { success in
                        // No reporting
                    } failure: { error in
                        // No reporting
                    }
                } failure: { error in
                    // No reporting
                }
            }
            // Reload root/default album
            self.settingsDelegate?.didChangeRecentPeriod()
        }
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
        let helpVC = HelpUtilities.getHelpViewController()
        if view.traitCollection.userInterfaceIdiom == .phone {
            helpVC.popoverPresentationController?.permittedArrowDirections = .up
            navigationController?.present(helpVC, animated:true)
        } else {
            helpVC.modalPresentationStyle = .currentContext
            helpVC.modalTransitionStyle = .flipHorizontal
            helpVC.popoverPresentationController?.sourceView = view
            navigationController?.present(helpVC, animated: true)
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
        
        // Inform user if Settings are presented
        if view.window != nil,
           let title = notification.userInfo?["title"] as? String, title.isEmpty == false,
           let message = notification.userInfo?["message"] as? String {
            dismissPiwigoError(withTitle: title, message: message) { }
        }
    }
    
    @MainActor
    func loginLogout() {
        // Set date of use of server and user
        let now = Date.timeIntervalSinceReferenceDate
        user?.lastUsed = now
        user?.server?.lastUsed = now
        mainContext.saveIfNeeded()
        
        // Guest user?
        if NetworkVars.shared.user.isEmpty || NetworkVars.shared.user.lowercased() == "guest" {
            ClearCache.closeSession()
            return
        }
        
        // Ask user for confirmation
        let alert = UIAlertController(title: "", message: NSLocalizedString("logoutConfirmation_message", comment: "Are you sure you want to logout?"), preferredStyle: .actionSheet)
        
        let cancelAction = UIAlertAction(title: NSLocalizedString("alertCancelButton", comment: "Cancel"), style: .cancel, handler: { action in
        })
        
        let logoutAction = UIAlertAction(title: NSLocalizedString("logoutConfirmation_title", comment: "Logout"), style: .destructive, handler: { action in
            // Show HUD
            let title = NSLocalizedString("login_closeSession", comment: "Closing Session...")
            self.navigationController?.showHUD(withTitle: title)
            
            // Perform Logout
            PwgSession.shared.sessionLogout {
                // Close session
                DispatchQueue.main.async { [self] in
                    self.navigationController?.hideHUD(afterDelay: pwgDelayHUD) {
                        ClearCache.closeSession()
                    }
                }
            } failure: { error in
                // Failed! This may be due to the replacement of a self-signed certificate.
                // So we inform the user that there may be something wrong with the server,
                // or simply a connection drop.
                DispatchQueue.main.async { [self] in
                    self.navigationController?.hideHUD {
                        self.navigationController?.dismissPiwigoError(withTitle: NSLocalizedString("logoutFail_title", comment: "Logout Failed"),
                                                                      message: error.localizedDescription) {
                            ClearCache.closeSession()
                        }
                    }
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
        alert.view.tintColor = PwgColor.tintColor
        alert.overrideUserInterfaceStyle = AppVars.shared.isDarkPaletteActive ? .dark : .light
        alert.popoverPresentationController?.sourceView = settingsTableView
        alert.popoverPresentationController?.permittedArrowDirections = [.up, .down]
        alert.popoverPresentationController?.sourceRect = rectOfCellInTableView ?? CGRect.zero
        present(alert, animated: true, completion: {
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            alert.view.tintColor = PwgColor.tintColor
        })
    }
    
    
    // MARK: - Content Sizes
    @objc func didChangeContentSizeCategory(_ notification: NSNotification) {
        // Update content sizes
//        guard let info = notification.userInfo,
//              let contentSizeCategory = info[UIContentSizeCategory.newValueUserInfoKey] as? UIContentSizeCategory
//        else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // Animated update for smoother experience
            self.settingsTableView?.beginUpdates()
            self.settingsTableView?.endUpdates()

            // Update navigation bar
            self.navigationController?.navigationBar.configAppearance(withLargeTitles: true)
        }
    }
}


// MARK: - MFMailComposeViewControllerDelegate
extension SettingsViewController: MFMailComposeViewControllerDelegate {
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: (any Error)?) {
        // Check the result or perform other tasks.

        // Dismiss the mail compose view controller.
        dismiss(animated: true)
    }
}
