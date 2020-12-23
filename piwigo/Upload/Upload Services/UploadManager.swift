//
//  UploadManager.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 22/05/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//
// See https://academy.realm.io/posts/gwendolyn-weston-ios-background-networking/

import Foundation
import Photos
import var CommonCrypto.CC_MD5_DIGEST_LENGTH
import func CommonCrypto.CC_MD5
import typealias CommonCrypto.CC_LONG

#if canImport(CryptoKit)
import CryptoKit        // Requires iOS 13
#endif

@objc
class UploadManager: NSObject, URLSessionDelegate {

    @objc static let shared = UploadManager()
    
    // MARK: - Initialisation
    override init() {
        super.init()
        
        // Register app giving up its active status to another app.
        NotificationCenter.default.addObserver(self, selector: #selector(self.willResignActive),
            name: UIApplication.willResignActiveNotification, object: nil)
    }
    
    @objc var isPaused = false
    private var appState = UIApplication.State.active
    @objc func willResignActive() -> Void {
        // Executed in the main queue when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
//        print("\(debugFormatter.string(from: Date())) > willResignActive")
        appState = UIApplication.State.inactive
    }
    
    // For logs
    let debugFormatter: DateFormatter = {
        var formatter = DateFormatter.init()
        formatter.locale = Locale.init(identifier: "en_US")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.ssssss"
        formatter.timeZone = TimeZone.init(secondsFromGMT: 0)
        return formatter
    }()
    
    /// Background queue in which uploads are managed
    let backgroundQueue: DispatchQueue = {
        return DispatchQueue(label: "org.piwigo.uploadBckgQueue", qos: .background)
    }()
    
    /// Uploads directory into which image/video files are temporarily stored
    let applicationUploadsDirectory: URL = {
        let fm = FileManager.default
        let anURL = DataController.applicationStoresDirectory.appendingPathComponent("Uploads")

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
    
    let sessionManager: AFHTTPSessionManager = NetworkHandler.createUploadSessionManager()
    let decoder = JSONDecoder()
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)

        // Close upload session
        sessionManager.invalidateSessionCancelingTasks(true, resetSession: true)
    }
    

    // MARK: - MD5 Checksum
    #if canImport(CryptoKit)        // Requires iOS 13
    @available(iOS 13.0, *)
    func MD5(data: Data?) -> String {
        let digest = Insecure.MD5.hash(data: data ?? Data())
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
    #endif

    func oldMD5(data: Data?) -> String {
        let length = Int(CC_MD5_DIGEST_LENGTH)
        let messageData = data ?? Data()
        var digestData = Data(count: length)

        _ = digestData.withUnsafeMutableBytes { digestBytes -> UInt8 in
                messageData.withUnsafeBytes { messageBytes -> UInt8 in
                if let messageBytesBaseAddress = messageBytes.baseAddress,
                    let digestBytesBlindMemory = digestBytes.bindMemory(to: UInt8.self).baseAddress {
                    let messageLength = CC_LONG(messageData.count)
                    CC_MD5(messageBytesBaseAddress, messageLength, digestBytesBlindMemory)
                }
                return 0
            }
        }
        return digestData.map { String(format: "%02hhx", $0) }.joined()
    }


    // MARK: - Core Data
    /**
     The UploadsProvider that collects upload data, saves it to Core Data,
     and serves it to the uploader.
     */
    lazy var uploadsProvider: UploadsProvider = {
        let provider : UploadsProvider = UploadsProvider()
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
    @objc var nberOfUploadsToComplete: Int {
        get {
            return _nberOfUploadsToComplete
        }
        set(requestsToComplete) {
            // Update value
            _nberOfUploadsToComplete = requestsToComplete
            // Update badge and button
            DispatchQueue.main.async { [unowned self] in
                // Update app badge
                UIApplication.shared.applicationIconBadgeNumber = self.nberOfUploadsToComplete
                // Update button of root album (or default album)
                let uploadInfo: [String : Any] = ["nberOfUploadsToComplete" : self.nberOfUploadsToComplete]
                let name = NSNotification.Name(rawValue: kPiwigoNotificationLeftUploads)
                NotificationCenter.default.post(name: name, object: nil, userInfo: uploadInfo)
            }
        }
    }
    
    // Update cell displaying an upload request
    func updateCell(with identifier:String, stateLabel: String,
                    photoResize: Int16?, progress: Float?, errorMsg: String?) {
        
        var uploadInfo: [String : Any] = ["localIdentifier" : identifier,
                                          "stateLabel" : stateLabel]
        if let photoResize = photoResize {
            uploadInfo.updateValue(photoResize, forKey: "photoResize")
        }
        if let progress = progress {
            uploadInfo.updateValue(progress, forKey: "progressFraction")
        }
        DispatchQueue.main.async {
            // Update UploadQueue cell and button shown in root album (or default album)
            let name = NSNotification.Name(rawValue: kPiwigoNotificationUploadProgress)
            NotificationCenter.default.post(name: name, object: nil, userInfo: uploadInfo)
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
    @objc
    func findNextImageToUpload() -> Void {
        // Check current queue
        print("\(debugFormatter.string(from: Date())) > findNextImageToUpload() in", queueName())
        print("\(debugFormatter.string(from: Date())) > preparing:\(isPreparing ? "Yes" : "No"), uploading:\(isUploading.count), finishing:\(isFinishing ? "Yes" : "No")")

        // Update app badge and Upload button in root/default album
        // Considers only uploads to the server to which the user is logged in
        let states: [kPiwigoUploadState] = [.waiting, .preparing, .preparingError,
                                            .preparingFail, .formatError, .prepared,
                                            .uploading, .uploadingError, .uploaded,
                                            .finishing, .finishingError]
        nberOfUploadsToComplete = uploadsProvider.getRequestsIn(states: states).count
        
        // Determine the Power State and if it should wait
        if ProcessInfo.processInfo.isLowPowerModeEnabled || isPaused {
            // Low Power Mode is enabled. Stop transferring images.
            return
        }

        // Acceptable conditions for treating upload requests?
        guard let _ = Model.sharedInstance()?.serverProtocol,
            let _ = Model.sharedInstance()?.username,
            let _ = Model.sharedInstance()?.wifiOnlyUploading,
            let _ = Model.sharedInstance()?.hasAdminRights else {
            return
        }
        
        // Check network access and status
        if !AFNetworkReachabilityManager.shared().isReachable ||
            (AFNetworkReachabilityManager.shared().isReachableViaWWAN && Model.sharedInstance().wifiOnlyUploading) {
            return
        }

        // Interrupted work shoulds be set as if an error was encountered
        /// - case of finishes
        let finishingIDs = uploadsProvider.getRequestsIn(states: [.finishing])
        if !isFinishing {
            // Transfers encountered an error
            for uploadID in finishingIDs {
                print("\(debugFormatter.string(from: Date())) >  Interrupted finish —> \(uploadID.uriRepresentation())")
                uploadsProvider.updateStatusOfUpload(with: uploadID, to: .finishingError, error: UploadError.networkUnavailable.errorDescription) { [unowned self] (_) in
                    self.findNextImageToUpload()
                    return
                }
            }
        }
        /// - case of transfers (a few transfers may be running in parallel)
        let uploadingIDs = uploadsProvider.getRequestsIn(states: [.uploading])
        for uploadID in uploadingIDs {
            if !isUploading.contains(uploadID) {
                // Transfer encountered an error
                print("\(debugFormatter.string(from: Date())) >  Interrupted transfer —> \(uploadID.uriRepresentation())")
                uploadsProvider.updateStatusOfUpload(with: uploadID, to: .uploadingError, error: UploadError.networkUnavailable.errorDescription) { [unowned self] (_) in
                    self.findNextImageToUpload()
                    return
                }
            }
        }
        /// - case of preparations
        let preparingIDs = uploadsProvider.getRequestsIn(states: [.preparing])
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

        // Not finishing and upload request to finish?
        // Only called when uploading with the pwg.images.upload method
        // because the title cannot be set during the upload.
        let nberFinishedWithError = uploadsProvider.getRequestsIn(states: [.finishingError]).count
        if !isFinishing, nberFinishedWithError < 2,
           let uploadID = uploadsProvider.getRequestsIn(states: [.uploaded]).first {
            
            // Pause upload manager if app not in the foreground
            // and not executed in a background task
            if appState == .inactive {
                return
            }
            
            // Update state of upload resquest and finish upload
            uploadsProvider.updateStatusOfUpload(with: uploadID, to: .finishing, error: "") {
                [unowned self] (_) in
                // Finish the job by setting image parameters…
                self.isFinishing = true
                self.setImageParameters(for: uploadID)
            }
            return
        }

        // Not transferring and file ready for transfer?
        let nberUploadedWithError = uploadsProvider.getRequestsIn(states: [.uploadingError]).count
        if isUploading.count < maxNberOfTransfers, nberFinishedWithError < 2, nberUploadedWithError < 2,
           let uploadID = uploadsProvider.getRequestsIn(states: [.prepared]).first {

            // Pause upload manager if app not in the foreground
            // and not executed in a background task
            if appState == .inactive {
                return
            }

            // Upload file ready, so we start the transfer
            self.launchTransfer(of: uploadID)
            return
        }
        
        // Not preparing and upload request waiting?
        let nberPrepared = uploadsProvider.getRequestsIn(states: [.prepared]).count
        let nberPreparedWithError = uploadsProvider.getRequestsIn(states: [.preparingError]).count
        if !isPreparing, nberPrepared < 2, nberFinishedWithError < 2,
           nberUploadedWithError < 2, nberPreparedWithError < 2,
           let uploadID = uploadsProvider.getRequestsIn(states: [.waiting]).first {
            print("\(debugFormatter.string(from: Date())) > preparedWithError:\(nberPreparedWithError), uploadingWithError:\(nberUploadedWithError), finishedWithError:\(nberFinishedWithError)")

            // Pause upload manager if app not in the foreground
            // and not executed in a background task
            if appState == .inactive {
                return
            }

            // Prepare the next upload
            isPreparing = true
            self.prepare(for: uploadID)
            return
        }
        
        // No more image to transfer ;-)
        // Moderate images uploaded by Community regular user
        // Considers only uploads to the server to which the user is logged in
        let finishedUploads = uploadsProvider.getRequestsIn(states: [.finished])
        if Model.sharedInstance()?.hasNormalRights ?? false,
           Model.sharedInstance()?.usesCommunityPluginV29 ?? false, finishedUploads.count > 0 {

            // Pause upload manager if app not in the foreground
            // and not executed in a background task
            if appState == .inactive {
                return
            }

            // Moderate uploaded images
            self.moderate(completedRequests: finishedUploads)
            return
        }

        // Suggest to delete images from Photo Library if user wanted it
        // The deletion will only be suggested once and after completion of all uploads
        if uploadsProvider.getRequestsIn(states: states).count > 0 { return }
        
        // Upload requests are completed
        // Considers only uploads to the server to which the user is logged in
        let (imageIDs, uploadIDs) = uploadsProvider.getCompletedRequestsToBeDeleted()
        if !imageIDs.isEmpty, !uploadIDs.isEmpty {
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
    /// - transfers failed due to wrong MD5 checksum are retried a certain number of times.
    @objc let maxNberOfUploadsPerBackgroundTask = 100
    @objc var indexOfUploadRequestToPrepare = 0
    @objc var uploadRequestsToPrepare = [NSManagedObjectID]()
    @objc var indexOfUploadRequestToTransfer = 0
    @objc var uploadRequestsToTransfer = [NSManagedObjectID]()
    @objc var isExecutingBackgroundUploadTask = false

    @objc
    func selectUploadRequestsForBckgTask() -> Void {
        // Initialisation
        uploadRequestsToPrepare = [NSManagedObjectID]()
        uploadRequestsToTransfer = [NSManagedObjectID]()

        // Get list of upload requests rasdy for transfer and whose transfer did fail
        let requestsToTransfer = uploadsProvider.getRequestsIn(states: [.prepared, .uploadingError])
        let nberToTransfer = requestsToTransfer.count
        if nberToTransfer > 0 {
            if nberToTransfer > maxNberOfUploadsPerBackgroundTask {
                uploadRequestsToTransfer = Array(requestsToTransfer[..<maxNberOfUploadsPerBackgroundTask])
            }
            else {
                uploadRequestsToTransfer = requestsToTransfer
            }
        }
        
        // Get list of upload requests to prepare
        let nberToPrepare = maxNberOfUploadsPerBackgroundTask - uploadRequestsToTransfer.count
        let requestsToPrepare = uploadsProvider.getRequestsIn(states: [.waiting])
        if requestsToPrepare.count > nberToPrepare {
            uploadRequestsToPrepare = Array(requestsToPrepare[..<nberToPrepare])
        } else {
            uploadRequestsToPrepare = requestsToPrepare
        }
    }
    
    @objc
    func appendJobToBckgTask() -> Void {
        // Add image transfer operations first
        if indexOfUploadRequestToTransfer < uploadRequestsToTransfer.count {
            // Get objectID of upload request
            let uploadID = uploadRequestsToTransfer[indexOfUploadRequestToTransfer]
            print("\(debugFormatter.string(from: Date())) >•• appendTransfer \(uploadID.uriRepresentation())")
            // Launch transfer
            launchTransfer(of: uploadID)
            // Increment index for next call
            indexOfUploadRequestToTransfer += 1
        }
        // then image preparation followed by transfer operations
        else if indexOfUploadRequestToPrepare < uploadRequestsToPrepare.count {
            // Get objectID of upload request
            let uploadID = uploadRequestsToPrepare[indexOfUploadRequestToPrepare]
            print("\(debugFormatter.string(from: Date())) >•• appendPrepare \(uploadID.uriRepresentation())")
            // Prepare image for transfer
            prepare(for: uploadID)
            // Increment index for next call
            indexOfUploadRequestToPrepare += 1
        }
    }
    
    
    // MARK: - Prepare image
    private var _isPreparing = false
    private var isPreparing: Bool {
        get {
            return _isPreparing
        }
        set(isPreparing) {
            _isPreparing = isPreparing
        }
    }

    @objc
    func prepare(for uploadID: NSManagedObjectID) -> Void {
        print("\(debugFormatter.string(from: Date())) >> prepare \(uploadID.uriRepresentation())")

        // Retrieve upload request properties
        var uploadProperties: UploadProperties!
        let taskContext = DataController.getPrivateContext()
        do {
            let upload = try taskContext.existingObject(with: uploadID) as! Upload
            if upload.isFault {
                // The upload request is not fired yet.
                upload.willAccessValue(forKey: nil)
                uploadProperties = upload.getProperties()
                upload.didAccessValue(forKey: nil)
            } else {
                uploadProperties = upload.getProperties()
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
        if !self.isExecutingBackgroundUploadTask {
            updateCell(with: uploadProperties.localIdentifier,
                       stateLabel: kPiwigoUploadState.preparing.stateInfo,
                       photoResize: Int16(uploadProperties.photoResize),
                       progress: Float(0.0), errorMsg: "")
        }
        
        // Add category to list of recent albums
        let userInfo = ["categoryId": String(format: "%ld", Int(uploadProperties.category))]
        let name = NSNotification.Name(rawValue: kPiwigoNotificationAddRecentAlbum)
        NotificationCenter.default.post(name: name, object: nil, userInfo: userInfo)

        // Determine from where the file comes from:
        // => Photo Library: use PHAsset local identifier
        // => UIPasteborad: use identifier of type "Clipboard-yyyyMMdd-HHmmssSSSS-typ-#"
        //    where "typ" is "img" (photo) or "mov" (video).
        if uploadProperties.localIdentifier.contains("Clipboard-") {
            // Case of an image retrieved from the pasteboard
            prepareImageInPasteboard(for: uploadID, with: uploadProperties)
        } else {
            // Case of an image from the local Photo Library
            prepareImageInPhotoLibrary(for: uploadID, with: uploadProperties)
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
            print("\(debugFormatter.string(from: Date())) > could not perform a shallow search of the Uploads directory: \(error)")
        }
        guard let fileURL = files.filter({$0.absoluteString.contains(uploadProperties.localIdentifier)}).first else {
            // File not available… deleted?
            uploadsProvider.updateStatusOfUpload(with: uploadID, to: .preparingFail, error: UploadError.missingAsset.errorDescription) { [unowned self] (_) in

                // Update UI
                updateCell(with: uploadProperties.localIdentifier, stateLabel: uploadProperties.stateLabel,
                           photoResize: nil, progress: nil, errorMsg: kPiwigoUploadState.preparingFail.stateInfo)
 
                // Investigate next upload request?
                self.didEndPreparation()
            }
            return
        }
        var fileName = fileURL.lastPathComponent
        if uploadProperties.prefixFileNameBeforeUpload, let prefix = uploadProperties.defaultPrefix {
            if !fileName.hasPrefix(prefix) { fileName = prefix + fileName }
        }

        // Check/update serverFileTypes if possible
        if let fileTypes = Model.sharedInstance()?.serverFileTypes, fileTypes.count > 0 {
            uploadProperties.serverFileTypes = fileTypes
        }

        // Launch preparation job if file format accepted by Piwigo server
        let fileExt = (URL(fileURLWithPath: fileName).pathExtension).lowercased()
        if fileName.contains("img") {
            uploadProperties.isVideo = false

            // Set filename after removing "SSSS-img-#" suffix
            if let range = fileName.range(of: "-img") {
                uploadProperties.fileName = String(fileName[..<range.lowerBound].dropLast(4))
            }

            // Chek that the image format is accepted by the Piwigo server
            if uploadProperties.serverFileTypes.contains(fileExt) {
                // Image file format accepted by the Piwigo server
                // Update state of upload
                uploadProperties.requestState = .preparing
                uploadsProvider.updatePropertiesOfUpload(with: uploadID, properties: uploadProperties) { [unowned self] (_) in
                    // Launch preparation job
                    self.prepareImage(for: uploadID, with: uploadProperties, atURL: fileURL)
                }
                return
            }
            // Convert image if JPEG format is accepted by Piwigo server
            if uploadProperties.serverFileTypes.contains("jpg") {
                // Try conversion to JPEG
                if fileExt == "heic" || fileExt == "heif" || fileExt == "avci" {
                    // Will convert HEIC encoded image to JPEG
                    print("\(debugFormatter.string(from: Date())) > converting photo \(uploadProperties.fileName!)…")
                    
                    // Update state of upload
                    uploadProperties.requestState = .preparing
                    uploadsProvider.updatePropertiesOfUpload(with: uploadID, properties: uploadProperties) { [unowned self] (_) in
                        // Launch preparation job
                        self.prepareImage(for: uploadID, with: uploadProperties, atURL: fileURL)
                    }
                    return
                }
            }
            // Image file format cannot be accepted by the Piwigo server
            uploadProperties.requestState = .formatError

            // Update UI
            updateCell(with: uploadProperties.localIdentifier, stateLabel: uploadProperties.stateLabel,
                       photoResize: nil, progress: nil, errorMsg: kPiwigoUploadState.formatError.stateInfo)
            
            // Update upload request
            uploadsProvider.updatePropertiesOfUpload(with: uploadID, properties: uploadProperties) { [unowned self] (_) in
                // Investigate next upload request?
                self.didEndPreparation()
            }
        }
        else if fileName.contains("mov") {
            uploadProperties.isVideo = true

        }
        else {
            
        }
    }
    
    private func prepareImageInPhotoLibrary(for uploadID: NSManagedObjectID, with properties: UploadProperties) {
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
        uploadProperties.creationDate = originalAsset.creationDate ?? Date.init()
        
        // Determine non-empty unique file name and extension from asset
        var fileName = PhotosFetch.sharedInstance().getFileNameFomImageAsset(originalAsset)
        if uploadProperties.prefixFileNameBeforeUpload, let prefix = uploadProperties.defaultPrefix {
            if !fileName.hasPrefix(prefix) { fileName = prefix + fileName }
        }
        uploadProperties.fileName = fileName
        
        // Check/update serverFileTypes if possible
        if let fileTypes = Model.sharedInstance()?.serverFileTypes, fileTypes.count > 0 {
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
                    self.prepareImage(for: uploadID, with: uploadProperties, asset: originalAsset)
                }
                return
            }
            // Convert image if JPEG format is accepted by Piwigo server
            if uploadProperties.serverFileTypes.contains("jpg") {
                // Try conversion to JPEG
                if fileExt == "heic" || fileExt == "heif" || fileExt == "avci" {
                    // Will convert HEIC encoded image to JPEG
                    print("\(debugFormatter.string(from: Date())) > converting photo \(uploadProperties.fileName!)…")
                    
                    // Update state of upload
                    uploadProperties.requestState = .preparing
                    uploadsProvider.updatePropertiesOfUpload(with: uploadID, properties: uploadProperties) { [unowned self] (_) in
                        // Launch preparation job
                        self.prepareImage(for: uploadID, with: uploadProperties, asset: originalAsset)
                    }
                    return
                }
            }

            // Image file format cannot be accepted by the Piwigo server
            uploadProperties.requestState = .formatError

            // Update UI
            updateCell(with: uploadProperties.localIdentifier, stateLabel: uploadProperties.stateLabel,
                       photoResize: nil, progress: nil, errorMsg: kPiwigoUploadState.formatError.stateInfo)
            
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
                print("\(debugFormatter.string(from: Date())) > preparing video \(uploadProperties.fileName!)…")

                // Update state of upload
                uploadProperties.requestState = .preparing
                uploadsProvider.updatePropertiesOfUpload(with: uploadID, properties: uploadProperties) { [unowned self] (_) in
                    // Launch preparation job
                    self.prepareVideo(for: uploadID, with: uploadProperties, originalAsset)
                }
                return
            }
            // Convert video if MP4 format is accepted by Piwigo server
            if uploadProperties.serverFileTypes.contains("mp4") {
                // Try conversion to MP4
                if fileExt == "mov" {
                    // Will convert MOV encoded video to MP4
                    print("\(debugFormatter.string(from: Date())) > converting video \(uploadProperties.fileName!)…")

                    // Update state of upload
                    uploadProperties.requestState = .preparing
                    uploadsProvider.updatePropertiesOfUpload(with: uploadID, properties: uploadProperties) { [unowned self] (_) in
                        // Launch preparation job
                        self.convertVideo(for: uploadID, with: uploadProperties, originalAsset)
                    }
                    return
                }
            }
            // Video file format cannot be accepted by the Piwigo server
            uploadProperties.requestState = .formatError
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

    @objc func didEndPreparation() {
        _isPreparing = false
        if isExecutingBackgroundUploadTask { return }
        if isUploading.count <= maxNberOfTransfers, !isFinishing { findNextImageToUpload() }
    }

    
    // MARK: - Transfer image
    @objc let maxNberOfTransfers = 1
    private var _isUploading = Set<NSManagedObjectID>()
    private var isUploading: Set<NSManagedObjectID> {
        get {
            return _isUploading
        }
        set(isUploading) {
            _isUploading = isUploading
        }
    }

    @objc
    func launchTransfer(of uploadID: NSManagedObjectID) -> Void {
        print("\(debugFormatter.string(from: Date())) >> launch transfer of \(uploadID.uriRepresentation())")

        // Update list of transfers
        if isUploading.contains(uploadID) { return }
        isUploading.insert(uploadID)

        // Retrieve upload request properties
        var uploadProperties: UploadProperties!
        let taskContext = DataController.getPrivateContext()
        do {
            let upload = try taskContext.existingObject(with: uploadID) as! Upload
            if upload.isFault {
                // The upload request is not fired yet.
                upload.willAccessValue(forKey: nil)
                uploadProperties = upload.getProperties()
                upload.didAccessValue(forKey: nil)
            } else {
                uploadProperties = upload.getProperties()
            }
        }
        catch {
            print("\(debugFormatter.string(from: Date())) > missing Core Data object \(uploadID.uriRepresentation())!")
            // Investigate next upload request?
            self.didEndTransfer(for: uploadID)
            return
        }

        // Update UI
        if !self.isExecutingBackgroundUploadTask {
            updateCell(with: uploadProperties.localIdentifier,
                       stateLabel: kPiwigoUploadState.uploading.stateInfo,
                       photoResize: nil, progress: Float(0), errorMsg: nil)
        }

        // Update state of upload request
        uploadsProvider.updateStatusOfUpload(with: uploadID, to: .uploading, error: "") { [unowned self] (_) in

            // Choose recent method if possible
            if Model.sharedInstance()?.usesUploadAsync ?? false || isExecutingBackgroundUploadTask {
                self.transferInBackgroundImage(for: uploadID, with: uploadProperties)
            } else {
                self.transferImage(for: uploadID, with: uploadProperties)
            }

            // Do not prepare next image in background task (already scheduled)
            if self.isExecutingBackgroundUploadTask { return }
            
            // Stop here if there no image to prepare
            if uploadsProvider.getRequestsIn(states: [.waiting]).count == 0 { return }

            // Should we prepare the next image in parallel?
            let nberFinishedWithError = uploadsProvider.getRequestsIn(states: [.finishingError]).count
            let nberUploadedWithError = uploadsProvider.getRequestsIn(states: [.uploadingError]).count
            let nberPreparedWithError = uploadsProvider.getRequestsIn(states: [.preparingError]).count
            let uploadIDsToPrepare = uploadsProvider.getRequestsIn(states: [.waiting])
            if !self.isPreparing, let uploadID = uploadIDsToPrepare.first,
               nberFinishedWithError < 2, nberUploadedWithError < 2, nberPreparedWithError < 2 {

                // Prepare the next upload
                self.isPreparing = true
                self.prepare(for: uploadID)
                return
            }
        }
    }

    @objc func didEndTransfer(for uploadID: NSManagedObjectID) {
        // Update list of current uploads
        isUploading.remove(uploadID)
        
        // In background task: stop operation here
        if self.isExecutingBackgroundUploadTask { return }
        
        // In foreground, always consider next file
        if !isPreparing, isUploading.count <= maxNberOfTransfers, !isFinishing { findNextImageToUpload() }
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

    @objc func didSetParameters() {
        _isFinishing = false
        if !isPreparing, isUploading.count <= maxNberOfTransfers { findNextImageToUpload() }
    }

    
    // MARK: - Uploaded Images Management
    
    private func moderate(completedRequests : [NSManagedObjectID]) -> Void {
        
        // Get completed upload requests
        let taskContext = DataController.getPrivateContext()
        var uploadedImages = [Upload]()
        completedRequests.forEach { (objectId) in
            uploadedImages.append(taskContext.object(with: objectId) as! Upload)
        }

        // Get list of categories
        let categories = IndexSet(uploadedImages.map({Int($0.category)}))
        
        // Moderate images by category
        for categoryId in categories {
            // Set list of images to moderate in that category
            let categoryImages = uploadedImages.filter({ $0.category == categoryId})
            let imageIds = categoryImages.map( { String(format: "%ld,", $0.imageId) } ).reduce("", +)
            
            // Moderate uploaded images
            moderateImages(withIds: imageIds, inCategory: categoryId) { (success) in
                if success {
                    // Update upload resquests to remember that the moderation was requested
                    var uploadsProperties = [UploadProperties]()
                    categoryImages.forEach { (moderatedUpload) in
                        uploadsProperties.append(moderatedUpload.getProperties(with: .moderated, error: ""))
                    }
                    self.uploadsProvider.importUploads(from: uploadsProperties) { [unowned self] (error) in
                        guard let _ = error else {
                            return  // Will retry later
                        }
                        self.findNextImageToUpload()    // Might still have to delete images
                    }
                } else {
                    return  // Will try later
                }
            }
        }
    }

    func delete(uploadedImages: [String], with uploadIDs: [NSManagedObjectID]) -> Void {

        // Get image assets of images to delete
        let assetsToDelete = PHAsset.fetchAssets(withLocalIdentifiers: uploadedImages, options: nil)
        
        // Delete images from Photo Library
        DispatchQueue.main.async(execute: {
            PHPhotoLibrary.shared().performChanges({
                // Delete images from the library
                PHAssetChangeRequest.deleteAssets(assetsToDelete as NSFastEnumeration)
            }, completionHandler: { success, error in
                if success == true {
                    // Delete upload requests in a private queue
                    DispatchQueue.global(qos: .userInitiated).async {
                        self.uploadsProvider.delete(uploadRequests: uploadIDs)
                    }
                }
            })
        })
    }
    
   
    // MARK: - Failed Uploads Management
    
    @objc func resumeAll() -> Void {
        // Reset flags
        appState = .active
        isPreparing = false; isFinishing = false
        isExecutingBackgroundUploadTask = false
        isUploading = Set<NSManagedObjectID>()
        
        // Get active upload tasks
        let taskContext = DataController.getPrivateContext()
        let uploadSession: URLSession = UploadSessionDelegate.shared.uploadSession
        uploadSession.getTasksWithCompletionHandler { (_, uploadTasks, _) in
            // Loop over the tasks
            for task in uploadTasks {
                switch task.state {
                case .running:
                    // Retrieve upload request properties
//                    print("======>> task \(task.taskIdentifier) - \(task.taskDescription ?? "no description")")
                    guard let taskDescription = task.taskDescription else { continue }
                    guard let objectURI = URL.init(string: taskDescription) else {
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
                let states: [kPiwigoUploadState] = [.preparingError, .preparingFail, .formatError,
                                                    .uploadingError, .finishingError]
                let failedUploads = self.uploadsProvider.getRequestsIn(states: states)
                if failedUploads.count > 0 {
                    // Resume failed uploads
                    self.resume(failedUploads: failedUploads) { (_) in
                        // Pursue the work
                        self.findNextImageToUpload()
                    }
                } else {
                    // Clean cache from completed uploads whose images do not exist in Photo Library
                    self.uploadsProvider.clearCompletedUploads()
                    // Pursue the work
                    self.findNextImageToUpload()
                }
            }
        }
    }

    func resume(failedUploads: [NSManagedObjectID], completionHandler: @escaping (Error?) -> Void) -> Void {
        
        // Initialisation
        var uploadsToUpdate = [UploadProperties]()
        
        // Create a private queue context.
        let taskContext = DataController.getPrivateContext()

        // Loop over the failed uploads
        for failedUploadID in failedUploads {
            do {
                // Get upload request
                let failedUpload = try (taskContext.existingObject(with: failedUploadID) as! Upload)

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
            completionHandler(error)
        }
    }
    
    func deleteFilesInUploadsDirectory(with prefix: String?) -> Void {
        let fileManager = FileManager.default
        do {
            // Get list of files
            var filesToDelete: [URL] = []
            let files = try fileManager.contentsOfDirectory(at: self.applicationUploadsDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
            if let prefix = prefix {
                // Will delete files with given prefix
                filesToDelete = files.filter({$0.lastPathComponent.hasPrefix(prefix)})
            } else {
                // Will delete all files
                filesToDelete = files
            }

            // Delete files
            for file in filesToDelete {
                try fileManager.removeItem(at: file)
            }

            // For debugging
//            let leftFiles = try fileManager.contentsOfDirectory(at: self.applicationUploadsDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
//            print("\(debugFormatter.string(from: Date())) > Remaining files in cache: \(leftFiles)")
        } catch {
            print("\(debugFormatter.string(from: Date())) > could not clear the Uploads folder: \(error)")
        }
    }
}


// MARK: - For checking operation queue
/// The name/description of the current queue (Operation or Dispatch), if that can be found. Else, the name/description of the thread.
public func queueName() -> String {
    if let currentOperationQueue = OperationQueue.current {
        if let currentDispatchQueue = currentOperationQueue.underlyingQueue {
            return "dispatch queue: \(currentDispatchQueue.label.nonEmpty ?? currentDispatchQueue.description)"
        }
        else {
            return "operation queue: \(currentOperationQueue.name?.nonEmpty ?? currentOperationQueue.description)"
        }
    }
    else {
        let currentThread = Thread.current
        return "thread: \(currentThread.name?.nonEmpty ?? currentThread.description)"
    }
}

public extension String {

    /// Returns this string if it is not empty, else `nil`.
    var nonEmpty: String? {
        if self.isEmpty {
            return nil
        }
        else {
            return self
        }
    }
}

