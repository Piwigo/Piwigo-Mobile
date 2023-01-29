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
    /// - image formats which can be converted with iOS
    /// - movie formats which can be converted with iOS
    /// See: https://developer.apple.com/documentation/uniformtypeidentifiers/system-declared_uniform_type_identifiers
    let acceptedImageFormats: String = {
        return "heic,heif,png,gif,jpg,jpeg,webp,tif,tiff,bmp,raw,ico,icns"
    }()
    let acceptedMovieFormats: String = {
        return "mov,mpg,mpeg,mpeg2,mp4,avi"
    }()

    // For logs
    let debugFormatter: DateFormatter = {
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
        let anURL = DataMigrator.appGroupDirectory.appendingPathComponent("Uploads")

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
    
    let frgdSession: URLSession = UploadSessions.shared.frgdSession
    let bckgSession: URLSession = UploadSessions.shared.bckgSession
    let decoder = JSONDecoder()
    
    deinit {
//        NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)

        // Close upload session
//        sessionManager.invalidateSessionCancelingTasks(true, resetSession: true)
    }
    

    // MARK: - Core Data Object Contexts
    lazy var bckgContext: NSManagedObjectContext = {
        let context:NSManagedObjectContext = DataController.shared.bckgContext
        return context
    }()

    
    // MARK: - Core Data Providers
    lazy var imageProvider: ImageProvider = {
        let provider : ImageProvider = ImageProvider()
        return provider
    }()

    public lazy var uploadProvider: UploadProvider = {
        let provider : UploadProvider = UploadProvider()
        return provider
    }()


    // MARK: - Core Data Source
    lazy var predicates: [NSPredicate] = {
        var andPredicates = [NSPredicate]()
        andPredicates.append(NSPredicate(format: "user.server.path == %@", NetworkVars.serverPath))
        andPredicates.append(NSPredicate(format: "user.username == %@", NetworkVars.username))
        return andPredicates
    }()

    lazy var fetchUploadsRequest: NSFetchRequest = {
        // Sort uploads by globalRank i.e. the order in which they are presented in the web UI
        let fetchRequest = Upload.fetchRequest()

        // Priority to uploads requested manually, oldest ones first
        var sortDescriptors = [NSSortDescriptor(key: #keyPath(Upload.markedForAutoUpload), ascending: true)]
        sortDescriptors.append(NSSortDescriptor(key: #keyPath(Upload.requestDate), ascending: true))
        fetchRequest.sortDescriptors = sortDescriptors

        // Retrieves only non-completed upload requests
        var andPredicates = predicates
        let states: [pwgUploadState] = [.waiting, .preparing, .preparingError,
                                        .preparingFail, .formatError, .prepared,
                                        .uploading, .uploadingError, .uploadingFail, .uploaded,
                                        .finishing, .finishingError]
        andPredicates.append(NSPredicate(format: "requestState IN %@", states.map({$0.rawValue})))
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)
        fetchRequest.fetchBatchSize = 20
        return fetchRequest
    }()

    lazy var uploads: NSFetchedResultsController<Upload> = {
        let uploads = NSFetchedResultsController(fetchRequest: fetchUploadsRequest,
                                                 managedObjectContext: self.bckgContext,
                                                 sectionNameKeyPath: nil, cacheName: nil)
//        uploads.delegate = self
        return uploads
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
    /// - Videos are exported in MP4 fomat and uploaded if the VideoJS plugin is installed
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
        
        // Perform fetch
        do {
            try uploads.performFetch()
        }
        catch {
            print("Error: \(error)")
        }

        // Update app badge and Upload button in root/default album
        // Considers only uploads to the server to which the user is logged in
        var states: [pwgUploadState] = [.waiting, .preparing, .preparingError,
                                        .preparingFail, .formatError, .prepared,
                                        .uploading, .uploadingError, .uploadingFail, .uploaded,
                                        .finishing, .finishingError]
        nberOfUploadsToComplete = uploads.fetchedObjects?.count ?? 0
//        return // for debugging background tasks

        // Pause upload manager if:
        /// - app not in the foreground anymore
        /// - executing a background task
        /// - in Low Power mode
        /// - Wi-Fi required but unavailable
        if isPaused || isExecutingBackgroundUploadTask ||
            ProcessInfo.processInfo.isLowPowerModeEnabled ||
            (UploadVars.wifiOnlyUploading && !NetworkVars.isConnectedToWiFi()) {
            return
        }

        // Interrupted work should be set as if an error was encountered
        /// - case of finishing uploads
        let finishing = uploads.fetchedObjects?.filter({$0.state == .finishing}) ?? []
        if !isFinishing, finishing.count > 0 {
            // Transfers encountered an error
            finishing.forEach({ upload in
                upload.setState(.finishingError, error: JsonError.networkUnavailable)
            })
            findNextImageToUpload()
            return
        }
        /// - case of transfers (a few transfers may be running in parallel)
        let uploading = uploads.fetchedObjects?.filter({$0.state == .uploading}) ?? []
        if isUploading.isEmpty == false, uploading.count > 0 {
            for upload in uploading {
                if isUploading.contains(upload.objectID) == false {
                    // Transfer encountered an error
                    upload.setState(.uploadingError, error: JsonError.networkUnavailable)
                    findNextImageToUpload()
                }
            }
            return
        }
        /// - case of upload preparation
        let preparing = uploads.fetchedObjects?.filter({$0.state == .preparing}) ?? []
        if isPreparing == false, preparing.count > 0 {
            // Preparations encountered an error
            preparing.forEach { upload in
                upload.setState(.preparingError, error: UploadError.missingAsset)
            }
            findNextImageToUpload()
            return
        }

        // How many upload requests did fail?
        let failedUploads = uploads.fetchedObjects?
            .filter({[.preparingError, .preparingFail,
                      .uploadingError, .uploadingFail].contains($0.state)}).count ?? 0

        // Too many failures?
        if failedUploads >= maxNberOfFailedUploads {
            return
        }

        // Not finishing and upload request to finish?
        /// Called when:
        /// - uploading with pwg.images.upload because the title cannot be set during the upload.
        /// - uploading with pwg.images.uploadAsync to empty the lounge as from the version 12 of the Piwigo server.
        if !isFinishing,
           let uploaded = uploads.fetchedObjects?.first(where: {$0.state == .uploaded}) {
            
            // Pause upload manager if the app is not in the foreground anymore
            if isPaused { return }
            
            // Upload file ready, so we start the transfer
            self.finishTransfer(of: uploaded)
            return
        }

        // Not transferring and file ready for transfer?
        if isUploading.count < maxNberOfTransfers,
           let prepared = uploads.fetchedObjects?.first(where: {$0.state == .prepared}) {

            // Pause upload manager if the app is not in the foreground anymore
            if isPaused { return }

            // Upload file ready, so we start the transfer
            self.launchTransfer(of: prepared)
            return
        }
        
        // Not preparing and upload request waiting?
        let nberPrepared = uploads.fetchedObjects?.filter({$0.state == .prepared}).count ?? 0
        if !isPreparing, nberPrepared < maxNberPreparedUploads,
           let waiting = uploads.fetchedObjects?.first(where: {$0.state == .waiting}) {

            // Pause upload manager if the app is not in the foreground anymore
            if isPaused { return }

            // Prepare the next upload
            self.prepare(waiting)
            return
        }
        
        // No more image to transfer ;-)
        // Moderate images uploaded by Community regular user
        // Considers only uploads to the server to which the user is logged in
        let finished = uploads.fetchedObjects?.filter({$0.state == .finished}) ?? []
        if NetworkVars.userStatus == .normal,
           NetworkVars.usesCommunityPluginV29, finished.count > 0 {

            // Pause upload manager if the app is not in the foreground anymore
            if isPaused { return }

            // Moderate uploaded images
            self.moderate(completedRequests: finished.map({$0.objectID}))
            return
        }

        // Suggest to delete images from the Photo Library if the user wanted it.
        // The deletion is suggested when there is no more upload to perform.
        // Note that some uploads may have failed and waiting a user decision.
        states = [.waiting, .preparing, .prepared,
                  .uploading, .uploaded, .finishing]
        if uploads.fetchedObjects?.filter({states.contains($0.state)}).count ?? 0 > 0 { return }
        
        // Upload requests are completed
        // Considers only uploads to the server to which the user is logged in
        let (imageIDs, uploadIDs) = uploadProvider.getRequests(inStates: [.finished, .moderated],
                                                                markedForDeletion: true)
        if imageIDs.isEmpty == false, uploadIDs.isEmpty == false {
            print("\(debugFormatter.string(from: Date())) > (\(imageIDs.count),\(uploadIDs.count)) should be deleted")
            self.delete(uploadedImages: imageIDs, with: uploadIDs)
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
        // Perform fetch
        do {
            try uploads.performFetch()
        }
        catch {
            print("Error: \(error)")
        }

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
        let states: [pwgUploadState] = [.preparingError, .preparingFail,
                                        .uploadingError, .uploadingFail]
        let failedUploads = uploads.fetchedObjects?
            .filter({states.contains($0.state) && $0.markedForAutoUpload == autoUploadOnly}) ?? []

        // Too many failures?
        if failedUploads.count >= maxNberOfFailedUploads { return }

        // Will retry a few…
        if failedUploads.count > 0 {
            // Will relaunch transfers with one which failed
            uploadRequestsToTransfer = Set(failedUploads.map({$0.objectID}))
            print("\(debugFormatter.string(from: Date())) >•• collected \(uploadRequestsToTransfer.count) failed uploads")
        }
        
        // Second, find upload requests ready for transfer
        let preparedUploads = uploads.fetchedObjects?
            .filter({$0.state == .prepared && $0.markedForAutoUpload == autoUploadOnly}) ?? []
        if preparedUploads.count > 0 {
            // Will then launch transfers of prepared uploads
            let prepared = preparedUploads.map({$0.objectID})
            uploadRequestsToTransfer = uploadRequestsToTransfer
                .union(Set(prepared[..<min(maxNberOfUploadsPerBckgTask,prepared.count)]))
            print("\(debugFormatter.string(from: Date())) >•• collected \(min(maxNberOfUploadsPerBckgTask, prepared.count)) prepared uploads")
        }
        
        // Finally, get list of upload requests to prepare
        let diff = maxNberPreparedUploads - uploadRequestsToTransfer.count
        if diff <= 0 { return }
        let requestsToPrepare = uploads.fetchedObjects?
            .filter({$0.state == .waiting && $0.markedForAutoUpload == autoUploadOnly}) ?? []
        print("\(debugFormatter.string(from: Date())) >•• collected \(min(diff, requestsToPrepare.count)) uploads to prepare")
        let toPrepare = preparedUploads.map({$0.objectID})
        uploadRequestsToPrepare = Set(toPrepare[..<min(diff, toPrepare.count)])
    }
    
    public func resumeTransfers() -> Void {
        // Get active upload tasks and initialise isUploading
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
                    guard let uploadID = bckgContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: objectURI) else {
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
                        guard let uploadID = bckgContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: objectURI) else {
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
                   let uploadID = self.uploadRequestsToTransfer.first,
                   let upload = uploads.fetchedObjects?.first(where: {$0.objectID == uploadID}) {
                    // Launch transfer
                    self.launchTransfer(of: upload)
                }
            }
        }
    }
        
    public func appendUploadRequestsToPrepareToBckgTask() -> Void {
        // Add image preparation followed by transfer operations
        if countOfBytesPrepared < UInt64(maxCountOfBytesToUpload),
           let uploadID = uploadRequestsToPrepare.first,
           let upload = uploads.fetchedObjects?.first(where: {$0.objectID == uploadID}) {
            // Prepare image for transfer
            prepare(upload)
        }
        if uploadRequestsToPrepare.isEmpty == false {
            // Remove objectID
            uploadRequestsToPrepare.removeFirst()
        }
    }
    
    
    // MARK: - Prepare image
    /// - One image at once
    /// - Maximum of 10 images prepared in advance
    private let maxNberPreparedUploads = 10
    private var isPreparing = false

    func prepare(_ upload: Upload) -> Void {
        print("\(debugFormatter.string(from: Date())) > prepare \(upload.objectID.uriRepresentation())")

        // Update upload status
        isPreparing = true

        // Update UI
        if !isExecutingBackgroundUploadTask {
            updateCell(with: upload.localIdentifier,
                       stateLabel: pwgUploadState.preparing.stateInfo,
                       photoMaxSize: upload.photoMaxSize,
                       progress: nil, errorMsg: "")
        }
        
        // Add category to list of recent albums
        let userInfo = ["categoryId": upload.category]
        NotificationCenter.default.post(name: .pwgAddRecentAlbum, object: nil, userInfo: userInfo)

        // Determine from where the file comes from:
        // => Photo Library: use PHAsset local identifier
        // => UIPasteborad: use identifier of type "Clipboard-yyyyMMdd-HHmmssSSSS-typ-#"
        //    where "typ" is "img" (photo) or "mov" (video).
        // => Intent: use identifier of type "Intent-yyyyMMdd-HHmmssSSSS-typ-#"
        //    where "typ" is "img" (photo) or "mov" (video).
        if upload.localIdentifier.hasPrefix(kIntentPrefix) {
            // Case of an image submitted by an intent
            prepareImageFromIntent(for: upload)
        } else if upload.localIdentifier.hasPrefix(kClipboardPrefix) {
            // Case of an image retrieved from the pasteboard
            prepareImageInPasteboard(for: upload)
        } else {
            // Case of an image from the local Photo Library
            prepareImageInPhotoLibrary(for: upload)
        }
    }
    
    private func prepareImageFromIntent(for upload: Upload) {
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
        guard files.count > 0,
              let fileURL = files.filter({$0.lastPathComponent.hasPrefix(upload.localIdentifier)}).first else {
            // File not available… deleted?
            upload.setState(.preparingFail, error: UploadError.missingAsset)
            
            // Update UI
            updateCell(with: upload.localIdentifier, stateLabel: upload.stateLabel,
                       photoMaxSize: nil, progress: nil, errorMsg: pwgUploadState.preparingFail.stateInfo)

            // Investigate next upload request?
            self.didEndPreparation()
            return
        }
        
        // Add prefix if requested by user
        var fileName = upload.fileName
        if upload.prefixFileNameBeforeUpload {
            if !fileName.hasPrefix(upload.defaultPrefix) {
                fileName = upload.defaultPrefix + fileName
            }
        }
        
        // Piwigo 2.10.2 supports the 3-byte UTF-8, not the standard UTF-8 (4 bytes)
        upload.fileName = NetworkUtilities.utf8mb3String(from: fileName)

        // Launch preparation job (limited to stripping metadata)
        if fileURL.lastPathComponent.contains("img") {
            upload.isVideo = false

            // Update state of upload and launch preparation job
            upload.setState(.preparing, error: nil)
            prepareImage(atURL: fileURL, for: upload)
            return
        }
    }
    
    private func prepareImageInPasteboard(for upload: Upload) {
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
        guard files.count > 0,
              let fileURL = files.filter({$0.absoluteString.contains(upload.localIdentifier)}).first else {
            // File not available… deleted?
            upload.setState(.preparingFail, error: UploadError.missingAsset)
            
            // Update UI
            updateCell(with: upload.localIdentifier, stateLabel: upload.stateLabel,
                       photoMaxSize: nil, progress: nil, errorMsg: pwgUploadState.preparingFail.stateInfo)

            // Investigate next upload request?
            self.didEndPreparation()
            return
        }
        var fileName = fileURL.lastPathComponent

        // Check/update serverFileTypes if possible
//        let fileTypes = UploadVars.serverFileTypes
//        if fileTypes.isEmpty == false {
//            uploadProperties.serverFileTypes = fileTypes
//        }

        // Launch preparation job if file format accepted by Piwigo server
        let fileExt = fileURL.pathExtension.lowercased()
        if fileName.contains("img") {
            upload.isVideo = false

            // Set filename by
            /// - removing the "Clipboard-" prefix i.e. kClipboardPrefix
            /// - removing the "SSSS-img-#" suffix i.e. "SSSS%@-#" where %@ is kImageSuffix
            /// - adding the file extension
            if let prefixRange = fileName.range(of: kClipboardPrefix),
               let suffixRange = fileName.range(of: kImageSuffix) {
                fileName = String(fileName[prefixRange.upperBound..<suffixRange.lowerBound].dropLast(4)) + ".\(fileExt)"
            }

            // Add prefix if requested by user
            if upload.prefixFileNameBeforeUpload {
                if !fileName.hasPrefix(upload.defaultPrefix) {
                    fileName = upload.defaultPrefix + fileName
                }
            }
            upload.fileName = fileName

            // Chek that the image format is accepted by the Piwigo server
            if UploadVars.serverFileTypes.contains(fileExt) {
                // Image file format accepted by the Piwigo server
                upload.setState(.preparing, error: nil)
                
                // Launch preparation job
                prepareImage(atURL: fileURL, for: upload)
                return
            }
            
            // Try to convert image if JPEG format is accepted by Piwigo server
            if UploadVars.serverFileTypes.contains("jpg"),
               acceptedImageFormats.contains(fileExt) {
                // Try conversion to JPEG
                print("\(debugFormatter.string(from: Date())) > converting photo \(upload.fileName)…")
                
                // Update state of upload
                upload.setState(.preparing, error: nil)
                try? bckgContext.save()
                
                // Launch preparation job
                prepareImage(atURL: fileURL, for: upload)
                return
            }
            
            // Image file format cannot be accepted by the Piwigo server
            upload.setState(.formatError, error: nil)

            // Update UI
            updateCell(with: upload.localIdentifier, stateLabel: upload.stateLabel,
                       photoMaxSize: nil, progress: nil, errorMsg: pwgUploadState.formatError.stateInfo)
            
            // Update upload request
            didEndPreparation()
        }
        else if fileName.contains("mov") {
            upload.isVideo = true

            // Set filename by
            /// - removing the "Clipboard-" prefix i.e. kClipboardPrefix
            /// - removing the "SSSS-mov-#" suffix i.e. "SSSS%@-#" where %@ is kMovieSuffix
            /// - adding the file extension
            if let prefixRange = fileName.range(of: kClipboardPrefix),
               let suffixRange = fileName.range(of: kMovieSuffix) {
                fileName = String(fileName[prefixRange.upperBound..<suffixRange.lowerBound].dropLast(4)) + ".\(fileExt)"
            }

            // Add prefix if requested by user
            if upload.prefixFileNameBeforeUpload {
                if !fileName.hasPrefix(upload.defaultPrefix) {
                    fileName = upload.defaultPrefix + fileName
                }
            }
            upload.fileName = fileName

            // Chek that the video format is accepted by the Piwigo server
            if UploadVars.serverFileTypes.contains(fileExt) {
                // Video file format accepted by the Piwigo server
                print("\(debugFormatter.string(from: Date())) > preparing video \(upload.fileName)…")

                // Update state of upload
                upload.setState(.preparing, error: nil)
                prepareVideo(atURL: fileURL, for: upload)
                return
            }
            
            // Convert video if MP4 format is accepted by Piwigo server
            if UploadVars.serverFileTypes.contains("mp4"),
               acceptedMovieFormats.contains(fileExt) {
                // Try conversion to MP4
                print("\(debugFormatter.string(from: Date())) > converting video \(upload.fileName)…")

                // Update state of upload
                upload.setState(.preparing, error: nil)
                convertVideo(atURL: fileURL, for: upload)
                return
            }
            
            // Video file format cannot be accepted by the Piwigo server
            upload.setState(.formatError, error: nil)

            // Update UI
            updateCell(with: upload.localIdentifier, stateLabel: upload.stateLabel,
                       photoMaxSize: nil, progress: nil, errorMsg: pwgUploadState.formatError.stateInfo)
            
            // Investigate next upload request?
            self.didEndPreparation()
        }
        else {
            // Unknown type
            upload.setState(.formatError, error: nil)

            // Update UI
            updateCell(with: upload.localIdentifier, stateLabel: upload.stateLabel,
                       photoMaxSize: nil, progress: nil, errorMsg: pwgUploadState.formatError.stateInfo)
            
            // Investigate next upload request?
            self.didEndPreparation()
        }
    }
    
    private func prepareImageInPhotoLibrary(for upload: Upload) {
        // Retrieve image asset
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [upload.localIdentifier], options: nil)
        guard assets.count > 0, let originalAsset = assets.firstObject else {
            // Asset not available… deleted?
            upload.setState(.preparingFail, error: UploadError.missingAsset)
            self.didEndPreparation()
            return
        }

        // Retrieve creation date
        if let creationDate = originalAsset.creationDate {
            upload.creationDate = creationDate.timeIntervalSinceReferenceDate
        } else {
            upload.creationDate = Date().timeIntervalSinceReferenceDate
        }
        
        // Get URL of image file to be stored into Piwigo/Uploads directory
        // and deletes temporary image file if exists (incomplete previous attempt?)
        let fileURL = getUploadFileURL(from: upload, withSuffix: kOriginalSuffix, deleted: true)

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
                
                upload.fileName = utf8mb3Filename
                self.dispatchImage(asset: originalAsset, atURL:fileURL, for: upload)
            }
        }
        else {
            // Asset not available… deleted?
            upload.setState(.preparingFail, error: UploadError.missingAsset)
            
            // Investigate next upload request?
            self.didEndPreparation()
        }
        
        // Release memory
        resources.removeAll(keepingCapacity: false)
    }
    
    private func dispatchImage(asset originalAsset:PHAsset, atURL uploadFileURL:URL, for upload: Upload) {
        // Append prefix provided by user if requested
        let fileName = upload.fileName
        if upload.prefixFileNameBeforeUpload {
            if !fileName.hasPrefix(upload.defaultPrefix) {
                upload.fileName = upload.defaultPrefix + fileName
            }
        }
        
        // Check/update serverFileTypes if possible
//        let fileTypes = UploadVars.serverFileTypes
//        if fileTypes.isEmpty == false {
//            uploadProperties.serverFileTypes = fileTypes
//        }
        
        // Launch preparation job if file format accepted by Piwigo server
        let fileExt = (URL(fileURLWithPath: fileName).pathExtension).lowercased()
        switch originalAsset.mediaType {
        case .image:
            upload.isVideo = false
            // Chek that the image format is accepted by the Piwigo server
            if UploadVars.serverFileTypes.contains(fileExt) {
                // Image file format accepted by the Piwigo server
                // Update state of upload
                upload.setState(.preparing, error: nil)
                
                // Launch preparation job
                self.prepareImage(atURL: uploadFileURL, for: upload)
                return
            }
            // Convert image if JPEG format is accepted by Piwigo server
            if UploadVars.serverFileTypes.contains("jpg"),
               acceptedImageFormats.contains(fileExt) {
                // Try conversion to JPEG
                print("\(debugFormatter.string(from: Date())) > converting photo \(upload.fileName)…")
                
                // Update state of upload
                upload.setState(.preparing, error: nil)

                // Launch preparation job
                self.convertImage(atURL: uploadFileURL, for: upload)
                return
            }

            // Image file format cannot be accepted by the Piwigo server
            upload.setState(.formatError, error: nil)

            // Update UI
            updateCell(with: upload.localIdentifier, stateLabel: upload.stateLabel,
                       photoMaxSize: nil, progress: nil, errorMsg: pwgUploadState.formatError.stateInfo)
            
            // Investigate next upload request?
            self.didEndPreparation()
//            showError(withTitle: NSLocalizedString("imageUploadError_title", comment: "Image Upload Error"), andMessage: NSLocalizedString("imageUploadError_format", comment: "Sorry, image files with extensions .\(fileExt.uppercased()) and .jpg are not accepted by the Piwigo server."), forRetrying: false, withImage: nextImageToBeUploaded)

        case .video:
            upload.isVideo = true
            // Chek that the video format is accepted by the Piwigo server
            if UploadVars.serverFileTypes.contains(fileExt) {
                // Video file format accepted by the Piwigo server
                print("\(debugFormatter.string(from: Date())) > preparing video \(upload.fileName)…")

                // Update state of upload
                upload.setState(.preparing, error: nil)

                // Launch preparation job
//                self.prepareVideo(atURL: uploadFileURL, for: uploadID, with: uploadProperties)
                self.prepareVideo(ofAsset: originalAsset, for: upload)
                return
            }
            // Convert video if MP4 format is accepted by Piwigo server
            if UploadVars.serverFileTypes.contains("mp4"),
               acceptedMovieFormats.contains(fileExt) {
                // Try conversion to MP4
                print("\(debugFormatter.string(from: Date())) > converting video \(upload.fileName)…")

                // Update state of upload
                upload.setState(.preparing, error: nil)

                // Launch preparation job
//                self.convertVideo(atURL: uploadFileURL, for: uploadID, with: uploadProperties)
                self.convertVideo(ofAsset: originalAsset, for: upload)
                return
            }
            
            // Video file format cannot be accepted by the Piwigo server
            upload.setState(.formatError, error: nil)

            // Update UI
            updateCell(with: upload.localIdentifier, stateLabel: upload.stateLabel,
                       photoMaxSize: nil, progress: nil, errorMsg: pwgUploadState.formatError.stateInfo)
            
            // Investigate next upload request?
            self.didEndPreparation()
//                showError(withTitle: NSLocalizedString("videoUploadError_title", comment: "Video Upload Error"), andMessage: NSLocalizedString("videoUploadError_format", comment: "Sorry, video files with extension .\(fileExt.uppercased()) are not accepted by the Piwigo server."), forRetrying: false, withImage: uploadToPrepare)

        case .audio:
            // Update state of upload: Not managed by Piwigo iOS yet…
            upload.setState(.formatError, error: nil)

            // Investigate next upload request?
            self.didEndPreparation()
//            showError(withTitle: NSLocalizedString("audioUploadError_title", comment: "Audio Upload Error"), andMessage: NSLocalizedString("audioUploadError_format", comment: "Sorry, audio files are not supported by Piwigo Mobile yet."), forRetrying: false, withImage: uploadToPrepare)

        case .unknown:
            fallthrough
        default:
            // Update state of upload request: Unknown format
            upload.setState(.formatError, error: nil)

            // Investigate next upload request?
            self.didEndPreparation()
        }
    }

    func didEndPreparation() {
        // Save Upload requests
        try? bckgContext.save()
        
        // Running in background or foreground?
        isPreparing = false
        if isExecutingBackgroundUploadTask {
            if countOfBytesToUpload < maxCountOfBytesToUpload {
                // In background task, launch a transfer if possible
                let prepared = uploads.fetchedObjects?.filter({$0.state == .prepared}) ?? []
                let states: [pwgUploadState] = [.preparingError, .preparingFail,
                                                .uploadingError, .uploadingFail,
                                                .finishingError]
                let failed = uploads.fetchedObjects?.filter({states.contains($0.state)}) ?? []
                if isUploading.count < maxNberOfTransfers,
                   failed.count < maxNberOfFailedUploads,
                   let upload = prepared.first {
                    launchTransfer(of: upload)
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
    public var isUploading = Set<NSManagedObjectID>()

    public func launchTransfer(of upload: Upload) -> Void {
        print("\(debugFormatter.string(from: Date())) > launch transfer of \(upload.objectID.uriRepresentation())")

        // Update list of transfers
        if isUploading.contains(upload.objectID) { return }
        isUploading.insert(upload.objectID)

        // Reset counter of progress bar in case we repeat the transfer
        UploadSessions.shared.clearCounter(withID: upload.localIdentifier)

        // Update UI
        if !isExecutingBackgroundUploadTask {
            // Initialise the progress bar
            updateCell(with: upload.localIdentifier,
                       stateLabel: pwgUploadState.uploading.stateInfo,
                       photoMaxSize: nil, progress: Float(0), errorMsg: nil)
        }

        // Update state of upload request and start transfer
        upload.setState(.uploading, error: nil)

        // Choose recent method when called by:
        /// - admins as from Piwigo server 11 or previous versions with the uploadAsync plugin installed.
        /// - Community users as from Piwigo 12.
        if NetworkVars.usesUploadAsync || isExecutingBackgroundUploadTask {
            // Prepare transfer
            self.transferInBackgroundImage(for: upload)
        } else {
            // Transfer image
            self.transferImage(for: upload)
        }
        
        // Do not prepare next image in background task (already scheduled)
        if self.isExecutingBackgroundUploadTask { return }

        // Stop here if there no image to prepare
        let waiting = uploads.fetchedObjects?.filter({$0.state == .waiting}) ?? []
        if waiting.isEmpty { return }

        // Should we prepare the next image in parallel?
        let states: [pwgUploadState] = [.preparingError, .preparingFail,
                                        .uploadingError, .uploadingFail,
                                        .finishingError]
        let failed = uploads.fetchedObjects?.filter({states.contains($0.state)}) ?? []
        if !self.isPreparing, failed.count < maxNberOfFailedUploads,
           let upload = waiting.first {

            // Prepare the next upload
            self.isPreparing = true
            self.prepare(upload)
            return
        }
    }

    func didEndTransfer(for upload: Upload) {
        // Save Upload requests
        try? bckgContext.save()
        
        // Update list of current uploads
        if let index = isUploading.firstIndex(where: {$0 == upload.objectID}) {
            isUploading.remove(at: index)
        }
        
        // Pursue the work…
        if isExecutingBackgroundUploadTask {
            if countOfBytesToUpload < maxCountOfBytesToUpload {
                // In background task, launch a transfer if possible
                let prepared = uploads.fetchedObjects?.filter({$0.state == .prepared}) ?? []
                let states: [pwgUploadState] = [.preparingError, .preparingFail,
                                               .uploadingError, .uploadingFail,
                                               .finishingError]
                let failed = uploads.fetchedObjects?.filter({states.contains($0.state)}) ?? []
                if isUploading.count < maxNberOfTransfers,
                   failed.count < maxNberOfFailedUploads,
                   let upload = prepared.first {
                    launchTransfer(of: upload)
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
    private var isFinishing = false

    private func finishTransfer(of upload: Upload) {
        print("\(debugFormatter.string(from: Date())) > finish transfers of \(upload.objectID.uriRepresentation())")

        // Update upload status
        isFinishing = true
        
        // Update UI
        if !isExecutingBackgroundUploadTask {
            updateCell(with: upload.localIdentifier,
                       stateLabel: pwgUploadState.finishing.stateInfo,
                       photoMaxSize: upload.photoMaxSize,
                       progress: nil, errorMsg: "")
        }
        
        // Update state of upload resquest and finish upload
        upload.setState(.finishing, error: nil)
        
        // Work depends on Piwigo server version
        if "12.0.0".compare(NetworkVars.pwgVersion, options: .numeric) != .orderedDescending {
            // Uploaded with pwg.images.uploadAsync -> Empty the lounge
            emptyLounge(for: upload)
        } else {
            // Uploaded with pwg.images.upload -> Set image title.
            setImageParameters(for: upload)
        }
    }

    func didFinishTransfer() {
        // Save Upload requests
        try? bckgContext.save()
        
        isFinishing = false
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
//                    self.uploadProvider.updateStatusOfUpload(with: uploadRequest.0,
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
            do {
                let upload = try bckgContext.existingObject(with: uploadID)
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
                    self.uploadProvider.updateStatusOfUpload(with: moderatedUpload.0,
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
                    self.uploadProvider.delete(uploadRequests: uploadIDs) { _ in }
                }
            })
        }
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
        bckgSession.getAllTasks { uploadTasks in
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
                    guard let uploadID = self.bckgContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: objectURI) else {
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
                let states: [pwgUploadState] = [.preparingError, .uploadingError, .finishingError]
                let failedUploads = self.uploadProvider.getRequests(inStates: states).1
                if failedUploads.count > 0 {
                    // Resume failed uploads
                    self.resume(failedUploads: failedUploads) { [unowned self] (_) in
                        // Resume operations
                        self.resumeOperations()
                    }
                } else {
                    // Clean cache from completed uploads whose images do not exist in Photo Library
                    self.uploadProvider.clearCompletedUploads()
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
        if Date().timeIntervalSinceReferenceDate > UploadVars.dateOfLastPhotoLibraryDeletion + UploadVars.pwgOneDay {
            // Are there images to delete from the Photo Library?
            let (imageIDs, uploadIDs) = uploadProvider.getRequests(inStates: [.finished, .moderated],
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
        let states: [pwgUploadState] = [.waiting, .preparing, .preparingError,
                                        .preparingFail, .formatError, .prepared,
                                        .uploadingFail]
        let imagesToUpload = uploadProvider.getRequests(inStates: states)
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
        uploadProvider.delete(uploadRequests: objectIDsToDelete) { [unowned self] _ in
            self.findNextImageToUpload()
        }
    }

    public func resume(failedUploads: [NSManagedObjectID], completionHandler: @escaping (Error?) -> Void) -> Void {
        
        // Initialisation
        var uploadsToUpdate = [UploadProperties]()
        
        // Loop over the failed uploads
        for failedUploadID in failedUploads {
            do {
                // Get upload request
                let object = try bckgContext.existingObject(with: failedUploadID)
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
        self.uploadProvider.importUploads(from: uploadsToUpdate) { (error) in
            // No need to update app badge and Upload button in root/default album
            completionHandler(error)
        }
    }
}


