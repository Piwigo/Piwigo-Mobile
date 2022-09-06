//
//  UploadManager.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 22/05/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//
// See https://academy.realm.io/posts/gwendolyn-weston-ios-background-networking/

import Foundation
import Photos
import CoreData
import MobileCoreServices

public class UploadManager: NSObject {

    // Singleton
    public static let shared = UploadManager()
    
    // Constants used to name and identify media
    let kOriginalSuffix = "-original"
    public let kIntentPrefix = "Intent-"
    public let kClipboardPrefix = "Clipboard-"
    public let kImageSuffix = "-img-"
    public let kMovieSuffix = "-mov-"
    
    // Constants returning the list of:
    /// - image formats whcih can be converted with iOS
    /// - movie formats which can be converted with iOS
    /// See: https://developer.apple.com/documentation/uniformtypeidentifiers/uttype/system_declared_types
    @nonobjc let acceptedImageFormats: String = {
        return "png,heic,heif,tif,tiff,jpg,jpeg,raw,webp,gif,bmp,ico"
    }()
    @nonobjc let acceptedMovieFormats: String = {
        return "mov,mpg,mpeg,mpeg2,mp4,avi"
    }()

    // For logs
    @nonobjc let debugFormatter: DateFormatter = {
        var formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.ssssss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    // MARK: - Initialisation
    public var isPaused = false
        
    /// Background queue in which uploads are managed
    public let backgroundQueue: DispatchQueue = {
        return DispatchQueue(label: "org.piwigo.uploadBckgQueue", qos: .background)
    }()
    
    /// Uploads directory into which image/video files are temporarily stored
    public let applicationUploadsDirectory: URL = {
        let fm = FileManager.default
        let anURL = DataController.shared.appGroupDirectory.appendingPathComponent("Uploads")

        // Create the Piwigo/Uploads directory if needed
        if !fm.fileExists(atPath: anURL.path) {
            var errorCreatingDirectory: Error? = nil
            do {
                try fm.createDirectory(at: anURL, withIntermediateDirectories: true, attributes: nil)
            } catch let errorCreatingDirectory {
            }

            if errorCreatingDirectory != nil {
                print("Unable to create directory for files to upload.")
                abort()
            }
        }
        return anURL
    }()
    
    let decoder = JSONDecoder()
    
    deinit {
//        NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)

        // Close upload session
//        sessionManager.invalidateSessionCancelingTasks(true, resetSession: true)
    }
    

    // MARK: - Core Data
    /**
     The UploadsProvider that collects upload data, saves it to Core Data,
     and serves it to the uploader.
     */
    var uploadsProvider: UploadProvider = {
        let provider : UploadProvider = UploadProvider()
        return provider
    }()

    
    // MARK: - Upload Request States
    /** The manager prepares an image for upload and then launches the transfer.
    - isPreparing is set to true when a photo/video is going to be prepared,
      and false when the preparation has completed or failed.
    - isUploading contains the localIdentifier of the photos/videos being transferred to the server,
    - isFinishing is set to true when the photo/video parameters are going to be set,
      and false when this job has completed or failed.
    */

    // Store number of upload requests to complete
    // Update app badge and Upload button in root/default album
    private var _nberOfUploadsToComplete: Int = 0
    public var nberOfUploadsToComplete: Int {
        get {
            return _nberOfUploadsToComplete
        }
        set(requestsToComplete) {
            // Update value
            _nberOfUploadsToComplete = requestsToComplete
            // Update badge and button
            DispatchQueue.main.async { [unowned self] in
                // Update app badge and button of root album (or default album)
                let uploadInfo: [String : Any] = ["nberOfUploadsToComplete" : self.nberOfUploadsToComplete]
                NotificationCenter.default.post(name: .pwgLeftUploads, object: nil, userInfo: uploadInfo)
            }
        }
    }
    
    // Update cell displaying an upload request
    func updateCell(with identifier:String, stateLabel: String,
                    photoMaxSize: Int16?, progress: Float?, errorMsg: String?) {
        
        var uploadInfo: [String : Any] = ["localIdentifier" : identifier,
                                          "stateLabel" : stateLabel]
        if let photoMaxSize = photoMaxSize {
            uploadInfo.updateValue(photoMaxSize, forKey: "photoMaxSize")
        }
        if let progress = progress {
            uploadInfo.updateValue(progress, forKey: "progressFraction")
        }
        DispatchQueue.main.async {
            // Update UploadQueue cell and button shown in root album (or default album)
            NotificationCenter.default.post(name: .pwgUploadProgress,
                                            object: nil, userInfo: uploadInfo)
        }
    }

    
    // MARK: - Foreground Upload Task Manager
    // Images are uploaded as follows:
    /// - Photos are prepared with appropriate metadata in a format accepted by the server
    /// - Videos are exported in MP4 fomat and uploaded (VideoJS plugin expected)
    /// - Images are uploaded with one of the following methods:
    ///      - pwg.images.upload: old method unable to set the image title
    ///        This requires a call to pwg.images.setInfo to set the title after the transfer.
    ///      - pwg.images.uploadAsync: new method accepting asynchroneous calls
    ///        and setting all parameters like pwg.images.setInfo.
    ///
    /// - Uploads can also be performed in the background with the method pwg.images.uploadAsync
    ///   and the BackgroundTasks farmework (iOS 13+)
    public func findNextImageToUpload() -> Void {
        // Check current queue
        print("\(debugFormatter.string(from: Date())) > findNextImageToUpload() in", queueName())
        print("\(debugFormatter.string(from: Date())) > preparing:\(isPreparing ? "Yes" : "No"), uploading:\(isUploading.count), finishing:\(isFinishing ? "Yes" : "No")")

        autoreleasepool {
            // Update app badge and Upload button in root/default album
            // Considers only uploads to the server to which the user is logged in
            var states: [kPiwigoUploadState] = [.waiting, .preparing, .preparingError,
                                                .preparingFail, .formatError, .prepared,
                                                .uploading, .uploadingError, .uploadingFail, .uploaded,
                                                .finishing, .finishingError]
            nberOfUploadsToComplete = uploadsProvider.getRequests(inStates: states).0.count
    //        return // for debugging background tasks

            // Pause upload manager if:
            /// - app not in the foreground anymore
            /// - executing a background task
            if isPaused || isExecutingBackgroundUploadTask { return }

            // Determine the Power State and if it should wait
            if ProcessInfo.processInfo.isLowPowerModeEnabled || isPaused {
                // Low Power Mode is enabled. Stop transferring images.
                return
            }
            
            // Check network access and status
            if !NetworkVars.isConnectedToWiFi() && UploadVars.wifiOnlyUploading {
                return
            }

            // Interrupted work should be set as if an error was encountered
            /// - case of finishes
            let finishingIDs = uploadsProvider.getRequests(inStates: [.finishing]).1
            if !isFinishing {
                // Transfers encountered an error
                for uploadID in finishingIDs {
                    print("\(debugFormatter.string(from: Date())) >  Interrupted finish —> \(uploadID.uriRepresentation())")
                    uploadsProvider.updateStatusOfUpload(with: uploadID, to: .finishingError, error: JsonError.networkUnavailable.errorDescription) { [unowned self] (_) in
                        self.findNextImageToUpload()
                        return
                    }
                }
            }
            /// - case of transfers (a few transfers may be running in parallel)
            let uploadingIDs = uploadsProvider.getRequests(inStates: [.uploading]).1
            for uploadID in uploadingIDs {
                if !isUploading.contains(uploadID) {
                    // Transfer encountered an error
                    print("\(debugFormatter.string(from: Date())) >  Interrupted transfer —> \(uploadID.uriRepresentation())")
                    uploadsProvider.updateStatusOfUpload(with: uploadID, to: .uploadingError, error: JsonError.networkUnavailable.errorDescription) { [unowned self] (_) in
                        self.findNextImageToUpload()
                        return
                    }
                }
            }
            /// - case of preparations
            let preparingIDs = uploadsProvider.getRequests(inStates: [.preparing]).1
            if !isPreparing {
                // Preparations encountered an error
                for uploadID in preparingIDs {
                    print("\(debugFormatter.string(from: Date())) >  Interrupted preparation —> \(uploadID.uriRepresentation())")
                    uploadsProvider.updateStatusOfUpload(with: uploadID, to: .preparingError, error: UploadError.missingAsset.errorDescription) { [unowned self] (_) in
                        self.findNextImageToUpload()
                        return
                    }
                }
            }

            // How many upload requests did fail?
            let failedUploads = uploadsProvider.getRequests(inStates: [.preparingError, .preparingFail,
                                                                       .uploadingError, .uploadingFail]).1.count
            // Too many failures?
            if failedUploads >= maxNberOfFailedUploads { return }

            // Not finishing and upload request to finish?
            /// Called when:
            /// - uploading with pwg.images.upload because the title cannot be set during the upload.
            /// - uploading with pwg.images.uploadAsync to empty the lounge as from the version 12 of the Piwigo server.
            if !isFinishing,
               let uploadID = uploadsProvider.getRequests(inStates: [.uploaded]).1.first {
                
                // Pause upload manager if the app is not in the foreground anymore
                if isPaused { return }
                
                // Upload file ready, so we start the transfer
                self.finishTransfer(of: uploadID)
                return
            }

            // Not transferring and file ready for transfer?
            if isUploading.count < maxNberOfTransfers,
               let uploadID = uploadsProvider.getRequests(inStates: [.prepared]).1.first {

                // Pause upload manager if the app is not in the foreground anymore
                if isPaused { return }

                // Upload file ready, so we start the transfer
                self.launchTransfer(of: uploadID)
                return
            }
            
            // Not preparing and upload request waiting?
            let nberPrepared = uploadsProvider.getRequests(inStates: [.prepared]).0.count
            if !isPreparing, nberPrepared < maxNberPreparedUploads,
               let uploadID = uploadsProvider.getRequests(inStates: [.waiting]).1.first {

                // Pause upload manager if the app is not in the foreground anymore
                if isPaused { return }

                // Prepare the next upload
                self.prepare(for: uploadID)
                return
            }
            
            // No more image to transfer ;-)
            // Moderate images uploaded by Community regular user
            // Considers only uploads to the server to which the user is logged in
            let finishedUploads = uploadsProvider.getRequests(inStates: [.finished]).1
            if NetworkVars.hasNormalRights,
               NetworkVars.usesCommunityPluginV29, finishedUploads.count > 0 {

                // Pause upload manager if the app is not in the foreground anymore
                if isPaused { return }

                // Moderate uploaded images
                self.moderate(completedRequests: finishedUploads)
                return
            }

            // Suggest to delete images from the Photo Library if the user wanted it.
            // The deletion is suggested when there is no more upload to perform.
            // Note that some uploads may have failed and waiting a user decision.
            states = [.waiting, .preparing, .prepared,
                      .uploading, .uploaded, .finishing]
            if uploadsProvider.getRequests(inStates: states).0.count > 0 { return }
            
            // Upload requests are completed
            // Considers only uploads to the server to which the user is logged in
            let (imageIDs, uploadIDs) = uploadsProvider.getRequests(inStates: [.finished, .moderated],
                                                                    markedForDeletion: true)
            if imageIDs.isEmpty == false, uploadIDs.isEmpty == false {
                print("\(debugFormatter.string(from: Date())) > (\(imageIDs.count),\(uploadIDs.count)) should be deleted")
                self.delete(uploadedImages: imageIDs, with: uploadIDs)
            }
        }
    }

    
    // MARK: - Background Upload Task Manager
    // Images are uploaded sequentially with BackgroundTasks.
    /// - getUploadRequests() returns a series of upload requests to deal with
    /// - photos and videos are prepared sequentially to reduce the memory needs
    /// - uploads are launched in the background with the method pwg.images.uploadAsync
    ///   and the BackgroundTasks farmework (iOS 13+)
    /// - The number of bytes to be transferred is calculated and limited.
    /// - A delay is set between series of upload tasks to prevent server overloads
    /// - Failing tasks are automatically retried by iOS
    /// Use the following command to test the background task:
    /// - e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"org.piwigo.uploadManager"]
    /// - e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateExpirationForTaskWithIdentifier:@"org.piwigo.uploadManager"]
    public var isExecutingBackgroundUploadTask = false
    public let maxNberOfUploadsPerBckgTask = 100                    // i.e. 100 requests to be considered
    public let maxNberOfAutoUploadsPerCheck = 500                   // i.e. do not add more than 500 requests at a time
    public var countOfBytesPrepared = UInt64(0)                     // Total amount of bytes of prepared files
    public var countOfBytesToUpload = 0                             // Total amount of bytes to be sent
    public let maxCountOfBytesToUpload = 50 * 1024 * 1024           // i.e. 50 MB every 30 min (100 MB/hour)
    public var uploadRequestsToPrepare = Set<NSManagedObjectID>()
    public var uploadRequestsToTransfer = Set<NSManagedObjectID>()

    public func initialiseBckgTask(autoUploadOnly: Bool = false,
                                   triggeredByExtension: Bool = false) -> Void {
        // Decisions will be taken for a background task
        isExecutingBackgroundUploadTask = true
        
        // Append auto-upload requests if not called by In-App intent or Extension
        if UploadVars.isAutoUploadActive && !triggeredByExtension {
            appendAutoUploadRequests()
        }
        
        // Reset variables
        countOfBytesPrepared = 0
        countOfBytesToUpload = 0

        // Reset flags and requests to prepare and transfer
        isUploading = Set<NSManagedObjectID>()
        uploadRequestsToPrepare = Set<NSManagedObjectID>()
        uploadRequestsToTransfer = Set<NSManagedObjectID>()

        // First, find upload requests whose transfer did fail
        let failedUploads = uploadsProvider.getRequests(inStates: [.preparingError, .preparingFail,
                                                                   .uploadingError, .uploadingFail],
                                                        markedForAutoUpload: autoUploadOnly).1
        // Too many failures?
        if failedUploads.count >= maxNberOfFailedUploads { return }

        // Will retry a few…
        if failedUploads.count > 0 {
            // Will relaunch transfers with one which failed
            uploadRequestsToTransfer = Set(failedUploads)
            print("\(debugFormatter.string(from: Date())) >•• collected \(uploadRequestsToTransfer.count) failed uploads")
        }
        
        // Second, find upload requests ready for transfer
        let preparedUploads = uploadsProvider.getRequests(inStates: [.prepared],
                                                          markedForAutoUpload: autoUploadOnly).1
        if preparedUploads.count > 0 {
            // Will then launch transfers of prepared uploads
            uploadRequestsToTransfer = uploadRequestsToTransfer
                .union(Set(preparedUploads[..<min(maxNberOfUploadsPerBckgTask,preparedUploads.count)]))
            print("\(debugFormatter.string(from: Date())) >•• collected \(min(maxNberOfUploadsPerBckgTask,preparedUploads.count)) prepared uploads")
        }
        
        // Finally, get list of upload requests to prepare
        let diff = maxNberPreparedUploads - uploadRequestsToTransfer.count
        if diff <= 0 { return }
        let requestsToPrepare = uploadsProvider.getRequests(inStates: [.waiting],
                                                            markedForAutoUpload: autoUploadOnly).1
        print("\(debugFormatter.string(from: Date())) >•• collected \(min(diff, requestsToPrepare.count)) uploads to prepare")
        uploadRequestsToPrepare = Set(requestsToPrepare[..<min(diff, requestsToPrepare.count)])
    }
    
    public func resumeTransfers() -> Void {
        // Get active upload tasks and initialise isUploading
        let taskContext = DataController.shared.bckgContext
        let frgdSession: URLSession = UploadSessions.shared.frgdSession
        let bckgSession: URLSession = UploadSessions.shared.bckgSession

        frgdSession.getAllTasks { [unowned self] uploadTasks in
            // Loop over the tasks launched in the foreground
            for task in uploadTasks {
                switch task.state {
                case .running:
                    // Retrieve upload request properties
                    guard let objectURIstr = task.originalRequest?.value(forHTTPHeaderField: UploadVars.HTTPuploadID) else { continue }
                    guard let objectURI = URL(string: objectURIstr) else {
                        print("\(debugFormatter.string(from: Date())) > task \(task.taskIdentifier) | no object URI!")
                        continue
                    }
                    guard let uploadID = taskContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: objectURI) else {
                        print("\(debugFormatter.string(from: Date())) > task \(task.taskIdentifier) | no objectID!")
                        continue
                    }
                    // Remembers that this upload request is being dealt with
                    print("\(debugFormatter.string(from: Date())) >> is uploading: \(uploadID)")
                    // Remembers that this upload request is being dealt with
                    self.isUploading.insert(uploadID)

                    // Avoids duplicates
                    uploadRequestsToTransfer.remove(uploadID)
                    uploadRequestsToPrepare.remove(uploadID)

                default:
                    continue
                }
            }

            // Continue with background tasks
            bckgSession.getAllTasks { [unowned self] uploadTasks in
                // Loop over the tasks
                for task in uploadTasks {
                    switch task.state {
                    case .running:
                        // Retrieve upload request properties
                        guard let objectURIstr = task.originalRequest?.value(forHTTPHeaderField: UploadVars.HTTPuploadID) else { continue }
                        guard let objectURI = URL(string: objectURIstr) else {
                            print("\(debugFormatter.string(from: Date())) > task \(task.taskIdentifier) | no object URI!")
                            continue
                        }
                        guard let uploadID = taskContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: objectURI) else {
                            print("\(debugFormatter.string(from: Date())) > task \(task.taskIdentifier) | no objectID!")
                            continue
                        }
                        // Remembers that this upload request is being dealt with
                        print("\(debugFormatter.string(from: Date())) >> is uploading: \(uploadID)")
                        // Remembers that this upload request is being dealt with
                        self.isUploading.insert(uploadID)
                        
                        // Avoids duplicates
                        uploadRequestsToTransfer.remove(uploadID)
                        uploadRequestsToPrepare.remove(uploadID)

                    default:
                        continue
                    }
                }

                // Relaunch transfers if necessary and possible
                if self.isUploading.count < maxNberOfTransfers,
                   let uploadID = self.uploadRequestsToTransfer.first {
                    // Launch transfer
                    self.launchTransfer(of: uploadID)
                }
            }
        }
    }
        
    public func appendUploadRequestsToPrepareToBckgTask() -> Void {
        // Add image preparation followed by transfer operations
        if countOfBytesPrepared < UInt64(maxCountOfBytesToUpload),
           let uploadID = uploadRequestsToPrepare.first {
            // Prepare image for transfer
            prepare(for: uploadID)
        }
        if uploadRequestsToPrepare.isEmpty == false {
            // Remove objectID
            uploadRequestsToPrepare.removeFirst()
        }
    }
    
    
    // MARK: - Prepare image
    public let maxNberPreparedUploads = 10
    private var _isPreparing = false
    private var isPreparing: Bool {
        get {
            return _isPreparing
        }
        set(isPreparing) {
            _isPreparing = isPreparing
        }
    }

    func prepare(for uploadID: NSManagedObjectID) -> Void {
        print("\(debugFormatter.string(from: Date())) >> prepare \(uploadID.uriRepresentation())")

        // Update upload status
        isPreparing = true

        // Retrieve upload request properties
        var uploadProperties: UploadProperties!
        let taskContext = DataController.shared.bckgContext
        do {
            let upload = try taskContext.existingObject(with: uploadID)
            if upload.isFault {
                // The upload request is not fired yet.
                upload.willAccessValue(forKey: nil)
                uploadProperties = (upload as! Upload).getProperties()
                upload.didAccessValue(forKey: nil)
            } else {
                uploadProperties = (upload as! Upload).getProperties()
            }
        }
        catch {
            print("\(debugFormatter.string(from: Date())) > missing Core Data object \(uploadID)!")
            // Request not available…!?
            uploadsProvider.updateStatusOfUpload(with: uploadID, to: .preparingFail, error: UploadError.missingData.errorDescription) { [unowned self] (_) in
                // Investigate next upload request?
                self.didEndPreparation()
            }
            return
        }

        // Update UI
        if !isExecutingBackgroundUploadTask {
            updateCell(with: uploadProperties.localIdentifier,
                       stateLabel: kPiwigoUploadState.preparing.stateInfo,
                       photoMaxSize: Int16(uploadProperties.photoMaxSize),
                       progress: nil, errorMsg: "")
        }
        
        // Add category to list of recent albums
        let userInfo = ["categoryId": uploadProperties.category]
        NotificationCenter.default.post(name: .pwgAddRecentAlbum, object: nil, userInfo: userInfo)

        // Determine from where the file comes from:
        // => Photo Library: use PHAsset local identifier
        // => UIPasteborad: use identifier of type "Clipboard-yyyyMMdd-HHmmssSSSS-typ-#"
        //    where "typ" is "img" (photo) or "mov" (video).
        // => Intent: use identifier of type "Intent-yyyyMMdd-HHmmssSSSS-typ-#"
        //    where "typ" is "img" (photo) or "mov" (video).
        if uploadProperties.localIdentifier.hasPrefix(kIntentPrefix) {
            // Case of an image submitted by an intent
            prepareImageFromIntent(for: uploadID, with: uploadProperties)
        } else if uploadProperties.localIdentifier.hasPrefix(kClipboardPrefix) {
            // Case of an image retrieved from the pasteboard
            prepareImageInPasteboard(for: uploadID, with: uploadProperties)
        } else {
            // Case of an image from the local Photo Library
            prepareImageInPhotoLibrary(for: uploadID, with: uploadProperties)
        }
    }
    
    private func prepareImageFromIntent(for uploadID: NSManagedObjectID, with properties: UploadProperties) {
        // Will update upload properties
        var uploadProperties = properties

        // Determine non-empty unique file name and extension from identifier
        var files = [URL]()
        do {
            // Get complete filename by searching in the Uploads directory
            files = try FileManager.default.contentsOfDirectory(at: applicationUploadsDirectory,
                        includingPropertiesForKeys: nil,
                        options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
        }
        catch {
            files = []
        }
        guard files.count > 0, let fileURL = files.filter({$0.lastPathComponent.hasPrefix(uploadProperties.localIdentifier)}).first else {
            // File not available… deleted?
            uploadsProvider.updateStatusOfUpload(with: uploadID, to: .preparingFail, error: UploadError.missingAsset.errorDescription) { [unowned self] (_) in

                // Update UI
                updateCell(with: uploadProperties.localIdentifier, stateLabel: uploadProperties.stateLabel,
                           photoMaxSize: nil, progress: nil, errorMsg: kPiwigoUploadState.preparingFail.stateInfo)
 
                // Investigate next upload request?
                self.didEndPreparation()
            }
            return
        }
        
        // Add prefix if requested by user
        var fileName = uploadProperties.fileName
        if uploadProperties.prefixFileNameBeforeUpload {
            if !fileName.hasPrefix(uploadProperties.defaultPrefix) {
                fileName = uploadProperties.defaultPrefix + fileName
            }
        }
        
        // Piwigo 2.10.2 supports the 3-byte UTF-8, not the standard UTF-8 (4 bytes)
        uploadProperties.fileName = NetworkUtilities.utf8mb3String(from: fileName)

        // Launch preparation job (limited to stripping metadata)
        if fileURL.lastPathComponent.contains("img") {
            uploadProperties.isVideo = false

            // Update state of upload
            uploadProperties.requestState = .preparing
            uploadsProvider.updatePropertiesOfUpload(with: uploadID, properties: uploadProperties) { [unowned self] (_) in
                // Launch preparation job
                self.prepareImage(atURL: fileURL, for: uploadID, with: uploadProperties)
            }
            return
        }
    }
    
    private func prepareImageInPasteboard(for uploadID: NSManagedObjectID, with properties: UploadProperties) {
        // Will update upload properties
        var uploadProperties = properties

        // Determine non-empty unique file name and extension from identifier
        var files = [URL]()
        do {
            // Get complete filename by searching in the Uploads directory
            files = try FileManager.default.contentsOfDirectory(at: applicationUploadsDirectory,
                        includingPropertiesForKeys: nil,
                        options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
        }
        catch {
            files = []
        }
        guard files.count > 0, let fileURL = files.filter({$0.absoluteString.contains(uploadProperties.localIdentifier)}).first else {
            // File not available… deleted?
            uploadsProvider.updateStatusOfUpload(with: uploadID, to: .preparingFail, error: UploadError.missingAsset.errorDescription) { [unowned self] (_) in

                // Update UI
                updateCell(with: uploadProperties.localIdentifier, stateLabel: uploadProperties.stateLabel,
                           photoMaxSize: nil, progress: nil, errorMsg: kPiwigoUploadState.preparingFail.stateInfo)
 
                // Investigate next upload request?
                self.didEndPreparation()
            }
            return
        }
        var fileName = fileURL.lastPathComponent

        // Check/update serverFileTypes if possible
        let fileTypes = UploadVars.serverFileTypes
        if fileTypes.isEmpty == false {
            uploadProperties.serverFileTypes = fileTypes
        }

        // Launch preparation job if file format accepted by Piwigo server
        let fileExt = fileURL.pathExtension.lowercased()
        if fileName.contains("img") {
            uploadProperties.isVideo = false

            // Set filename by
            /// - removing the "Clipboard-" prefix i.e. kClipboardPrefix
            /// - removing the "SSSS-img-#" suffix i.e. "SSSS%@-#" where %@ is kImageSuffix
            /// - adding the file extension
            if let prefixRange = fileName.range(of: kClipboardPrefix),
               let suffixRange = fileName.range(of: kImageSuffix) {
                fileName = String(fileName[prefixRange.upperBound..<suffixRange.lowerBound].dropLast(4)) + ".\(fileExt)"
            }

            // Add prefix if requested by user
            if uploadProperties.prefixFileNameBeforeUpload {
                if !fileName.hasPrefix(uploadProperties.defaultPrefix) {
                    fileName = uploadProperties.defaultPrefix + fileName
                }
            }
            uploadProperties.fileName = fileName

            // Chek that the image format is accepted by the Piwigo server
            if uploadProperties.serverFileTypes.contains(fileExt) {
                // Image file format accepted by the Piwigo server
                // Update state of upload
                uploadProperties.requestState = .preparing
                uploadsProvider.updatePropertiesOfUpload(with: uploadID, properties: uploadProperties) { [unowned self] (_) in
                    // Launch preparation job
                    self.prepareImage(atURL: fileURL, for: uploadID, with: uploadProperties)
                }
                return
            }
            
            // Try to convert image if JPEG format is accepted by Piwigo server
            if uploadProperties.serverFileTypes.contains("jpg"),
               acceptedImageFormats.contains(fileExt) {
                // Try conversion to JPEG
                print("\(debugFormatter.string(from: Date())) > converting photo \(uploadProperties.fileName)…")
                
                // Update state of upload
                uploadProperties.requestState = .preparing
                uploadsProvider.updatePropertiesOfUpload(with: uploadID, properties: uploadProperties) { [unowned self] (_) in
                    // Launch preparation job
                    self.prepareImage(atURL: fileURL, for: uploadID, with: uploadProperties)
                }
                return
            }
            
            // Image file format cannot be accepted by the Piwigo server
            uploadProperties.requestState = .formatError

            // Update UI
            updateCell(with: uploadProperties.localIdentifier, stateLabel: uploadProperties.stateLabel,
                       photoMaxSize: nil, progress: nil, errorMsg: kPiwigoUploadState.formatError.stateInfo)
            
            // Update upload request
            uploadsProvider.updatePropertiesOfUpload(with: uploadID, properties: uploadProperties) { [unowned self] (_) in
                // Investigate next upload request?
                self.didEndPreparation()
            }
        }
        else if fileName.contains("mov") {
            uploadProperties.isVideo = true

            // Set filename by
            /// - removing the "Clipboard-" prefix i.e. kClipboardPrefix
            /// - removing the "SSSS-mov-#" suffix i.e. "SSSS%@-#" where %@ is kMovieSuffix
            /// - adding the file extension
            if let prefixRange = fileName.range(of: kClipboardPrefix),
               let suffixRange = fileName.range(of: kMovieSuffix) {
                fileName = String(fileName[prefixRange.upperBound..<suffixRange.lowerBound].dropLast(4)) + ".\(fileExt)"
            }

            // Add prefix if requested by user
            if uploadProperties.prefixFileNameBeforeUpload {
                if !fileName.hasPrefix(uploadProperties.defaultPrefix) {
                    fileName = uploadProperties.defaultPrefix + fileName
                }
            }
            uploadProperties.fileName = fileName

            // Chek that the video format is accepted by the Piwigo server
            if uploadProperties.serverFileTypes.contains(fileExt) {
                // Video file format accepted by the Piwigo server
                print("\(debugFormatter.string(from: Date())) > preparing video \(uploadProperties.fileName)…")

                // Update state of upload
                uploadProperties.requestState = .preparing
                uploadsProvider.updatePropertiesOfUpload(with: uploadID, properties: uploadProperties) { [unowned self] (_) in
                    // Launch preparation job
                    self.prepareVideo(atURL: fileURL, for: uploadID, with: uploadProperties)
                }
                return
            }
            
            // Convert video if MP4 format is accepted by Piwigo server
            if uploadProperties.serverFileTypes.contains("mp4"),
               acceptedMovieFormats.contains(fileExt) {
                // Try conversion to MP4
                print("\(debugFormatter.string(from: Date())) > converting video \(uploadProperties.fileName)…")

                // Update state of upload
                uploadProperties.requestState = .preparing
                uploadsProvider.updatePropertiesOfUpload(with: uploadID, properties: uploadProperties) { [unowned self] (_) in
                    // Launch preparation job
                    self.convertVideo(atURL: fileURL, for: uploadID, with: uploadProperties)
                }
                return
            }
            
            // Video file format cannot be accepted by the Piwigo server
            uploadProperties.requestState = .formatError

            // Update UI
            updateCell(with: uploadProperties.localIdentifier, stateLabel: uploadProperties.stateLabel,
                       photoMaxSize: nil, progress: nil, errorMsg: kPiwigoUploadState.formatError.stateInfo)
            
            // Update upload request
            uploadsProvider.updatePropertiesOfUpload(with: uploadID, properties: uploadProperties) { [unowned self] (_) in
                // Investigate next upload request?
                self.didEndPreparation()
            }
        }
        else {
            // Unknown type
            uploadProperties.requestState = .formatError

            // Update UI
            updateCell(with: uploadProperties.localIdentifier, stateLabel: uploadProperties.stateLabel,
                       photoMaxSize: nil, progress: nil, errorMsg: kPiwigoUploadState.formatError.stateInfo)
            
            // Update upload request
            uploadsProvider.updatePropertiesOfUpload(with: uploadID, properties: uploadProperties) { [unowned self] (_) in
                // Investigate next upload request?
                self.didEndPreparation()
            }
        }
    }
    
    private func prepareImageInPhotoLibrary(for uploadID: NSManagedObjectID,
                                            with properties: UploadProperties) {
        // Will update upload properties
        var uploadProperties = properties

        // Retrieve image asset
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [uploadProperties.localIdentifier], options: nil)
        guard assets.count > 0, let originalAsset = assets.firstObject else {
            // Asset not available… deleted?
            uploadsProvider.updateStatusOfUpload(with: uploadID, to: .preparingFail, error: UploadError.missingAsset.errorDescription) { [unowned self] (_) in
                // Investigate next upload request?
                self.didEndPreparation()
            }
            return
        }

        // Retrieve creation date
        if let creationDate = originalAsset.creationDate {
            uploadProperties.creationDate = creationDate.timeIntervalSinceReferenceDate
        } else {
            uploadProperties.creationDate = Date().timeIntervalSinceReferenceDate
        }
        
        // Get URL of image file to be stored into Piwigo/Uploads directory
        // and deletes temporary image file if exists (incomplete previous attempt?)
        let fileURL = getUploadFileURL(from: uploadProperties, withSuffix: kOriginalSuffix, deleted: true)

        // Retrieve asset resources
        var resources = PHAssetResource.assetResources(for: originalAsset)
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true
        let edited = resources.first(where: { $0.type == .fullSizePhoto || $0.type == .fullSizeVideo })
        let original = resources.first(where: { $0.type == .photo || $0.type == .video || $0.type == .audio })
        let resource = edited ?? original ?? resources.first(where: { $0.type == .alternatePhoto})
        let originalFilename = original?.originalFilename ?? ""

        // Priority to original media data
        if let res = resource {
            // Store original data in file
            PHAssetResourceManager.default().writeData(for: res, toFile: fileURL,
                                                       options: options) { error in
                // Piwigo 2.10.2 supports the 3-byte UTF-8, not the standard UTF-8 (4 bytes)
                var utf8mb3Filename = NetworkUtilities.utf8mb3String(from: originalFilename)
                
                // If encodedFileName is empty, build one from the current date
                if utf8mb3Filename.count == 0 {
                    // No filename => Build filename from creation date
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyyMMdd-HHmmssSSSS"
                    if let creation = originalAsset.creationDate {
                        utf8mb3Filename = dateFormatter.string(from: creation)
                    } else {
                        utf8mb3Filename = dateFormatter.string(from: Date())
                    }

                    // Filename extension required by Piwigo so that it knows how to deal with it
                    if originalAsset.mediaType == .image {
                        // Adopt JPEG photo format by default, will be rechecked
                        utf8mb3Filename = URL(fileURLWithPath: utf8mb3Filename).appendingPathExtension("jpg").lastPathComponent
                    } else if originalAsset.mediaType == .video {
                        // Videos are exported in MP4 format
                        utf8mb3Filename = URL(fileURLWithPath: utf8mb3Filename).appendingPathExtension("mp4").lastPathComponent
                    } else if originalAsset.mediaType == .audio {
                        // Arbitrary extension, not managed yet
                        utf8mb3Filename = URL(fileURLWithPath: utf8mb3Filename).appendingPathExtension("m4a").lastPathComponent
                    }
                }
                
                uploadProperties.fileName = utf8mb3Filename
                self.dispatchImage(asset: originalAsset, atURL:fileURL,
                                   for: uploadID, with: uploadProperties)
            }
        }
        else {
            // Asset not available… deleted?
            uploadsProvider.updateStatusOfUpload(with: uploadID, to: .preparingFail, error: UploadError.missingAsset.errorDescription) { [unowned self] (_) in
                // Investigate next upload request?
                self.didEndPreparation()
            }
        }
        
        // Release memory
        resources.removeAll(keepingCapacity: false)
    }
    
    private func dispatchImage(asset originalAsset:PHAsset, atURL uploadFileURL:URL,
                               for uploadID:NSManagedObjectID, with properties:UploadProperties) {
        // Will update upload properties
        var uploadProperties = properties

        // Append prefix provided by user if requested
        let fileName = properties.fileName
        if uploadProperties.prefixFileNameBeforeUpload {
            if !fileName.hasPrefix(uploadProperties.defaultPrefix) {
                uploadProperties.fileName = uploadProperties.defaultPrefix + fileName
            }
        }
        
        // Check/update serverFileTypes if possible
        let fileTypes = UploadVars.serverFileTypes
        if fileTypes.isEmpty == false {
            uploadProperties.serverFileTypes = fileTypes
        }
        
        // Launch preparation job if file format accepted by Piwigo server
        let fileExt = (URL(fileURLWithPath: fileName).pathExtension).lowercased()
        switch originalAsset.mediaType {
        case .image:
            uploadProperties.isVideo = false
            // Chek that the image format is accepted by the Piwigo server
            if uploadProperties.serverFileTypes.contains(fileExt) {
                // Image file format accepted by the Piwigo server
                // Update state of upload
                uploadProperties.requestState = .preparing
                uploadsProvider.updatePropertiesOfUpload(with: uploadID, properties: uploadProperties) { [unowned self] (_) in
                    // Launch preparation job
                    self.prepareImage(atURL: uploadFileURL, for: uploadID, with: uploadProperties)
                }
                return
            }
            // Convert image if JPEG format is accepted by Piwigo server
            if uploadProperties.serverFileTypes.contains("jpg"),
               acceptedImageFormats.contains(fileExt) {
                // Try conversion to JPEG
                print("\(debugFormatter.string(from: Date())) > converting photo \(uploadProperties.fileName)…")
                
                // Update state of upload
                uploadProperties.requestState = .preparing
                uploadsProvider.updatePropertiesOfUpload(with: uploadID, properties: uploadProperties) { [unowned self] (_) in
                    // Launch preparation job
                    self.convertImage(atURL: uploadFileURL, for: uploadID, with: uploadProperties)
                }
                return
            }

            // Image file format cannot be accepted by the Piwigo server
            uploadProperties.requestState = .formatError

            // Update UI
            updateCell(with: uploadProperties.localIdentifier, stateLabel: uploadProperties.stateLabel,
                       photoMaxSize: nil, progress: nil, errorMsg: kPiwigoUploadState.formatError.stateInfo)
            
            // Update upload request
            uploadsProvider.updatePropertiesOfUpload(with: uploadID, properties: uploadProperties) { [unowned self] (_) in
                // Investigate next upload request?
                self.didEndPreparation()
            }
//            showError(withTitle: NSLocalizedString("imageUploadError_title", comment: "Image Upload Error"), andMessage: NSLocalizedString("imageUploadError_format", comment: "Sorry, image files with extensions .\(fileExt.uppercased()) and .jpg are not accepted by the Piwigo server."), forRetrying: false, withImage: nextImageToBeUploaded)

        case .video:
            uploadProperties.isVideo = true
            // Chek that the video format is accepted by the Piwigo server
            if uploadProperties.serverFileTypes.contains(fileExt) {
                // Video file format accepted by the Piwigo server
                print("\(debugFormatter.string(from: Date())) > preparing video \(uploadProperties.fileName)…")

                // Update state of upload
                uploadProperties.requestState = .preparing
                uploadsProvider.updatePropertiesOfUpload(with: uploadID, properties: uploadProperties) { [unowned self] (_) in
                    // Launch preparation job
//                    self.prepareVideo(atURL: uploadFileURL, for: uploadID, with: uploadProperties)
                    self.prepareVideo(ofAsset: originalAsset, for: uploadID, with: uploadProperties)
                }
                return
            }
            // Convert video if MP4 format is accepted by Piwigo server
            if uploadProperties.serverFileTypes.contains("mp4"),
               acceptedMovieFormats.contains(fileExt) {
                // Try conversion to MP4
                print("\(debugFormatter.string(from: Date())) > converting video \(uploadProperties.fileName)…")

                // Update state of upload
                uploadProperties.requestState = .preparing
                uploadsProvider.updatePropertiesOfUpload(with: uploadID, properties: uploadProperties) { [unowned self] (_) in
                    // Launch preparation job
//                    self.convertVideo(atURL: uploadFileURL, for: uploadID, with: uploadProperties)
                    self.convertVideo(ofAsset: originalAsset, for: uploadID, with: uploadProperties)
                }
                return
            }
            // Video file format cannot be accepted by the Piwigo server
            uploadProperties.requestState = .formatError

            // Update UI
            updateCell(with: uploadProperties.localIdentifier, stateLabel: uploadProperties.stateLabel,
                       photoMaxSize: nil, progress: nil, errorMsg: kPiwigoUploadState.formatError.stateInfo)
            
            // Update upload request
            uploadsProvider.updatePropertiesOfUpload(with: uploadID, properties: uploadProperties) { [unowned self] (_) in
                // Investigate next upload request?
                self.didEndPreparation()
            }
//                showError(withTitle: NSLocalizedString("videoUploadError_title", comment: "Video Upload Error"), andMessage: NSLocalizedString("videoUploadError_format", comment: "Sorry, video files with extension .\(fileExt.uppercased()) are not accepted by the Piwigo server."), forRetrying: false, withImage: uploadToPrepare)

        case .audio:
            // Update state of upload: Not managed by Piwigo iOS yet…
            uploadProperties.requestState = .formatError
            uploadsProvider.updatePropertiesOfUpload(with: uploadID, properties: uploadProperties) { [unowned self] (_) in
                // Investigate next upload request?
                self.didEndPreparation()
            }
//            showError(withTitle: NSLocalizedString("audioUploadError_title", comment: "Audio Upload Error"), andMessage: NSLocalizedString("audioUploadError_format", comment: "Sorry, audio files are not supported by Piwigo Mobile yet."), forRetrying: false, withImage: uploadToPrepare)

        case .unknown:
            fallthrough
        default:
            // Update state of upload request: Unknown format
            uploadProperties.requestState = .formatError
            uploadsProvider.updatePropertiesOfUpload(with: uploadID, properties: uploadProperties) { [unowned self] (_) in
                // Investigate next upload request?
                self.didEndPreparation()
            }
        }
    }

    func didEndPreparation() {
        _isPreparing = false
        if isExecutingBackgroundUploadTask {
            if countOfBytesToUpload < maxCountOfBytesToUpload {
                // In background task, launch a transfer if possible
                let preparedUploadRequests = uploadsProvider.getRequests(inStates: [.prepared]).1
                let nberOfFailedUploads = uploadsProvider.getRequests(inStates: [.preparingError, .preparingFail,
                                                                                 .uploadingError, .uploadingFail,
                                                                                 .finishingError]).1.count
                if isUploading.count < maxNberOfTransfers,
                   nberOfFailedUploads < maxNberOfFailedUploads,
                   let uploadID = preparedUploadRequests.first {
                    launchTransfer(of: uploadID)
                }
            }
        } else {
            // In foreground, always consider next file
            if isUploading.count <= maxNberOfTransfers, !isFinishing {
                findNextImageToUpload()
            }
        }
    }

    
    // MARK: - Transfer image
    let maxNberOfTransfers = 1
    public let maxNberOfFailedUploads = 5
    private var _isUploading = Set<NSManagedObjectID>()
    public var isUploading: Set<NSManagedObjectID> {
        get { return _isUploading }
        set(isUploading) { _isUploading = isUploading }
    }

    public func launchTransfer(of uploadID: NSManagedObjectID) -> Void {
        print("\(debugFormatter.string(from: Date())) >> launch transfer of \(uploadID.uriRepresentation())")

        // Update list of transfers
        if isUploading.contains(uploadID) { return }
        isUploading.insert(uploadID)

        // Retrieve upload request properties
        var uploadProperties: UploadProperties!
        let taskContext = DataController.shared.bckgContext
        do {
            let upload = try taskContext.existingObject(with: uploadID)
            if upload.isFault {
                // The upload request is not fired yet.
                upload.willAccessValue(forKey: nil)
                uploadProperties = (upload as! Upload).getProperties()
                upload.didAccessValue(forKey: nil)
            } else {
                uploadProperties = (upload as! Upload).getProperties()
            }
        }
        catch {
            print("\(debugFormatter.string(from: Date())) > missing Core Data object \(uploadID.uriRepresentation())!")
            // Request not available…!?
            uploadsProvider.updateStatusOfUpload(with: uploadID, to: .uploadingFail, error: UploadError.missingData.errorDescription) { [unowned self] (_) in
                // Investigate next upload request?
                self.didEndTransfer(for: uploadID)
            }
            return
        }

        // Reset counter of progress bar in case we repeat the transfer
        UploadSessions.shared.clearCounter(withID: uploadProperties.localIdentifier)

        // Update UI
        if !isExecutingBackgroundUploadTask {
            // Initialise the progress bar
            updateCell(with: uploadProperties.localIdentifier,
                       stateLabel: kPiwigoUploadState.uploading.stateInfo,
                       photoMaxSize: nil, progress: Float(0), errorMsg: nil)
        }

        // Choose recent method when called by:
        /// - admins as from Piwigo server 11 or previous versions with the uploadAsync plugin installed.
        /// - Community users as from Piwigo 12.
        if NetworkVars.usesUploadAsync || isExecutingBackgroundUploadTask {
            // Prepare transfer
            self.transferInBackgroundImage(for: uploadID, with: uploadProperties)

            // Do not prepare next image in background task (already scheduled)
            if self.isExecutingBackgroundUploadTask { return }

            // Stop here if there no image to prepare
            if uploadsProvider.getRequests(inStates: [.waiting]).0.count == 0 { return }

            // Should we prepare the next image in parallel?
            let uploadIDsToPrepare = uploadsProvider.getRequests(inStates: [.waiting]).1
            let nberOfFailedUploads = uploadsProvider.getRequests(inStates: [.preparingError, .preparingFail,
                                                                             .uploadingError, .uploadingFail,
                                                                             .finishingError]).1.count
            if !self.isPreparing, let uploadID = uploadIDsToPrepare.first,
               nberOfFailedUploads < maxNberOfFailedUploads {

                // Prepare the next upload
                self.isPreparing = true
                self.prepare(for: uploadID)
                return
            }
        }
        else {
            // Update state of upload request and start transfer
            uploadsProvider.updateStatusOfUpload(with: uploadID, to: .uploading, error: "") { [unowned self] (_) in
                // Transfer image
                self.transferImage(for: uploadID, with: uploadProperties)

                // Stop here if there no image to prepare
                if uploadsProvider.getRequests(inStates: [.waiting]).1.count == 0 { return }

                // Should we prepare the next image in parallel?
                let uploadIDsToPrepare = uploadsProvider.getRequests(inStates: [.waiting]).1
                let nberOfFailedUploads = uploadsProvider.getRequests(inStates: [.preparingError, .preparingFail,
                                                                                 .uploadingError, .uploadingFail,
                                                                                 .finishingError]).1.count
                if !self.isPreparing, let uploadID = uploadIDsToPrepare.first,
                   nberOfFailedUploads < maxNberOfFailedUploads {

                    // Prepare the next upload
                    self.isPreparing = true
                    self.prepare(for: uploadID)
                    return
                }
            }
        }
    }

    func didEndTransfer(for uploadID: NSManagedObjectID) {
        // Update list of current uploads
        if let index = isUploading.firstIndex(where: {$0 == uploadID}) {
            isUploading.remove(at: index)
        }
        
        // Pursue the work…
        if isExecutingBackgroundUploadTask {
            if countOfBytesToUpload < maxCountOfBytesToUpload {
                // In background task, launch a transfer if possible
                let preparedUploadRequests = uploadsProvider.getRequests(inStates: [.prepared]).1
                let nberOfFailedUploads = uploadsProvider.getRequests(inStates: [.preparingError, .preparingFail,
                                                                                 .uploadingError, .uploadingFail,
                                                                                 .finishingError]).1.count
                if isUploading.count < maxNberOfTransfers,
                   nberOfFailedUploads < maxNberOfFailedUploads,
                   let uploadID = preparedUploadRequests.first {
                    launchTransfer(of: uploadID)
                }
            } else {
                debugPrint("\(debugFormatter.string(from: Date())) >•• didEndTransfer | STOP (\(countOfBytesToUpload) transferred)")
            }
        } else {
            // In foreground, always consider next file
            if !isPreparing, isUploading.count <= maxNberOfTransfers, !isFinishing {
                findNextImageToUpload()
            }
        }
    }

    
    // MARK: - Finish transfer

    private var _isFinishing = false
    private var isFinishing: Bool {
        get {
            return _isFinishing
        }
        set(isFinishing) {
            _isFinishing = isFinishing
        }
    }

    private func finishTransfer(of uploadID: NSManagedObjectID) {
        print("\(debugFormatter.string(from: Date())) >> finish transfers of \(uploadID.uriRepresentation())")

        // Update upload status
        isFinishing = true
        
        // Retrieve upload request properties
        var uploadProperties: UploadProperties!
        let taskContext = DataController.shared.bckgContext
        do {
            let upload = try taskContext.existingObject(with: uploadID)
            if upload.isFault {
                // The upload request is not fired yet.
                upload.willAccessValue(forKey: nil)
                uploadProperties = (upload as! Upload).getProperties()
                upload.didAccessValue(forKey: nil)
            } else {
                uploadProperties = (upload as! Upload).getProperties()
            }
        }
        catch {
            print("\(debugFormatter.string(from: Date())) > missing Core Data object \(uploadID)!")
            // Request not available…!?
            uploadsProvider.updateStatusOfUpload(with: uploadID, to: .finishingFail, error: UploadError.missingData.errorDescription) { [unowned self] (_) in
                // Investigate next upload request?
                self.didFinishTransfer()
            }
            return
        }

        // Update UI
        if !isExecutingBackgroundUploadTask {
            updateCell(with: uploadProperties.localIdentifier,
                       stateLabel: kPiwigoUploadState.finishing.stateInfo,
                       photoMaxSize: Int16(uploadProperties.photoMaxSize),
                       progress: nil, errorMsg: "")
        }
        
        // Update state of upload resquest and finish upload
        uploadsProvider.updateStatusOfUpload(with: uploadID, to: .finishing, error: "") {
            [unowned self] (_) in
            // Work depends on Piwigo server version
            if "12.0.0".compare(NetworkVars.pwgVersion, options: .numeric) != .orderedDescending {
                // Uploaded with pwg.images.uploadAsync -> Empty the lounge
                self.emptyLounge(for: uploadID, with: uploadProperties)
            } else {
                // Uploaded with pwg.images.upload -> Set image title.
                self.setImageParameters(for: uploadID, with: uploadProperties)
            }
        }
    }

    func didFinishTransfer() {
        _isFinishing = false
        if !isPreparing, isUploading.count <= maxNberOfTransfers {
            findNextImageToUpload()
        }
    }


    // MARK: - Uploaded Images Management
    
//    private func emptyLounge(for requests: [NSManagedObjectID]) -> Void
//    {
//        // Get upload requests of uploaded images
//        var uploadedImages = [(NSManagedObjectID, UploadProperties)]()
//        requests.forEach { (uploadID) in
//            // Retrieve upload request properties
//            var uploadProperties: UploadProperties!
//            let taskContext = DataController.shared.privateManagedObjectContext
//            do {
//                let upload = try taskContext.existingObject(with: uploadID)
//                if upload.isFault {
//                    // The upload request is not fired yet.
//                    upload.willAccessValue(forKey: nil)
//                    uploadProperties = (upload as! Upload).getProperties()
//                    upload.didAccessValue(forKey: nil)
//                } else {
//                    uploadProperties = (upload as! Upload).getProperties()
//                }
//                uploadedImages.append((uploadID, uploadProperties))
//            }
//            catch {
//                debugPrint("\(debugFormatter.string(from: Date())) > missing Core Data object \(uploadID.uriRepresentation())!") // Will retry later…
//                return
//            }
//        }
//
//        // Get list of categories
//        let categories = IndexSet(uploadedImages.map({Int($0.1.category)}))
//
//        // Process images by category
//        for categoryId in categories {
//            // Set list of images to moderate in that category
//            let categoryImages = uploadedImages.filter({ $0.1.category == categoryId})
//            let imageIds = String(categoryImages.map( { "\($0.1.imageId)," } )
//                .reduce("", +).dropLast())
//
//            // Moderate uploaded images
//            processImages(withIds: imageIds, inCategory: categoryId) { success in
//                if !success { return }    // Will retry later
//
//                // Update state of upload requests
//                var count = 0
//                categoryImages.forEach { (uploadRequest) in
//                    // Update upload requests to remember that the moderation was requested
//                    self.uploadsProvider.updateStatusOfUpload(with: uploadRequest.0,
//                                                              to: .finished, error: "") { [unowned self] _ in
//                        // Did we update all requests?
//                        count += 1
//                        if count == categoryImages.count {
//                            // We still have to moderate and delete images
//                            self.findNextImageToUpload()
//                        }
//                    }
//                }
//            }
//        }
//    }
    
    private func moderate(completedRequests: [NSManagedObjectID]) -> Void
    {
        // Get completed upload requests
        var uploadedImages = [(NSManagedObjectID, UploadProperties)]()
        completedRequests.forEach { (uploadID) in
            // Retrieve upload request properties
            var uploadProperties: UploadProperties!
            let taskContext = DataController.shared.bckgContext
            do {
                let upload = try taskContext.existingObject(with: uploadID)
                if upload.isFault {
                    // The upload request is not fired yet.
                    upload.willAccessValue(forKey: nil)
                    uploadProperties = (upload as! Upload).getProperties()
                    upload.didAccessValue(forKey: nil)
                } else {
                    uploadProperties = (upload as! Upload).getProperties()
                }
                uploadedImages.append((uploadID, uploadProperties))
            }
            catch {
                debugPrint("\(debugFormatter.string(from: Date())) > missing Core Data object \(uploadID.uriRepresentation())!") // Will retry later…
                return
            }
        }

        // Get list of categories
        let categories = IndexSet(uploadedImages.map({Int($0.1.category)}))
        
        // Moderate images by category
        for categoryId in categories {
            // Set list of images to moderate in that category
            let categoryImages = uploadedImages.filter({ $0.1.category == categoryId})
            let imageIds = String(categoryImages.map( { "\($0.1.imageId)," } )
                .reduce("", +).dropLast())
            
            // Moderate uploaded images
            self.moderateImages(withIds: imageIds, inCategory: categoryId) { [unowned self] (success, _) in
                if !success { return }    // Will retry later

                // Update state of upload requests
                var count = 0
                categoryImages.forEach { (moderatedUpload) in
                    // Update upload requests to remember that the moderation was requested
                    self.uploadsProvider.updateStatusOfUpload(with: moderatedUpload.0,
                                                              to: .moderated, error: "") { [unowned self] _ in
                        // Did we update all requests?
                        count += 1
                        if count == categoryImages.count {
                            // We might still have to delete images
                            self.findNextImageToUpload()
                        }
                    }
                }
            }
        }
    }

    public func delete(uploadedImages: [String], with uploadIDs: [NSManagedObjectID]) -> Void {

        // Get image assets of images to delete
        let assetsToDelete = PHAsset.fetchAssets(withLocalIdentifiers: uploadedImages, options: nil)
        if assetsToDelete.count == 0 { return }
        
        // Delete images from Photo Library
        DispatchQueue.main.async {
            PHPhotoLibrary.shared().performChanges({
                // Delete images from the library
                PHAssetChangeRequest.deleteAssets(assetsToDelete as NSFastEnumeration)
            }, completionHandler: { [unowned self] success, error in
                if success == true {
                    // Delete upload requests in the main thread
                    self.uploadsProvider.delete(uploadRequests: uploadIDs) { _ in }
                }
            })
        }
    }
    
    public func didDeletePiwigoImage(withID imageId: Int) {
        // Mark this uploaded image as deleted from the Piwigo server
        uploadsProvider.markAsDeletedPiwigoImage(withID: Int64(imageId))
    }
    
   
    // MARK: - Failed Uploads Management
    
    public func resumeAll() -> Void {
        // Reset flags
        isPaused = false
        isPreparing = false; isFinishing = false
        isExecutingBackgroundUploadTask = false
        isUploading = Set<NSManagedObjectID>()
        print("••> Resume upload operations…")

        // Get active upload tasks
        let taskContext = DataController.shared.bckgContext
        let uploadSession: URLSession = UploadSessions.shared.bckgSession
        uploadSession.getAllTasks { uploadTasks in
            // Loop over the tasks
            for task in uploadTasks {
                switch task.state {
                case .running:
                    // Retrieve upload request properties
                    guard let objectURIstr = task.originalRequest?.value(forHTTPHeaderField: UploadVars.HTTPuploadID) else { continue }
                    guard let objectURI = URL(string: objectURIstr) else {
                        print("\(self.debugFormatter.string(from: Date())) > task \(task.taskIdentifier) | no object URI!")
                        continue
                    }
                    guard let uploadID = taskContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: objectURI) else {
                        print("\(self.debugFormatter.string(from: Date())) > task \(task.taskIdentifier) | no objectID!")
                        continue
                    }
                    print("\(self.debugFormatter.string(from: Date())) >> is uploading \(uploadID)")
                    self.isUploading.insert(uploadID)

                default:
                    continue
                }
            }

            // Resume failed uploads and pursue the work
            self.backgroundQueue.async { [unowned self] in
                // Considers only uploads to the server to which the user is logged in
                let states: [kPiwigoUploadState] = [.preparingError, .uploadingError, .finishingError]
                let failedUploads = self.uploadsProvider.getRequests(inStates: states).1
                if failedUploads.count > 0 {
                    // Resume failed uploads
                    self.resume(failedUploads: failedUploads) { [unowned self] (_) in
                        // Resume operations
                        self.resumeOperations()
                    }
                } else {
                    // Clean cache from completed uploads whose images do not exist in Photo Library
                    self.uploadsProvider.clearCompletedUploads()
                    // Resume operations
                    self.resumeOperations()
                }
            }
        }
    }
    
    private func resumeOperations() {
        // Append auto-upload requests if requested
        if UploadVars.isAutoUploadActive {
            self.appendAutoUploadRequests()
        } else {
            self.disableAutoUpload()
        }
        
        // Propose to delete uploaded image of the photo Library once a day maximum
        if Date().timeIntervalSinceReferenceDate > UploadVars.dateOfLastPhotoLibraryDeletion + UploadVars.kPiwigoOneDay {
            // Are there images to delete from the Photo Library?
            let (imageIDs, uploadIDs) = uploadsProvider.getRequests(inStates: [.finished, .moderated],
                                                                    markedForDeletion: true)
            if imageIDs.count > 0 {
                // Store date of last deletion
                UploadVars.dateOfLastPhotoLibraryDeletion = Date().timeIntervalSinceReferenceDate

                // Suggest to delete images from the Photo Library
                print("\(debugFormatter.string(from: Date())) > (\(imageIDs.count),\(uploadIDs.count)) should be deleted")
                self.delete(uploadedImages: imageIDs, with: uploadIDs)
            }
        }

        // Remove upload requests of assets that have become unavailable
        let states: [kPiwigoUploadState] = [.waiting, .preparing, .preparingError,
                                            .preparingFail, .formatError, .prepared,
                                            .uploadingFail]
        let imagesToUpload = uploadsProvider.getRequests(inStates: states)
        var assetIDsToDelete: [String] = imagesToUpload.0
        var objectIDsToDelete: [NSManagedObjectID] = imagesToUpload.1
        
        // Remove upload requests of files from intent and clipboard
        while let index = assetIDsToDelete.firstIndex(where: { $0.hasPrefix(kIntentPrefix) || $0.hasPrefix(kClipboardPrefix)}) {
            assetIDsToDelete.remove(at: index)
            objectIDsToDelete.remove(at: index)
        }
        
        // Fetch available assets
        let availableAssets = PHAsset.fetchAssets(withLocalIdentifiers: assetIDsToDelete, options: nil)
        
        // Remove available assets
        availableAssets.enumerateObjects { asset, _, _ in
            if let index = assetIDsToDelete.firstIndex(where: { $0 == asset.localIdentifier }) {
                assetIDsToDelete.remove(at: index)
                objectIDsToDelete.remove(at: index)
            }
        }
        
        // Delete upload requests of assets that have become unavailable
        uploadsProvider.delete(uploadRequests: objectIDsToDelete) { [unowned self] _ in
            self.findNextImageToUpload()
        }
    }

    public func resume(failedUploads: [NSManagedObjectID], completionHandler: @escaping (Error?) -> Void) -> Void {
        
        // Initialisation
        var uploadsToUpdate = [UploadProperties]()
        
        // Create a private queue context.
        let taskContext = DataController.shared.bckgContext

        // Loop over the failed uploads
        for failedUploadID in failedUploads {
            do {
                // Get upload request
                let object = try taskContext.existingObject(with: failedUploadID)
                let failedUpload = object as! Upload

                // Create upload properties cancelling error
                var uploadProperties: UploadProperties
                switch failedUpload.state {
                case .uploadingError:
                    // -> Will retry to transfer the image
                    uploadProperties = failedUpload.getProperties(with: .prepared, error: "")
                case .finishingError:
                    // -> Will retry to finish the upload
                    uploadProperties = failedUpload.getProperties(with: .uploaded, error: "")
                default:
                    // —> Will retry from scratch
                    uploadProperties = failedUpload.getProperties(with: .waiting, error: "")
                }
                
                // Append updated upload
                uploadsToUpdate.append(uploadProperties)
            }
            catch {
                print("\(debugFormatter.string(from: Date())) > missing Core Data object \(failedUploadID)!")
                // Request not available…!?
                continue
            }
        }
        
        // Update failed uploads
        self.uploadsProvider.importUploads(from: uploadsToUpdate) { (error) in
            // No need to update app badge and Upload button in root/default album
            completionHandler(error)
        }
    }
}


