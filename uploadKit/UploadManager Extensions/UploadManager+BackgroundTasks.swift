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
        
        // Limit number of uploads to prepare
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
                // Task completed w/o or w/o success
                UploadVars.shared.isProcessingTaskActive = false
                
                // Perform last actions according to app state
                self.finishUploadTask()
                
                // Inform the background task scheduler that the task is complete.
                task.setTaskCompleted(success: success)
            }
            
            // Get IDs of upload requests (limited to 100 transfers, i.e. a few hundreds URLSessionTasks)
            var (toFinish, toTransfer, toPrepare) = await UploadManager.shared.initialiseBckgTask()
            
            // Finish transfers
            if !toFinish.isEmpty && !shouldStopUploadTask() && !Task.isCancelled {
                await UploadManager.shared.finishTransferOfUpload(withIDs: toFinish, inTaskType: .bckgProcessingTask)
                toFinish.removeAll()
            }
            
            // Launch transfers
            while !toTransfer.isEmpty {
                // Low-Power mode activated? No required Wi-Fi?
                if shouldStopUploadTask() || Task.isCancelled { break }
                
                // Launch transfer
                let uploadID = toTransfer.removeFirst()
                await UploadManager.shared.transferOrCopyFileOfUpload(withID: uploadID, inTaskType: .bckgProcessingTask)
            }
            
            // Prepare upload and launch transfer
            while !toPrepare.isEmpty {
                // Low-Power mode activated? No required Wi-Fi?
                if shouldStopUploadTask() || Task.isCancelled { break }
                
                // Prepare upload and launch transfer
                let uploadID = toPrepare.removeFirst()
                await UploadManager.shared.prepareUpload(withID: uploadID, inTaskType: .bckgProcessingTask)
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
        let subtitle = String.piwigoKitUploadingLabel   // To avoid a duplicate translation
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
                // Task completed w/o or w/o success
                UploadVars.shared.isContinuedProcessingTaskActive = false
                
                // Perform last actions according to app state
                self.finishUploadTask()
                
                // Inform the background task scheduler that the task is complete.
                task.setTaskCompleted(success: success)
            }
            
            // Get IDs of upload requests (limited to 100 transfers, i.e. a few hundreds URLSessionTasks)
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
                // Low-Power mode activated? No required Wi-Fi?
                if shouldStopUploadTask() || Task.isCancelled { break }
                
                // Launch transfer
                let uploadID = toTransfer.removeFirst()
                await UploadManager.shared.transferOrCopyFileOfUpload(withID: uploadID, inTaskType: .bckgContinuedProcessingTask)
                task.progress.completedUnitCount += 1
                let diff = task.progress.totalUnitCount - task.progress.completedUnitCount
                let remaining = NumberFormatter.localizedString(from: NSNumber(value: diff), number: .decimal)
                task.updateTitle(title, subtitle: "\(remaining) uploads remaining")
                
                // Wait before launching a new transfer?
//                while UploadManager.shared.nberOfUploadsInTransfer >= UploadVars.shared.maxNberOfUploadTransfers {
//                    debugPrint("••> Continued upload task paused for 1s")
//                    try? await Task.sleep(nanoseconds: 1_000_000_000)
//                }
            }
            
            // Prepare uploads and launch transfers
            while !toPrepare.isEmpty {
                // Low-Power mode activated? No required Wi-Fi?
                if shouldStopUploadTask() || Task.isCancelled { break }
                
                // Prepare upload and launch transfer
                let uploadID = toPrepare.removeFirst()
                await UploadManager.shared.prepareUpload(withID: uploadID, inTaskType: .bckgContinuedProcessingTask)
                task.progress.completedUnitCount += 1
                let diff = task.progress.totalUnitCount - task.progress.completedUnitCount
                let remaining = NumberFormatter.localizedString(from: NSNumber(value: diff), number: .decimal)
                task.updateTitle(title, subtitle: "\(remaining) uploads remaining")
                
                // Low-Power mode activated? No required Wi-Fi?
                if shouldStopUploadTask() || Task.isCancelled { break }
                
                // Add upload requests recently added by the user
                let uploadIDs = UploadProvider().getIDsOfPendingUploads(onlyInStates: [.waiting], inContext: self.uploadBckgContext).0
                let alreadyQueuedIDs = Set(uploadIDs).intersection(Set(toPrepare))
                var uploadIDsToAdd = uploadIDs
                uploadIDsToAdd.removeAll(where: { alreadyQueuedIDs.contains($0) })
                toPrepare.append(contentsOf: uploadIDsToAdd)
                task.progress.totalUnitCount += Int64(uploadIDsToAdd.count)
                if uploadIDsToAdd.isEmpty == false {
                    UploadManager.logger.notice("Added \(uploadIDsToAdd.count) upload requests to '\(pwgBackgroundContinuedUploadTask)'.")
                }
            }
            
            // Task cancelled? Low-Power mode enabled? Wi-Fi required?
            if Task.isCancelled {
                // Inform that the task is stopped
                UploadManager.logger.notice("Background task '\(pwgBackgroundContinuedUploadTask)' cancelled by iOS.")
                let subtitle = "Please relaunch the app."
                task.updateTitle(task.title, subtitle: subtitle)
            }
            else if ProcessInfo.processInfo.isLowPowerModeEnabled {
                // Inform that the task is stopped
                UploadManager.logger.notice("Background task '\(pwgBackgroundContinuedUploadTask)' stopped: Low-Power mode is enabled.")
                let subtitle = "Low power mode enabled. Please turn it off."
                task.updateTitle(task.title, subtitle: subtitle)
            }
            else if UploadVars.shared.wifiOnlyUploading && !NetworkVars.shared.isConnectedToWiFi {
                // Inform that the task is stopped
                UploadManager.logger.notice("Background task '\(pwgBackgroundContinuedUploadTask)' stopped: Wi-Fi required, but not connected.")
                let subtitle = "WiFi only uploading. Please connect to WiFi."
                task.updateTitle(task.title, subtitle: subtitle)
            }
            else {
                // Inform that the task is completed with success
                success = true
                UploadManager.logger.notice("Background task '\(pwgBackgroundContinuedUploadTask)' completed with success.")
                let subtitle = "\(task.progress.completedUnitCount) uploads completed."
                task.updateTitle(task.title, subtitle: subtitle)
            }
        }
    }
}
