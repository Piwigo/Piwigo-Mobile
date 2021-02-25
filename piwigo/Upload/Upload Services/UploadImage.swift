//
//  UploadImage.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 21/05/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import Photos
import MobileCoreServices

extension UploadManager {
    
    // MARK: - Image preparation
    /// Case of an image from the pasteboard
    func prepareImage(atURL fileURL: URL,
                      for uploadID: NSManagedObjectID, with uploadProperties: UploadProperties) -> Void {
        
        // Retrieve image data from file stored in the Uploads directory
        /// The full resolution image contains all metadata
        var fullResImageData: Data = Data()
        do {
            try fullResImageData = NSData (contentsOf: fileURL) as Data
        }
        catch let error as NSError {
            // Could not find the file to upload!
            print(error.localizedDescription)
            let error = NSError.init(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
            self.didPrepareImage(for: uploadID, with: uploadProperties, error)
            return
        }
        
        // Did the user request a resize?
        if !uploadProperties.resizeImageOnUpload || (uploadProperties.photoResize == 100) {
            // No -> Upload full resolution image
            exportFullResolutionImage(from: fullResImageData,
                                      for: uploadID, with: uploadProperties) { (newUploadProperties, error) in
                // Update upload request
                self.didPrepareImage(for: uploadID, with: newUploadProperties, error)
            }
            return
        }
        
        // Retrieve UIImage from imageData
        guard let originalImage = UIImage(data: fullResImageData) else {
            let error = NSError.init(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
            self.didPrepareImage(for: uploadID, with: uploadProperties, error)
            return
        }

        // Resize image
        let originalSize = max(originalImage.size.width, originalImage.size.height)
        let dimension: CGFloat = CGFloat(uploadProperties.photoResize) / 100.0 * originalSize
        let resizedImage = originalImage.resize(to: dimension, opaque: false, scale: 1.0)

        // Export resized image
        self.exportResizedImage(for: uploadProperties,
                                with: fullResImageData, andResized: resizedImage) { (newUploadProperties, error) in
            // Update upload request
            self.didPrepareImage(for: uploadID, with: newUploadProperties, error)
        }
    }
    
    /// Case of an image from the Photo Library
    func prepareImage(asset imageAsset: PHAsset,
                      for uploadID: NSManagedObjectID, with uploadProperties: UploadProperties) -> Void {

        // Retrieve image data
        self.retrieveFullSizeImageData(from: imageAsset) { (fullSizeData, dataError) in
            if let _ = dataError {
                self.didPrepareImage(for: uploadID, with: uploadProperties, dataError)
                return
            }
            guard let fullResImageData = fullSizeData else {
                let error = NSError.init(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                self.didPrepareImage(for: uploadID, with: uploadProperties, error)
                return
            }

            // Did the user request a resize?
            if !uploadProperties.resizeImageOnUpload || (uploadProperties.photoResize == 100) {
                // No -> Upload full resolution image
                self.exportFullResolutionImage(from: fullResImageData,
                                               for:uploadID, with: uploadProperties) { (newUploadProperties, error) in
                    // Update upload request
                    self.didPrepareImage(for: uploadID, with: newUploadProperties, error)
                }
                return
            }
            
            // Retrieve UIImage
            self.retrieveScaledUIImage(from: imageAsset, for: uploadProperties) { (scaledUIImage, imageError) in
                if let imageError = imageError {
                    self.didPrepareImage(for: uploadID, with: uploadProperties, imageError)
                    return
                }
                guard let resizedImage = scaledUIImage else {
                    let error = NSError.init(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                    self.didPrepareImage(for: uploadID, with: uploadProperties, error)
                    return
                }

                // Export image
                self.exportResizedImage(for: uploadProperties,
                                        with: fullResImageData, andResized: resizedImage) { (newUploadProperties, error) in
                    // Update upload request
                    self.didPrepareImage(for: uploadID, with: newUploadProperties, error)
                }
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
                   photoResize: nil, progress: Float(0.0), errorMsg: errorMsg)

        // Update state of upload request
        print("\(debugFormatter.string(from: Date())) > prepared \(uploadID) i.e. \(properties.fileName) \(errorMsg)")
        uploadsProvider.updatePropertiesOfUpload(with: uploadID, properties: newProperties) { [unowned self] (_) in
            // Upload ready for transfer
            if self.isExecutingBackgroundUploadTask {
                // In background task
                if newProperties.requestState == .prepared {
                    self.transferInBackgroundImage(for: uploadID, with: newProperties)
                }
            } else {
                // Consider next step
                self.didEndPreparation()
            }
        }
    }

    
    // MARK: - Full Resolution Image
    /// Request the full resolution image data with all metadata
    private func retrieveFullSizeImageData(from imageAsset: PHAsset,
                                           completionHandler: @escaping (Data?, Error?) -> Void) {
        // Options for retrieving metadata
        let options = PHImageRequestOptions()
        // Photos processes the image request synchronously unless when the app is active
        options.isSynchronous = isExecutingBackgroundUploadTask
        // Requests the most recent version of the image asset
        options.version = .current
        // Requests a fast-loading image, possibly sacrificing image quality.
        options.deliveryMode = .fastFormat
        // Photos can download the requested video from iCloud
        options.isNetworkAccessAllowed = true

        // The block Photos calls periodically while downloading the photo
        options.progressHandler = { progress, error, stop, info in
            print(String(format: "    > retrieveFullSizeAssetDataFromImage... progress %lf", progress))
        }

        autoreleasepool {
            if #available(iOS 13.0, *) {
                PHImageManager.default().requestImageDataAndOrientation(for: imageAsset, options: options,
                                                                        resultHandler: { imageData, dataUTI, orientation, info in
                    // resultHandler redirected to the main thread by default!
                    if self.isExecutingBackgroundUploadTask {
//                        print("\(self.debugFormatter.string(from: Date())) > exits retrieveFullSizeAssetDataFromImage in", queueName())
                        if info?[PHImageErrorKey] != nil || ((imageData?.count ?? 0) == 0) {
                            completionHandler(nil, info?[PHImageErrorKey] as? Error)
                        } else {
                            completionHandler(imageData, nil)
                        }
                    } else {
                        DispatchQueue(label: "prepareImage").async {
//                            print("\(self.debugFormatter.string(from: Date())) > exits retrieveFullSizeAssetDataFromImage in", queueName())
                            if info?[PHImageErrorKey] != nil || ((imageData?.count ?? 0) == 0) {
                                completionHandler(nil, info?[PHImageErrorKey] as? Error)
                            } else {
                                completionHandler(imageData, nil)
                            }
                        }
                    }
                })
            } else {
                PHImageManager.default().requestImageData(for: imageAsset, options: options,
                                                          resultHandler: { imageData, dataUTI, orientation, info in
                    // resultHandler performed on main thread!
                    if self.isExecutingBackgroundUploadTask {
//                        print("\(self.debugFormatter.string(from: Date())) > exits retrieveFullSizeAssetDataFromImage in", queueName())
                        if info?[PHImageErrorKey] != nil || ((imageData?.count ?? 0) == 0) {
                            completionHandler(nil, info?[PHImageErrorKey] as? Error)
                        } else {
                            completionHandler(imageData, nil)
                        }
                    } else {
                        DispatchQueue(label: "prepareImage").async {
//                            print("\(self.debugFormatter.string(from: Date())) > exits retrieveFullSizeAssetDataFromImage in", queueName())
                            if info?[PHImageErrorKey] != nil || ((imageData?.count ?? 0) == 0) {
                                completionHandler(nil, info?[PHImageErrorKey] as? Error)
                            } else {
                                completionHandler(imageData, nil)
                            }
                        }
                    }
                })
            }
        }
    }

    /// Export the full resolution image file to be uploaded
    /// - Private metadata are removed if requested by the user
    /// - The format is converted to JPEG if the server does not accept the original format
    private func exportFullResolutionImage(from fullResImageData: Data,
                                           for uploadID: NSManagedObjectID, with upload: UploadProperties,
                                           completionHandler: @escaping (UploadProperties, Error?) -> Void) {
        print("\(self.debugFormatter.string(from: Date())) > enters exportFullResolutionImage in", queueName())
        // Initialisation
        var newUpload = upload
        
        // Proceed immadiately if:
        /// - the image container format is accepted by the server
        /// - the user did not request a compression
        let fileExt = (URL(fileURLWithPath: upload.fileName).pathExtension).lowercased()
        if upload.serverFileTypes.contains(fileExt), !upload.compressImageOnUpload {
            // Get MIME type
            guard let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, fileExt as NSString, nil)?.takeRetainedValue() else {
                let error = NSError.init(domain: "Piwigo", code: 0, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                completionHandler(upload, error)
                return
            }
            guard let mimeType = (UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType)?.takeRetainedValue()) as String? else  {
                let error = NSError.init(domain: "Piwigo", code: 0, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                completionHandler(upload, error)
                return
            }
            newUpload.mimeType = mimeType

            // File name of final image data to be stored into Piwigo/Uploads directory
            let fileName = upload.localIdentifier.replacingOccurrences(of: "/", with: "-")
            let fileURL = self.applicationUploadsDirectory.appendingPathComponent(fileName)

            // Deletes temporary image file if exists (incomplete previous attempt?)
            do {
                try FileManager.default.removeItem(at: fileURL)
            } catch {
            }

            // Should we strip GPS metadata?
            if !upload.stripGPSdataOnUpload {
                // No need to remove private metadata
                // Export full resolution image file into Piwigo/Uploads directory
                do {
                    try fullResImageData.write(to: fileURL)
                } catch let error as NSError {
                    completionHandler(newUpload, error)
                    return
                }
                
                // Determine MD5 checksum of image file to upload
                newUpload.md5Sum = fullResImageData.MD5checksum()
                print("\(self.debugFormatter.string(from: Date())) > MD5: \(String(describing: newUpload.md5Sum))")
                completionHandler(newUpload, nil)
                return
            }
            
            // Remove private metadata
            // Create CGI reference from full resolution image data
            guard let sourceRef: CGImageSource = CGImageSourceCreateWithData((fullResImageData as CFData), nil) else {
                // Could not prepare image source
                let error = NSError.init(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                completionHandler(upload, error)
                return
            }

            // Prepare destination file of same type
            guard let UTI = CGImageSourceGetType(sourceRef),
                  let destinationRef = CGImageDestinationCreateWithURL(fileURL as CFURL, UTI, 1, nil) else {
                // Could not prepare image source
                let error = NSError.init(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                completionHandler(upload, error)
                return
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
                    // Determine MD5 checksum of image file to upload
                    let error: NSError?
                    (newUpload.md5Sum, error) = fileURL.MD5checksum()
                    print("\(self.debugFormatter.string(from: Date())) > MD5: \(String(describing: newUpload.md5Sum))")
                    if error != nil {
                        // Could not determine the MD5 checksum
                        completionHandler(upload, error)
                        return
                    }
                    completionHandler(newUpload, nil)
                    return
                }
            }

            // We could not copy source into destination, so we try by recompressing the image
            guard var imageProperties = CGImageSourceCopyPropertiesAtIndex(sourceRef, 0, nil) as? [CFString:Any] else {
                // Could not prepare image source
                let error = NSError.init(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                completionHandler(upload, error)
                return
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
                // Could not prepare full resolution image file
                let error = NSError.init(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                completionHandler(upload, error)
                return
            }

            // Determine MD5 checksum of image file to upload
            let error: NSError?
            (newUpload.md5Sum, error) = fileURL.MD5checksum()
            print("\(self.debugFormatter.string(from: Date())) > MD5: \(String(describing: newUpload.md5Sum))")
            if error != nil {
                // Could not determine the MD5 checksum
                completionHandler(newUpload, error)
                return
            }
            completionHandler(newUpload, nil)
            return
        }
        
        // Image container format refused by server and/or compression requested
        // => retrieve UIImage from imageData
        guard let imageData = UIImage(data: fullResImageData) else {
            let error = NSError.init(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
            completionHandler(newUpload, error)
            return
        }
        
        // Convert and/or compress image, check metadata
        exportResizedImage(for: upload,
                           with: fullResImageData, andResized: imageData) { (newUploadProperties, error) in
            // Update upload request
            self.didPrepareImage(for: uploadID, with: newUploadProperties, error)
        }
    }


    // MARK: - Resized Image
    /// Request a resized version of the image stored in the Photo Library
    private func retrieveScaledUIImage(from imageAsset: PHAsset, for upload:UploadProperties,
                                       completionHandler: @escaping (UIImage?, Error?) -> Void) {

        // Options for retrieving image of requested size
        let options = PHImageRequestOptions()
        // Photos processes the image request synchronously unless when the app is active
        options.isSynchronous = isExecutingBackgroundUploadTask
        // Requests the most recent version of the image asset
        options.version = .current
        // Requests the highest-quality image available, regardless of how much time it takes to load.
        options.deliveryMode = .highQualityFormat
        // Photos can download the requested image
        options.isNetworkAccessAllowed = true
        // Requests Photos to resize the image according to user settings
        var size = PHImageManagerMaximumSize
        options.resizeMode = .exact
        if upload.resizeImageOnUpload && Float(upload.photoResize) < 100.0 {
            let scale = CGFloat(upload.photoResize) / 100.0
            size = CGSize(width: CGFloat(imageAsset.pixelWidth) * scale, height: CGFloat(imageAsset.pixelHeight) * scale)
            options.resizeMode = .exact
        }

        // The block Photos calls periodically while downloading the photo
        options.progressHandler = { progress, error, stop, info in
            print(String(format: "    > retrieveUIImageFrom... progress %lf", progress))
        }

        // Requests image…
        var error: Error?
        var fixedImageObject: UIImage?
        PHImageManager.default().requestImage(for: imageAsset, targetSize: size, contentMode: .default,
                                              options: options, resultHandler: { imageObject, info in

            // resultHandler redirected to the main thread by default!
            if self.isExecutingBackgroundUploadTask {
                // Any error?
                if info?[PHImageErrorKey] != nil || (imageObject?.size.width == 0) || (imageObject?.size.height == 0) {
                    completionHandler(nil, info?[PHImageErrorKey] as? Error)
                    return
                }

                // Retrieved UIImage representation for the specified asset
                guard let imageObject = imageObject else {
                    error = NSError.init(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                    completionHandler(nil, error)
                    return
                }
                
                // Fix orientation if needed
                fixedImageObject = imageObject.fixOrientation()

                // Job completed
//                print("\(self.debugFormatter.string(from: Date())) > exits retrieveUIImageFrom in", queueName())
                completionHandler(fixedImageObject, nil)
            } else {
                DispatchQueue(label: "prepareImage").async {
                    // Any error?
                    if info?[PHImageErrorKey] != nil || (imageObject?.size.width == 0) || (imageObject?.size.height == 0) {
                        completionHandler(nil, info?[PHImageErrorKey] as? Error)
                        return
                    }

                    // Retrieved UIImage representation for the specified asset
                    guard let imageObject = imageObject else {
                        error = NSError.init(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                        completionHandler(nil, error)
                        return
                    }
                    
                    // Fix orientation if needed
                    fixedImageObject = imageObject.fixOrientation()

                    // Job completed
//                    print("\(self.debugFormatter.string(from: Date())) > exits retrieveUIImageFrom in", queueName())
                    completionHandler(fixedImageObject, nil)
                }
            }
        })
    }

    /// Export a resized version of the image
    /// - Private metadata are removed if requested by the user
    /// - The format is converted to JPEG if the server does not accept the original format
    private func exportResizedImage(for upload: UploadProperties,
                                    with fullResImageData: Data, andResized resizedImage: UIImage,
                                    completionHandler: @escaping (UploadProperties, Error?) -> Void) {
        print("\(self.debugFormatter.string(from: Date())) > enters exportResizedImage in", queueName())

        // Create CGImage reference from full resolution image data
        guard let sourceFullRef: CGImageSource = CGImageSourceCreateWithData((fullResImageData as CFData), nil) else {
            // Could not prepare image source
            let error = NSError.init(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
            completionHandler(upload, error)
            return
        }

        // Get metadata from image data
        guard var imageProperties = CGImageSourceCopyPropertiesAtIndex(sourceFullRef, 0, nil) as! Dictionary<CFString,Any>? else {
            // Could not retrieve metadata
            let error = NSError.init(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
            completionHandler(upload, error)
            return
        }

        // Strip GPS metadata if user requested it in Settings
        if upload.stripGPSdataOnUpload {
            imageProperties = imageProperties.stripPrivateProperties()
        }

        // Fix image metadata (size, type, etc.)
        imageProperties = imageProperties.fixContents(from: resizedImage) as Dictionary<CFString,Any>

        // Check Piwigo creation date from EXIF metadata if possible
        var newUpload = upload
        if let EXIFdictionary = imageProperties[kCGImagePropertyExifDictionary] as? Dictionary<CFString,Any> {
            let EXIFdateFormatter = DateFormatter()
            EXIFdateFormatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
            if let EXIFdateTimeOriginal = EXIFdictionary[kCGImagePropertyExifDateTimeOriginal] as? String {
                if let creationDate = EXIFdateFormatter.date(from: EXIFdateTimeOriginal),
                   newUpload.creationDate > creationDate {
                    newUpload.creationDate = creationDate
                }
            } else if let EXIFdateTimeDigitized = EXIFdictionary[kCGImagePropertyExifDateTimeDigitized] as? String {
                if let creationDate = EXIFdateFormatter.date(from: EXIFdateTimeDigitized),
                   newUpload.creationDate > creationDate {
                    newUpload.creationDate = creationDate
                }
            }
        }
        
        // Apply compression if user requested it in Settings, or convert to JPEG if necessary
        var imageCompressed: Data? = nil
        let fileExt = (URL(fileURLWithPath: upload.fileName).pathExtension).lowercased()
        if upload.compressImageOnUpload && (CGFloat(upload.photoQuality) < 100.0) {
            // Compress image (only possible in JPEG)
            let compressionQuality: CGFloat = CGFloat(upload.photoQuality) / 100.0
            imageCompressed = resizedImage.jpegData(compressionQuality: compressionQuality)

            // Final image file will be in JPEG format
            newUpload.fileName = URL(fileURLWithPath: upload.fileName).deletingPathExtension().appendingPathExtension("jpg").lastPathComponent
        }
        else if !(upload.serverFileTypes.contains(fileExt)) {
            // Image in unaccepted file format for Piwigo server => convert to JPEG format
            imageCompressed = resizedImage.jpegData(compressionQuality: 1.0)

            // Final image file will be in JPEG format
            newUpload.fileName = URL(fileURLWithPath: upload.fileName).deletingPathExtension().appendingPathExtension("jpg").lastPathComponent
        }

        // If compression failed or imageCompressed is nil, try to use original image
        if imageCompressed == nil {
            imageCompressed = fullResImageData
        }
        
        // Determine MIME type from image data, check file extension
        newUpload.mimeType = "image/jpeg"
        if let type = imageCompressed!.contentType() {
            if type.count > 0  {
                // Adopt determined Mime type
                newUpload.mimeType = type
                // Re-check filename extension if MIME type known
                let fileExt = (URL(fileURLWithPath: newUpload.fileName).pathExtension).lowercased()
                let expectedFileExtension = imageCompressed!.fileExtension()
                if !(fileExt == expectedFileExtension) {
                    newUpload.fileName = URL(fileURLWithPath: upload.fileName).deletingPathExtension().appendingPathExtension(expectedFileExtension ?? "").lastPathComponent
                }
            }
        }

        // File name of final image data to be stored into Piwigo/Uploads directory
        let fileName = upload.localIdentifier.replacingOccurrences(of: "/", with: "-")
        let fileURL = self.applicationUploadsDirectory.appendingPathComponent(fileName)
        
        // Deletes temporary image file if exists (incomplete previous attempt?)
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch {
        }

        // Create CGImage reference from full resolution image data
        guard let sourceRef: CGImageSource = CGImageSourceCreateWithData((imageCompressed! as CFData), nil) else {
            // Could not create source reference
            let error = NSError.init(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
            completionHandler(upload, error)
            return
        }

        // Prepare destination file of same type
        guard let UTI = CGImageSourceGetType(sourceRef),
              let destinationRef = CGImageDestinationCreateWithURL(fileURL as CFURL, UTI, 1, nil) else {
            // Could not prepare image source
            let error = NSError.init(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
            completionHandler(upload, error)
            return
        }

        // Copy source into destination with unavoidable recompression
        CGImageDestinationSetProperties(destinationRef, imageProperties as CFDictionary)
        let nberOfImages = CGImageSourceGetCount(sourceRef)
        for index in 0..<nberOfImages {
            // Add image at index
            CGImageDestinationAddImageFromSource(destinationRef, sourceRef, index, imageProperties as CFDictionary)
        }

        // Save destination
        guard CGImageDestinationFinalize(destinationRef) else {
            // Could not prepare full resolution image file
            let error = NSError.init(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
            completionHandler(upload, error)
            return
        }

        // Determine MD5 checksum of image file to upload
        let error: NSError?
        (newUpload.md5Sum, error) = fileURL.MD5checksum()
        print("\(self.debugFormatter.string(from: Date())) > MD5: \(String(describing: newUpload.md5Sum))")
        if error != nil {
            // Could not determine the MD5 checksum
            completionHandler(upload, error)
            return
        }
        completionHandler(newUpload, nil)
    }
}
