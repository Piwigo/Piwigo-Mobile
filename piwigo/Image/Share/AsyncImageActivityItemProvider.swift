//
//  AsyncImageActivityItemProvider.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 12/01/2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//
//  Converted to Swift 5.2 by Eddy Lelièvre-Berna on 10/01/2021
//

import Photos
import UIKit
import LinkPresentation

//let kPiwigoNotificationDidShareImage = "kPiwigoNotificationDidShareImage"
//let kPiwigoNotificationCancelDownloadImage = "kPiwigoNotificationCancelDownloadImage"

@objc
class AsyncImageActivityItemProvider: UIActivityItemProvider {
    
    // MARK: - Initialisation
    @objc weak var delegate: AsyncImageActivityItemProviderDelegate?

    private var imageData: PiwigoImageData              // Piwigo image data
    private var task: URLSessionDownloadTask?           // Download task
    private var alertTitle: String?                     // Used if task cancels or fails
    private var alertMessage: String?
    private var imageFileURL: URL                       // Shared image file path
    private var imageFileData: Data                     // Content of the shared image file

    
    // MARK: - Placeholder Image
    @objc
    init(placeholderImage imageData: PiwigoImageData) {
        // Store Piwigo image data for future use
        self.imageData = imageData

        // We use the thumbnail cached in memory
        let alreadyLoadedSize = Model.sharedInstance().defaultThumbnailSize
        guard let thumbnailRL = URL(string: imageData.getURLFromImageSizeType(alreadyLoadedSize)) else {
            imageFileData = Data()
            imageFileURL = URL.init(string: "")!
            super.init(placeholderItem: UIImage(named: "AppIcon")!)
            return
        }
        
        // Retrieve thumbnail image
        let thumb = UIImageView()
        thumb.setImageWith(thumbnailRL, placeholderImage: UIImage(named: "AppIcon"))
        if let thumbnailImage = thumb.image {
            imageFileURL = thumbnailRL
            imageFileData = thumbnailImage.jpegData(compressionQuality: 1.0) ?? Data()
            super.init(placeholderItem: thumbnailImage)
        } else {
            imageFileData = Data()
            imageFileURL = URL.init(string: "")!
            super.init(placeholderItem: UIImage(named: "AppIcon")!)
        }
    }

    // MARK: - Download & Prepare Image
    ///*************************************************
    /// The item method runs on a secondary thread using an NSOperationQueue
    /// (UIActivityItemProvider subclasses NSOperation).
    /// The implementation of this method loads an image from the Piwigo server.
    ///****************************************************
    override var item: Any {
        // Notify the delegate on the main thread that the processing is beginning.
        DispatchQueue.main.async(execute: {
            self.delegate?.imageActivityItemProviderPreprocessingDidBegin(self, withTitle: NSLocalizedString("downloadingImage", comment: "Downloading Photo"))
        })

        // Register image share methods to perform on completion
        NotificationCenter.default.addObserver(self, selector: #selector(didFinishSharingImage), name: NSNotification.Name(kPiwigoNotificationDidShareImage), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(cancelDownloadImageTask), name: NSNotification.Name(kPiwigoNotificationCancelDownloadImage), object: nil)

        // Select the most appropriate image size (infinity when undefined)
        // See https://makeawebsitehub.com/social-media-image-sizes-cheat-sheet/
        // High resolution for: AirDrop, Copy, Mail, Message, iBooks, Flickr, Print, SaveToCameraRoll
        var minSize = CGFloat.greatestFiniteMagnitude
        if #available(iOS 10, *) {
            if let _ = activityType {
                switch activityType! {
                case .assignToContact:
                    minSize = 1024
                case .postToFacebook:
                    minSize = 1200
                case .postToTencentWeibo:
                    minSize = 640 // 9 images max + 1 video
                case .postToTwitter:
                    minSize = 880 // 4 images max
                case .postToWeibo:
                    minSize = 640 // 9 images max + 1 video
                case kPiwigoActivityTypePostToWhatsApp:
                    minSize = 1920
                case kPiwigoActivityTypePostToSignal:
                    minSize = 1920
                case kPiwigoActivityTypeMessenger:
                    minSize = 1920
                case kPiwigoActivityTypePostInstagram:
                    minSize = 1080
                default:
                    minSize = CGFloat.greatestFiniteMagnitude
                }
            }
        }

        // Determine the URL request
        guard let urlRequest = ShareUtilities.urlRequest(forImage: imageData, withMnimumSize: minSize) else {
            // Cancel task
            cancel()
            // Notify the delegate on the main thread that the processing is cancelled
            self.alertTitle = NSLocalizedString("downloadImageFail_title", comment: "Download Fail")
            self.alertMessage = String.localizedStringWithFormat(NSLocalizedString("downloadImageFail_message", comment: "Failed to download image!\n%@"), "")
            DispatchQueue.main.async(execute: {
                self.delegate?.imageActivityItemProviderPreprocessingDidEnd(self, withImageId: self.imageData.imageId)
            })
            return placeholderItem!
        }

        // Do we have the image in cache?
        if let cachedImageData = Model.sharedInstance().imageCache.cachedResponse(for: urlRequest)?.data,
            !cachedImageData.isEmpty {
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
            }
            catch let error as NSError {
                // Cancel task
                cancel()
                // Notify the delegate on the main thread that the processing is cancelled
                self.alertTitle = NSLocalizedString("downloadImageFail_title", comment: "Download Fail")
                self.alertMessage = String.localizedStringWithFormat(NSLocalizedString("downloadImageFail_message", comment: "Failed to download image!\n%@"), error.localizedDescription)
            }
        }
        else {
            // Download synchronously the image file and store it in cache
            downloadSynchronouslyImage(with: urlRequest)
        }

        // Prepare file before sharing
        checkMetadata()

        // Cancel item task if image preparation failed
        if alertTitle != nil {
            // Cancel task
            cancel()

            // Notify the delegate on the main thread that the processing is cancelled.
            DispatchQueue.main.async(execute: {
                self.delegate?.imageActivityItemProviderPreprocessingDidEnd(self, withImageId: self.imageData.imageId)
            })
            return placeholderItem!
        }

        // Notify the delegate on the main thread to show how it makes progress.
        DispatchQueue.main.async(execute: {
            self.delegate?.imageActivityItemProvider(self, preprocessingProgressDidUpdate: 1.0)
        })

        // Notify the delegate on the main thread that the processing has finished.
        DispatchQueue.main.async(execute: {
            self.delegate?.imageActivityItemProviderPreprocessingDidEnd(self, withImageId: self.imageData.imageId)
        })

        // Return image to share
        return imageFileURL
    }

    private func downloadSynchronouslyImage(with urlRequest: URLRequest){
        let sema = DispatchSemaphore(value: 0)
        task = ShareUtilities.downloadImage(with: imageData, and: urlRequest,
            onProgress: { progress in
                // Notify the delegate on the main thread to show how it makes progress.
                DispatchQueue.main.async(execute: {
                    self.delegate?.imageActivityItemProvider(self, preprocessingProgressDidUpdate: Float((0.75 * (progress?.fractionCompleted ?? 0.0))))
                })
            },
            completionHandler: { response, fileURL, error in
                // Any error ?
                if let error = error{
                    // Failed
                    self.alertTitle = NSLocalizedString("downloadImageFail_title", comment: "Download Fail")
                    self.alertMessage = String.localizedStringWithFormat(NSLocalizedString("downloadImageFail_message", comment: "Failed to download image!\n%@"), error.localizedDescription)
                    sema.signal()
                }
                else {
                    // Get response
                    if let fileURL = fileURL, let response = response {
                        do {
                            // Get file content (file URL defined by ImageService.getFileUrl(ofImage:withUrlRequest)
                            let data = try Data(contentsOf: fileURL)

                            // Check content
                            if data.isEmpty {
                                self.alertTitle = NSLocalizedString("downloadImageFail_title", comment: "Download Fail")
                                self.alertMessage = String.localizedStringWithFormat(NSLocalizedString("downloadImageFail_message", comment: "Failed to download image!\n%@"), "")
                                sema.signal()
                            }
                            else {
                                // Store image in cache
                                let cachedResponse = CachedURLResponse(response: response, data: data)
                                Model.sharedInstance().imageCache.storeCachedResponse(cachedResponse, for: urlRequest)

                                // Set image file URL
                                self.imageFileURL = fileURL
                                
                                // Store image data for future use
                                self.imageFileData = data
                                sema.signal()
                            }
                        }
                        catch let error as NSError {
                            self.alertTitle = NSLocalizedString("downloadImageFail_title", comment: "Download Fail")
                            self.alertMessage = String.localizedStringWithFormat(NSLocalizedString("downloadImageFail_message", comment: "Failed to download image!\n%@"), error.localizedDescription)
                            sema.signal()
                        }
                    }
                }
            })
        let _ = sema.wait(timeout: .distantFuture)
    }

    func checkMetadata() {
        
        // Create CGI reference from image data (to retrieve complete metadata)
        guard let sourceRef = CGImageSourceCreateWithURL(imageFileURL as CFURL, nil) else {
            // Error
            alertTitle = NSLocalizedString("imageSaveError_title", comment: "Fail Saving Image")
            alertMessage = String.localizedStringWithFormat(NSLocalizedString("imageSaveError_message", comment: "Failed to save image. Error: %@"), NSLocalizedString("imageUploadError_source", comment: "cannot create image source"))
            return
        }

        // Notify the delegate on the main thread to show how it makes progress.
        DispatchQueue.main.async(execute: {
            self.delegate?.imageActivityItemProvider(self, preprocessingProgressDidUpdate: 0.8)
        })

        // Get metadata from image data
        guard var imageMetadata = CGImageSourceCopyPropertiesAtIndex(sourceRef, 0, nil) as? [CFString:Any] else {
            // Notify the delegate on the main thread to show how it makes progress.
            DispatchQueue.main.async(execute: {
                self.delegate?.imageActivityItemProvider(self, preprocessingProgressDidUpdate: 0.85)
            })
            return
        }

        // Update/add file metadata from image metadata
        if let originalImage = UIImage(data: imageFileData) {
            imageMetadata = ImageUtilities.fixContents(of: imageMetadata, from: originalImage)
        }
        
        // Strip GPS metadata if user requested it in Settings
        var didChangeMetadata = false
        if #available(iOS 10, *) {
            if let _ = activityType {
                switch activityType! {
                case .airDrop:
                    if !Model.sharedInstance().shareMetadataTypeAirDrop {
                        (didChangeMetadata, imageMetadata) = ImageUtilities.stripGPSdata(from: imageMetadata)
                    }
                case .assignToContact:
                    if !Model.sharedInstance().shareMetadataTypeAssignToContact {
                        (didChangeMetadata, imageMetadata) = ImageUtilities.stripGPSdata(from: imageMetadata)
                    }
                case .copyToPasteboard:
                    if !Model.sharedInstance().shareMetadataTypeCopyToPasteboard {
                        (didChangeMetadata, imageMetadata) = ImageUtilities.stripGPSdata(from: imageMetadata)
                    }
                case .mail:
                    if !Model.sharedInstance().shareMetadataTypeMail {
                        (didChangeMetadata, imageMetadata) = ImageUtilities.stripGPSdata(from: imageMetadata)
                    }
                case .message:
                    if !Model.sharedInstance().shareMetadataTypeMessage {
                        (didChangeMetadata, imageMetadata) = ImageUtilities.stripGPSdata(from: imageMetadata)
                    }
                case .postToFacebook:
                    if !Model.sharedInstance().shareMetadataTypePostToFacebook {
                        (didChangeMetadata, imageMetadata) = ImageUtilities.stripGPSdata(from: imageMetadata)
                    }
                case kPiwigoActivityTypeMessenger:
                    if !Model.sharedInstance().shareMetadataTypeMessenger {
                        (didChangeMetadata, imageMetadata) = ImageUtilities.stripGPSdata(from: imageMetadata)
                    }
                case .postToFlickr:
                    if !Model.sharedInstance().shareMetadataTypePostToFlickr {
                        (didChangeMetadata, imageMetadata) = ImageUtilities.stripGPSdata(from: imageMetadata)
                    }
                case kPiwigoActivityTypePostInstagram:
                    if !Model.sharedInstance().shareMetadataTypePostInstagram {
                        (didChangeMetadata, imageMetadata) = ImageUtilities.stripGPSdata(from: imageMetadata)
                    }
                case kPiwigoActivityTypePostToSignal:
                    if !Model.sharedInstance().shareMetadataTypePostToSignal {
                        (didChangeMetadata, imageMetadata) = ImageUtilities.stripGPSdata(from: imageMetadata)
                    }
                case kPiwigoActivityTypePostToSnapchat:
                    if !Model.sharedInstance().shareMetadataTypePostToSnapchat {
                        (didChangeMetadata, imageMetadata) = ImageUtilities.stripGPSdata(from: imageMetadata)
                    }
                case .postToTencentWeibo:
                    if !Model.sharedInstance().shareMetadataTypePostToTencentWeibo {
                        (didChangeMetadata, imageMetadata) = ImageUtilities.stripGPSdata(from: imageMetadata)
                    }
                case .postToTwitter:
                    if !Model.sharedInstance().shareMetadataTypePostToTwitter {
                        (didChangeMetadata, imageMetadata) = ImageUtilities.stripGPSdata(from: imageMetadata)
                    }
                case .postToVimeo:
                    if !Model.sharedInstance().shareMetadataTypePostToVimeo {
                        (didChangeMetadata, imageMetadata) = ImageUtilities.stripGPSdata(from: imageMetadata)
                    }
                case .postToWeibo:
                    if !Model.sharedInstance().shareMetadataTypePostToWeibo {
                        (didChangeMetadata, imageMetadata) = ImageUtilities.stripGPSdata(from: imageMetadata)
                    }
                case kPiwigoActivityTypePostToWhatsApp:
                    if !Model.sharedInstance().shareMetadataTypePostToWhatsApp {
                        (didChangeMetadata, imageMetadata) = ImageUtilities.stripGPSdata(from: imageMetadata)
                    }
                case .saveToCameraRoll:
                    if !Model.sharedInstance().shareMetadataTypeSaveToCameraRoll {
                        (didChangeMetadata, imageMetadata) = ImageUtilities.stripGPSdata(from: imageMetadata)
                    }
                default:
                    if !Model.sharedInstance().shareMetadataTypeOther {
                        (didChangeMetadata, imageMetadata) = ImageUtilities.stripGPSdata(from: imageMetadata)
                    }
                }
            }
        } else {
            // Single On/Off share metadata option (use first boolean)
            if !Model.sharedInstance().shareMetadataTypeAirDrop {
                (didChangeMetadata, imageMetadata) = ImageUtilities.stripGPSdata(from: imageMetadata)
            }
        }

        // Notify the delegate on the main thread to show how it makes progress.
        DispatchQueue.main.async(execute: {
            self.delegate?.imageActivityItemProvider(self, preprocessingProgressDidUpdate: 0.85)
        })

        // Keep original file if metadata can be shared
        if !didChangeMetadata {
            return
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
            // Error
            alertTitle = NSLocalizedString("imageSaveError_title", comment: "Fail Saving Image")
            alertMessage = String.localizedStringWithFormat(NSLocalizedString("imageSaveError_message", comment: "Failed to save image. Error: %@"), error.localizedDescription)
            return
        }
        
        // Notify the delegate on the main thread to show how it makes progress.
        DispatchQueue.main.async(execute: {
            self.delegate?.imageActivityItemProvider(self, preprocessingProgressDidUpdate: 0.90)
        })

        // Create CGI reference from moved source file (to retrieve complete metadata)
        guard let source2Ref = CGImageSourceCreateWithURL(newSourceURL as CFURL, nil) else {
            // Error
            alertTitle = NSLocalizedString("imageSaveError_title", comment: "Fail Saving Image")
            alertMessage = String.localizedStringWithFormat(NSLocalizedString("imageSaveError_message", comment: "Failed to save image. Error: %@"), NSLocalizedString("imageUploadError_source", comment: "cannot create image source"))
            return
        }

        // Prepare destination file of same type
        guard let UTI = CGImageSourceGetType(source2Ref),
              let destinationRef = CGImageDestinationCreateWithURL(imageFileURL as CFURL, UTI, 1, nil) else {
            // Error
            alertTitle = NSLocalizedString("imageSaveError_title", comment: "Fail Saving Image")
            alertMessage = String.localizedStringWithFormat(NSLocalizedString("imageSaveError_message", comment: "Failed to save image. Error: %@"), NSLocalizedString("imageUploadError_source", comment: "cannot create image source"))
            return
        }

        // Add image from source to destination with new properties
        CGImageDestinationAddImageFromSource(destinationRef, sourceRef, 0, imageMetadata as CFDictionary)

        // Save destination
        guard CGImageDestinationFinalize(destinationRef) else {
            // Error
            alertTitle = NSLocalizedString("imageSaveError_title", comment: "Fail Saving Image")
            alertMessage = String.localizedStringWithFormat(NSLocalizedString("imageSaveError_message", comment: "Failed to save image. Error: %@"), NSLocalizedString("imageUploadError_destination", comment: "cannot create photo destination"))
            return
        }
    }

    @objc func cancelDownloadImageTask() {
        // Cancel image file download
        task?.cancel()
    }

    @objc func didFinishSharingImage() {
        // Remove image share observers
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(kPiwigoNotificationDidShareImage), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(kPiwigoNotificationCancelDownloadImage), object: nil)

        // Inform user in case of error after dismissing activity view controller
        if let alertTitle = alertTitle {
            if delegate?.responds(to: #selector(AsyncImageActivityItemProviderDelegate.showError(withTitle:andMessage:))) ?? false {
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
    
    @available(iOS 13.0, *)
    override func activityViewControllerLinkMetadata(_: UIActivityViewController) -> LPLinkMetadata? {
        let linkMetaData = LPLinkMetadata()
        
        // We use the thumbnail cached in memory
        let alreadyLoadedSize = Model.sharedInstance().defaultThumbnailSize
        if let thumbnailRL = URL(string: imageData.getURLFromImageSizeType(alreadyLoadedSize)) {
            // Retrieve thumbnail image
            let thumb = UIImageView()
            thumb.setImageWith(thumbnailRL, placeholderImage: UIImage(named: "AppIcon"))
            if let thumbnailImage = thumb.image {
                linkMetaData.imageProvider = NSItemProvider(object: thumbnailImage)
            } else {
                linkMetaData.imageProvider = NSItemProvider(object: UIImage(named: "AppIcon")!)
            }
        }
        
        // Title
        linkMetaData.title = imageData.fileName
                
        return linkMetaData
    }
}


// MARK: - AsyncImageActivityItemProvider Delegate
@objc protocol AsyncImageActivityItemProviderDelegate: NSObjectProtocol {
    func imageActivityItemProviderPreprocessingDidBegin(_ imageActivityItemProvider: UIActivityItemProvider?,
                                                        withTitle title: String?)
    func imageActivityItemProvider(_ imageActivityItemProvider: UIActivityItemProvider?,
                                   preprocessingProgressDidUpdate progress: Float)
    func imageActivityItemProviderPreprocessingDidEnd(_ imageActivityItemProvider: UIActivityItemProvider?,
                                                      withImageId imageId: Int)
    func showError(withTitle title: String?, andMessage message: String?)
}
