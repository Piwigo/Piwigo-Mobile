//
//  DataMigrationViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 01/06/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import UIKit
import piwigoKit

class DataMigrationViewController: UIViewController {
    
    @IBOutlet var piwigoLogo: UIImageView!
    @IBOutlet var migrationLabel: UILabel!
    @IBOutlet var pleaseWaitLabel: UILabel!
    @IBOutlet var piwigoUrlLabel: UILabel!
    @IBOutlet weak var progressView: UIProgressView!
    
    var migrator: DataMigrator?
    private var migrationBckgTask: UIBackgroundTaskIdentifier = .invalid

    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        migrationLabel.text = NSLocalizedString("CoreData_MigrationProgress", comment: "Migration in progress...")
        pleaseWaitLabel.text = NSLocalizedString("Coredata_MigrationPleaseWait", comment: "We are currently migrating some of your data. Please wait until it is complete. Do not kill the application.")
    }
    
    @objc func applyColorPalette() {
        // Background color of the view
        view.backgroundColor = .piwigoColorBackground()
        
        // Change text colour according to palette colour
        if #available(iOS 13.0, *) {
            piwigoLogo?.overrideUserInterfaceStyle = AppVars.shared.isDarkPaletteActive ? .dark : .light
        }
        
        // Text color depdending on background color
        migrationLabel.textColor = .piwigoColorText()
        pleaseWaitLabel.textColor = .piwigoColorText()
        piwigoUrlLabel.textColor = .piwigoColorText()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Set colors, fonts, etc.
        applyColorPalette()
        
        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: Notification.Name.pwgPaletteChanged, object: nil)
        // Register progress
        NotificationCenter.default.addObserver(self, selector: #selector(updateProgress),
                                               name: Notification.Name.pwgMigrationProgressUpdated, object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        // Should this view launch the migration?
        guard let migrator = self.migrator
        else {
            debugPrint("Migration already running. Display view only...")
            return
        }

        // Register application state changes when this view controller launches the migration
        NotificationCenter.default.addObserver(self, selector: #selector(appWillResignActive),
                                               name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive),
                                               name: UIApplication.didBecomeActiveNotification, object: nil)

        // Perform migration in background thread to prevent triggering watchdog after 10 s
        DispatchQueue(label: "com.piwigo.migrator", qos: .userInitiated).async { [self] in
            // Perform migration
            do {
                // Remember that a migration is running
                AppVars.shared.isMigrationRunning = true
                
                // Launch the migration of the database
                try migrator.migrateStore()
                
                // Tell iOS that the background task can be ended
                endBackgroundTaskIfActive()
                
                // Migration completed
                AppVars.shared.isMigrationRunning = false
                
                // Present login and/or album views
                DispatchQueue.main.async { [self] in
                    guard let appDelegate = UIApplication.shared.delegate as? AppDelegate
                    else { return }
                    
                    if #available(iOS 13.0, *) {
                        // Get all scenes
                        let connectedScenes = UIApplication.shared.connectedScenes
                        
                        // Restore scenes if possible
                        var restoredScenes = Set<UIScene>()
                        var hasProtectedActiveScene: Bool = false
                        connectedScenes.forEach { scene in
                            if let sceneDelegate = (scene.delegate as? SceneDelegate),
                               let window = sceneDelegate.window {
                                if let userActivity =  scene.userActivity ?? scene.session.stateRestorationActivity,
                                   sceneDelegate.configure(window: window, session: scene.session, with: userActivity) {
                                    debugPrint("••> \(scene.session.persistentIdentifier): Restore scene after migration")
                                    // Collect restored scenes
                                    restoredScenes.insert(scene)
                                    // Remember this activity for later when this app quits or suspends.
                                    scene.userActivity = userActivity
                                    // Set the title for this scene to allow the system to differentiate multiple scenes for the user.
                                    scene.title = userActivity.title
                                    // Blur views if the App Lock is enabled
                                    if scene.activationState == .foregroundActive, hasProtectedActiveScene == false {
                                        sceneDelegate.addPrivacyProtection(toFirstScene: true)
                                        hasProtectedActiveScene = true
                                    } else {
                                        sceneDelegate.addPrivacyProtection(toFirstScene: false)
                                    }
                                    // Manages privacy protection and resume uploads
                                    sceneDelegate.sceneDidBecomeActive(scene)
                                }
                            }
                        }
                        
                        // Load login album view controller
                        let otherScenes = connectedScenes.subtracting(restoredScenes)
                        if otherScenes.count == connectedScenes.count {
                            otherScenes.forEach { scene in
                                if let sceneDelegate = (scene.delegate as? SceneDelegate),
                                   let window = sceneDelegate.window {
                                    debugPrint("••> \(scene.session.persistentIdentifier): Present Login view after migration")
                                    if scene.activationState == .foregroundActive, hasProtectedActiveScene == false {
                                        // Replace migration with login view controller
                                        appDelegate.loadLoginView(in: window)
                                        // Blur views if the App Lock is enabled
                                        sceneDelegate.addPrivacyProtection(toFirstScene: true)
                                        hasProtectedActiveScene = true
                                        // Manages privacy protection and resume uploads
                                        sceneDelegate.sceneDidBecomeActive(scene)
                                    } else {
                                        sceneDelegate.window?.rootViewController = nil
                                        UIApplication.shared.requestSceneSessionDestruction(scene.session, options: nil)
                                    }
                                }
                            }
                        } else {
                            // Some scenes was created during the migration ► Present Album navigator
                            otherScenes.forEach { scene in
                                if let sceneDelegate = (scene.delegate as? SceneDelegate),
                                   let window = sceneDelegate.window {
                                    debugPrint("••> \(scene.session.persistentIdentifier): Present Album view after migration")
                                    // Replace migration with login view controller
                                    appDelegate.loadNavigation(in: window)
                                    // Blur views if the App Lock is enabled
                                    if scene.activationState == .foregroundActive, hasProtectedActiveScene == false {
                                        sceneDelegate.addPrivacyProtection(toFirstScene: true)
                                        hasProtectedActiveScene = true
                                    } else {
                                        sceneDelegate.addPrivacyProtection(toFirstScene: false)
                                    }
                                    // Manages privacy protection and resume uploads
                                    sceneDelegate.sceneDidBecomeActive(scene)
                                }
                            }
                        }
                    } else {
                        // Fallback on earlier version
                        if let window = self.view.window {
                            appDelegate.loadLoginView(in: window)
                            appDelegate.addPrivacyProtectionIfNeeded()
                        }
                    }
                }
            } catch {
                // Report error
                DispatchQueue.main.async {
                    let title = NSLocalizedString("CoreData_MigrationError_title", comment: "Migration Failed")
                    var message = NSLocalizedString("CoreData_MigrationError_generic", comment: "An unexpected error occurred during the migration.")
                    var errorMsg = error.localizedDescription
                    if let error = error as? DataMigrationError {
                        message = error.localizedDescription
                        errorMsg = ""
                    }
                    self.dismissPiwigoError(withTitle: title, message: message, errorMessage: errorMsg) {
                        fatalError("Migration Failed")
                    }
                }
            }
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate(alongsideTransition: { _ in
        }, completion: nil)
    }
    
    @objc func updateProgress(_ notification: Notification) {
        guard let progressString = notification.userInfo?["progress"] as? Float else { return }
        progressView.progress = Float(progressString)
    }
    
    deinit {
        // Unregister all observers
        NotificationCenter.default.removeObserver(self)
    }
    
    
    // MARK: - Background Task
    private func registerBackgroundTask() {
        // Tell iOS to provide additional background execution
        // This time will be used to complete or cancel the migration.
        migrationBckgTask = UIApplication.shared.beginBackgroundTask(withName: "Data Migration Background Task", expirationHandler: { [weak self] in
            debugPrint("Data Migration: iOS has signaled time has expired.")
            // Function to call when iOS is going to stop the migration
            self?.endBackgroundTaskIfActive()
        })
    }

    private func endBackgroundTaskIfActive() {
        // Called right before iOS stops the migration
        let isBackgroundTaskActive = migrationBckgTask != .invalid
        if isBackgroundTaskActive {
            debugPrint("Data Migration: Background task ended.")
            UIApplication.shared.endBackgroundTask(migrationBckgTask)
            migrationBckgTask = .invalid
        }
    }
    
    @objc func appWillResignActive() {
        debugPrint("Data Migration: App is going to background.")
        let isBackgroundTaskActive = migrationBckgTask == .invalid
        if isBackgroundTaskActive {
            registerBackgroundTask()
        }
    }
    
    @objc func appDidBecomeActive() {
        debugPrint( "Data Migration: App is back in foreground.")
        endBackgroundTaskIfActive()
    }
}
