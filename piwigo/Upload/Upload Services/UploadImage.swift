//
//  UploadImage.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 21/05/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import Photos
import var CommonCrypto.CC_MD5_DIGEST_LENGTH
import func CommonCrypto.CC_MD5
import typealias CommonCrypto.CC_LONG

#if canImport(CryptoKit)
import CryptoKit        // Requires iOS 13
#endif

extension UploadManager {

    // MARK: - Image preparation
    func prepareImage(for upload: UploadProperties, from imageAsset: PHAsset) -> Void {
        
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
        modifyImage(for: upload, with: imageData, andObject: imageObject) { [unowned self] (newUpload, error) in
            // Update upload request
            self.updateUploadRequestWith(newUpload, error: error)
        }
    }
    
    private func updateUploadRequestWith(_ upload: UploadProperties, error: Error?) {

        // Error?
        if let error = error {
            // Could not prepare image
            let uploadProperties = upload.update(with: .preparingError, error: error.localizedDescription)
            
            // Update request with error description
            print("    >", error.localizedDescription)
            uploadsProvider.updateRecord(with: uploadProperties, completionHandler: { [unowned self] _ in
                // Consider next image
                self.setIsPreparing(status: false)
            })
            return
        }

        // Update state of upload
        let uploadProperties = upload.update(with: .prepared, error: "")

        // Update request ready for transfer
        print("    > prepared file \(uploadProperties.fileName!)")
        uploadsProvider.updateRecord(with: uploadProperties, completionHandler: { [unowned self] _ in
            // Upload ready for transfer
            self.setIsPreparing(status: false)
        })
    }

    // MARK: - Retrieve UIImage and Image Data
    
    private func retrieveUIImage(from imageAsset: PHAsset, for upload:UploadProperties) -> (UIImage?, Error?) {
        print("    > retrieveUIImageFrom...")

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
//                print("     returned info(\(String(describing: info)))")
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

    private func retrieveFullSizeImageData(from imageAsset: PHAsset) -> (Data?, Error?) {
        print("    > retrieveFullSizeAssetDataFromImage...")

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
    
    private func modifyImage(for upload: UploadProperties,
                             with originalData: Data, andObject originalObject: UIImage,
                             completionHandler: @escaping (UploadProperties, Error?) -> Void) {
        print("    > modifyImage...")

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
        let fileName = upload.localIdentifier.replacingOccurrences(of: "/", with: "-") + "-" + newUpload.fileName!
        let fileURL = applicationUploadsDirectory.appendingPathComponent(fileName)
        
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
            md5Checksum = MD5(data: imageData)
            #endif
        } else {
            // Fallback on earlier versions
            md5Checksum = oldMD5(data: imageData)
        }
        print("   > Checksum: \(md5Checksum ?? "No MD5 Checksum!")")
        newUpload.md5Sum = md5Checksum

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

        if memcmp(bytes, &jpg, jpg.count) == 0 {
            return "image/jpeg"
        } else if memcmp(bytes, &heic, heic.count) == 0 {
            return "image/heic"
        } else if memcmp(bytes, &png, png.count) == 0 {
            return "image/png"
        } else if memcmp(bytes, &gif87a, gif87a.count) == 0 || memcmp(bytes, &gif89a, gif89a.count) == 0 {
            return "image/gif"
        } else if memcmp(bytes, &bmp, bmp.count) == 0 {
            return "image/x-ms-bmp"
        } else if memcmp(bytes, &psd, psd.count) == 0 {
            return "image/vnd.adobe.photoshop"
        } else if memcmp(bytes, &iff, iff.count) == 0 {
            return "image/iff"
        } else if memcmp(bytes, &webp, webp.count) == 0 {
            return "image/webp"
        } else if memcmp(bytes, &win_ico, win_ico.count) == 0 || memcmp(bytes, &win_cur, win_cur.count) == 0 {
            return "image/x-icon"
        } else if memcmp(bytes, &tif_ii, tif_ii.count) == 0 || memcmp(bytes, &tif_mm, tif_mm.count) == 0 {
            return "image/tiff"
        } else if memcmp(bytes, &jp2, jp2.count) == 0 {
            return "image/jp2"
        }
        return nil
    }

    private func fileExtension(forImageData data: Data?) -> String? {
        var bytes: [UInt8] = Array.init(repeating: UInt8(0), count: 12)
        (data! as NSData).getBytes(&bytes, length: 12)

        if memcmp(bytes, &jpg, jpg.count) == 0 {
            return "jpg"
        } else if memcmp(bytes, &heic, heic.count) == 0 {
            return "heic"
        } else if memcmp(bytes, &png, png.count) == 0 {
            return "png"
        } else if memcmp(bytes, &gif87a, gif87a.count) == 0 || memcmp(bytes, &gif89a, gif89a.count) == 0 {
            return "gif"
        } else if memcmp(bytes, &bmp, bmp.count) == 0 {
            return "bmp"
        } else if memcmp(bytes, &psd, psd.count) == 0 {
            return "psd"
        } else if memcmp(bytes, &iff, iff.count) == 0 {
            return "iff"
        } else if memcmp(bytes, &webp, webp.count) == 0 {
            return "webp"
        } else if memcmp(bytes, &win_ico, win_ico.count) == 0 {
            return "ico"
        } else if memcmp(bytes, &win_cur, win_cur.count) == 0 {
            return "cur"
        } else if memcmp(bytes, &tif_ii, tif_ii.count) == 0 || memcmp(bytes, &tif_mm, tif_mm.count) == 0 {
            return "tif"
        } else if memcmp(bytes, &jp2, jp2.count) == 0 {
            return "jp2"
        }
        return nil
    }

    // MARK: - MD5 Checksum
    #if canImport(CryptoKit)        // Requires iOS 13
    @available(iOS 13.0, *)
    func MD5(data: Data?) -> String {
        let digest = Insecure.MD5.hash(data: data ?? Data())
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
    #endif

    func oldMD5(data: Data?) -> String {
        let length = Int(CC_MD5_DIGEST_LENGTH)
        let messageData = data ?? Data()
        var digestData = Data(count: length)

        _ = digestData.withUnsafeMutableBytes { digestBytes -> UInt8 in
                messageData.withUnsafeBytes { messageBytes -> UInt8 in
                if let messageBytesBaseAddress = messageBytes.baseAddress,
                    let digestBytesBlindMemory = digestBytes.bindMemory(to: UInt8.self).baseAddress {
                    let messageLength = CC_LONG(messageData.count)
                    CC_MD5(messageBytesBaseAddress, messageLength, digestBytesBlindMemory)
                }
                return 0
            }
        }
        return digestData.map { String(format: "%02hhx", $0) }.joined()
    }
}
