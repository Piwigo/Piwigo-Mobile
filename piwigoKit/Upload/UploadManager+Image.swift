//
//  UploadImage.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 21/05/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import CoreData
import MobileCoreServices
import Photos
import UIKit

extension UploadManager {
    // See https://developer.apple.com/library/archive/documentation/GraphicsImaging/Conceptual/ImageIOGuide/imageio_intro/ikpg_intro.html#//apple_ref/doc/uid/TP40005462-CH201-TPXREF101
    // See https://developer.apple.com/documentation/uniformtypeidentifiers
    
    // MARK: - Image preparation
    /// Case of an image format accepted by the server
    func prepareImage(atURL originalFileURL: URL, for upload: Upload) -> Void {
        
        // Upload the file as is if the user did not request any modification of the photo
        if (!upload.resizeImageOnUpload || upload.photoMaxSize == 0),
           !upload.compressImageOnUpload, !upload.stripGPSdataOnUpload
        {
            // Get MD5 checksum and MIME type, update counter
            finalizeImageFile(atURL: originalFileURL, with: upload) {
                self.didPrepareImage(for: upload, nil)
            } failure: { error in
                self.didPrepareImage(for: upload, error)
            }
            return
        }
        
        // The user only requested a removal of private metadata
        // We do it w/o recompression of the image.
        if (!upload.resizeImageOnUpload || upload.photoMaxSize == 0),
           !upload.compressImageOnUpload
        {
            stripMetadataOfImage(atURL: originalFileURL, with: upload) { fileURL in
                // Get MD5 checksum and MIME type, update counter
                self.finalizeImageFile(atURL: fileURL, with: upload) {
                    // Update upload request
                    self.didPrepareImage(for: upload, nil)
                } failure: { error in
                    self.didPrepareImage(for: upload, error)
                }
            } failure: { error in
                self.didPrepareImage(for: upload, error)
            }
            return
        }
        
        // The user requested a resize and/or compression
        modifyImage(atURL: originalFileURL, with: upload) { fileURL in
            // Get MD5 checksum and MIME type, update counter
            self.finalizeImageFile(atURL: fileURL, with: upload) {
                // Update upload request
                self.didPrepareImage(for: upload, nil)
            } failure: { error in
                self.didPrepareImage(for: upload, error)
            }
        } failure: { error in
            self.didPrepareImage(for: upload, error)
        }
    }
    
    /// Case of an image format not accepted by the server
    func convertImage(atURL originalFileURL: URL, for upload: Upload) -> Void {
        // Convert image to JPEG format
        convertImage(atURL: originalFileURL, with: upload) { fileURL in
            // Get MD5 checksum and MIME type, update counter
            self.finalizeImageFile(atURL: fileURL, with: upload) {
                // Update upload request
                self.didPrepareImage(for: upload, nil)
            } failure: { error in
                self.didPrepareImage(for: upload, error)
            }
        } failure: { error in
            self.didPrepareImage(for: upload, error)
        }
    }
    
    private func didPrepareImage(for upload: Upload, _ error: Error?) {
        // Error?
        if let error = error {
            upload.setState(.preparingError, error: error)
            // Update UI
            updateCell(with: upload.localIdentifier, stateLabel: upload.stateLabel,
                       photoMaxSize: nil, progress: nil, errorMsg: error.localizedDescription)
        } else {
            upload.setState(.prepared, error: nil)
            updateCell(with: upload.localIdentifier, stateLabel: upload.stateLabel,
                       photoMaxSize: nil, progress: nil, errorMsg: "")
        }

        // Upload ready for transfer
        self.backgroundQueue.async {
            self.didEndPreparation()
        }
    }

    
    // MARK: - Utilities    
    /// - Strip private metadata w/o recompression
    /// -> Return file URL w/ or w/o error
    private func stripMetadataOfImage(atURL originalFileURL:URL, with upload: Upload,
                                      completion: @escaping (URL) -> Void,
                                      failure: @escaping (Error?) -> Void) {
        autoreleasepool {
            // Create image source
            let imageSourceOptions = [kCGImageSourceShouldCache      : false,
                                      kCGImageSourceShouldAllowFloat : true] as CFDictionary
            guard let sourceRef = CGImageSourceCreateWithURL(originalFileURL as CFURL, imageSourceOptions) else {
                // Could not prepare image source
                let error = NSError(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                failure(error)
                return
            }

            // Get number of images in source
            let nberOfImages = CGImageSourceGetCount(sourceRef)
            if nberOfImages == 0 {
                // Could not prepare image source
                let error = NSError(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                failure(error)
                return
            }

            // Get URL of final image data file to be stored into Piwigo/Uploads directory
            let fileURL = getUploadFileURL(from: upload, deleted: true)

            // Prepare destination file of same type with same number of images
            guard let UTI = CGImageSourceGetType(sourceRef),
                  let destinationRef = CGImageDestinationCreateWithURL(fileURL as CFURL, UTI, nberOfImages, nil) else {
                // Could not prepare image source
                let error = NSError(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                failure(error)
                return
            }

            // Apply properties of the source to the destination w/o GPS metadada
            /// - must be done before adding images
            let option = [kCGImageMetadataShouldExcludeGPS : true] as CFDictionary
            CGImageDestinationSetProperties(destinationRef, option)

            // Loop over images contained in source file
            for imageId in 0..<nberOfImages {
                // Copy image w/o GPS metadata
                CGImageDestinationAddImageFromSource(destinationRef, sourceRef, imageId, option as CFDictionary)
            }

            // Save image file
            guard CGImageDestinationFinalize(destinationRef) else {
                // Could not prepare full resolution image file
                let error = NSError(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                failure(error)
                return
            }
            completion(fileURL)
        }
    }
    
    // Modify images at URL (w/o changing its format)
    /// - Resize images
    /// - Compress images if demanded in properties
    /// - Strip private metadata if demanded in properties
    /// -> Return file URL w/ or w/o error
    private func modifyImage(atURL originalFileURL:URL, with upload: Upload,
                             completion: @escaping (URL) -> Void,
                             failure: @escaping (Error?) -> Void) {
        autoreleasepool {
            // Create image source
            let imageSourceOptions = [kCGImageSourceShouldCacheImmediately : false,
                                      kCGImageSourceShouldAllowFloat       : true] as CFDictionary
            guard let sourceRef = CGImageSourceCreateWithURL(originalFileURL as CFURL, imageSourceOptions) else {
                // Could not prepare image source
                let error = NSError(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                failure(error)
                return
            }
            
            // Get number of images in source
            let nberOfImages = CGImageSourceGetCount(sourceRef)
            if nberOfImages == 0 {
                // Could not prepare image source
                let error = NSError(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                failure(error)
                return
            }
            
            // Get URL of final image data file to be stored into Piwigo/Uploads directory
            let fileURL = getUploadFileURL(from: upload, deleted: true)

            // Prepare destination file of same type with same number of images
            guard let UTI = CGImageSourceGetType(sourceRef),
                  let destinationRef = CGImageDestinationCreateWithURL(fileURL as CFURL, UTI, nberOfImages, nil) else {
                // Could not prepare image source
                let error = NSError(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                failure(error)
                return
            }

            // Apply properties of the source to the destination
            /// - must be done before adding images
            if let containerProperties = CGImageSourceCopyProperties(sourceRef, imageSourceOptions) as? [CFString : Any] {
                // Should we remove private metadata?
                var options: [CFString : Any] = [:]
                if upload.stripGPSdataOnUpload {
                    // Removes private metadata attributed to this image
                    options = containerProperties.stripPrivateProperties()
                } else {
                    // Removes private metadata attributed to this image
                    options = containerProperties
                }
                
                // Fix properties
                options.fixProperties(from: containerProperties)
                
                // Copy metadata w/o private infos
                CGImageDestinationSetProperties(destinationRef, options as CFDictionary)
            }

            // Loop over images contained in source file
            for imageIndex in 0..<nberOfImages {
                // Should we resize the images?
                var image:CGImage
                if upload.resizeImageOnUpload, upload.photoMaxSize != 0 {
                    // Set options for retrieving the primary image
                    let maxSize = pwgPhotoMaxSizes(rawValue: upload.photoMaxSize)?.pixels ?? Int.max
                    let resizeOptions = [kCGImageSourceCreateThumbnailFromImageAlways : true,
                                         kCGImageSourceCreateThumbnailWithTransform   : false,
                                         kCGImageSourceThumbnailMaxPixelSize          : maxSize] as [CFString : Any]
                    // Get image
                    guard let resized = CGImageSourceCreateThumbnailAtIndex(sourceRef, imageIndex,
                                                                            resizeOptions as CFDictionary) else {
                        // Could not retrieve primary image
                        let error = NSError(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                        failure(error)
                        return
                    }
                    image = resized
                } else {
                    // Get image
                    guard let copied = CGImageSourceCreateImageAtIndex(sourceRef, imageIndex, nil) else {
                        // Could not retrieve primary image
                        let error = NSError(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                        failure(error)
                        return
                    }
                    image = copied
                }
                
                // Set metadata from the source image
                var imageOptions: [CFString : Any] = [:]
                if let imageProperties = CGImageSourceCopyPropertiesAtIndex(sourceRef, imageIndex,
                                                                            imageSourceOptions) as? [CFString : Any] {
                    // Should we remove private metadata?
                    if upload.stripGPSdataOnUpload {
                        // Removes private metadata attributed to this image
                        imageOptions = imageProperties.stripPrivateProperties()
                    }
                    else {
                        // Copy metadata attributed to this image
                        imageOptions = imageProperties
                    }
                    
                    // Fix metadata for resized image
                    imageOptions.fixContents(from: image)
                }
                
                // Should we compress the image?
                if upload.compressImageOnUpload {
                    let quality = CGFloat(upload.photoQuality) / 100.0
                    imageOptions.updateValue(quality as CFNumber, forKey: kCGImageDestinationLossyCompressionQuality)
                }
                        
                // Add image to destination w/ appropriate metadatab
                CGImageDestinationAddImage(destinationRef, image, imageOptions as CFDictionary)
            }

            // Save image file
            guard CGImageDestinationFinalize(destinationRef) else {
                // Could not prepare full resolution image file
                let error = NSError(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                failure(error)
                return
            }
            completion(fileURL)
        }
    }

    /// - Convert image at URL using ImageIO
    /// - Resize images if demanded in properties
    /// - Compress images if demanded in properties
    /// - Strip private metadata if demanded in properties
    /// -> Return file URL w/ or w/o error
    private func convertImage(atURL originalFileURL:URL, with upload: Upload,
                              completion: @escaping (URL) -> Void,
                              failure: @escaping (Error?) -> Void) {
        autoreleasepool {
            // Create image source
            let imageSourceOptions = [kCGImageSourceShouldCacheImmediately : false,
                                      kCGImageSourceShouldAllowFloat       : true] as CFDictionary
            guard let sourceRef = CGImageSourceCreateWithURL(originalFileURL as CFURL, imageSourceOptions) else {
                // Could not prepare image source
                let error = NSError(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                failure(error)
                return
            }
            
            // Get index of the primary image (assumes 0 before iOS 12)
            var imageIndex = 0
            if #available(iOSApplicationExtension 12.0, *) {
                imageIndex = CGImageSourceGetPrimaryImageIndex(sourceRef)
            }
            
            // Should we resize the image?
            var image:CGImage
            if upload.resizeImageOnUpload, upload.photoMaxSize != 0 {
                // Set options for retrieving the primary image
                let maxSize = pwgPhotoMaxSizes(rawValue: upload.photoMaxSize)?.pixels ?? Int.max
                let resizeOptions = [kCGImageSourceCreateThumbnailFromImageAlways : true,
                                     kCGImageSourceCreateThumbnailWithTransform   : false,
                                     kCGImageSourceThumbnailMaxPixelSize          : maxSize] as [CFString : Any]
                // Get image
                guard let resized = CGImageSourceCreateThumbnailAtIndex(sourceRef, imageIndex,
                                                                        resizeOptions as CFDictionary) else {
                    // Could not retrieve primary image
                    let error = NSError(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                    failure(error)
                    return
                }
                image = resized
            } else {
                // Get image
                guard let copied = CGImageSourceCreateImageAtIndex(sourceRef, imageIndex, nil) else {
                    // Could not retrieve primary image
                    let error = NSError(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                    failure(error)
                    return
                }
                image = copied
            }
            
            // Prepare conversion to JPEG format
            var UTI: CFString, fileExt: String
            if #available(iOSApplicationExtension 14.0, *) {
                UTI = UTType.jpeg.identifier as CFString
                fileExt = UTType.jpeg.preferredFilenameExtension!
            } else {
                // Fallback on earlier versions
                UTI = kUTTypeJPEG as CFString
                fileExt = "jpeg"
            }
            upload.fileName = URL(fileURLWithPath: upload.fileName)
                .deletingPathExtension().appendingPathExtension(fileExt).lastPathComponent
            
            // Get URL of final image data file to be stored into Piwigo/Uploads directory
            let fileURL = getUploadFileURL(from: upload, deleted: true)

            // Prepare destination file of JPEG type with a single image
            guard let destinationRef = CGImageDestinationCreateWithURL(fileURL as CFURL, UTI, 1, nil) else {
                // Could not prepare image source
                let error = NSError(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                failure(error)
                return
            }
            
            // Apply properties of the source to the destination
            /// - must be done before adding images
            if let containerProperties = CGImageSourceCopyProperties(sourceRef, imageSourceOptions) as? [CFString : Any] {
                // Should we remove private metadata?
                var options: [CFString : Any] = [:]
                if upload.stripGPSdataOnUpload {
                    // Removes private metadata attributed to this image
                    options = containerProperties.stripPrivateProperties()
                } else {
                    // Removes private metadata attributed to this image
                    options = containerProperties
                }
                
                // Fix properties
                options.fixProperties(from: containerProperties)
                
                // Copy metadata w/o private infos
                CGImageDestinationSetProperties(destinationRef, options as CFDictionary)
            }

            // Set metadata from the source image
            var imageOptions: Dictionary<CFString,Any> = [:]
            if let imageProperties = CGImageSourceCopyPropertiesAtIndex(sourceRef, imageIndex,
                                                                        imageSourceOptions) as? [CFString : Any] {
                // Should we remove private metadata?
                if upload.stripGPSdataOnUpload {
                    // Removes private metadata attributed to this image
                    imageOptions = imageProperties.stripPrivateProperties()
                }
                else {
                    // Copy metadata attributed to this image
                    imageOptions = imageProperties
                }
                
                // Fix metadata for converted/resized image
                imageOptions.fixContents(from: image)
            }
            
            // Should we compress the image?
            if upload.compressImageOnUpload {
                let quality = CGFloat(upload.photoQuality) / 100.0
                imageOptions.updateValue(quality as CFNumber, forKey: kCGImageDestinationLossyCompressionQuality)
            }
                    
            // Add image to destination w/ appropriate metadata
            CGImageDestinationAddImage(destinationRef, image, imageOptions as CFDictionary)

            // Save image file
            guard CGImageDestinationFinalize(destinationRef) else {
                // Could not prepare full resolution image file
                let error = NSError(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                failure(error)
                return
            }
            completion(fileURL)
        }
    }
}
