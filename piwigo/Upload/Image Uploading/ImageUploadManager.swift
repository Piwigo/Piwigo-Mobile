//  Converted to Swift 5.1 by Swiftify v5.1.31847 - https://swiftify.com/
//
//  ImageUploadManager.swift
//  piwigo
//
//  Created by Spencer Baker on 2/3/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

import ImageIO
import Photos

enum kImagePermission : Int {
    case everybody = 0
    case adminsFamilyFriendsContacts = 1
    case adminsFamilyFriends = 2
    case adminsFamily = 4
    case admins = 8
}

@objc protocol ImageUploadDelegate: NSObjectProtocol {
    func imageUploaded(_ image: ImageUpload?, placeInQueue rank: Int, outOf totalInQueue: Int, withResponse response: [AnyHashable : Any]?)
    func imageProgress(_ image: ImageUpload?, onCurrent current: Int, forTotal total: Int, onChunk currentChunk: Int, forChunks totalChunks: Int, iCloudProgress progress: CGFloat)

    @objc optional func images(toUploadChanged imagesLeftToUpload: Int)
}

// MARK: - MIME type and file extension sniffing

        // See https://en.wikipedia.org/wiki/List_of_file_signatures
        // https://mimesniff.spec.whatwg.org/#sniffing-in-an-image-context

        // https://en.wikipedia.org/wiki/BMP_file_format
    let bmp = ["B", "M"]
    // https://en.wikipedia.org/wiki/GIF
    let gif87a = ["G", "I", "F", "8", "7", "a"]
let gif89a = ["G", "I", "F", "8", "9", "a"]
    // https://en.wikipedia.org/wiki/High_Efficiency_Image_File_Format
    let heic = [0x00, 0x00, 0x00, 0x18, "f", "t", "y", "p", "h", "e", "i", "c"]
    // https://en.wikipedia.org/wiki/ILBM
    let iff = ["F", "O", "R", "M"]
    // https://en.wikipedia.org/wiki/JPEG
    let jpg = [0xff, 0xd8, 0xff]
    // https://en.wikipedia.org/wiki/JPEG_2000
    let jp2 = [0x00, 0x00, 0x00, 0x0c, 0x6a, 0x50, 0x20, 0x20, 0x0d, 0x0a, 0x87, 0x0a]
    // https://en.wikipedia.org/wiki/Portable_Network_Graphics
    let png = [0x89, "P", "N", "G", 0x0d, 0x0a, 0x1a, 0x0a]
    // https://en.wikipedia.org/wiki/Adobe_Photoshop#File_format
    let psd = ["8", "B", "P", "S"]
    // https://en.wikipedia.org/wiki/TIFF
    let tif_ii = ["I", "I", 0x2a, 0x00]
let tif_mm = ["M", "M", 0x00, 0x2a]
    // https://en.wikipedia.org/wiki/WebP
    let webp = ["R", "I", "F", "F"]
    // https://en.wikipedia.org/wiki/ICO_(file_format)
    let win_ico = [0x00, 0x00, 0x01, 0x00]
let win_cur = [0x00, 0x00, 0x02, 0x00]


#if DEBUG_UPLOAD
private func FourCCString(_ code: FourCharCode) -> String? {
    let result = "\(Int((code >> 24)) & 0xff)\(Int((code >> 16)) & 0xff)\(Int((code >> 8)) & 0xff)\(code & 0xff)"
    let characterSet = CharacterSet.whitespaces
    return result.trimmingCharacters(in: characterSet)
}

class ImageUploadManager: UploadService {
    static var instance: ImageUploadManager? = nil

    class func sharedInstance() -> ImageUploadManager? {
        // `dispatch_once()` call was converted to a static variable initializer
        return instance
    }

    var imageUploadQueue: [AnyHashable]?
    var imageNamesUploadQueue: [AnyHashable]?
    var imageDeleteQueue: [AnyHashable]?
    var uploadedImagesToBeModerated: String?

    private var _maximumImagesForBatch = 0
    var maximumImagesForBatch: Int {
        get {
            _maximumImagesForBatch
        }
        set(maximumImagesForBatch) {
            _maximumImagesForBatch = maximumImagesForBatch

            if delegate?.responds(to: #selector(ImageUploadDelegate.images(toUploadChanged:))) ?? false {
                delegate?.images?(toUploadChanged: maximumImagesForBatch)
            }
        }
    }
    weak var delegate: ImageUploadDelegate?

    func addImage(_ image: ImageUpload?) {
        if let image = image {
            imageUploadQueue?.append(image)
        }
        maximumImagesForBatch += 1
        startUploadIfNeeded()

        // The file name extension may change e.g. MOV => MP4, HEIC => JPG
        imageNamesUploadQueue?.append(URL(fileURLWithPath: image?.fileName ?? "").deletingPathExtension().absoluteString)
    }

    func addImages(_ images: [AnyHashable]?) {
        for image in images ?? [] {
            guard let image = image as? ImageUpload else {
                continue
            }
            addImage(image)
        }
    }

    func getIndexOfImage(_ image: ImageUpload?) -> Int {
        if let image = image {
            return imageUploadQueue?.firstIndex(of: image) ?? NSNotFound
        }
        return 0
    }


    private var _isUploading = false
    private var isUploading: Bool {
        get {
            _isUploading
        }
        set(isUploading) {
            _isUploading = isUploading

            if !isUploading {
                // Reset variables
                maximumImagesForBatch = 0
                onCurrentImageUpload = 1

                // Allow system sleep
                UIApplication.shared.isIdleTimerDisabled = false
            } else {
                // Prevent system sleep
                UIApplication.shared.isIdleTimerDisabled = true
            }
        }
    }
    private var imageData: Data?
    private var onCurrentImageUpload = 0
    private var current = 0
    private var total = 0
    private var currentChunk = 0
    private var totalChunks = 0
    private var iCloudProgress: CGFloat = 0.0

    init() {
        super.init()
        imageUploadQueue = []
        imageNamesUploadQueue = []
        imageDeleteQueue = []
        uploadedImagesToBeModerated = ""
        isUploading = false

        current = 0
        total = 1
        currentChunk = 1
        totalChunks = 1
    }

// MARK: - Upload image queue management

    func startUploadIfNeeded() {
        if !isUploading {
            imageDeleteQueue = []
            uploadedImagesToBeModerated = ""
            uploadNextImage()
        }
    }

    func uploadNextImage() {
        // Another image or video to upload?
        if (imageUploadQueue?.count ?? 0) <= 0 {
            // Stop uploading
            isUploading = false
            return
        }

        iCloudProgress = -1.0 // No iCloud download (will become positive if any)
        isUploading = true
        Model.sharedInstance().hasUploadedImages = true

        // Image or video to be uploaded
        let nextImageToBeUploaded = imageUploadQueue?.first as? ImageUpload
        var fileExt = (URL(fileURLWithPath: nextImageToBeUploaded?.fileName ?? "").pathExtension).lowercased()
        let originalAsset = nextImageToBeUploaded?.imageAsset

        // Retrieve Photo, Live Photo or Video
        if originalAsset?.mediaType == .image {

            // Chek that the image format will be accepted by the Piwigo server
            if (!Model.sharedInstance().uploadFileTypes.contains(fileExt ?? "")) && (!Model.sharedInstance().uploadFileTypes.contains("jpg")) {
                showError(withTitle: NSLocalizedString("imageUploadError_title", comment: "Image Upload Error"), andMessage: NSLocalizedString("imageUploadError_format", comment: "Sorry, image files with extensions .\(fileExt?.uppercased() ?? "") and .jpg are not accepted by the Piwigo server."), forRetrying: false, withImage: nextImageToBeUploaded)
                return
            }

            // Image file type accepted
            switch originalAsset?.mediaSubtypes {
            //            case PHAssetMediaSubtypePhotoLive:
            //                [self retrieveFullSizeAssetDataFromLivePhoto:nextImageToBeUploaded];
            //                break;
                case [], .photoPanorama, .photoHDR, .photoScreenshot, .photoLive, .photoDepthEffect:
                    fallthrough
                default:
                    // Image upload allowed — Will wait for image file download from iCloud if necessary
                    retrieveImageFromiCloud(forAsset: nextImageToBeUploaded)
            }
        } else if originalAsset?.mediaType == .video {

            // Videos are always exported in MP4 format (whenever possible)
            fileExt = "mp4"
            nextImageToBeUploaded?.fileName = URL(fileURLWithPath: URL(fileURLWithPath: nextImageToBeUploaded?.fileName ?? "").deletingPathExtension().absoluteString).appendingPathExtension(fileExt ?? "").absoluteString

            // Chek that the video format is accepted by the Piwigo server
            if !(Model.sharedInstance().uploadFileTypes.contains(fileExt ?? "")) {
                showError(withTitle: NSLocalizedString("videoUploadError_title", comment: "Video Upload Error"), andMessage: NSLocalizedString("videoUploadError_format", comment: "Sorry, video files with extension .\(fileExt?.uppercased() ?? "") are not accepted by the Piwigo server."), forRetrying: false, withImage: nextImageToBeUploaded)
                return
            }

            // Video upload allowed — Will wait for video file download from iCloud if necessary
            retrieveFullSizeAssetData(fromVideo: nextImageToBeUploaded)
        } else if originalAsset?.mediaType == .audio {

            // Not managed by Piwigo iOS yet…
            showError(withTitle: NSLocalizedString("audioUploadError_title", comment: "Audio Upload Error"), andMessage: NSLocalizedString("audioUploadError_format", comment: "Sorry, audio files are not supported by Piwigo Mobile yet."), forRetrying: false, withImage: nextImageToBeUploaded)
            return

            // Chek that the audio format is accepted by the Piwigo server
            //        if (![[Model sharedInstance].uploadFileTypes containsString:fileExt]) {
            //            [self showErrorWithTitle:NSLocalizedString(@"audioUploadError_title", @"Audio Upload Error")
            //                          andMessage:[NSString stringWithFormat:NSLocalizedString(@"audioUploadError_format", @"Sorry, audio files with extension .%@ are not accepted by the Piwigo server."), [fileExt uppercaseString]]
            //                         forRetrying:NO
            //                           withImage:nextImageToBeUploaded];
            //            return;
            //        }

            // Audio upload allowed — Will wait for audio file download from iCloud if necessary
            //        [self retrieveFullSizeAssetDataFromAudio:nextImageToBeUploaded];
        }
    }

    func uploadNextImageAndRemoveImage(fromQueue image: ImageUpload?, withResponse response: [AnyHashable : Any]?) {
        // Remove image from queue (in both tables)
        if (imageUploadQueue?.count ?? 0) > 0 {
            // Added to prevent crash
            imageUploadQueue?.remove(at: 0)
            imageNamesUploadQueue?.removeAll { $0 as AnyObject === URL(fileURLWithPath: image?.fileName ?? "").deletingPathExtension().absoluteString as AnyObject }

            // Update progress infos
            if delegate?.responds(to: #selector(ImageUploadDelegate.imageUploaded(_:placeInQueue:outOf:withResponse:))) ?? false {
                delegate?.imageUploaded(image, placeInQueue: onCurrentImageUpload, outOf: maximumImagesForBatch, withResponse: response)
            }
        }

        // Upload next image
        uploadNextImage()
    }

// MARK: - Image, retrieve and modify before upload
    func retrieveImageFromiCloud(forAsset image: ImageUpload?) {
#if DEBUG_UPLOAD
        print("retrieveImageFromiCloudForAsset starting...")
#endif
        // Case of an image…
        let options = PHImageRequestOptions()
        // Does not block the calling thread until image data is ready or an error occurs
        options.isSynchronous = false
        // Requests the most recent version of the image asset
        options.version() = PHImageRequestOptionsVersion.current.rawValue
        // Requests the highest-quality image available, regardless of how much time it takes to load.
        options.deliveryMode = .highQualityFormat
        // Photos can download the requested video from iCloud
        options.isNetworkAccessAllowed = true
        // Requests Photos to resize the image according to user settings
        var size = PHImageManagerMaximumSize
        options.resizeMode = .exact
        if Model.sharedInstance().resizeImageOnUpload && Model.sharedInstance().photoResize < 100.0 {
            let scale: CGFloat = Model.sharedInstance().photoResize / 100.0
            size = CGSize(width: CGFloat(truncating: image?.imageAsset.pixelWidth ?? 0.0) * scale, height: CGFloat(truncating: image?.imageAsset.pixelHeight ?? 0.0) * scale)
            options.resizeMode = .exact
        }

        // The block Photos calls periodically while downloading the photo
        options.progressHandler = { progress, error, stop, info in
        #if DEBUG_UPLOAD
            print(String(format: "downloading Photo from iCloud — progress %lf", progress))
        #endif
            // The handler needs to update the user interface => Dispatch to main thread
            DispatchQueue.main.async(execute: {

                self.iCloudProgress = CGFloat(progress)
                let imageBeingUploaded = self.imageUploadQueue?.first as? ImageUpload
                if error != nil {
                    // Inform user and propose to cancel or continue
                    self.showError(withTitle: NSLocalizedString("imageUploadError_title", comment: "Image Upload Error"), andMessage: NSLocalizedString("imageUploadError_iCloud", comment: "Could not retrieve image. Error: \(error?.localizedDescription ?? "")"), forRetrying: true, withImage: image)
                    return
                } else if imageBeingUploaded?.stopUpload != nil {
                    // User wants to cancel the download
                    stop = UnsafeMutablePointer<ObjCBool>(mutating: &true)

                    // Remove image from queue, update UI and upload next one
                    self.maximumImagesForBatch -= 1
                    self.uploadNextImageAndRemoveImage(fromQueue: image, withResponse: nil)
                } else {
                    // Update progress bar(s)
                    if self.delegate?.responds(to: #selector(ImageUploadDelegate.imageProgress(_:onCurrent:forTotal:onChunk:forChunks:iCloudProgress:))) ?? false {
                        self.delegate?.imageProgress(image, onCurrent: self.current, forTotal: self.total, onChunk: self.currentChunk, forChunks: self.totalChunks, iCloudProgress: CGFloat(progress))
                    }
                }
            })
        }

        // Requests image…
        autoreleasepool {
            if let imageAsset = image?.imageAsset {
                PHImageManager.default().requestImage(for: imageAsset, targetSize: size, contentMode: .default, options: options, resultHandler: { imageObject, info in
                #if DEBUG_UPLOAD
                    if let comment = imageObject?.comment, let info = info {
                        print("retrieveImageFromiCloudForAsset \"\(comment)\" returned info(\(info))")
                    }
                    print(String(format: "got image %.0fw x %.0fh with orientation %ld", imageObject?.size.width ?? 0.0, imageObject?.size.height ?? 0.0, imageObject?.imageOrientation.rawValue))
                #endif
                    if info?[PHImageErrorKey] != nil || (imageObject?.size.width == 0) || (imageObject?.size.height == 0) {
                        let error = info?[PHImageErrorKey] as? Error
                        // Inform user and propose to cancel or continue
                        self.showError(withTitle: NSLocalizedString("imageUploadError_title", comment: "Image Upload Error"), andMessage: NSLocalizedString("imageUploadError_iCloud", comment: "Could not retrieve image. Error: \(error?.localizedDescription ?? "")"), forRetrying: true, withImage: image)
                        return
                    }

                    // Fix orientation if needed
                    let fixedImageObject = self.fixOrientationOf(imageObject)

                    // Expected resource available
                    self.retrieveFullSizeImageData(forAsset: image, andObject: fixedImageObject)
                })
            }
        }
    }

    func retrieveFullSizeImageData(forAsset image: ImageUpload?, andObject imageObject: UIImage?) {
#if DEBUG_UPLOAD
        print("retrieveFullSizeAssetDataFromImage starting...")
#endif
        // Case of an image…
        let options = PHImageRequestOptions()
        // Does not block the calling thread until image data is ready or an error occurs
        options.isSynchronous = false
        // Requests the most recent version of the image asset
        options.version() = PHImageRequestOptionsVersion.current.rawValue
        // Requests a fast-loading image, possibly sacrificing image quality.
        options.deliveryMode = .fastFormat
        // Photos can download the requested video from iCloud
        options.isNetworkAccessAllowed = true

        // The block Photos calls periodically while downloading the photo
        options.progressHandler = { progress, error, stop, info in
        #if DEBUG_UPLOAD
            print(String(format: "downloading Photo from iCloud — progress %lf", progress))
        #endif
            // The handler needs to update the user interface => Dispatch to main thread
            DispatchQueue.main.async(execute: {

                self.iCloudProgress = CGFloat(progress)
                let imageBeingUploaded = self.imageUploadQueue?.first as? ImageUpload
                if error != nil {
                    // Inform user and propose to cancel or continue
                    self.showError(withTitle: NSLocalizedString("imageUploadError_title", comment: "Image Upload Error"), andMessage: NSLocalizedString("imageUploadError_iCloud", comment: "Could not retrieve image. Error: \(error?.localizedDescription ?? "")"), forRetrying: true, withImage: image)
                    return
                } else if imageBeingUploaded?.stopUpload != nil {
                    // User wants to cancel the download
                    stop = UnsafeMutablePointer<ObjCBool>(mutating: &true)

                    // Remove image from queue, update UI and upload next one
                    self.maximumImagesForBatch -= 1
                    self.uploadNextImageAndRemoveImage(fromQueue: image, withResponse: nil)
                } else {
                    // Update progress bar(s)
                    if self.delegate?.responds(to: #selector(ImageUploadDelegate.imageProgress(_:onCurrent:forTotal:onChunk:forChunks:iCloudProgress:))) ?? false {
                        self.delegate?.imageProgress(image, onCurrent: self.current, forTotal: self.total, onChunk: self.currentChunk, forChunks: self.totalChunks, iCloudProgress: CGFloat(progress))
                    }
                }
            })
        }

        autoreleasepool {
            if #available(iOS 13.0, *) {
                if let imageAsset = image?.imageAsset {
                    PHImageManager.default().requestImageDataAndOrientation(for: imageAsset, options: options, resultHandler: { imageData, dataUTI, orientation, info in
                    #if DEBUG_UPLOAD
                        if let fileName = image?.fileName, let info = info {
                            print("retrieveFullSizeImageDataForAsset \"\(fileName)\" returned info(\(info))")
                        }
                        print(String(format: "got image %.0fw x %.0fh with orientation:%ld", imageObject?.size.width ?? 0.0, imageObject?.size.height ?? 0.0, orientation.rawValue))
                    #endif
                        if info?[PHImageErrorKey] != nil || ((imageData?.count ?? 0) == 0) {
                            let error = info?[PHImageErrorKey] as? Error
                            // Inform user and propose to cancel or continue
                            self.showError(withTitle: NSLocalizedString("imageUploadError_title", comment: "Image Upload Error"), andMessage: NSLocalizedString("imageUploadError_iCloud", comment: "Could not retrieve image. Error: \(error?.localizedDescription ?? "")"), forRetrying: true, withImage: image)
                            return
                        }

                        // Expected resource available
                        self.modifyImage(image, with: imageData, andObject: imageObject)
                    })
                }
            } else {
                PHImageManager.default().requestImageData(forAsset: image?.imageAsset, options: options, resultHandler: { imageData, dataUTI, orientation, info in
                #if DEBUG_UPLOAD
                    if let fileName = image?.fileName, let info = info {
                        print("retrieveFullSizeImageDataForAsset \"\(fileName)\" returned info(\(info))")
                    }
                    print(String(format: "got image %.0fw x %.0fh with orientation:%ld", imageObject?.size.width ?? 0.0, imageObject?.size.height ?? 0.0, orientation.rawValue))
                #endif
                    if info?[PHImageErrorKey] != nil || ((imageData?.count ?? 0) == 0) {
                        let error = info?[PHImageErrorKey] as? Error
                        // Inform user and propose to cancel or continue
                        self.showError(withTitle: NSLocalizedString("imageUploadError_title", comment: "Image Upload Error"), andMessage: NSLocalizedString("imageUploadError_iCloud", comment: "Could not retrieve image. Error: \(error?.localizedDescription ?? "")"), forRetrying: true, withImage: image)
                        return
                    }

                    // Expected resource available
                    self.modifyImage(image, with: imageData, andObject: imageObject)
                })
            }
        }
    }

    func modifyImage(_ image: ImageUpload?, with originalData: Data?, andObject originalObject: UIImage?) {
        var originalData = originalData
        var originalObject = originalObject
        // Create CGI reference from image data (to retrieve complete metadata)
        var source: CGImageSource? = nil
        if let data = originalData as? CFMutableData? {
            source = CGImageSourceCreateWithData(data, nil)
        }
        if source == nil {
        #if DEBUG_UPLOAD
            print("Error: Could not create source")
        #endif
            // Inform user and propose to cancel or continue
            showError(withTitle: NSLocalizedString("imageUploadError_title", comment: "Image Upload Error"), andMessage: NSLocalizedString("uploadError_message", comment: "Could not upload your image. Error: \(NSLocalizedString("imageUploadError_source", comment: "cannot create image source"))"), forRetrying: true, withImage: image)
            return
        }

        // Get metadata from image data
        var imageMetadata = CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source, 0, nil)) as? [AnyHashable : Any]
#if DEBUG_UPLOAD
        if let imageMetadata = imageMetadata {
            print("modifyImage finds metadata from data:\(imageMetadata)")
        }
        print(String(format: "originalObject is %.0fw x %.0fh", originalObject?.size.width ?? 0.0, originalObject?.size.height ?? 0.0))
#endif

        // Strip GPS metadata if user requested it in Settings
        if Model.sharedInstance().stripGPSdataOnUpload && (imageMetadata != nil) {
            imageMetadata = ImageService.stripGPSdata(fromImageMetadata: imageMetadata)
        }

        // Fix image metadata (size, type, etc.)
        imageMetadata = ImageService.fixMetadata(imageMetadata, of: originalObject)

        // Final metadata…
#if DEBUG_UPLOAD
        if let imageMetadata = imageMetadata {
            print("modifyImage: metadata to upload => \(imageMetadata)")
        }
#endif

        // Apply compression if user requested it in Settings, or convert to JPEG if necessary
        var imageCompressed: Data? = nil
        var fileExt = (URL(fileURLWithPath: image?.fileName ?? "").pathExtension).lowercased()
        if Model.sharedInstance().compressImageOnUpload && (Model.sharedInstance().photoQuality < 100.0) {
            // Compress image (only possible in JPEG)
            let compressionQuality: CGFloat = Model.sharedInstance().photoQuality / 100.0
            imageCompressed = originalObject?.jpegData(compressionQuality: compressionQuality)

            // Final image file will be in JPEG format
            image?.fileName = URL(fileURLWithPath: URL(fileURLWithPath: image?.fileName ?? "").deletingPathExtension().absoluteString).appendingPathExtension("JPG").absoluteString
        } else if !(Model.sharedInstance().uploadFileTypes.contains(fileExt ?? "")) {
            // Image in unaccepted file format for Piwigo server => convert to JPEG format
            imageCompressed = originalObject?.jpegData(compressionQuality: 1.0)

            // Final image file will be in JPEG format
            image?.fileName = URL(fileURLWithPath: URL(fileURLWithPath: image?.fileName ?? "").deletingPathExtension().absoluteString).appendingPathExtension("JPG").absoluteString
        }

        // If compression failed or imageCompressed nil, try to use original image
        if imageCompressed == nil {
            var UTI: CFString? = nil
            if let source = source {
                UTI = CGImageSourceGetType(source)
            }
            let imageDataRef = CFDataCreateMutable(nil, CFIndex(0))
            var destination: CGImageDestination? = nil
            if let imageDataRef = imageDataRef, let UTI = UTI {
                destination = CGImageDestinationCreateWithData(imageDataRef, UTI, 1, nil)
            }
            if let destination = destination, let CGImage = originalObject?.cgImage {
                CGImageDestinationAddImage(destination, CGImage, nil)
            }
            if let destination = destination {
                if !CGImageDestinationFinalize(destination) {
                #if DEBUG_UPLOAD
                    print("Error: Could not retrieve imageData object")
                #endif

                    // Inform user and propose to cancel or continue
                    showError(withTitle: NSLocalizedString("imageUploadError_title", comment: "Image Upload Error"), andMessage: NSLocalizedString("uploadError_message", comment: "Could not upload your image. Error: \(NSLocalizedString("imageUploadError_destination", comment: "cannot create image destination"))"), forRetrying: true, withImage: image)
                    return
                }
            }
            imageCompressed = imageDataRef as? Data
        }

        // Release original CGImageSourceRef


        // Add metadata to final image
        imageData = ImageService.writeMetadata(imageMetadata, intoImageData: imageCompressed)

        // Release memory
        imageCompressed = nil
        imageMetadata = nil
        originalObject = nil
        originalData = nil

        // Try to determine MIME type from image data
        var mimeType = ""
        mimeType = contentType(forImageData: imageData) ?? ""

        // Re-check filename extension if MIME type known
        if mimeType != nil {
            fileExt = (URL(fileURLWithPath: image?.fileName ?? "").pathExtension).lowercased()
            let expectedFileExtension = fileExtension(forImageData: imageData)
            if !(fileExt == expectedFileExtension) {
                image?.fileName = URL(fileURLWithPath: URL(fileURLWithPath: image?.fileName ?? "").deletingPathExtension().absoluteString).appendingPathExtension(expectedFileExtension ?? "").absoluteString
            }
        } else {
            // Could not determine image file format from image data,
            // keep file extension and use arbitrary mime type
            mimeType = "image/jpg"
        }

        // Upload image with tags and properties
        uploadImage(image, withMimeType: mimeType)
    }

    func contentType(forImageData data: Data?) -> String? {
        var bytes = [0]
        data?.getBytes(&bytes, length: 12)

        if !memcmp(bytes, jpg, 3) {
            return "image/jpeg"
        } else if !memcmp(bytes, heic, 12) {
            return "image/heic"
        } else if !memcmp(bytes, png, 8) {
            return "image/png"
        } else if !memcmp(bytes, gif87a, 6) || !memcmp(bytes, gif89a, 6) {
            return "image/gif"
        } else if !memcmp(bytes, bmp, 2) {
            return "image/x-ms-bmp"
        } else if !memcmp(bytes, psd, 4) {
            return "image/vnd.adobe.photoshop"
        } else if !memcmp(bytes, iff, 4) {
            return "image/iff"
        } else if !memcmp(bytes, webp, 4) {
            return "image/webp"
        } else if !memcmp(bytes, win_ico, 4) || !memcmp(bytes, win_cur, 4) {
            return "image/x-icon"
        } else if !memcmp(bytes, tif_ii, 4) || !memcmp(bytes, tif_mm, 4) {
            return "image/tiff"
        } else if !memcmp(bytes, jp2, 12) {
            return "image/jp2"
        }

        return nil
    }

    func fileExtension(forImageData data: Data?) -> String? {
        var bytes = [0]
        data?.getBytes(&bytes, length: 12)

        if !memcmp(bytes, jpg, 3) {
            return "jpg"
        } else if !memcmp(bytes, heic, 12) {
            return "heic"
        } else if !memcmp(bytes, png, 8) {
            return "png"
        } else if !memcmp(bytes, gif87a, 6) || !memcmp(bytes, gif89a, 6) {
            return "gif"
        } else if !memcmp(bytes, bmp, 2) {
            return "bmp"
        } else if !memcmp(bytes, psd, 4) {
            return "psd"
        } else if !memcmp(bytes, iff, 4) {
            return "iff"
        } else if !memcmp(bytes, webp, 4) {
            return "webp"
        } else if !memcmp(bytes, win_ico, 4) {
            return "ico"
        } else if !memcmp(bytes, win_cur, 4) {
            return "cur"
        } else if !memcmp(bytes, tif_ii, 4) || !memcmp(bytes, tif_mm, 4) {
            return "tif"
        } else if !memcmp(bytes, jp2, 12) {
            return "jp2"
        }

        return nil
    }

    //-(void)retrieveFullSizeAssetDataFromLivePhoto:(ImageUpload *)image   // Asynchronous
    //{
    //    __block NSData *assetData = nil;
    //
    //    // Case of an Live Photo…
    //    PHLivePhotoRequestOptions *options = [[PHLivePhotoRequestOptions alloc] init];
    //    // Requests the most recent version of the image asset
    //    options.version = PHImageRequestOptionsVersionOriginal;
    //    // Requests the highest-quality image available, regardless of how much time it takes to load.
    //    options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
    //    // Photos can download the requested video from iCloud.
    //    options.networkAccessAllowed = YES;
    //    // The block Photos calls periodically while downloading the LivePhoto.
    //    options.progressHandler = ^(double progress,NSError *error,BOOL* stop, NSDictionary* dict) {
    //        NSLog(@"downloading Live Photo from iCloud — progress %lf",progress);
    //    };
    //
    //    // Requests Live Photo…
    //    @autoreleasepool {
    //        [[PHImageManager defaultManager] requestLivePhotoForAsset:image.imageAsset
    //                   targetSize:CGSizeZero contentMode:PHImageContentModeDefault
    //                      options:options resultHandler:^(PHLivePhoto *livePhoto, NSDictionary *info) {
    //#if defined(DEBUG_UPLOAD)
    //                          NSLog(@"retrieveFullSizeAssetDataFromLivePhoto returned info(%@)", info);
    //#endif
    //                          if ([info objectForKey:PHImageErrorKey]) {
    //                              NSError *error = [info valueForKey:PHImageErrorKey];
    //                              NSLog(@"=> Error : %@", error.description);
    //                          }
    //
    //                          if (![[info valueForKey:PHImageResultIsDegradedKey] boolValue]) {
    //                              // Expected resource available
    //                              NSArray<PHAssetResource*>* resources = [PHAssetResource assetResourcesForLivePhoto:livePhoto];
    //                              // Extract still high resolution image and original video
    //                              __block PHAssetResource *resImage = nil;
    //                              [resources enumerateObjectsUsingBlock:^(PHAssetResource *res, NSUInteger idx, BOOL *stop) {
    //                                  if (res.type == PHAssetResourceTypeFullSizePhoto) {
    //                                      resImage = res;
    //                                  }
    //                              }];
    //
    //                              // Store resources
    //                              NSURL *urlImage = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[[image.image stringByDeletingPathExtension] stringByAppendingPathExtension:@"jpg"]]];
    //
    //                              // Deletes temporary file if exists (might be incomplete, etc.)
    //                              [[NSFileManager defaultManager] removeItemAtURL:urlImage error:nil];
    //
    //                              // Store temporarily still image and video, then extract data
    //                              [[PHAssetResourceManager defaultManager] writeDataForAssetResource:resImage toFile:urlImage options:nil completionHandler:^(NSError * _Nullable error) {
    //                                      if (error.code) {
    //                                          NSLog(@"=> Error storing image: %@", error.description);
    //                                      }
    //                                      assetData = [[NSData dataWithContentsOfURL:urlImage] copy];
    //                                      assert(assetData.length != 0);
    //                                      // Modify image before upload if needed
    //                                      [self modifyImage:image withData:assetData];
    //                              }];
    //                          }
    //                      }
    //         ];
    //    }
    //}
// MARK: - Video, retrieve and modify before upload
    func retrieveFullSizeAssetData(fromVideo image: ImageUpload?) {
        // Case of a video…
        let options = PHVideoRequestOptions()
        // Requests the most recent version of the image asset
        options.version() = PHVideoRequestOptionsVersion.current.rawValue
        // Requests the highest-quality video available, regardless of how much time it takes to load.
        options.deliveryMode = .highQualityFormat
        // Photos can download the requested video from iCloud.
        options.isNetworkAccessAllowed = true

        // The block Photos calls periodically while downloading the video.
        options.progressHandler = { progress, error, stop, dict in
        #if DEBUG_UPLOAD
            print(String(format: "downloading Video from iCloud — progress %lf", progress))
        #endif
            // The handler needs to update the user interface => Dispatch to main thread
            DispatchQueue.main.async(execute: {

                self.iCloudProgress = CGFloat(progress)
                let imageBeingUploaded = self.imageUploadQueue?.first as? ImageUpload
                if error != nil {
                    // Inform user and propose to cancel or continue
                    self.showError(withTitle: NSLocalizedString("videoUploadError_title", comment: "Video Upload Error"), andMessage: NSLocalizedString("videoUploadError_iCloud", comment: "Could not retrieve video. Error: \(error?.localizedDescription ?? "")"), forRetrying: true, withImage: image)
                    return
                } else if imageBeingUploaded?.stopUpload != nil {
                    // User wants to cancel the download
                    stop = UnsafeMutablePointer<ObjCBool>(mutating: &true)

                    // Remove image from queue and upload next one
                    self.maximumImagesForBatch -= 1
                    self.uploadNextImageAndRemoveImage(fromQueue: image, withResponse: nil)
                } else {
                    // Updates progress bar(s)
                    if self.delegate?.responds(to: #selector(ImageUploadDelegate.imageProgress(_:onCurrent:forTotal:onChunk:forChunks:iCloudProgress:))) ?? false {
                        print(String(format: "retrieveFullSizeAssetDataFromVideo: %.2f", progress))
                        self.delegate?.imageProgress(image, onCurrent: self.current, forTotal: self.total, onChunk: self.currentChunk, forChunks: self.totalChunks, iCloudProgress: CGFloat(progress))
                    }
                }
            })
        }

        // Available export session presets?
        if let imageAsset = image?.imageAsset {
            PHImageManager.default().requestAVAsset(forVideo: imageAsset, options: options, resultHandler: { avasset, audioMix, info in

            #if DEBUG_UPLOAD
                if let metadata = avasset?.metadata {
                    print("=> Metadata: \(metadata)")
                }
                if let creationDate = avasset?.creationDate {
                    print("=> Creation date: \(creationDate)")
                }
                print("=> Exportable: \(avasset?.isExportable ?? false ? "Yes" : "No")")
                if let avasset = avasset {
                    print("=> Compatibility: \(AVAssetExportSession.exportPresets(compatibleWith: avasset))")
                }
                if let tracks = avasset?.tracks {
                    print("=> Tracks: \(tracks)")
                }
                for track in avasset?.tracks ?? [] {
                    if track.mediaType == .video {
                        print(String(format: "=>       : %.f x %.f", track.naturalSize.width, track.naturalSize.height))
                    }
                    var format = ""
                    for i in 0..<track.formatDescriptions.count {
                        let desc = track.formatDescriptions[i] as? CMFormatDescription
                        // Get String representation of media type (vide, soun, sbtl, etc.)
                        var type: String? = nil
                        if let desc = desc {
                            type = FourCCString(CMFormatDescriptionGetMediaType(desc))
                        }
                        // Get String representation media subtype (avc1, aac, tx3g, etc.)
                        var subType: String? = nil
                        if let desc = desc {
                            subType = FourCCString(CMFormatDescriptionGetMediaSubType(desc))
                        }
                        // Format string as type/subType
                        format += "\(type ?? "")/\(subType ?? "")"
                        // Comma separate if more than one format description
                        if i < track.formatDescriptions.count - 1 {
                            format += ","
                        }
                    }
                    print("=>       : \(format)")
                }
            #endif

                // QuickTime video exportable with passthrough option (e.g. recorded with device)?
                //                  [AVAssetExportSession determineCompatibilityOfExportPreset:AVAssetExportPresetPassthrough withAsset:avasset outputFileType:AVFileTypeMPEG4 completionHandler:^(BOOL compatible) {
                //
                var exportPreset: String? = nil
                //                      if (compatible) {
                //                          // No reencoding required — will keep metadata (or not depending on user's settings)
                //                          exportPreset = AVAssetExportPresetPassthrough;
                //                      }
                //                      else
                //                      {
                let maxPixels = lround(fmax(Float(truncating: image?.imageAsset.pixelWidth ?? 0.0), Float(truncating: image?.imageAsset.pixelHeight ?? 0.0)))
                var presets: [String]? = nil
                if let avasset = avasset {
                    presets = AVAssetExportSession.exportPresets(compatibleWith: avasset)
                }
                // This array never contains AVAssetExportPresetPassthrough,
                // that is why we use determineCompatibilityOfExportPreset: before.
                if (maxPixels <= 640) && (presets?.contains(AVAssetExportPreset640x480)) ?? false {
                    // Encode in 640x480 pixels — metadata will be lost
                    exportPreset = AVAssetExportPreset640x480
                } else if (maxPixels <= 960) && (presets?.contains(AVAssetExportPreset960x540)) ?? false {
                    // Encode in 960x540 pixels — metadata will be lost
                    exportPreset = AVAssetExportPreset960x540
                } else if (maxPixels <= 1280) && (presets?.contains(AVAssetExportPreset1280x720)) ?? false {
                    // Encode in 1280x720 pixels — metadata will be lost
                    exportPreset = AVAssetExportPreset1280x720
                } else if (maxPixels <= 1920) && (presets?.contains(AVAssetExportPreset1920x1080)) ?? false {
                    // Encode in 1920x1080 pixels — metadata will be lost
                    exportPreset = AVAssetExportPreset1920x1080
                } else if (maxPixels <= 3840) && (presets?.contains(AVAssetExportPreset1920x1080)) ?? false {
                    // Encode in 1920x1080 pixels — metadata will be lost
                    exportPreset = AVAssetExportPreset3840x2160
                } else {
                    // Use highest quality for device
                    exportPreset = AVAssetExportPresetHighestQuality
                }
                //                      }

                // Requests video with selected export preset…
                autoreleasepool {
                    if let imageAsset = image?.imageAsset {
                        PHImageManager.default().requestExportSession(forVideo: imageAsset, options: options, exportPreset: exportPreset ?? "", resultHandler: { exportSession, info in
                        #if DEBUG_UPLOAD
                            if let info = info {
                                print("retrieveFullSizeAssetDataFromVideo returned info(\(info))")
                            }
                        #endif
                            // The handler needs to update the user interface => Dispatch to main thread
                            DispatchQueue.main.async(execute: {
                                if info?[PHImageErrorKey] != nil {
                                    // Inform user and propose to cancel or continue
                                    let error = info?[PHImageErrorKey] as? Error
                                    self.showError(withTitle: NSLocalizedString("videoUploadError_title", comment: "Video Upload Error"), andMessage: NSLocalizedString("videoUploadError_iCloud", comment: "Could not retrieve video. Error: \(error?.localizedDescription ?? "")"), forRetrying: true, withImage: image)
                                    return
                                }
                            })

                            // Modifies video before upload to Piwigo server
                            self.modifyVideo(image, with: avasset, beforeExporting: exportSession)
                            //                                  [self modifyVideo:image beforeExporting:exportSession];
                        })
                    }
                }
            })
        }
        //              }];
    }

    func modifyVideo(_ image: ImageUpload?, with originalVideo: AVAsset?, beforeExporting exportSession: AVAssetExportSession?) {
        // Strips private metadata if user requested it in Settings
        // Apple documentation: 'metadataItemFilterForSharing' removes user-identifying metadata items, such as location information and leaves only metadata releated to commerce or playback itself. For example: playback, copyright, and commercial-related metadata, such as a purchaser’s ID as set by a vendor of digital media, along with metadata either derivable from the media itself or necessary for its proper behavior are all left intact.
        exportSession?.metadata = nil
        if Model.sharedInstance().stripGPSdataOnUpload {
            exportSession?.metadataItemFilter = AVMetadataItemFilter.forSharing()
        } else {
            exportSession?.metadataItemFilter = nil
        }

        // Complete video range
        exportSession?.timeRange = CMTimeRangeMake(start: .zero, duration: .positiveInfinity)

        // Video formats — Always export video in MP4 format
        exportSession?.outputFileType = .mp4
        exportSession?.shouldOptimizeForNetworkUse = true
#if DEBUG_UPLOAD
        if let supportedFileTypes = exportSession?.supportedFileTypes {
            print("Supported file types: \(supportedFileTypes)")
        }
        print("Description: \(exportSession?.description ?? "")")
#endif

        // Prepare MIME type
        let mimeType = "video/mp4"

        // Temporary filename and path
        exportSession?.outputURL = URL(fileURLWithPath: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(URL(fileURLWithPath: URL(fileURLWithPath: image?.fileName ?? "").deletingPathExtension().absoluteString).appendingPathExtension("mp4").absoluteString).absoluteString)

        // Deletes temporary video file if exists (might be incomplete, etc.)
        do {
            if let outputURL = exportSession?.outputURL {
                try FileManager.default.removeItem(at: outputURL)
            }
        } catch {
        }

        // Export temporary video for upload
        exportSession?.exportAsynchronously(completionHandler: {
            DispatchQueue.main.async(execute: {
                if exportSession?.status == .completed {
                    // Gets copy as NSData
                    if let outputURL = exportSession?.outputURL {
                        self.imageData = Data(contentsOf: outputURL)?.copy()
                    }
                    assert((self.imageData?.count ?? 0) != 0)
                #if DEBUG_UPLOAD
                    var videoAsset: AVAsset? = nil
                    if let outputURL = exportSession?.outputURL {
                        videoAsset = AVAsset(url: outputURL)
                    }
                    let assetMetadata = videoAsset?.commonMetadata
                    print("Export sucess :-)")
                    if let assetMetadata = assetMetadata {
                        print("Video metadata: \(assetMetadata)")
                    }
                #endif

                    // Deletes temporary video file
                    do {
                        if let outputURL = exportSession?.outputURL {
                            try FileManager.default.removeItem(at: outputURL)
                        }
                    } catch {
                    }

                    // Upload video with tags and properties
                    self.uploadImage(image, withMimeType: mimeType)
                } else if exportSession?.status == .failed {
                    // Deletes temporary video file if any
                    do {
                        if let outputURL = exportSession?.outputURL {
                            try FileManager.default.removeItem(at: outputURL)
                        }
                    } catch {
                    }

                    // Try to upload original file
                    if (originalVideo is AVURLAsset) && Model.sharedInstance().uploadFileTypes.contains(URL(fileURLWithPath: image?.fileName ?? "").pathExtension ?? "") {
                        let originalFileURL = originalVideo as? AVURLAsset
                        if let URL = originalFileURL?.url {
                            self.imageData = Data(contentsOf: URL)?.copy()
                        }
                        let assetMetadata = originalVideo?.commonMetadata

                        // Creates metadata without location data
                        var newAssetMetadata: [AnyHashable] = []
                        for item in assetMetadata ?? [] {
                            if item.commonKey?.isEqual(toString: AVMetadataKey.commonKeyLocation) != nil {
                            #if DEBUG_UPLOAD
                                print("Location found: \(item.stringValue ?? "")")
                            #endif
                            } else {
                                newAssetMetadata.append(item)
                            }
                        }
                        let assetDoesNotContainGPSmetadata = (newAssetMetadata.count == assetMetadata?.count) || (assetMetadata?.count == 0)

                        if self.imageData != nil && ((!Model.sharedInstance().stripGPSdataOnUpload) || (Model.sharedInstance().stripGPSdataOnUpload && assetDoesNotContainGPSmetadata)) {

                            // Upload video with tags and properties

                            self.uploadImage(image, withMimeType: mimeType)
                            return
                        } else {
                            // No data — Inform user that it won't succeed
                            self.showError(withTitle: NSLocalizedString("videoUploadError_title", comment: "Video Upload Error"), andMessage: NSLocalizedString("videoUploadError_export", comment: "Sorry, the video could not be retrieved for the upload. Error: \(exportSession?.error?.localizedDescription ?? "")"), forRetrying: false, withImage: image)
                            return
                        }
                    }
                } else if exportSession?.status == .cancelled {
                    // Deletes temporary video file
                    do {
                        if let outputURL = exportSession?.outputURL {
                            try FileManager.default.removeItem(at: outputURL)
                        }
                    } catch {
                    }

                    // Inform user
                    self.showError(withTitle: NSLocalizedString("uploadCancelled_title", comment: "Upload Cancelled"), andMessage: NSLocalizedString("videoUploadCancelled_message", comment: "The upload of the video has been cancelled."), forRetrying: true, withImage: image)
                    return
                } else {
                    // Deletes temporary video files
                    do {
                        if let outputURL = exportSession?.outputURL {
                            try FileManager.default.removeItem(at: outputURL)
                        }
                    } catch {
                    }

                    // Inform user
                    self.showError(withTitle: NSLocalizedString("videoUploadError_title", comment: "Video Upload Error"), andMessage: NSLocalizedString("videoUploadError_unknown", comment: "Sorry, the upload of the video has failed for an unknown error during the MP4 conversion. Error: \(exportSession?.error?.localizedDescription ?? "")"), forRetrying: true, withImage: image)
                    return
                }
            })
        })
    }

#endif

    // The creation date is kept when copying the MOV video file and uploading it with MP4 extension in Piwigo
    // However, it is replaced when exporting the file in Piwigo while the metadata is correct.
    // With this method, the thumbnail is produced correctly

    //-(void)retrieveFullSizeAssetDataFromVideo:(ImageUpload *)image withMimeType:(NSString *)mimeType  // Asynchronous
    //{
    //    // Case of a video…
    //    PHVideoRequestOptions *options = [[PHVideoRequestOptions alloc] init];
    //    // Requests the most recent version of the image asset
    //    options.version = PHVideoRequestOptionsVersionCurrent;
    //    // Requests the highest-quality video available, regardless of how much time it takes to load.
    //    options.deliveryMode = PHVideoRequestOptionsDeliveryModeHighQualityFormat;
    //    // Photos can download the requested video from iCloud.
    //    options.networkAccessAllowed = YES;
    //    // The block Photos calls periodically while downloading the video.
    //    options.progressHandler = ^(double progress,NSError *error,BOOL* stop, NSDictionary* dict) {
    //        NSLog(@"downloading Video from iCloud — progress %lf",progress);
    //    };
    //
    //    // Requests video…
    //    @autoreleasepool {
    //        [[PHImageManager defaultManager] requestAVAssetForVideo:image.imageAsset options:options
    //              resultHandler:^(AVAsset * _Nullable asset, AVAudioMix * _Nullable audioMix, NSDictionary * _Nullable info) {
    //#if defined(DEBUG_UPLOAD)
    //                  NSLog(@"retrieveFullSizeAssetDataFromVideo returned info(%@)", info);
    //#endif
    //                  // Error encountered while retrieving asset?
    //                  if ([info objectForKey:PHImageErrorKey]) {
    //                      NSError *error = [info valueForKey:PHImageErrorKey];
    //#if defined(DEBUG_UPLOAD)
    //                      NSLog(@"=> Error : %@", error.description);
    //#endif
    //                  }
    //
    //                  // We don't accept degraded assets
    //                  if ([[info valueForKey:PHImageResultIsDegradedKey] boolValue]) {
    //                      // This is a degraded version, wait for the next one…
    //                      return;
    //                  }
    //
    //                  // Location of temporary video file
    //                  NSURL *fileURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:image.image]];
    //
    //                  // Deletes temporary file if exists already (might be incomplete, etc.)
    //                  [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
    //
    //                  // Writes to documents folder before uploading to Piwigo server
    //                  if ([asset isKindOfClass:[AVURLAsset class]]) {
    //
    //                      // Simple video
    //                      AVURLAsset *avurlasset = (AVURLAsset*) asset;
    //                      NSLog(@"avurlasset=%@", avurlasset.URL.absoluteString);
    //
    //                      // Creates temporary video file and modify it as needed
    //                      NSError *error;
    //                      if ([[NSFileManager defaultManager] copyItemAtURL:avurlasset.URL toURL:fileURL error:&error]) {
    //                          // Modifies video before upload to Piwigo server
    //                          [self modifyVideo:image atURL:fileURL withMimeType:mimeType];
    //                      } else {
    //                          // Could not copy the video file!
    //#if defined(DEBUG_UPLOAD)
    //                          NSLog(@"=> Error : %@", error.description);
    //#endif
    //                      }
    //                  } else if ([asset isKindOfClass:[AVComposition class]]) {
    //
    ////                      NSURL *avurlasset = [NSURL fileURLWithPath:@"/var/mobile/Media/DCIM/105APPLE/IMG_5374.MOV"];
    ////                      NSLog(@"avurlasset=%@", avurlasset.absoluteString);
    ////
    ////                      // Creates temporary video file and modify it as needed
    ////                      NSError *error;
    ////                      if ([[NSFileManager defaultManager] copyItemAtURL:avurlasset toURL:fileURL error:&error]) {
    ////                          // Modifies video before upload to Piwigo server
    ////                          [self modifyVideo:image atURL:fileURL withMimeType:mimeType];
    ////                      } else {
    ////                          // Could not copy the video file!
    ////#if defined(DEBUG_UPLOAD)
    ////                          NSLog(@"=> Error : %@", error.description);
    ////#endif
    ////                      }
    //
    //                      // AVComposition object, e.g. a Slow-Motion video
    //                      AVMutableComposition *avComp = [(AVComposition*) asset copy];
    //
    //                      // Export Slow-Mo as standard video
    //                      AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:avComp presetName:AVAssetExportPresetHighestQuality];
    //                      [exportSession setOutputURL:fileURL];
    //                      exportSession.outputFileType = AVFileTypeMPEG4;
    ////                      exportSession.outputFileType = AVFileTypeQuickTimeMovie;
    //                      [exportSession setShouldOptimizeForNetworkUse:YES];
    //                      [exportSession exportAsynchronouslyWithCompletionHandler:^{
    //                          // Error ?
    //                          if (exportSession.error) {
    //                              NSLog(@"=> exportSession Status: %ld and Error: %@", (long)exportSession.status, exportSession.error.description);
    //                              return;
    //                          }
    //
    //                          // Modifies video before upload to Piwigo server
    //                          [self modifyVideo:image atURL:exportSession.outputURL withMimeType:mimeType];
    //                      }];
    //                  }
    //              }
    //         ];
    //    }
    //}

    //-(void)modifyVideo:(ImageUpload *)image atURL:(NSURL *)fileURL withMimeType:(NSString *)mimeType
    //{
    //    // Video and metadata from asset
    //    __block NSData *assetData = nil;
    //    AVAsset *videoAsset = [AVAsset assetWithURL:fileURL];
    //    NSArray *assetMetadata = [videoAsset commonMetadata];
    //
    //    // Strips GPS data if user requested it in Settings
    //    if (![Model sharedInstance].stripGPSdataOnUpload || ([assetMetadata count] == 0)) {
    //
    //        // Gets copy as NSData
    //        assetData = [[NSData dataWithContentsOfURL:fileURL] copy];
    //        assert(assetData.length != 0);
    //
    //        // Deletes temporary video file
    //        [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
    //
    //        // Upload video with tags and properties
    //        [self uploadImage:image withData:assetData andMimeType:mimeType];
    //    }
    //    else
    //    {
    //        // Creates metadata without location data
    //        NSMutableArray *newAssetMetadata = [NSMutableArray array];
    //        for (AVMetadataItem *item in assetMetadata) {
    //            if ([item.commonKey isEqualToString:AVMetadataCommonKeyLocation]){
    //#if defined(DEBUG_UPLOAD)
    //                NSLog(@"Location found: %@", item.stringValue);
    //#endif
    //            } else {
    //                [newAssetMetadata addObject:item];
    //            }
    //        }
    //
    //        // Done if metadata did not contain location
    //        if (newAssetMetadata.count == assetMetadata.count) {
    //
    //            // Gets copy as NSData
    //            assetData = [[NSData dataWithContentsOfURL:fileURL] copy];
    //            assert(assetData.length != 0);
    //
    //            // Deletes temporary video file
    //            [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
    //
    //            // Upload video with tags and properties
    //            [self uploadImage:image withData:assetData andMimeType:mimeType];
    //        }
    //        else if ([videoAsset isExportable]) {
    //
    //            // Export new asset from original asset
    //            AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:videoAsset presetName:AVAssetExportPresetPassthrough];
    //            NSLog(@"exportSession (before): %@", exportSession);
    //            NSLog(@"Supported file types: %@", exportSession.supportedFileTypes);
    //
    //            // Filename is ("_" + name + ".mp4") in same directory
    //            NSURL *newFileURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[[@"_" stringByAppendingString:[image.image stringByDeletingPathExtension]] stringByAppendingPathExtension:@"mp4"]]];
    //            exportSession.outputURL = newFileURL;
    //            if ([exportSession.supportedFileTypes containsObject:AVFileTypeMPEG4]) {
    //                exportSession.outputFileType = AVFileTypeMPEG4;
    //            } else {
    //                exportSession.outputFileType = AVFileTypeQuickTimeMovie;
    //            }
    //            exportSession.shouldOptimizeForNetworkUse = YES;
    ////            exportSession.fileLengthLimit ??
    //
    //            // Deletes temporary file if exists already (might be incomplete, etc.)
    //            [[NSFileManager defaultManager] removeItemAtURL:newFileURL error:nil];
    //
    //            // Video range
    //            CMTime start = kCMTimeZero;
    //            CMTimeRange range = CMTimeRangeMake(start, [videoAsset duration]);
    //            exportSession.timeRange = range;
    //
    //            // Updated metadata
    //            exportSession.metadata = newAssetMetadata;
    //
    //            // Export video
    //            [exportSession exportAsynchronouslyWithCompletionHandler:^{
    //                if ([exportSession status] == AVAssetExportSessionStatusCompleted)
    //                {
    //#if defined(DEBUG_UPLOAD)
    //                    NSLog(@"Export sucess…");
    //#endif
    //                    // Gets copy as NSData
    //                    assetData = [[NSData dataWithContentsOfURL:newFileURL] copy];
    //                    AVAsset *videoAsset = [AVAsset assetWithURL:newFileURL];
    //                    NSArray *assetMetadata = [videoAsset commonMetadata];
    //                    NSLog(@"Video metadata: %@", assetMetadata);
    //                    assert(assetData.length != 0);
    //
    //                    // Deletes temporary video files
    //                    [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
    //                    [[NSFileManager defaultManager] removeItemAtURL:newFileURL error:nil];
    //
    //                    // Upload video with tags and properties
    //                    [self uploadImage:image withData:assetData andMimeType:mimeType];
    //                }
    //                else if ([exportSession status] == AVAssetExportSessionStatusFailed)
    //                {
    //#if defined(DEBUG_UPLOAD)
    //                    NSLog(@"Export failed: %@", [[exportSession error] localizedDescription]);
    //#endif
    //                    // Deletes temporary video files
    //                    [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
    //                    [[NSFileManager defaultManager] removeItemAtURL:newFileURL error:nil];
    //
    //                }
    //                else if ([exportSession status] == AVAssetExportSessionStatusCancelled)
    //                {
    //#if defined(DEBUG_UPLOAD)
    //                    NSLog(@"Export canceled");
    //#endif
    //                    // Deletes temporary video files
    //                    [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
    //                    [[NSFileManager defaultManager] removeItemAtURL:newFileURL error:nil];
    //
    //                }
    //                else
    //                {
    //#if defined(DEBUG_UPLOAD)
    //                    NSLog(@"Export ??");
    //#endif
    //                    // Deletes temporary video files
    //                    [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
    //                    [[NSFileManager defaultManager] removeItemAtURL:newFileURL error:nil];
    //
    //                }
    //            }];
    //        }
    //        else {
    //            // Could not export a new video — What to do?
    //        }
    //    }
    //}


// MARK: - Upload image/video

    //-(void)uploadImage:(ImageUpload *)image withMimeType:(NSString *)mimeType
    //{
    //    // Chek that the final image format will be accepted by the Piwigo server
    //    if (![[Model sharedInstance].uploadFileTypes containsString:[[image.fileName pathExtension] lowercaseString]]) {
    //        [self showErrorWithTitle:NSLocalizedString(@"uploadError_title", @"Upload Error")
    //                      andMessage:[NSString stringWithFormat:NSLocalizedString(@"uploadError_message", @"Could not upload your image. Error: %@"), NSLocalizedString(@"imageUploadError_destination", @"cannot create image destination")]
    //                     forRetrying:YES
    //                       withImage:image];
    //        return;
    //    }
    //
    //    // Append Tags
    //    NSMutableArray *tagIds = [NSMutableArray new];
    //    for(PiwigoTagData *tagData in image.tags)
    //    {
    //        [tagIds addObject:@(tagData.tagId)];
    //    }
    //
    //    // Prepare properties for uploaded image/video (filename key is kPiwigoImagesUploadParamFileName)
    //    __block NSDictionary *imageProperties = @{
    //                                      kPiwigoImagesUploadParamFileName : image.fileName,
    //                                      kPiwigoImagesUploadParamTitle : image.imageTitle,
    //                                      kPiwigoImagesUploadParamCategory : [NSString stringWithFormat:@"%@", @(image.categoryToUploadTo)],
    //                                      kPiwigoImagesUploadParamPrivacy : [NSString stringWithFormat:@"%@", @(image.privacyLevel)],
    //                                      kPiwigoImagesUploadParamAuthor : image.author,
    //                                      kPiwigoImagesUploadParamDescription : image.comment,
    //                                      kPiwigoImagesUploadParamTags : [tagIds copy],
    //                                      kPiwigoImagesUploadParamMimeType : mimeType
    //                                      };
    //    tagIds = nil;
    //
    //    // Release memory
    //    imageProperties = nil;
    //    self.imageData = nil;
    //
    //    NSLog(@"END");
    //}
    func uploadImage(_ image: ImageUpload?, withMimeType mimeType: String?) {
        // Chek that the final image format will be accepted by the Piwigo server
        if !(Model.sharedInstance().uploadFileTypes.contains((URL(fileURLWithPath: image?.fileName ?? "").pathExtension).lowercased() ?? "")) {
            showError(withTitle: NSLocalizedString("uploadError_title", comment: "Upload Error"), andMessage: NSLocalizedString("uploadError_message", comment: "Could not upload your image. Error: \(NSLocalizedString("imageUploadError_destination", comment: "cannot create image destination"))"), forRetrying: true, withImage: image)
            return
        }

        // Prepare creation date
        var creationDate = ""
        if image?.creationDate != nil {
            let dateFormat = DateFormatter()
            dateFormat.dateFormat = "yyyy-MM-dd HH:mm:ss"
            if let creationDate1 = image?.creationDate {
                creationDate = dateFormat.string(from: creationDate1)
            }
        }

        // Append Tags
        var tagIds: [AnyHashable] = []
        if let tags = image?.tags {
            for tagData in tags {
                guard let tagData = tagData as? PiwigoTagData else {
                    continue
                }
                tagIds.append(NSNumber(value: tagData.tagId))
            }
        }

        // Prepare properties for uploaded image/video (filename key is kPiwigoImagesUploadParamFileName)
        var imageProperties: [AnyHashable : UnknownType?]? = nil
        if let fileName = image?.fileName, let author = image?.author, let comment = image?.comment {
            imageProperties = [
            kPiwigoImagesUploadParamFileName: fileName,
            kPiwigoImagesUploadParamCreationDate: creationDate,
            kPiwigoImagesUploadParamTitle: image?.imageTitle() ?? "",
            kPiwigoImagesUploadParamCategory: "\(NSNumber(value: image?.categoryToUploadTo))",
            kPiwigoImagesUploadParamPrivacy: "\(NSNumber(value: image?.privacyLevel))",
            kPiwigoImagesUploadParamAuthor: author,
            kPiwigoImagesUploadParamDescription: comment,
            kPiwigoImagesUploadParamTags: tagIds,
            kPiwigoImagesUploadParamMimeType: mimeType ?? ""
        ]
        }
        tagIds = nil

        // Upload photo or video
        UploadService.uploadImage(imageData, withInformation: imageProperties, onProgress: { progress, currentChunk, totalChunks in
            let imageBeingUploaded = self.imageUploadQueue?.first as? ImageUpload
            if imageBeingUploaded?.stopUpload != nil {
                progress?.cancel()
            }
            self.current = Int(progress?.completedUnitCount ?? 0)
            self.total = Int(progress?.totalUnitCount ?? 0)
            self.currentChunk = currentChunk
            self.totalChunks = totalChunks
            if self.delegate?.responds(to: #selector(ImageUploadDelegate.imageProgress(_:onCurrent:forTotal:onChunk:forChunks:iCloudProgress:))) ?? false {
                self.delegate?.imageProgress(image, onCurrent: self.current, forTotal: self.total, onChunk: currentChunk, forChunks: totalChunks, iCloudProgress: self.iCloudProgress)
            }
        }, onCompletion: { task, response in

            if (response?["stat"] == "ok") {
                // Consider image job done
                self.onCurrentImageUpload += 1

                // Get imageId
                let imageResponse = response?["result"] as? [AnyHashable : Any]
                let imageId = (imageResponse?["image_id"] as? NSNumber)?.intValue ?? 0

                // Set properties of uploaded image/video on Piwigo server and add it to cahe
                self.setImage(image, withInfo: imageProperties, andId: imageId)

                // The image must be moderated if the Community plugin is installed
                if Model.sharedInstance().usesCommunityPluginV29 {
                    // Append image to list of images to moderate
                    self.uploadedImagesToBeModerated = self.uploadedImagesToBeModerated ?? "" + (String(format: "%ld,", imageId))
                }

                // Release memory
                imageProperties = nil
                self.imageData = nil

                // Delete image from Photos library if requested
                if Model.sharedInstance().deleteImageAfterUpload && (image?.imageAsset.sourceType != PHAssetSourceType.typeCloudShared) {
                    if let imageAsset = image?.imageAsset {
                        self.imageDeleteQueue?.append(imageAsset)
                    }
                }

                DispatchQueue.main.async(execute: {
                    // Remove image from queue and upload next one
                    self.uploadNextImageAndRemoveImage(fromQueue: image, withResponse: response)
                })
            } else {
                // Release memory
                imageProperties = nil
                self.imageData = nil

                // Display Piwigo error
                var errorMsg = ""
                if response?["message"] != nil {
                    errorMsg = response?["message"] as? String ?? ""
                }
                self.showError(withTitle: NSLocalizedString("uploadError_title", comment: "Upload Error"), andMessage: NSLocalizedString("uploadError_message", comment: "Could not upload your image. Error: \(errorMsg)"), forRetrying: true, withImage: image)
            }

        }, onFailure: { task, error in
            // Release memory
            imageProperties = nil
            self.imageData = nil

            // What should we do?
            let imageBeingUploaded = self.imageUploadQueue?.first as? ImageUpload
            if imageBeingUploaded?.stopUpload != nil {

                // Upload was cancelled by user
                self.maximumImagesForBatch -= 1

                // Remove image from queue and upload next one
                self.uploadNextImageAndRemoveImage(fromQueue: image, withResponse: nil)
            } else {
            #if DEBUG_UPLOAD
                if let error = error {
                    print("ERROR IMAGE UPLOAD: \(error)")
                }
            #endif
                // Inform user and propose to cancel or continue
                self.showError(withTitle: NSLocalizedString("uploadError_title", comment: "Upload Error"), andMessage: NSLocalizedString("uploadError_message", comment: "Could not upload your image. Error: \(error?.localizedDescription ?? "")"), forRetrying: true, withImage: image)
            }
        })
    }

    func showError(withTitle title: String?, andMessage message: String?, forRetrying retry: Bool, withImage image: ImageUpload?) {
        // Determine present view controller
        var topViewController = UIApplication.shared.keyWindow?.rootViewController
        while topViewController?.presentedViewController {
            topViewController = topViewController?.presentedViewController
        }

        // Present alert
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)

        let dismissAction = UIAlertAction(title: NSLocalizedString("alertDismissButton", comment: "Dismiss"), style: .cancel, handler: { action in

                // Consider image job done
                self.onCurrentImageUpload += 1

                // Empty queue
                while (self.imageUploadQueue?.count ?? 0) > 0 {
                    self.onCurrentImageUpload += 1
                    let nextImage = self.imageUploadQueue?.first as? ImageUpload
                    self.imageUploadQueue?.remove(at: 0)
                    self.imageNamesUploadQueue?.removeAll { $0 as AnyObject === URL(fileURLWithPath: nextImage?.fileName ?? "").deletingPathExtension().absoluteString as AnyObject }
                }

                // Tell user how many images have been uploaded
                if self.delegate?.responds(to: #selector(ImageUploadDelegate.imageUploaded(_:placeInQueue:outOf:withResponse:))) ?? false {
                    self.delegate?.imageUploaded(image, placeInQueue: self.onCurrentImageUpload, outOf: self.maximumImagesForBatch, withResponse: nil)
                }

                // Stop uploading
                self.isUploading = false
            })

        // Should we propose to retry?
        if retry {
            // Retry to upload the image
            let retryAction = UIAlertAction(title: NSLocalizedString("alertRetryButton", comment: "Retry"), style: .default, handler: { action in
                    // Upload image
                    self.uploadNextImage()
                })
            alert.addAction(retryAction)
        }

        // Should we propose to upload the next image
        if (imageUploadQueue?.count ?? 0) > 1 {
            let nextAction = UIAlertAction(title: NSLocalizedString("alertNextButton", comment: "Next Image"), style: .default, handler: { action in

                    // Consider image job done
                    self.onCurrentImageUpload += 1

                    // Remove image from queue and upload next one
                    self.uploadNextImageAndRemoveImage(fromQueue: image, withResponse: nil)
                })
            alert.addAction(nextAction)
        }

        alert.addAction(dismissAction)
        alert.view.tintColor = UIColor.piwigoColorOrange
        if #available(iOS 13.0, *) {
            alert.overrideUserInterfaceStyle = Model.sharedInstance().isDarkPaletteActive ? .dark : .light
        } else {
            // Fallback on earlier versions
        }
        topViewController?.present(alert, animated: true) {
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            alert.view.tintColor = UIColor.piwigoColorOrange
        }
    }

// MARK: - Finish image upload
    func setImage(_ image: ImageUpload?, withInfo imageInfo: [AnyHashable : Any]?, andId imageId: Int) {
        // Set properties of image on Piwigo server
        ImageService.setImageInfoForImageWithId(imageId, withInformation: imageInfo, onProgress: { progress in
            // progress
        }, onCompletion: { task, response in

            if (response?["stat"] == "ok") {
                // Increment number of images in category
                CategoriesData.sharedInstance().getCategoryById(image?.categoryToUploadTo).incrementImageSizeByOne()

                // Read image/video information and update cache
                self.addImageData(toCategoryCache: imageId)
            } else {
                // Display Piwigo error in HUD
                let error = NetworkHandler.getPiwigoError(fromResponse: response, path: kPiwigoImageSetInfo, andURLparams: nil)
                self.showError(withTitle: NSLocalizedString("uploadError_title", comment: "Upload Error"), andMessage: error?.localizedDescription, forRetrying: false, withImage: image)
            }
        }, onFailure: { task, error in
            // Inform user and propose to cancel or continue
            self.showError(withTitle: NSLocalizedString("uploadError_title", comment: "Upload Error"), andMessage: error?.localizedDescription, forRetrying: false, withImage: image)
        })
    }

    func addImageData(toCategoryCache imageId: Int) {
        // Read image information and update cache
        ImageService.getImageInfo(byId: imageId, andAddImageToCache: true, listOnCompletion: { task, imageData in
            // Post to the app that the category data have been updated
            //                          NSDictionary *userInfo = @{@"NoHUD" : @"YES", @"fromCache" : @"NO"};
            //                          [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationGetCategoryData object:nil userInfo:userInfo];
            NotificationCenter.default.post(name: kPiwigoNotificationCategoryDataUpdated, object: nil, userInfo: nil)
        }, onFailure: { task, error in
            //
        })
    }

// MARK: - Scale, crop, rotate, etc. image before upload
    
    func fixOrientationOf(_ image: UIImage?) -> UIImage? {

        // No-op if the orientation is already correct
        if image?.imageOrientation == .up {
            return image
        }

        // We need to calculate the proper transformation to make the image upright.
        // We do it in 2 steps: Rotate if Left/Right/Down, and then flip if Mirrored.
        var transform: CGAffineTransform = .identity

        switch image?.imageOrientation {
            case .down, .downMirrored:
                transform = transform.translatedBy(x: image?.size.width, y: image?.size.height)
                transform = transform.rotated(by: .pi)
            case .left, .leftMirrored:
                transform = transform.translatedBy(x: image?.size.width, y: 0)
                transform = transform.rotated(by: M_PI_2)
            case .right, .rightMirrored:
                transform = transform.translatedBy(x: 0, y: image?.size.height)
                transform = transform.rotated(by: -M_PI_2)
            case .up, .upMirrored:
                break
            @unknown default:
                break
        }

        switch image?.imageOrientation {
            case .upMirrored, .downMirrored:
                transform = transform.translatedBy(x: image?.size.width, y: 0)
                transform = transform.scaledBy(x: -1, y: 1)
            case .leftMirrored, .rightMirrored:
                transform = transform.translatedBy(x: image?.size.height, y: 0)
                transform = transform.scaledBy(x: -1, y: 1)
            case .up, .down, .left, .right:
                break
            @unknown default:
                break
        }

        // Now we draw the underlying CGImage into a new context, applying the transform
        // calculated above.
        let ctx = CGContext(data: nil, width: image?.size.width, height: image?.size.height, bitsPerComponent: image?.cgImage?.bitsPerComponent, bytesPerRow: 0, space: image?.cgImage?.colorSpace, bitmapInfo: image?.cgImage?.bitmapInfo)
        ctx?.concatenate(transform)
        switch image?.imageOrientation {
            case .left, .leftMirrored, .right, .rightMirrored:
                // Grr...
                ctx?.draw(in: image?.cgImage, image: CGRect(x: 0, y: 0, width: image?.size.height ?? 0.0, height: image?.size.width ?? 0.0))
            default:
                ctx?.draw(in: image?.cgImage, image: CGRect(x: 0, y: 0, width: image?.size.width ?? 0.0, height: image?.size.height ?? 0.0))
        }

        // And now we just create a new UIImage from the drawing context
        let cgimg = ctx?.makeImage()
        var img: UIImage? = nil
        if let cgimg = cgimg {
            img = UIImage(cgImage: cgimg)
        }
        CGContextRelease(ctx)
        CGImageRelease(cgimg)
        return img
    }

    func rotateImage(_ imageIn: UIImage?, andScaleItTo scaleRatio: CGFloat) -> UIImage? {
        let imgRef = imageIn?.cgImage
        let width = CGFloat(imgRef?.width)
        let height = CGFloat(imgRef?.height)
        var transform: CGAffineTransform = .identity
        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        bounds.size.width = width * scaleRatio
        bounds.size.height = height * scaleRatio

        let imageSize = CGSize(width: CGFloat(imgRef?.width), height: CGFloat(imgRef?.height))
        let orient = imageIn?.imageOrientation
        var boundHeight: CGFloat

        switch orient {
            case .up /*EXIF = 1 */:
                transform = .identity
            case .upMirrored /*EXIF = 2 */:
                transform = CGAffineTransform(translationX: imageSize.width, y: 0.0)
                transform = transform.scaledBy(x: -1.0, y: 1.0)
            case .down /*EXIF = 3 */:
                transform = CGAffineTransform(translationX: imageSize.width, y: imageSize.height)
                transform = transform.rotated(by: .pi)
            case .downMirrored /*EXIF = 4 */:
                transform = CGAffineTransform(translationX: 0.0, y: imageSize.height)
                transform = transform.scaledBy(x: 1.0, y: -1.0)
            case .leftMirrored /*EXIF = 5 */:
                boundHeight = bounds.size.height
                bounds.size.height = bounds.size.width
                bounds.size.width = boundHeight
                transform = CGAffineTransform(translationX: imageSize.height, y: imageSize.width)
                transform = transform.scaledBy(x: -1.0, y: 1.0)
                transform = transform.rotated(by: 3.0 * .pi / 2.0)
            case .left /*EXIF = 6 */:
                boundHeight = bounds.size.height
                bounds.size.height = bounds.size.width
                bounds.size.width = boundHeight
                transform = CGAffineTransform(translationX: 0.0, y: imageSize.width)
                transform = transform.rotated(by: 3.0 * .pi / 2.0)
            case .rightMirrored /*EXIF = 7 */:
                boundHeight = bounds.size.height
                bounds.size.height = bounds.size.width
                bounds.size.width = boundHeight
                transform = CGAffineTransform(scaleX: -1.0, y: 1.0)
                transform = transform.rotated(by: .pi / 2.0)
            case .right /*EXIF = 8 */:
                boundHeight = bounds.size.height
                bounds.size.height = bounds.size.width
                bounds.size.width = boundHeight
                transform = CGAffineTransform(translationX: imageSize.height, y: 0.0)
                transform = transform.rotated(by: .pi / 2.0)
            default:
                NSException.raise(NSExceptionName.internalInconsistencyException, format: "Invalid image orientation")
        }

        UIGraphicsBeginImageContext(bounds.size)

        let context = UIGraphicsGetCurrentContext()

        if orient == .right || orient == .left {
            context?.scaleBy(x: -scaleRatio, y: scaleRatio)
            context?.translateBy(x: -height, y: 0)
        } else {
            context?.scaleBy(x: scaleRatio, y: -scaleRatio)
            context?.translateBy(x: 0, y: -height)
        }

        context?.concatenate(transform)

        UIGraphicsGetCurrentContext()?.draw(in: imgRef, image: CGRect(x: 0, y: 0, width: width, height: height))
        let imageCopy = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return imageCopy
    }

    func scale(_ image: UIImage?, to newSize: CGSize, contentMode: UIView.ContentMode) -> UIImage? {
        if contentMode == .scaleToFill {
            return self.image(image, byScalingToFill: newSize)
        } else if (contentMode == .scaleAspectFill) || (contentMode == .scaleAspectFit) {
            let horizontalRatio = (image?.size.width ?? 0.0) / newSize.width
            let verticalRatio = (image?.size.height ?? 0.0) / newSize.height
            var ratio: CGFloat

            if contentMode == .scaleAspectFill {
                ratio = min(horizontalRatio, verticalRatio)
            } else {
                ratio = max(horizontalRatio, verticalRatio)
            }

            let sizeForAspectScale = CGSize(width: (image?.size.width ?? 0.0) / ratio, height: (image?.size.height ?? 0.0) / ratio)

            var newImage = self.image(image, byScalingToFill: sizeForAspectScale)

            // if we're doing aspect fill, then the image still needs to be cropped
            if contentMode == .scaleAspectFill {
                let subRect = CGRect(x: floor((sizeForAspectScale.width - newSize.width) / 2.0), y: floor((sizeForAspectScale.height - newSize.height) / 2.0), width: newSize.width, height: newSize.height)
                newImage = self.image(newImage, byCroppingToBounds: subRect)
            }

            return newImage
        }

        return nil
    }

    func image(_ image: UIImage?, byCroppingToBounds bounds: CGRect) -> UIImage? {
        let imageRef = image?.cgImage?.cropping(to: bounds) as? CGImage
        var croppedImage: UIImage? = nil
        if let imageRef = imageRef {
            croppedImage = UIImage(cgImage: imageRef)
        }
        CGImageRelease(imageRef)
        return croppedImage
    }

    func image(_ image: UIImage?, byScalingToFill newSize: CGSize) -> UIImage? {
        UIGraphicsBeginImageContext(newSize)
        image?.draw(in: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage
    }

    func image(_ image: UIImage?, byScalingAspectFill newSize: CGSize) -> UIImage? {
        return scale(image, to: newSize, contentMode: .scaleAspectFill)
    }

    func image(_ image: UIImage?, byScalingAspectFit newSize: CGSize) -> UIImage? {
        return scale(image, to: newSize, contentMode: .scaleAspectFit)
    }
}

#if !DEBUG_UPLOAD
//#define DEBUG_UPLOAD
#endif
