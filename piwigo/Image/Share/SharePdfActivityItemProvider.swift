//
//  SharePdfActivityItemProvider.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 25/07/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import LinkPresentation
import MobileCoreServices
import UIKit
import UniformTypeIdentifiers
import piwigoKit
import uploadKit

// Warning: class must restate inherited '@unchecked Sendable' conformance
class SharePdfActivityItemProvider: UIActivityItemProvider, @unchecked Sendable {
    
    // MARK: - Initialisation
    weak var delegate: (any ShareImageActivityItemProviderDelegate)?
    
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
            let title = NSLocalizedString("downloadingPDF", comment: "Downloading PDF file")
            self.delegate?.imageActivityItemProviderPreprocessingDidBegin(self, withTitle: title)
        }

        // Get the server ID and URL on server
        guard let serverID = imageData.server?.uuid,
              let imageURL = imageData.downloadUrl as? URL else {
            // Cancel task
            cancel()
            // Notify the delegate on the main thread that the processing is cancelled
            alertTitle = PwgKitError.failedToPrepareDownload.localizedDescription
            alertMessage = String.localizedStringWithFormat(NSLocalizedString("downloadPdfFail_message", comment: "Failed to download PDF file!\n%@"), "")
            preprocessingDidEnd()
            return placeholderItem!
        }
        
        // Store URL of PDF file in Piwigo server for being able to cancel the download
        pwgImageURL = imageURL

        // Download PDF file synchronously if not in cache
        let sema = DispatchSemaphore(value: 0)
        ImageDownloader.shared.getImage(withID: imageData.pwgID, ofSize: .fullRes, type: .album, atURL: imageURL,
                                        fromServer: serverID, fileSize: imageData.fileSize) { [weak self] fractionCompleted in
            // Notify the delegate on the main thread to show how it makes progress.
            self?.updateProgressView(with: Float((0.75 * fractionCompleted)))
        } completion: { [unowned self] fileURL in
            self.cachedFileURL = fileURL
            sema.signal()
        } failure: { [unowned self] error in
            // Will notify the delegate on the main thread that the processing is cancelled
            self.alertTitle = NSLocalizedString("shareFailError_title", comment: "Share Fail")
            self.alertMessage = String.localizedStringWithFormat(NSLocalizedString("downloadPdfFail_message", comment: "Failed to download PDF file!\n%@"), error.localizedDescription)
            sema.signal()
        }
        let _ = sema.wait(timeout: .distantFuture)

        // Cancel item task if PDF file could not be retrieved
        if alertTitle != nil {
            // Cancel task
            cancel()
            // Notify the delegate on the main thread that the processing is cancelled.
            preprocessingDidEnd()
            return placeholderItem!
        }
        
        // Check that we have the URL of the cached PDF file
        guard let cachedFileURL = cachedFileURL else {
            // Will notify the delegate on the main thread that the processing is cancelled
            self.alertTitle = NSLocalizedString("shareFailError_title", comment: "Share Fail")
            self.alertMessage = String.localizedStringWithFormat(NSLocalizedString("downloadPdfFail_message", comment: "Failed to download PDF file!\n%@"), "")
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
            alertMessage = String.localizedStringWithFormat("%@ (%@)", PwgKitError.cannotStripPrivateMetadata.localizedDescription, error.localizedDescription)
            preprocessingDidEnd()
            return placeholderItem!
        }

        // Notify the delegate on the main thread to show how it makes progress.
        progressFraction = 1.0
        // Notify the delegate on the main thread that the processing has finished.
        preprocessingDidEnd()
        // Return PDF file to share
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
        ImageDownloader.shared.cancelDownload(atURL: pwgImageURL)
    }

    @objc func didFinishSharingImage() {
        // Unregister all observers
        NotificationCenter.default.removeObserver(self)

        // Inform user in case of error after dismissing activity view controller
        if let alertTitle = alertTitle {
            if delegate?.responds(to: #selector((any ShareImageActivityItemProviderDelegate).showError(withTitle:andMessage:))) ?? false {
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
        return UTType.pdf.identifier
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
