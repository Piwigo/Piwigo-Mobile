//
//  AppDelegate+UploadImages.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 19/07/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//

import BackgroundTasks
import Foundation

import PwgKit
import PwgAPIKit
import PwgCacheKit
import PwgUploadKit

extension AppDelegate
{
    // MARK: - Background Task | Uploads
    /* For testing the background task:
     - Build and run the app, then background it to schedule the task.
     - Bring the app to the foreground again. Then in Xcode, hit the pause button in the debugger, type one of the commands:
     e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"org.piwigo.uploadManager"]
     e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"net.lelievre-berna.piwigo.uploadManager"]
     e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateExpirationForTaskWithIdentifier:@"org.piwigo.uploadManager"]
     e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateExpirationForTaskWithIdentifier:@"net.lelievre-berna.piwigo.uploadManager"]
     - and continue the execution.
     */
    func registerBgUploadImagesTask() {
        // Register background upload task
        BGTaskScheduler.shared.register(forTaskWithIdentifier: pwgBackgroundUploadTask, using: nil) { bgTask in
            // Check task creation
            guard let task = bgTask as? BGProcessingTask else { return }
                        
            // Don't upload images now if a migration is planned
            if CacheVars.shared.isMigrationRunning {
                AppDelegate.logger.notice("Background task '\(pwgBackgroundUploadTask)' rescheduled because a migration is ongoing.")
                task.setTaskCompleted(success: false)
                return
            }
            
            // iOS may launch the task when the app is active (since iOS 18)
            /// Comment below lines to debug BGProcessingTask
            if UploadVars.shared.isApplicationActive {
                AppDelegate.logger.notice("Background task '\(pwgBackgroundUploadTask)' halted because the app is active.")
                task.setTaskCompleted(success: false)
                return
            }
            
            // Are conditions appropriate?
            if UploadVars.shared.isContinuedProcessingTaskActive,
                ProcessInfo.processInfo.isLowPowerModeEnabled ||
                [.serious, .critical].contains(ProcessInfo.processInfo.thermalState) ||
                (UploadVars.shared.wifiOnlyUploading && !ServerVars.shared.isConnectedToWiFi) {
                AppDelegate.logger.notice("Background task '\(pwgBackgroundUploadTask)' halted because in Low-Power mode, Wi-Fi unavailable, device in high thermal state, or already uploading.")
                task.setTaskCompleted(success: false)
                return
            }
            
            // Start network monitoring
            Task { @NetworkMonitoring in
                await self.networkMonitor?.startMonitoring()
            }
            
            // Handle next upload
            Task(priority: .utility) { @UploadManagerActor in
                UploadManager.shared.handleNextUpload(task: task)
            }
        }
    }
    
    @available(iOS 26.0, *)
    func registerBgContinuedUploadImagesTask() {
        // Register continued background upload task
        BGTaskScheduler.shared.register(forTaskWithIdentifier: pwgBackgroundContinuedUploadTask, using: nil) { bgTask in
            // Check task creation
            guard let task = bgTask as? BGContinuedProcessingTask else { return }
            
            // Don't upload images now if a migration is planned
            if CacheVars.shared.isMigrationRunning {
                AppDelegate.logger.notice("Background task '\(pwgBackgroundContinuedUploadTask)' rescheduled because a migration is ongoing.")
                task.setTaskCompleted(success: true)
                return
            }
            
            // Handle next uploads
            Task(priority: .utility) { @UploadManagerActor in
                UploadManager.shared.handleContinuedUpload(task: task)
            }
        }
    }
}
