//
//  LoginViewController.swift
//  piwigo
//
//  Created by Spencer Baker on 1/17/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//
//  Converted to Swift 5.4 by Eddy Lelièvre-Berna on 26/02/2022.
//

import MessageUI
import System
import UIKit
import piwigoKit

let kPiwigoSupport = "— iOS@piwigo.org —"

class LoginViewController: UIViewController {

    var piwigoLogo: UIButton?
    var piwigoButton: UIButton?
    var serverTextField: PiwigoTextField?
    var userTextField: PiwigoTextField?
    var passwordTextField: PiwigoTextField?
    var loginButton: PiwigoButton?
    var websiteNotSecure: UILabel?
    var byLabel1: UILabel?
    var byLabel2: UILabel?
    var versionLabel: UILabel?
    var isAlreadyTryingToLogin = false
    var portraitConstraints: [AnyHashable]?
    var landscapeConstraints: [AnyHashable]?

    private var httpAlertController: UIAlertController?
    private var httpLoginAction: UIAlertAction?
    private var hudViewController: UIViewController?

    override init(nibName: String?, bundle: Bundle?) {
        super.init(nibName: nil, bundle: nil)
        view.backgroundColor = UIColor.piwigoColorBrown()

        piwigoLogo = UIButton(type: .custom)
        piwigoLogo?.setImage(UIImage(named: "piwigoLogo"), for: .normal)
        piwigoLogo?.translatesAutoresizingMaskIntoConstraints = false
        piwigoLogo?.contentMode = .scaleAspectFit
        piwigoLogo?.addTarget(self, action: #selector(openPiwigoURL), for: .touchUpInside)
        if let piwigoLogo = piwigoLogo {
            view.addSubview(piwigoLogo)
        }

        piwigoButton = UIButton()
        piwigoButton?.backgroundColor = UIColor.clear
        piwigoButton?.translatesAutoresizingMaskIntoConstraints = false
        piwigoButton?.titleLabel?.font = UIFont.piwigoFontNormal()
        piwigoButton?.setTitleColor(UIColor.piwigoColorOrange(), for: .normal)
        piwigoButton?.setTitle(kPiwigoSupport, for: .normal)
        piwigoButton?.addTarget(self, action: #selector(mailPiwigoSupport), for: .touchUpInside)
        if let piwigoButton = piwigoButton {
            view.addSubview(piwigoButton)
        }

        serverTextField = PiwigoTextField()
        serverTextField?.placeholder = NSLocalizedString("login_serverPlaceholder", comment: "example.com")
        serverTextField?.text = "\(NetworkVars.serverProtocol)\(NetworkVars.serverPath)"
        serverTextField?.keyboardType = .URL
        serverTextField?.returnKeyType = .next
        serverTextField?.delegate = self
        if let serverTextField = serverTextField {
            view.addSubview(serverTextField)
        }

        userTextField = PiwigoTextField()
        userTextField?.placeholder = NSLocalizedString("login_userPlaceholder", comment: "Username (optional)")
        userTextField?.text = NetworkVars.username
        userTextField?.keyboardType = .default
        userTextField?.returnKeyType = .next
        if #available(iOS 11.0, *) {
            userTextField?.textContentType = .username
        }
        userTextField?.delegate = self
        if let userTextField = userTextField {
            view.addSubview(userTextField)
        }

        passwordTextField = PiwigoTextField()
        passwordTextField?.placeholder = NSLocalizedString("login_passwordPlaceholder", comment: "Password (optional)")
        passwordTextField?.isSecureTextEntry = true
        passwordTextField?.text = KeychainUtilitiesObjc.password(forService: NetworkVars.serverPath, account: NetworkVars.username)
        passwordTextField?.keyboardType = .default
        if #available(iOS 11.0, *) {
            passwordTextField?.textContentType = .password
        }
        passwordTextField?.returnKeyType = .go
        if let passwordTextField = passwordTextField {
            view.addSubview(passwordTextField)
        }

        loginButton = PiwigoButton()
        loginButton?.translatesAutoresizingMaskIntoConstraints = false
        loginButton?.setTitle(NSLocalizedString("login", comment: "Login"), for: .normal)
        loginButton?.addTarget(self, action: #selector(launchLogin), for: .touchUpInside)
        if let loginButton = loginButton {
            view.addSubview(loginButton)
        }

        websiteNotSecure = UILabel()
        websiteNotSecure?.translatesAutoresizingMaskIntoConstraints = false
        websiteNotSecure?.font = UIFont.piwigoFontSmall()
        websiteNotSecure?.text = NSLocalizedString("settingsHeader_notSecure", comment: "Website Not Secure!")
        websiteNotSecure?.textAlignment = .center
        websiteNotSecure?.textColor = UIColor.white
        websiteNotSecure?.adjustsFontSizeToFitWidth = true
        websiteNotSecure?.minimumScaleFactor = 0.8
        websiteNotSecure?.lineBreakMode = .byTruncatingTail
        if let websiteNotSecure = websiteNotSecure {
            view.addSubview(websiteNotSecure)
        }

        byLabel1 = UILabel()
        byLabel1?.translatesAutoresizingMaskIntoConstraints = false
        byLabel1?.font = UIFont.piwigoFontSmall()
        byLabel1?.textColor = UIColor.piwigoColorOrangeLight()
        byLabel1?.text = NSLocalizedString("authors1", tableName: "About", bundle: Bundle.main, value: "", comment: "By Spencer Baker, Olaf Greck,")
        if let byLabel1 = byLabel1 {
            view.addSubview(byLabel1)
        }

        byLabel2 = UILabel()
        byLabel2?.translatesAutoresizingMaskIntoConstraints = false
        byLabel2?.font = UIFont.piwigoFontSmall()
        byLabel2?.textColor = UIColor.piwigoColorOrangeLight()
        byLabel2?.text = NSLocalizedString("authors2", tableName: "About", bundle: Bundle.main, value: "", comment: "and Eddy Lelièvre-Berna")
        if let byLabel2 = byLabel2 {
            view.addSubview(byLabel2)
        }

        versionLabel = UILabel()
        versionLabel?.translatesAutoresizingMaskIntoConstraints = false
        versionLabel?.font = UIFont.piwigoFontTiny()
        versionLabel?.textColor = UIColor.piwigoColorOrangeLight()
        if let versionLabel = versionLabel {
            view.addSubview(versionLabel)
        }

        let appVersionString = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let appBuildString = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        versionLabel?.text = "— \(NSLocalizedString("version", tableName: "About", bundle: Bundle.main, value: "", comment: "Version:")) \(appVersionString ?? "") (\(appBuildString ?? "")) —"

        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(UIInputViewController.dismissKeyboard)))

        if UIDevice.current.userInterfaceIdiom == .phone {
            setupAutoLayout4iPhone()
        } else {
            setupAutoLayout4iPad()
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    
    // MARK: - View Lifecycle

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Set colors, fonts, etc.
        applyColorPalette()

        // Not yet trying to login
        isAlreadyTryingToLogin = false

        // Inform user if the connection is not secure
        websiteNotSecure?.isHidden = NetworkVars.serverProtocol == "https://"

        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: PwgNotifications.paletteChanged, object: nil)
    }

    @objc func applyColorPalette() {
        // Server
        serverTextField?.textColor = UIColor.piwigoColorText()
        serverTextField?.backgroundColor = UIColor.piwigoColorBackground()

        // Username
        userTextField?.textColor = UIColor.piwigoColorText()
        userTextField?.backgroundColor = UIColor.piwigoColorBackground()

        // Password
        passwordTextField?.textColor = UIColor.piwigoColorText()
        passwordTextField?.backgroundColor = UIColor.piwigoColorBackground()

        // Login button
        if AppVars.shared.isDarkPaletteActive {
            loginButton?.backgroundColor = UIColor.piwigoColorOrangeSelected()
        } else {
            loginButton?.backgroundColor = UIColor.piwigoColorOrange()
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        // Should we update user interface based on the appearance?
        if #available(iOS 13.0, *) {
            let hasUserInterfaceStyleChanged = previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle
            if hasUserInterfaceStyleChanged {
                AppVars.shared.isSystemDarkModeActive = (traitCollection.userInterfaceStyle == .dark)
                let appDelegate = UIApplication.shared.delegate as? AppDelegate
                appDelegate?.screenBrightnessChanged()
            }
        } else {
            // Fallback on earlier versions
        }
    }

    deinit {
        // Unregister palette changes
        NotificationCenter.default.removeObserver(self, name: PwgNotifications.paletteChanged, object: nil)

        // Release memory
        hudViewController = nil
    }

    // MARK: - Login business

    @objc func launchLogin() {
        // User pressed "Login"
        view.endEditing(true)

        // Default settings
        isAlreadyTryingToLogin = true
        NetworkVars.hasAdminRights = false
        NetworkVars.hasNormalRights = false
        NetworkVars.usesCommunityPluginV29 = false

        #if DEBUG_SESSION
        print("=> launchLogin: starting with…")
        print(
            "   usesCommunityPluginV29=\(NetworkVars.usesCommunityPluginV29 ? "YES" : "NO"), hasAdminRights=\(NetworkVars.hasAdminRights ? "YES" : "NO"), hasNormalRights=\(NetworkVars.hasNormalRights ? "YES" : "NO")")
        #endif

        // Check server address and cancel login if address not provided
        if (serverTextField?.text?.count ?? 0) <= 0 {
            let alert = UIAlertController(
                title: NSLocalizedString("loginEmptyServer_title", comment: "Enter a Web Address"),
                message: NSLocalizedString("loginEmptyServer_message", comment: "Please select a protocol and enter a Piwigo web address in order to proceed."),
                preferredStyle: .alert)

            let defaultAction = UIAlertAction(
                title: NSLocalizedString("alertOkButton", comment: "OK"),
                style: .cancel,
                handler: { action in
                })

            alert.addAction(defaultAction)
            alert.view.tintColor = UIColor.piwigoColorOrange()
            if #available(iOS 13.0, *) {
                alert.overrideUserInterfaceStyle = AppVars.shared.isDarkPaletteActive ? .dark : .light
            } else {
                // Fallback on earlier versions
            }
            present(alert, animated: true) {
                // Bugfix: iOS9 - Tint not fully Applied without Reapplying
                alert.view.tintColor = UIColor.piwigoColorOrange()
            }

            return
        }

        // Display HUD during login
        //    UIViewController *rootViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
        //    self.hudViewController = rootViewController.childViewControllers.firstObject;
        hudViewController = UIApplication.shared.keyWindow?.rootViewController
        hudViewController?.showPiwigoHUD(
            withTitle: NSLocalizedString("login_loggingIn", comment: "Logging In..."),
            detail: NSLocalizedString("login_connecting", comment: "Connecting"),
            buttonTitle: NSLocalizedString("internetCancelledConnection_button", comment: "Cancel Connection"),
            buttonTarget: self,
            buttonSelector: #selector(cancelLoggingIn),
            inMode: .indeterminate)

        // Save credentials in Keychain (needed before login when using HTTP Authentication)
        if let username = userTextField?.text, username.isEmpty == false {
            // Store credentials in Keychain
            KeychainUtilities.setPassword(passwordTextField?.text ?? "",
                                          forService: NetworkVars.serverPath,
                                          account: username)
        }

        // Create permanent session managers for retrieving data and downloading images
        NetworkHandler.createJSONdataSessionManager() // 30s timeout, 4 connections max
        NetworkHandler.createFavoritesDataSessionManager() // 30s timeout, 1 connection max
        NetworkHandler.createImagesSessionManager() // 60s timeout, 4 connections max

        // Collect list of methods supplied by Piwigo server
        // => Determine if Community extension 2.9a or later is installed and active
        #if DEBUG_SESSION
        print("=> launchLogin: getMethodsList using \(NetworkVars.serverProtocol)")
        #endif
        NetworkVarsObjc.sessionManager!.session.configuration.timeoutIntervalForRequest = 10
        LoginUtilities.getMethods {
            // Back to default timeout
            NetworkVarsObjc.sessionManager!.session.configuration.timeoutIntervalForRequest = 30

            // Known methods, pursue logging in…
            DispatchQueue.main.async { [self] in
                performLogin()
            }
        } failure: { error in
            // If Piwigo used a non-trusted certificate, ask permission
            if NetworkVars.didRejectCertificate {
                // The SSL certificate is not trusted
                self.requestCertificateApproval(afterError: error)
                return
            }

            // HTTP Basic authentication required?
            if (error as NSError).code == 401 || (error as NSError).code == 403 || NetworkVars.didFailHTTPauthentication {
                // Without prior knowledge, the app already tried Piwigo credentials
                // but unsuccessfully, so we request HTTP credentials
                self.requestHttpCredentials(afterError: error)
                return
            }

            switch (error as NSError).code {
            case Int(NSURLErrorUserAuthenticationRequired):
                // Without prior knowledge, the app already tried Piwigo credentials
                // but unsuccessfully, so must now request HTTP credentials
                self.requestHttpCredentials(afterError: error)
                return
            case Int(NSURLErrorUserCancelledAuthentication):
                self.logging(inConnectionError: nil)
                return
            case Int(NSURLErrorBadServerResponse), Int(NSURLErrorBadURL), Int(NSURLErrorCallIsActive), Int(NSURLErrorCannotDecodeContentData), Int(NSURLErrorCannotDecodeRawData), Int(NSURLErrorCannotFindHost), Int(NSURLErrorCannotParseResponse), Int(NSURLErrorClientCertificateRequired), Int(NSURLErrorDataLengthExceedsMaximum), Int(NSURLErrorDataNotAllowed), Int(NSURLErrorDNSLookupFailed), Int(NSURLErrorHTTPTooManyRedirects), Int(NSURLErrorInternationalRoamingOff), Int(NSURLErrorNetworkConnectionLost), Int(NSURLErrorNotConnectedToInternet), Int(NSURLErrorRedirectToNonExistentLocation), Int(NSURLErrorRequestBodyStreamExhausted), Int(NSURLErrorTimedOut), Int(NSURLErrorUnknown), Int(NSURLErrorUnsupportedURL), Int(NSURLErrorZeroByteResource):
                self.logging(inConnectionError: NetworkVars.userCancelledCommunication ? nil : error)
                return
            case Int(NSURLErrorCannotConnectToHost),                 // Happens when the server does not reply to the request (HTTP or HTTPS)
            Int(NSURLErrorSecureConnectionFailed):
                // HTTPS request failed ?
                if (NetworkVars.serverProtocol == "https://") && !NetworkVars.userCancelledCommunication {
                    // Suggest HTTP connection if HTTPS attempt failed
                    self.requestNonSecuredAccess(afterError: error)
                    return
                }
                return
            case Int(NSURLErrorClientCertificateRejected), Int(NSURLErrorServerCertificateHasBadDate), Int(NSURLErrorServerCertificateHasUnknownRoot), Int(NSURLErrorServerCertificateNotYetValid), Int(NSURLErrorServerCertificateUntrusted):
                // The SSL certificate is not trusted
                self.requestCertificateApproval(afterError: error)
                return
            default:
                break
            }

            // Display error message
            self.logging(inConnectionError: NetworkVars.userCancelledCommunication ? nil : error)
        }
    }

    func requestCertificateApproval(afterError error: Error?) {
        let message = "\(NSLocalizedString("loginCertFailed_message", comment: "Piwigo warns you when a website has a certificate that is not valid. Do you still want to accept this certificate?"))\r\r\(NetworkVars.certificateInformation)"
        httpAlertController = UIAlertController(
            title: NSLocalizedString("loginCertFailed_title", comment: "Connection Not Private"),
            message: message,
            preferredStyle: .alert)

        let cancelAction = UIAlertAction(
            title: NSLocalizedString("alertCancelButton", comment: "Cancel"),
            style: .cancel,
            handler: { [self] action in
                // Should forget certificate
                NetworkVars.didApproveCertificate = false
                // Report error
                logging(inConnectionError: error)
            })

        let acceptAction = UIAlertAction(
            title: NSLocalizedString("alertOkButton", comment: "OK"),
            style: .default,
            handler: { [self] action in
                // Cancel task
                NetworkVarsObjc.sessionManager!.invalidateSessionCancelingTasks(true, resetSession: true)
                // Will accept certificate
                NetworkVars.didApproveCertificate = true
                // Try logging in with approved certificate
                launchLogin()
            })

        httpAlertController?.addAction(cancelAction)
        httpAlertController?.addAction(acceptAction)
        httpAlertController?.view.tintColor = UIColor.piwigoColorOrange()
        if #available(iOS 13.0, *) {
            httpAlertController?.overrideUserInterfaceStyle = AppVars.shared.isDarkPaletteActive ? .dark : .light
        } else {
            // Fallback on earlier versions
        }
        DispatchQueue.main.async { [self] in
            if let httpAlertController = httpAlertController {
                present(httpAlertController, animated: true) {
                    // Bugfix: iOS9 - Tint not fully Applied without Reapplying
                    httpAlertController.view.tintColor = UIColor.piwigoColorOrange()
                }
            }
        }
    }

    func requestHttpCredentials(afterError error: Error?) {
        let username = NetworkVars.httpUsername
        let password = KeychainUtilitiesObjc.password(forService: "\(NetworkVars.serverProtocol)\(NetworkVars.serverPath)", account: username)

        httpAlertController = UIAlertController(
            title: NSLocalizedString("loginHTTP_title", comment: "HTTP Credentials"),
            message: NSLocalizedString("loginHTTP_message", comment: "HTTP basic authentification is required by the Piwigo server:"),
            preferredStyle: .alert)

        httpAlertController?.addTextField(configurationHandler: { [self] userTextField in
            userTextField.placeholder = NSLocalizedString("loginHTTPuser_placeholder", comment: "username")
            userTextField.text = (username.count > 0) ? username : ""
            userTextField.clearButtonMode = .always
            userTextField.keyboardType = .default
            userTextField.keyboardAppearance = AppVars.shared.isDarkPaletteActive ? .dark : .default
            userTextField.returnKeyType = .continue
            userTextField.autocapitalizationType = .none
            userTextField.autocorrectionType = .no
            userTextField.delegate = self;
        })

        httpAlertController?.addTextField(configurationHandler: { pwdTextField in
            pwdTextField.placeholder = NSLocalizedString("loginHTTPpwd_placeholder", comment: "password")
            pwdTextField.text = (password.count > 0) ? password : ""
            pwdTextField.clearButtonMode = .always
            pwdTextField.keyboardType = .default
            pwdTextField.isSecureTextEntry = true
            pwdTextField.keyboardAppearance = AppVars.shared.isDarkPaletteActive ? .dark : .default
            pwdTextField.autocapitalizationType = .none
            pwdTextField.autocorrectionType = .no
            pwdTextField.returnKeyType = .continue
            pwdTextField.delegate = self;
        })

        let cancelAction = UIAlertAction(
            title: NSLocalizedString("alertCancelButton", comment: "Cancel"),
            style: .cancel,
            handler: { [self] action in
                // Stop logging in action, display error message
                logging(inConnectionError: error)
            })

        httpLoginAction = UIAlertAction(
            title: NSLocalizedString("alertOkButton", comment: "OK"),
            style: .default,
            handler: { [self] action in
                // Store credentials
                if let httpUsername = httpAlertController?.textFields?[0].text,
                   httpUsername.isEmpty == false {
                    NetworkVars.httpUsername = httpUsername
                    KeychainUtilities.setPassword(httpAlertController?.textFields?[1].text ?? "",
                        forService: "\(NetworkVars.serverProtocol)\(NetworkVars.serverPath)",
                        account: httpUsername)
                    // Try logging in with new HTTP credentials
                    launchLogin()
                }
            })

        httpAlertController?.addAction(cancelAction)
        if let httpLoginAction = httpLoginAction {
            httpAlertController?.addAction(httpLoginAction)
        }
        httpAlertController?.view.tintColor = UIColor.piwigoColorOrange()
        if #available(iOS 13.0, *) {
            httpAlertController?.overrideUserInterfaceStyle = AppVars.shared.isDarkPaletteActive ? .dark : .light
        } else {
            // Fallback on earlier versions
        }
        if let httpAlertController = httpAlertController {
            present(httpAlertController, animated: true) {
                // Bugfix: iOS9 - Tint not fully Applied without Reapplying
                httpAlertController.view.tintColor = UIColor.piwigoColorOrange()
            }
        }
    }

    func requestNonSecuredAccess(afterError error: Error?) {
        httpAlertController = UIAlertController(
            title: NSLocalizedString("loginHTTPSfailed_title", comment: "Secure Connection Failed"),
            message: NSLocalizedString("loginHTTPSfailed_message", comment: "Piwigo cannot establish a secure connection. Do you want to try to establish an insecure connection?"),
            preferredStyle: .alert)

        let cancelAction = UIAlertAction(
            title: NSLocalizedString("alertNoButton", comment: "No"),
            style: .cancel,
            handler: { [self] action in
                // Stop logging in action, display error message
                logging(inConnectionError: error)
            })

        let acceptAction = UIAlertAction(
            title: NSLocalizedString("alertYesButton", comment: "Yes"),
            style: .default,
            handler: { [self] action in
                // Try logging in with HTTP scheme
                tryNonSecuredAccess(afterError: error)
            })

        httpAlertController?.addAction(cancelAction)
        httpAlertController?.addAction(acceptAction)
        httpAlertController?.view.tintColor = UIColor.piwigoColorOrange()
        if #available(iOS 13.0, *) {
            httpAlertController?.overrideUserInterfaceStyle = AppVars.shared.isDarkPaletteActive ? .dark : .light
        } else {
            // Fallback on earlier versions
        }
        DispatchQueue.main.async { [self] in
            if let httpAlertController = httpAlertController {
                present(httpAlertController, animated: true) {
                    // Bugfix: iOS9 - Tint not fully Applied without Reapplying
                    httpAlertController.view.tintColor = UIColor.piwigoColorOrange()
                }
            }
        }
    }

    func tryNonSecuredAccess(afterError error: Error?) {
        // Proceed at their own risk
        NetworkVars.serverProtocol = "http://"

        // Update URL on UI
        serverTextField?.text = "\(NetworkVars.serverProtocol)\(NetworkVars.serverPath)"

        // Display security message below credentials
        websiteNotSecure?.isHidden = false

        // Collect list of methods supplied by Piwigo server
        // => Determine if Community extension 2.9a or later is installed and active
        #if DEBUG_SESSION
        print("=> launchLogin using http: getMethodsList…")
        #endif
        LoginUtilities.getMethods {
            // Back to default timeout
            NetworkVarsObjc.sessionManager!.session.configuration.timeoutIntervalForRequest = 30

            // Known methods, pursue logging in…
            DispatchQueue.main.async { [self] in
                performLogin()
            }
        } failure: { error in
            // Get Piwigo methods failed
            DispatchQueue.main.async { [self] in
                logging(inConnectionError: NetworkVars.userCancelledCommunication ? nil : error)
            }
        }
    }

    func performLogin() {
        #if DEBUG_SESSION
        print(
            "   usesCommunityPluginV29=\(NetworkVars.usesCommunityPluginV29 ? "YES" : "NO"), hasAdminRights=\(NetworkVars.hasAdminRights ? "YES" : "NO"), hasNormalRights=\(NetworkVars.hasNormalRights ? "YES" : "NO")")
        print("=> performLogin: starting…")
        #endif

        // Perform login if username exists
        let username = userTextField?.text ?? ""
        let password = passwordTextField?.text ?? ""
        if ((userTextField?.text?.count ?? 0) > 0) && !NetworkVars.userCancelledCommunication {
            // Update HUD during login
            hudViewController?.showPiwigoHUD(
                withTitle: NSLocalizedString("login_loggingIn", comment: "Logging In..."),
                detail: NSLocalizedString("login_newSession", comment: "Opening Session"),
                buttonTitle: NSLocalizedString("internetCancelledConnection_button", comment: "Cancel Connection"),
                buttonTarget: self,
                buttonSelector: #selector(cancelLoggingIn),
                inMode: .indeterminate)

            // Perform login
            LoginUtilities.sessionLogin(
                withUsername: username,
                password: password,
                completion: { [self] in
                    // Session now opened
                    // First determine user rights if Community extension installed
                    getCommunityStatus(atFirstLogin: true, withReloginCompletion: { })

                },
                failure: { [self] error in
                    // Don't keep unaccepted credentials
                    KeychainUtilitiesObjc.deletePassword(
                        forService: NetworkVars.serverPath,
                        account: username)
                    // Login request failed
                    logging(inConnectionError: NetworkVars.userCancelledCommunication ? nil : error)
                })
        } else {
            // Reset keychain and credentials
            KeychainUtilitiesObjc.deletePassword(forService: NetworkVars.serverPath,
                                                 account: NetworkVars.username)
            NetworkVars.username = ""

            // Check Piwigo version, get token, available sizes, etc.
            getCommunityStatus(atFirstLogin: true, withReloginCompletion: { })
        }
    }

    // Determine true user rights when Community extension installed
    func getCommunityStatus(atFirstLogin isFirstLogin: Bool,
                            withReloginCompletion reloginCompletion: @escaping () -> Void) {
        #if DEBUG_SESSION
        print(
            "   usesCommunityPluginV29=\(NetworkVars.usesCommunityPluginV29 ? "YES" : "NO"), hasAdminRights=\(NetworkVars.hasAdminRights ? "YES" : "NO"), hasNormalRights=\(NetworkVars.hasNormalRights ? "YES" : "NO")")
        print("=> getCommunityStatusAtFirstLogin:\(isFirstLogin ? "YES" : "NO") starting…")
        #endif
        if (NetworkVars.usesCommunityPluginV29) && !NetworkVars.userCancelledCommunication {
            // Update HUD during login
            hudViewController?.showPiwigoHUD(
                withTitle: NSLocalizedString("login_loggingIn", comment: "Logging In..."),
                detail: NSLocalizedString("login_communityParameters", comment: "Community Parameters"),
                buttonTitle: NSLocalizedString("internetCancelledConnection_button", comment: "Cancel Connection"),
                buttonTarget: self,
                buttonSelector: #selector(cancelLoggingIn),
                inMode: .indeterminate)

            // Community extension installed
            LoginUtilities.communityGetStatus {
                // Check Piwigo version, get token, available sizes, etc.
                self.getSessionStatus(atLogin: true, andFirstLogin: isFirstLogin, withReloginCompletion: reloginCompletion)
            } failure: { error in
                // Inform user that server failed to retrieve Community parameters
                NetworkVars.hadOpenedSession = false
                self.isAlreadyTryingToLogin = false
                self.logging(inConnectionError: NetworkVars.userCancelledCommunication ? nil : error)
            }
        } else {
            // Community extension not installed
            // Check Piwigo version, get token, available sizes, etc.
            getSessionStatus(atLogin: true, andFirstLogin: isFirstLogin, withReloginCompletion: reloginCompletion)
        }
    }

    // Check Piwigo version, get token, available sizes, etc.
    func getSessionStatus(
        atLogin isLoggingIn: Bool,
        andFirstLogin isFirstLogin: Bool,
        withReloginCompletion reloginCompletion: @escaping () -> Void
    ) {
        #if DEBUG_SESSION
        print(
            "   hudViewController=\(NetworkVars.usesCommunityPluginV29 ? "YES" : "NO"), hasAdminRights=\(NetworkVars.hasAdminRights ? "YES" : "NO"), hasNormalRights=\(NetworkVars.hasNormalRights ? "YES" : "NO")")
        print(
            "=> getSessionStatusAtLogin:\(isLoggingIn ? "YES" : "NO") andFirstLogin:\(isFirstLogin ? "YES" : "NO") starting…")
        #endif
        if !NetworkVars.userCancelledCommunication {
            // Update HUD during login
            hudViewController?.showPiwigoHUD(
                withTitle: NSLocalizedString("login_loggingIn", comment: "Logging In..."),
                detail: NSLocalizedString("login_serverParameters", comment: "Piwigo Parameters"),
                buttonTitle: NSLocalizedString("internetCancelledConnection_button", comment: "Cancel Connection"),
                buttonTarget: self,
                buttonSelector: #selector(cancelLoggingIn),
                inMode: .indeterminate)

            LoginUtilities.sessionGetStatus(atLogin: isLoggingIn, completion: { [self] in
                if "2.8.0".compare(NetworkVars.pwgVersion, options: .numeric, range: nil, locale: .current) != .orderedAscending {
                    // They need to update, ask user what to do
                    // Reinitialise flag
                    NetworkVars.userCancelledCommunication = false

                    // Close loading or re-login view and ask what to do
                    DispatchQueue.main.async { [self] in
                        hudViewController?.hidePiwigoHUD() { [self] in
                            let defaultAction = UIAlertAction(
                                title: NSLocalizedString("alertNoButton", comment: "No"),
                                style: .cancel,
                                handler: { [self] action in
                                    isAlreadyTryingToLogin = false
                                })
                            let continueAction = UIAlertAction(
                                title: NSLocalizedString("alertYesButton", comment: "Yes"),
                                style: .destructive,
                                handler: { [self] action in
                                    // Proceed at their own risk
                                    launchApp(
                                        atFirstLogin: isFirstLogin,
                                        withReloginCompletion: reloginCompletion)
                                })
                            presentPiwigoAlert(withTitle: NSLocalizedString("serverVersionNotCompatible_title", comment: "Server Incompatible"), message: String.localizedStringWithFormat(NSLocalizedString("serverVersionNotCompatible_message", comment: "Your server version is %@. Piwigo Mobile only supports a version of at least 2.8. Please update your server to use Piwigo Mobile\nDo you still want to continue?"), NetworkVars.pwgVersion), actions: [defaultAction, continueAction])
                        }
                    }
                } else {
                    // Their version is Ok. Close HUD.
                    launchApp(atFirstLogin: isFirstLogin,
                              withReloginCompletion: reloginCompletion)
                }
            }, failure: { [self] error in
                NetworkVars.hadOpenedSession = false
                isAlreadyTryingToLogin = false
                // Display error message
                logging(inConnectionError: NetworkVars.userCancelledCommunication ? nil : error)
            })
        } else {
            NetworkVars.hadOpenedSession = false
            isAlreadyTryingToLogin = false
            logging(inConnectionError: nil)
        }
    }

    func launchApp(atFirstLogin isFirstLogin: Bool,
                   withReloginCompletion reloginCompletion: @escaping () -> Void) {
        isAlreadyTryingToLogin = false
        NetworkVars.dateOfLastLogin = Date()

        // Load navigation if needed
        if isFirstLogin {
            // Update HUD during login
            hudViewController?.showPiwigoHUD(
                withTitle: NSLocalizedString("loadingHUD_label", comment: "Loading…"),
                detail: NSLocalizedString("tabBar_albums", comment: "Albums"),
                buttonTitle: NSLocalizedString("internetCancelledConnection_button", comment: "Cancel Connection"),
                buttonTarget: self,
                buttonSelector: #selector(cancelLoggingIn),
                inMode: .indeterminate)

            // Load category data in recursive mode
            DispatchQueue.global(qos: .default).async { [self] in
                AlbumService.getAlbumData(onCompletion: { [self] task, didChange in
                    // Reinitialise flag
                    NetworkVars.userCancelledCommunication = false

                    // Hide HUD and present root album
                    if let hudViewController = hudViewController {
                        hudViewController.hidePiwigoHUD() {
                            // Present Album/Images view and resume uploads
                            let appDelegate = UIApplication.shared.delegate as? AppDelegate
                            appDelegate?.loadNavigation()
                        }
                    } else {
                        hidePiwigoHUD() {
                            // Present Album/Images view and resume uploads
                            let appDelegate = UIApplication.shared.delegate as? AppDelegate
                            appDelegate?.loadNavigation()
                        }
                    }

                    // Load favorites in the background if necessary
                    if !NetworkVars.hasGuestRights && ("2.10.0".compare(NetworkVars.pwgVersion, options: .numeric, range: nil, locale: .current) != .orderedDescending) {
                        // Initialise favorites album
                        if let favoritesAlbum = PiwigoAlbumData.init(discoverAlbumForCategory: kPiwigoFavoritesCategoryId) {
                            CategoriesData.sharedInstance().updateCategories([favoritesAlbum])
                        }

                        // Load favorites data in the background with dedicated URL session
                        DispatchQueue.global(qos: .default).async {
                            CategoriesData.sharedInstance().getCategoryById(kPiwigoFavoritesCategoryId).loadAllCategoryImageData(
                                withSort: kPiwigoSortObjc(rawValue: UInt32(AlbumVars.shared.defaultSort)),
                                forProgress: nil,
                                onCompletion: nil,
                                onFailure: nil)
                        }
                    }
                }, onFailure: { [self] task, error in
                    DispatchQueue.main.async { [self] in
                        // Inform user that we could not load album data
                        NetworkVars.hadOpenedSession = false
                        logging(inConnectionError: NetworkVars.userCancelledCommunication ? nil : error)
                    }
                })
            }
        } else {
            // Hide HUD if needed
            if let hudViewController = hudViewController {
                hudViewController.hidePiwigoHUD() {
                    reloginCompletion()
                }
            } else {
                hidePiwigoHUD() {
                    reloginCompletion()
                }
            }
        }
    }

    func performRelogin(withCompletion reloginCompletion: @escaping () -> Void) {
        #if DEBUG_SESSION
        print(
            "   usesCommunityPluginV29=\(NetworkVars.usesCommunityPluginV29 ? "YES" : "NO"), hasAdminRights=\(NetworkVars.hasAdminRights ? "YES" : "NO"), hasNormalRights=\(NetworkVars.hasNormalRights ? "YES" : "NO")")
        print("=> performRelogin: starting…")
        #endif

        // Don't try to relogin in if already being trying
        if isAlreadyTryingToLogin {
            return
        }

        // Do not present HUD during re-login
        hudViewController = nil

        // Perform re-login
        let username = NetworkVars.username
        let password = KeychainUtilitiesObjc.password(forService: NetworkVars.serverPath, account: username)
        isAlreadyTryingToLogin = true
        LoginUtilities.sessionLogin(withUsername: username, password: password, completion: { [self] in
            // Session re-opened
            // First determine user rights if Community extension installed
            getCommunityStatus(atFirstLogin: false,
                               withReloginCompletion: reloginCompletion)
        }, failure: { [self] error in
            // Could not re-establish the session, login/pwd changed, something else ?
            isAlreadyTryingToLogin = false

            // Display error message
            logging(inConnectionError: NetworkVars.userCancelledCommunication ? nil : error)
        })
    }

    func reloadCatagoryDataInBckgMode() {
        // Load category data in recursive mode in the background
        DispatchQueue.global(qos: .default).async { [self] in
            AlbumService.getAlbumData(onCompletion: { task, didChange in
                let viewController = UIApplication.shared.keyWindow?.rootViewController?.children.last
                if viewController is AlbumImagesViewController {
                    // Check data source and reload collection if needed
                    let vc = viewController as? AlbumImagesViewController
                    vc?.checkDataSource(withChangedCategories: didChange)
                }

                // Resume uploads
                let appDelegate = UIApplication.shared.delegate as? AppDelegate
                appDelegate?.resumeAll()

                // Load favorites in the background if necessary
//                if (!NetworkVars.hasGuestRights &&
//                    ([@"2.10.0" compare:NetworkVars.pwgVersion options:NSNumericSearch] != NSOrderedDescending))
//                {
//                    // Initialise favorites album
//                    PiwigoAlbumData *favoritesAlbum = [[PiwigoAlbumData alloc] initDiscoverAlbumForCategory:kPiwigoFavoritesCategoryId];
//                    [CategoriesData.sharedInstance updateCategories:@[favoritesAlbum]];
//
//                    // Load favorites data in the background with dedicated URL session
//                    dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0),^{
//                        [[CategoriesData.sharedInstance getCategoryById:kPiwigoFavoritesCategoryId] loadAllCategoryImageDataWithSort:(kPiwigoSortObjc)AlbumVars.shared.defaultSort
//                        forProgress:nil onCompletion:nil onFailure:nil];
//                    });
//                }
            }, onFailure: { [self] task, error in
                DispatchQueue.main.async(execute: { [self] in
                    // Inform user that we could not load album data
                    logging(inConnectionError: NetworkVars.userCancelledCommunication ? nil : error)
                })
            })
        }
    }

    // MARK: - HUD methods

    @objc func cancelLoggingIn() {
        // Propagate user's request
        NetworkVars.userCancelledCommunication = true
        NetworkVarsObjc.dataSession.getAllTasks(completionHandler: { tasks in
            for task in tasks {
                task.cancel()
            }
        })
        let tasks = NetworkVarsObjc.sessionManager!.tasks
        for task in tasks {
            task.cancel()
        }

        // Update login HUD
        hudViewController?.showPiwigoHUD(
            withTitle: NSLocalizedString("login_loggingIn", comment: "Logging In..."),
            detail: NSLocalizedString("internetCancellingConnection_button", comment: "Cancelling Connection…"),
            buttonTitle: NSLocalizedString("internetCancelledConnection_button", comment: "Cancel Connection"),
            buttonTarget: self,
            buttonSelector: #selector(cancelLoggingIn),
            inMode: .indeterminate)
    }

    func logging(inConnectionError error: Error?) {
        // Do not present error message when executing background task
        if UploadVarsObjc.isExecutingBackgroundUploadTask {
            hideLoading()
            return
        }

        if error == nil {
            hudViewController?.showPiwigoHUD(
                withTitle: NSLocalizedString("internetCancelledConnection_title", comment: "Connection Cancelled"),
                detail: " ",
                buttonTitle: NSLocalizedString("alertDismissButton", comment: "Dismiss"),
                buttonTarget: self,
                buttonSelector: #selector(hideLoading),
                inMode: .text)
        } else {
            var detail = error?.localizedDescription ?? ""
            if detail.isEmpty {
                detail = String(format: "%ld", (error as NSError?)?.code ?? 0)
            }
            hudViewController?.showPiwigoHUD(
                withTitle: NSLocalizedString("internetErrorGeneral_title", comment: "Connection Error"),
                detail: detail,
                buttonTitle: NSLocalizedString("alertDismissButton", comment: "Dismiss"),
                buttonTarget: self,
                buttonSelector: #selector(hideLoading),
                inMode: .text)
        }
    }

    @objc func hideLoading() {
        // Reinitialise flag
        NetworkVars.userCancelledCommunication = false

        // Hide and remove login HUD
        hudViewController?.hidePiwigoHUD() { }
    }


    // MARK: - Utilities

    func saveServerAddress(_ serverString: String?, andUsername username: String?) -> Bool {
        guard var serverString = serverString else { return false }
        if serverString.isEmpty {
            // The URL is not correct
            //        NSLog(@"ATTENTION!!! Incorrect URL");
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

        // User may have entered an incorrect URLs (would lead to a crash)
        if serverString.contains("http://") == false,
           serverString.contains("https://") == false {
            serverString = "https://" + serverString
        }
        guard let serverURL = URL(string: serverString) else { return false }

        // Is the port provided ?
//        debugPrint("sheme:\(serverURL.scheme), user:\(serverURL.user), pwd:\(serverURL.password), host:\(serverURL.host), port:\(serverURL.port), path:\(serverURL.path)")
        if serverURL.port != nil {
            // Port provided => Adopt user choice but check protocol
            // Save username, server address and protocol to disk
            switch serverURL.port {
            case 80:
                NetworkVars.serverProtocol = "http://"
            case 443:
                NetworkVars.serverProtocol = "https://"
            default:
                NetworkVars.serverProtocol = "\(serverURL.scheme ?? "https")://"
            }

            // Hide/show warning
            if NetworkVars.serverProtocol == "https://" {
                // Hide security message below credentials if needed
                websiteNotSecure?.isHidden = true
            } else {
                // Show security message below credentials if needed
                websiteNotSecure?.isHidden = false
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
            websiteNotSecure?.isHidden = true
        } else {
            // Show security message below credentials if needed
            websiteNotSecure?.isHidden = false
        }

        // Save username, server address and protocol to disk
        NetworkVars.serverPath = "\(serverURL.host ?? "")\(serverURL.path)"
        NetworkVars.username = username ?? ""
        return true
    }

    func showIncorrectWebAddressAlert() {
        // The URL is not correct —> inform user
        let alert = UIAlertController(
            title: NSLocalizedString("serverURLerror_title", comment: "Incorrect URL"),
            message: NSLocalizedString("serverURLerror_message", comment: "Please correct the Piwigo web server address."),
            preferredStyle: .alert)

        let defaultAction = UIAlertAction(
            title: NSLocalizedString("alertOkButton", comment: "OK"),
            style: .cancel,
            handler: { action in
            })

        alert.addAction(defaultAction)
        alert.view.tintColor = UIColor.piwigoColorOrange()
        if #available(iOS 13.0, *) {
            alert.overrideUserInterfaceStyle = AppVars.shared.isDarkPaletteActive ? .dark : .light
        } else {
            // Fallback on earlier versions
        }
        present(alert, animated: true) {
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            alert.view.tintColor = UIColor.piwigoColorOrange()
        }
    }

    @objc func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc func openPiwigoURL() {
        if let url = URL(string: "https://piwigo.org") {
            UIApplication.shared.openURL(url)
        }
    }

    @objc func mailPiwigoSupport() {
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
            composeVC.setSubject("[Ticket#\(ticketDate)]: \(NSLocalizedString("settings_appName", comment: "Piwigo Mobile"))")

            // Collect system and device data
            let deviceModel = UIDevice.current.modelName
            let deviceOS = UIDevice.current.systemName
            let deviceOSversion = UIDevice.current.systemVersion

            // Set message body
            composeVC.setMessageBody("\(NSLocalizedString("settings_appName", comment: "Piwigo Mobile")) \(appVersionString ?? "") (\(appBuildString ?? ""))\n\(deviceModel) — \(deviceOS) \(deviceOSversion)\n==============>>\n\n", isHTML: false)

            // Present the view controller modally.
            present(composeVC, animated: true)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}


// MARK: - UITextField Delegate Methods
extension LoginViewController: UITextFieldDelegate
{
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        // Disable HTTP login action until user provides credentials
        if let httpAlertController = httpAlertController {
            // Requesting autorisation to access non secure web site
            // or asking HTTP basic authentication credentials
            if (httpAlertController.textFields?.count ?? 0) > 0 {
                // Being requesting HTTP basic authentication credentials
                if textField == httpAlertController.textFields?[0] {
                    if (httpAlertController.textFields?[0].text?.count ?? 0) == 0 {
                        httpLoginAction?.isEnabled = false
                    }
                } else if textField == httpAlertController.textFields?[1] {
                    if (httpAlertController.textFields?[1].text?.count ?? 0) == 0 {
                        httpLoginAction?.isEnabled = false
                    }
                }
            }
        }
        return true
    }

    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        // Disable login buttons
        if textField == serverTextField {
            loginButton?.isEnabled = false
        } else if let httpAlertController = httpAlertController {
            // Requesting autorisation to access non secure web site
            // or asking HTTP basic authentication credentials
            if (httpAlertController.textFields?.count ?? 0) > 0 {
                // Being requesting HTTP basic authentication credentials
                if (textField == httpAlertController.textFields?[0]) || (textField == httpAlertController.textFields?[1]) {
                    httpLoginAction?.isEnabled = false
                }
            }
        }

        return true
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let finalString = (textField.text as NSString?)?.replacingCharacters(in: range, with: string)

        if textField == serverTextField {
            // Disable Login button if URL invalid
            let _ = saveServerAddress(finalString, andUsername: userTextField?.text)
            loginButton?.isEnabled = true
        } else if let httpAlertController = httpAlertController {
            // Requesting autorisation to access non secure web site
            // or asking HTTP basic authentication credentials
            if (httpAlertController.textFields?.count ?? 0) > 0 {
                // Being requesting HTTP basic authentication credentials
                if (textField == httpAlertController.textFields?[0]) || (textField == httpAlertController.textFields?[1]) {
                    // Enable HTTP Login action if field not empty
                    httpLoginAction?.isEnabled = (finalString?.count ?? 0) >= 1
                }
            }
        }

        return true
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == serverTextField {
            // Save server address and username to disk
            let validURL = saveServerAddress(serverTextField?.text, andUsername: userTextField?.text)
            loginButton?.isEnabled = validURL
            if !validURL {
                // Incorrect URL
                showIncorrectWebAddressAlert()
                return false
            }

            // User entered acceptable server address
            userTextField?.becomeFirstResponder()
        }
        else if textField == userTextField {
            // User entered username
            let pwd = KeychainUtilities.password(forService: serverTextField?.text ?? "",
                                                 account: userTextField?.text ?? "")
            passwordTextField?.text = pwd
            passwordTextField?.becomeFirstResponder()
        }
        else if textField == passwordTextField {
            // User entered password —> Launch login
            launchLogin()
        }
        return true
    }

    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        if textField == serverTextField {
            // Save server address and username to disk
            let validURL = saveServerAddress(serverTextField?.text, andUsername: userTextField?.text)
            loginButton?.isEnabled = validURL
            if !validURL {
                // Incorrect URL
                showIncorrectWebAddressAlert()
                return false
            }
        }
        return true
    }
}


extension LoginViewController: MFMailComposeViewControllerDelegate
{
    func mailComposeController(_ controller: MFMailComposeViewController,
                               didFinishWith result: MFMailComposeResult, error: Error?) {
        dismiss(animated: true)
    }
}
