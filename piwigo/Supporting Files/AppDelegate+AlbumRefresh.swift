//
//  AppDelegate+AlbumRefresh.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 18/07/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//

import BackgroundTasks
import Foundation
import UIKit

import PwgKit
import PwgAPIKit
import PwgCacheKit
import PwgUploadKit

/// Identifier of the background task refreshing the album data once a day
let pwgBackgroundAlbumRefreshTask = "\(Bundle.main.bundleIdentifier!).albumRefresh"

extension AppDelegate
{
    // MARK: - Background Task | Album Data Refresh
    /* For testing the background task:
    - Build and run the app, then background it to schedule the task.
    - Bring the app to the foreground again. Then in Xcode, hit the pause button in the debugger, type one of the commands:
      e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"org.piwigo.albumRefresh"]
      e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"net.lelievre-berna.piwigo.albumRefresh"]
      e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateExpirationForTaskWithIdentifier:@"org.piwigo.albumRefresh"]
      e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateExpirationForTaskWithIdentifier:@"net.lelievre-berna.piwigo.albumRefresh"]
     - and continue the execution.
     */
    func registerAlbumRefreshTask() {
        // Register background album data refresh task
        BGTaskScheduler.shared.register(forTaskWithIdentifier: pwgBackgroundAlbumRefreshTask, using: nil) { bgTask in
            // Check task creation
            guard let task = bgTask as? BGProcessingTask else { return }

            // Don't refresh album data now if a migration is planned
            if CacheVars.shared.isMigrationRunning {
                AppDelegate.logger.notice("Background task '\(pwgBackgroundAlbumRefreshTask)' rescheduled because a migration is ongoing.")
                task.setTaskCompleted(success: false)
                return
            }
            
            // iOS may launch the task when the app is active (since iOS 18)
            // Album data is then fetched while the user browses albums
            /// Comment below lines to debug BGProcessingTask
            if UploadVars.shared.isApplicationActive {
                AppDelegate.logger.notice("Background task '\(pwgBackgroundAlbumRefreshTask)' halted because the app is active.")
                task.setTaskCompleted(success: false)
                return
            }
            
            // Fetch all album data recursively
            self.handleAlbumRefresh(task: task)
        }
    }
    
    func scheduleAlbumRefresh() {
        // NOP until the user establishes a connection to a Piwigo server
        guard ServerVars.shared.serverPath.isEmpty == false,
              ServerVars.shared.username.isEmpty == false
        else { return }

        // Schedule album data refresh one day after the last refresh
        // Refreshing requires network connectivity but not external power
        let request = BGProcessingTaskRequest(identifier: pwgBackgroundAlbumRefreshTask)
        let nextRefreshDate = Date(timeIntervalSinceReferenceDate: CacheVars.shared.dateOfLastAlbumRefresh + 24 * 3600)
        request.earliestBeginDate = max(nextRefreshDate, Date(timeIntervalSinceNow: 15 * 60))
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false

        // Submit album data refresh request
        do {
            try BGTaskScheduler.shared.submit(request)
            AppDelegate.logger.notice("Background task '\(pwgBackgroundAlbumRefreshTask)' submitted with success.")
        } catch {
            AppDelegate.logger.notice("Failed to submit background task '\(pwgBackgroundAlbumRefreshTask)': \(error.localizedDescription)")
        }
    }

    private func handleAlbumRefresh(task: BGProcessingTask) {
        // Task expiration management
        var refreshTask: Task<Void, Never>?
        task.expirationHandler = {
            // Flags the task as cancelled.
            refreshTask?.cancel()
            AppDelegate.logger.notice("Background task '\(pwgBackgroundAlbumRefreshTask)' expiration handler fired.")
        }

        // Launch album data refresh task
        refreshTask = Task(priority: .utility) {

            // Remember when the task started to log its duration
            let startTime = Date.timeIntervalSinceReferenceDate

            // Defer finishing code to manage unhandled errors or crashes
            var success = false
            defer {
                // Schedule the next refresh (in a day if this one succeeded)
                self.scheduleAlbumRefresh()

                // Inform the background task scheduler that the task is complete.
                task.setTaskCompleted(success: success)
            }

            do {
                // Retrieve the current user account
                let bckgContext = DataController.shared.newTaskContext()
                guard let user = try UserProvider().getUserAccount(inContext: bckgContext)
                else {
                    AppDelegate.logger.notice("Background task '\(pwgBackgroundAlbumRefreshTask)' stopped: no user account.")
                    return
                }
                let userID = user.objectID
                let userData = try UserProvider().getPropertiesOfUser(withURIstr: userID.uriRepresentation().absoluteString,
                                                                      inContext: bckgContext)

                // Re-login if the session was closed
                try await UploadManager.shared.checkSession(ofUserWithID: userID, lastConnected: userData.lastUsed)
                if Task.isCancelled { return }

                // Fetch data of all albums at once
                let thumbnailSize = pwgImageSize(rawValue: AlbumVars.shared.defaultAlbumThumbnailSize) ?? .medium
                let pwgData = try await JSONManager.shared.fetchAlbums(forUserWithAdminRights: userData.hasAdminRights,
                                                                       inParentWithId: 0, recursively: true,
                                                                       thumbnailSize: thumbnailSize)
                if Task.isCancelled { return }

                // Import the album data into the cache
                try AlbumProvider().importAlbums(pwgData, recursively: true, inParent: 0)

                // Remember when all album data was last refreshed
                CacheVars.shared.dateOfLastAlbumRefresh = Date().timeIntervalSinceReferenceDate

                // Inform that the task is completed with success
                /// 1.7 s to retrieve the data of 582 albums with the Piwigo 16.4 test server
                success = true
                let duration = Date.timeIntervalSinceReferenceDate - startTime
                AppDelegate.logger.notice("Background task '\(pwgBackgroundAlbumRefreshTask)' completed with success (\(pwgData.count) albums in \(String(format: "%.1f", duration)) s).")
            }
            catch {
                AppDelegate.logger.notice("Background task '\(pwgBackgroundAlbumRefreshTask)' failed: \(error.localizedDescription)")
            }
        }
    }
}
