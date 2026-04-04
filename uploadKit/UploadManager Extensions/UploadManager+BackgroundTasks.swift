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
            debugPrint("••> Background upload task request with ID \(pwgBackgroundUploadTask) submitted with success.")
        } catch {
            debugPrint("••> Failed to submit background upload request with ID \(pwgBackgroundUploadTask): \(error.localizedDescription)")
        }
    }
    
    public func handleNextUpload(task: BGProcessingTask) {
        // Background task active
        UploadVars.shared.isProcessingTaskActive = true
        
        // Schedule the next uploads if needed
        if UploadVars.shared.nberOfUploadsToComplete != 0 {
            debugPrint("••> Schedule next uploads.")
            scheduleNextUpload()
        }
        
        // Task management
        var wasExpired = false
        task.expirationHandler = {
            wasExpired = true
            debugPrint("••> Background upload task expired or cancelled by iOS.")
        }
        
        Task(priority: .utility) { @UploadManagerActor in
            // Get IDs of upload requests (limited to 100 transfers, i.e. a few hundreds URLSessionTasks)
            var (toFinish, toTransfer, toPrepare) = await UploadManager.shared.initialiseBckgTask()
            
            // Finish transfers
            if !toFinish.isEmpty {
                await UploadManager.shared.finishTransferOfUpload(withIDs: toFinish)
                toFinish.removeAll()
            }
            
            // Launch transfers
            while !toTransfer.isEmpty {
                // Check if the task expired
                if wasExpired {
                    // Stop network monitoring
                    NotificationCenter.default.post(name: .pwgStopNetworkMonitoring, object: nil)
                    UploadVars.shared.isProcessingTaskActive = false
                    task.setTaskCompleted(success: false)
                    return
                }
                // Launch transfer
                let uploadID = toTransfer.removeFirst()
                await UploadManager.shared.transferOrCopyFileOfUpload(withID: uploadID)
            }
            
            // Prepare upload and launch transfer
            while !toPrepare.isEmpty {
                // Check if the task was canceled
                if wasExpired {
                    // Stop network monitoring
                    NotificationCenter.default.post(name: .pwgStopNetworkMonitoring, object: nil)
                    UploadVars.shared.isProcessingTaskActive = false
                    task.setTaskCompleted(success: false)
                    return
                }
                // Prepare upload
                let uploadID = toPrepare.removeFirst()
                await UploadManager.shared.prepareUpload(withID: uploadID)
            }
            
            // Stop network monitoring
            NotificationCenter.default.post(name: .pwgStopNetworkMonitoring, object: nil)
            UploadVars.shared.isProcessingTaskActive = false
            task.setTaskCompleted(success: true)
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
            debugPrint("••> Background upload task request with ID \(pwgBackgroundContinuedUploadTask) submitted with success.")
        } catch {
            debugPrint("••> Failed to submit background upload request with ID \(pwgBackgroundContinuedUploadTask): \(error.localizedDescription)")
        }
    }
    
    @available(iOS 26.0, *)
    public func handleContinuedUpload(task: BGContinuedProcessingTask) {
        // Background task active
        UploadVars.shared.isContinuedProcessingTaskActive = true
        
        // Task expiration management
        var wasExpired = false
        task.expirationHandler = {
            wasExpired = true
            debugPrint("••> Continued upload task expired or cancelled by iOS.")
        }
        
        Task(priority: .utility) { @UploadManagerActor in
            // Get IDs of upload requests (limited to 100 transfers, i.e. a few hundreds URLSessionTasks)
            var (toFinish, toTransfer, toPrepare) = await UploadManager.shared.initialiseBckgTask()
            
            // Task progress initialisation
            let title = "Piwigo"
            task.progress.totalUnitCount = Int64(toTransfer.count + toPrepare.count)
            task.progress.completedUnitCount = 0
            
            // Finish transfers
            if !toFinish.isEmpty {
                await UploadManager.shared.finishTransferOfUpload(withIDs: toFinish)
                toFinish.removeAll()
            }
            
            // Launch transfers
            while !toTransfer.isEmpty {
                // Check if the task expired or should be stopped
                if shouldStopTask(task, expired: wasExpired) {
                    UploadVars.shared.isContinuedProcessingTaskActive = false
                    task.setTaskCompleted(success: false)
                    return
                }
                
                // Launch transfer
                let uploadID = toTransfer.removeFirst()
                await UploadManager.shared.transferOrCopyFileOfUpload(withID: uploadID)
                task.progress.completedUnitCount += 1
                let diff = task.progress.totalUnitCount - task.progress.completedUnitCount
                let remaining = NumberFormatter.localizedString(from: NSNumber(value: diff), number: .decimal)
                task.updateTitle(title, subtitle: "\(remaining) uploads remaining")
                
                // Wait before launching a new transfer?
                while UploadManager.shared.nberOfUploadsInTransfer >= UploadVars.shared.maxNberOfUploadTransfers {
                    debugPrint("••> Continued upload task paused for 1s")
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }
            }
            
            // Prepare uploads and launch transfers
            while !toPrepare.isEmpty {
                // Check if the task expired or should be stopped
                if shouldStopTask(task, expired: wasExpired) {
                    UploadVars.shared.isContinuedProcessingTaskActive = false
                    task.setTaskCompleted(success: false)
                    return
                }
                
                // Prepare upload and launch transfer
                let uploadID = toPrepare.removeFirst()
                await UploadManager.shared.prepareUpload(withID: uploadID)
                task.progress.completedUnitCount += 1
                let diff = task.progress.totalUnitCount - task.progress.completedUnitCount
                let remaining = NumberFormatter.localizedString(from: NSNumber(value: diff), number: .decimal)
                task.updateTitle(title, subtitle: "\(remaining) uploads remaining")
                
                // Add upload requests recently added by the user
                let uploadIDs = UploadProvider().getIDsOfPendingUploads(onlyInStates: [.waiting], inContext: self.uploadBckgContext).0
                let alreadyQueuedIDs = Set(uploadIDs).intersection(Set(toPrepare))
                var uploadIDsToAdd = uploadIDs
                uploadIDsToAdd.removeAll(where: { alreadyQueuedIDs.contains($0) })
                toPrepare.append(contentsOf: uploadIDsToAdd)
                task.progress.totalUnitCount += Int64(uploadIDsToAdd.count)
                debugPrint("••> Added \(uploadIDsToAdd.count) upload requests to the continued upload task.")
            }
            
            // Continued upload task completed
            UploadVars.shared.isContinuedProcessingTaskActive = false
            let subtitle = "\(task.progress.completedUnitCount) uploads completed."
            task.updateTitle(task.title, subtitle: subtitle)
            task.setTaskCompleted(success: true)
        }
    }
    
    @available(iOS 26.0, *)
    private func shouldStopTask(_ task: BGContinuedProcessingTask, expired wasExpired: Bool) -> Bool
    {
        var subtitle = ""
        if wasExpired {
            subtitle = "Upload task expired. Please try again."
        }
        else if ProcessInfo.processInfo.isLowPowerModeEnabled {
            subtitle = "Low power mode enabled. Please turn it off."
        }
        else if UploadVars.shared.wifiOnlyUploading && !NetworkVars.shared.isConnectedToWiFi {
            subtitle = "WiFi only uploading. Please connect to WiFi."
        }
        else {
            return false
        }
        
        task.updateTitle(task.title, subtitle: subtitle)
        return true
    }
}
