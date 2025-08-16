//
//  AppDelegate.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 20/06/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import AVFoundation
import BackgroundTasks
import CoreData
import CoreHaptics
import Foundation
import Intents
import LocalAuthentication
import UIKit

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
    var networkMonitor: NetworkMonitor?

    // MARK: - Core Data Object Contexts
    private lazy var mainContext: NSManagedObjectContext = {
        return DataController.shared.mainContext
    }()
    

    // MARK: - App Initialisation
    func application(_ application: UIApplication, didFinishLaunchingWithOptions
                        launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Register notifications for displaying number of uploads to perform in app badge
        UNUserNotificationCenter.current().requestAuthorization(options: .badge) { granted, Error in
//                if granted { debugPrint("request succeeded!") }
        }

        // Remember the natural scale associated with the integrated screen for future initialisations
        AppVars.shared.currentDeviceScale = UIScreen.main.scale
        
        // Color palette depends on system settings
        initColorPalette()
        
        // Check if the device supports haptics.
        let hapticCapability = CHHapticEngine.capabilitiesForHardware()
        AppVars.shared.supportsHaptics = hapticCapability.supportsHaptics
        
        // "0 day" option added in v3.1.2 for allowing user to disable "recent" icon
        CacheVars.shared.correctRecentPeriodIndex()

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

        // If a migration is planned:
        // - disable Core Data usage
        // - postpone background tasks
        // until the migration is done.
        let migrator = DataMigrator()
        AppVars.shared.isMigrationRunning = migrator.requiresMigration()
        
        // Register launch handlers for tasks
        /// All launch handlers must be registered before application finishes launching.
        /// Will have to check if pwg.images.uploadAsync is available
        registerBgTasks()

        // Register network connection changes
        Task { @MainActor in
            // Start network monitoring
            self.networkMonitor = await NetworkMonitor()
        }

        // Register left upload requests notifications updating the badge
        NotificationCenter.default.addObserver(self, selector: #selector(updateBadge),
                                               name: Notification.Name.pwgLeftUploads, object: nil)
        
        // Register auto-upload appender failures
        NotificationCenter.default.addObserver(self, selector: #selector(displayAutoUploadErrorAndResume),
                                               name: Notification.Name.pwgAppendAutoUploadRequestsFailed, object: nil)
        return true
    }

    func addPrivacyProtectionIfNeeded() {
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
        debugPrint("Did fail to register notifications.")
    }
    

    // MARK: - Transitioning to the Background
    func applicationWillTerminate(_ application: UIApplication) {
        debugPrint("••> App will terminate.")
        // Called when the application is about to terminate.
        // Save data if appropriate. See also applicationDidEnterBackground:.
        
        // Should we save changes in cache?
        if AppVars.shared.isMigrationRunning == false {
            // Save cached data in the main thread
            mainContext.saveIfNeeded()
        }

        // Cancel tasks and close session
        PwgSession.shared.dataSession.invalidateAndCancel()

        // Unregister network connection changes
        Task { @MainActor in
            // Stop network monitoring
            await self.networkMonitor?.stopMonitoring()
        }

        // Clean up /tmp directory
        cleanUpTemporaryDirectory(immediately: false)

        // Unregister all observers
        NotificationCenter.default.removeObserver(self)
    }
    

    // MARK: - Background Task | Uploads
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession
                        identifier: String, completionHandler: @escaping () -> Void) {
        debugPrint("    > Handle events for background session with ID: \(identifier)");
        
        // Upload session of the app?
        if identifier.compare(UploadSessions.shared.uploadBckgSessionIdentifier) == .orderedSame {
            UploadSessions.shared.uploadSessionCompletionHandler = completionHandler
            debugPrint("••> Rejoining session with CompletionHandler.")
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

    private func registerBgTasks() {
        // Register background upload task
        BGTaskScheduler.shared.register(forTaskWithIdentifier: pwgBackgroundTaskUpload, using: nil) { task in
             self.handleNextUpload(task: task as! BGProcessingTask)
        }
    }

    func scheduleNextUpload() {
        // Schedule upload not earlier than 15 minute from now
        // Uploading requires network connectivity and external power
        let request = BGProcessingTaskRequest.init(identifier: pwgBackgroundTaskUpload)
        request.earliestBeginDate = Date.init(timeIntervalSinceNow: 15 * 60)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = true
        
        // Submit upload request
        do {
            try BGTaskScheduler.shared.submit(request)
            debugPrint("••> Background upload task request submitted with success.")
        } catch {
            debugPrint("••> Failed to submit background upload request: \(error)")
        }
    }

    private func handleNextUpload(task: BGProcessingTask) {
        // Schedule the next uploads if needed
        if UploadVars.shared.nberOfUploadsToComplete > 0 {
            debugPrint("    > Schedule next uploads.")
            scheduleNextUpload()
        }

        // Don't upload images now if a migration is planned
        if AppVars.shared.isMigrationRunning {
            debugPrint("    > Background upload task rescheduled because a migration is ongoing.")
            task.setTaskCompleted(success: true)
            return
        }
        
        // iOS may launch the task when the app is active (since iOS 18)
        if AppVars.shared.applicationIsActive {
            debugPrint("    > Background upload task halted because the app is active.")
            task.setTaskCompleted(success: true)
            return
        }

        // Create the operation queue
        let uploadQueue = OperationQueue()
        uploadQueue.maxConcurrentOperationCount = 1
        
        // Add operation setting flag and selecting upload requests
        let initOperation = BlockOperation {
            // Start network monitoring
            Task {
                await self.networkMonitor?.startMonitoring()
            }

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
        for _ in 0..<UploadVars.shared.maxNberOfUploadsPerBckgTask {
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
            debugPrint("    > Task expired: Upload operation cancelled.")
            // Cancel operations
            uploadQueue.cancelAllOperations()
            // Stop network monitoring
            Task {
                await self.networkMonitor?.stopMonitoring()
            }
        }
        
        // Inform the system that the background task is complete
        // when the operation completes
        let lastOperation = uploadOperations.last!
        lastOperation.completionBlock = {
            debugPrint("••> Task completed with success.")
            task.setTaskCompleted(success: true)
            // Stop network monitoring
            Task {
                await self.networkMonitor?.stopMonitoring()
            }
            // Save cached data in the main thread
            DispatchQueue.main.async {
                self.mainContext.saveIfNeeded()
            }
        }

        // Start the operation
        debugPrint("••> Start upload operations in background task...");
        uploadQueue.addOperations(uploadOperations, waitUntilFinished: false)
    }

    @objc func updateBadge(_ notification: Notification) {
        // Verify user info
        guard let nberOfUploads = notification.userInfo?["nberOfUploadsToComplete"] as? Int
        else { preconditionFailure("!!! Expected an integer !!!") }
        
        // Store number of upload requests for next app launch
        UploadVars.shared.nberOfUploadsToComplete = nberOfUploads
        
        // Update the badge of the app
        if #available(iOS 16, *) {
            UNUserNotificationCenter.current().setBadgeCount(nberOfUploads)
        } else {
            UIApplication.shared.applicationIconBadgeNumber = nberOfUploads
        }
        
        // Always re-enable sleep mode if uploads are completed
        if nberOfUploads == 0 {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    @objc func displayAutoUploadErrorAndResume(_ notification: Notification) {
        // Retrieve message and error
        guard let message = notification.userInfo?["message"] as? String else { return }
        let errorMsg = notification.userInfo?["errorMsg"] as? String

        // Display error message and resume Upload Manager operation
        let title = NSLocalizedString("settings_autoUpload", comment: "Auto Upload")
        let keyWindows = UIApplication.shared.connectedScenes
            .filter({$0.session.role == .windowApplication})
            .filter({$0.activationState == .foregroundActive})
            .map({$0 as? UIWindowScene})
            .compactMap({$0})
            .first?.windows
            .filter({$0.isKeyWindow})
        if let keyWindow = keyWindows?.first,
           let topViewController = keyWindow.windowScene?.rootViewController(),
           topViewController is UINavigationController,
           let visibleVC = (topViewController as! UINavigationController).visibleViewController {
            // Inform user
            visibleVC.dismissPiwigoError(withTitle: title, message: message, errorMessage: errorMsg ?? "") {
                // Restart UploadManager activities
                UploadManager.shared.isPaused = false
                UploadManager.shared.backgroundQueue.async {
                    UploadManager.shared.findNextImageToUpload()
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
                debugPrint("Could not clean up the temporary directory")
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
    func loadMigrationView(in window: UIWindow?, startMigrationWith migrator: DataMigrator? = nil) {
        guard let window = window
        else { preconditionFailure("!!! No UIWindow !!!") }
        
        // Create data migration view
        let migrationSB = UIStoryboard(name: "DataMigrationViewController", bundle: nil)
        guard let migrationVC = migrationSB.instantiateViewController(withIdentifier: "DataMigrationViewController") as? DataMigrationViewController
        else { preconditionFailure("!!! No DataMigrationViewController !!!") }
        migrationVC.migrator = migrator
        
        // Show migration view in provided window
        let nav = UINavigationController(rootViewController: migrationVC)
        nav.setNavigationBarHidden(true, animated: false)
        window.rootViewController = nav

        // Transition to migration view
        UIView.transition(with: window, duration: 0.5,
                          options: .transitionCrossDissolve,
                          animations: nil) { _ in }
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

        // Transition to login view
        UIView.transition(with: window, duration: 0.5,
                          options: .transitionCrossDissolve,
                          animations: nil) { _ in }
    }

    @objc func checkSessionWhenLeavingLowPowerMode() {
        if !ProcessInfo.processInfo.isLowPowerModeEnabled {
            UploadManager.shared.backgroundQueue.async {
                UploadManager.shared.resumeAll()
            }
        }
    }

    
    // MARK: - Album Navigator
    func loadNavigation(in window: UIWindow?, keepLoginView: Bool = false) {
        guard let window = window else { return }
        
        // Display default album
        let albumSB = UIStoryboard(name: "AlbumViewController", bundle: nil)
        guard let albumVC = albumSB.instantiateViewController(withIdentifier: "AlbumViewController") as? AlbumViewController
        else { preconditionFailure("Could not load AlbumViewController") }
        albumVC.categoryId = AlbumVars.shared.defaultCategory
        window.rootViewController = AlbumNavigationController(rootViewController: albumVC)
        UIView.transition(with: window, duration: 0.5,
                          options: .transitionCrossDissolve) { }
            completion: { [self] success in
                if success, keepLoginView == false {
                    self._loginVC = nil
                }
            }

        // Resume upload operations in background queue
        // and update badge, upload button of album navigator
        UploadManager.shared.backgroundQueue.async {
            UploadManager.shared.resumeAll()
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
            preconditionFailure("!!! Did not provide a category ID !!!")
        }
        if (categoryId <= 0) || (categoryId == Int32.min) { return }

        // Get album ID to add as string
        let categoryIdStr = String(categoryId)

        // Get current list of recent albums
        var recentAlbumsStr = AlbumVars.shared.recentCategories.components(separatedBy: ",").compactMap({$0})
        
        // Add or put back album ID to beginning of list
        if recentAlbumsStr.contains(categoryIdStr) {
            recentAlbumsStr.removeAll { $0 == categoryIdStr }
        }
        recentAlbumsStr.insert(categoryIdStr, at: 0)

        // We will present 3 - 10 albums (5 by default), but because some recent albums
        // may not be suggested or other may be deleted, we store more than 10, say 20.
        let nberExtraCats: Int = max(0, recentAlbumsStr.count - 20)
        AlbumVars.shared.recentCategories = recentAlbumsStr.dropLast(nberExtraCats).joined(separator: ",")
        debugPrint("••> Added album \(categoryId); Recent albums: \(AlbumVars.shared.recentCategories) (max: \(AlbumVars.shared.maxNberRecentCategories))")
    }

    @objc func removeRecentAlbumWithAlbumId(_ notification: Notification) {
        // NOP if albumId undefined, root or smart album
        guard let categoryId = notification.userInfo?["categoryId"] as? Int else {
            preconditionFailure("!!! Did not provide a category ID !!!")
        }
        if (categoryId <= 0) || (categoryId == Int32.min) { return }

        // Get album ID to remove as string
        let categoryIdStr = String(categoryId)

        // Get current list of recent albums
        var recentAlbumsStr = AlbumVars.shared.recentCategories.components(separatedBy: ",").compactMap({$0})

        // Remove album ID from list if necessary
        if recentAlbumsStr.contains(categoryIdStr) {
            recentAlbumsStr.removeAll { $0 == categoryIdStr }
        }

        // List should not be empty (add root album ID)
        if recentAlbumsStr.isEmpty {
            recentAlbumsStr.append(String(0))
        }

        // Update list
        AlbumVars.shared.recentCategories = recentAlbumsStr.joined(separator: ",")
        debugPrint("••> Removed album \(categoryIdStr); Recent albums: \(AlbumVars.shared.recentCategories) (max: \(AlbumVars.shared.maxNberRecentCategories))")
    }


    // MARK: - Light and Dark Modes
    private func initColorPalette() {
        // Color palette depends on system settings
        AppVars.shared.isSystemDarkModeActive = (UIScreen.main.traitCollection.userInterfaceStyle == .dark)
        debugPrint("••> iOS mode: \(AppVars.shared.isSystemDarkModeActive ? "Dark" : "Light"), App mode: \(AppVars.shared.isDarkPaletteModeActive ? "Dark" : "Light"), Brightness: \(lroundf(Float(UIScreen.main.brightness) * 100.0))/\(AppVars.shared.switchPaletteThreshold), app: \(AppVars.shared.isDarkPaletteActive ? "Dark" : "Light")")

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
        } else {
            // Return to either static Light or Dark mode
            AppVars.shared.isLightPaletteModeActive = !AppVars.shared.isSystemDarkModeActive;
            AppVars.shared.isDarkPaletteModeActive = AppVars.shared.isSystemDarkModeActive;
            AppVars.shared.isDarkPaletteActive = AppVars.shared.isSystemDarkModeActive;
        }
        
        // Tint colour
        UIView.appearance().tintColor = PwgColor.orange
        
        // Activity indicator
        UIActivityIndicatorView.appearance().color = PwgColor.orange

        // Tab bars
        UITabBar.appearance().barTintColor = PwgColor.background

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
//        debugPrint("••> App changed to \(AppVars.shared.isDarkPaletteActive ? "dark" : "light") mode");
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
            let username = NetworkVars.shared.username
            let service = NetworkVars.shared.serverPath
            var password = ""

            // Look for paswword in Keychain if server address and username are provided
            if service.count > 0, username.count > 0 {
                password = KeychainUtilities.password(forService: service, account: username)
            }

            // Login?
            if service.count > 0 || (username.count > 0 && password.count > 0) {
                debugPrint("••> Call launchLogin() from AppDelegate.")
                loginVC.launchLogin()
            }
            return
        }
    }
}
