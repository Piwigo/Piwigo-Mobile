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
import UniformTypeIdentifiers
import piwigoKit
import uploadKit

@objc
protocol ShareImageActivityItemProviderDelegate: NSObjectProtocol {
    func imageActivityItemProviderPreprocessingDidBegin(_ imageActivityItemProvider: UIActivityItemProvider?,
                                                        withTitle title: String)
    func imageActivityItemProvider(_ imageActivityItemProvider: UIActivityItemProvider?,
                                   preprocessingProgressDidUpdate progress: Float)
    func imageActivityItemProviderPreprocessingDidEnd(_ imageActivityItemProvider: UIActivityItemProvider?,
                                                      withImageID imageID: Int64, contextually: Bool)
    func showError(withTitle title: String, andMessage message: String?)
}

// Warning: class must restate inherited '@unchecked Sendable' conformance
class ShareImageActivityItemProvider: UIActivityItemProvider, @unchecked Sendable {
    
    // MARK: - Initialisation
    weak var delegate: ShareImageActivityItemProviderDelegate?

    private var imageData: Image                        // Core Data image
    private var alertTitle: String?                     // Used if task cancels or fails
    private var alertMessage: String?
    private var pwgImageURL: URL                        // URL of image in Piwigo server
    private var cachedFileURL: URL?                     // URL of cached image file
    private var imageFileURL: URL                       // URL of shared image file
    private var isCancelledByUser = false               // Flag updated when pressing Cancel
    private var contextually = false
    
    
    // MARK: - Progress Fraction
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
    init(imageData: Image, scale: CGFloat, contextually: Bool) {
        // Store Piwigo image data for future use
        self.imageData = imageData
        
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
        
        // Store URL of image in cache
        imageFileURL = cacheURL
        pwgImageURL = imageFileURL
        
        // Retrieve image in cache
        if let cachedImage = UIImage(contentsOfFile: imageFileURL.path) {
            let resizedImage = cachedImage.resize(to: CGFloat(70.0), opaque: true, scale: scale)
            super.init(placeholderItem: resizedImage)
        } else {
            super.init(placeholderItem: UIImage(named: "AppIconShare")!)
        }

        // Register image share methods to perform on completion
        NotificationCenter.default.addObserver(self, selector: #selector(didFinishSharingImage),
                                               name: Notification.Name.pwgDidShare, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(cancelDownloadImageTask),
                                               name: Notification.Name.pwgCancelDownload, object: nil)
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
        DispatchQueue.main.async { [self] in
            let title = NSLocalizedString("downloadingImage", comment: "Downloading Photo")
            self.delegate?.imageActivityItemProviderPreprocessingDidBegin(self, withTitle: title)
        }

        // Get the maximum accepted image size (infinity for largest)
        let maxSize = activityType?.imageMaxSize() ?? Int.max

        // Get the server ID and optimum available image size
        guard let serverID = imageData.server?.uuid,
              let (imageSize, imageURL) = ShareUtilities.getOptimumSizeAndURL(imageData, ofMaxSize: maxSize) else {
            // Cancel task
            cancel()
            // Notify the delegate on the main thread that the processing is cancelled
            alertTitle = NSLocalizedString("downloadImageFail_title", comment: "Download Fail")
            alertMessage = String.localizedStringWithFormat(NSLocalizedString("downloadImageFail_message", comment: "Failed to download image!\n%@"), "")
            preprocessingDidEnd()
            return placeholderItem!
        }
        
        // Store URL of image in Piwigo server for being able to cancel the download
        pwgImageURL = imageURL

        // Download image synchronously if not in cache
        let sema = DispatchSemaphore(value: 0)
        PwgSession.shared.getImage(withID: imageData.pwgID, ofSize: imageSize, type: .album, atURL: imageURL,
                                   fromServer: serverID, fileSize: imageData.fileSize) { [weak self] fractionCompleted in
            // Notify the delegate on the main thread to show how it makes progress.
            self?.updateProgressView(with: Float((0.75 * fractionCompleted)))
        } completion: { [unowned self] fileURL in
            self.cachedFileURL = fileURL
            sema.signal()
        } failure: { [unowned self] error in
            // Will notify the delegate on the main thread that the processing is cancelled
            self.alertTitle = NSLocalizedString("shareFailError_title", comment: "Share Fail")
            self.alertMessage = String.localizedStringWithFormat(NSLocalizedString("downloadImageFail_message", comment: "Failed to download image!\n%@"), error.localizedDescription)
            sema.signal()
        }
        let _ = sema.wait(timeout: .distantFuture)

        // Cancel item task if image could not be retrieved
        if alertTitle != nil {
            // Cancel task
            cancel()
            // Notify the delegate on the main thread that the processing is cancelled.
            preprocessingDidEnd()
            return placeholderItem!
        }
        
        // Check that we have the URL of the cached image
        guard let cachedFileURL = cachedFileURL else {
            // Will notify the delegate on the main thread that the processing is cancelled
            self.alertTitle = NSLocalizedString("shareFailError_title", comment: "Share Fail")
            self.alertMessage = String.localizedStringWithFormat(NSLocalizedString("downloadImageFail_message", comment: "Failed to download image!\n%@"), "")
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
        try? FileManager.default.removeItem(at: newSourceURL)

        // Rename temporary original image file
        do {
            try FileManager.default.moveItem(at: imageFileURL, to: newSourceURL)
        }
        catch let error {
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
            ] as [CFString : Any] as CFDictionary
            
            // Copy image source w/o private metadata
            if CGImageDestinationCopyImageSource(destinationRef, sourceRef, options, nil) {
                // Notify the delegate on the main thread to show how it makes progress.
                progressFraction = 1.0

                // Notify the delegate on the main thread that the processing has finished.
                preprocessingDidEnd()

                // Set creation date as the photo creation date
                try? FileManager.default.setAttributes(attrs, ofItemAtPath: imageFileURL.path)

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

        // Set creation date as the photo creation date
        try? FileManager.default.setAttributes(attrs, ofItemAtPath: imageFileURL.path)

        // Return image to share
        return imageFileURL
    }

    private func updateProgressView(with fractionCompleted: Float) {
        DispatchQueue.main.async { [self] in
            // Show download progress
            self.progressFraction = fractionCompleted
        }
    }
    
    private func preprocessingDidEnd() {
        // Notify the delegate on the main thread that the processing is cancelled.
        DispatchQueue.main.async { [self] in
            self.delegate?.imageActivityItemProviderPreprocessingDidEnd(self, withImageID: self.imageData.pwgID, contextually: self.contextually)
        }
    }
    
    @objc func cancelDownloadImageTask() {
        // Will cancel share when operation starts
        isCancelledByUser = true
        // Cancel image file download
        PwgSession.shared.cancelDownload(atURL: pwgImageURL)
    }

    @objc func didFinishSharingImage() {
        // Unregister all observers
        NotificationCenter.default.removeObserver(self)

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
        if #available(iOS 14.0, *) {
            return UTType.image.identifier
        } else {
            return kUTTypeImage as String
        }
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
