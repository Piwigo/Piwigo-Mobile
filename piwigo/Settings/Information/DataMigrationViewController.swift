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
    var completionHandler: (() -> Void)?
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
        // Register application state changes
        NotificationCenter.default.addObserver(self, selector: #selector(appWillResignActive),
                                               name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive),
                                               name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        // Should this view launch the migration?
        guard let migrator = self.migrator
        else { return }
//        migrator.dataMigrationDelegate = self

        // Perform migration in background thread to prevent triggering watchdog after 10 s
        DispatchQueue(label: "com.piwigo.migrator", qos: .userInitiated).async { [self] in
            // Perform migration
            do {
                try migrator.migrateStore()
                
                // Tell iOS that the background task can be ended
                endBackgroundTaskIfActive()
                
                // Present login and/or album views
                guard let completionHandler = self.completionHandler
                else { return }
                DispatchQueue.main.async {
                    // Complete the work
                    completionHandler()
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


// MARK: - DataMigratorDelegate Methods
//extension DataMigrationViewController: DataMigratorDelegate {
//    // Called by the migrator to determine if the migration should pursue
//    func canPursueMigration(with timeRequired: TimeInterval) -> Bool {
//        switch UIApplication.shared.applicationState {
//        case .background:
//            let timeRemaining = UIApplication.shared.backgroundTimeRemaining
//            if timeRemaining < Double.greatestFiniteMagnitude {
//                let secondsRemaining = String(format: "%.1f seconds remaining", timeRemaining)
//                debugPrint("Data Migration: App is backgrounded - \(secondsRemaining)")
//                return timeRemaining < timeRequired ? false : true
//            }
//        case .active, .inactive:
//            return true
//        default:
//            break
//        }
//        return false
//    }
//}
