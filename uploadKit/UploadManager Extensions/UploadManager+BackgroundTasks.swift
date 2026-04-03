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
    public func initialiseBckgTask() async -> ([NSManagedObjectID], [NSManagedObjectID]) {
        // Wait until fix completed
        guard NetworkVars.shared.fixUserIsAPIKeyV412 == false
        else { return ([],[]) }
        
        // Reset flags
        UploadVars.shared.isPaused = false
        
        // Get Upload URI strings of active transfers
        let activeUploadsURIstr = await getUploadURIsOfTransfers()
        
        // Clear upload requests which encountered an error
        let (_,_) = await clearFailedUploads(except: activeUploadsURIstr)
        
        // Store number, update badge and default album view button
        let nberOfPendingUploads = UploadProvider().getCountOfPendingUploads(inContext: self.uploadBckgContext)
        DispatchQueue.main.async {
            // Update app badge and button of root album (or default album)
            let uploadInfo: [String : Any] = ["nberOfUploadsToComplete" : nberOfPendingUploads]
            NotificationCenter.default.post(name: .pwgLeftUploads, object: nil, userInfo: uploadInfo)
        }
        
        // Get uploaded tasks to complete
        var toTransfer = UploadProvider().getIDsOfPendingUploads(onlyInStates: [.uploaded], inContext: self.uploadBckgContext).0
        
        // Append prepared uploads to transfer
        var preparedUploadIDs = UploadProvider().getIDsOfPendingUploads(onlyInStates: [.prepared], inContext: self.uploadBckgContext).0
        let alreadyQueuedIDs = Set(preparedUploadIDs).intersection(Set(toTransfer))
        preparedUploadIDs.removeAll(where: { alreadyQueuedIDs.contains($0) })
        toTransfer.append(contentsOf: preparedUploadIDs)
        
        // Append auto-upload requests if requested
        if UploadVars.shared.isAutoUploadActive {
            await self.appendAutoUploadRequests(inBckgTask: true)
        } else {
            await self.disableAutoUpload(inBckgTask: true)
        }
        
        // Append uploads to prepare
        var toPrepare = UploadProvider().getIDsOfPendingUploads(onlyInStates: [.waiting], inContext: self.uploadBckgContext).0
        
        // Limit number of uploads to prepare
        let maxNberToPrepare = max(0, maxNberOfUploadsPerBckgTask - toTransfer.count)
        if toPrepare.count > maxNberToPrepare {
            toPrepare.removeLast(toPrepare.count - maxNberToPrepare)
        }
        
        // Logs stats
        UploadManager.logger.notice("Resuming uploads: \(toTransfer.count, privacy: .public) file(s) to transfer, \(toPrepare.count, privacy: .public) uploads to prepare")
        
        // Returns object IDs of upload requests to transfer and prepare
        return (toTransfer, toPrepare)
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
            // Get object IDs of upload requests (limited to 100 upload requests)
            let (toTransfer, toPrepare) = await UploadManager.shared.initialiseBckgTask()
            
            // Launch transfers
            for uploadID in toTransfer {
                // Check if the task was canceled
                if wasExpired {
                    // Stop network monitoring
                    NotificationCenter.default.post(name: .pwgStopNetworkMonitoring, object: nil)
                    UploadVars.shared.isProcessingTaskActive = false
                    task.setTaskCompleted(success: false)
                    return
                }
                // Launch transfer
                await UploadManager.shared.transferOrCopyFileOfUpload(withID: uploadID)
            }
            
            // Prepare uploads
            for uploadID in toPrepare {
                // Check if the task was canceled
                if wasExpired {
                    // Stop network monitoring
                    NotificationCenter.default.post(name: .pwgStopNetworkMonitoring, object: nil)
                    UploadVars.shared.isProcessingTaskActive = false
                    task.setTaskCompleted(success: false)
                    return
                }
                // Prepare upload
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
        if UploadVars.shared.isContinuedProcessingTaskActive ||
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
        
        // Check that there are images to transfer
        guard UploadVars.shared.nberOfUploadsToComplete != 0
        else {
            UploadVars.shared.isContinuedProcessingTaskActive = false
            task.setTaskCompleted(success: false)
            return
        }
        
        // Task expiration management
        var wasExpired = false
        task.expirationHandler = {
            wasExpired = true
            debugPrint("••> Continued upload task expired or cancelled by iOS.")
        }
        
        Task(priority: .utility) { @UploadManagerActor in
            // Get object IDs of upload requests (limited to 100 upload requests)
            let (toTransfer, toPrepare) = await UploadManager.shared.initialiseBckgTask()
            
            // Task progress initialisation
            let title = "Piwigo"
            task.progress.totalUnitCount = Int64(toTransfer.count + toPrepare.count)
            task.progress.completedUnitCount = 0
            
            // Launch transfers
            for uploadID in toTransfer {
                // Check if the task was canceled
                if wasExpired {
                    UploadVars.shared.isContinuedProcessingTaskActive = false
                    task.setTaskCompleted(success: false)
                    return
                }
                // Launch transfer
                await UploadManager.shared.transferOrCopyFileOfUpload(withID: uploadID)
                task.progress.completedUnitCount += 1
                let percent = NumberFormatter.localizedString(from: NSNumber(value: task.progress.fractionCompleted), number: .percent)
                task.updateTitle(title, subtitle: "\(percent) complete")
            }
            
            // Prepare uploads
            for uploadID in toPrepare {
                // Check if the task was canceled
                if wasExpired {
                    UploadVars.shared.isContinuedProcessingTaskActive = false
                    task.setTaskCompleted(success: false)
                    return
                }
                // Prepare upload
                await UploadManager.shared.prepareUpload(withID: uploadID)
                task.progress.completedUnitCount += 1
                let percent = NumberFormatter.localizedString(from: NSNumber(value: task.progress.fractionCompleted), number: .percent)
                task.updateTitle(title, subtitle: "\(percent) complete")
            }
            
            // Continued upload task completed
            UploadVars.shared.isContinuedProcessingTaskActive = false
            task.setTaskCompleted(success: true)
        }
    }
}
