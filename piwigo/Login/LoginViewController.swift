//
//  LoginViewController.swift
//  piwigo
//
//  Created by Spencer Baker on 1/17/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//
//  Converted to Swift 5.4 by Eddy Lelièvre-Berna on 26/02/2022.
//

import CoreData
import MessageUI
import UIKit
import piwigoKit
import uploadKit

class LoginViewController: UIViewController {

    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var piwigoLogo: UIButton!
    @IBOutlet weak var serverTextField: UITextField!
    @IBOutlet weak var userTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var loginButton: UIButton!
    @IBOutlet weak var websiteNotSecure: UILabel!
    @IBOutlet weak var versionLabel: UILabel!
    
    private var isAlreadyTryingToLogin = false
    var httpAlertController: UIAlertController?
    var httpLoginAction: UIAlertAction?

    override var preferredStatusBarStyle: UIStatusBarStyle {
        if #available(iOS 13.0, *) {
            return AppVars.shared.isDarkPaletteActive ? .lightContent : .darkContent
        } else {
            // Fallback on earlier versions
            return .lightContent
        }
    }

    
    // MARK: - Core Data Object Contexts
    lazy var mainContext: NSManagedObjectContext = {
        let context:NSManagedObjectContext = DataController.shared.mainContext
        return context
    }()


    // MARK: - Core Data Providers
    private lazy var userProvider: UserProvider = {
        let provider : UserProvider = UserProvider.shared
        return provider
    }()


    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        scrollView.contentSize = contentView.bounds.size

        // Server URL text field
        serverTextField.placeholder = NSLocalizedString("login_serverPlaceholder", comment: "example.com")
        serverTextField.text = NetworkVars.service

        // Username text field
        userTextField.placeholder = NSLocalizedString("login_userPlaceholder", comment: "Username (optional)")
        userTextField.text = NetworkVars.username
        userTextField.textContentType = .username
        
        // Password text field
        passwordTextField.placeholder = NSLocalizedString("login_passwordPlaceholder", comment: "Password (optional)")
        passwordTextField.text = KeychainUtilities.password(forService: NetworkVars.serverPath,
                                                            account: NetworkVars.username)
        passwordTextField.textContentType = .password
        
        // Login button
        loginButton.setTitle(NSLocalizedString("login", comment: "Login"), for: .normal)
        loginButton.addTarget(self, action: #selector(launchLogin), for: .touchUpInside)

        // Website not secure info
        websiteNotSecure.text = NSLocalizedString("settingsHeader_notSecure", comment: "Website Not Secure!")
        
        // App version
        let appVersionString = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let appBuildString = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        versionLabel.text = "— \(NSLocalizedString("version", tableName: "About", bundle: Bundle.main, value: "", comment: "Version:")) \(appVersionString ?? "") (\(appBuildString ?? "")) —"

        // Keyboard
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(UIInputViewController.dismissKeyboard)))

        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: Notification.Name.pwgPaletteChanged, object: nil)
        
        // Register keyboard appearance/disappearance
        NotificationCenter.default.addObserver(self, selector: #selector(onKeyboardWillShow(_:)),
                                               name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onKeyboardWillHide(_:)), 
                                               name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc func applyColorPalette() {
        // Background color of the view
        view.backgroundColor = .piwigoColorBackground()
        contentView.backgroundColor = .piwigoColorBackground()

        // Change text colour according to palette colour
        if #available(iOS 13.0, *) {
            piwigoLogo.imageView?.overrideUserInterfaceStyle = AppVars.shared.isDarkPaletteActive ? .dark : .light
        }

        // Navigation bar
        let attributes = [
            NSAttributedString.Key.foregroundColor: UIColor.piwigoColorWhiteCream(),
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17)
        ]
        navigationController?.navigationBar.titleTextAttributes = attributes as [NSAttributedString.Key : Any]
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationController?.navigationBar.barStyle = AppVars.shared.isDarkPaletteActive ? .black : .default
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

        // Text color depdending on background color
        serverTextField.textColor = .piwigoColorText()
        serverTextField.backgroundColor = .piwigoColorCellBackground()
        userTextField.textColor = .piwigoColorText()
        userTextField.backgroundColor = .piwigoColorCellBackground()
        passwordTextField.textColor = .piwigoColorText()
        passwordTextField.backgroundColor = .piwigoColorCellBackground()
        versionLabel.textColor = .piwigoColorText()
        websiteNotSecure.textColor = .piwigoColorText()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Set colors, fonts, etc.
        applyColorPalette()

        // Not yet trying to login
        isAlreadyTryingToLogin = false

        // Inform user if the connection is not secure
        websiteNotSecure.isHidden = NetworkVars.serverProtocol == "https://"
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Update title of current scene (iPad only)
        if #available(iOS 13.0, *) {
            view.window?.windowScene?.title = NSLocalizedString("login", comment: "Login")
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        // Should we update user interface based on the appearance?
        if #available(iOS 13.0, *) {
            let isSystemDarkModeActive = UIScreen.main.traitCollection.userInterfaceStyle == .dark
            if AppVars.shared.isSystemDarkModeActive != isSystemDarkModeActive {
                AppVars.shared.isSystemDarkModeActive = isSystemDarkModeActive
                let appDelegate = UIApplication.shared.delegate as? AppDelegate
                appDelegate?.screenBrightnessChanged()
            }
        }
    }

    deinit {
        // Release memory
        
        // Unregister all observers
        NotificationCenter.default.removeObserver(self)
    }

    
    
    // MARK: - Login business
    @objc func launchLogin() {
        // User pressed "Login"
        view.endEditing(true)

        // Default settings
        isAlreadyTryingToLogin = true
        NetworkVars.userStatus = pwgUserStatus.guest
        NetworkVars.usesCommunityPluginV29 = false
        print(
            "   usesCommunityPluginV29=\(NetworkVars.usesCommunityPluginV29 ? "YES" : "NO"), hasUserRights=\(NetworkVars.userStatus.rawValue)")

        // Check server address and cancel login if address not provided
        if let serverURL = serverTextField.text, serverURL.isEmpty {
            let title = NSLocalizedString("loginEmptyServer_title", comment: "Enter a Web Address")
            let message = NSLocalizedString("loginEmptyServer_message", comment: "Please select a protocol and enter a Piwigo web address in order to proceed.")
            dismissPiwigoError(withTitle: title, message: message) { }
            return
        }

        // Display HUD during login
        showHUD(withTitle: NSLocalizedString("login_loggingIn", comment: "Logging In..."),
                detail: NSLocalizedString("login_connecting", comment: "Connecting"),
                buttonTitle: NSLocalizedString("internetCancelledConnection_button", comment: "Cancel Connection"),
                buttonTarget: self, buttonSelector: #selector(cancelLoggingIn), inMode: .indeterminate)

        // Save credentials in Keychain (needed before login when using HTTP Authentication)
        if let username = userTextField.text, username.isEmpty == false {
            // Store credentials in Keychain
            KeychainUtilities.setPassword(passwordTextField.text ?? "",
                                          forService: NetworkVars.serverPath,
                                          account: username)
        }

        // Collect list of methods supplied by Piwigo server
        requestServerMethods()
    }
    
    func requestServerMethods() {
        // Collect list of methods supplied by Piwigo server
        NetworkUtilities.requestServerMethods { [self] in
            // Pursue logging in…
            DispatchQueue.main.async {
                self.performLogin()
            }
        } didRejectCertificate: { [self] error in
            // The SSL certificate is not trusted
            DispatchQueue.main.async {
                self.requestCertificateApproval(afterError: error)
            }
        } didFailHTTPauthentication: { [self] error in
            // Without prior knowledge, the app already tried Piwigo credentials
            // but unsuccessfully, so we request HTTP credentials
            DispatchQueue.main.async {
                self.requestHttpCredentials(afterError: error)
            }
        } didFailSecureConnection: { [self] error in
            // Suggest HTTP connection if HTTPS attempt failed
            DispatchQueue.main.async {
                self.requestNonSecuredAccess(afterError: error)
            }
        } failure: { [self] error in
            DispatchQueue.main.async {
                self.logging(inConnectionError: error)
            }
        }
    }

    func requestCertificateApproval(afterError error: Error?) {
        let title = NSLocalizedString("loginCertFailed_title", comment: "Connection Not Private")
        let message = "\(NSLocalizedString("loginCertFailed_message", comment: "Piwigo warns you when a website has a certificate that is not valid. Do you still want to accept this certificate?"))\r\r\(NetworkVars.certificateInformation)"
        let cancelAction = UIAlertAction(
            title: NSLocalizedString("alertCancelButton", comment: "Cancel"),
            style: .cancel, handler: { [self] action in
                // Should forget certificate
                NetworkVars.didApproveCertificate = false
                // Report error
                logging(inConnectionError: error)
            })
        let acceptAction = UIAlertAction(
            title: NSLocalizedString("alertOkButton", comment: "OK"),
            style: .default, handler: { [self] action in
                // Cancel task and relaunch login
                PwgSession.shared.dataSession.getAllTasks { tasks in
                    // Cancel task
                    tasks.forEach({ $0.cancel() })
                    // Will accept certificate
                    NetworkVars.didApproveCertificate = true
                    // Try logging in with approved certificate
                    DispatchQueue.main.async {
                        self.launchLogin()
                    }
                }
            })
        presentPiwigoAlert(withTitle: title, message: message, actions: [cancelAction, acceptAction])
    }

    func requestHttpCredentials(afterError error: Error?) {
        let username = NetworkVars.httpUsername
        let password = KeychainUtilities.password(forService: NetworkVars.service, account: username)
        httpAlertController = LoginUtilities.getHttpCredentialsAlert(textFieldDelegate: self,
                                                                     username: username, password: password,
                                                                     cancelAction: { [self] action in
            // Stop logging in action, display error message
            logging(inConnectionError: error)
        }, loginAction: { [self] action in
            // Store credentials
            if let httpUsername = httpAlertController?.textFields?[0].text,
               httpUsername.isEmpty == false {
                NetworkVars.httpUsername = httpUsername
                KeychainUtilities.setPassword(httpAlertController?.textFields?[1].text ?? "",
                    forService: NetworkVars.service, account: httpUsername)
                // Try logging in with new HTTP credentials
                launchLogin()
            }
        })
        if let httpAlertController = httpAlertController {
            present(httpAlertController, animated: true) {
                // Bugfix: iOS9 - Tint not fully Applied without Reapplying
                httpAlertController.view.tintColor = UIColor.piwigoColorOrange()
            }
        }
    }

    func requestNonSecuredAccess(afterError error: Error?) {
        let title = NSLocalizedString("loginHTTPSfailed_title", comment: "Secure Connection Failed")
        let message = NSLocalizedString("loginHTTPSfailed_message", comment: "Piwigo cannot establish a secure connection. Do you want to try to establish an insecure connection?")
        let cancelAction = UIAlertAction(
            title: NSLocalizedString("alertCancelButton", comment: "Cancel"),
            style: .cancel, handler: { [self] action in
                // Stop logging in action, display error message
                logging(inConnectionError: error)
            })
        let loginAction = UIAlertAction(
            title: NSLocalizedString("alertOkButton", comment: "OK"),
            style: .default, handler: { [self] action in
                // Try logging in with HTTP scheme
                tryNonSecuredAccess(afterError: error)
            })
        presentPiwigoAlert(withTitle: title, message: message, actions: [cancelAction, loginAction])
    }

    func tryNonSecuredAccess(afterError error: Error?) {
        // Proceed at their own risk
        NetworkVars.serverProtocol = "http://"

        // Update URL on UI
        serverTextField.text = NetworkVars.service

        // Display security message below credentials
        websiteNotSecure.isHidden = false

        // Collect list of methods supplied by Piwigo server
        requestServerMethods()
    }

    func performLogin() {
        print(
            "   usesCommunityPluginV29=\(NetworkVars.usesCommunityPluginV29 ? "YES" : "NO"), hasUserRights=\(NetworkVars.userStatus.rawValue)")

        // Perform login if username exists
        let username = userTextField.text ?? ""
        let password = passwordTextField.text ?? ""
        if username.isEmpty == false {
            // Update HUD during login
            updateHUD(detail: NSLocalizedString("login_newSession", comment: "Opening Session"))

            // Perform login
            PwgSession.shared.sessionLogin(withUsername: username, password: password) { [self] in
                // Session now opened
                NetworkVars.username = username

                // Create/update User account in persistent cache, create Server if necessary.
                // Performed in main thread so to avoid concurrency issue with AlbumViewController initialisation
                DispatchQueue.main.async { [self] in
                    let _ = self.userProvider.getUserAccount(inContext: mainContext,
                                                             withUsername: username, afterUpdate: true)
                }

                // First determine user rights if Community extension installed
                getCommunityStatus()
            } failure: { [self] error in
                // Don't keep unaccepted credentials
                KeychainUtilities.deletePassword(forService: NetworkVars.serverPath,
                                                 account: username)
                // Login request failed
                logging(inConnectionError: error)
            }
        } else {
            // Reset keychain and credentials
            KeychainUtilities.deletePassword(forService: NetworkVars.serverPath,
                                             account: username)
            NetworkVars.username = ""

            // Create/update guest account in persistent cache, create Server if necessary.
            // Performed in main thread so to avoid concurrency issue with AlbumViewController initialisation
            DispatchQueue.main.async { [self] in
                let _ = self.userProvider.getUserAccount(inContext: mainContext,
                                                         withUsername: username, afterUpdate: true)
            }

            // Check Piwigo version, get token, available sizes, etc.
            getCommunityStatus()
        }
    }

    // Determine true user rights when Community extension installed
    func getCommunityStatus() {
        print(
            "   usesCommunityPluginV29=\(NetworkVars.usesCommunityPluginV29 ? "YES" : "NO"), hasUserRights=\(NetworkVars.userStatus.rawValue)")
        // Community plugin installed?
        if NetworkVars.usesCommunityPluginV29 {
            // Update HUD during login
            updateHUD(detail: NSLocalizedString("login_communityParameters", comment: "Community Parameters"))

            // Community extension installed
            PwgSession.shared.communityGetStatus { [self] in
                // Update user account in persistent cache
                // Performed in main thread so to avoid concurrency issue with AlbumViewController initialisation
                DispatchQueue.main.async { [self] in
                    let _ = self.userProvider.getUserAccount(inContext: mainContext, afterUpdate: true)
                }

                // Check Piwigo version, get token, available sizes, etc.
                getSessionStatus()
            } failure: { [self] error in
                // Inform user that server failed to retrieve Community parameters
                isAlreadyTryingToLogin = false
                logging(inConnectionError: error)
            }
        } else {
            // Community extension not installed
            // Check Piwigo version, get token, available sizes, etc.
            getSessionStatus()
        }
    }

    // Check Piwigo version, get token, available sizes, etc.
    func getSessionStatus() {
        print(
            "   hasCommunityPlugin=\(NetworkVars.usesCommunityPluginV29 ? "YES" : "NO"), hasUserRights=\(NetworkVars.userStatus.rawValue)")
        // Update HUD during login
        updateHUD(detail: NSLocalizedString("login_serverParameters", comment: "Piwigo Parameters"))

        PwgSession.shared.sessionGetStatus() { [self] _ in
            // Is the Piwigo server incompatible?
            if NetworkVars.pwgVersion.compare(NetworkVars.pwgMinVersion, options: .numeric) == .orderedAscending {
                // Piwigo update required ► Close login or re-login view and inform user
                isAlreadyTryingToLogin = false
                // Display error message
                logging(inConnectionError: PwgSessionError.incompatiblePwgVersion)
                return
            }
            
            // Should this server be updated?
            let now: Double = Date().timeIntervalSinceReferenceDate
            if now > NetworkVars.dateOfLastUpdateRequest + AppVars.shared.pwgOneMonth,
               NetworkVars.pwgVersion.compare(NetworkVars.pwgRecentVersion, options: .numeric) == .orderedAscending {
                // Store date of last upgrade request
                NetworkVars.dateOfLastUpdateRequest = now

                // Piwigo server update recommanded ► Inform user
                DispatchQueue.main.async { [self] in
                    hideHUD() {
                        self.dismissPiwigoError(withTitle: NSLocalizedString("serverVersionOld_title", comment: "Server Update Available"), message: String.localizedStringWithFormat(NSLocalizedString("serverVersionOld_message", comment: "Your Piwigo server version is %@. Please ask the administrator to update it."), NetworkVars.pwgVersion), completion: {
                                // Piwigo server version is still appropriate.
                                self.launchApp()
                        })
                    }
                }
            }
            else {
                // Piwigo server version is appropriate.
                launchApp()
            }
        } failure: { [self] error in
            isAlreadyTryingToLogin = false
            // Display error message
            logging(inConnectionError: error)
        }
    }

    func launchApp() {
        isAlreadyTryingToLogin = false
        // Hide HUD and present root album
        DispatchQueue.main.async { [unowned self] in
            // Update user account in persistent cache
            // Performed in main thread to avoid concurrency issue with AlbumViewController initialisation
            let _ = self.userProvider.getUserAccount(inContext: mainContext, afterUpdate: true)

            // Check image size availabilities
            LoginUtilities.checkAvailableSizes()

            // Present Album/Images view and resume uploads
            let appDelegate = UIApplication.shared.delegate as? AppDelegate
            hideHUD() {
                // Present Album/Images view and resume uploads
                appDelegate?.loadNavigation(in: self.view.window)
            }
        }
    }
    
    
    // MARK: - HUD methods
    @objc func cancelLoggingIn() {
        // Update login HUD
        updateHUD(detail: NSLocalizedString("internetCancellingConnection_button", comment: "Cancelling Connection…"))

        // Propagate user's request
        PwgSession.shared.dataSession.getAllTasks() { tasks in
            tasks.forEach { $0.cancel() }
        }
    }

    func logging(inConnectionError error: Error?) {
        // Do not present error message when executing background task
        if UploadManager.shared.isExecutingBackgroundUploadTask {
            hideLoading()
            return
        }

        // Unknown error?
        guard let error = error else {
            updateHUD(title: NSLocalizedString("internetCancelledConnection_title", comment: "Connection Cancelled"), 
                      detail: "",
                      buttonTitle: NSLocalizedString("alertDismissButton", comment: "Dismiss"),
                      buttonTarget: self, buttonSelector: #selector(hideLoading),
                      inMode: .text)
            return
        }
        
        // Error returned
        var title = NSLocalizedString("internetErrorGeneral_title", comment: "Connection Error")
        var detail = error.localizedDescription
        if let pwgError = error as? PwgSessionError,
           pwgError == PwgSessionError.incompatiblePwgVersion {
            title = NSLocalizedString("serverVersionNotCompatible_title", comment: "Server Incompatible")
            detail = String.localizedStringWithFormat(NSLocalizedString("serverVersionNotCompatible_message", comment: "Your server version is %@. Piwigo Mobile only supports a version of at least %@. Please update your server to use Piwigo Mobile."), NetworkVars.pwgVersion, NetworkVars.pwgMinVersion)
        }
        else {
            if detail.isEmpty {
                detail = String(format: "%ld", (error as NSError?)?.code ?? 0)
            }
        }
        updateHUD(title: title, detail: detail,
                  buttonTitle: NSLocalizedString("alertDismissButton", comment: "Dismiss"),
                  buttonTarget: self, buttonSelector: #selector(hideLoading),
                  inMode: .text)
    }

    @objc func hideLoading() {
        // Hide and remove login HUD
        hideHUD() { }
    }


    // MARK: - Utilities
    func saveServerAddress(_ serverString: String?, andUsername username: String?) -> Bool {
        guard var serverString = serverString else { return false }
        if serverString.isEmpty {
            // The URL is not correct
            return false
        }

        // Remove extra "/" at the end of the server address
        while serverString.hasSuffix("/") {
            serverString.removeLast()
        }

        // Remove extra " " at the end of the server address
        while serverString.hasSuffix(" ") {
            serverString.removeLast()
        }

        // Add default scheme if needed
        if serverString.contains("http://") == false,
           serverString.contains("https://") == false {
            serverString = "https://" + serverString
        }

        // User may have entered an incorrect URLs (would lead to a crash)
        guard let serverURL = URL(string: serverString) else { return false }

        // Is the port provided ?
//        print("sheme:\(serverURL.scheme), user:\(serverURL.user), pwd:\(serverURL.password), host:\(serverURL.host), port:\(serverURL.port), path:\(serverURL.path)")
        if serverURL.port != nil {
            // Port provided => Adopt user choice but check protocol
            // Save username, server address and protocol to disk
            switch serverURL.port {
            case 80:
                NetworkVars.serverProtocol = "http://"
                serverString = serverString.replacingOccurrences(of: "https://", with: "http://")
            case 443:
                NetworkVars.serverProtocol = "https://"
                serverString = serverString.replacingOccurrences(of: "http://", with: "https://")
            default:
                NetworkVars.serverProtocol = "\(serverURL.scheme ?? "https")://"
            }

            // Hide/show warning
            if NetworkVars.serverProtocol == "https://" {
                // Hide security message below credentials if needed
                websiteNotSecure.isHidden = true
            } else {
                // Show security message below credentials if needed
                websiteNotSecure.isHidden = false
            }

            // Save username, server address and protocol to disk
            NetworkVars.serverPath = "\(serverURL.host ?? ""):\(serverURL.port ?? 0)\(serverURL.path)"
            NetworkVars.username = username ?? ""
            return true
        }

        // Store scheme
        NetworkVars.serverProtocol = "\(serverURL.scheme ?? "https")://"

        // Hide/show warning
        if NetworkVars.serverProtocol == "https://" {
            // Hide security message below credentials if needed
            websiteNotSecure.isHidden = true
        } else {
            // Show security message below credentials if needed
            websiteNotSecure.isHidden = false
        }

        // Save username, server address and protocol to disk
        NetworkVars.serverPath = "\(serverURL.host ?? "")\(serverURL.path)"
        NetworkVars.username = username ?? ""
        return true
    }

    func showIncorrectWebAddressAlert() {
        // The URL is not correct —> inform user
        let defaultAction = UIAlertAction(
            title: NSLocalizedString("alertOkButton", comment: "OK"),
            style: .cancel, handler: { action in })
        presentPiwigoAlert(withTitle: NSLocalizedString("serverURLerror_title", comment: "Incorrect URL"),
                           message: NSLocalizedString("serverURLerror_message", comment: "Please correct the Piwigo web server address."), actions: [defaultAction])
    }

    @objc func dismissKeyboard() {
        view.endEditing(true)
    }

    @IBAction func openPiwigoURL(_ sender: UIButton) {
        if let url = URL(string: "https://piwigo.org") {
            UIApplication.shared.open(url)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}


// MARK: - MFMailComposeViewController Delegate
extension LoginViewController: MFMailComposeViewControllerDelegate
{
    func mailComposeController(_ controller: MFMailComposeViewController,
                               didFinishWith result: MFMailComposeResult, error: Error?) {
        dismiss(animated: true)
    }
}
