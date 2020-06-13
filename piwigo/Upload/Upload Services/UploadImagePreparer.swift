//
//  UploadImagePreparer.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 21/05/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import Photos

class UploadImagePreparer {

    func prepare(from imageAsset: PHAsset, for upload: UploadProperties,
                      completionHandler: @escaping (_ updatedUpload: UploadProperties?, _ mimitype: String?, _ imageData: Data?, Error?) -> Void) {
        // Retrieve UIImage
        retrieveUIImageFrom(imageAsset: imageAsset) { (fixedImageObject, error) in
            // Error?
            if let error = error {
                completionHandler(upload, "", nil, error)
                return
            }

            // Valid UIImage with fixed orientation?
            guard let imageObject = fixedImageObject else {
                // define error !!!!
                completionHandler(upload, "", nil, error)
                return
            }

            // Retrieve image data
            self.retrieveFullSizeImageDataFrom(imageAsset: imageAsset) { (imageData, error) in
                // Error?
                if let error = error {
                    completionHandler(upload, "", imageData, error)
                    return
                }
                
                // Valid image data?
                guard let imageData = imageData else {
                    // define error !!!!
                    completionHandler(upload, "", nil, error)
                    return
                }
                
                // Modify image
                self.modifyImage(upload, with: imageData, andObject: imageObject) { (updatedUpload, mimeType, updatedImageData, error) in
                    // Error?
                    if let error = error {
                        completionHandler(upload, mimeType, imageData, error)
                        return
                    } else {
                        completionHandler(updatedUpload, mimeType, updatedImageData, nil)
                    }
                }
            }
        }
    }

    // MARK: - Retrieve UIImage and Image Data
    
    private func retrieveUIImageFrom(imageAsset: PHAsset, completionHandler: @escaping (UIImage?, Error?) -> Void) {
        print("•••> retrieveUIImageFrom...")

        // Case of an image…
        let options = PHImageRequestOptions()
        // Does not block the calling thread until image data is ready or an error occurs
        options.isSynchronous = false
        // Requests the most recent version of the image asset
        options.version = PHImageRequestOptionsVersion.current
        // Requests the highest-quality image available, regardless of how much time it takes to load.
        options.deliveryMode = .highQualityFormat
        // Photos can download the requested video from iCloud
        options.isNetworkAccessAllowed = true
        // Requests Photos to resize the image according to user settings
        var size = PHImageManagerMaximumSize
        options.resizeMode = .exact
        if Model.sharedInstance().resizeImageOnUpload && Float(Model.sharedInstance().photoResize) < 100.0 {
            let scale = CGFloat(Model.sharedInstance().photoResize) / 100.0
            size = CGSize(width: CGFloat(imageAsset.pixelWidth) * scale, height: CGFloat(imageAsset.pixelHeight) * scale)
            options.resizeMode = .exact
        }

        // The block Photos calls periodically while downloading the photo
        options.progressHandler = { progress, error, stop, info in
            print(String(format: "downloading Photo — progress %lf", progress))
        }

        // Requests image…
        PHImageManager.default().requestImage(for: imageAsset, targetSize: size, contentMode: .default,
                                              options: options, resultHandler: { imageObject, info in
            // Any error?
            if info?[PHImageErrorKey] != nil || (imageObject?.size.width == 0) || (imageObject?.size.height == 0) {
                print("     returned info(\(String(describing: info)))")
                let error = info?[PHImageErrorKey] as? Error
                completionHandler(nil, error)
                return
                // Inform user and propose to cancel or continue
//                self.showError(withTitle: NSLocalizedString("imageUploadError_title", comment: "Image Upload Error"), andMessage: NSLocalizedString("imageUploadError_iCloud", comment: "Could not retrieve image. Error: \(error?.localizedDescription ?? "")"), forRetrying: true, withImage: image)
            }

            // Retrieved UIImage representation for the specified asset
            if let imageObject = imageObject {
                // Fix orientation if needed
                let fixedImageObject = self.fixOrientationOf(imageObject)
                // Expected resource available
                completionHandler(fixedImageObject, nil)
                return
            }
            else {
                completionHandler(imageObject, nil)
            }
        })
        completionHandler(nil, nil)
    }

    private func retrieveFullSizeImageDataFrom(imageAsset: PHAsset, completionHandler: @escaping (Data?, Error?) -> Void) {
        print("•••> retrieveFullSizeAssetDataFromImage...")

        // Case of an image…
        let options = PHImageRequestOptions()
        // Does not block the calling thread until image data is ready or an error occurs
        options.isSynchronous = false
        // Requests the most recent version of the image asset
        options.version = PHImageRequestOptionsVersion.current
        // Requests a fast-loading image, possibly sacrificing image quality.
        options.deliveryMode = .fastFormat
        // Photos can download the requested video from iCloud
        options.isNetworkAccessAllowed = true

        // The block Photos calls periodically while downloading the photo
        options.progressHandler = { progress, error, stop, info in
            print(String(format: "downloading Photo from iCloud — progress %lf", progress))
        }

        autoreleasepool {
            if #available(iOS 13.0, *) {
                PHImageManager.default().requestImageDataAndOrientation(for: imageAsset, options: options,
                                                                        resultHandler: { imageData, dataUTI, orientation, info in
                    if info?[PHImageErrorKey] != nil || ((imageData?.count ?? 0) == 0) {
                        print("     returned info(\(String(describing: info)))")
                        let error = info?[PHImageErrorKey] as? Error
                        completionHandler(imageData, error)
                        // Inform user and propose to cancel or continue
//                        self.showError(withTitle: NSLocalizedString("imageUploadError_title", comment: "Image Upload Error"), andMessage: NSLocalizedString("imageUploadError_iCloud", comment: "Could not retrieve image. Error: \(error?.localizedDescription ?? "")"), forRetrying: true, withImage: image)
                    } else {
                        // Expected resource available
                        completionHandler(imageData, nil)
                    }
                })
            } else {
                PHImageManager.default().requestImageData(for: imageAsset, options: options,
                                                          resultHandler: { imageData, dataUTI, orientation, info in
                    if info?[PHImageErrorKey] != nil || ((imageData?.count ?? 0) == 0) {
                        let error = info?[PHImageErrorKey] as? Error
                        completionHandler(imageData, error)
                        // Inform user and propose to cancel or continue
//                        self.showError(withTitle: NSLocalizedString("imageUploadError_title", comment: "Image Upload Error"), andMessage: NSLocalizedString("imageUploadError_iCloud", comment: "Could not retrieve image. Error: \(error?.localizedDescription ?? "")"), forRetrying: true, withImage: image)
                    } else {
                        completionHandler(imageData, nil)
                    }
                })
            }
        }
    }

    
    // MARK: - Modify Metadata
    
    private func modifyImage(_ upload: UploadProperties, with originalData: Data, andObject originalObject: UIImage,
                             completionHandler: @escaping (_ updatedUpload: UploadProperties?, _ mimetype: String?, _ imageData: Data?, Error?) -> Void) {
        print("•••> modifyImage...")

        // Create CGI reference from image data (to retrieve complete metadata)
        guard let source: CGImageSource = CGImageSourceCreateWithData((originalData as CFData), nil) else {
            // Could not prepare image source
            return
        }

        // Get metadata from image data
        guard var imageMetadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as Dictionary? else {
            // Could not retrieve metadata
            return
        }

        // Strip GPS metadata if user requested it in Settings
        if Model.sharedInstance().stripGPSdataOnUpload {
            imageMetadata = ImageService.stripGPSdata(fromImageMetadata: imageMetadata)! as Dictionary<NSObject, AnyObject>
        }

        // Fix image metadata (size, type, etc.)
        imageMetadata = ImageService.fixMetadata(imageMetadata, of: originalObject)! as Dictionary<NSObject, AnyObject>

        // Apply compression if user requested it in Settings, or convert to JPEG if necessary
        var imageCompressed: Data? = nil
        var newUpload = upload
        let fileExt = (URL(fileURLWithPath: upload.fileName!).pathExtension).lowercased()
        if Model.sharedInstance().compressImageOnUpload && (CGFloat(Model.sharedInstance().photoQuality) < 100.0) {
            // Compress image (only possible in JPEG)
            let compressionQuality: CGFloat = CGFloat(Model.sharedInstance().photoQuality) / 100.0
            imageCompressed = originalObject.jpegData(compressionQuality: compressionQuality)

            // Final image file will be in JPEG format
            newUpload.fileName = URL(fileURLWithPath: URL(fileURLWithPath: upload.fileName!).deletingPathExtension().absoluteString).appendingPathExtension("JPG").lastPathComponent
        }
        else if !(Model.sharedInstance().uploadFileTypes.contains(fileExt)) {
            // Image in unaccepted file format for Piwigo server => convert to JPEG format
            imageCompressed = originalObject.jpegData(compressionQuality: 1.0)

            // Final image file will be in JPEG format
            newUpload.fileName = URL(fileURLWithPath: URL(fileURLWithPath: upload.fileName!).deletingPathExtension().absoluteString).appendingPathExtension("JPG").lastPathComponent
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
                    print("Error: Could not retrieve imageData object")
                    completionHandler(upload, "", nil, nil)
                    // Inform user and propose to cancel or continue
//                    showError(withTitle: NSLocalizedString("imageUploadError_title", comment: "Image Upload Error"), andMessage: NSLocalizedString("uploadError_message", comment: "Could not upload your image. Error: \(NSLocalizedString("imageUploadError_destination", comment: "cannot create image destination"))"), forRetrying: true, withImage: image)
                    return
                }
            }
            imageCompressed = imageDataRef as Data?
        }

        // Add metadata to final image
        let imageData = ImageService.writeMetadata(imageMetadata, intoImageData: imageCompressed)

        // Try to determine MIME type from image data
        var mimeType: String = "image/jpg"
        if let type = contentType(forImageData: imageData) {
            if type.count > 0  {
                // Adopt determined Mime tyme
                mimeType = type
                // Re-check filename extension if MIME type known
                let fileExt = (URL(fileURLWithPath: upload.fileName ?? "").pathExtension).lowercased()
                let expectedFileExtension = fileExtension(forImageData: imageData)
                if !(fileExt == expectedFileExtension) {
                    newUpload.fileName = URL(fileURLWithPath: upload.fileName ?? "file").deletingPathExtension().appendingPathExtension(expectedFileExtension ?? "").lastPathComponent
                }
            }
        }

        // Transfer image
        completionHandler(newUpload, mimeType, imageData, nil)
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
        var bytes: [UInt8] = []
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
        var bytes: [UInt8] = []
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

    // See https://en.wikipedia.org/wiki/List_of_file_signatures
    // https://mimesniff.spec.whatwg.org/#sniffing-in-an-image-context

    // https://en.wikipedia.org/wiki/BMP_file_format
    var bmp: [UInt8] = "BM".map { $0.asciiValue! }
    
    // https://en.wikipedia.org/wiki/GIF
    var gif87a: [UInt8] = "GIF87a".map { $0.asciiValue! }
    var gif89a: [UInt8] = "GIF89a".map { $0.asciiValue! }
    
    // https://en.wikipedia.org/wiki/High_Efficiency_Image_File_Format
    var heic: [UInt8] = [0x00, 0x00, 0x00, 0x18] + "ftypheic".map { $0.asciiValue! }
    
    // https://en.wikipedia.org/wiki/ILBM
    var iff: [UInt8] = "FORM".map { $0.asciiValue! }
    
    // https://en.wikipedia.org/wiki/JPEG
    var jpg: [UInt8] = [0xff, 0xd8, 0xff]
    
    // https://en.wikipedia.org/wiki/JPEG_2000
    var jp2: [UInt8] = [0x00, 0x00, 0x00, 0x0c, 0x6a, 0x50, 0x20, 0x20, 0x0d, 0x0a, 0x87, 0x0a]
    
    // https://en.wikipedia.org/wiki/Portable_Network_Graphics
    var png: [UInt8] = [0x89] + "PNG".map { $0.asciiValue! } + [0x0d, 0x0a, 0x1a, 0x0a]
    
    // https://en.wikipedia.org/wiki/Adobe_Photoshop#File_format
    var psd: [UInt8] = "8BPS".map { $0.asciiValue! }
    
    // https://en.wikipedia.org/wiki/TIFF
    var tif_ii: [UInt8] = "II".map { $0.asciiValue! } + [0x2a, 0x00]
    var tif_mm: [UInt8] = "MM".map { $0.asciiValue! } + [0x00, 0x2a]
    
    // https://en.wikipedia.org/wiki/WebP
    var webp: [UInt8] = "RIFF".map { $0.asciiValue! }
    
    // https://en.wikipedia.org/wiki/ICO_(file_format)
    var win_ico: [UInt8] = [0x00, 0x00, 0x01, 0x00]
    var win_cur: [UInt8] = [0x00, 0x00, 0x02, 0x00]
}
