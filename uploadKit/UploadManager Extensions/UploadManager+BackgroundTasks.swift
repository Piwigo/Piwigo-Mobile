//
//  UploadManager+BackgroundTasks.swift
//  uploadKit
//
//  Created by Eddy Lelièvre-Berna on 02/04/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//

import BackgroundTasks
import CoreData
import Foundation
import Photos
import piwigoKit

@UploadManagerActor
extension UploadManager
{
    // MARK: - Resume in Background Task
    public func initialiseBckgTask() async -> ([NSManagedObjectID], [NSManagedObjectID], [NSManagedObjectID]) {
        // Wait until fix completed
        guard NetworkVars.shared.fixUserIsAPIKeyV412 == false
        else { return ([],[],[]) }
        
        // Reset flags
        UploadVars.shared.isPaused = false
        
        // Get Upload URI strings of active transfers
        let activeUploadsURIstr = await getUploadURIsOfTransfers()
        
        // Clear upload requests which encountered an error
        let (_,_) = await clearFailedUploads(except: activeUploadsURIstr)
        
        // Update number of uploads to complete, badge and default album view button
        self.updateNberOfUploadsToComplete()
        
        // Get IDs of uploads to finish
        let toFinish = UploadProvider().getIDsOfPendingUploads(onlyInStates: [.uploaded], inContext: self.uploadBckgContext).0
        
        // Get IDs of uploads to transfer
        let toTransfer = UploadProvider().getIDsOfPendingUploads(onlyInStates: [.prepared], inContext: self.uploadBckgContext).0
        
        // Append auto-upload requests if requested
        if UploadVars.shared.isAutoUploadActive {
            await self.appendAutoUploadRequests(inBckgTask: true)
        } else {
            await self.disableAutoUpload(inBckgTask: true)
        }
        
        // Get IDs of uploads to prepare
        var toPrepare = UploadProvider().getIDsOfPendingUploads(onlyInStates: [.waiting], inContext: self.uploadBckgContext).0
        
        // Limit number of uploads to prepare to 100 transfers, i.e. a few hundreds URLSessionTasks
        let maxNberToPrepare = max(0, maxNberOfUploadsPerBckgTask - toTransfer.count)
        if toPrepare.count > maxNberToPrepare {
            toPrepare.removeLast(toPrepare.count - maxNberToPrepare)
        }
        
        // Logs stats
        UploadManager.logger.notice("Resuming uploads: \(toTransfer.count, privacy: .public) file(s) to transfer, \(toPrepare.count, privacy: .public) uploads to prepare")
        
        // Returns object IDs of upload requests to transfer and prepare
        return (toFinish, toTransfer, toPrepare)
    }
    
    
    // MARK: - Processing Task
    public func scheduleNextUpload() {
        // Schedule upload not earlier than 15 minute from now
        // Uploading requires network connectivity and external power
        let request = BGProcessingTaskRequest.init(identifier: pwgBackgroundUploadTask)
        request.earliestBeginDate = Date.init(timeIntervalSinceNow: 15 * 60)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = true
        
        // Submit upload request
        do {
            try BGTaskScheduler.shared.submit(request)
            UploadManager.logger.notice("Background task '\(pwgBackgroundUploadTask)' submitted with success.")
        } catch {
            UploadManager.logger.notice("Failed to submit background task '\(pwgBackgroundUploadTask)': \(error.localizedDescription)")
        }
    }
    
    public func handleNextUpload(task: BGProcessingTask) {
        // Will tell that this background task is active
        UploadVars.shared.isProcessingTaskActive = true
        
        // Schedule the next uploads if needed
        if UploadVars.shared.nberOfUploadsToComplete != 0 {
            UploadManager.logger.notice("Schedule next background task '\(pwgBackgroundUploadTask)'.")
            scheduleNextUpload()
        }
        
        // Task expiration management
        var uploadTask: Task<Void, Never>?
        task.expirationHandler = {
            // Flags the task as cancelled.
            uploadTask?.cancel()
            UploadManager.logger.notice("Background task '\(pwgBackgroundUploadTask)' expiration handler fired.")
        }
        
        // Launch upload task
        uploadTask = Task(priority: .utility) { @UploadManagerActor in
            
            // Defer finishing code to managed unhandled error or crashes
            var success = false
            defer {
                // Task completed w/ or w/o success
                UploadVars.shared.isProcessingTaskActive = false
                
                // Perform last actions according to app state
                self.finishUploadTask()
                
                // Inform the background task scheduler that the task is complete.
                task.setTaskCompleted(success: success)
            }
            
            // Get IDs of a first batch of upload requests (limited to 25, i.e. a few hundreds URLSessionTasks)
            var (toFinish, toTransfer, toPrepare) = await UploadManager.shared.initialiseBckgTask()
            
            // Finish transfers
            if !toFinish.isEmpty && !shouldStopUploadTask() && !Task.isCancelled {
                await UploadManager.shared.finishTransferOfUpload(withIDs: toFinish, inTaskType: .bckgProcessingTask)
                toFinish.removeAll()
            }
            
            // Launch transfers
            while !toTransfer.isEmpty {
                // Low-Power mode activated? No required Wi-Fi? Task cancelled?
                if shouldStopUploadTask() || Task.isCancelled { break }
                
                // Launch transfer
                let uploadID = toTransfer.removeFirst()
                await UploadManager.shared.transferOrCopyFileOfUpload(withID: uploadID, inTaskType: .bckgProcessingTask)
                
                // Wait before launching a new transfer?
                if UploadManager.shared.nberOfUploadsInTransfer >= UploadVars.shared.maxNberOfUploadTransfers {
                    UploadManager.logger.notice("Background task '\(pwgBackgroundUploadTask)' is paused.")
                    while UploadManager.shared.nberOfUploadsInTransfer >= UploadVars.shared.maxNberOfUploadTransfers {
                        try? await Task.sleep(nanoseconds: 250_000_000)
                        if Task.isCancelled { break }
                    }
                    UploadManager.logger.notice("Background task '\(pwgBackgroundUploadTask)' is resumed.")
                }
            }
            
            // Prepare upload and launch transfer
            while !toPrepare.isEmpty {
                // Low-Power mode activated? No required Wi-Fi? Task cancelled?
                if shouldStopUploadTask() || Task.isCancelled { break }
                
                // Prepare upload and launch transfer
                let uploadID = toPrepare.removeFirst()
                await UploadManager.shared.prepareUpload(withID: uploadID, inTaskType: .bckgProcessingTask)
                
                // Wait before launching a new transfer?
                if UploadManager.shared.nberOfUploadsInTransfer >= UploadVars.shared.maxNberOfUploadTransfers {
                    UploadManager.logger.notice("Background task '\(pwgBackgroundUploadTask)' is paused.")
                    while UploadManager.shared.nberOfUploadsInTransfer >= UploadVars.shared.maxNberOfUploadTransfers {
                        try? await Task.sleep(nanoseconds: 250_000_000)
                        if Task.isCancelled { break }
                    }
                    UploadManager.logger.notice("Background task '\(pwgBackgroundUploadTask)' is resumed.")
                }
                
                // Get IDs of uploads waiting for preparation
                let uploadIDs = UploadProvider().getIDsOfPendingUploads(onlyInStates: [.waiting], inContext: self.uploadBckgContext).0
                
                // Remove IDs of uploads already in the queue
                let alreadyQueuedIDs = Set(uploadIDs).intersection(Set(toPrepare))
                var uploadIDsToAdd = uploadIDs
                uploadIDsToAdd.removeAll(where: { alreadyQueuedIDs.contains($0) })
                
                // Limit the number of uploads to prepare to 25, i.e. a few hundreds URLSessionTasks
                let maxNberToPrepare = max(0, maxNberOfUploadsPerBckgTask - toPrepare.count)
                if uploadIDsToAdd.count > maxNberToPrepare {
                    uploadIDsToAdd.removeLast(uploadIDsToAdd.count - maxNberToPrepare)
                }
                
                // Add upload requests without queuing more than 25
                if uploadIDsToAdd.isEmpty == false {
                    toPrepare.append(contentsOf: uploadIDsToAdd)
                    UploadManager.logger.notice("Added \(uploadIDsToAdd.count) upload requests to '\(pwgBackgroundContinuedUploadTask)'.")
                }
            }
            
            // Task cancelled? Low-Power mode enabled? Wi-Fi required?
            if Task.isCancelled {
                // Inform that the task is stopped
                UploadManager.logger.notice("Background task '\(pwgBackgroundUploadTask)' cancelled by iOS.")
            }
            else if ProcessInfo.processInfo.isLowPowerModeEnabled {
                // Inform that the task is stopped
                UploadManager.logger.notice("Background task '\(pwgBackgroundUploadTask)' stopped: Low-Power mode is enabled.")
            }
            else if UploadVars.shared.wifiOnlyUploading && !NetworkVars.shared.isConnectedToWiFi {
                // Inform that the task is stopped
                UploadManager.logger.notice("Background task '\(pwgBackgroundUploadTask)' stopped: Wi-Fi required, but not connected.")
            }
            else {
                // Inform that the task is completed with success
                success = true
                UploadManager.logger.notice("Background task '\(pwgBackgroundUploadTask)' completed with success.")
             }
        }
    }
    
    private func shouldStopUploadTask() -> Bool {
        // Low-Power mode enabled? Wi-Fi required?
        return ProcessInfo.processInfo.isLowPowerModeEnabled ||
                (UploadVars.shared.wifiOnlyUploading && !NetworkVars.shared.isConnectedToWiFi)
    }
    
    private func finishUploadTask() {
        // Explicitly abort pending CoreData work
        self.uploadBckgContext.rollback()
        
        // Is the app in the foreground?
        if UploadVars.shared.isApplicationActive {
            // Resume upload activities in the foreground
            Task(priority: .utility) { @UploadManagerActor in
                UploadVars.shared.didResumeUploads = false
                await UploadManager.shared.resumeInForeground()
            }
        } else {
            // Stop network monitoring
            NotificationCenter.default.post(name: .pwgStopNetworkMonitoring, object: nil)
        }
    }
    
    
    // MARK: - Continued Processing Task
    @available(iOS 26.0, *)
    public func runContinuedUploadTask() {
        // Should we postpone uploads?
        if UploadVars.shared.nberOfUploadsToComplete == 0 ||
            UploadVars.shared.isContinuedProcessingTaskActive ||
            UploadVars.shared.isPaused ||
            ProcessInfo.processInfo.isLowPowerModeEnabled ||
            (UploadVars.shared.wifiOnlyUploading && !NetworkVars.shared.isConnectedToWiFi) {
            return
        }
        
        // Schedule continued upload now
        // Continued uploading requires network connectivity but not external power
        let title = "Piwigo"
        let subtitle = String(localized: "backgroundTask_preparing", bundle: .uploadKit, comment: "Preparing uploads…")
        let request = BGContinuedProcessingTaskRequest(identifier: pwgBackgroundContinuedUploadTask,
                                                       title: title, subtitle: subtitle)
        request.strategy = .queue   // Queues the task to begin as soon as possible
        
        // Submit upload request
        do {
            try BGTaskScheduler.shared.submit(request)
            UploadManager.logger.notice("Background task '\(pwgBackgroundContinuedUploadTask)' submitted with success.")
        } catch {
            UploadManager.logger.notice("Failed to submit background task '\(pwgBackgroundContinuedUploadTask)': \(error.localizedDescription)")
        }
    }
    
    @available(iOS 26.0, *)
    public func handleContinuedUpload(task: BGContinuedProcessingTask) {
        // Will tell that this background task is active
        UploadVars.shared.isContinuedProcessingTaskActive = true
        
        // Task expiration management
        var uploadTask: Task<Void, Never>?
        task.expirationHandler = {
            // Flags the task as cancelled.
            uploadTask?.cancel()
            UploadManager.logger.notice("Background task '\(pwgBackgroundContinuedUploadTask)' expiration handler fired.")
        }
        
        // Launch upload task
        uploadTask = Task(priority: .utility) { @UploadManagerActor in
            
            // Defer finishing code to managed unhandled error or crashes
            var success = false
            defer {
                // Task completed w/ or w/o success
                UploadVars.shared.isContinuedProcessingTaskActive = false
                
                // Perform last actions according to app state
                self.finishUploadTask()
                
                // Inform the background task scheduler that the task is complete.
                task.setTaskCompleted(success: success)
            }
            
            // Get IDs of a first batch of upload requests (limited to 25, i.e. a few hundreds URLSessionTasks)
            var (toFinish, toTransfer, toPrepare) = await UploadManager.shared.initialiseBckgTask()
            
            // Task progress initialisation
            let title = "Piwigo"
            task.progress.totalUnitCount = Int64(toTransfer.count + toPrepare.count)
            task.progress.completedUnitCount = 0
            
            // Finish transfers
            if !toFinish.isEmpty && !shouldStopUploadTask() && !Task.isCancelled {
                await UploadManager.shared.finishTransferOfUpload(withIDs: toFinish, inTaskType: .bckgContinuedProcessingTask)
                toFinish.removeAll()
            }
            
            // Launch transfers
            while !toTransfer.isEmpty {
                // Low-Power mode activated? No required Wi-Fi? Task cancelled?
                if shouldStopUploadTask() || Task.isCancelled { break }
                
                // Launch transfer
                let uploadID = toTransfer.removeFirst()
                await UploadManager.shared.transferOrCopyFileOfUpload(withID: uploadID, inTaskType: .bckgContinuedProcessingTask)

                // Update progress bar
                task.progress.completedUnitCount += 1
                let diff = task.progress.totalUnitCount - task.progress.completedUnitCount
                let subtitle = String(format: String(localized: "backgroundTask_remaining", bundle: .uploadKit, comment: "%lld uploads remaining"), diff)
                task.updateTitle(title, subtitle: subtitle)
                
                // Wait before launching a new transfer?
                if UploadManager.shared.nberOfUploadsInTransfer >= UploadVars.shared.maxNberOfUploadTransfers {
                    UploadManager.logger.notice("Background task '\(pwgBackgroundContinuedUploadTask)' is paused.")
                    while UploadManager.shared.nberOfUploadsInTransfer >= UploadVars.shared.maxNberOfUploadTransfers {
                        try? await Task.sleep(nanoseconds: 250_000_000)
                        if Task.isCancelled { break }
                    }
                    UploadManager.logger.notice("Background task '\(pwgBackgroundContinuedUploadTask)' is resumed.")
                }
            }
            
            // Prepare uploads and launch transfers
            var toPrepareCount = toPrepare.count
            var preparedCount = 0
            while !toPrepare.isEmpty {
                // Low-Power mode activated? No required Wi-Fi? Task cancelled?
                if shouldStopUploadTask() || Task.isCancelled { break }
                
                // Prepare upload and launch transfer
                let uploadID = toPrepare.removeFirst()
                await UploadManager.shared.prepareUpload(withID: uploadID, inTaskType: .bckgContinuedProcessingTask)
                
                // Update progress bar
                preparedCount += 1
                task.progress.completedUnitCount += 1
                let diff = task.progress.totalUnitCount - task.progress.completedUnitCount
                let subtitle = String(format: String(localized: "backgroundTask_remaining", bundle: .uploadKit, comment: "%lld uploads remaining"), diff)
                task.updateTitle(title, subtitle: subtitle)
                
                // Low-Power mode activated? No required Wi-Fi? Task cancelled?
                if shouldStopUploadTask() || Task.isCancelled { break }
                
                // Wait before launching a new transfer?
                if UploadManager.shared.nberOfUploadsInTransfer >= UploadVars.shared.maxNberOfUploadTransfers {
                    UploadManager.logger.notice("Background task '\(pwgBackgroundContinuedUploadTask)' is paused.")
                    while UploadManager.shared.nberOfUploadsInTransfer >= UploadVars.shared.maxNberOfUploadTransfers {
                        // Wait 250 ms
                        try? await Task.sleep(nanoseconds: 250_000_000)
                        
                        // Low-Power mode activated? No required Wi-Fi? Task cancelled?
                        if shouldStopUploadTask() || Task.isCancelled { break }
                    }
                    UploadManager.logger.notice("Background task '\(pwgBackgroundContinuedUploadTask)' is resumed.")
                }
                
                // Get IDs of uploads waiting for preparation
                let uploadIDs = UploadProvider().getIDsOfPendingUploads(onlyInStates: [.waiting], inContext: self.uploadBckgContext).0
                
                // Did the user submit additional upload requests
                let nberOfNewUploads = uploadIDs.count - (toPrepareCount - preparedCount)
                if nberOfNewUploads > 0 {
                    // User submitted additional upload requests ► Update total count
                    toPrepareCount += nberOfNewUploads
                    task.progress.totalUnitCount += Int64(nberOfNewUploads)
                    UploadManager.logger.notice("User submitted \(nberOfNewUploads) additional upload requests to '\(pwgBackgroundContinuedUploadTask)'.")
                }
                
                // Remove IDs of uploads already in the queue
                let alreadyQueuedIDs = Set(uploadIDs).intersection(Set(toPrepare))
                var uploadIDsToAdd = uploadIDs
                uploadIDsToAdd.removeAll(where: { alreadyQueuedIDs.contains($0) })
                
                // Limit the number of uploads to prepare to 25, i.e. a few hundreds URLSessionTasks
                let maxNberToPrepare = max(0, maxNberOfUploadsPerBckgTask - toPrepare.count)
                if uploadIDsToAdd.count > maxNberToPrepare {
                    uploadIDsToAdd.removeLast(uploadIDsToAdd.count - maxNberToPrepare)
                }
                
                // Add upload requests without queuing more than 25
                if uploadIDsToAdd.isEmpty == false {
                    toPrepare.append(contentsOf: uploadIDsToAdd)
                    UploadManager.logger.notice("Added \(uploadIDsToAdd.count) upload requests to '\(pwgBackgroundContinuedUploadTask)'.")
                }
            }
            
            // Task cancelled? Low-Power mode enabled? Wi-Fi required?
            if Task.isCancelled {
                // Inform that the task is stopped
                UploadManager.logger.notice("Background task '\(pwgBackgroundContinuedUploadTask)' cancelled by iOS.")
                let subtitle = String(localized: "backgroundTask_cancelled", bundle: .uploadKit, comment: "Uploads interrupted. Please restart the app.")
                task.updateTitle(task.title, subtitle: subtitle)
            }
            else if ProcessInfo.processInfo.isLowPowerModeEnabled {
                // Inform that the task is stopped
                UploadManager.logger.notice("Background task '\(pwgBackgroundContinuedUploadTask)' stopped: Low-Power mode is enabled.")
                let subtitle = String(localized: "backgroundTask_lowPowerMode", bundle: .uploadKit, comment: "Low power mode enabled. Please turn it off.")
                task.updateTitle(task.title, subtitle: subtitle)
            }
            else if UploadVars.shared.wifiOnlyUploading && !NetworkVars.shared.isConnectedToWiFi {
                // Inform that the task is stopped
                UploadManager.logger.notice("Background task '\(pwgBackgroundContinuedUploadTask)' stopped: Wi-Fi required, but not connected.")
                let subtitle = String(localized: "backgroundTask_noWifi", bundle: .uploadKit, comment: "Wi-Fi only uploading. Please connect to Wi-Fi.")
                task.updateTitle(task.title, subtitle: subtitle)
            }
            else {
                // Inform that the task is completed with success
                success = true
                UploadManager.logger.notice("Background task '\(pwgBackgroundContinuedUploadTask)' completed with success.")
                let subtitle = String(format: String(localized: "backgroundTask_completed", bundle: .uploadKit, comment: "%lld uploads completed"), task.progress.completedUnitCount)
                task.updateTitle(task.title, subtitle: subtitle)
            }
        }
    }
}
