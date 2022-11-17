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

    private var imageData: PiwigoImageData              // Piwigo image data
    private var task: URLSessionDownloadTask?           // Download task
    private var exportSession: AVAssetExportSession?    // Export session
    private var alertTitle: String?                     // Used if task cancels or fails
    private var alertMessage: String?
    private var imageFileURL: URL                       // Shared image file URL
    private var isCancelledByUser = false               // Flag updated when pressing Cancel


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
    init(placeholderImage imageData: PiwigoImageData) {
        // Store Piwigo image data for future use
        self.imageData = imageData

        // We use the thumbnail cached in memory
        let alreadyLoadedSize = kPiwigoImageSize(AlbumVars.shared.defaultThumbnailSize)
        guard let thumbnailURL = URL(string: imageData.getURLFromImageSizeType(alreadyLoadedSize)) else {
            imageFileURL = Bundle.main.url(forResource: "piwigo", withExtension: "png")!
            super.init(placeholderItem: UIImage(named: "AppIconShare")!)
            return
        }
        
        // Retrieve thumbnail image
        let thumb = UIImageView()
        thumb.setImageWith(thumbnailURL, placeholderImage: UIImage(named: "AppIconShare"))
        if let thumbnailImage = thumb.image {
            imageFileURL = thumbnailURL
            let resizedImage = thumbnailImage.resize(to: CGFloat(70.0), opaque: true)
            super.init(placeholderItem: resizedImage)
        } else {
            imageFileURL = Bundle.main.url(forResource: "piwigo", withExtension: "png")!
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

        // Determine the URL request
        /// - The movie URL is necessarily the one of the full resolution Piwigo image
        guard let urlRequest: URLRequest = ShareUtilities.getUrlRequest(forImage: imageData, withMaxSize: Int.max) else {
            // Cancel task
            cancel()
            // Notify the delegate on the main thread that the processing is cancelled
            alertTitle = NSLocalizedString("downloadImageFail_title", comment: "Download Fail")
            alertMessage = String.localizedStringWithFormat(NSLocalizedString("downloadVideoFail_message", comment: "Failed to download video!\n%@"), "")
            preprocessingDidEnd()
            return placeholderItem!
        }

        // Do we have the movie in cache?
        if let cache = NetworkVarsObjc.imageCache,
           let cachedImageData = cache.cachedResponse(for: urlRequest)?.data, cachedImageData.isEmpty == false {
            // Create file URL where the shared file is expected to be found
            imageFileURL = ShareUtilities.getFileUrl(ofImage: imageData, withURLrequest: urlRequest)
            
            // Deletes temporary image file if it exists
            do {
                try FileManager.default.removeItem(at: imageFileURL)
            } catch {
            }

            // Store cached image data into /tmp directory
            do {
                try cachedImageData.write(to: imageFileURL)
                // Notify the delegate on the main thread to show how it makes progress.
                progressFraction = 0.5
            }
            catch let error as NSError {
                // Cancel task
                cancel()
                // Notify the delegate on the main thread that the processing is cancelled
                alertTitle = NSLocalizedString("downloadImageFail_title", comment: "Download Fail")
                alertMessage = String.localizedStringWithFormat(NSLocalizedString("downloadVideoFail_message", comment: "Failed to download video!\n%@"), error.localizedDescription)
            }
        }
        else {
            // Download synchronously the image file and store it in cache
            downloadSynchronouslyVideo(with: urlRequest)
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
        do {
            try FileManager.default.removeItem(at: newSourceURL)
        } catch {
        }

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

    private func downloadSynchronouslyVideo(with urlRequest: URLRequest) {
        let sema = DispatchSemaphore(value: 0)
        task = ShareUtilities.downloadImage(with: imageData, at: urlRequest,
            onProgress: { (progress) in
                // Notify the delegate on the main thread to show how it makes progress.
                if let progress = progress {
                    self.progressFraction = Float(0.75 * progress.fractionCompleted)
                }
            }, completionHandler: { (response, fileURL, error) in
                // Any error ?
                if let error = error {
                    // Failed
                    self.alertTitle = NSLocalizedString("shareFailError_title", comment: "Share Fail")
                    self.alertMessage = String.localizedStringWithFormat(NSLocalizedString("downloadVideoFail_message", comment: "Failed to download video!\n%@"), error.localizedDescription)
                    sema.signal()
                } else {
                    // Get response
                    if let fileURL = fileURL, let response = response {
                        do {
                            // Get file content (file URL defined by ShareUtilities.getFileUrl(ofImage:withUrlRequest)
                            let data = try Data(contentsOf: fileURL)

                            // Check content
                            if data.isEmpty {
                                self.alertTitle = NSLocalizedString("shareFailError_title", comment: "Share Fail")
                                self.alertMessage = String.localizedStringWithFormat(NSLocalizedString("downloadVideoFail_message", comment: "Failed to download video!\n%@"), "")
                                sema.signal()
                            }
                            else {
                                // Store image in cache
                                let cachedResponse = CachedURLResponse(response: response, data: data)
                                if let cache = NetworkVarsObjc.imageCache {
                                    cache.storeCachedResponse(cachedResponse, for: urlRequest)
                                }

                                // Set image file URL
                                self.imageFileURL = fileURL
                                sema.signal()
                            }
                        }
                        catch let error as NSError {
                            self.alertTitle = NSLocalizedString("shareFailError_title", comment: "Share Fail")
                            self.alertMessage = String.localizedStringWithFormat(NSLocalizedString("downloadVideoFail_message", comment: "Failed to download video!\n%@"), error.localizedDescription)
                            sema.signal()
                        }
                    }
                }
            })
        let _ = sema.wait(timeout: .distantFuture)
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
            self.delegate?.imageActivityItemProviderPreprocessingDidEnd(self, withImageId: Int64(self.imageData.imageId))
        })
    }
    
    @objc func cancelDownloadVideoTask() {
        // Will cancel share when operation starts
        isCancelledByUser = true
        // Cancel video file download
        task?.cancel()
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
        let linkMetaData = LPLinkMetadata()
        
        // We use the thumbnail in cache
        let alreadyLoadedSize = kPiwigoImageSize(AlbumVars.shared.defaultThumbnailSize)
        if let thumbnailURL = URL(string: imageData.getURLFromImageSizeType(alreadyLoadedSize)) {
            // Retrieve thumbnail image
            let thumb = UIImageView()
            thumb.setImageWith(thumbnailURL, placeholderImage: UIImage(named: "AppIconShare"))
            if let thumbnailImage = thumb.image {
                linkMetaData.imageProvider = NSItemProvider(object: thumbnailImage)
            } else {
                linkMetaData.imageProvider = NSItemProvider(object: UIImage(named: "AppIconShare")!)
            }
        }
        
        // Title
        linkMetaData.title = imageData.fileName
                
        return linkMetaData
    }
}
