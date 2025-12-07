//
//  UploadManager+Image.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 21/05/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import CoreData
import MobileCoreServices
import Photos
import UIKit
import piwigoKit

extension UploadManager {
    // See https://developer.apple.com/library/archive/documentation/GraphicsImaging/Conceptual/ImageIOGuide/imageio_intro/ikpg_intro.html#//apple_ref/doc/uid/TP40005462-CH201-TPXREF101
    // See https://developer.apple.com/documentation/uniformtypeidentifiers
    
    // MARK: - Image preparation
    /// Case of an image format accepted by the server
    func prepareImage(atURL originalFileURL: URL, for upload: Upload) -> Void {
        autoreleasepool {
            // Upload the file as is if the user did not request any modification of the photo
            if (!upload.resizeImageOnUpload || upload.photoMaxSize == 0),
               !upload.compressImageOnUpload, !upload.stripGPSdataOnUpload
            {
                // Get creation date from metadata if possible
                upload.creationDate = getCreationDateOfImage(atURL: originalFileURL)
                
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
    }
    
    /// Case of an image format not accepted by the server
    func convertImage(atURL originalFileURL: URL, for upload: Upload) -> Void {
        autoreleasepool {
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
    }
    
    private func didPrepareImage(for upload: Upload, _ error: Error?) {
        // Upload ready for transfer
        // Error?
        if let error = error {
            upload.setState(.preparingError, error: error, save: false)
        } else {
            upload.setState(.prepared, save: false)
        }
        
        self.backgroundQueue.async {
            self.uploadBckgContext.saveIfNeeded()
            self.didEndPreparation()
        }
    }

    
    // MARK: - Utilities
    // Extract creation date from metadata
    /// -> update upload.creationDate
    fileprivate func getCreationDateOfImage(atURL originalFileURL: URL) -> TimeInterval {
        autoreleasepool {
            // Initialise date with file creation date
            let creationDate = (originalFileURL.creationDate ?? DateUtilities.unknownDate).timeIntervalSinceReferenceDate
            
            // Create image source
            let options = [kCGImageSourceShouldCache : false] as CFDictionary
            guard let sourceRef = CGImageSourceCreateWithURL(originalFileURL as CFURL, options) else {
                // Could not prepare image source
                return creationDate
            }

            // Get number of images in source
            let nberOfImages = CGImageSourceGetCount(sourceRef)
            if nberOfImages == 0 {
                // Could not prepare image source
                return creationDate
            }
            
            // Get creation date from metadata if possible
            if let dateFromMetadata = getCreationDateOfImageSource(sourceRef, options: options, nberOfImages: nberOfImages) {
                return dateFromMetadata.timeIntervalSinceReferenceDate
            }
            return creationDate
        }
    }
    
    fileprivate func getCreationDateOfImageSource(_ sourceRef: CGImageSource, options: CFDictionary,
                                              nberOfImages: Int) -> Date? {
        autoreleasepool {
            // Loop over images contained in source file and adopt first available date/time of creation
            for imageIndex in 0..<nberOfImages {
                if let properties = CGImageSourceCopyPropertiesAtIndex(sourceRef, imageIndex, options) as? [CFString : Any],
                   let date = properties.creationDate() {
                    return date
                }
            }
            return nil
        }
    }
    
    // Strip private metadata w/o recompression
    /// -> Return file URL w/ or w/o error
    private func stripMetadataOfImage(atURL originalFileURL:URL, with upload: Upload,
                                      completion: @escaping (URL) -> Void,
                                      failure: @escaping (Error?) -> Void) {
        autoreleasepool {
            // Create image source
            let options = [kCGImageSourceShouldCache      : false,
                           kCGImageSourceShouldAllowFloat : true] as CFDictionary
            guard let sourceRef = CGImageSourceCreateWithURL(originalFileURL as CFURL, options) else {
                // Could not prepare image source
                failure(.missingAsset)
                return
            }

            // Get number of images in source
            let nberOfImages = CGImageSourceGetCount(sourceRef)
            if nberOfImages == 0 {
                // Could not prepare image source
                failure(.missingAsset)
                return
            }
            
            // Get creation date from metadata if possible
            if let dateFromMetadata = getCreationDateOfImageSource(sourceRef, options: options, nberOfImages: nberOfImages) {
                upload.creationDate = dateFromMetadata.timeIntervalSinceReferenceDate
            } else {
                upload.creationDate = (originalFileURL.creationDate ?? DateUtilities.unknownDate).timeIntervalSinceReferenceDate
            }

            // Get URL of final image data file to be stored into Piwigo/Uploads directory
            let fileURL = getUploadFileURL(from: upload, deleted: true)

            // Prepare destination file of same type with same number of images
            guard let UTI = CGImageSourceGetType(sourceRef),
                  let destinationRef = CGImageDestinationCreateWithURL(fileURL as CFURL, UTI, nberOfImages, nil) else {
                // Could not prepare image source
                failure(.missingAsset)
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
                failure(.missingAsset)
                return
            }
            completion(fileURL)
        }
    }
    
    // Modify image at URL (w/o changing its format)
    /// - Resize images
    /// - Compress images if demanded in properties
    /// - Strip private metadata if demanded in properties
    /// -> Return file URL w/ or w/o error
    private func modifyImage(atURL originalFileURL:URL, with upload: Upload,
                             completion: @escaping (URL) -> Void,
                             failure: @escaping (Error?) -> Void) {
        autoreleasepool {
            // Create image source
            let options = [kCGImageSourceShouldCacheImmediately : false,
                           kCGImageSourceShouldAllowFloat       : true] as CFDictionary
            guard let sourceRef = CGImageSourceCreateWithURL(originalFileURL as CFURL, options) else {
                // Could not prepare image source
                failure(.missingAsset)
                return
            }
            
            // Get number of images in source
            let nberOfImages = CGImageSourceGetCount(sourceRef)
            if nberOfImages == 0 {
                // Could not prepare image source
                failure(.missingAsset)
                return
            }
            
            // Get creation date from metadata if possible
            if let dateFromMetadata = getCreationDateOfImageSource(sourceRef, options: options, nberOfImages: nberOfImages) {
                upload.creationDate = dateFromMetadata.timeIntervalSinceReferenceDate
            } else {
                upload.creationDate = (originalFileURL.creationDate ?? DateUtilities.unknownDate).timeIntervalSinceReferenceDate
            }

            // Get URL of final image data file to be stored into Piwigo/Uploads directory
            let fileURL = getUploadFileURL(from: upload, deleted: true)

            // Prepare destination file of same type with same number of images
            guard let UTI = CGImageSourceGetType(sourceRef),
                  let destinationRef = CGImageDestinationCreateWithURL(fileURL as CFURL, UTI, nberOfImages, nil) else {
                // Could not prepare image source
                failure(.missingAsset)
                return
            }

            // Prepare container properties from the source
            /// - must be added before adding images
            var properties: [CFString : Any] = [:]
            if let containerProperties = CGImageSourceCopyProperties(sourceRef, options) as? [CFString : Any] {
#if DEBUG
//debugPrint("====> Container properties of the source image:")
//containerProperties.forEach { (key, value) in
//    debugPrint("\(key): \(value)")
//}
#endif
                // Should we remove private metadata?
                if upload.stripGPSdataOnUpload {
                    // Removes private metadata attributed to this image
                    properties = containerProperties.stripPrivateProperties()
                } else {
                    // Keeps private metadata attributed to this image
                    properties = containerProperties
                }
            }

            // Get index of the primary image
            let imageIndex = CGImageSourceGetPrimaryImageIndex(sourceRef)
            
            // Should we resize the primary image?
            var image:CGImage
            let resizeImage = upload.resizeImageOnUpload && (upload.photoMaxSize != 0)
            if resizeImage {
                // Set options for retrieving the primary image
                let maxSize = pwgPhotoMaxSizes(rawValue: upload.photoMaxSize)?.pixels ?? Int.max
                let resizeOptions = [kCGImageSourceCreateThumbnailFromImageAlways : true,
                                     kCGImageSourceCreateThumbnailWithTransform   : true,
                                     kCGImageSourceThumbnailMaxPixelSize          : maxSize] as [CFString : Any]
                // Get image
                guard let resized = CGImageSourceCreateThumbnailAtIndex(sourceRef, imageIndex,
                                                                        resizeOptions as CFDictionary) else {
                    // Could not retrieve primary image
                    failure(.missingAsset)
                    return
                }
                image = resized
            } else {
                // Get image
                guard let copied = CGImageSourceCreateImageAtIndex(sourceRef, imageIndex, nil) else {
                    // Could not retrieve primary image
                    failure(.missingAsset)
                    return
                }
                image = copied
            }

            // Fix container properties from converted/resized image
            properties.fixContents(from: image, resettingOrientation: resizeImage)
#if DEBUG
//debugPrint("====> Container properties of the destination image:")
//properties.forEach { (key, value) in
//    debugPrint("\(key): \(value)")
//}
#endif
            
            // Set container metadata
            CGImageDestinationSetProperties(destinationRef, properties as CFDictionary)

            // Set primary metadata from the source image
            var imageOptions: Dictionary<CFString,Any> = [:]
            if let imageProperties = CGImageSourceCopyPropertiesAtIndex(sourceRef, imageIndex, options) as? [CFString : Any] {
#if DEBUG
//debugPrint("====> Primary image properties of the source image:")
//imageProperties.forEach { (key, value) in
//    debugPrint("\(key): \(value)")
//}
#endif
                // Should we remove private metadata?
                if upload.stripGPSdataOnUpload {
                    // Removes private metadata attributed to this image
                    imageOptions = imageProperties.stripPrivateProperties()
                }
                else {
                    // Copy metadata attributed to this image
                    imageOptions = imageProperties
                }
                
                // Fix primary image properties from converted/resized image
                imageOptions.fixContents(from: image, resettingOrientation: resizeImage)
#if DEBUG
//debugPrint("====> Primary image properties of the destination image:")
//imageOptions.forEach { (key, value) in
//    debugPrint("\(key): \(value)")
//}
#endif
            }

            // Should we compress the image?
            if upload.compressImageOnUpload {
                let quality = CGFloat(upload.photoQuality) / 100.0
                imageOptions.updateValue(quality as CFNumber, forKey: kCGImageDestinationLossyCompressionQuality)
            }
                    
            // Add image to destination w/ appropriate metadata
            CGImageDestinationAddImage(destinationRef, image, imageOptions as CFDictionary)

            // Loop over the remaining images of the source container
            for index in 0..<nberOfImages {
                // All images except the primary one
                if index == imageIndex { continue }
                
                // Should we resize the images?
                if resizeImage {
                    // Set options for retrieving the primary image
                    let maxSize = pwgPhotoMaxSizes(rawValue: upload.photoMaxSize)?.pixels ?? Int.max
                    let resizeOptions = [kCGImageSourceCreateThumbnailFromImageAlways : true,
                                         kCGImageSourceCreateThumbnailWithTransform   : true,
                                         kCGImageSourceThumbnailMaxPixelSize          : maxSize] as [CFString : Any]
                    // Get image
                    guard let resized = CGImageSourceCreateThumbnailAtIndex(sourceRef, index,
                                                                            resizeOptions as CFDictionary) else {
                        // Could not retrieve primary image
                        failure(.missingAsset)
                        return
                    }
                    image = resized
                } else {
                    // Get image
                    guard let copied = CGImageSourceCreateImageAtIndex(sourceRef, index, nil) else {
                        // Could not retrieve primary image
                        failure(.missingAsset)
                        return
                    }
                    image = copied
                }
                
                // Set metadata from the source image
                if let imageProperties = CGImageSourceCopyPropertiesAtIndex(sourceRef, index, options) as? [CFString : Any] {
#if DEBUG
//debugPrint("====> Image #\(index) properties of the source image:")
//imageProperties.forEach { (key, value) in
//    debugPrint("\(key): \(value)")
//}
#endif
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
                    imageOptions.fixContents(from: image, resettingOrientation: resizeImage)
#if DEBUG
//debugPrint("====> Image #\(index) properties of the destination image:")
//imageOptions.forEach { (key, value) in
//    debugPrint("\(key): \(value)")
//}
#endif
                }
                
                // Should we compress the image?
                if upload.compressImageOnUpload {
                    let quality = CGFloat(upload.photoQuality) / 100.0
                    imageOptions.updateValue(quality as CFNumber, forKey: kCGImageDestinationLossyCompressionQuality)
                }
                        
                // Add image to destination w/ appropriate metadata
                CGImageDestinationAddImage(destinationRef, image, imageOptions as CFDictionary)
            }

            // Save image file
            guard CGImageDestinationFinalize(destinationRef) else {
                // Could not prepare full resolution image file
                failure(.missingAsset)
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
            let options = [kCGImageSourceShouldCacheImmediately : false,
                           kCGImageSourceShouldAllowFloat       : true] as CFDictionary
            guard let sourceRef = CGImageSourceCreateWithURL(originalFileURL as CFURL, options) else {
                // Could not prepare image source
                failure(.missingAsset)
                return
            }
            
            // Check number of images in source
            let nberOfImages = CGImageSourceGetCount(sourceRef)
            if nberOfImages == 0 {
                // Could not prepare image source
                failure(.missingAsset)
                return
            }
            
            // Get creation date from metadata if possible
            if let dateFromMetadata = getCreationDateOfImageSource(sourceRef, options: options, nberOfImages: nberOfImages) {
                upload.creationDate = dateFromMetadata.timeIntervalSinceReferenceDate
            } else {
                upload.creationDate = (originalFileURL.creationDate ?? DateUtilities.unknownDate).timeIntervalSinceReferenceDate
            }
            
            // Prepare conversion to JPEG format
            var UTI: CFString, fileExt: String
            UTI = UTType.jpeg.identifier as CFString
            fileExt = UTType.jpeg.preferredFilenameExtension!
            upload.fileName = URL(fileURLWithPath: upload.fileName)
                .deletingPathExtension().appendingPathExtension(fileExt).lastPathComponent
            
            // Get URL of final image data file to be stored into Piwigo/Uploads directory
            let fileURL = getUploadFileURL(from: upload, deleted: true)

            // Prepare destination file of JPEG type containing a single image
            guard let destinationRef = CGImageDestinationCreateWithURL(fileURL as CFURL, UTI, 1, nil) else {
                // Could not prepare image source
                failure(.missingAsset)
                return
            }
            
            // Prepare container properties from the source
            /// - must be added before adding images
            var properties: [CFString : Any] = [:]
            if let containerProperties = CGImageSourceCopyProperties(sourceRef, options) as? [CFString : Any] {
#if DEBUG
//debugPrint("====> Container properties of the source image:")
//containerProperties.forEach { (key, value) in
//    debugPrint("\(key): \(value)")
//}
#endif
                // Should we remove private metadata?
                if upload.stripGPSdataOnUpload {
                    // Removes private metadata attributed to this image
                    properties = containerProperties.stripPrivateProperties()
                } else {
                    // Keeps private metadata attributed to this image
                    properties = containerProperties
                }
            }

            // Get index of the primary image
            let imageIndex = CGImageSourceGetPrimaryImageIndex(sourceRef)
            
            // Should we resize the image?
            var image:CGImage
            let resizeImage = upload.resizeImageOnUpload && (upload.photoMaxSize != 0)
            if resizeImage {
                // Set options for retrieving the primary image
                let maxSize = pwgPhotoMaxSizes(rawValue: upload.photoMaxSize)?.pixels ?? Int.max
                let resizeOptions = [kCGImageSourceCreateThumbnailFromImageAlways : true,
                                     kCGImageSourceCreateThumbnailWithTransform   : true,
                                     kCGImageSourceThumbnailMaxPixelSize          : maxSize] as [CFString : Any]
                // Get image
                guard let resized = CGImageSourceCreateThumbnailAtIndex(sourceRef, imageIndex,
                                                                        resizeOptions as CFDictionary) else {
                    // Could not retrieve primary image
                    failure(.missingAsset)
                    return
                }
                image = resized
            } else {
                // Get image
                guard let copied = CGImageSourceCreateImageAtIndex(sourceRef, imageIndex, nil) else {
                    // Could not retrieve primary image
                    failure(.missingAsset)
                    return
                }
                image = copied
            }
            
            // Fix container properties from converted/resized image
            properties.fixContents(from: image, resettingOrientation: resizeImage)
#if DEBUG
//debugPrint("====> Container properties of the destination image:")
//properties.forEach { (key, value) in
//    debugPrint("\(key): \(value)")
//}
#endif
            
            // Set container metadata
            CGImageDestinationSetProperties(destinationRef, properties as CFDictionary)

            // Set primary image metadata from the source image
            var imageOptions: Dictionary<CFString,Any> = [:]
            if let imageProperties = CGImageSourceCopyPropertiesAtIndex(sourceRef, imageIndex, options) as? [CFString : Any] {
#if DEBUG
//debugPrint("====> Primary image properties of the source image:")
//imageProperties.forEach { (key, value) in
//    debugPrint("\(key): \(value)")
//}
#endif
                // Should we remove private metadata?
                if upload.stripGPSdataOnUpload {
                    // Removes private metadata attributed to this image
                    imageOptions = imageProperties.stripPrivateProperties()
                }
                else {
                    // Copy metadata attributed to this image
                    imageOptions = imageProperties
                }
                
                // Fix primary image properties from converted/resized image
                imageOptions.fixContents(from: image, resettingOrientation: resizeImage)
#if DEBUG
//debugPrint("====> Primary image properties of the destination image:")
//imageOptions.forEach { (key, value) in
//    debugPrint("\(key): \(value)")
//}
#endif
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
                failure(.missingAsset)
                return
            }
            completion(fileURL)
        }
    }
}
