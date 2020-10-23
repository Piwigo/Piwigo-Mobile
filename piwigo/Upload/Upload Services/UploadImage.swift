//
//  UploadImage.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 21/05/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import Photos

class UploadImage: NSObject {
    
    // MARK: - Image preparation
    class
    func prepareImage(for upload: UploadProperties, from imageAsset: PHAsset) -> Void {
        print("\(UploadManager.shared.debugFormatter.string(from: Date())) > prepareImage() in ", queueName())

        // Retrieve UIImage
        let (fixedImageObject, imageError) = retrieveUIImage(from: imageAsset, for: upload)
        if let _ = imageError {
            updateUploadRequestWith(upload, error: imageError)
        }
        guard let imageObject = fixedImageObject else {
            let error = NSError.init(domain: "Piwigo", code: 0, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
            updateUploadRequestWith(upload, error: error)
            return
        }

        // Retrieve image data
        let (fullSizeData, dataError) = retrieveFullSizeImageData(from: imageAsset)
        if let _ = dataError {
            updateUploadRequestWith(upload, error: dataError)
        }
        guard let imageData = fullSizeData else {
            let error = NSError.init(domain: "Piwigo", code: 0, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
            updateUploadRequestWith(upload, error: error)
            return
        }
        
        // Modify image
        modifyImage(for: upload, with: imageData, andObject: imageObject) { (newUpload, error) in
            // Update upload request
            self.updateUploadRequestWith(newUpload, error: error)
        }
    }
    
    class
    func updateUploadRequestWith(_ upload: UploadProperties, error: Error?) {

        // Error?
        if let error = error {
            // Could not prepare image
            let uploadProperties = upload.update(with: .preparingError, error: error.localizedDescription)
            
            // Update request with error description
            print("\(UploadManager.shared.debugFormatter.string(from: Date())) > ", error.localizedDescription)
            UploadManager.shared.uploadsProvider.updateRecord(with: uploadProperties, completionHandler: { _ in
                // Upload ready for transfer
                if UploadManager.shared.isExecutingBackgroundUploadTask {
                    // In background task
                } else {
                    // In foreground, update UI
                    let uploadInfo: [String : Any] = ["localIndentifier" : upload.localIdentifier,
                                                      "stateLabel" : kPiwigoUploadState.preparingError.stateInfo,
                                                      "Error" : error.localizedDescription,
                                                      "progressFraction" : Float(0.0)]
                    DispatchQueue.main.async {
                        // Update UploadQueue cell and button shown in root album (or default album)
                        let name = NSNotification.Name(rawValue: kPiwigoNotificationUploadProgress)
                        NotificationCenter.default.post(name: name, object: nil, userInfo: uploadInfo)
                    }
                    // Consider next image
                    let name = NSNotification.Name(rawValue: UploadManager.shared.kPiwigoNotificationDidPrepareImage)
                    NotificationCenter.default.post(name: name, object: nil, userInfo: nil)
                }
            })
            return
        }

        // Update state of upload
        let uploadProperties = upload.update(with: .prepared, error: "")

        // Update request ready for transfer
        print("\(UploadManager.shared.debugFormatter.string(from: Date())) > prepared file \(uploadProperties.fileName!)")
        UploadManager.shared.uploadsProvider.updateRecord(with: uploadProperties, completionHandler: { _ in
            // Upload ready for transfer
            if UploadManager.shared.isExecutingBackgroundUploadTask {
                // In background task
                UploadManager.shared.transferInBackgroundImage(of: uploadProperties)
            } else {
                // In foreground, update UI
                let uploadInfo: [String : Any] = ["localIndentifier" : upload.localIdentifier,
                                                  "stateLabel" : kPiwigoUploadState.prepared.stateInfo,
                                                  "Error" : "",
                                                  "progressFraction" : Float(0.0)]
                DispatchQueue.main.async {
                    // Update UploadQueue cell and button shown in root album (or default album)
                    let name = NSNotification.Name(rawValue: kPiwigoNotificationUploadProgress)
                    NotificationCenter.default.post(name: name, object: nil, userInfo: uploadInfo)
                }
                // Consider next image
                let name = NSNotification.Name(rawValue: UploadManager.shared.kPiwigoNotificationDidPrepareImage)
                NotificationCenter.default.post(name: name, object: nil, userInfo: nil)
            }
        })
    }

    
    // MARK: - Retrieve UIImage and Image Data
    class
    func retrieveUIImage(from imageAsset: PHAsset, for upload:UploadProperties) -> (UIImage?, Error?) {
        print("\(UploadManager.shared.debugFormatter.string(from: Date())) > retrieveUIImageFrom...")

        // Case of an image…
        let options = PHImageRequestOptions()
        // Does not block the calling thread until image data is ready or an error occurs
        options.isSynchronous = true
        // Requests the most recent version of the image asset
        options.version = .current
        // Requests the highest-quality image available, regardless of how much time it takes to load.
        options.deliveryMode = .highQualityFormat
        // Photos can download the requested video
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
            // Any error?
            if info?[PHImageErrorKey] != nil || (imageObject?.size.width == 0) || (imageObject?.size.height == 0) {
//                print("\(debugFormatter.string(from: Date())) > returned info(\(String(describing: info)))")
                error = info?[PHImageErrorKey] as? Error
                return
            }

            // Retrieved UIImage representation for the specified asset
            if let imageObject = imageObject {
                // Fix orientation if needed
                fixedImageObject = self.fixOrientationOf(imageObject)
                return
            }
            else {
                error = NSError.init(domain: "Piwigo", code: 0, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                return
            }
        })
        return (fixedImageObject, error)
    }

    class
    func retrieveFullSizeImageData(from imageAsset: PHAsset) -> (Data?, Error?) {
        print("\(UploadManager.shared.debugFormatter.string(from: Date())) > retrieveFullSizeAssetDataFromImage...")

        // Case of an image…
        let options = PHImageRequestOptions()
        // Does not block the calling thread until image data is ready or an error occurs
        options.isSynchronous = true
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

        var error: Error?
        var data: Data?
        autoreleasepool {
            if #available(iOS 13.0, *) {
                PHImageManager.default().requestImageDataAndOrientation(for: imageAsset, options: options,
                                                                        resultHandler: { imageData, dataUTI, orientation, info in
                    if info?[PHImageErrorKey] != nil || ((imageData?.count ?? 0) == 0) {
                        error = info?[PHImageErrorKey] as? Error
                    } else {
                        data = imageData
                    }
                })
            } else {
                PHImageManager.default().requestImageData(for: imageAsset, options: options,
                                                          resultHandler: { imageData, dataUTI, orientation, info in
                    if info?[PHImageErrorKey] != nil || ((imageData?.count ?? 0) == 0) {
                        error = info?[PHImageErrorKey] as? Error
                    } else {
                        data = imageData
                    }
                })
            }
        }
        return (data, error)
    }

    
    // MARK: - Modify Metadata
    
    class
    func modifyImage(for upload: UploadProperties,
                             with originalData: Data, andObject originalObject: UIImage,
                             completionHandler: @escaping (UploadProperties, Error?) -> Void) {
        print("\(UploadManager.shared.debugFormatter.string(from: Date())) > modifyImage...")

        // Create CGI reference from image data (to retrieve complete metadata)
        guard let source: CGImageSource = CGImageSourceCreateWithData((originalData as CFData), nil) else {
            // Could not prepare image source
            let error = NSError.init(domain: "Piwigo", code: 0, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
            completionHandler(upload, error)
            return
        }

        // Get metadata from image data
        guard var imageMetadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as Dictionary? else {
            // Could not retrieve metadata
            let error = NSError.init(domain: "Piwigo", code: 0, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
            completionHandler(upload, error)
            return
        }

        // Strip GPS metadata if user requested it in Settings
        if upload.stripGPSdataOnUpload {
            imageMetadata = ImageService.stripGPSdata(fromImageMetadata: imageMetadata)! as Dictionary<NSObject, AnyObject>
        }

        // Fix image metadata (size, type, etc.)
        imageMetadata = ImageService.fixMetadata(imageMetadata, of: originalObject)! as Dictionary<NSObject, AnyObject>

        // Apply compression if user requested it in Settings, or convert to JPEG if necessary
        var imageCompressed: Data? = nil
        var newUpload = upload
        let fileExt = (URL(fileURLWithPath: upload.fileName!).pathExtension).lowercased()
        if upload.compressImageOnUpload && (CGFloat(upload.photoQuality) < 100.0) {
            // Compress image (only possible in JPEG)
            let compressionQuality: CGFloat = CGFloat(upload.photoQuality) / 100.0
            imageCompressed = originalObject.jpegData(compressionQuality: compressionQuality)

            // Final image file will be in JPEG format
            newUpload.fileName = URL(fileURLWithPath: upload.fileName!).deletingPathExtension().appendingPathExtension("JPG").lastPathComponent
        }
        else if !(Model.sharedInstance().uploadFileTypes.contains(fileExt)) {
            // Image in unaccepted file format for Piwigo server => convert to JPEG format
            imageCompressed = originalObject.jpegData(compressionQuality: 1.0)

            // Final image file will be in JPEG format
            newUpload.fileName = URL(fileURLWithPath: upload.fileName!).deletingPathExtension().appendingPathExtension("JPG").lastPathComponent
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
                    let error = NSError.init(domain: "Piwigo", code: 0, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
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
        let fileURL = UploadManager.shared.applicationUploadsDirectory.appendingPathComponent(fileName)
        
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
            md5Checksum = UploadManager.shared.MD5(data: imageData)
            #endif
        } else {
            // Fallback on earlier versions
            md5Checksum = UploadManager.shared.oldMD5(data: imageData)
        }
        newUpload.md5Sum = md5Checksum
        print("\(UploadManager.shared.debugFormatter.string(from: Date())) > MD5: \(String(describing: md5Checksum))")

        completionHandler(newUpload, nil)
    }


    // MARK: - Fix Image Orientation
    
    class
    func fixOrientationOf(_ image: UIImage) -> UIImage {

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

    class
    func contentType(forImageData data: Data?) -> String? {
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

    class
    func fileExtension(forImageData data: Data?) -> String? {
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
    class func bmpSignature() -> [UInt8] {
        return "BM".map { $0.asciiValue! }
    }
    
    // https://en.wikipedia.org/wiki/GIF
    class func gif87aSignature() -> [UInt8] {
        return "GIF87a".map { $0.asciiValue! }
    }
    class func gif89aSignature() -> [UInt8] {
        return "GIF89a".map { $0.asciiValue! }
    }
    
    // https://en.wikipedia.org/wiki/High_Efficiency_Image_File_Format
    class func heicSignature() -> [UInt8] {
        return [0x00, 0x00, 0x00, 0x18] + "ftypheic".map { $0.asciiValue! }
    }
    
    // https://en.wikipedia.org/wiki/ILBM
    class func iffSignature() -> [UInt8] {
        return "FORM".map { $0.asciiValue! }
    }
    
    // https://en.wikipedia.org/wiki/JPEG
    class func jpgSignature() -> [UInt8] {
        return [0xff, 0xd8, 0xff]
    }
    
    // https://en.wikipedia.org/wiki/JPEG_2000
    class func jp2Signature() -> [UInt8] {
        return [0x00, 0x00, 0x00, 0x0c, 0x6a, 0x50, 0x20, 0x20, 0x0d, 0x0a, 0x87, 0x0a]
    }
    
    // https://en.wikipedia.org/wiki/Portable_Network_Graphics
    class func pngSignature() -> [UInt8] {
        return [0x89] + "PNG".map { $0.asciiValue! } + [0x0d, 0x0a, 0x1a, 0x0a]
    }
    
    // https://en.wikipedia.org/wiki/Adobe_Photoshop#File_format
    class func psdSignature() -> [UInt8] {
        return "8BPS".map { $0.asciiValue! }
    }
    
    // https://en.wikipedia.org/wiki/TIFF
    class func tif_iiSignature() -> [UInt8] {
        return "II".map { $0.asciiValue! } + [0x2a, 0x00]
    }
    class func tif_mmSignature() -> [UInt8] {
        return "MM".map { $0.asciiValue! } + [0x00, 0x2a]
    }
    
    // https://en.wikipedia.org/wiki/WebP
    class func webpSignature() -> [UInt8] {
        return "RIFF".map { $0.asciiValue! }
    }
    
    // https://en.wikipedia.org/wiki/ICO_(file_format)
    class func win_icoSignature() -> [UInt8] {
        return [0x00, 0x00, 0x01, 0x00]
    }
    class func win_curSignature() -> [UInt8] {
        return [0x00, 0x00, 0x02, 0x00]
    }
}
