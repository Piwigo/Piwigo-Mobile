//
//  AppDelegate.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 20/06/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import AVFoundation
import BackgroundTasks
import Foundation
import UIKit

import IQKeyboardManagerSwift
import piwigoKit

@main
@objc class AppDelegate: UIResponder, UIApplicationDelegate {
        
    let kPiwigoBackgroundTaskUpload = "kPiwigoBackgroundTaskUpload"

    var window: UIWindow?
    
    private var _loginVC: LoginViewController!
    var loginVC: LoginViewController {
        // Already existing?
        if _loginVC != nil { return _loginVC }
        
        // Create login view controller for current device
        if UIDevice.current.userInterfaceIdiom == .phone {
            _loginVC = LoginViewController_iPhone()
        } else {
            _loginVC = LoginViewController_iPad()
        }
        return _loginVC
    }


    // MARK: - Application delegate methods
    func application(_ application: UIApplication, didFinishLaunchingWithOptions
                        launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
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

        // Set Settings Bundle data
        setSettingsBundleData()
        
        // Register launch handlers for tasks if using iOS 13
        // Will have to check if pwg.images.uploadAsync is available
        if #available(iOS 13.0, *) {
            registerBgTasks()
        }

        if #available(iOS 13.0, *) {
            // Delegate to SceneDelegate
            /// - Present login view
        } else {
            // Complete user interface initialization, login ?
            let username = NetworkVars.shared.username
            let service = NetworkVars.shared.serverPath
            var password = ""

            // Look for paswword in Keychain if server address and username are provided
            if service.count > 0, username.count > 0 {
                password = KeychainUtilities.password(forService: service, account: username)
            }

            // Show login view
            window = UIWindow(frame: UIScreen.main.bounds)
            window?.makeKeyAndVisible()
            loadLoginView()
            
            // Login?
            if service.count > 0 || (username.count > 0 && password.count > 0) {
                loginVC.launchLogin()
            }
        }
        
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Did fail to register notifications.")
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        
        // Save cached data
//        DataController.saveContext()

        // Cancel tasks and close sessions
        NetworkVarsObjc.shared.sessionManager?.invalidateSessionCancelingTasks(true, resetSession: true)
        NetworkVarsObjc.shared.imagesSessionManager?.invalidateSessionCancelingTasks(true, resetSession: true)

        // Disable network activity indicator
        AFNetworkActivityIndicatorManager.shared().isEnabled = false
        
        // Disable network reachability monitoring
        AFNetworkReachabilityManager.shared().stopMonitoring()
        
        // Clean up /tmp directory
        cleanUpTemporaryDirectory(immediately: false)
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.

        if #available(iOS 13.0, *) {
            // Delegate to SceneDelegate
            /// - Save cached data
            /// - Schedule background tasks
        } else {
            // Save cached data
//            DataController.saveContext()
        }
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        
        if #available(iOS 13.0, *) {
            // Delegate to SceneDelegate
            /// - Save cached data
            /// - Schedule background tasks
            /// - Delete files stored in /tmp directory
        } else {
            // Save cached data
//            DataController.saveContext()

            // Disable network activity indicator
            AFNetworkActivityIndicatorManager.shared().isEnabled = false
            
            // Disable network reachability monitoring
            AFNetworkReachabilityManager.shared().stopMonitoring()

            // Clean up /tmp directory
            cleanUpTemporaryDirectory(immediately: false)
        }
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state.
        // This call is then followed by a call to applicationDidBecomeActive().

        if #available(iOS 13.0, *) {
            // Managed by SceneDelegate
        } else {
            // Enable network activity indicator
            AFNetworkActivityIndicatorManager.shared().isEnabled = true
            
            // Enable network reachability monitoring
            AFNetworkReachabilityManager.shared().startMonitoring()
        }
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive.
        // If the application was previously in the background, optionally refresh the user interface.
        
        if #available(iOS 13.0, *) {
            // Managed by SceneDelegate
        } else {
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

            // Should we resume uploads?
            if let rootVC = self.window?.rootViewController,
               rootVC.children.first is AlbumImagesViewController {
                // Determine for how long the session is opened
                let timeSinceLastLogin = NetworkVars.shared.dateOfLastLogin.timeIntervalSinceNow
                if timeSinceLastLogin < TimeInterval(-900) { // i.e. 15 minutes (Piwigo 11 session duration defaults to an hour)
                    /// - Perform relogin
                    /// - Resume upload operations in background queue
                    ///   and update badge, upload button of album navigator
                    reloginAndRetry {
                        // Refresh Album/Images view
                        let uploadInfo: [String : Any] = ["fromCache" : "NO",
                                                          "albumId" : String(0)]
                        let name = NSNotification.Name(rawValue: kPiwigoNotificationGetCategoryData)
                        NotificationCenter.default.post(name: name, object: nil, userInfo: uploadInfo)
                    }
                } else {
                    /// - Resume upload operations in background queue
                    ///   and update badge, upload button of album navigator
                    UploadManager.shared.resumeAll()
                }
            }
        }
    }
    
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession
                        identifier: String, completionHandler: @escaping () -> Void) {
        print("    > Handle events for background session with ID: \(identifier)");
        if identifier.compare(UploadSessionDelegate.shared.uploadSessionIdentifier) == .orderedSame {
            let config = URLSessionConfiguration.background(withIdentifier: identifier)
            let session = URLSession.init(configuration: config,
                                          delegate: UploadSessionDelegate.shared,
                                          delegateQueue: nil)
            UploadSessionDelegate.shared.uploadSessionCompletionHandler = completionHandler
            print("    > Rejoining session \(session) with CompletionHandler")
        }
    }


    // MARK: - UISceneSession lifecycle

    @available(iOS 13.0, *)
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
    @available(iOS 13.0, *)
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
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


    // MARK: - Settings bundle

    // Updates the version and build numbers in the app's settings bundle.
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


    // MARK: - Login View

    func loadLoginView() {
        // Load Login view
        let nav = LoginNavigationController(rootViewController: loginVC)
        nav.setNavigationBarHidden(true, animated: false)
        window?.rootViewController = nav
        
        // Next line fixes #259 view not displayed with iOS 8 and 9 on iPad
        window?.rootViewController?.view.setNeedsUpdateConstraints()

        // Color palette depends on system settings
        if #available(iOS 13.0, *) {
            AppVars.shared.isSystemDarkModeActive = (loginVC.traitCollection.userInterfaceStyle == .dark);
            print("•••> iOS mode: %@, app mode: %@, Brightness: %.1ld/%ld, app: %@", AppVars.shared.isSystemDarkModeActive ? "Dark" : "Light", AppVars.shared.isDarkPaletteModeActive ? "Dark" : "Light", lroundf(Float(UIScreen.main.brightness) * 100.0), AppVars.shared.switchPaletteThreshold, AppVars.shared.isDarkPaletteActive ? "Dark" : "Light");
        } else {
            // Fallback on earlier versions
            AppVars.shared.isSystemDarkModeActive = false
        }
        
        // Apply color palette
        screenBrightnessChanged()
    }

    @objc func reloginAndRetry(completion: @escaping () -> Void) {
        let hadOpenedSession = NetworkVars.shared.hadOpenedSession
        let server = NetworkVars.shared.serverPath
        let user = NetworkVars.shared.username
        
        if hadOpenedSession && (server.count > 0) && (user.count > 0) {
            DispatchQueue.main.async {
                self.loginVC.performRelogin(completion: completion)
            }
        }
    }

    @objc func checkSessionWhenLeavingLowPowerMode() {
        if !ProcessInfo.processInfo.isLowPowerModeEnabled {
            reloginAndRetry { }
        }
    }

    
    // MARK: - Album navigator

    @objc func loadNavigation() {
        // Display default album
        guard let defaultAlbum = AlbumImagesViewController(albumId: AlbumVars.shared.defaultCategory,
                                                           inCache: false) else { return }
        if #available(iOS 13.0, *) {
            if let sceneDelegate = UIApplication.shared.connectedScenes.randomElement()?.delegate as? SceneDelegate,
               let window = sceneDelegate.window {
                window.rootViewController = UINavigationController(rootViewController: defaultAlbum)
                UIView.transition(with: window, duration: 0.5,
                                  options: .transitionCrossDissolve) { }
                    completion: { _ in }
            }
        } else {
            // Fallback on earlier versions
            window?.rootViewController = UINavigationController(rootViewController: defaultAlbum)
            loginVC.removeFromParent()
            _loginVC = nil
        }
        
        // Observe the UIScreenBrightnessDidChangeNotification
        // When that notification is posted, the method screenBrightnessChanged will be called.
        NotificationCenter.default.addObserver(self, selector: #selector(screenBrightnessChanged),
                                               name: UIScreen.brightnessDidChangeNotification, object: nil)

        // Observe the PiwigoAddRecentAlbumNotification
        NotificationCenter.default.addObserver(self, selector: #selector(addRecentAlbumWithAlbumId),
                                               name: PwgNotifications.addRecentAlbum, object: nil)

        // Observe the PiwigoRemoveRecentAlbumNotification
        NotificationCenter.default.addObserver(self, selector: #selector(removeRecentAlbumWithAlbumId),
                                               name: PwgNotifications().removeRecentAlbum, object: nil)

        // Observe the Power State notification
        let name = Notification.Name.NSProcessInfoPowerStateDidChange
        NotificationCenter.default.addObserver(self, selector: #selector(checkSessionWhenLeavingLowPowerMode),
                                               name: name, object: nil)

        // Resume upload operations in background queue
        // and update badge, upload button of album navigator
        UploadManager.shared.resumeAll()
    }


    // MARK: - Background tasks

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
            UploadManager.shared.resumeTransfersOfBckgTask()
        }
        resumeOperation.addDependency(uploadOperations.last!)
        uploadOperations.append(resumeOperation)

        // Add image preparation which will be followed by transfer operations
        for _ in 0..<UploadManager.shared.maxNberOfUploadsPerBckgTask {
            let uploadOperation = BlockOperation {
                // Transfer image
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
//            DataController.saveContext()
        }

        // Start the operation
        print("    > Start upload operations in background task...");
        uploadQueue.addOperations(uploadOperations, waitUntilFinished: false)
    }


    // MARK: - Light and dark modes

    // Called when the screen brightness has changed, when user changes settings
    // and by traitCollectionDidChange: when the system switches between Light and Dark modes
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
        UIView.appearance().tintColor = UIColor.piwigoColorOrange()
        
        // Activity indicator
        UIActivityIndicatorView.appearance().color = UIColor.piwigoColorOrange()

        // Tab bars
        UITabBar.appearance().barTintColor = UIColor.piwigoColorBackground()

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
        NotificationCenter.default.post(name: PwgNotifications.paletteChanged, object: nil)
//        print("•••> app changed to %@ mode", AppVars.shared.isDarkPaletteActive ? "Dark" : "Light");
    }


    // MARK: - Recent albums

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
//        print("•••> Recent albums: \(AlbumVars.shared.recentCategories) (max: \(AlbumVars.shared.maxNberRecentCategories)")
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
//        pring("•••> Recent albums: \(AlbumVars.shared.recentCategories)"
    }
}
