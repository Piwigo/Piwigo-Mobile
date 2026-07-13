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
import PwgKit
import PwgAPIKit
import PwgCacheKit
import PwgUIKit
import PwgUploadKit

class LoginViewController: UIViewController {

    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var piwigoLogo: UIButton!
    @IBOutlet weak var serverTextField: UITextField!
    @IBOutlet weak var serverTextFiledHeight: NSLayoutConstraint!
    @IBOutlet weak var userTextField: UITextField!
    @IBOutlet weak var userTextFieldHeight: NSLayoutConstraint!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var passwordTextFieldHeight: NSLayoutConstraint!
    @IBOutlet weak var loginButton: UIButton!
    @IBOutlet weak var loginButtonHeight: NSLayoutConstraint!
    @IBOutlet weak var websiteNotSecure: UILabel!
    @IBOutlet weak var piwigoURL: UIButton!
    
    private var isAlreadyTryingToLogin = false
    var httpAlertController: UIAlertController?
    var httpLoginAction: UIAlertAction?

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return InterfaceVars.shared.isDarkPaletteActive ? .lightContent : .darkContent
    }

    
    // MARK: - Core Data Object Contexts
    lazy var mainContext: NSManagedObjectContext = {
        let context:NSManagedObjectContext = DataController.shared.mainContext
        return context
    }()


    // MARK: - Core Data Providers
    private lazy var userProvider: UserProvider = {
        let provider : UserProvider = UserProvider()
        return provider
    }()


    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        scrollView.contentSize = contentView.bounds.size

        // Server URL text field
        serverTextField.placeholder = String(localized: "login_serverPlaceholder", comment: "example.com")
        serverTextField.text = ServerVars.shared.service
        serverTextField.layer.cornerRadius = TableViewUtilities.rowCornerRadius

        // Username text field
        userTextField.placeholder = String(localized: "login_userPlaceholder", comment: "Username (optional)")
        userTextField.text = ServerVars.shared.username
        userTextField.textContentType = .username
        userTextField.layer.cornerRadius = TableViewUtilities.rowCornerRadius
        
        // Password text field
        passwordTextField.placeholder = String(localized: "login_passwordPlaceholder", comment: "Password (optional)")
        passwordTextField.text = KeychainUtilities.password(forService: ServerVars.shared.serverPath,
                                                            account: ServerVars.shared.username)
        passwordTextField.textContentType = .password
        passwordTextField.layer.cornerRadius = TableViewUtilities.rowCornerRadius
        
        // Login button
        loginButton.setTitle(String(localized: "login", comment: "Login"), for: .normal)
        loginButton.addTarget(self, action: #selector(launchLogin), for: .touchUpInside)
        loginButton.layer.cornerRadius = TableViewUtilities.rowCornerRadius
        if #available(iOS 26.0, *) {
            let cornerRadius = UICornerRadius.fixed(TableViewUtilities.rowCornerRadius)
            loginButton.cornerConfiguration = .corners(radius: cornerRadius)
        }
        
        // Text fields and button heights
        updateContentSizes(for: traitCollection.preferredContentSizeCategory)
        
        // Website not secure info
        websiteNotSecure.text = String(localized: "settingsHeader_notSecure", comment: "Website Not Secure!")
                
        // Keyboard
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(UIInputViewController.dismissKeyboard)))

        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: Notification.Name.pwgPaletteChanged, object: nil)

        // Register font changes
        NotificationCenter.default.addObserver(self, selector: #selector(didChangeContentSizeCategory),
                                               name: UIContentSizeCategory.didChangeNotification, object: nil)

        // Register keyboard appearance/disappearance
        NotificationCenter.default.addObserver(self, selector: #selector(onKeyboardWillShow(_:)),
                                               name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onKeyboardWillHide(_:)), 
                                               name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @MainActor
    @objc func applyColorPalette() {
        // Background color of the view
        view.backgroundColor = PwgColor.background
        contentView.backgroundColor = PwgColor.background

        // Status bar
        setNeedsStatusBarAppearanceUpdate()

        // Change text colour according to palette color
        piwigoLogo.imageView?.overrideUserInterfaceStyle = InterfaceVars.shared.isDarkPaletteActive ? .dark : .light

        // Text color depdending on background color
        serverTextField.textColor = PwgColor.text
        serverTextField.backgroundColor = PwgColor.cellBackground
        userTextField.textColor = PwgColor.text
        userTextField.backgroundColor = PwgColor.cellBackground
        passwordTextField.textColor = PwgColor.text
        passwordTextField.backgroundColor = PwgColor.cellBackground
        websiteNotSecure.textColor = PwgColor.text
        piwigoURL.tintColor = PwgColor.text
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Set colors, fonts, etc.
        applyColorPalette()

        // Not yet trying to login
        isAlreadyTryingToLogin = false

        // Inform user if the connection is not secure
        websiteNotSecure.isHidden = ServerVars.shared.serverProtocol == "https://"
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Update title of current scene (iPad only)
        view.window?.windowScene?.title = String(localized: "login", comment: "Login")
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        // Should we update the user interface based on the appearance?
        InterfaceManager.shared.applyColorPalette(for: traitCollection.userInterfaceStyle)
    }
    
    deinit {
        // Release memory
        
        // Unregister all observers
        NotificationCenter.default.removeObserver(self)
    }

    
    // MARK: - Content Sizes
    @objc func didChangeContentSizeCategory(_ notification: NSNotification) {
        // Update content sizes
        guard let info = notification.userInfo,
              let contentSizeCategory = info[UIContentSizeCategory.newValueUserInfoKey] as? UIContentSizeCategory
        else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // Update text fields and button sizes
            updateContentSizes(for: contentSizeCategory)
            
            // Update navigation bar
            self.navigationController?.navigationBar.configAppearance(withLargeTitles: true)
        }
    }

    private func updateContentSizes(for contentSizeCategory: UIContentSizeCategory) {
        // Set cell size according to the selected category
        /// https://developer.apple.com/design/human-interface-guidelines/typography#Specifications
        let fieldHeight = TableViewUtilities.rowHeight(forContentSizeCategory: contentSizeCategory)
        serverTextFiledHeight.constant = fieldHeight
        userTextFieldHeight.constant = fieldHeight
        passwordTextFieldHeight.constant = fieldHeight
        loginButtonHeight.constant = fieldHeight
    }
    

    // MARK: - Login business
    @MainActor
    @objc func launchLogin() {
        // User pressed "Login"
        view.endEditing(true)

        // Default settings
        isAlreadyTryingToLogin = true
        ServerVars.shared.userStatus = pwgUserStatus.guest
        ServerVars.shared.usesCommunityPluginV29 = false
        ServerVars.shared.usesSetCategory = false
        NetworkVars.shared.usesAPIkeys = false
        
        // Check server address and cancel login if address not provided
        if let serverURL = serverTextField.text, serverURL.isEmpty {
            let title = String(localized: "loginEmptyServer_title", comment: "Enter a Web Address")
            let message = String(localized: "loginEmptyServer_message", comment: "Please select a protocol and enter a Piwigo web address in order to proceed.")
            dismissPiwigoError(withTitle: title, message: message) { }
            return
        }

        // Display HUD during login
        let buttonTitle = String(localized: "internetCancelledConnection_button", comment: "Cancel Connection")
        showHUD(withTitle: String(localized: "login_loggingIn", comment: "Logging In..."),
                detail: String(localized: "login_connecting", comment: "Connecting"),
                buttonTitle: buttonTitle,
                buttonTarget: self, buttonSelector: #selector(cancelLoggingIn), inMode: .indeterminate)

        // Save credentials in Keychain (needed before login when using HTTP Authentication)
        if let username = userTextField.text, username.isEmpty == false {
            // Store credentials in Keychain
            KeychainUtilities.setPassword(passwordTextField.text ?? "",
                                          forService: ServerVars.shared.serverPath,
                                          account: username)
        }

        // Collect list of methods supplied by Piwigo server
        requestServerMethods()
    }
    
    func requestServerMethods() {
        // Collect list of methods supplied by Piwigo server on background
        Task.detached {
            do {
                try await JSONManager.shared.getMethods()
                
                // Pursue logging in…
                await MainActor.run {
                    self.performLogin()
                }
            }
            catch let error as PwgKitError {
                await MainActor.run {
                    // If Piwigo uses a non-trusted certificate, ask permission
                    if ServerVars.shared.didRejectCertificate {
                        // The SSL certificate is not trusted
                        self.requestCertificateApproval(afterError: error)
                        return
                    }

                    // HTTP Basic authentication required?
                    if error.failedAuthentication || ServerVars.shared.didFailHTTPauthentication {
                        // Without prior knowledge, the app already tried Piwigo credentials
                        // but unsuccessfully, so we request HTTP credentials
                        self.requestHttpCredentials(afterError: error)
                        return
                    }

                    switch (error as NSError).code {
                    case NSURLErrorClientCertificateRejected, NSURLErrorServerCertificateHasBadDate,
                         NSURLErrorServerCertificateHasUnknownRoot, NSURLErrorServerCertificateNotYetValid,
                         NSURLErrorServerCertificateUntrusted:
                        // The SSL certificate is not trusted
                        self.requestCertificateApproval(afterError: error)
                        return
                    case NSURLErrorUserAuthenticationRequired:
                        // Without prior knowledge, the app already tried Piwigo credentials
                        // but unsuccessfully, so must now request HTTP credentials
                        self.requestHttpCredentials(afterError: error)
                        return
                    case NSURLErrorCannotConnectToHost,    // Happens when the server does not reply to the request (HTTP or HTTPS)
                         NSURLErrorSecureConnectionFailed:
                        // HTTPS request failed ?
                        if ServerVars.shared.serverProtocol == "https://" {
                            // Suggest HTTP connection if HTTPS attempt failed
                            self.requestNonSecuredAccess(afterError: error)
                        }
                        return
                    case NSURLErrorUserCancelledAuthentication:
                        self.logging(inConnectionError: error)
                        return
                    case NSURLErrorBadServerResponse, NSURLErrorBadURL, NSURLErrorCallIsActive,
                         NSURLErrorCannotDecodeContentData, NSURLErrorCannotDecodeRawData,
                         NSURLErrorCannotFindHost, NSURLErrorCannotParseResponse, NSURLErrorClientCertificateRequired,
                         NSURLErrorDataLengthExceedsMaximum, NSURLErrorDataNotAllowed, NSURLErrorDNSLookupFailed,
                         NSURLErrorHTTPTooManyRedirects, NSURLErrorInternationalRoamingOff, NSURLErrorNetworkConnectionLost,
                         NSURLErrorNotConnectedToInternet, NSURLErrorRedirectToNonExistentLocation,
                         NSURLErrorRequestBodyStreamExhausted, NSURLErrorTimedOut, NSURLErrorUnknown, NSURLErrorUnsupportedURL,
                         NSURLErrorZeroByteResource:
                        self.logging(inConnectionError: error)
                        return
                    default:
                        self.logging(inConnectionError: error)
                    }
                }
            }
        }
    }

    @MainActor
    func requestCertificateApproval(afterError error: PwgKitError) {
        let title = String(localized: "loginCertFailed_title", comment: "Connection Not Private")
        let message = "\(String(localized: "loginCertFailed_message", comment: "Piwigo warns you when a website has a certificate that is not valid. Do you still want to accept this certificate?"))\r\r\(ServerVars.shared.certificateInformation)"
        let cancelAction = UIAlertAction(title: Localized.cancel,
                                         style: .cancel, handler: { [self] action in
                // Should forget certificate
                ServerVars.shared.didApproveCertificate = false
                // Report error
                logging(inConnectionError: error)
            })
        let acceptAction = UIAlertAction(
            title: String(localized: "alertOkButton", comment: "OK"),
            style: .default, handler: { [self] action in
                // Cancel task and relaunch login
                dataSession.getAllTasks { tasks in
                    // Cancel task
                    tasks.forEach({ $0.cancel() })
                    // Will accept certificate
                    ServerVars.shared.didApproveCertificate = true
                    // Try logging in with approved certificate
                    DispatchQueue.main.async {
                        self.launchLogin()
                    }
                }
            })
        presentPiwigoAlert(withTitle: title, message: message, actions: [cancelAction, acceptAction])
    }

    @MainActor
    func requestHttpCredentials(afterError error: PwgKitError) {
        let username = ServerVars.shared.httpUsername
        let password = KeychainUtilities.password(forService: ServerVars.shared.service, account: username)
        httpAlertController = LoginUtilities.getHttpCredentialsAlert(textFieldDelegate: self,
                                                                     username: username, password: password,
                                                                     cancelAction: { [self] action in
            // Stop logging in action, display error message
            logging(inConnectionError: error)
        }, loginAction: { [self] action in
            // Store credentials
            if let httpUsername = httpAlertController?.textFields?[0].text,
               httpUsername.isEmpty == false {
                ServerVars.shared.httpUsername = httpUsername
                KeychainUtilities.setPassword(httpAlertController?.textFields?[1].text ?? "",
                    forService: ServerVars.shared.service, account: httpUsername)
                // Try logging in with new HTTP credentials
                launchLogin()
            }
        })
        if let httpAlertController = httpAlertController {
            present(httpAlertController, animated: true) {
                // Bugfix: iOS9 - Tint not fully Applied without Reapplying
                httpAlertController.view.tintColor = PwgColor.tintColor
            }
        }
    }

    @MainActor
    func requestNonSecuredAccess(afterError error: PwgKitError) {
        let title = String(localized: "loginHTTPSfailed_title", comment: "Secure Connection Failed")
        let message = String(localized: "loginHTTPSfailed_message", comment: "Piwigo cannot establish a secure connection. Do you want to try to establish an insecure connection?")
        let cancelAction = UIAlertAction(title: Localized.cancel,
                                         style: .cancel, handler: { [self] action in
            // Stop logging in action, display error message
            logging(inConnectionError: error)
        })
        let loginAction = UIAlertAction(
            title: String(localized: "alertOkButton", comment: "OK"),
            style: .default, handler: { [self] action in
                // Try logging in with HTTP scheme
                tryNonSecuredAccess(afterError: error)
            })
        presentPiwigoAlert(withTitle: title, message: message, actions: [cancelAction, loginAction])
    }

    func tryNonSecuredAccess(afterError error: PwgKitError?) {
        // Proceed at their own risk
        ServerVars.shared.serverProtocol = "http://"

        // Update URL on UI
        serverTextField.text = ServerVars.shared.service

        // Display security message below credentials
        websiteNotSecure.isHidden = false

        // Collect list of methods supplied by Piwigo server
        requestServerMethods()
    }

    @MainActor
    func performLogin() {
        // Perform login if username exists
        let username = userTextField.text ?? ""
        let password = passwordTextField.text ?? ""
        if username.isEmpty == false {
            // Update HUD during login
            updateHUD(detail: String(localized: "login_newSession", comment: "Opening Session"))

            Task.detached {
                do {
                    // Perform login
                    try await JSONManager.shared.sessionLogin(withUsername: username, password: password)
                    // Session now opened
                    ServerVars.shared.username = username

                    await MainActor.run { [self] in
                        // First determine user rights if Community extension installed
                        self.getCommunityStatus()
                    }
                }
                catch let error as PwgKitError {
                    // Don't keep unaccepted credentials
                    KeychainUtilities.deletePassword(forService: ServerVars.shared.serverPath,
                                                     account: username)
                    await MainActor.run { [self] in
                        // Login request failed
                        self.logging(inConnectionError: error)
                    }
                }
            }
        } else {
            // Reset keychain and credentials
            KeychainUtilities.deletePassword(forService: ServerVars.shared.serverPath,
                                             account: username)
            ServerVars.shared.user = ""
            ServerVars.shared.username = ""
            ServerVars.shared.userStatus = .guest
            
            // Create/update guest account in persistent cache, create Server if necessary.
            do {
                // Performed in main thread so to avoid concurrency issue with AlbumViewController initialisation
                _ = try self.userProvider.getUserAccount(inContext: mainContext, afterUpdate: true)
                
                // Check Piwigo version, get token, available sizes, etc.
                self.getCommunityStatus()
            }
            catch {
                // Login request failed
                logging(inConnectionError: error)
            }
        }
    }

    // Determine true user rights when Community extension installed
    @MainActor
    func getCommunityStatus() {
        // Community plugin installed?
        if ServerVars.shared.usesCommunityPluginV29 {
            // Update HUD during login
            updateHUD(detail: String(localized: "login_communityParameters", comment: "Community Parameters"))

            Task.detached {
                do {
                    // Community extension installed, get real user's status
                    try await JSONManager.shared.communityGetStatus()
                    
                    await MainActor.run { [self] in
                        // Check Piwigo version, get token, available sizes, etc.
                        self.getSessionStatus()
                    }
                }
                catch let error as PwgKitError {
                    // Inform user that server failed to retrieve Community parameters
                    await MainActor.run { [self] in
                        self.isAlreadyTryingToLogin = false
                        self.logging(inConnectionError: error)
                    }
                }
            }
        } else {
            // Community extension not installed
            // Check Piwigo version, get token, available sizes, etc.
            self.getSessionStatus()
        }
    }

    // Check Piwigo version, get username, token, available sizes, etc.
    @MainActor
    func getSessionStatus() {
        // Update HUD during login
        updateHUD(detail: String(localized: "login_serverParameters", comment: "Piwigo Parameters"))

        Task.detached {
            do {
                // Update Piwigo username (≠ credential)
                ServerVars.shared.user = try await JSONManager.shared.sessionGetStatus()

                await MainActor.run { [self] in
                    // Should this server be updated?
                    let now: Double = Date().timeIntervalSinceReferenceDate
                    if now > ServerVars.shared.dateOfLastUpdateRequest + AppVars.shared.pwgOneMonth,
                       ServerVars.shared.pwgVersion.compare(pwgRecentVersion, options: .numeric) == .orderedAscending {
                        // Store date of last upgrade request
                        ServerVars.shared.dateOfLastUpdateRequest = now
                        
                        // Piwigo server update recommanded ► Inform user
                        self.hideHUD() {
                            self.dismissPiwigoError(withTitle: String(localized: "serverVersionOld_title", comment: "Server Update Available"), message: String.localizedStringWithFormat(String(localized: "serverVersionOld_message", comment: "Your Piwigo server version is %@. Please ask the administrator to update it."), ServerVars.shared.pwgVersion), completion: {
                                    // Piwigo server version is still appropriate.
                                    self.launchApp()
                            })
                        }
                    } else {
                        // Piwigo server version is appropriate.
                        self.launchApp()
                    }
                }
            }
            catch let error as PwgKitError {
                await MainActor.run { [self] in
                    self.isAlreadyTryingToLogin = false
                    // Display error message
                    self.logging(inConnectionError: error)
                }
            }
        }
    }

    @MainActor
    func launchApp() {
        isAlreadyTryingToLogin = false

        // Create/update User account in persistent cache, create Server if necessary.
        do {
            // Performed in main thread so to avoid concurrency issue with AlbumViewController initialisation
            _ = try self.userProvider.getUserAccount(inContext: mainContext, afterUpdate: true)
        }
        catch {
            logging(inConnectionError: error)
        }
        
        // Check image size availabilities
        let scale = CGFloat(fmax(1.0, self.view.traitCollection.displayScale))
        LoginUtilities.checkAvailableSizes(forScale: scale)

        // Present Album/Images view and resume uploads
        guard let window = self.view.window,
              let appDelegate = UIApplication.shared.delegate as? AppDelegate
        else { return }
        hideHUD() {
            // Present Album/Images view and resume uploads
            appDelegate.loadNavigation(in: window)
        }
    }
    
    
    // MARK: - HUD methods
    @MainActor
    @objc func cancelLoggingIn() {
        // Update login HUD
        updateHUD(detail: String(localized: "internetCancellingConnection_button", comment: "Cancelling Connection…"))

        // Propagate user's request
        dataSession.getAllTasks() { tasks in
            tasks.forEach { $0.cancel() }
        }
    }

    @MainActor
    func logging(inConnectionError error: PwgKitError) {
        // Do not present error message when executing background task
        if view.window == nil {
            hideLoading()
            return
        }

        // Error returned
        var title = String(localized: "internetErrorGeneral_title", comment: "Connection Error")
        var detail = error.localizedDescription
        var buttonSelector = #selector(hideLoading)
        if error.requestCancelled {
            title = String(localized: "internetCancelledConnection_title", comment: "Connection Cancelled")
        }
        else if error.failedAuthentication {
            title = String(localized: "loginError_title", comment: "Login Fail")
            buttonSelector = #selector(suggestPwdRetrieval)
        }
        else if error.incompatibleVersion {
            title = String(localized: "serverVersionNotCompatible_title", comment: "Server Incompatible")
            detail = String.localizedStringWithFormat(PwgKitError.incompatiblePwgVersion.localizedDescription, ServerVars.shared.pwgVersion, pwgMinVersion)
        }
        else if detail.isEmpty {
                detail = String(format: "%ld", (error as NSError?)?.code ?? 0)
        }
        updateHUD(title: title, detail: detail,
                  buttonTitle: Localized.dismiss,
                  buttonTarget: self, buttonSelector: buttonSelector,
                  inMode: pwgHudMode.none)
    }
    
    @MainActor
    @objc func suggestPwdRetrieval() {
        // Hide HUD
        hideLoading()
        
        // Suggest to retrieve password
        let title = String(localized: "loginError_title", comment: "Login Fail")
        let message = String(localized: "loginError_resetPwd", comment: "Would you like to reset your password from the web interface?")
        let cancelAction = UIAlertAction(title: Localized.cancel, style: .cancel, handler: { _ in })
        let retrieveAction = UIAlertAction(
            title: String(localized: "alertOkButton", comment: "OK"),
            style: .default, handler: { _ in
                if let url = URL(string: ServerVars.shared.service + "/password.php") {
                    UIApplication.shared.open(url)
                }
            })
        presentPiwigoAlert(withTitle: title, message: message, actions: [cancelAction, retrieveAction])
    }

    @MainActor
    @objc func hideLoading() {
        // Hide and remove login HUD
        hideHUD() { }
    }


    // MARK: - Utilities
    func saveServerAddress(_ serverString: String?) -> Bool {
        // Check server address
        guard var serverString = serverString, serverString.isEmpty == false
        else { return false }

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
//        debugPrint("sheme:\(serverURL.scheme), user:\(serverURL.user), pwd:\(serverURL.password), host:\(serverURL.host), port:\(serverURL.port), path:\(serverURL.path)")
        if serverURL.port != nil {
            // Port provided => Adopt user choice but check protocol
            // Save server address and protocol
            switch serverURL.port {
            case 80:
                ServerVars.shared.serverProtocol = "http://"
                if #available(iOS 16.0, *) {
                    serverString = serverString.replacing("https://", with: "http://")
                } else {
                    // Fallback on earlier versions
                    serverString = serverString.replacingOccurrences(of: "https://", with: "http://")
                }
            case 443:
                ServerVars.shared.serverProtocol = "https://"
                if #available(iOS 16.0, *) {
                    serverString = serverString.replacing("http://", with: "https://")
                } else {
                    // Fallback on earlier versions
                    serverString = serverString.replacingOccurrences(of: "http://", with: "https://")
                }
            default:
                ServerVars.shared.serverProtocol = "\(serverURL.scheme ?? "https")://"
            }

            // Hide/show warning
            if ServerVars.shared.serverProtocol == "https://" {
                // Hide security message below credentials if needed
                websiteNotSecure.isHidden = true
            } else {
                // Show security message below credentials if needed
                websiteNotSecure.isHidden = false
            }

            // Save server address and protocol to disk
            ServerVars.shared.serverPath = "\(serverURL.host ?? ""):\(serverURL.port ?? 0)\(serverURL.path)"
            return true
        }

        // Store scheme
        ServerVars.shared.serverProtocol = "\(serverURL.scheme ?? "https")://"

        // Hide/show warning
        if ServerVars.shared.serverProtocol == "https://" {
            // Hide security message below credentials if needed
            websiteNotSecure.isHidden = true
        } else {
            // Show security message below credentials if needed
            websiteNotSecure.isHidden = false
        }

        // Save server address and protocol to disk
        ServerVars.shared.serverPath = "\(serverURL.host ?? "")\(serverURL.path)"
        return true
    }

    @MainActor
    func showIncorrectWebAddressAlert() {
        // The URL is not correct —> inform user
        let defaultAction = UIAlertAction(
            title: String(localized: "alertOkButton", comment: "OK"),
            style: .cancel, handler: { action in })
        presentPiwigoAlert(withTitle: PwgKitError.wrongServerURL.localizedDescription,
                           message: PwgKitError.invalidURL.localizedDescription, actions: [defaultAction])
    }

    @MainActor
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
