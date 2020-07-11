//
//  UploadManager.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 22/05/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import Foundation
import Photos

let kPiwigoNotificationUploadProgress = "kPiwigoNotificationUploadProgress"

@objc
class UploadManager: NSObject {

    // MARK: - Initialisation
    override init() {
        super.init()
        
        NotificationCenter.default.addObserver(self, selector: #selector(didBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(willResignActive), name: UIApplication.willResignActiveNotification, object: nil)
    }

    private var appState = UIApplication.State.active
    @objc func didBecomeActive() -> Void {
        // Executed when the application is about to move from inactive to active state.
        print("•••>> didBecomeActive")
        appState = UIApplication.State.active
        findNextImageToUpload()
    }
    
    @objc func willResignActive() -> Void {
        // Executed when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        print("•••>> willResignActive")
        appState = UIApplication.State.inactive
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
    }
    
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

    
    // MARK: - Core Data
    /**
     The UploadsProvider that collects upload data, saves it to Core Data,
     and serves it to the uploader.
     */
    private lazy var uploadsProvider: UploadsProvider = {
        let provider : UploadsProvider = UploadsProvider()
        return provider
    }()

    
    // MARK: - Background Tasks Manager
    /** The manager prepares an image for upload and then launches the transfer.
    - isPreparing tells that an image/video is being prepared for upload.
    - isUploading tells that an image/video is being transferred to the server.
    - isFinishing tells that the image/video parameters are being set.
    */
    @objc func setIsPaused(status : Bool) {
        _isPaused = status
    }
    private var _isPaused = false
    private var isPaused: Bool {
        get {
            return _isPaused
        }
        set(isPaused) {
            _isPaused = isPaused
        }
    }

    @objc func setIsPreparing(status : Bool) {
        _isPreparing = status
        if !status, !isUploading, !isFinishing { findNextImageToUpload() }
    }
    private var _isPreparing = false
    private var isPreparing: Bool {
        get {
            return _isPreparing
        }
        set(isPreparing) {
            _isPreparing = isPreparing
        }
    }

    @objc func setIsUploading(status : Bool) {
        _isUploading = status
        if !isPreparing, !status, !isFinishing { findNextImageToUpload() }
    }
    private var _isUploading = false
    private var isUploading: Bool {
        get {
            return _isUploading
        }
        set(isUploading) {
            _isUploading = isUploading
        }
    }

    @objc func setIsFinishing(status : Bool) {
        _isFinishing = status
        if !isPreparing, !isUploading, !status { findNextImageToUpload() }
    }
    private var _isFinishing = false
    private var isFinishing: Bool {
        get {
            return _isFinishing
        }
        set(isFinishing) {
            _isFinishing = isFinishing
        }
    }
        
    @objc
    func findNextImageToUpload() -> Void {
        print("•••>> findNextImageToUpload()", self.debugDescription)
        print("    > ", isPaused, "|", isPreparing, "|", isUploading, "|", isFinishing)

        // Pause upload maneger if app not in the foreground
        if appState == .background || appState == .inactive {
            print("    > NOT IN FOREGROUND !!!")
            return
        }

        // Check network access and status
        if isPaused || !AFNetworkReachabilityManager.shared().isReachable {
            return
        }

        // Get uploads in queue
        guard let allUploads = uploadsProvider.requestsToComplete() else {
            return
        }
        
        // Any interrupted transfer?
        if !isFinishing, let upload = allUploads.first(where: { $0.state == .finishing }) {
            // Transfer encountered an error
            let uploadProperties = UploadProperties.init(localIdentifier: upload.localIdentifier,
                category: Int(upload.category),
                requestDate: upload.requestDate, requestState: .finishingError,
                requestDelete: upload.requestDelete, requestError: UploadError.networkUnavailable.errorDescription,
                creationDate: upload.creationDate, fileName: upload.fileName, mimeType: upload.mimeType,
                isVideo: upload.isVideo, author: upload.author, privacyLevel: upload.privacy,
                imageTitle: upload.imageName, comment: upload.comment, tags: upload.tags, imageId: Int(upload.imageId))
            
            print("    >  Interrupted finish")
            uploadsProvider.updateRecord(with: uploadProperties, completionHandler: { [unowned self] _ in
                self.findNextImageToUpload()
                return
            })
        }
        if !isUploading, let upload = allUploads.first(where: { $0.state == .uploading }) {
            // Transfer encountered an error
            let uploadProperties = UploadProperties.init(localIdentifier: upload.localIdentifier,
                category: Int(upload.category),
                requestDate: upload.requestDate, requestState: .uploadingError,
                requestDelete: upload.requestDelete, requestError: UploadError.networkUnavailable.errorDescription,
                creationDate: upload.creationDate, fileName: upload.fileName, mimeType: upload.mimeType,
                isVideo: upload.isVideo, author: upload.author, privacyLevel: upload.privacy,
                imageTitle: upload.imageName, comment: upload.comment, tags: upload.tags, imageId: Int(upload.imageId))

            print("    >  Interrupted upload")
            uploadsProvider.updateRecord(with: uploadProperties, completionHandler: { [unowned self] _ in
                self.findNextImageToUpload()
                return
            })
        }
        if !isPreparing, let upload = allUploads.first(where: { $0.state == .preparing }) {
            // Transfer encountered an error
            let uploadProperties = UploadProperties.init(localIdentifier: upload.localIdentifier,
                category: Int(upload.category),
                requestDate: upload.requestDate, requestState: .preparingError,
                requestDelete: upload.requestDelete, requestError: UploadError.networkUnavailable.errorDescription,
                creationDate: upload.creationDate, fileName: upload.fileName, mimeType: upload.mimeType,
                isVideo: upload.isVideo, author: upload.author, privacyLevel: upload.privacy,
                imageTitle: upload.imageName, comment: upload.comment, tags: upload.tags, imageId: Int(upload.imageId))

            print("    >  Interrupted preparation")
            uploadsProvider.updateRecord(with: uploadProperties, completionHandler: { [unowned self] _ in
                self.findNextImageToUpload()
                return
            })
        }

        // Not finishing and upload request to finish?
        let nberFinishedWithError = allUploads.filter({ $0.state == .finishingError } ).count
        if !isFinishing, nberFinishedWithError < 2,
            let upload = allUploads.first(where: { $0.state == .uploaded } ) {
            // Finish upload
            isFinishing = true
            DispatchQueue.global(qos: .background).async {
                self.finish(nextUpload: upload)
            }
            return
        }

        // Not transferring and file ready for transfer?
        let nberUploadedWithError = allUploads.filter({ $0.state == .uploadingError } ).count
        if !isUploading, nberFinishedWithError < 2, nberUploadedWithError < 2,
            let upload = allUploads.first(where: { $0.state == .prepared }) {
            // Upload ready, so start the transfer
            isUploading = true
            DispatchQueue.global(qos: .background).async {
                self.transfer(nextUpload: upload)
            }
            return
        }
        
        // Not preparing and upload request waiting?
        let nberPreparedWithError = allUploads.filter({ $0.state == .preparingError } ).count
        if !isPreparing, nberFinishedWithError < 2, nberUploadedWithError < 2, nberPreparedWithError < 2,
            let nextUpload = allUploads.first(where: { $0.state == .waiting }) {
            // Prepare the next upload
            isPreparing = true
            DispatchQueue.global(qos: .background).async {
                self.prepare(nextUpload: nextUpload)
            }
            return
        }
        
        // No more image to transfer
        // Moderate uploaded images if Community plugin installed
        if Model.sharedInstance().usesCommunityPluginV29 {
            DispatchQueue.global(qos: .background).async {
                self.moderateUploadedImages()
            }
            return
        }

        // Delete images from Photo Library if user wanted it
        let uploadsToDelete = allUploads.filter({ $0.state == .finished && $0.requestDelete == true })
        DispatchQueue.global(qos: .background).async {
            self.delete(uploadedImages: uploadsToDelete)
        }
    }

    private func prepare(nextUpload: Upload) -> Void {
        print("•••>> prepare next upload…")

        // Pause upload maneger if app not in the foreground
        if appState == .background || appState == .inactive {
            print("    > NOT IN FOREGROUND !!!")
            return
        }

        // Add category to list of recent albums
        let userInfo = ["categoryId": String(format: "%ld", Int(nextUpload.category))]
        let name = NSNotification.Name(rawValue: kPiwigoNotificationAddRecentAlbum)
        NotificationCenter.default.post(name: name, object: nil, userInfo: userInfo)

        // Set upload properties
        if nextUpload.isFault {
            // The upload request is not fired yet.
            print("    > nextUpload.isFault !!!!!!!!!!!!!!")
        }
        var uploadProperties = UploadProperties.init(localIdentifier: nextUpload.localIdentifier,
            category: Int(nextUpload.category),
            requestDate: nextUpload.requestDate, requestState: nextUpload.state,
            requestDelete: nextUpload.requestDelete, requestError: nextUpload.requestError,
            creationDate: nextUpload.creationDate, fileName: nextUpload.fileName,
            mimeType: nextUpload.mimeType, isVideo: nextUpload.isVideo,
            author: nextUpload.author, privacyLevel: nextUpload.privacy,
            imageTitle: nextUpload.imageName, comment: nextUpload.comment,
            tags: nextUpload.tags, imageId: NSNotFound)

        // Retrieve image asset
        guard let originalAsset = PHAsset.fetchAssets(withLocalIdentifiers: [nextUpload.localIdentifier], options: nil).firstObject else {
            // Asset not available… deleted?
            uploadProperties.requestState = .preparingFail
            uploadProperties.requestError = UploadError.missingAsset.errorDescription
            self.uploadsProvider.updateRecord(with: uploadProperties, completionHandler: { _ in
                // Consider next image
                self.isPreparing = false
                self.findNextImageToUpload()
            })
            return
        }

        // Retrieve creation date
        uploadProperties.creationDate = originalAsset.creationDate ?? Date.init()
        
        // Determine non-empty unique file name and extension from asset
        uploadProperties.fileName = PhotosFetch.sharedInstance().getFileNameFomImageAsset(originalAsset)
        let fileExt = (URL(fileURLWithPath: uploadProperties.fileName!).pathExtension).lowercased()
        
        // Launch preparation job if file format accepted by Piwigo server
        switch originalAsset.mediaType {
        case .image:
            uploadProperties.isVideo = false
            // Chek that the image format is accepted by the Piwigo server
            if Model.sharedInstance().uploadFileTypes.contains(fileExt) {
                // Image file format accepted by the Piwigo server
                print("•••>> preparing photo \(uploadProperties.fileName!)…")

                // Update state of upload
                uploadProperties.requestState = .preparing
                uploadsProvider.updateRecord(with: uploadProperties, completionHandler: { _ in
                    // Launch preparation job
                    let image = UploadImage()
                    image.uploadManager = self
                    image.prepare(uploadProperties, from: originalAsset)
                })
                return
            }
            // Convert image if JPEG format is accepted by Piwigo server
            if Model.sharedInstance().uploadFileTypes.contains("jpg") {
                // Try conversion to JPEG
                if fileExt == "heic" || fileExt == "heif" || fileExt == "avci" {
                    // Will convert HEIC encoded image to JPEG
                    print("•••>> preparing photo \(uploadProperties.fileName!)…")
                    
                    // Update state of upload
                    uploadProperties.requestState = .preparing
                    uploadsProvider.updateRecord(with: uploadProperties, completionHandler: { _ in
                        // Launch preparation job
                        let image = UploadImage()
                        image.uploadManager = self
                        image.prepare(uploadProperties, from: originalAsset)
                    })
                    return
                }
            }
            // Image file format cannot be accepted by the Piwigo server
            uploadProperties.requestState = .formatError
            uploadsProvider.updateRecord(with: uploadProperties, completionHandler: { _ in
                // Investigate next upload request
                self.isPreparing = false
                self.findNextImageToUpload()
            })
//            showError(withTitle: NSLocalizedString("imageUploadError_title", comment: "Image Upload Error"), andMessage: NSLocalizedString("imageUploadError_format", comment: "Sorry, image files with extensions .\(fileExt.uppercased()) and .jpg are not accepted by the Piwigo server."), forRetrying: false, withImage: nextImageToBeUploaded)

        case .video:
            uploadProperties.isVideo = true
            // Chek that the video format is accepted by the Piwigo server
            if Model.sharedInstance().uploadFileTypes.contains(fileExt) {
                // Video file format accepted by the Piwigo server
                print("•••>> preparing video \(nextUpload.fileName!)…")

                // Update state of upload
                uploadProperties.requestState = .preparing
                uploadsProvider.updateRecord(with: uploadProperties, completionHandler: { _ in
                    // Launch preparation job
                    let video = UploadVideo()
                    video.uploadManager = self
                    video.prepare(uploadProperties, from: originalAsset)
                })
                return
            }
            // Convert video if MP4 format is accepted by Piwigo server
            if Model.sharedInstance().uploadFileTypes.contains("mp4") {
                // Try conversion to MP4
                if fileExt == "mov" {
                    // Will convert MOV encoded video to MP4
                    print("•••>> preparing video \(nextUpload.fileName!)…")

                    // Update state of upload
                    uploadProperties.requestState = .preparing
                    uploadsProvider.updateRecord(with: uploadProperties, completionHandler: { _ in
                        // Launch preparation job
                        let video = UploadVideo()
                        video.uploadManager = self
                        video.convert(originalAsset, for: uploadProperties)
                    })
                    return
                }
            }
            // Video file format cannot be accepted by the Piwigo server
            uploadProperties.requestState = .formatError
            uploadsProvider.updateRecord(with: uploadProperties, completionHandler: { _ in
                // Investigate next upload request
                self.isPreparing = false
                self.findNextImageToUpload()
            })
//                showError(withTitle: NSLocalizedString("videoUploadError_title", comment: "Video Upload Error"), andMessage: NSLocalizedString("videoUploadError_format", comment: "Sorry, video files with extension .\(fileExt.uppercased()) are not accepted by the Piwigo server."), forRetrying: false, withImage: uploadToPrepare)

        case .audio:
            // Update state of upload: Not managed by Piwigo iOS yet…
            uploadProperties.requestState = .formatError
            uploadsProvider.updateRecord(with: uploadProperties, completionHandler: { _ in
                // Investigate next upload request
                self.isPreparing = false
                self.findNextImageToUpload()
            })
//            showError(withTitle: NSLocalizedString("audioUploadError_title", comment: "Audio Upload Error"), andMessage: NSLocalizedString("audioUploadError_format", comment: "Sorry, audio files are not supported by Piwigo Mobile yet."), forRetrying: false, withImage: uploadToPrepare)

        case .unknown:
            fallthrough
        default:
            // Update state of upload request: Unknown format
            uploadProperties.requestState = .formatError
            uploadsProvider.updateRecord(with: uploadProperties, completionHandler: { _ in
                // Investigate next upload request
                self.isPreparing = false
                self.findNextImageToUpload()
            })
        }
    }
    
    private func transfer(nextUpload: Upload) -> Void {
        print("•••>> starting transfer of \(nextUpload.fileName!)…")

        // Pause upload maneger if app not in the foreground
        if appState == .background || appState == .inactive {
            print("    > NOT IN FOREGROUND !!!")
            return
        }

        // Set upload properties
        var uploadProperties = UploadProperties.init(localIdentifier: nextUpload.localIdentifier,
            category: Int(nextUpload.category),
            requestDate: nextUpload.requestDate, requestState: nextUpload.state,
            requestDelete: nextUpload.requestDelete, requestError: nextUpload.requestError,
            creationDate: nextUpload.creationDate, fileName: nextUpload.fileName,
            mimeType: nextUpload.mimeType, isVideo: nextUpload.isVideo,
            author: nextUpload.author, privacyLevel: nextUpload.privacy,
            imageTitle: nextUpload.imageName, comment: nextUpload.comment,
            tags: nextUpload.tags, imageId: Int(nextUpload.imageId))

        // Update state of upload request
        uploadProperties.requestState = .uploading
        uploadsProvider.updateRecord(with: uploadProperties, completionHandler: { _ in
            // Launch transfer if possible
            let transfer = UploadTransfer()
            transfer.uploadManager = self
            transfer.imageOfRequest(uploadProperties)
        })
    }
    
    // Called when using Piwigo server before version 2.10.x?
    // because the title could not be set during the upload.
    private func finish(nextUpload: Upload) -> Void {
        print("•••>> finishing transfer of \(nextUpload.fileName!)…")

        // Pause upload maneger if app not in the foreground
        if appState == .background || appState == .inactive {
            print("    > NOT IN FOREGROUND !!!")
            return
        }

        // Set upload properties
        var uploadProperties = UploadProperties.init(localIdentifier: nextUpload.localIdentifier,
            category: Int(nextUpload.category),
            requestDate: nextUpload.requestDate, requestState: nextUpload.state,
            requestDelete: nextUpload.requestDelete, requestError: nextUpload.requestError,
            creationDate: nextUpload.creationDate, fileName: nextUpload.fileName,
            mimeType: nextUpload.mimeType, isVideo: nextUpload.isVideo,
            author: nextUpload.author, privacyLevel: nextUpload.privacy,
            imageTitle: nextUpload.imageName, comment: nextUpload.comment,
            tags: nextUpload.tags, imageId: Int(nextUpload.imageId))

        // Update state of upload resquest
        uploadProperties.requestState = .finishing
        uploadsProvider.updateRecord(with: uploadProperties, completionHandler: { _ in
            // Finish the job by setting image parameters…
            let finish = UploadFinisher()
            finish.uploadManager = self
            finish.imageOfRequest(upload: uploadProperties)
        })
    }


    // MARK: - Uploaded Images Management
    
    private func moderateUploadedImages() -> Void {
        // Get uploads in queue
        guard let allUploads = uploadsProvider.fetchedResultsController.fetchedObjects else {
            return
        }
        // Get uploaded images to moderate
        let uploadedImages = allUploads.filter({ $0.state == .finished })
        
        // Get list of categories
        let categories = IndexSet(uploadedImages.map({Int($0.category)}))
        
        // Quit if App not in the foreground
        DispatchQueue.main.async {
            let appState = UIApplication.shared.applicationState
            if appState == .background || appState == .inactive {
                print("    > will moderate later: NOT IN FOREGROOUND !!!")
                return
            }
        }
        
        // Moderate images by category
        for category in categories {
            let imageIds = uploadedImages.filter({ $0.category == category}).map( { String(format: "%ld,", $0.imageId) } ).reduce("", +)
            // Moderate uploaded images
            UploadFinisher().moderateImages(imageIds: imageIds, inCategory: category)
        }
    }

    func delete(uploadedImages : [Upload]) -> Void {
        // Get local identifiers of uploaded images to delete
        let uploadedImagesToDelete = uploadedImages.map( { $0.localIdentifier} )
        
        // Get image assets of images to delete
        let assetsToDelete = PHAsset.fetchAssets(withLocalIdentifiers: uploadedImagesToDelete, options: nil)
        
        // Delete images from Photo Library
        DispatchQueue.main.async(execute: {
            PHPhotoLibrary.shared().performChanges({
                // Delete images from the library
                PHAssetChangeRequest.deleteAssets(assetsToDelete as NSFastEnumeration)
            }, completionHandler: { success, error in
                if success == true {
                    // Delete upload requests in background
                    self.uploadsProvider.delete(uploadRequests: uploadedImages)
                } else {
                    // User refused to delete the photos
                    var uploadsToUpdate = [UploadProperties]()
                    for upload in uploadedImages {
                        let uploadProperties = UploadProperties.init(localIdentifier: upload.localIdentifier,
                            category: Int(upload.category),
                            requestDate: upload.requestDate, requestState: upload.state,
                            requestDelete: false, requestError: upload.requestError,
                            creationDate: upload.creationDate, fileName: upload.fileName,
                            mimeType: upload.mimeType, isVideo: upload.isVideo,
                            author: upload.author, privacyLevel: upload.privacy,
                            imageTitle: upload.imageName, comment: upload.comment, tags: upload.tags, imageId: Int(upload.imageId))
                        uploadsToUpdate.append(uploadProperties)
                    }
                    self.uploadsProvider.importUploads(from: uploadsToUpdate) { (_) in
                        // Done ;-)
                    }
                }
            })
        })
    }
    
   
    // MARK: - Failed Uploads Management
    
    @objc func resumeAll() -> Void {
        isPaused = false
        isPreparing = false
        isUploading = false
        isFinishing = false
        if let failedUploads = uploadsProvider.requestsToResume() {
            // Resume failed uploads
            resume(failedUploads: failedUploads) { (_) in }
        }
    }

    func resume(failedUploads : [Upload], completionHandler: @escaping (Error?) -> Void) -> Void {
        
        // Initialisation
        var uploadsToUpdate = [UploadProperties]()
        
        // Loop over the failed uploads
        for failedUpload in failedUploads {
            
            // Create upload properties with no error
            var uploadProperties = UploadProperties.init(localIdentifier: failedUpload.localIdentifier,
                category: Int(failedUpload.category),
                requestDate: failedUpload.requestDate, requestState: failedUpload.state,
                requestDelete: failedUpload.requestDelete, requestError: "",
                creationDate: failedUpload.creationDate, fileName: failedUpload.fileName,
                mimeType: failedUpload.mimeType, isVideo: failedUpload.isVideo,
                author: failedUpload.author, privacyLevel: failedUpload.privacy,
                imageTitle: failedUpload.imageName, comment: failedUpload.comment,
                tags: failedUpload.tags, imageId: Int(failedUpload.imageId))
            
            // Update state from which to try again
            switch failedUpload.state {
            case .preparingError, .uploadingError:
                // -> Will try to re-prepare the image
                uploadProperties.requestState = .waiting
            case .finishingError:
                // -> Will try again to finish the upload
                uploadProperties.requestState = .uploaded
            default:
                uploadProperties.requestState = .waiting
            }
            
            // Append updated upload
            uploadsToUpdate.append(uploadProperties)
        }
        
        // Update failed uploads
        self.uploadsProvider.importUploads(from: uploadsToUpdate) { (error) in
            if let error = error {
                completionHandler(error)
                return;
            }
            // Launch uploads
            self.findNextImageToUpload()
            completionHandler(nil)
        }
    }
    
    func emptyUploadsDirectory() -> Void {
        let fileManager = FileManager.default
        do {
            // Get list of files
            let files = try fileManager.contentsOfDirectory(at: self.applicationUploadsDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
//            print("all files in cache: \(files)")
            // Delete files
            for file in files {
                try fileManager.removeItem(at: file)
            }
            // For debugging
//            let leftFiles = try fileManager.contentsOfDirectory(at: self.applicationUploadsDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
//            print("all files in cache after deleting images: \(leftFiles)")
        } catch {
            print("Could not clear upload folder: \(error)")
        }
    }
}
