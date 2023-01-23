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
import piwigoKit

class ShareVideoActivityItemProvider: UIActivityItemProvider {

    // MARK: - Initialisation
    weak var delegate: ShareImageActivityItemProviderDelegate?

    private var imageData: Image                        // Core Data image
    private var exportSession: AVAssetExportSession?    // Export session
    private var alertTitle: String?                     // Used if task cancels or fails
    private var alertMessage: String?
    private var imageFileURL: URL                       // Shared image file URL
    private var isCancelledByUser = false               // Flag updated when pressing Cancel
    private var download: ImageDownload?


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
            DispatchQueue.main.async(execute: {
                self.delegate?.imageActivityItemProvider(self, preprocessingProgressDidUpdate: self._progressFraction)
            })
        }
    }
    
    
    // MARK: - Placeholder Image
    init(placeholderImage: Image) {
        // Store Piwigo image data for future use
        self.imageData = placeholderImage

        // We use the thumbnail image stored in cache
        let size = pwgImageSize(rawValue: AlbumVars.shared.defaultThumbnailSize) ?? .thumb
        guard let serverID = imageData.server?.uuid else {
            imageFileURL = Bundle.main.url(forResource: "piwigo", withExtension: "png")!
            super.init(placeholderItem: UIImage(named: "AppIconShare")!)
            return
        }
        
        // Retrieve URL of image in cache
        let cacheDir = DataController.cacheDirectory.appendingPathComponent(serverID)
        imageFileURL = cacheDir.appendingPathComponent(size.path)
            .appendingPathComponent(String(imageData.pwgID))
        
        // Retrieve image in cache
        if let cachedImage = UIImage(contentsOfFile: imageFileURL.path) {
            let resizedImage = cachedImage.resize(to: CGFloat(70.0), opaque: true)
            super.init(placeholderItem: resizedImage)
        } else {
            super.init(placeholderItem: UIImage(named: "AppIconShare")!)
        }

        // Register image share methods to perform on completion
        NotificationCenter.default.addObserver(self, selector: #selector(didFinishSharingVideo),
                                               name: .pwgDidShare, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(cancelDownloadVideoTask),
                                               name: .pwgCancelDownload, object: nil)
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
        DispatchQueue.main.async(execute: {
            self.delegate?.imageActivityItemProviderPreprocessingDidBegin(self, withTitle: NSLocalizedString("downloadingVideo", comment: "Downloading Video"))
        })

        // Get the server ID and optimum available image size
        guard let serverID = imageData.server?.uuid,
              let (imageSize, imageURL) = ShareUtilities.getOptimumSizeAndURL(imageData, ofMaxSize: Int.max) else {
            // Cancel task
            cancel()
            // Notify the delegate on the main thread that the processing is cancelled
            alertTitle = NSLocalizedString("downloadImageFail_title", comment: "Download Fail")
            alertMessage = String.localizedStringWithFormat(NSLocalizedString("downloadVideoFail_message", comment: "Failed to download video!\n%@"), "")
            preprocessingDidEnd()
            return placeholderItem!
        }

        // Download video synchronously if not in cache
        let sema = DispatchSemaphore(value: 0)
        download = ImageDownload(imageID: imageData.pwgID, ofSize: imageSize, atURL: imageURL as URL,
                                 fromServer: serverID, placeHolder: placeholderItem as! UIImage) { fractionCompleted in
            // Notify the delegate on the main thread to show how it makes progress.
            self.progressFraction = Float((0.75 * fractionCompleted))
        } completion: { _ in
            sema.signal()
        } failure: { error in
            // Will notify the delegate on the main thread that the processing is cancelled
            self.alertTitle = NSLocalizedString("shareFailError_title", comment: "Share Fail")
            self.alertMessage = String.localizedStringWithFormat(NSLocalizedString("downloadVideoFail_message", comment: "Failed to download video!\n%@"), error.localizedDescription)
            sema.signal()
        }
        download?.getImage()
        let _ = sema.wait(timeout: .distantFuture)
        
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
        guard let cachedFileURL = download?.fileURL else {
            // Will notify the delegate on the main thread that the processing is cancelled
            self.alertTitle = NSLocalizedString("shareFailError_title", comment: "Share Fail")
            self.alertMessage = NSLocalizedString("downloadVideoFail_message", comment: "Failed to download video!")
            // Cancel task
            cancel()
            // Notify the delegate on the main thread that the processing is cancelled.
            preprocessingDidEnd()
            return placeholderItem!
        }

        // Shared files are stored in the /tmp directory and will be deleted:
        // - by the app if the user kills it
        // - by the system after a certain amount of time
        imageFileURL = ShareUtilities.getFileUrl(ofImage: imageData, withURL: imageURL as URL)

        // Deletes temporary image file if it exists
        try? FileManager.default.removeItem(at: imageFileURL)

        // Copy original file to /tmp directly with appropriate file name
        do {
            try FileManager.default.copyItem(at: cachedFileURL, to: imageFileURL)
        }
        catch {
            // Cancel task
            cancel()
            // Notify the delegate on the main thread that the processing is cancelled.
            alertTitle = NSLocalizedString("shareFailError_title", comment: "Share Fail")
            alertMessage = String.localizedStringWithFormat("%@ (%@)", NSLocalizedString("shareMetadataError_message", comment: "Cannot strip private metadata"), error.localizedDescription)
            preprocessingDidEnd()
            return placeholderItem!
        }

        // Should we strip GPS metadata (yes by default)?
        if !(activityType?.shouldStripMetadata() ?? true) {
            // Notify the delegate on the main thread to show how it makes progress.
            progressFraction = 1.0
            // Notify the delegate on the main thread that the processing has finished.
            preprocessingDidEnd()
            // No need to strip metadata, share the file immediately
            return imageFileURL
        }

        // Does the file contain private metadata?
        let asset = AVAsset(url: imageFileURL)

        // For debugging
//        let commonMetadata = asset.commonMetadata
//        print("===>> Common Metadata: \(commonMetadata)")
//        let allMetadata = asset.metadata
//        print("===>> All Metadata: \(allMetadata)")

        if !asset.metadata.containsPrivateMetadata() {
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
            alertTitle = NSLocalizedString("shareFailError_title", comment: "Share Fail")
            alertMessage = NSLocalizedString("shareMetadataError_message", comment: "Cannot strip private metadata")
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
        catch let error as NSError {
            // Cancel task
            cancel()
            // Notify the delegate on the main thread that the processing is cancelled.
            alertTitle = NSLocalizedString("shareFailError_title", comment: "Share Fail")
            alertMessage = String.localizedStringWithFormat("%@ (%@)", NSLocalizedString("shareMetadataError_message", comment: "Cannot strip private metadata"), error.localizedDescription)
            preprocessingDidEnd()
            return placeholderItem!
        }

        // Determine available export options compatible with the video asset
        /// - The 'presets' array never contains AVAssetExportPresetPassthrough.
        let originalAsset = AVAsset(url: newSourceURL)
        let presets = AVAssetExportSession.exportPresets(compatibleWith: originalAsset)
        
        // Get the maximum accepted resolution (infinity for largest)
        let maxResolution = activityType?.imageMaxSize() ?? Int.max

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
        return imageFileURL
    }
    
    private func exportSynchronously(originalAsset: AVAsset, with exportPreset: String) {
        let sema = DispatchSemaphore(value: 0)
        // Create export session
        guard let session = AVAssetExportSession(asset: originalAsset,
                                                 presetName: exportPreset) else {
            // Notify the delegate on the main thread that the processing is cancelled.
            alertTitle = NSLocalizedString("shareFailError_title", comment: "Share Fail")
            alertMessage = NSLocalizedString("shareMetadataError_message", comment: "Cannot strip private metadata")
            sema.signal()
            return
        }
        
        exportSession = session
        session.outputFileType = .mp4
        session.shouldOptimizeForNetworkUse = true
        session.outputURL = imageFileURL
        session.metadataItemFilter = .forSharing()
        session.exportAsynchronously {
            // Handle export results
            switch session.status {
            case .exporting, .waiting:
                self.progressFraction = 0.75 + 0.25 * session.progress
            
            case .failed, .cancelled:
                // Notify the delegate on the main thread that the processing is cancelled.
                self.alertTitle = NSLocalizedString("shareFailError_title", comment: "Share Fail")
                self.alertMessage = NSLocalizedString("shareMetadataError_message", comment: "Cannot strip private metadata")
                sema.signal()
            
            case .completed:
                self.progressFraction = 1.0
                sema.signal()
            
            default:
                // Deletes temporary video files
                do {
                    try FileManager.default.removeItem(at: session.outputURL!)
                } catch {
                }
                
                // Notify the delegate on the main thread that the processing is cancelled.
                self.alertTitle = NSLocalizedString("shareFailError_title", comment: "Share Fail")
                self.alertMessage = NSLocalizedString("shareMetadataError_message", comment: "Cannot strip private metadata")
                sema.signal()
            }
        }
        let _ = sema.wait(timeout: .distantFuture)
    }
    
    private func preprocessingDidEnd() {
        // Notify the delegate on the main thread that the processing is cancelled.
        DispatchQueue.main.async(execute: {
            self.delegate?.imageActivityItemProviderPreprocessingDidEnd(self, withImageId: self.imageData.pwgID)
        })
    }
    
    @objc func cancelDownloadVideoTask() {
        // Will cancel share when operation starts
        isCancelledByUser = true
        // Cancel video file download
        download?.task?.cancel()
        // Cancel video export
        exportSession?.cancelExport()
    }

    @objc func didFinishSharingVideo() {
        // Remove image share observers
        NotificationCenter.default.removeObserver(self, name: .pwgDidShare, object: nil)
        NotificationCenter.default.removeObserver(self, name: .pwgCancelDownload, object: nil)

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
        return kUTTypeMovie as String
    }
    
    @available(iOS 13.0, *)
    override func activityViewControllerLinkMetadata(_: UIActivityViewController) -> LPLinkMetadata? {
        // Initialisation
        let linkMetaData = LPLinkMetadata()

        // We use the thumbnail in cache
        if let serverID = imageData.server?.uuid {
            // Retrieve URL of image in cache
            let size = pwgImageSize(rawValue: AlbumVars.shared.defaultThumbnailSize) ?? .thumb
            let cacheDir = DataController.cacheDirectory.appendingPathComponent(serverID)
            let fileURL = cacheDir.appendingPathComponent(size.path)
                .appendingPathComponent(String(imageData.pwgID))

            // Retrieve image in cache
            if let cachedImage = UIImage(contentsOfFile: fileURL.path) {
                linkMetaData.imageProvider = NSItemProvider(object: cachedImage)
            } else {
                linkMetaData.imageProvider = NSItemProvider(object: UIImage(named: "AppIconShare")!)
            }
        } else {
            linkMetaData.imageProvider = NSItemProvider(object: UIImage(named: "AppIconShare")!)
        }
        
        // Title
        linkMetaData.title = imageData.fileName
                
        return linkMetaData
    }
}
