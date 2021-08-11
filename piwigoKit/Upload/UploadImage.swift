//
//  UploadImage.swift
//  piwigo
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
    func prepareImage(atURL originalFileURL: URL,
                      for uploadID: NSManagedObjectID, with properties: UploadProperties) -> Void {
        
        // Upload the file as is if the user did not request any modification of the photo
        if (!properties.resizeImageOnUpload || properties.photoMaxSize == 0),
           !properties.compressImageOnUpload, !properties.stripGPSdataOnUpload
        {
            // Get MD5 checksum and MIME type, update counter
            finalizeImageFile(atURL: originalFileURL, with: properties) { [unowned self] finalProperties, error in
                // Update upload request
                self.didPrepareImage(for: uploadID, with: finalProperties, nil)
            }
            return
        }
        
        // The user only requested a removal of private metadata
        // We do it w/o recompression of the image.
        if (!properties.resizeImageOnUpload || properties.photoMaxSize == 0),
           !properties.compressImageOnUpload
        {
            stripMetadataOfImage(atURL: originalFileURL, with: properties) { fileURL, error in
                // Get MD5 checksum and MIME type, update counter
                self.finalizeImageFile(atURL: fileURL, with: properties) { finalProperties, error in
                    // Update upload request
                    self.didPrepareImage(for: uploadID, with: finalProperties, error)
                }
            }
            return
        }
        
        // The user requested a resize and/or compression
        modifyImage(atURL: originalFileURL, with: properties) { [unowned self] fileURL, error in
            // Get MD5 checksum and MIME type, update counter
            self.finalizeImageFile(atURL: fileURL, with: properties) { finalProperties, error in
                // Update upload request
                self.didPrepareImage(for: uploadID, with: finalProperties, error)
            }
        }
    }
    
    /// Case of an image format not accepted by the server
    func convertImage(atURL originalFileURL: URL,
                      for uploadID: NSManagedObjectID, with properties: UploadProperties) -> Void {
        // Convert image to JPEG format
        convertImage(atURL: originalFileURL, with: properties) { [unowned self] updatedProperties, fileURL, error in
            // Get MD5 checksum and MIME type, update counter
            self.finalizeImageFile(atURL: fileURL, with: updatedProperties) { finalProperties, error in
                // Update upload request
                self.didPrepareImage(for: uploadID, with: finalProperties, error)
            }
        }
    }
    
    private func didPrepareImage(for uploadID: NSManagedObjectID,
                                 with properties: UploadProperties, _ error: Error?) {
        // Initialisation
        var newProperties = properties
        newProperties.requestState = .prepared
        var errorMsg = ""
        
        // Error?
        if let error = error {
            newProperties.requestState = .preparingError
            errorMsg = error.localizedDescription
        }

        // Update UI
        updateCell(with: newProperties.localIdentifier, stateLabel: newProperties.stateLabel,
                   photoMaxSize: nil, progress: nil, errorMsg: errorMsg)

        // Update state of upload request
        print("\(debugFormatter.string(from: Date())) > prepared \(uploadID) i.e. \(properties.fileName) \(errorMsg)")
        uploadsProvider.updatePropertiesOfUpload(with: uploadID, properties: newProperties) { [unowned self] (_) in
            // Upload ready for transfer
            self.didEndPreparation()
        }
    }

    
    // MARK: - Utilities    
    /// - Strip private metadata w/o recompression
    /// -> Return file URL w/ or w/o error
    private func stripMetadataOfImage(atURL originalFileURL:URL, with properties: UploadProperties,
                                      completionHandler: @escaping (URL, Error?) -> Void) {
        autoreleasepool {
            // Create image source
            let imageSourceOptions = [kCGImageSourceShouldCache      : false,
                                      kCGImageSourceShouldAllowFloat : true] as CFDictionary
            guard let sourceRef = CGImageSourceCreateWithURL(originalFileURL as CFURL, imageSourceOptions) else {
                // Could not prepare image source
                let error = NSError(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                completionHandler(originalFileURL, error)
                return
            }

            // Get number of images in source
            let nberOfImages = CGImageSourceGetCount(sourceRef)
            if nberOfImages == 0 {
                // Could not prepare image source
                let error = NSError(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                completionHandler(originalFileURL, error)
                return
            }

            // Get URL of final image data file to be stored into Piwigo/Uploads directory
            let fileURL = getUploadFileURL(from: properties, deleted: true)

            // Prepare destination file of same type with same number of images
            guard let UTI = CGImageSourceGetType(sourceRef),
                  let destinationRef = CGImageDestinationCreateWithURL(fileURL as CFURL, UTI, nberOfImages, nil) else {
                // Could not prepare image source
                let error = NSError(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                completionHandler(fileURL, error)
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
                completionHandler(fileURL, error)
                return
            }
            completionHandler(fileURL, nil)
        }
    }
    
    // Modify images at URL (w/o changing its format)
    /// - Resize images
    /// - Compress images if demanded in properties
    /// - Strip private metadata if demanded in properties
    /// -> Return file URL w/ or w/o error
    private func modifyImage(atURL originalFileURL:URL, with properties: UploadProperties,
                             completionHandler: @escaping (URL, Error?) -> Void) {
        autoreleasepool {
            // Create image source
            let imageSourceOptions = [kCGImageSourceShouldCacheImmediately : false,
                                      kCGImageSourceShouldAllowFloat       : true] as CFDictionary
            guard let sourceRef = CGImageSourceCreateWithURL(originalFileURL as CFURL, imageSourceOptions) else {
                // Could not prepare image source
                let error = NSError(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                completionHandler(originalFileURL, error)
                return
            }
            
            // Get number of images in source
            let nberOfImages = CGImageSourceGetCount(sourceRef)
            if nberOfImages == 0 {
                // Could not prepare image source
                let error = NSError(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                completionHandler(originalFileURL, error)
                return
            }
            
            // Get URL of final image data file to be stored into Piwigo/Uploads directory
            let fileURL = getUploadFileURL(from: properties, deleted: true)

            // Prepare destination file of same type with same number of images
            guard let UTI = CGImageSourceGetType(sourceRef),
                  let destinationRef = CGImageDestinationCreateWithURL(fileURL as CFURL, UTI, nberOfImages, nil) else {
                // Could not prepare image source
                let error = NSError(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                completionHandler(fileURL, error)
                return
            }

            // Apply properties of the source to the destination
            /// - must be done before adding images
            if let containerProperties = CGImageSourceCopyProperties(sourceRef, imageSourceOptions) as? [CFString : Any] {
                // Should we remove private metadata?
                var options: [CFString : Any] = [:]
                if properties.stripGPSdataOnUpload {
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
                if properties.resizeImageOnUpload, properties.photoMaxSize != 0 {
                    // Set options for retrieving the primary image
                    let maxSize = pwgPhotoMaxSizes(rawValue: properties.photoMaxSize)?.pixels ?? Int.max
                    let resizeOptions = [kCGImageSourceCreateThumbnailFromImageAlways : true,
                                         kCGImageSourceCreateThumbnailWithTransform   : false,
                                         kCGImageSourceThumbnailMaxPixelSize          : maxSize] as [CFString : Any]
                    // Get image
                    guard let resized = CGImageSourceCreateThumbnailAtIndex(sourceRef, imageIndex,
                                                                            resizeOptions as CFDictionary) else {
                        // Could not retrieve primary image
                        let error = NSError(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                        completionHandler(originalFileURL, error)
                        return
                    }
                    image = resized
                } else {
                    // Get image
                    guard let copied = CGImageSourceCreateImageAtIndex(sourceRef, imageIndex, nil) else {
                        // Could not retrieve primary image
                        let error = NSError(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                        completionHandler(originalFileURL, error)
                        return
                    }
                    image = copied
                }
                
                // Set metadata from the source image
                var imageOptions: [CFString : Any] = [:]
                if let imageProperties = CGImageSourceCopyPropertiesAtIndex(sourceRef, imageIndex,
                                                                            imageSourceOptions) as? [CFString : Any] {
                    // Should we remove private metadata?
                    if properties.stripGPSdataOnUpload {
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
                if properties.compressImageOnUpload {
                    let quality = CGFloat(properties.photoQuality) / 100.0
                    imageOptions.updateValue(quality as CFNumber, forKey: kCGImageDestinationLossyCompressionQuality)
                }
                        
                // Add image to destination w/ appropriate metadatab
                CGImageDestinationAddImage(destinationRef, image, imageOptions as CFDictionary)
            }

            // Save image file
            guard CGImageDestinationFinalize(destinationRef) else {
                // Could not prepare full resolution image file
                let error = NSError(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                completionHandler(fileURL, error)
                return
            }
            completionHandler(fileURL, nil)
        }
    }

    /// - Convert image at URL using ImageIO
    /// - Resize images if demanded in properties
    /// - Compress images if demanded in properties
    /// - Strip private metadata if demanded in properties
    /// -> Return file URL w/ or w/o error
    private func convertImage(atURL originalFileURL:URL, with properties: UploadProperties,
                              completionHandler: @escaping (UploadProperties, URL, Error?) -> Void) {
        autoreleasepool {
            // Create image source
            let imageSourceOptions = [kCGImageSourceShouldCacheImmediately : false,
                                      kCGImageSourceShouldAllowFloat       : true] as CFDictionary
            guard let sourceRef = CGImageSourceCreateWithURL(originalFileURL as CFURL, imageSourceOptions) else {
                // Could not prepare image source
                let error = NSError(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                completionHandler(properties, originalFileURL, error)
                return
            }
            
            // Get index of the primary image (assumes 0 before iOS 12)
            var imageIndex = 0
            if #available(iOSApplicationExtension 12.0, *) {
                imageIndex = CGImageSourceGetPrimaryImageIndex(sourceRef)
            }
            
            // Should we resize the image?
            var image:CGImage
            if properties.resizeImageOnUpload, properties.photoMaxSize != 0 {
                // Set options for retrieving the primary image
                let maxSize = pwgPhotoMaxSizes(rawValue: properties.photoMaxSize)?.pixels ?? Int.max
                let resizeOptions = [kCGImageSourceCreateThumbnailFromImageAlways : true,
                                     kCGImageSourceCreateThumbnailWithTransform   : false,
                                     kCGImageSourceThumbnailMaxPixelSize          : maxSize] as [CFString : Any]
                // Get image
                guard let resized = CGImageSourceCreateThumbnailAtIndex(sourceRef, imageIndex,
                                                                        resizeOptions as CFDictionary) else {
                    // Could not retrieve primary image
                    let error = NSError(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                    completionHandler(properties, originalFileURL, error)
                    return
                }
                image = resized
            } else {
                // Get image
                guard let copied = CGImageSourceCreateImageAtIndex(sourceRef, imageIndex, nil) else {
                    // Could not retrieve primary image
                    let error = NSError(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                    completionHandler(properties, originalFileURL, error)
                    return
                }
                image = copied
            }
            
            // Prepare conversion to JPEG format
            var UTI: CFString, fileExt: String
            var uploadProperties = properties
            if #available(iOSApplicationExtension 14.0, *) {
                UTI = UTType.jpeg.identifier as CFString
                fileExt = UTType.jpeg.preferredFilenameExtension!
            } else {
                // Fallback on earlier versions
                UTI = kUTTypeJPEG as CFString
                fileExt = "jpeg"
            }
            uploadProperties.fileName = URL(fileURLWithPath: properties.fileName).deletingPathExtension().appendingPathExtension(fileExt).lastPathComponent
            
            // Get URL of final image data file to be stored into Piwigo/Uploads directory
            let fileURL = getUploadFileURL(from: properties, deleted: true)

            // Prepare destination file of JPEG type with a single image
            guard let destinationRef = CGImageDestinationCreateWithURL(fileURL as CFURL, UTI, 1, nil) else {
                // Could not prepare image source
                let error = NSError(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                completionHandler(uploadProperties, fileURL, error)
                return
            }
            
            // Apply properties of the source to the destination
            /// - must be done before adding images
            if let containerProperties = CGImageSourceCopyProperties(sourceRef, imageSourceOptions) as? [CFString : Any] {
                // Should we remove private metadata?
                var options: [CFString : Any] = [:]
                if properties.stripGPSdataOnUpload {
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
                if properties.stripGPSdataOnUpload {
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
            if properties.compressImageOnUpload {
                let quality = CGFloat(properties.photoQuality) / 100.0
                imageOptions.updateValue(quality as CFNumber, forKey: kCGImageDestinationLossyCompressionQuality)
            }
                    
            // Add image to destination w/ appropriate metadata
            CGImageDestinationAddImage(destinationRef, image, imageOptions as CFDictionary)

            // Save image file
            guard CGImageDestinationFinalize(destinationRef) else {
                // Could not prepare full resolution image file
                let error = NSError(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                completionHandler(uploadProperties, fileURL, error)
                return
            }
            completionHandler(uploadProperties, fileURL, nil)
        }
    }
}
