//
//  AppDelegate.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 20/06/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import AVFoundation
import CoreData
import CoreHaptics
import Foundation
import Intents
import LocalAuthentication
import UIKit

#if canImport(BackgroundTasks)
import BackgroundTasks        // Requires iOS 13
#endif

import piwigoKit
import uploadKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
        
    private let k1WeekInDays: TimeInterval  = 60 * 60 * 24 *  7.0
    private let k2WeeksInDays: TimeInterval = 60 * 60 * 24 * 14.0
    private let k3WeeksInDays: TimeInterval = 60 * 60 * 24 * 21.0
    private let pwgBackgroundTaskUpload = "org.piwigo.uploadManager"

    var window: UIWindow?
    var privacyView: UIView?
    var isAuthenticatingWithBiometrics = false
    var didCancelBiometricsAuthentication = false

    // MARK: - Core Data Object Contexts
    private lazy var mainContext: NSManagedObjectContext = {
        return DataController.shared.mainContext
    }()
    

    // MARK: - App Initialisation
    func application(_ application: UIApplication, didFinishLaunchingWithOptions
                        launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Register notifications for displaying number of uploads to perform in app badge
        UNUserNotificationCenter.current().requestAuthorization(options: .badge) { granted, Error in
//                if granted { print("request succeeded!") }
        }

        // Color palette depends on system settings
        initColorPalette()

        // Check if the device supports haptics.
        if #available(iOS 13.0, *) {
            let hapticCapability = CHHapticEngine.capabilitiesForHardware()
            AppVars.shared.supportsHaptics = hapticCapability.supportsHaptics
        }
        
        // Set Settings Bundle data
        setSettingsBundleData()
        
        // In absence of passcode, albums are always accessible
        if AppVars.shared.appLockKey.isEmpty {
            AppVars.shared.isAppLockActive = false
            AppVars.shared.isAppUnlocked = true
        }

        // Register transformers at the very beginning
        ValueTransformer.setValueTransformer(DescriptionValueTransformer(), forName: .descriptionToDataTransformer)
        ValueTransformer.setValueTransformer(RelativeURLValueTransformer(), forName: .relativeUrlToDataTransformer)
        ValueTransformer.setValueTransformer(ResolutionValueTransformer(), forName: .resolutionToDataTransformer)

        // Register launch handlers for tasks if using iOS 13+
        /// Will have to check if pwg.images.uploadAsync is available
        if #available(iOS 13.0, *) {
            registerBgTasks()
        }

        // What follows depends on iOS version
        if #available(iOS 13.0, *) {
            // Delegate to SceneDelegate
            /// - Present login view and if needed passcode view
            /// - or album view behind passcode view if needed
        } else {
            // Create window
            window = UIWindow(frame: UIScreen.main.bounds)

            // Check if a migration is necessary
            let migrator = DataMigrator()
            if migrator.requiresMigration() {
                // Tell user to wait until migration is completed
                loadMigrationView(in: window)

                // Perform migration in background thread to prevent triggering watchdog after 10 s
                DispatchQueue(label: "com.piwigo.migrator", qos: .userInitiated).async { [self] in
                    // Perform migration
                    migrator.migrateStore()

                    // Present views
                    DispatchQueue.main.async { [self] in
                        // Create login view
                        loadLoginView(in: window)
                        addPrivacyProtectionIfNeeded()
                    }
                }
            } else {
                // Create login view
                loadLoginView(in: window)
                addPrivacyProtectionIfNeeded()
            }
        }

        // Display view
        window?.makeKeyAndVisible()

        // Register left upload requests notifications updating the badge
        NotificationCenter.default.addObserver(self, selector: #selector(updateBadge),
                                               name: Notification.Name.pwgLeftUploads, object: nil)
        
        // Register auto-upload appender failures
        NotificationCenter.default.addObserver(self, selector: #selector(displayAutoUploadErrorAndResume),
                                               name: Notification.Name.pwgAppendAutoUploadRequestsFailed, object: nil)
        return true
    }

    private func addPrivacyProtectionIfNeeded() {
        // Blur view if the App Lock is enabled
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
    

    // MARK: - Scene Configuration
    @available(iOS 13.0, *)
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {

        // Check connection options for user activities and attempt to generate an ActivityType
        var currentActivity: ActivityType?
        options.userActivities.forEach {
            currentActivity = ActivityType(rawValue: $0.activityType)
        }

        // Default acitivty depends if user connected an external display
        var activity: ActivityType!
        if #available(iOS 16.0, *) {
            switch connectingSceneSession.role {
            case .windowApplication:                    /* Main display     */
                // User activity defaults to displaying albums
                activity = currentActivity ?? ActivityType.album

            case .windowExternalDisplayNonInteractive:  /* External display */
                // User activity defaults to displaying albums
                activity = currentActivity ?? ActivityType.external

            default:
                debugPrint("••> Un-managed scene session role!")
                activity = currentActivity ?? ActivityType.album
            }
        } else {
            // Fallback on earlier versions
            switch connectingSceneSession.role {
            case .windowApplication:                    /* Main display     */
                // User activity defaults to displaying albums
                activity = currentActivity ?? ActivityType.album

            case .windowExternalDisplay:                /* External display */
                // User activity defaults to displaying albums
                activity = currentActivity ?? ActivityType.external

            default:
                debugPrint("••> Un-managed scene session role!")
                activity = currentActivity ?? ActivityType.album
            }
        }
        
        return activity.sceneConfiguration()
    }

    @available(iOS 13.0, *)
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the system, due to a user interaction or a request from the application itself, removes one or more representation from the -[UIApplication openSessions] set
        // If sessions are discarded while the application is not running, this method is called shortly after the applications next launch.
        sceneSessions.forEach { sceneSession in
            let wantedRole: UISceneSession.Role!
            if #available(iOS 16.0, *) {
                wantedRole = .windowExternalDisplayNonInteractive
            } else {
                // Fallback on earlier versions
                wantedRole = .windowExternalDisplay
            }
            if sceneSession.role == wantedRole,
                let delegate = sceneSession.scene?.delegate as? ExternalDisplaySceneDelegate {
                 delegate.tearDownWindow(for: sceneSession.persistentIdentifier)
            }
        }
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
        
        // Save cached data in the main thread
        mainContext.saveIfNeeded()

        // Clean up /tmp directory
        cleanUpTemporaryDirectory(immediately: false)
    }
        
    func applicationWillTerminate(_ application: UIApplication) {
        print("••> App will terminate.")
        // Called when the application is about to terminate.
        // Save data if appropriate. See also applicationDidEnterBackground:.
        
        // Save cached data in the main thread
        mainContext.saveIfNeeded()

        // Cancel tasks and close session
        PwgSession.shared.dataSession.invalidateAndCancel()

        // Clean up /tmp directory
        cleanUpTemporaryDirectory(immediately: false)

        // Unregister all observers
        NotificationCenter.default.removeObserver(self)

        if #available(iOS 13.0, *) {
            // NOP
        } else {
            // Unregister brightnessDidChangeNotification
            NotificationCenter.default.removeObserver(self, name: UIScreen.brightnessDidChangeNotification, object: nil)
        }
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
        BGTaskScheduler.shared.register(forTaskWithIdentifier: pwgBackgroundTaskUpload, using: nil) { task in
             self.handleNextUpload(task: task as! BGProcessingTask)
        }
    }

    @available(iOS 13.0, *)
    func scheduleNextUpload() {
        // Schedule upload not earlier than 1 minute from now
        // Uploading requires network connectivity and external power
        let request = BGProcessingTaskRequest.init(identifier: pwgBackgroundTaskUpload)
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
            // Save cached data in the main thread
            DispatchQueue.main.async {
                self.mainContext.saveIfNeeded()
            }
        }

        // Start the operation
        print("    > Start upload operations in background task...");
        uploadQueue.addOperations(uploadOperations, waitUntilFinished: false)
    }

    @objc func updateBadge(_ notification: Notification) {
        guard let nberOfUploadsToComplete = notification.userInfo?["nberOfUploadsToComplete"] as? Int else {
            preconditionFailure("!!! Did not provide an integer !!!")
        }
        if #available(iOS 16, *) {
            UNUserNotificationCenter.current().setBadgeCount(nberOfUploadsToComplete)
        } else {
            UIApplication.shared.applicationIconBadgeNumber = nberOfUploadsToComplete
        }
        // Re-enable sleep mode if uploads are completed
        if nberOfUploadsToComplete == 0 {
            UIApplication.shared.isIdleTimerDisabled = false
        }
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
        DispatchQueue.global(qos: .background).async { [self] in
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
//        switch intent {
//        case is AutoUploadIntent:
//            let handler = AutoUploadIntentHandler()
//            handler.handle(intent: intent as! AutoUploadIntent) { response in
//                completionHandler(response)
//            }
//        default:
//            break
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
        context.localizedReason = NSLocalizedString("settings_appLockEnter", comment: "Enter Passcode")

        // First check if we have the needed hardware support
        var error: NSError?
        let policy = LAPolicy.deviceOwnerAuthenticationWithBiometrics
        if context.canEvaluatePolicy(policy, error: &error) {
            // Exploit TouchID or FaceID
            self.isAuthenticatingWithBiometrics = true
            let reason = NSLocalizedString("settings_biometricsReason", comment: "Access your Piwigo albums")
            context.evaluatePolicy(policy, localizedReason: reason ) { success, error in
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


    // MARK: - Data Migration View
    private var _migrationVC: DataMigrationViewController!
    var migrationVC: DataMigrationViewController {
        // Already existing?
        if _migrationVC != nil { return _migrationVC }
        
        // Create data migration view
        let migrationSB = UIStoryboard(name: "DataMigrationViewController", bundle: nil)
        guard let migrationVC = migrationSB.instantiateViewController(withIdentifier: "DataMigrationViewController") as? DataMigrationViewController else {
            fatalError("!!! No DataMigrationViewController !!!")
        }
        _migrationVC = migrationVC
        return _migrationVC
    }
    
    func loadMigrationView(in window: UIWindow?) {
        guard let window = window else { return }
        
        // Load Login view
        let nav = LoginNavigationController(rootViewController: migrationVC)
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

    
    // MARK: - Login View
    private var _loginVC: LoginViewController!
    var loginVC: LoginViewController {
        // Already existing?
        if _loginVC != nil { return _loginVC }
        
        // Create login view controller
        let loginSB = UIStoryboard(name: "LoginViewController", bundle: nil)
        guard let loginVC = loginSB.instantiateViewController(withIdentifier: "LoginViewController") as? LoginViewController else {
            fatalError("!!! No LoginViewController !!!")
        }
        _loginVC = loginVC
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
                              animations: nil) { [self] success in
                if success {
                    self._migrationVC = nil
                }
            }
        } else {
            // Fallback on earlier versions
            _migrationVC?.removeFromParent()
            _migrationVC = nil
        }
    }

    @objc func checkSessionWhenLeavingLowPowerMode() {
        if !ProcessInfo.processInfo.isLowPowerModeEnabled {
            UploadManager.shared.backgroundQueue.async {
                UploadManager.shared.resumeAll()
            }
        }
    }

    
    // MARK: - Album Navigator
    func loadNavigation(in window: UIWindow?) {
        guard let window = window else { return }
        
        // Display default album
        let albumSB = UIStoryboard(name: "AlbumViewController", bundle: nil)
        guard let albumVC = albumSB.instantiateViewController(withIdentifier: "AlbumViewController") as? AlbumViewController
        else { preconditionFailure("Could not load AlbumViewController") }
        albumVC.categoryId = AlbumVars.shared.defaultCategory
        window.rootViewController = AlbumNavigationController(rootViewController: albumVC)
        if #available(iOS 13.0, *) {
            UIView.transition(with: window, duration: 0.5,
                              options: .transitionCrossDissolve) { }
                completion: { [self] success in
                    if success {
                        self._loginVC = nil
                    }
                }
        } else {
            // Fallback on earlier versions
            _loginVC?.removeFromParent()
            _loginVC = nil

            // Resume upload operations in background queue
            // and update badge, upload button of album navigator
            UploadManager.shared.backgroundQueue.async {
                UploadManager.shared.resumeAll()
            }
            
            // Observe the UIScreenBrightnessDidChangeNotification
            NotificationCenter.default.addObserver(self, selector: #selector(screenBrightnessChanged),
                                                   name: UIScreen.brightnessDidChangeNotification, object: nil)
        }

        // Observe the PiwigoAddRecentAlbumNotification
        NotificationCenter.default.addObserver(self, selector: #selector(addRecentAlbumWithAlbumId),
                                               name: Notification.Name.pwgAddRecentAlbum, object: nil)

        // Observe the PiwigoRemoveRecentAlbumNotification
        NotificationCenter.default.addObserver(self, selector: #selector(removeRecentAlbumWithAlbumId),
                                               name: Notification.Name.pwgRemoveRecentAlbum, object: nil)

        // Observe the Power State notification
        let name = Notification.Name.NSProcessInfoPowerStateDidChange
        NotificationCenter.default.addObserver(self, selector: #selector(checkSessionWhenLeavingLowPowerMode),
                                               name: name, object: nil)
    }

    @objc func addRecentAlbumWithAlbumId(_ notification: Notification) {
        // NOP if albumId undefined, root or smart album
        guard let categoryId = notification.userInfo?["categoryId"] as? Int32 else {
            fatalError("!!! Did not provide a category ID !!!")
        }
        if (categoryId <= 0) || (categoryId == Int32.min) { return }

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
        if (categoryId <= 0) || (categoryId == Int32.min) { return }

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
        AppVars.shared.isSystemDarkModeActive = (UIScreen.main.traitCollection.userInterfaceStyle == .dark)
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
                // Already in light mode but make sure that images stays in appropriate mode
                NotificationCenter.default.post(name: .pwgPaletteChanged, object: nil)
                return;
            } else {
                // "Always Light Mode" selected
                AppVars.shared.isDarkPaletteActive = false
            }
        }
        else if AppVars.shared.isDarkPaletteModeActive
        {
            if AppVars.shared.isDarkPaletteActive {
                // Already showing dark palette but make sure that images stays in appropriate mode
                NotificationCenter.default.post(name: .pwgPaletteChanged, object: nil)
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
                        // Keep dark palette but make sure that images stays in appropriate mode
                        NotificationCenter.default.post(name: .pwgPaletteChanged, object: nil)
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
                        // Keep light palette but make sure that images stays in appropriate mode
                        NotificationCenter.default.post(name: .pwgPaletteChanged, object: nil)
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
}


// MARK: - AppLockDelegate Methods
extension AppDelegate: AppLockDelegate {
    func loginOrReloginAndResumeUploads() {
        // Release memory
        privacyView?.removeFromSuperview()

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
                print("••> Call launchLogin() from AppDelegate.")
                loginVC.launchLogin()
            }
            return
        }
    }
}
