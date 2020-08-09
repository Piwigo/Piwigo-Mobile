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

let kPiwigoNotificationUploadProgress = "kPiwigoNotificationUploadProgress"

@objc
class UploadManager: NSObject, URLSessionDelegate {

    @objc static var shared = UploadManager()

    // MARK: - Initialisation
    override init() {
        super.init()
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.didBecomeActive),
                                               name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.willResignActive),
                                               name: UIApplication.willResignActiveNotification, object: nil)
//        NotificationCenter.default.addObserver(self, selector: #selector(self.findNextImageToUpload),
//                                               name: NSNotification.Name.NSProcessInfoPowerStateDidChange, object: nil)
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

    // MARK: - Networking
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
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
//        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.NSProcessInfoPowerStateDidChange, object: nil)

        // Close upload session
        sessionManager.invalidateSessionCancelingTasks(true, resetSession: true)
    }
    

    // MARK: - Image Formats
    // See https://en.wikipedia.org/wiki/List_of_file_signatures
    // https://mimesniff.spec.whatwg.org/#sniffing-in-an-image-context

    // https://en.wikipedia.org/wiki/BMP_file_format
    var bmp: [UInt8] = "BM".map { $0.asciiValue! }
    
    // https://en.wikipedia.org/wiki/GIF
    var gif87a: [UInt8] = "GIF87a".map { $0.asciiValue! }
    var gif89a: [UInt8] = "GIF89a".map { $0.asciiValue! }
    
    // https://en.wikipedia.org/wiki/High_Efficiency_Image_File_Format
    var heic: [UInt8] = [0x00, 0x00, 0x00, 0x18] + "ftypheic".map { $0.asciiValue! }
    
    // https://en.wikipedia.org/wiki/ILBM
    var iff: [UInt8] = "FORM".map { $0.asciiValue! }
    
    // https://en.wikipedia.org/wiki/JPEG
    var jpg: [UInt8] = [0xff, 0xd8, 0xff]
    
    // https://en.wikipedia.org/wiki/JPEG_2000
    var jp2: [UInt8] = [0x00, 0x00, 0x00, 0x0c, 0x6a, 0x50, 0x20, 0x20, 0x0d, 0x0a, 0x87, 0x0a]
    
    // https://en.wikipedia.org/wiki/Portable_Network_Graphics
    var png: [UInt8] = [0x89] + "PNG".map { $0.asciiValue! } + [0x0d, 0x0a, 0x1a, 0x0a]
    
    // https://en.wikipedia.org/wiki/Adobe_Photoshop#File_format
    var psd: [UInt8] = "8BPS".map { $0.asciiValue! }
    
    // https://en.wikipedia.org/wiki/TIFF
    var tif_ii: [UInt8] = "II".map { $0.asciiValue! } + [0x2a, 0x00]
    var tif_mm: [UInt8] = "MM".map { $0.asciiValue! } + [0x00, 0x2a]
    
    // https://en.wikipedia.org/wiki/WebP
    var webp: [UInt8] = "RIFF".map { $0.asciiValue! }
    
    // https://en.wikipedia.org/wiki/ICO_(file_format)
    var win_ico: [UInt8] = [0x00, 0x00, 0x01, 0x00]
    var win_cur: [UInt8] = [0x00, 0x00, 0x02, 0x00]

    
    // MARK: - Core Data
    /**
     The UploadsProvider that collects upload data, saves it to Core Data,
     and serves it to the uploader.
     */
    lazy var uploadsProvider: UploadsProvider = {
        let provider : UploadsProvider = UploadsProvider()
        return provider
    }()

    
    // MARK: - Background Tasks Manager
    /** The manager prepares an image for upload and then launches the transfer.
    - isPreparing tells that an image/video is being prepared for upload.
    - isUploading tells that an image/video is being transferred to the server.
    - isFinishing tells that the image/video parameters are being set.
    */
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
        print("    > ", isPreparing, "|", isUploading, "|", isFinishing)

        // Get uploads to complete in queue
        guard let allUploads = uploadsProvider.requestsToComplete() else {
            return
        }
        
        // Update app badge and Upload button in root/default album
        DispatchQueue.main.async {
            // Update app badge
            UIApplication.shared.applicationIconBadgeNumber = allUploads.count
            // Update button of root album (or default album)
            let uploadInfo: [String : Any] = ["nberOfUploadsToComplete" : allUploads.count]
            NotificationCenter.default.post(name: NSNotification.Name(kPiwigoNotificationLeftUploads), object: nil, userInfo: uploadInfo)
        }
        
        // Pause upload maneger if app not in the foreground
        if appState == .background || appState == .inactive {
            print("    > NOT IN FOREGROUND !!!")
            return
        }

        // Determine the Power State
        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            // Low Power Mode is enabled. Stop transferring images.
            return
        }

        // Check network access and status
        if !AFNetworkReachabilityManager.shared().isReachable ||
            (AFNetworkReachabilityManager.shared().isReachableViaWWAN && Model.sharedInstance().wifiOnlyUploading) {
            return
        }

        // Any interrupted transfer?
        if !isFinishing, let upload = allUploads.first(where: { $0.state == .finishing }) {
            // Transfer encountered an error
            let uploadProperties = upload.getUploadProperties(with: .finishingError, error: UploadError.networkUnavailable.errorDescription)
            print("    >  Interrupted finish")
            uploadsProvider.updateRecord(with: uploadProperties, completionHandler: { [unowned self] _ in
                self.findNextImageToUpload()
                return
            })
        }
        if !isUploading, let upload = allUploads.first(where: { $0.state == .uploading }) {
            // Transfer encountered an error
            let uploadProperties = upload.getUploadProperties(with: .uploadingError, error: UploadError.networkUnavailable.errorDescription)
            print("    >  Interrupted upload")
            uploadsProvider.updateRecord(with: uploadProperties, completionHandler: { [unowned self] _ in
                self.findNextImageToUpload()
                return
            })
        }
        if !isPreparing, let upload = allUploads.first(where: { $0.state == .preparing }) {
            // Transfer encountered an error
            let uploadProperties = upload.getUploadProperties(with: .preparingError, error:  UploadError.networkUnavailable.errorDescription)
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
            self.finish(nextUpload: upload)
            return
        }

        // Not transferring and file ready for transfer?
        let nberUploadedWithError = allUploads.filter({ $0.state == .uploadingError } ).count
        if !isUploading, nberFinishedWithError < 2, nberUploadedWithError < 2,
            let upload = allUploads.first(where: { $0.state == .prepared }) {
            // Upload ready, so start the transfer
            isUploading = true
            self.transfer(nextUpload: upload)
            return
        }
        
        // Not preparing and upload request waiting?
        let nberPreparedWithError = allUploads.filter({ $0.state == .preparingError } ).count
        if !isPreparing, nberFinishedWithError < 2, nberUploadedWithError < 2, nberPreparedWithError < 2,
            let nextUpload = allUploads.first(where: { $0.state == .waiting }) {
            // Prepare the next upload
            isPreparing = true
            self.prepare(nextUpload: nextUpload)
            return
        }
        
        // No more image to transfer
        // Get completed uploads in queue
        guard let completedUploads = uploadsProvider.requestsCompleted() else {
            return
        }

        // Moderate uploaded images if Community plugin installed
        if Model.sharedInstance().usesCommunityPluginV29 {
            self.moderate(uploadedImages: completedUploads)
            return
        }

        // Delete images from Photo Library if user wanted it
        self.delete(uploadedImages: completedUploads.filter({$0.deleteImageAfterUpload == true}))
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
        var uploadProperties: UploadProperties
        if nextUpload.isFault {
            // The upload request is not fired yet.
            // Happens after a crash during an upload for example
            nextUpload.willAccessValue(forKey: nil)
            uploadProperties = nextUpload.getUploadProperties(with: .waiting, error: "")
            nextUpload.didAccessValue(forKey: nil)
        } else {
            uploadProperties = nextUpload.getUploadProperties(with: nextUpload.state, error: nextUpload.requestError)
        }
        
        // Retrieve image asset
        guard let originalAsset = PHAsset.fetchAssets(withLocalIdentifiers: [nextUpload.localIdentifier], options: nil).firstObject else {
            // Asset not available… deleted?
            uploadProperties.requestState = .preparingFail
            uploadProperties.requestError = UploadError.missingAsset.errorDescription
            self.uploadsProvider.updateRecord(with: uploadProperties, completionHandler: { [unowned self] _ in
                // Consider next image
                self.isPreparing = false
                self.findNextImageToUpload()
            })
            return
        }

        // Retrieve creation date
        uploadProperties.creationDate = originalAsset.creationDate ?? Date.init()
        
        // Determine non-empty unique file name and extension from asset
        var fileName = PhotosFetch.sharedInstance().getFileNameFomImageAsset(originalAsset)
        if nextUpload.prefixFileNameBeforeUpload, let prefix = nextUpload.defaultPrefix {
            if !fileName.hasPrefix(prefix) { fileName = prefix + fileName }
        }
        uploadProperties.fileName = fileName
        let fileExt = (URL(fileURLWithPath: fileName).pathExtension).lowercased()
        
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
                uploadsProvider.updateRecord(with: uploadProperties, completionHandler: { [unowned self] _ in
                    // Launch preparation job
                    self.prepareImage(for: uploadProperties, from: originalAsset)
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
                    uploadsProvider.updateRecord(with: uploadProperties, completionHandler: { [unowned self] _ in
                        // Launch preparation job
                        self.prepareImage(for: uploadProperties, from: originalAsset)
                    })
                    return
                }
            }
            // Image file format cannot be accepted by the Piwigo server
            uploadProperties.requestState = .formatError
            uploadsProvider.updateRecord(with: uploadProperties, completionHandler: { [unowned self] _ in
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
                uploadsProvider.updateRecord(with: uploadProperties, completionHandler: { [unowned self] _ in
                    // Launch preparation job
                    self.prepareVideo(for: uploadProperties, from: originalAsset)
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
                    uploadsProvider.updateRecord(with: uploadProperties, completionHandler: { [unowned self] _ in
                        // Launch preparation job
                        self.convertVideo(of: originalAsset, for: uploadProperties)
                    })
                    return
                }
            }
            // Video file format cannot be accepted by the Piwigo server
            uploadProperties.requestState = .formatError
            uploadsProvider.updateRecord(with: uploadProperties, completionHandler: { [unowned self] _ in
                // Investigate next upload request
                self.isPreparing = false
                self.findNextImageToUpload()
            })
//                showError(withTitle: NSLocalizedString("videoUploadError_title", comment: "Video Upload Error"), andMessage: NSLocalizedString("videoUploadError_format", comment: "Sorry, video files with extension .\(fileExt.uppercased()) are not accepted by the Piwigo server."), forRetrying: false, withImage: uploadToPrepare)

        case .audio:
            // Update state of upload: Not managed by Piwigo iOS yet…
            uploadProperties.requestState = .formatError
            uploadsProvider.updateRecord(with: uploadProperties, completionHandler: { [unowned self] _ in
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
            uploadsProvider.updateRecord(with: uploadProperties, completionHandler: { [unowned self] _ in
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

        // Update state of upload request
        let uploadProperties = nextUpload.getUploadProperties(with: .uploading, error: "")
        uploadsProvider.updateRecord(with: uploadProperties, completionHandler: { [unowned self] _ in
            // Launch transfer if possible
//            self.transferInBackgroundImage(of: uploadProperties)
            self.transferImage(of: uploadProperties)
//            self.essai2()
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

        // Update state of upload resquest
        let uploadProperties = nextUpload.getUploadProperties(with: .finishing, error: "")
        uploadsProvider.updateRecord(with: uploadProperties, completionHandler: { [unowned self] _ in
            // Finish the job by setting image parameters…
            self.setImageParameters(with: uploadProperties)
        })
    }


    // MARK: - Uploaded Images Management
    
    private func moderate(uploadedImages : [Upload]) -> Void {
        // Get list of categories
        let categories = IndexSet(uploadedImages.map({Int($0.category)}))
        
        // Quit if App not in the foreground
        DispatchQueue.main.async {
            let appState = UIApplication.shared.applicationState
            if appState == .background || appState == .inactive {
                print("    > will moderate later: NOT IN FOREGROUND !!!")
                return
            }
        }
        
        // Moderate images by category
        for category in categories {
            let imageIds = uploadedImages.filter({ $0.category == category}).map( { String(format: "%ld,", $0.imageId) } ).reduce("", +)
            // Moderate uploaded images
            self.moderateImages(withIds: imageIds, inCategory: category)
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
                    // Delete upload requests in the main queue
                    self.uploadsProvider.delete(uploadRequests: uploadedImages)
                } else {
                    // User refused to delete the photos
                    var uploadsToUpdate = [UploadProperties]()
                    for upload in uploadedImages {
                        let uploadProperties = upload.getUploadPropertiesCancellingDeletion()
                        uploadsToUpdate.append(uploadProperties)
                    }
                    // Update upload requests
                    self.uploadsProvider.importUploads(from: uploadsToUpdate) { (_) in
                        // Done ;-)
                    }
                }
            })
        })
    }
    
   
    // MARK: - Failed Uploads Management
    
    @objc func resumeAll() -> Void {
        isPreparing = false
        isUploading = false
        isFinishing = false
        if let failedUploads = uploadsProvider.requestsToResume() {
            if failedUploads.count > 0 {
                // Resume failed uploads
                resume(failedUploads: failedUploads) { (_) in }
            } else {
                // Continue uploads
                findNextImageToUpload()
            }
        }
    }

    func resume(failedUploads : [Upload], completionHandler: @escaping (Error?) -> Void) -> Void {
        
        // Initialisation
        var uploadsToUpdate = [UploadProperties]()
        
        // Loop over the failed uploads
        for failedUpload in failedUploads {
            
            // Create upload properties with no error
            var uploadProperties: UploadProperties
            switch failedUpload.state {
            case .preparingError, .uploadingError:
                // -> Will try to re-prepare the image
                uploadProperties = failedUpload.getUploadProperties(with: .waiting, error: "")
            case .finishingError:
                // -> Will try again to finish the upload
                uploadProperties = failedUpload.getUploadProperties(with: .uploaded, error: "")
            default:
                // —> Will retry from scratch
                uploadProperties = failedUpload.getUploadProperties(with: .waiting, error: "")
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
//            print("all files in cache after deleting images: \(leftFiles)")
        } catch {
            print("Could not clear upload folder: \(error)")
        }
    }
}
