//
//  ShareVideoActivityItemProvider.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 19/01/2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//
//  Converted to Swift 5.2 by Eddy Lelièvre-Berna on 12/01/2021.
//

import AVFoundation
import LinkPresentation
import MobileCoreServices
import UIKit
import UniformTypeIdentifiers
import PwgKit
import PwgAPIKit
import PwgCacheKit
import PwgUploadKit

// Warning: class must restate inherited '@unchecked Sendable' conformance
class ShareVideoActivityItemProvider: UIActivityItemProvider, @unchecked Sendable {

    // MARK: - Initialisation
    weak var delegate: (any ShareImageActivityItemProviderDelegate)?

    private var imageData: Image                        // Core Data image
    private var exportSession: AVAssetExportSession?    // Export session
    private var alertTitle: String?                     // Used if task cancels or fails
    private var alertMessage: String?
    private var pwgImageURL: URL                        // URL of video in Piwigo server
    private var cachedFileURL: URL?                     // URL of cached video file
    private var imageFileURL: URL                       // URL of shared video file
    private var isCancelledByUser = false               // Flag updated when pressing Cancel
    /// Released either by the download, or by the user cancelling it: a cancelled download
    /// reports nothing, so without this the operation would wait for ever and the HUD which
    /// it asked to present would never be dismissed.
    private let downloadSemaphore = DispatchSemaphore(value: 0)
    private var contextually = false
    private let options: ShareOptions                   // Options chosen by the user before sharing


    // MARK: - Progress Faction
    private var _progressFraction: Float = 0.0
    private var progressFraction: Float {
        get {
            return _progressFraction
        }
        set(progress) {
            // Update the value
            _progressFraction = progress
            // Notify the delegate on the main thread to show how it makes progress.
            DispatchQueue.main.async {
                self.delegate?.imageActivityItemProvider(self, preprocessingProgressDidUpdate: self._progressFraction)
            }
        }
    }
    
    
    // MARK: - Placeholder Image
    init(imageData: Image, scale: CGFloat, options: ShareOptions, contextually: Bool) {
        // Store Piwigo image data for future use
        self.imageData = imageData

        // Store the options chosen by the user in the Options view
        self.options = options

        // Remember if this video is shared from a contextual menu
        self.contextually = contextually

        // We use the thumbnail image stored in cache
        let size = pwgImageSize(rawValue: AlbumVars.shared.defaultThumbnailSize) ?? .thumb
        guard let cacheURL = imageData.cacheURL(ofSize: size) else {
            imageFileURL = Bundle.main.url(forResource: "piwigo", withExtension: "png")!
            pwgImageURL = imageFileURL
            super.init(placeholderItem: UIImage(named: "AppIconShare")!)
            return
        }
        
        // Retrieve URL of image in cache
        imageFileURL = cacheURL
        pwgImageURL = imageFileURL

        // Retrieve image in cache
        if let cachedImage = UIImage(contentsOfFile: imageFileURL.path) {
            let resizedImage = cachedImage.resize(to: CGFloat(70.0), opaque: true, scale: scale)
            super.init(placeholderItem: resizedImage)
        } else {
            super.init(placeholderItem: UIImage(named: "AppIconShare")!)
        }

        // The item method downloads the video and waits for the export session to finish.
        /// AVFoundation runs the export at the default quality of service, so waiting for it
        /// from a user-initiated operation is a priority inversion which the Thread Performance
        /// Checker reports. Asking for the same quality of service avoids it.
        /// - The share sheet owns the queue running this operation and may still promote it.
        qualityOfService = .default

        // Register image share methods to perform on completion
        NotificationCenter.default.addObserver(self, selector: #selector(didFinishSharingVideo),
                                               name: Notification.Name.pwgDidShare, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(cancelDownloadVideoTask),
                                               name: Notification.Name.pwgCancelDownload, object: nil)
    }

    // MARK: - Download & Prepare Video
    ///*************************************************
    /// The item method runs on a secondary thread using an NSOperationQueue
    /// (UIActivityItemProvider subclasses NSOperation).
    /// The implementation of this method loads an image from the Piwigo server.
    ///****************************************************
    override var item: Any {
        // First check if this operation is not cancelled
        if isCancelledByUser {
            // Cancel task
            cancel()
            // Notify the delegate on the main thread that the processing is cancelled
            preprocessingDidEnd()
            return placeholderItem!
        }
        
        // Notify the delegate on the main thread that the processing is beginning.
        DispatchQueue.main.async { [self] in
            let title = String(localized: "downloadingVideo", comment: "Downloading Video")
            self.delegate?.imageActivityItemProviderPreprocessingDidBegin(self, withTitle: title)
        }

        // Get the server ID and optimum available image size
        guard let serverID = imageData.server?.uuid,
              let imageURL = imageData.downloadUrl as? URL else {
            // Cancel task
            cancel()
            // Notify the delegate on the main thread that the processing is cancelled
            alertTitle = PwgKitError.failedToPrepareDownload.localizedDescription
            alertMessage = String.localizedStringWithFormat(String(localized: "downloadVideoFail_message", comment: "Failed to download video!\n%@"), "")
            preprocessingDidEnd()
            return placeholderItem!
        }

        // Store URL of image in Piwigo server for being able to cancel the download
        pwgImageURL = imageURL

        // Download video synchronously if not in cache
        Task {
            await ImageDownloader.shared.getImage(withID: imageData.pwgID, ofSize: .fullRes, type: .album, atURL: imageURL,
                                                  fromServer: serverID, fileSize: imageData.fileSize) { [weak self = self] fractionCompleted in
                // Notify the delegate on the main thread to show how it makes progress.
                self?.updateProgressView(with: Float((0.75 * fractionCompleted)))
            }
            completion: { [unowned self = self] fileURL in
                self.cachedFileURL = fileURL
                downloadSemaphore.signal()
            }
            failure: { [unowned self = self] error in
                // Will notify the delegate on the main thread that the processing is cancelled
                self.alertTitle = String(localized: "shareFailError_title", comment: "Share Fail")
                self.alertMessage = String.localizedStringWithFormat(String(localized: "downloadVideoFail_message", comment: "Failed to download video!\n%@"), error.localizedDescription)
                downloadSemaphore.signal()
            }
        }
        _ = downloadSemaphore.wait(timeout: .distantFuture)
        
        // Did the user cancel the download? End quietly, without reporting a failure.
        if isCancelledByUser {
            cancel()
            preprocessingDidEnd()
            return placeholderItem!
        }
        
        // Cancel item task if we could not retrieve the file
        if alertTitle != nil {
            // Cancel task
            cancel()
            // Notify the delegate on the main thread that the processing has finished.
            preprocessingDidEnd()
            // Could not retrieve video file
            return placeholderItem!
        }

        // Check that we have the URL of the cached video
        guard let cachedFileURL = cachedFileURL else {
            // Will notify the delegate on the main thread that the processing is cancelled
            self.alertTitle = String(localized: "shareFailError_title", comment: "Share Fail")
            self.alertMessage = String.localizedStringWithFormat(String(localized: "downloadVideoFail_message", comment: "Failed to download video!\n%@"), "")
            // Cancel task
            cancel()
            // Notify the delegate on the main thread that the processing is cancelled.
            preprocessingDidEnd()
            return placeholderItem!
        }

        // Shared files are stored in the /tmp directory with an appropriate name and will be deleted:
        // - by the app if the user kills it
        // - by the system after a certain amount of time
        imageFileURL = ShareUtilities.getFileUrl(ofImage: imageData, withURL: imageURL)

        // Copy original file to /tmp directly with appropriate file name
        // and set creation date as the photo creation date
        let fileDate = imageData.dateCreated == DateUtilities.unknownDateInterval ? imageData.datePosted : imageData.dateCreated
        let creationDate = NSDate(timeIntervalSinceReferenceDate: fileDate)
        let attrs = [FileAttributeKey.creationDate     : creationDate,
                     FileAttributeKey.modificationDate : creationDate]
        do {
            try? FileManager.default.removeItem(at: imageFileURL)
            try  FileManager.default.copyItem(at: cachedFileURL, to: imageFileURL)
            try? FileManager.default.setAttributes(attrs, ofItemAtPath: imageFileURL.path)
        }
        catch {
            // Cancel task
            cancel()
            // Notify the delegate on the main thread that the processing is cancelled.
            alertTitle = String(localized: "shareFailError_title", comment: "Share Fail")
            alertMessage = String.localizedStringWithFormat("%@ (%@)", PwgKitError.cannotStripPrivateMetadata.localizedDescription, error.localizedDescription)
            preprocessingDidEnd()
            return placeholderItem!
        }

        // Must the video be exported?
        /// - Unlike photos, videos have no derivative the app could download in the wanted
        ///   size: they are downscaled by the export session. The export also produces an
        ///   MP4 file whose metadata is filtered for sharing. It is therefore required as
        ///   soon as the user asks for a smaller size, for the most compatible format,
        ///   or refuses to share some of the private metadata.
        /// - AVAssetExportSession filters the metadata as a whole: unlike photos, videos
        ///   cannot keep their author while dropping their location.
        let toStrip = options.metadataToStrip
        let needsConversion = (options.format == .mostCompatible)
                           && imageFileURL.pathExtension.lowercased() != "mp4"
        let maxResolution = options.maxSize(for: activityType, isVideo: true)
        /// Videos of unknown resolution are exported so that they are never shared
        /// larger than requested — the export never scales them up anyway.
        let videoMaxSide = imageData.fullRes.map({ max($0.width, $0.height) }) ?? Int.max
        let needsDownscaling = videoMaxSide > maxResolution
        if toStrip.isEmpty, needsConversion == false, needsDownscaling == false {
            // Notify the delegate on the main thread to show how it makes progress.
            progressFraction = 1.0
            // Notify the delegate on the main thread that the processing has finished.
            preprocessingDidEnd()
            // Nothing to remove, to convert nor to downscale, share the file immediately
            return imageFileURL
        }

        // Does the file contain private metadata?
        let asset = AVAsset(url: imageFileURL)

        // For debugging
//        let commonMetadata = asset.commonMetadata
//        debugPrint("===>> Common Metadata: \(commonMetadata)")
//        let allMetadata = asset.metadata
//        debugPrint("===>> All Metadata: \(allMetadata)")

        if needsConversion == false, needsDownscaling == false,
           !asset.metadata.containsPrivateMetadata() {
            // Notify the delegate on the main thread to show how it makes progress.
            progressFraction = 1.0
            // Notify the delegate on the main thread that the processing has finished.
            preprocessingDidEnd()
            // No need to strip metadata, share the file immediately
            return imageFileURL
        }
        
        // We cannot remove the private metadata if the video cannot be exported
        if !asset.isExportable {
            // Cancel task
            cancel()
            // Notify the delegate on the main thread that the processing is cancelled
            alertTitle = String(localized: "shareFailError_title", comment: "Share Fail")
            alertMessage = PwgKitError.cannotStripPrivateMetadata.localizedDescription
            preprocessingDidEnd()
            return placeholderItem!
        }

        // Create new file from original one because one cannot modify metadata of existing file
        // Shared files are saved in the /tmp directory and will be deleted:
        // - by the app if the user kills it
        // - by the system after a certain amount of time
        let newSourceFileName = imageFileURL.lastPathComponent.dropLast(imageFileURL.pathExtension.count+1)
                                            .appending("-original." + imageFileURL.pathExtension)
        let tempDirectoryUrl = URL(fileURLWithPath: NSTemporaryDirectory())
        let newSourceURL = tempDirectoryUrl.appendingPathComponent(newSourceFileName)

        // Deletes temporary image file if it exists
        try? FileManager.default.removeItem(at: newSourceURL)

        // Rename temporary original image file
        do {
            try FileManager.default.moveItem(at: imageFileURL, to: newSourceURL)
        }
        catch let error {
            // Cancel task
            cancel()
            // Notify the delegate on the main thread that the processing is cancelled.
            alertTitle = String(localized: "shareFailError_title", comment: "Share Fail")
            alertMessage = String.localizedStringWithFormat("%@ (%@)", PwgKitError.cannotStripPrivateMetadata.localizedDescription, error.localizedDescription)
            preprocessingDidEnd()
            return placeholderItem!
        }

        // Determine available export options compatible with the video asset
        /// - The 'presets' array never contains AVAssetExportPresetPassthrough.
        let originalAsset = AVAsset(url: newSourceURL)
        let presets = AVAssetExportSession.exportPresets(compatibleWith: originalAsset)
        
        // The exported file is an MP4 one: adopt the matching file name.
        /// The original file has just been moved aside, but a file of that name may be
        /// left over from a previous share — the export session refuses to overwrite it.
        imageFileURL = imageFileURL.deletingPathExtension().appendingPathExtension("mp4")
        try? FileManager.default.removeItem(at: imageFileURL)

        // We select a resolution lower than the one required by the activity type
        /// - The export will not scale the video up from a smaller size.
        /// - Compression for video uses H.264; compression for audio uses AAC.
        var exportPreset = AVAssetExportPresetHighestQuality
        if (maxResolution <= 640) && presets.contains(AVAssetExportPreset640x480) {
            // Encode in 640x480 pixels
            exportPreset = AVAssetExportPreset640x480
        } else if (maxResolution <= 960) && presets.contains(AVAssetExportPreset960x540) {
            // Encode in 960x540 pixels
            exportPreset = AVAssetExportPreset960x540
        } else if (maxResolution <= 1280) && presets.contains(AVAssetExportPreset1280x720) {
            // Encode in 1280x720 pixels
            exportPreset = AVAssetExportPreset1280x720
        } else if (maxResolution <= 1920) && presets.contains(AVAssetExportPreset1920x1080) {
            // Encode in 1920x1080 pixels
            exportPreset = AVAssetExportPreset1920x1080
        } else if (maxResolution <= 3840) && presets.contains(AVAssetExportPreset3840x2160) {
            // Encode in 3840x2160 pixels
            exportPreset = AVAssetExportPreset3840x2160
        }

        // We export the video in MP4
        exportSynchronously(originalAsset: originalAsset, with: exportPreset)

        // Cancel item task if we could not retrieve the file
        if alertTitle != nil {
            // Cancel task
            cancel()
            // Notify the delegate on the main thread that the processing has finished.
            preprocessingDidEnd()
            // Could not retrieve video file
            return placeholderItem!
        }

        // Notify the delegate on the main thread that the processing has finished.
        preprocessingDidEnd()

        // Shared files w/ or w/o private metadata are saved in the /tmp directory and will be deleted:
        // - by the app if the user kills it
        // - by the system after a certain amount of time
        try? FileManager.default.setAttributes(attrs, ofItemAtPath: imageFileURL.path)
        return imageFileURL
    }
    
    private func updateProgressView(with fractionCompleted: Float) {
        DispatchQueue.main.async { [self] in
            // Show download progress
            self.progressFraction = fractionCompleted
        }
    }
    
    /// How often the export progress is polled, in seconds.
    private let progressPollingInterval = 0.2

    private func exportSynchronously(originalAsset: AVAsset, with exportPreset: String) {
        let sema = DispatchSemaphore(value: 0)
        // Create export session
        guard let session = AVAssetExportSession(asset: originalAsset,
                                                 presetName: exportPreset) else {
            // Notify the delegate on the main thread that the processing is cancelled.
            alertTitle = String(localized: "shareFailError_title", comment: "Share Fail")
            alertMessage = PwgKitError.cannotStripPrivateMetadata.localizedDescription
            sema.signal()
            return
        }
        
        exportSession = session
        session.outputFileType = .mp4
        session.shouldOptimizeForNetworkUse = true
        session.outputURL = imageFileURL
        session.metadataItemFilter = .forSharing()
        // Report how the export makes progress, from 75% to 100%
        /// The item method blocks the thread it runs on until the export is over, so a timer
        /// cannot be scheduled on its run loop: a dispatch source drives the polling instead.
        let progressPoller = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .default))
        progressPoller.schedule(deadline: .now() + progressPollingInterval,
                                repeating: progressPollingInterval)
        progressPoller.setEventHandler { [weak self] in
            self?.progressFraction = 0.75 + 0.25 * session.progress
        }
        progressPoller.resume()

        session.exportAsynchronously { [self] in
            // Whatever the outcome, the item method must stop waiting for this export
            progressPoller.cancel()
            defer { sema.signal() }

            // Handle export results
            /// The handler is called once the export is over, i.e. the status is never
            /// .exporting nor .waiting here.
            switch session.status {
            case .completed:
                self.progressFraction = 1.0

            case .failed, .cancelled:
                // Notify the delegate on the main thread that the processing is cancelled.
                self.alertTitle = String(localized: "shareFailError_title", comment: "Share Fail")
                self.alertMessage = PwgKitError.cannotStripPrivateMetadata.localizedDescription

            default:
                // Deletes temporary video files
                do {
                    try FileManager.default.removeItem(at: session.outputURL!)
                } catch {
                }

                // Notify the delegate on the main thread that the processing is cancelled.
                self.alertTitle = String(localized: "shareFailError_title", comment: "Share Fail")
                self.alertMessage = PwgKitError.cannotStripPrivateMetadata.localizedDescription
            }
        }
        _ = sema.wait(timeout: .distantFuture)
    }
    
    private func preprocessingDidEnd() {
        // Notify the delegate on the main thread that the processing is cancelled.
        DispatchQueue.main.async(execute: {
            self.delegate?.imageActivityItemProviderPreprocessingDidEnd(self, withImageID: self.imageData.pwgID, contextually: self.contextually)
        })
    }
    
    @objc func cancelDownloadVideoTask() {
        // Will cancel share when operation starts
        isCancelledByUser = true
        // Release the operation if it is waiting for the video being downloaded: a cancelled
        // download calls neither its completion nor its failure handler.
        downloadSemaphore.signal()
        // Cancel video file download
        Task { await ImageDownloader.shared.cancelDownload(atURL: pwgImageURL) }
        // Cancel video export
        exportSession?.cancelExport()
    }

    @objc func didFinishSharingVideo() {
        // Unregister all observers
        NotificationCenter.default.removeObserver(self)

        // Inform user in case of error after dismissing activity view controller
        if let alertTitle = alertTitle {
            delegate?.showError(withTitle: alertTitle, andMessage: alertMessage)
        }

        // Release momory
        alertTitle = nil
        alertMessage = nil
    }

    // MARK: - UIActivityItemSource Methods
    override func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        // Use the filename of the image as subject
        return self.imageData.fileName
    }
    
    override func activityViewController(_ activityViewController: UIActivityViewController, dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?) -> String {
        return UTType.movie.identifier
    }
    
    override func activityViewControllerLinkMetadata(_: UIActivityViewController) -> LPLinkMetadata? {
        // Initialisation
        let linkMetaData = LPLinkMetadata()

        // We use the thumbnail in cache
        let size = pwgImageSize(rawValue: AlbumVars.shared.defaultThumbnailSize) ?? .thumb
        if let cachedImage = imageData.cachedThumbnail(ofSize: size) {
            linkMetaData.imageProvider = NSItemProvider(object: cachedImage)
        } else {
            linkMetaData.imageProvider = NSItemProvider(object: UIImage(named: "AppIconShare")!)
        }
        
        // Title
        linkMetaData.title = imageData.fileName
                
        return linkMetaData
    }
}
