//
//  AppDelegate.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 20/06/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import AVFoundation
import BackgroundTasks
import CoreHaptics
import Foundation
import Intents
import LocalAuthentication
import UIKit

import IQKeyboardManagerSwift
import piwigoKit

@UIApplicationMain
@objc class AppDelegate: UIResponder, UIApplicationDelegate {
        
    let kPiwigoBackgroundTaskUpload = "org.piwigo.uploadManager"

    var window: UIWindow?
    var privacyView: UIView?
    var isAuthenticatingWithBiometrics = false
    var didCancelBiometricsAuthentication = false

    // MARK: - App Initialisation
    func application(_ application: UIApplication, didFinishLaunchingWithOptions
                        launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        print("••> App did finish launching with options.")
        // Read old settings file and create UserDefaults cached files
        Model.sharedInstance().readFromDisk()

        // Register notifications for displaying number of uploads to perform in app badge
        if #available(iOS 9.0, *) {
            let settings = UIUserNotificationSettings.init(types: .badge, categories: nil)
            UIApplication.shared.registerUserNotificationSettings(settings)
        }
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().requestAuthorization(options: .badge) { granted, Error in
//                if granted { print("request succeeded!") }
            }
        }

        // IQKeyboardManager
        let keyboardManager = IQKeyboardManager.shared
        keyboardManager.enable = true
        keyboardManager.overrideKeyboardAppearance = true
        keyboardManager.shouldToolbarUsesTextFieldTintColor = true
        keyboardManager.shouldShowToolbarPlaceholder = true

        // Color palette depends on system settings
        initColorPalette()

        // Check if the device supports haptics.
        if #available(iOS 13.0, *) {
            let hapticCapability = CHHapticEngine.capabilitiesForHardware()
            AppVars.shared.supportsHaptics = hapticCapability.supportsHaptics
        }
        
        // Set Settings Bundle data
        setSettingsBundleData()
        
        // Create permanent session managers for retrieving data and downloading images
        NetworkHandler.createJSONdataSessionManager()       // 30s timeout, 4 connections max
        NetworkHandler.createFavoritesDataSessionManager()  // 30s timeout, 1 connection max
        NetworkHandler.createImagesSessionManager()         // 60s timeout, 4 connections max

        // In absence of passcode, albums are always accessible
        if AppVars.shared.appLockKey.isEmpty {
            AppVars.shared.isAppLockActive = false
            AppVars.shared.isAppUnlocked = true
        }
        
        // What follows depends on iOS version
        if #available(iOS 13.0, *) {
            // Register launch handlers for tasks if using iOS 13
            /// Will have to check if pwg.images.uploadAsync is available
            registerBgTasks()

            // Delegate to SceneDelegate
            /// - Present login view and if needed passcode view
        } else {
            // Create login view
            window = UIWindow(frame: UIScreen.main.bounds)
            loadLoginView(in: window)
            window?.makeKeyAndVisible()
            
            // Blur views if the App Lock is enabled
            /// The passcode window is not presented  so that the app
            /// does not request the passcode until it is put into the background.
            if AppVars.shared.isAppLockActive {
                // User is not allowed to access albums yet
                AppVars.shared.isAppUnlocked = false
                // Protect presented login view
                addPrivacyProtection(to: window)
            }
            else {
                // User is allowed to access albums
                AppVars.shared.isAppUnlocked = true
            }
        }
        
        // Register left upload requests notifications updating the badge
        NotificationCenter.default.addObserver(self, selector: #selector(updateBadge),
                                               name: .pwgLeftUploads, object: nil)
        
        // Register auto-upload appender failures
        NotificationCenter.default.addObserver(self, selector: #selector(displayAutoUploadErrorAndResume),
                                               name: .pwgAppendAutoUploadRequestsFailed, object: nil)

        // Register uploaded image notification appending image to CategoriesData cache
        NotificationCenter.default.addObserver(self, selector: #selector(addImage),
                                               name: .pwgAddUploadedImageToCache, object: nil)
        return true
    }


    // MARK: - Scene Configuration
    @available(iOS 13.0, *)
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        
        var currentActivity: ActivityType?
        options.userActivities.forEach {
          currentActivity = ActivityType(rawValue: $0.activityType)
        }

        let activity = currentActivity ?? ActivityType.album
        return activity.sceneConfiguration()
    }

    @available(iOS 13.0, *)
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        //..
    }

    
    // MARK: - App Remote Notifications
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Did fail to register notifications.")
    }
    

    // MARK: - Transitioning to the Foreground
    func applicationWillEnterForeground(_ application: UIApplication) {
        print("••> App will enter foreground.")
        // Called when the app is about to enter the foreground.
        // This call is then followed by a call to applicationDidBecomeActive().

        // Enable network activity indicator
        AFNetworkActivityIndicatorManager.shared().isEnabled = true
        
        // Enable network reachability monitoring
        AFNetworkReachabilityManager.shared().startMonitoring()
    }
        
    func applicationDidBecomeActive(_ application: UIApplication) {
        print("••> App did become active.")
        // The app has become active.
        // Restart any tasks that were paused (or not yet started) while the application was inactive.
        // If the application was previously in the background, optionally refresh the user interface.
        
        // Called during biometric authentication?
        if isAuthenticatingWithBiometrics { return }

        // Request passcode if necessary
        if AppVars.shared.isAppUnlocked == false {
            // Request passcode for accessing app
            requestPasscode(onTopOf: window) { appLockVC in
                // Set delegate
                appLockVC.delegate = self
                // Hide privacy view
                self.privacyView?.isHidden = true
                // Did user enable biometrics?
                if AppVars.shared.isBiometricsEnabled,
                   self.didCancelBiometricsAuthentication == false {
                    // Yes, perform biometrics authentication
                    self.performBiometricAuthentication() { success in
                        // Authentication successful?
                        if !success { return }
                        // Dismiss passcode view controller
                        appLockVC.dismiss(animated: true) {
                            // Unlock the app
                            self.loginOrReloginAndResumeUploads()
                        }
                    }
                }
            }
            return
        }

        // Login/relogin and resume uploads
        loginOrReloginAndResumeUploads()
    }

    
    // MARK: - Transitioning to the Background
    func applicationWillResignActive(_ application: UIApplication) {
        print("••> App will resign active.")
        // Called when the app is about to become inactive. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.

        // Called during biometric authentication?
        if isAuthenticatingWithBiometrics { return }

        // Blur views if the App Lock is enabled
        /// The passcode window is not presented  so that the app
        /// does not request the passcode until it is put into the background.
        if AppVars.shared.isAppLockActive {
            // Remember to ask for passcode
            AppVars.shared.isAppUnlocked = false
            // Remove passcode view controller if presented
            if let topViewController = window?.topMostViewController(),
               topViewController is AppLockViewController {
                // Protect presented views
                privacyView?.isHidden = false
                // Reset biometry flag
                didCancelBiometricsAuthentication = false
                // Dismiss passcode view
                topViewController.dismiss(animated: true)
            } else {
                // Protect presented views
                addPrivacyProtection(to: window)
            }
        } else {
            // Remember to not ask for passcode
            AppVars.shared.isAppUnlocked = true
        }

        // Inform Upload Manager to pause activities
        UploadManager.shared.isPaused = true
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        print("••> App did enter background.")
        // Called when the app is now in the background.
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        
        // Save cached data
        DataController.saveContext()

        // Disable network activity indicator
        AFNetworkActivityIndicatorManager.shared().isEnabled = false
        
        // Disable network reachability monitoring
        AFNetworkReachabilityManager.shared().stopMonitoring()

        // Clean up /tmp directory
        cleanUpTemporaryDirectory(immediately: false)
    }
        
    func applicationWillTerminate(_ application: UIApplication) {
        print("••> App will terminate.")
        // Called when the application is about to terminate.
        // Save data if appropriate. See also applicationDidEnterBackground:.
        
        // Save cached data
        DataController.saveContext()

        // Cancel tasks and close sessions
        NetworkVarsObjc.sessionManager?.invalidateSessionCancelingTasks(true, resetSession: true)
        NetworkVarsObjc.imagesSessionManager?.invalidateSessionCancelingTasks(true, resetSession: true)

        // Disable network activity indicator
        AFNetworkActivityIndicatorManager.shared().isEnabled = false
        
        // Disable network reachability monitoring
        AFNetworkReachabilityManager.shared().stopMonitoring()
        
        // Clean up /tmp directory
        cleanUpTemporaryDirectory(immediately: false)

        // Unregister left upload requests notifications updating the badge
        NotificationCenter.default.removeObserver(self, name: .pwgLeftUploads, object: nil)
        
        // Unregister auto-upload appender failures
        NotificationCenter.default.removeObserver(self, name: .pwgAppendAutoUploadRequestsFailed, object: nil)
        
        // Unregister uploaded image notification appending image to CategoriesData cache
        NotificationCenter.default.removeObserver(self, name: .pwgAddUploadedImageToCache, object: nil)
    }
    

    // MARK: - Background Uploading
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession
                        identifier: String, completionHandler: @escaping () -> Void) {
        print("    > Handle events for background session with ID: \(identifier)");
        
        // Upload session of the app?
        if identifier.compare(UploadSessions.shared.uploadBckgSessionIdentifier) == .orderedSame {
            UploadSessions.shared.uploadSessionCompletionHandler = completionHandler
            print("    > Rejoining session with CompletionHandler.")
        }
    }
    
    /// Contains any `URLSession` instances associated with app extensions.
//    private lazy var appExtensionSessions: [URLSession] = []

    /// Creates an identical `URLSession` for the given identifier or returns an existing `URLSession` if it was already registered.
    /// - Parameter identifier: The `URLSessionConfiguration` identifier to use for recreating the `URLSession`.
    /// - Returns: A newly created or existing `URLSession` instance matching the given identifier.
    /// The URL sessions are cached in appExtensionSessions.
//    private func session(for identifier: String) -> URLSession {
//        if let existingSession = appExtensionSessions.first(where: { $0.configuration.identifier == identifier }) {
//            return existingSession
//        }
//
//        let configuration = URLSessionConfiguration.background(withIdentifier: identifier)
//        configuration.sharedContainerIdentifier = UserDefaults.appGroup
//        let appExtensionSession = URLSession(configuration: configuration,
//                                             delegate: AutoUploadSessionDelegate.shared,
//                                             delegateQueue: nil)
//        appExtensionSessions.append(appExtensionSession)
//        return appExtensionSession
//    }

    @available(iOS 13.0, *)
    private func registerBgTasks() {
        // Register background upload task
        BGTaskScheduler.shared.register(forTaskWithIdentifier: kPiwigoBackgroundTaskUpload, using: nil) { task in
             self.handleNextUpload(task: task as! BGProcessingTask)
        }
    }

    @available(iOS 13.0, *)
    func scheduleNextUpload() {
        // Schedule upload not earlier than 1 minute from now
        // Uploading requires network connectivity and external power
        let request = BGProcessingTaskRequest.init(identifier: kPiwigoBackgroundTaskUpload)
        request.earliestBeginDate = Date.init(timeIntervalSinceNow: 1 * 60)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = true
        
        // Submit upload request
        do {
            try BGTaskScheduler.shared.submit(request)
            print("    > Background upload task request submitted with success.")
        } catch {
            print("    > Failed to submit background upload request: \(error)")
        }
    }

    @available(iOS 13.0, *)
    private func handleNextUpload(task: BGProcessingTask) {
        // Schedule the next upload if needed
        if UploadManager.shared.nberOfUploadsToComplete > 0 {
            print("    > Schedule next uploads.")
            scheduleNextUpload()
        }

        // Create the operation queue
        let uploadQueue = OperationQueue()
        uploadQueue.maxConcurrentOperationCount = 1
        
        // Add operation setting flag and selecting upload requests
        let initOperation = BlockOperation {
            // Initialse variables and determine upload requests to prepare and transfer
            UploadManager.shared.initialiseBckgTask()
        }

        // Initialise list of operations
        var uploadOperations = [BlockOperation]()
        uploadOperations.append(initOperation)

        // Resume transfers
        let resumeOperation = BlockOperation {
            // Transfer image
            UploadManager.shared.resumeTransfers()
        }
        resumeOperation.addDependency(uploadOperations.last!)
        uploadOperations.append(resumeOperation)

        // Add image preparation which will be followed by transfer operations
        for _ in 0..<UploadManager.shared.maxNberOfUploadsPerBckgTask {
            let uploadOperation = BlockOperation {
                // Prepare then transfer image
                UploadManager.shared.appendUploadRequestsToPrepareToBckgTask()
            }
            uploadOperation.addDependency(uploadOperations.last!)
            uploadOperations.append(uploadOperation)
        }

        // Provide an expiration handler for the background task
        // that cancels the operation
        task.expirationHandler = {
            print("    > Task expired: Upload operation cancelled.")
            // Cancel operations
            uploadQueue.cancelAllOperations()
        }
        
        // Inform the system that the background task is complete
        // when the operation completes
        let lastOperation = uploadOperations.last!
        lastOperation.completionBlock = {
            print("    > Task completed with success.")
            task.setTaskCompleted(success: true)
            // Save cached data
            DispatchQueue.main.async {
                DataController.saveContext()
            }
        }

        // Start the operation
        print("    > Start upload operations in background task...");
        uploadQueue.addOperations(uploadOperations, waitUntilFinished: false)
    }

    @objc func updateBadge(_ notification: Notification) {
        guard let nberOfUploadsToComplete = notification.userInfo?["nberOfUploadsToComplete"] as? Int else {
            fatalError("!!! Did not provide an integer !!!")
        }
        UIApplication.shared.applicationIconBadgeNumber = nberOfUploadsToComplete
    }

    @objc func displayAutoUploadErrorAndResume(_ notification: Notification) {
        // Retrieve message and error
        guard let message = notification.userInfo?["message"] as? String else { return }
        let errorMsg = notification.userInfo?["errorMsg"] as? String

        // Display error message and resume Upload Manager operation
        let title = NSLocalizedString("settings_autoUpload", comment: "Auto Upload")
        if let topViewController = UIApplication.shared.keyWindow?.rootViewController,
           topViewController is UINavigationController,
           let visibleVC = (topViewController as! UINavigationController).visibleViewController {
            // Inform user
            visibleVC.dismissPiwigoError(withTitle: title, message: message, errorMessage: errorMsg ?? "") {
                // Restart UploadManager activities
                if UploadManager.shared.isPaused {
                    UploadManager.shared.isPaused = false
                    UploadManager.shared.backgroundQueue.async {
                        UploadManager.shared.findNextImageToUpload()
                    }
                }
            }
        }
    }


    // MARK: - Cleaning
    /// Delete files stored in the temporary directory after a week i.e. after the timeout period of the UploadSessionDelegate
    func cleanUpTemporaryDirectory(immediately: Bool) {
        let fm = FileManager.default
        do {
            let tmpDirectory = try fm.contentsOfDirectory(atPath: NSTemporaryDirectory())
            for file in tmpDirectory {
                let path = String(format: "%@%@", NSTemporaryDirectory(), file)
                let attrs = try fm.attributesOfItem(atPath: path)
                if let fileCreationDate = attrs[FileAttributeKey.creationDate] as? Date,
                   (fileCreationDate.timeIntervalSinceReferenceDate + k1WeekInDays < Date.timeIntervalSinceReferenceDate) || immediately {
                    try fm.removeItem(atPath: path)
                }
            }
        }
        catch {
            print("Could not clean up the temporary directory")
        }
    }

    
    // MARK: - Intents
    
    @available(iOS 14.0, *)
    func application(_ application: UIApplication, handlerFor intent: INIntent) -> Any? {
        switch intent {
        case is AutoUploadIntent:
            return AutoUploadIntentHandler()
        default:
            return nil
        }
    }
    
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        debugPrint(userActivity)
        return true
    }
    
//    @available(iOS 10.0, *)
//    func application(_ application: UIApplication, handle intent: INIntent, completionHandler: @escaping (INIntentResponse) -> Void) {
//        if #available(iOS 12.0, *) {
//            switch intent {
//            case is AutoUploadIntent:
//                let handler = AutoUploadIntentHandler()
//                handler.handle(intent: intent as! AutoUploadIntent) { response in
//                    completionHandler(response)
//                }
//            default:
//                break
//            }
//        } else {
//            // Fallback on earlier versions
//        }
//    }
    
    
    // MARK: - Settings bundle
    /// Updates the version and build numbers in the app's settings bundle.
    private func setSettingsBundleData() {
        
        // Get the Settings.bundle object
        let defaults = UserDefaults.standard
        
        // Get bunch of values from the .plist file and take note that the values that
        // we pull are generated in a Build Phase script that is definied in the Target.
        guard let appVersionString = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else { return }
        guard let appBuildString = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String else { return }
        
        // Create the version number
        let versionNumberInSettings = String(format: "%@ (%@)", appVersionString, appBuildString)
        
        // Set the build date and version number in the settings bundle reflected in app settings.
        defaults.setValue(versionNumberInSettings, forKey: "version_prefs")
    }

    
    // MARK: - Privacy & Passcode
    func addPrivacyProtection(to window: UIWindow?) {
        // Blur views if the App Lock is enabled
        /// The passcode window is not presented now so that the app
        /// does not request the passcode until it is put into the background.
        if privacyView == nil,
           let frame = window?.frame {
            if UIAccessibility.isReduceTransparencyEnabled {
                 // Settings ▸ Accessibility ▸ Display & Text Size ▸ Reduce Transparency is enabled
                 let storyboard = UIStoryboard(name: "LaunchScreen", bundle: nil)
                 let initialViewController = storyboard.instantiateInitialViewController()
                 privacyView = initialViewController?.view
             } else {
                 // Settings ▸ Accessibility ▸ Display & Text Size ▸ Reduce Transparency is disabled
                 let blurEffect = UIBlurEffect(style: .dark)
                 privacyView = UIVisualEffectView(effect: blurEffect)
                 privacyView?.frame = frame
             }
         }
        window?.addSubview(privacyView!)
        privacyView?.isHidden = false
    }

    func requestPasscode(onTopOf window: UIWindow?,
                         completion: @escaping (AppLockViewController) -> Void) {
        // Check if the passcode is already being requested
        guard let topViewController = window?.topMostViewController() else { return }
        if let appLockVC = topViewController as? AppLockViewController {
            // Passcode view controller already presented
            completion(appLockVC)
            return
        }

        // Create passcode view controller
        let appLockSB = UIStoryboard(name: "AppLockViewController", bundle: nil)
        guard let appLockVC = appLockSB.instantiateViewController(withIdentifier: "AppLockViewController") as? AppLockViewController else { return }
        appLockVC.config(forAction: .unlockApp)
        appLockVC.modalPresentationStyle = .overFullScreen
        appLockVC.modalTransitionStyle = .crossDissolve
        topViewController.present(appLockVC, animated: false, completion: {
            completion(appLockVC)
        })
    }
    
    func performBiometricAuthentication(completion: @escaping (Bool) -> Void) {
        // Get a fresh context
        let context = LAContext()
        context.localizedFallbackTitle = ""
        if #available(iOS 11.0, *) {
            context.localizedReason = NSLocalizedString("settings_appLockEnter", comment: "Enter Passcode")
        }

        // First check if we have the needed hardware support
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            // Exploit TouchID or FaceID
            self.isAuthenticatingWithBiometrics = true
            let reason = NSLocalizedString("settings_biometricsReason", comment: "Access your Piwigo albums")
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason ) { success, error in
                // Biometric authentication completed
                self.isAuthenticatingWithBiometrics = false
                // Did user authenticate successfully?
                if success {
                    // User allowed to access app
                    AppVars.shared.isAppUnlocked = true
                    // Dismiss passcode view
                    DispatchQueue.main.async {
                        completion(true)
                    }
                }
                else {
                    // Fall back to a asking for passcode
                    if let error = error as? LAError {
                        switch error.code {
                        case .userCancel, .userFallback, .invalidContext, .notInteractive:
                            self.didCancelBiometricsAuthentication = true
                        case .authenticationFailed, .systemCancel, .appCancel, .passcodeNotSet:
                            fallthrough
                        default:
                            debugPrint(error.localizedDescription)
                        }
                    }
                    DispatchQueue.main.async {
                        completion(false)
                    }
                }
            }
        }
    }


    // MARK: - Login View
    private var _loginVC: LoginViewController!
    var loginVC: LoginViewController {
        // Already existing?
        if _loginVC != nil { return _loginVC }
        
        // Create login view controller
        let loginSB = UIStoryboard(name: "LoginViewController", bundle: nil)
        _loginVC = loginSB.instantiateViewController(withIdentifier: "LoginViewController") as? LoginViewController
        return _loginVC
    }

    func loadLoginView(in window: UIWindow?) {
        guard let window = window else { return }
        
        // Load Login view
        let nav = LoginNavigationController(rootViewController: loginVC)
        nav.setNavigationBarHidden(true, animated: false)
        window.rootViewController = nav

        if #available(iOS 13.0, *) {
            // Transition to login view
            UIView.transition(with: window, duration: 0.5,
                              options: .transitionCrossDissolve,
                              animations: nil) { _ in }
        } else {
            // Next line fixes #259 view not displayed with iOS 8 and 9 on iPad
            window.rootViewController?.view.setNeedsUpdateConstraints()
        }
    }

    @objc func reloginAndRetry(afterRestoringScene: Bool,
                               completion: @escaping () -> Void) {
        let server = NetworkVars.serverPath
        let user = NetworkVars.username
        
        DispatchQueue.main.async {
            if (server.isEmpty == false) && (user.isEmpty == false) {
                self.loginVC.performRelogin(afterRestoringScene: afterRestoringScene) { completion() }
            } else if afterRestoringScene {
                self.loginVC.reloadCatagoryDataInBckgMode(afterRestoringScene: true)
            } else {
                // Return to login view
                ClearCache.closeSessionAndClearCache() { }
            }
        }
    }

    @objc func checkSessionWhenLeavingLowPowerMode() {
        if !ProcessInfo.processInfo.isLowPowerModeEnabled {
            reloginAndRetry(afterRestoringScene: false) { }
        }
    }

    
    // MARK: - Album Navigator
    @objc func loadNavigation(in window: UIWindow?) {
        guard let window = window else { return }
        
        // Display default album
        guard let defaultAlbum = AlbumImagesViewController(albumId: AlbumVars.shared.defaultCategory) else { return }
        window.rootViewController = UINavigationController(rootViewController: defaultAlbum)
        if #available(iOS 13.0, *) {
            UIView.transition(with: window, duration: 0.5,
                              options: .transitionCrossDissolve) { }
                completion: { success in
//                    self._loginVC = nil
                }
        } else {
            // Fallback on earlier versions
            loginVC.removeFromParent()
//            _loginVC = nil
        }
        
        // Observe the UIScreenBrightnessDidChangeNotification
        // When that notification is posted, the method screenBrightnessChanged will be called.
        NotificationCenter.default.addObserver(self, selector: #selector(screenBrightnessChanged),
                                               name: UIScreen.brightnessDidChangeNotification, object: nil)

        // Observe the PiwigoAddRecentAlbumNotification
        NotificationCenter.default.addObserver(self, selector: #selector(addRecentAlbumWithAlbumId),
                                               name: .pwgAddRecentAlbum, object: nil)

        // Observe the PiwigoRemoveRecentAlbumNotification
        NotificationCenter.default.addObserver(self, selector: #selector(removeRecentAlbumWithAlbumId),
                                               name: .pwgRemoveRecentAlbum, object: nil)

        // Observe the Power State notification
        let name = Notification.Name.NSProcessInfoPowerStateDidChange
        NotificationCenter.default.addObserver(self, selector: #selector(checkSessionWhenLeavingLowPowerMode),
                                               name: name, object: nil)

        // Resume upload operations in background queue
        // and update badge, upload button of album navigator
        UploadManager.shared.backgroundQueue.async {
            UploadManager.shared.resumeAll()
        }
    }

    @objc func addRecentAlbumWithAlbumId(_ notification: Notification) {
        // NOP if albumId undefined, root or smart album
        guard let categoryId = notification.userInfo?["categoryId"] as? Int else {
            fatalError("!!! Did not provide a category ID !!!")
        }
        if (categoryId <= 0) || (categoryId == NSNotFound) { return }

        // Get new album Id as string
        let categoryIdStr = String(categoryId)
        
        // Create new array of recent albums
        var newList = [String]()
        
        // Add albumId to top of list
        newList.append(categoryIdStr)

        // Get current list of recent albums
        let recentAlbumsStr = AlbumVars.shared.recentCategories

        // Add recent albums while avoiding duplicates
        if (recentAlbumsStr.count != 0) {
            // List of recent album IDs
            let oldList = recentAlbumsStr.components(separatedBy: ",")
            
            // Append album IDs of old list
            for catId in oldList {
                if newList.contains(catId) { continue }
                newList.append(catId)
            }
        }

        // We will present 3 - 10 albums (5 by default), but because some recent albums
        // may not be suggested or other may be deleted, we store more than 10, say 20.
        let count = newList.count
        if count > 20 {
            AlbumVars.shared.recentCategories = newList.dropLast(count - 20).joined(separator: ",")
        } else {
            AlbumVars.shared.recentCategories = newList.joined(separator: ",")
        }
//        debugPrint("••> Recent albums: \(AlbumVars.shared.recentCategories) (max: \(AlbumVars.shared.maxNberRecentCategories))")
    }

    @objc func removeRecentAlbumWithAlbumId(_ notification: Notification) {
        // NOP if albumId undefined, root or smart album
        guard let categoryId = notification.userInfo?["categoryId"] as? Int else {
            fatalError("!!! Did not provide a category ID !!!")
        }
        if (categoryId <= 0) || (categoryId == NSNotFound) { return }

        // Get current list of recent albums
        let recentAlbumsStr = AlbumVars.shared.recentCategories
        if recentAlbumsStr.isEmpty { return }

        // Get new album Id as string
        let categoryIdStr = String(categoryId)

        // Remove albumId from list if necessary
        var recentCategories = recentAlbumsStr.components(separatedBy: ",")
        recentCategories.removeAll(where: { $0 == categoryIdStr })

        // List should not be empty (add root album Id)
        if recentCategories.isEmpty {
            recentCategories.append(String(0))
        }

        // Update list
        AlbumVars.shared.recentCategories = recentCategories.joined(separator: ",")
//        debugPrint("••> Recent albums: \(AlbumVars.shared.recentCategories)"
    }


    // MARK: - Light and Dark Modes
    private func initColorPalette() {
        // Color palette depends on system settings
        if #available(iOS 12.0, *) {
            AppVars.shared.isSystemDarkModeActive = (UIScreen.main.traitCollection.userInterfaceStyle == .dark)
        } else {
            // Fallback on earlier versions
            AppVars.shared.isSystemDarkModeActive = false
        }
        print("••> iOS mode: \(AppVars.shared.isSystemDarkModeActive ? "Dark" : "Light"), App mode: \(AppVars.shared.isDarkPaletteModeActive ? "Dark" : "Light"), Brightness: \(lroundf(Float(UIScreen.main.brightness) * 100.0))/\(AppVars.shared.switchPaletteThreshold), app: \(AppVars.shared.isDarkPaletteActive ? "Dark" : "Light")")

        // Apply color palette
        screenBrightnessChanged()
    }

    // Called when the screen brightness has changed, when user changes settings
    // and by traitCollectionDidChange() when the system switches between Light and Dark modes
    @objc func screenBrightnessChanged() {
        if AppVars.shared.isLightPaletteModeActive
        {
            if !AppVars.shared.isDarkPaletteActive {
                // Already in light mode
                return;
            } else {
                // "Always Light Mode" selected
                AppVars.shared.isDarkPaletteActive = false
            }
        }
        else if AppVars.shared.isDarkPaletteModeActive
        {
            if AppVars.shared.isDarkPaletteActive {
                // Already showing dark palette
                return;
            } else {
                // "Always Dark Mode" selected or iOS Dark Mode active => Dark palette
                AppVars.shared.isDarkPaletteActive = true
            }
        }
        else if AppVars.shared.switchPaletteAutomatically
        {
            // Dynamic palette mode chosen
            if #available(iOS 13.0, *) {
                if AppVars.shared.isSystemDarkModeActive {
                    // System-wide dark mode active
                    if AppVars.shared.isDarkPaletteActive {
                        // Keep dark palette
                        return;
                    } else {
                        // Switch to dark mode
                        AppVars.shared.isDarkPaletteActive = true
                    }
                } else {
                    // System-wide light mode active
                    if AppVars.shared.isDarkPaletteActive {
                        // Switch to light mode
                        AppVars.shared.isDarkPaletteActive = false
                    } else {
                        // Keep light palette
                        return;
                    }
                }
            }
            else {
                // Option managed by screen brightness
                let currentBrightness = lroundf(Float(UIScreen.main.brightness) * 100.0);
                if AppVars.shared.isDarkPaletteActive {
                    // Dark palette displayed
                    if currentBrightness > AppVars.shared.switchPaletteThreshold
                    {
                        // Screen brightness > thereshold, switch to light palette
                        AppVars.shared.isDarkPaletteActive = false
                    } else {
                        // Keep dark palette
                        return;
                    }
                } else {
                    // Light palette displayed
                    if currentBrightness < AppVars.shared.switchPaletteThreshold
                    {
                        // Screen brightness < threshold, switch to dark palette
                        AppVars.shared.isDarkPaletteActive = true
                    } else {
                        // Keep light palette
                        return;
                    }
                }
            }
        } else {
            // Return to either static Light or Dark mode
            AppVars.shared.isLightPaletteModeActive = !AppVars.shared.isSystemDarkModeActive;
            AppVars.shared.isDarkPaletteModeActive = AppVars.shared.isSystemDarkModeActive;
            AppVars.shared.isDarkPaletteActive = AppVars.shared.isSystemDarkModeActive;
        }
        
        // Tint colour
        UIView.appearance().tintColor = .piwigoColorOrange()
        
        // Activity indicator
        UIActivityIndicatorView.appearance().color = .piwigoColorOrange()

        // Tab bars
        UITabBar.appearance().barTintColor = .piwigoColorBackground()

        // Styles
        if AppVars.shared.isDarkPaletteActive
        {
            UITabBar.appearance().barStyle = .black
            UIToolbar.appearance().barStyle = .black
        }
        else {
            UITabBar.appearance().barStyle = .default
            UIToolbar.appearance().barStyle = .default
        }

        // Notify palette change to views
        NotificationCenter.default.post(name: .pwgPaletteChanged, object: nil)
//        print("••> App changed to \(AppVars.shared.isDarkPaletteActive ? "dark" : "light") mode");
    }

    
    // MARK: - Upload Methods advertised to Obj-C and Old Cache
    
    @objc func resumeAll() {
        UploadManager.shared.backgroundQueue.async {
            UploadManager.shared.resumeAll()
        }
    }
    
    @objc func didDeletePiwigoImage(withID imageId: Int) {
        UploadManager.shared.backgroundQueue.async {
            UploadManager.shared.didDeletePiwigoImage(withID: imageId)
        }
    }
    
    // Add image uploaded to the Piwigo server
    @objc func addImage(_ notification: Notification) {
        // Prepare image for cache
        let imageData = PiwigoImageData()
        imageData.imageId = notification.userInfo?["imageId"] as? Int ?? NSNotFound
        imageData.categoryIds = [(notification.userInfo?["categoryId"] as? Int ?? 0) as NSNumber]

        imageData.imageTitle = notification.userInfo?["imageTitle"] as? String ?? ""
        imageData.author = notification.userInfo?["author"] as? String ?? ""
        imageData.privacyLevel = kPiwigoPrivacyObjc(rawValue: notification.userInfo?["privacyLevel"] as? Int32 ?? Int32(kPiwigoPrivacy.unknown.rawValue))
        imageData.comment = notification.userInfo?["comment"] as? String ?? ""
        imageData.visits = notification.userInfo?["visits"] as? Int ?? 0
        imageData.ratingScore = notification.userInfo?["ratingScore"] as? Float ?? 0.0

        // Switch to old cache data format
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        var tagList = [PiwigoTagData]()
        let tags = notification.userInfo?["tags"] as? [TagProperties] ?? []
        tags.forEach { (tag) in
            let newTag = PiwigoTagData()
            newTag.tagId = Int(tag.id!)
            newTag.tagName = tag.name
            newTag.lastModified = dateFormatter.date(from: tag.lastmodified ?? "")
            newTag.numberOfImagesUnderTag = tag.counter ?? 0
            tagList.append(newTag)
        }
        imageData.tags = tagList

        imageData.fileName = notification.userInfo?["fileName"] as? String ?? "image.jpg"
        imageData.fileSize = notification.userInfo?["fileSize"] as? Int ?? NSNotFound    // Will trigger pwg.images.getInfo
        imageData.isVideo = notification.userInfo?["isVideo"] as? Bool ?? false
        imageData.datePosted = notification.userInfo?["datePosted"] as? Date ?? Date()
        imageData.dateCreated = notification.userInfo?["dateCreated"] as? Date ?? Date()
        imageData.md5checksum = notification.userInfo?["md5checksum"] as? String ?? ""

        imageData.fullResPath = notification.userInfo?["fullResPath"] as? String ?? ""
        imageData.fullResWidth = notification.userInfo?["fullResWidth"] as? Int ?? 1
        imageData.fullResHeight = notification.userInfo?["fullResHeight"] as? Int ?? 1
        imageData.squarePath = notification.userInfo?["squarePath"] as? String ?? ""
        imageData.squareWidth = notification.userInfo?["squareWidth"] as? Int ?? 1
        imageData.squareHeight = notification.userInfo?["squareHeight"] as? Int ?? 1
        imageData.thumbPath = notification.userInfo?["thumbPath"] as? String ?? ""
        imageData.thumbWidth = notification.userInfo?["thumbWidth"] as? Int ?? 1
        imageData.thumbHeight = notification.userInfo?["thumbHeight"] as? Int ?? 1
        imageData.mediumPath = notification.userInfo?["mediumPath"] as? String ?? ""
        imageData.mediumWidth = notification.userInfo?["mediumWidth"] as? Int ?? 1
        imageData.mediumHeight = notification.userInfo?["mediumHeight"] as? Int ?? 1
        imageData.xxSmallPath = notification.userInfo?["xxSmallPath"] as? String ?? ""
        imageData.xxSmallWidth = notification.userInfo?["xxSmallWidth"] as? Int ?? 1
        imageData.xxSmallHeight = notification.userInfo?["xxSmallHeight"] as? Int ?? 1
        imageData.xSmallPath = notification.userInfo?["xSmallPath"] as? String ?? ""
        imageData.xSmallWidth = notification.userInfo?["xSmallWidth"] as? Int ?? 1
        imageData.xSmallHeight = notification.userInfo?["xSmallHeight"] as? Int ?? 1
        imageData.smallPath = notification.userInfo?["smallPath"] as? String ?? ""
        imageData.smallWidth = notification.userInfo?["smallWidth"] as? Int ?? 1
        imageData.smallHeight = notification.userInfo?["smallHeight"] as? Int ?? 1
        imageData.largePath = notification.userInfo?["largePath"] as? String ?? ""
        imageData.largeWidth = notification.userInfo?["largeWidth"] as? Int ?? 1
        imageData.largeHeight = notification.userInfo?["largeHeight"] as? Int ?? 1
        imageData.xLargePath = notification.userInfo?["xLargePath"] as? String ?? ""
        imageData.xLargeWidth = notification.userInfo?["xLargeWidth"] as? Int ?? 1
        imageData.xLargeHeight = notification.userInfo?["xLargeHeight"] as? Int ?? 1
        imageData.xxLargePath = notification.userInfo?["xxLargePath"] as? String ?? ""
        imageData.xxLargeWidth = notification.userInfo?["xxLargeWidth"] as? Int ?? 1
        imageData.xxLargeHeight = notification.userInfo?["xxLargeHeight"] as? Int ?? 1

        // Add uploaded image to cache and update UI if needed
        CategoriesData.sharedInstance()?.addImage(imageData)
    }
}


// MARK: - AppLockDelegate Methods
extension AppDelegate: AppLockDelegate {
    func loginOrReloginAndResumeUploads() {
        print("••> loginOrReloginAndResumeUploads() in AppDelegate.")
        // Release memory
        privacyView?.removeFromSuperview()

        // Piwigo Mobile will play audio even if the Silent switch set to silent or when the screen locks.
        // Furthermore, it will interrupt any other current audio sessions (no mixing)
        let audioSession = AVAudioSession.sharedInstance()
        let availableCategories = audioSession.availableCategories
        if availableCategories.contains(AVAudioSession.Category.playback) {
            do {
                try audioSession.setCategory(.playback)
            } catch {
            }
        }

        // Should we log in?
        if let rootVC = self.window?.rootViewController,
            let child = rootVC.children.first, child is LoginViewController {
            // Look for credentials if server address provided
            let username = NetworkVars.username
            let service = NetworkVars.serverPath
            var password = ""

            // Look for paswword in Keychain if server address and username are provided
            if service.count > 0, username.count > 0 {
                password = KeychainUtilities.password(forService: service, account: username)
            }

            // Login?
            if service.count > 0 || (username.count > 0 && password.count > 0) {
                loginVC.launchLogin()
            }
            return
        }

        // Determine for how long the session is opened
        /// Piwigo 11 session duration defaults to an hour.
        if let rootVC = window?.rootViewController, let child = rootVC.children.first,
           !(child is LoginViewController) {
            // Determine for how long the session is opened
            /// Piwigo 11 session duration defaults to an hour.
            let timeSinceLastLogin = NetworkVars.dateOfLastLogin.timeIntervalSinceNow
            if timeSinceLastLogin < TimeInterval(-300) {    // i.e. 5 minutes
                /// - Perform relogin
                /// - Resume upload operations in background queue
                ///   and update badge, upload button of album navigator
                NetworkVars.dateOfLastLogin = Date()
                reloginAndRetry(afterRestoringScene: false) {
                    // Reload category data from server in background mode
                    self.loginVC.reloadCatagoryDataInBckgMode(afterRestoringScene: false)
                }
            } else {
                /// - Resume upload operations in background queue
                ///   and update badge, upload button of album navigator
                UploadManager.shared.backgroundQueue.async {
                    UploadManager.shared.resumeAll()
                }
            }
        }
    }
}
