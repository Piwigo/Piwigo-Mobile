//
//  ShareImageActivityItemProvider.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 12/01/2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//
//  Converted to Swift 5.2 by Eddy Lelièvre-Berna on 10/01/2021.
//

import LinkPresentation
import MobileCoreServices
import Photos
import UIKit
import piwigoKit

@objc
class ShareImageActivityItemProvider: UIActivityItemProvider {
    
    // MARK: - Initialisation
    @objc weak var delegate: ShareImageActivityItemProviderDelegate?

    private var imageData: PiwigoImageData              // Piwigo image data
    private var task: URLSessionDownloadTask?           // Download task
    private var alertTitle: String?                     // Used if task cancels or fails
    private var alertMessage: String?
    private var imageFileURL: URL                       // Shared image file URL
    private var imageFileData: Data                     // Content of the shared image file
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
    @objc
    init(placeholderImage imageData: PiwigoImageData) {
        // Store Piwigo image data for future use
        self.imageData = imageData

        // We use the thumbnail cached in memory
        let alreadyLoadedSize = kPiwigoImageSize(AlbumVars.defaultThumbnailSize)
        guard let thumbnailURL = URL(string: imageData.getURLFromImageSizeType(alreadyLoadedSize)) else {
            imageFileData = Data()
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
            imageFileData = resizedImage.jpegData(compressionQuality: 1.0) ?? Data()
            super.init(placeholderItem: thumbnailImage)
        } else {
            imageFileData = Data()
            imageFileURL = Bundle.main.url(forResource: "piwigo", withExtension: "png")!
            super.init(placeholderItem: UIImage(named: "AppIconShare")!)
        }

        // Register image share methods to perform on completion
        NotificationCenter.default.addObserver(self, selector: #selector(didFinishSharingImage), name: NSNotification.Name(kPiwigoNotificationDidShare), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(cancelDownloadImageTask), name: NSNotification.Name(kPiwigoNotificationCancelDownload), object: nil)
    }

    // MARK: - Download & Prepare Image
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
            self.delegate?.imageActivityItemProviderPreprocessingDidBegin(self, withTitle: NSLocalizedString("downloadingImage", comment: "Downloading Photo"))
        })

        // Get the maximum accepted image size (infinity for largest)
        let maxSize = activityType?.imageMaxSize() ?? Int.max

        // Determine the URL request of the image stored on the piwigo server
        guard let urlRequest: URLRequest = ShareUtilities.getUrlRequest(forImage: imageData, withMaxSize: maxSize) else {
            // Cancel task
            cancel()
            // Notify the delegate on the main thread that the processing is cancelled
            alertTitle = NSLocalizedString("downloadImageFail_title", comment: "Download Fail")
            alertMessage = String.localizedStringWithFormat(NSLocalizedString("downloadImageFail_message", comment: "Failed to download image!\n%@"), "")
            preprocessingDidEnd()
            return placeholderItem!
        }

        // Do we have the image in cache?
        if let cache = NetworkVarsObjc.imageCache,
           let cachedImageData = cache.cachedResponse(for: urlRequest)?.data, cachedImageData.isEmpty == false {
            // Create file URL where the shared file is expected to be found
            imageFileURL = ShareUtilities.getFileUrl(ofImage: imageData, withURLrequest: urlRequest)
            // Store image data for future use
            imageFileData = cachedImageData
            
            // Deletes temporary image file if it exists
            do {
                try FileManager.default.removeItem(at: imageFileURL)
            } catch {
            }

            // Store cached image data into /tmp directory
            do {
                try imageFileData.write(to: imageFileURL)
                // Notify the delegate on the main thread to show how it makes progress.
                progressFraction = 0.75
            }
            catch let error as NSError {
                // Will notify the delegate on the main thread that the processing is cancelled
                alertTitle = NSLocalizedString("downloadImageFail_title", comment: "Download Fail")
                alertMessage = String.localizedStringWithFormat(NSLocalizedString("downloadImageFail_message", comment: "Failed to download image!\n%@"), error.localizedDescription)
            }
        }
        else {
            // Download synchronously the image file and store it in cache
            downloadSynchronouslyImage(with: urlRequest)
        }

        // Cancel item task if image could not be retrieved
        if alertTitle != nil {
            // Cancel task
            cancel()
            // Notify the delegate on the main thread that the processing is cancelled.
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

        // We now need to remove private metadata…
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
        
        // Notify the delegate on the main thread to show how it makes progress.
        progressFraction = 0.80

        // Create CGI reference from moved source file
        guard let sourceRef = CGImageSourceCreateWithURL(newSourceURL as CFURL, nil) else {
            // Cancel task
            cancel()
            // Notify the delegate on the main thread that the processing is cancelled.
            alertTitle = NSLocalizedString("shareFailError_title", comment: "Share Fail")
            alertMessage = NSLocalizedString("shareMetadataError_message", comment: "Cannot strip private metadata")
            preprocessingDidEnd()
            return placeholderItem!
        }

        // Prepare destination file of same type
        guard let UTI = CGImageSourceGetType(sourceRef),
              let destinationRef = CGImageDestinationCreateWithURL(imageFileURL as CFURL, UTI, 1, nil) else {
            // Cancel task
            cancel()
            // Notify the delegate on the main thread that the processing is cancelled.
            alertTitle = NSLocalizedString("shareFailError_title", comment: "Share Fail")
            alertMessage = NSLocalizedString("shareMetadataError_message", comment: "Cannot strip private metadata")
            preprocessingDidEnd()
            return placeholderItem!
        }

        // Copy source to destination without private data
        /// See https://developer.apple.com/library/archive/qa/qa1895/_index.html
        /// Try to copy source into destination w/o recompression
        /// One of kCGImageDestinationMetadata, kCGImageDestinationOrientation, or kCGImageDestinationDateTime is required.
        if var metadata = CGImageSourceCopyMetadataAtIndex(sourceRef, 0, nil) {
            // Strip private metadata
            metadata = metadata.stripPrivateMetadata()
            
            // Set destination options
            let options = [kCGImageDestinationMetadata      : metadata,
                           kCGImageMetadataShouldExcludeGPS : true
            ] as CFDictionary
            
            // Copy image source w/o private metadata
            if CGImageDestinationCopyImageSource(destinationRef, sourceRef, options, nil) {
                // Notify the delegate on the main thread to show how it makes progress.
                progressFraction = 1.0

                // Notify the delegate on the main thread that the processing has finished.
                preprocessingDidEnd()

                // Return image to share
                return imageFileURL
            }
        }
        
        // We could not copy source into destination, so we try by recompressing the image
        guard var imageProperties = CGImageSourceCopyPropertiesAtIndex(sourceRef, 0, nil) as? [CFString:Any] else {
            // Cancel task
            cancel()
            // Notify the delegate on the main thread that the processing is cancelled.
            alertTitle = NSLocalizedString("shareFailError_title", comment: "Share Fail")
            alertMessage = NSLocalizedString("shareMetadataError_message", comment: "Private metadata cannot be removed")
            preprocessingDidEnd()
            return placeholderItem!
        }

        // Strip private properties
        imageProperties = imageProperties.stripPrivateProperties()

        // Copy source into destination with unavoidable recompression
        CGImageDestinationSetProperties(destinationRef, imageProperties as CFDictionary)
        let nberOfImages = CGImageSourceGetCount(sourceRef)
        for index in 0..<nberOfImages {
            // Add image at index
            CGImageDestinationAddImageFromSource(destinationRef, sourceRef, index, imageProperties as CFDictionary)
        }

        // Save destination
        guard CGImageDestinationFinalize(destinationRef) else {
            // Cancel task
            cancel()
            // Notify the delegate on the main thread that the processing is cancelled.
            alertTitle = NSLocalizedString("shareFailError_title", comment: "Share Fail")
            alertMessage = NSLocalizedString("shareMetadataError_message", comment: "Cannot strip private metadata")
            preprocessingDidEnd()
            return placeholderItem!
        }

        // Notify the delegate on the main thread to show how it makes progress.
        progressFraction = 1.0

        // Notify the delegate on the main thread that the processing has finished.
        preprocessingDidEnd()

        // Return image to share
        return imageFileURL
    }

    private func downloadSynchronouslyImage(with urlRequest: URLRequest) {
        let sema = DispatchSemaphore(value: 0)
        task = ShareUtilities.downloadImage(with: imageData, at: urlRequest,
            onProgress: { [unowned self] progress in
                // Notify the delegate on the main thread to show how it makes progress.
                self.progressFraction = Float((0.75 * (progress?.fractionCompleted ?? 0.0)))
            },
            completionHandler: { response, fileURL, error in
                // Any error ?
                if let error = error {
                    // Will notify the delegate on the main thread that the processing is cancelled
                    self.alertTitle = NSLocalizedString("shareFailError_title", comment: "Share Fail")
                    self.alertMessage = String.localizedStringWithFormat(NSLocalizedString("downloadImageFail_message", comment: "Failed to download image!\n%@"), error.localizedDescription)
                    sema.signal()
                }
                else {
                    // Get response
                    if let fileURL = fileURL, let response = response {
                        do {
                            // Get file content (file URL defined by ShareUtilities.getFileUrl(ofImage:withUrlRequest)
                            let data = try Data(contentsOf: fileURL)

                            // Check content
                            if data.isEmpty {
                                // Will notify the delegate on the main thread that the processing is cancelled
                                self.alertTitle = NSLocalizedString("shareFailError_title", comment: "Share Fail")
                                self.alertMessage = String.localizedStringWithFormat(NSLocalizedString("downloadImageFail_message", comment: "Failed to download image!\n%@"), "")
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
                                
                                // Store image data for future use
                                self.imageFileData = data
                                sema.signal()
                            }
                        }
                        catch let error as NSError {
                            // Will notify the delegate on the main thread that the processing is cancelled
                            self.alertTitle = NSLocalizedString("shareFailError_title", comment: "Share Fail")
                            self.alertMessage = String.localizedStringWithFormat(NSLocalizedString("downloadImageFail_message", comment: "Failed to download image!\n%@"), error.localizedDescription)
                            sema.signal()
                        }
                    }
                }
            })
        let _ = sema.wait(timeout: .distantFuture)
    }

    private func preprocessingDidEnd() {
        // Notify the delegate on the main thread that the processing is cancelled.
        DispatchQueue.main.async(execute: {
            self.delegate?.imageActivityItemProviderPreprocessingDidEnd(self, withImageId: self.imageData.imageId)
        })
    }
    
    @objc func cancelDownloadImageTask() {
        // Will cancel share when operation starts
        isCancelledByUser = true
        // Cancel image file download
        task?.cancel()
    }

    @objc func didFinishSharingImage() {
        // Remove image share observers
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(kPiwigoNotificationDidShare), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(kPiwigoNotificationCancelDownload), object: nil)

        // Inform user in case of error after dismissing activity view controller
        if let alertTitle = alertTitle {
            if delegate?.responds(to: #selector(ShareImageActivityItemProviderDelegate.showError(withTitle:andMessage:))) ?? false {
                delegate?.showError(withTitle: alertTitle, andMessage: alertMessage)
            }
        }

        // Release memory
        alertTitle = nil
        alertMessage = nil
    }

    
    // MARK: - UIActivityItemSource Methods
    override func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        // Use the filename of the image as subject
        return self.imageData.fileName
    }
    
    override func activityViewController(_ activityViewController: UIActivityViewController, dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?) -> String {
        return kUTTypeImage as String
    }
    
    @available(iOS 13.0, *)
    override func activityViewControllerLinkMetadata(_: UIActivityViewController) -> LPLinkMetadata? {
        let linkMetaData = LPLinkMetadata()
        
        // We use the thumbnail in cache
        let alreadyLoadedSize = kPiwigoImageSize(AlbumVars.defaultThumbnailSize)
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


// MARK: - ShareImageActivityItemProvider Delegate
@objc protocol ShareImageActivityItemProviderDelegate: NSObjectProtocol {
    func imageActivityItemProviderPreprocessingDidBegin(_ imageActivityItemProvider: UIActivityItemProvider?,
                                                        withTitle title: String?)
    func imageActivityItemProvider(_ imageActivityItemProvider: UIActivityItemProvider?,
                                   preprocessingProgressDidUpdate progress: Float)
    func imageActivityItemProviderPreprocessingDidEnd(_ imageActivityItemProvider: UIActivityItemProvider?,
                                                      withImageId imageId: Int)
    func showError(withTitle title: String?, andMessage message: String?)
}
