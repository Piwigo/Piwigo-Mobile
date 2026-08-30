//
//  UploadManager+BackgroundTasks.swift
//  PwgUploadKit
//
//  Created by Eddy Lelièvre-Berna on 02/04/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//

import BackgroundTasks
import CoreData
import Foundation
import Photos
import PwgKit
import PwgCacheKit

/// Number of upload requests prepared concurrently by a background task.
/// The jobs interleave on the upload actor: while a video export waits on AVFoundation, the
/// following requests are prepared and their transfers launched in the meantime.
/// Only the BGContinuedProcessingTask, which iOS 26 runs on recent devices, prepares two
/// requests at a time — two 4K HDR exports at once remain well within its budget. The
/// BGProcessingTask also runs on older devices, whose background memory limit is tighter,
/// and therefore prepares the requests one by one.
private func maxNberOfConcurrentPreparations(inTaskType taskType: UploadTaskType) -> Int {
    return taskType == .bckgContinuedProcessingTask ? 2 : 1
}

@UploadManagerActor
extension UploadManager
{
    // MARK: - Resume in Background Task
    public func initialiseBckgTask() async -> ([NSManagedObjectID], [NSManagedObjectID], [NSManagedObjectID]) {
        // Wait until fix completed
        guard ServerVars.shared.fixUserIsAPIKeyV412 == false
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
        UploadManager.logger.notice("Resuming uploads: \(toTransfer.count) file(s) to transfer, \(toPrepare.count) upload(s) to prepare")
        
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
                self.finishUploadProcessingTask()
                
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
            }
            
            // Prepare uploads and launch transfers
            await UploadManager.shared.prepareUploads(withIDs: toPrepare, inTaskType: .bckgProcessingTask)
            
            // Task cancelled? Low-Power mode enabled? Wi-Fi required?
            if Task.isCancelled {
                // Inform that the task is stopped
                UploadManager.logger.notice("Background task '\(pwgBackgroundUploadTask)' cancelled by iOS.")
            }
            else if ProcessInfo.processInfo.isLowPowerModeEnabled {
                // Inform that the task is stopped
                UploadManager.logger.notice("Background task '\(pwgBackgroundUploadTask)' stopped: Low-Power mode is enabled.")
            }
            else if [.serious, .critical].contains(ProcessInfo.processInfo.thermalState) {
                // Inform that the task is stopped
                UploadManager.logger.notice("Background task '\(pwgBackgroundUploadTask)' stopped: Device in high thermal state.")
            }
            else if UploadVars.shared.wifiOnlyUploading && !ServerVars.shared.isConnectedToWiFi {
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
    
    /// Prepares the queued upload requests, keeping as many jobs in flight as the task type
    /// allows, and appends the requests submitted while the task runs.
    /// Every job is a child of the task group, so none of them outlives this method: a background
    /// task cannot complete — and the app be suspended — while a video is still being exported.
    /// Should iOS expire the task, cancellation propagates to the jobs in flight, which report
    /// their request as retryable.
    /// `onPreparation` is called after each prepared request with the number of requests which
    /// were appended to the queue, so that the caller may update its progress bar.
    private func prepareUploads(withIDs uploadIDs: [NSManagedObjectID],
                                inTaskType taskType: UploadTaskType,
                                onPreparation: (_ nberOfNewRequests: Int) -> Void = { _ in }) async
    {
        var toPrepare = uploadIDs
        let maxNberOfJobs = maxNberOfConcurrentPreparations(inTaskType: taskType)
        await withTaskGroup(of: Void.self) { group in
            var nberOfJobsInFlight = 0
            while true {
                // Low-Power mode activated? No required Wi-Fi? Task cancelled? Device in high thermal state?
                if shouldStopUploadTask() || Task.isCancelled { break }
                
                // Launch jobs until the maximum number of concurrent preparations is reached
                while nberOfJobsInFlight < maxNberOfJobs, toPrepare.isEmpty == false {
                    let uploadID = toPrepare.removeFirst()
                    group.addTask {
                        await UploadManager.shared.prepareUpload(withID: uploadID, inTaskType: taskType)
                    }
                    nberOfJobsInFlight += 1
                }
                
                // Nothing left to prepare?
                if nberOfJobsInFlight == 0 { break }
                
                // Wait for the next job to complete
                _ = await group.next()
                nberOfJobsInFlight -= 1
                
                // Get IDs of uploads waiting for preparation
                let waitingIDs = UploadProvider().getIDsOfPendingUploads(onlyInStates: [.waiting], inContext: self.uploadBckgContext).0
                
                // Remove IDs of uploads already in the queue
                /// The requests being prepared and those already prepared are not in the .waiting
                /// state, so they are never fetched twice.
                let alreadyQueuedIDs = Set(waitingIDs).intersection(Set(toPrepare))
                var uploadIDsToAdd = waitingIDs
                uploadIDsToAdd.removeAll(where: { alreadyQueuedIDs.contains($0) })
                
                // Limit the number of uploads to prepare, i.e. a few hundreds URLSessionTasks
                let maxNberToPrepare = max(0, maxNberOfUploadsPerBckgTask - toPrepare.count)
                if uploadIDsToAdd.count > maxNberToPrepare {
                    uploadIDsToAdd.removeLast(uploadIDsToAdd.count - maxNberToPrepare)
                }
                
                // Did the user submit additional upload requests?
                if uploadIDsToAdd.isEmpty == false {
                    toPrepare.append(contentsOf: uploadIDsToAdd)
                    UploadManager.logger.notice("Added \(uploadIDsToAdd.count) upload requests to '\(taskType.rawValue)'.")
                }
                
                // Let the caller update its progress bar
                onPreparation(uploadIDsToAdd.count)
            }
            
            // Await the jobs still in flight before returning
            await group.waitForAll()
        }
    }
    
    private func shouldStopUploadTask() -> Bool {
        // Low-Power mode enabled? Wi-Fi required? Device in high thermal state?
        return ProcessInfo.processInfo.isLowPowerModeEnabled ||
                [.serious, .critical].contains(ProcessInfo.processInfo.thermalState) ||
                (UploadVars.shared.wifiOnlyUploading && !ServerVars.shared.isConnectedToWiFi)
    }
    
    private func finishUploadProcessingTask() {
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
    #if os(iOS) && !targetEnvironment(macCatalyst)
    @available(iOS 26.0, *)
    public func runContinuedUploadTask() {
        // Should we postpone uploads?
        if (UploadVars.shared.nberOfUploadsToComplete == 0 && !UploadVars.shared.isAutoUploadActive) ||
            UploadVars.shared.isContinuedProcessingTaskActive ||
            UploadVars.shared.isPaused ||
            ProcessInfo.processInfo.isLowPowerModeEnabled ||
            [.serious, .critical].contains(ProcessInfo.processInfo.thermalState) ||
            (UploadVars.shared.wifiOnlyUploading && !ServerVars.shared.isConnectedToWiFi) {

            // Propose to delete uploaded images of the photo Library once a day
            // or immediately if there is no pending upload request, if any
            suggestToDeleteUploadedImages(withPendingUploads: UploadVars.shared.nberOfUploadsToComplete)
            return
        }
        
        // Schedule continued upload now
        // Continued uploading requires network connectivity but not external power
        let title = "Piwigo"
        let subtitle = String(localized: "backgroundTask_preparing", bundle: .pwgUploadKit,
                              comment: "Preparing uploads…")
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
                self.finishUploadContinuedProcessingTask()
                
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
                let subtitle = String(localized: "backgroundTask_remaining \(diff)", bundle: .pwgUploadKit,
                                      comment: "%lld uploads remaining")
                task.updateTitle(title, subtitle: subtitle)
            }
            
            // Prepare uploads and launch transfers
            await UploadManager.shared.prepareUploads(withIDs: toPrepare, inTaskType: .bckgContinuedProcessingTask) { nberOfNewRequests in
                // Did the user submit additional upload requests? ► Update total count
                if nberOfNewRequests > 0 {
                    task.progress.totalUnitCount += Int64(nberOfNewRequests)
                    UploadManager.logger.notice("User submitted \(nberOfNewRequests) additional upload requests to '\(pwgBackgroundContinuedUploadTask)'.")
                }
                
                // Update progress bar
                task.progress.completedUnitCount += 1
                let diff = task.progress.totalUnitCount - task.progress.completedUnitCount
                let subtitle = String(localized: "backgroundTask_remaining \(diff)", bundle: .pwgUploadKit,
                                      comment: "%lld uploads remaining")
                task.updateTitle(title, subtitle: subtitle)
            }
            
            // Task cancelled? Low-Power mode enabled? Wi-Fi required? Device in high thermal state?
            if Task.isCancelled {
                // Inform that the task is stopped
                UploadManager.logger.notice("Background task '\(pwgBackgroundContinuedUploadTask)' cancelled by iOS.")
                let subtitle = String(localized: "backgroundTask_cancelled", bundle: .pwgUploadKit,
                                      comment: "Uploads interrupted. Please restart the app.")
                task.updateTitle(task.title, subtitle: subtitle)
            }
            else if ProcessInfo.processInfo.isLowPowerModeEnabled {
                // Inform that the task is stopped
                UploadManager.logger.notice("Background task '\(pwgBackgroundContinuedUploadTask)' stopped: Low-Power mode is enabled.")
                let subtitle = String(localized: "backgroundTask_lowPowerMode", bundle: .pwgUploadKit,
                                      comment: "Low power mode enabled. Please turn it off.")
                task.updateTitle(task.title, subtitle: subtitle)
            }
            else if [.serious, .critical].contains(ProcessInfo.processInfo.thermalState) {
                // Inform that the task is stopped
                UploadManager.logger.notice("Background task '\(pwgBackgroundUploadTask)' stopped: Device in high thermal state.")
                let subtitle = String(localized: "backgroundTask_highThermalState", bundle: .pwgUploadKit,
                                      comment: "The device needs to cool down.")
                task.updateTitle(task.title, subtitle: subtitle)
            }
            else if UploadVars.shared.wifiOnlyUploading && !ServerVars.shared.isConnectedToWiFi {
                // Inform that the task is stopped
                UploadManager.logger.notice("Background task '\(pwgBackgroundContinuedUploadTask)' stopped: Wi-Fi required, but not connected.")
                let subtitle = String(localized: "backgroundTask_noWifi", bundle: .pwgUploadKit,
                                      comment: "Wi-Fi only uploading. Please connect to Wi-Fi.")
                task.updateTitle(task.title, subtitle: subtitle)
            }
            else {
                // Inform that the task is completed with success
                success = true
                UploadManager.logger.notice("Background task '\(pwgBackgroundContinuedUploadTask)' completed with success.")
                let subtitle = String(localized: "backgroundTask_completed \(task.progress.completedUnitCount)", bundle: .pwgUploadKit,
                                      comment: "%lld uploads completed")
                task.updateTitle(task.title, subtitle: subtitle)
            }
        }
    }
    
    @available(iOS 26.0, *)
    private func finishUploadContinuedProcessingTask() {
        // Explicitly abort pending CoreData work
        self.uploadBckgContext.rollback()
        
        // Stop network monitoring
        NotificationCenter.default.post(name: .pwgStopNetworkMonitoring, object: nil)
    }
    #endif
}
