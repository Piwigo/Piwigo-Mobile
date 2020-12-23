//
//  UploadImage.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 21/05/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import Photos

extension UploadManager {
    
    // MARK: - Image preparation
    /// Case of an image from the pasteboard
    func prepareImage(for uploadID: NSManagedObjectID,
                      with uploadProperties: UploadProperties, atURL fileURL: URL) -> Void {
        
        // Retrieve image data from file stored in the Uploads directory
        var imageData: Data = Data()
        do {
            try imageData = NSData (contentsOf: fileURL) as Data
        }
        catch let error as NSError {
            // Could not find the file to upload!
            print(error.localizedDescription)
            let error = NSError.init(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
            self.didPrepareImage(for: uploadID, with: uploadProperties, error)
            return
        }
        
        // Retrieve UIImage from imageData
        guard let imageObject = UIImage(data: imageData) else {
            let error = NSError.init(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
            self.didPrepareImage(for: uploadID, with: uploadProperties, error)
            return
        }

        // Modify image
        self.modifyImage(for: uploadProperties, with: imageData, andObject: imageObject) { (newUploadProperties, error) in
            // Update upload request
            self.didPrepareImage(for: uploadID, with: newUploadProperties, error)
            return
        }
    }
    
    /// Case of an image from the Photo Library
    func prepareImage(for uploadID: NSManagedObjectID,
                      with uploadProperties: UploadProperties, asset imageAsset: PHAsset) -> Void {

        // Retrieve UIImage
        self.retrieveUIImage(from: imageAsset, for: uploadProperties) { (fixedImageObject, imageError) in
            if let imageError = imageError {
                self.didPrepareImage(for: uploadID, with: uploadProperties, imageError)
                return
            }
            guard let imageObject = fixedImageObject else {
                let error = NSError.init(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                self.didPrepareImage(for: uploadID, with: uploadProperties, error)
                return
            }

            // Retrieve image data
            self.retrieveFullSizeImageData(from: imageAsset) { (fullSizeData, dataError) in
                if let _ = dataError {
                    self.didPrepareImage(for: uploadID, with: uploadProperties, dataError)
                    return
                }
                guard let imageData = fullSizeData else {
                    let error = NSError.init(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                    self.didPrepareImage(for: uploadID, with: uploadProperties, error)
                    return
                }

                // Modify image
                self.modifyImage(for: uploadProperties, with: imageData, andObject: imageObject) { (newUploadProperties, error) in
                    // Update upload request
                    self.didPrepareImage(for: uploadID, with: newUploadProperties, error)
                    return
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
        updateCell(with: newProperties.localIdentifier, stateLabel: newProperties.stateLabel)

        // Update state of upload request
        print("\(debugFormatter.string(from: Date())) > prepared \(uploadID) i.e. \(properties.fileName!) \(errorMsg)")
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

    
    // MARK: - Retrieve UIImage and Image Data
    private func retrieveUIImage(from imageAsset: PHAsset, for upload:UploadProperties,
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
                fixedImageObject = self.fixOrientationOf(imageObject)

                // Job completed
//                print("\(self.debugFormatter.string(from: Date())) > exits retrieveUIImageFrom in", queueName())
                completionHandler(fixedImageObject, nil)
                return
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
                    fixedImageObject = self.fixOrientationOf(imageObject)

                    // Job completed
//                    print("\(self.debugFormatter.string(from: Date())) > exits retrieveUIImageFrom in", queueName())
                    completionHandler(fixedImageObject, nil)
                    return
                }
            }
        })
    }

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

    
    // MARK: - Modify Metadata
    
    private func modifyImage(for upload: UploadProperties,
                     with originalData: Data, andObject originalObject: UIImage,
                     completionHandler: @escaping (UploadProperties, Error?) -> Void) {
//        print("\(self.debugFormatter.string(from: Date())) > enters modifyImage in", queueName())

        // Create CGI reference from image data (to retrieve complete metadata)
        guard let source: CGImageSource = CGImageSourceCreateWithData((originalData as CFData), nil) else {
            // Could not prepare image source
            let error = NSError.init(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
            completionHandler(upload, error)
            return
        }

        // Get metadata from image data
        guard var imageMetadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as Dictionary? else {
            // Could not retrieve metadata
            let error = NSError.init(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
            completionHandler(upload, error)
            return
        }

        // Strip GPS metadata if user requested it in Settings
        if upload.stripGPSdataOnUpload {
            imageMetadata = ImageService.stripGPSdata(fromImageMetadata: imageMetadata)! as Dictionary<NSObject, AnyObject>
        }

        // Fix image metadata (size, type, etc.)
        imageMetadata = ImageService.fixMetadata(imageMetadata, of: originalObject)! as Dictionary<NSObject, AnyObject>

        // Check Piwigo creation date from EXIF metadata if possible
        var newUpload = upload
        if let EXIFdictionary = imageMetadata[kCGImagePropertyExifDictionary] {
            let EXIFdateFormatter = DateFormatter()
            EXIFdateFormatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
            if let EXIFdateTimeOriginal = EXIFdictionary[kCGImagePropertyExifDateTimeOriginal] as? String {
                if let creationDate = EXIFdateFormatter.date(from: EXIFdateTimeOriginal),
                   newUpload.creationDate ?? Date() > creationDate {
                    newUpload.creationDate = creationDate
                }
            } else if let EXIFdateTimeDigitized = EXIFdictionary[kCGImagePropertyExifDateTimeDigitized] as? String {
                if let creationDate = EXIFdateFormatter.date(from: EXIFdateTimeDigitized),
                   newUpload.creationDate ?? Date() > creationDate {
                    newUpload.creationDate = creationDate
                }
            }
        }
        
        // Apply compression if user requested it in Settings, or convert to JPEG if necessary
        var imageCompressed: Data? = nil
        let fileExt = (URL(fileURLWithPath: upload.fileName!).pathExtension).lowercased()
        if upload.compressImageOnUpload && (CGFloat(upload.photoQuality) < 100.0) {
            // Compress image (only possible in JPEG)
            let compressionQuality: CGFloat = CGFloat(upload.photoQuality) / 100.0
            imageCompressed = originalObject.jpegData(compressionQuality: compressionQuality)

            // Final image file will be in JPEG format
            newUpload.fileName = URL(fileURLWithPath: upload.fileName!).deletingPathExtension().appendingPathExtension("jpg").lastPathComponent
        }
        else if !(upload.serverFileTypes.contains(fileExt)) {
            // Image in unaccepted file format for Piwigo server => convert to JPEG format
            imageCompressed = originalObject.jpegData(compressionQuality: 1.0)

            // Final image file will be in JPEG format
            newUpload.fileName = URL(fileURLWithPath: upload.fileName!).deletingPathExtension().appendingPathExtension("jpg").lastPathComponent
        }

        // If compression failed or imageCompressed is nil, try to use original image
        if imageCompressed == nil {
            let UTI: CFString? = CGImageSourceGetType(source)
            let imageDataRef = CFDataCreateMutable(nil, CFIndex(0))
            var destination: CGImageDestination? = nil
            if let imageDataRef = imageDataRef, let UTI = UTI {
                destination = CGImageDestinationCreateWithData(imageDataRef, UTI, 1, nil)
            }
            if let destination = destination, let CGImage = originalObject.cgImage {
                CGImageDestinationAddImage(destination, CGImage, nil)
            }
            if let destination = destination {
                if !CGImageDestinationFinalize(destination) {
                    let error = NSError.init(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                    completionHandler(upload, error)
                    return
                }
            }
            imageCompressed = imageDataRef as Data?
        }

        // Add metadata to final image
        let imageData = ImageService.writeMetadata(imageMetadata, intoImageData: imageCompressed)
        imageCompressed = nil

        // Try to determine MIME type from image data
        newUpload.mimeType = "image/jpeg"
        if let type = contentType(forImageData: imageData) {
            if type.count > 0  {
                // Adopt determined Mime type
                newUpload.mimeType = type
                // Re-check filename extension if MIME type known
                let fileExt = (URL(fileURLWithPath: newUpload.fileName ?? "").pathExtension).lowercased()
                let expectedFileExtension = fileExtension(forImageData: imageData)
                if !(fileExt == expectedFileExtension) {
                    newUpload.fileName = URL(fileURLWithPath: upload.fileName ?? "file").deletingPathExtension().appendingPathExtension(expectedFileExtension ?? "").lastPathComponent
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

        // Store final image data into Piwigo/Uploads directory
        do {
            try imageData?.write(to: fileURL)
        } catch let error as NSError {
            completionHandler(newUpload, error)
            return
        }
        
        // Determine MD5 checksum of image file to upload
        var md5Checksum: String? = ""
        if #available(iOS 13.0, *) {
            #if canImport(CryptoKit)        // Requires iOS 13
            md5Checksum = self.MD5(data: imageData)
            #endif
        } else {
            // Fallback on earlier versions
            md5Checksum = self.oldMD5(data: imageData)
        }
        newUpload.md5Sum = md5Checksum
        print("\(self.debugFormatter.string(from: Date())) > MD5: \(String(describing: md5Checksum)) | \(String(describing: newUpload.fileName))")
        completionHandler(newUpload, nil)
    }


    // MARK: - Fix Image Orientation
    
    private func fixOrientationOf(_ image: UIImage) -> UIImage {

        // No-op if the orientation is already correct
        if image.imageOrientation == .up {
            return image
        }

        // We need to calculate the proper transformation to make the image upright.
        // We do it in 2 steps: Rotate if Left/Right/Down, and then flip if Mirrored.
        var transform: CGAffineTransform = .identity

        switch image.imageOrientation {
            case .down, .downMirrored:
                transform = transform.translatedBy(x: image.size.width, y: image.size.height)
                transform = transform.rotated(by: .pi)
            case .left, .leftMirrored:
                transform = transform.translatedBy(x: image.size.width, y: 0)
                transform = transform.rotated(by: .pi / 2)
            case .right, .rightMirrored:
                transform = transform.translatedBy(x: 0, y: image.size.height)
                transform = transform.rotated(by: -.pi / 2)
            case .up, .upMirrored:
                break
            @unknown default:
                break
        }

        switch image.imageOrientation {
            case .upMirrored, .downMirrored:
                transform = transform.translatedBy(x: image.size.width, y: 0)
                transform = transform.scaledBy(x: -1, y: 1)
            case .leftMirrored, .rightMirrored:
                transform = transform.translatedBy(x: image.size.height, y: 0)
                transform = transform.scaledBy(x: -1, y: 1)
            case .up, .down, .left, .right:
                break
            @unknown default:
                break
        }

        // Now we draw the underlying CGImage into a new context,
        // applying the transform calculated above.
        let ctx = CGContext(data: nil, width: Int(image.size.width), height: Int(image.size.height),
                            bitsPerComponent: image.cgImage!.bitsPerComponent, bytesPerRow: 0,
                            space: image.cgImage!.colorSpace!, bitmapInfo: image.cgImage!.bitmapInfo.rawValue)
        ctx?.concatenate(transform)
        switch image.imageOrientation {
            case .left, .leftMirrored, .right, .rightMirrored:
                // Grr...
                ctx?.draw(image.cgImage!, in: CGRect(x: 0, y: 0, width: image.size.height , height: image.size.width ))
            default:
                ctx?.draw(image.cgImage!, in: CGRect(x: 0, y: 0, width: image.size.width , height: image.size.height ))
        }

        // And now we just create a new UIImage from the drawing context
        let cgimg = ctx?.makeImage()
        var img: UIImage? = nil
        if let cgimg = cgimg {
            img = UIImage(cgImage: cgimg)
        }
        return img!
    }


    // MARK: - MIME type and file extension sniffing

    private func contentType(forImageData data: Data?) -> String? {
        var bytes: [UInt8] = Array.init(repeating: UInt8(0), count: 12)
        (data! as NSData).getBytes(&bytes, length: 12)

        var jpg = jpgSignature()
        if memcmp(bytes, &jpg, jpg.count) == 0 { return "image/jpeg" }
        
        var heic = heicSignature()
        if memcmp(bytes, &heic, heic.count) == 0 { return "image/heic" }
        
        var png = pngSignature()
        if memcmp(bytes, &png, png.count) == 0 { return "image/png" }
        
        var gif87a = gif87aSignature()
        var gif89a = gif89aSignature()
        if memcmp(bytes, &gif87a, gif87a.count) == 0 ||
            memcmp(bytes, &gif89a, gif89a.count) == 0 { return "image/gif" }
        
        var bmp = bmpSignature()
        if memcmp(bytes, &bmp, bmp.count) == 0 { return "image/x-ms-bmp" }
        
        var psd = psdSignature()
        if memcmp(bytes, &psd, psd.count) == 0 { return "image/vnd.adobe.photoshop" }
        
        var iff = iffSignature()
        if memcmp(bytes, &iff, iff.count) == 0 { return "image/iff" }
        
        var webp = webpSignature()
        if memcmp(bytes, &webp, webp.count) == 0 { return "image/webp" }
        
        var win_ico = win_icoSignature()
        var win_cur = win_curSignature()
        if memcmp(bytes, &win_ico, win_ico.count) == 0 ||
            memcmp(bytes, &win_cur, win_cur.count) == 0 { return "image/x-icon" }
        
        var tif_ii = tif_iiSignature()
        var tif_mm = tif_mmSignature()
        if memcmp(bytes, &tif_ii, tif_ii.count) == 0 ||
            memcmp(bytes, &tif_mm, tif_mm.count) == 0 { return "image/tiff" }
        
        var jp2 = jp2Signature()
        if memcmp(bytes, &jp2, jp2.count) == 0 { return "image/jp2" }
        
        return nil
    }

    private func fileExtension(forImageData data: Data?) -> String? {
        var bytes: [UInt8] = Array.init(repeating: UInt8(0), count: 12)
        (data! as NSData).getBytes(&bytes, length: 12)

        var jpg = jpgSignature()
        if memcmp(bytes, &jpg, jpg.count) == 0 { return "jpg" }
        
        var heic = heicSignature()
        if memcmp(bytes, &heic, heic.count) == 0 { return "heic" }

        var png = pngSignature()
        if memcmp(bytes, &png, png.count) == 0 { return "png" }
        
        var gif87a = gif87aSignature()
        var gif89a = gif89aSignature()
        if memcmp(bytes, &gif87a, gif87a.count) == 0 ||
            memcmp(bytes, &gif89a, gif89a.count) == 0 { return "gif" }
        
        var bmp = bmpSignature()
        if memcmp(bytes, &bmp, bmp.count) == 0 { return "bmp" }

        var psd = psdSignature()
        if memcmp(bytes, &psd, psd.count) == 0 { return "psd" }
        
        var iff = iffSignature()
        if memcmp(bytes, &iff, iff.count) == 0 { return "iff" }
        
        var webp = webpSignature()
        if memcmp(bytes, &webp, webp.count) == 0 { return "webp" }

        var win_ico = win_icoSignature()
        if memcmp(bytes, &win_ico, win_ico.count) == 0 { return "ico" }

        var win_cur = win_curSignature()
        if memcmp(bytes, &win_cur, win_cur.count) == 0 { return "cur" }
        
        var tif_ii = tif_iiSignature()
        var tif_mm = tif_mmSignature()
        if memcmp(bytes, &tif_ii, tif_ii.count) == 0 ||
            memcmp(bytes, &tif_mm, tif_mm.count) == 0 { return "tif" }
        
        var jp2 = jp2Signature()
        if memcmp(bytes, &jp2, jp2.count) == 0 { return "jp2" }
        
        return nil
    }


    // MARK: - Image Formats
    // See https://en.wikipedia.org/wiki/List_of_file_signatures
    // https://mimesniff.spec.whatwg.org/#sniffing-in-an-image-context

    // https://en.wikipedia.org/wiki/BMP_file_format
    private func bmpSignature() -> [UInt8] {
        return "BM".map { $0.asciiValue! }
    }
    
    // https://en.wikipedia.org/wiki/GIF
    private func gif87aSignature() -> [UInt8] {
        return "GIF87a".map { $0.asciiValue! }
    }
    private func gif89aSignature() -> [UInt8] {
        return "GIF89a".map { $0.asciiValue! }
    }
    
    // https://en.wikipedia.org/wiki/High_Efficiency_Image_File_Format
    private func heicSignature() -> [UInt8] {
        return [0x00, 0x00, 0x00, 0x18] + "ftypheic".map { $0.asciiValue! }
    }
    
    // https://en.wikipedia.org/wiki/ILBM
    private func iffSignature() -> [UInt8] {
        return "FORM".map { $0.asciiValue! }
    }
    
    // https://en.wikipedia.org/wiki/JPEG
    private func jpgSignature() -> [UInt8] {
        return [0xff, 0xd8, 0xff]
    }
    
    // https://en.wikipedia.org/wiki/JPEG_2000
    private func jp2Signature() -> [UInt8] {
        return [0x00, 0x00, 0x00, 0x0c, 0x6a, 0x50, 0x20, 0x20, 0x0d, 0x0a, 0x87, 0x0a]
    }
    
    // https://en.wikipedia.org/wiki/Portable_Network_Graphics
    private func pngSignature() -> [UInt8] {
        return [0x89] + "PNG".map { $0.asciiValue! } + [0x0d, 0x0a, 0x1a, 0x0a]
    }
    
    // https://en.wikipedia.org/wiki/Adobe_Photoshop#File_format
    private func psdSignature() -> [UInt8] {
        return "8BPS".map { $0.asciiValue! }
    }
    
    // https://en.wikipedia.org/wiki/TIFF
    private func tif_iiSignature() -> [UInt8] {
        return "II".map { $0.asciiValue! } + [0x2a, 0x00]
    }
    private func tif_mmSignature() -> [UInt8] {
        return "MM".map { $0.asciiValue! } + [0x00, 0x2a]
    }
    
    // https://en.wikipedia.org/wiki/WebP
    private func webpSignature() -> [UInt8] {
        return "RIFF".map { $0.asciiValue! }
    }
    
    // https://en.wikipedia.org/wiki/ICO_(file_format)
    private func win_icoSignature() -> [UInt8] {
        return [0x00, 0x00, 0x01, 0x00]
    }
    private func win_curSignature() -> [UInt8] {
        return [0x00, 0x00, 0x02, 0x00]
    }
}
