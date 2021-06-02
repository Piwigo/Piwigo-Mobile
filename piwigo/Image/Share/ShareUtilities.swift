//
//  ShareUtilities.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 07/01/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation

class ShareUtilities {
    
    // MARK: - Image Download
    /// - Get the URL of the image file stored on the Piwigo server whose resolution matches the one expected by the activity type
    /// - Get the URL of image file that will be stored temporarily on the device before the share
    /// - Download the image file and store it in /tmp.
    
    // URL request of image to download
    class func getUrlRequest(forImage image: PiwigoImageData,
                             withMaxSize wantedSize: Int) -> URLRequest? {
        // If this is a video, always select the full resolution file, i.e. the video.
        if image.isVideo {
            // NOP if no image can be downloaded
            if image.fullResPath.isEmpty { return nil }
            if let url = URL(string: image.fullResPath) {
                return URLRequest(url: url)
            }
            return nil
        }
        
        // Download image of optimum size (depends on Piwigo server settings)
        /// - Check available image sizes from the smallest to the highest resolution
        /// - Note: image.width and .height are always > 1
        var selectedURLRequest = ""
        var selectedSize = Int.zero

        // Square Size (should always be available)
        if !image.squarePath.isEmpty {
            // Max dimension of this image
            let size = max(image.squareWidth, image.squareHeight)
            // Ensure that at least an URL will be returned
            if selectedURLRequest.isEmpty {
                selectedURLRequest = image.squarePath
                selectedSize = size
            }
        }

        // Thumbnail Size (should always be available)
        if !image.thumbPath.isEmpty {
            // Max dimension of this image
            let size = max(image.thumbWidth, image.thumbHeight)
            // Ensure that at least an URL will be returned
            if selectedURLRequest.isEmpty {
                selectedURLRequest = image.thumbPath
                selectedSize = size
            }
            // Is this resolution more appropriate?
            if size < wantedSize, abs(wantedSize - size) < abs(wantedSize - selectedSize) {
                selectedURLRequest = image.thumbPath
                selectedSize = size
            }
        }

        // XX Small Size
        if !image.xxSmallPath.isEmpty {
            // Max dimension of this image
            let size = max(image.xxSmallWidth, image.xxSmallHeight)
            // Ensure that at least an URL will be returned
            if selectedURLRequest.isEmpty {
                selectedURLRequest = image.xxSmallPath
                selectedSize = size
            }
            // Is this resolution more appropriate?
            if size < wantedSize, abs(wantedSize - size) < abs(wantedSize - selectedSize) {
                selectedURLRequest = image.xxSmallPath
                selectedSize = size
            }
        }

        // X Small Size
        if !image.xSmallPath.isEmpty {
            // Max dimension of this image
            let size = max(image.xSmallWidth, image.xSmallHeight)
            // Ensure that at least an URL will be returned
            if selectedURLRequest.isEmpty {
                selectedURLRequest = image.xSmallPath
                selectedSize = size
            }
            // Is this resolution more appropriate?
            if size < wantedSize, abs(wantedSize - size) < abs(wantedSize - selectedSize) {
                selectedURLRequest = image.xSmallPath
                selectedSize = size
            }
        }

        // Small Size
        if !image.smallPath.isEmpty {
            // Max dimension of this image
            let size = max(image.smallWidth, image.smallHeight)
            // Ensure that at least an URL will be returned
            if selectedURLRequest.isEmpty {
                selectedURLRequest = image.smallPath
                selectedSize = size
            }
            // Is this resolution more appropriate?
            if size < wantedSize, abs(wantedSize - size) < abs(wantedSize - selectedSize) {
                selectedURLRequest = image.smallPath
                selectedSize = size
            }
        }

        // Medium Size (should always be available)
        if !image.mediumPath.isEmpty {
            // Max dimension of this image
            let size = max(image.mediumWidth, image.mediumHeight)
            // Ensure that at least an URL will be returned
            if selectedURLRequest.isEmpty {
                selectedURLRequest = image.mediumPath
                selectedSize = size
            }
            // Is this resolution more appropriate?
            if size < wantedSize, abs(wantedSize - size) < abs(wantedSize - selectedSize) {
                selectedURLRequest = image.mediumPath
                selectedSize = size
            }
        }

        // Large Size
        if !image.largePath.isEmpty {
            // Max dimension of this image
            let size = max(image.largeWidth, image.largeHeight)
            // Ensure that at least an URL will be returned
            if selectedURLRequest.isEmpty {
                selectedURLRequest = image.largePath
                selectedSize = size
            }
            // Is this resolution more appropriate?
            if size < wantedSize, abs(wantedSize - size) < abs(wantedSize - selectedSize) {
                selectedURLRequest = image.largePath
                selectedSize = size
            }
        }

        // X Large Size
        if !image.xLargePath.isEmpty {
            // Max dimension of this image
            let size = max(image.xLargeWidth, image.xLargeHeight)
            // Ensure that at least an URL will be returned
            if selectedURLRequest.isEmpty {
                selectedURLRequest = image.xLargePath
                selectedSize = size
            }
            // Is this resolution more appropriate?
            if size < wantedSize, abs(wantedSize - size) < abs(wantedSize - selectedSize) {
                selectedURLRequest = image.xLargePath
                selectedSize = size
            }
        }

        // XX Large Size
        if !image.xxLargePath.isEmpty {
            // Max dimension of this image
            let size = max(image.xxLargeWidth, image.xxLargeHeight)
            // Ensure that at least an URL will be returned
            if selectedURLRequest.isEmpty {
                selectedURLRequest = image.xxLargePath
                selectedSize = size
            }
            // Is this resolution more appropriate?
            if size < wantedSize, abs(wantedSize - size) < abs(wantedSize - selectedSize) {
                selectedURLRequest = image.xxLargePath
                selectedSize = size
            }
        }

        // Full Resolution
        if !image.fullResPath.isEmpty {
            // Max dimension of this image
            let size = max(image.fullResWidth, image.fullResHeight)
            // Ensure that at least an URL will be returned
            if selectedURLRequest.isEmpty {
                selectedURLRequest = image.fullResPath
                selectedSize = size
            }
            // Is this resolution more appropriate?
            if size < wantedSize, abs(wantedSize - size) < abs(wantedSize - selectedSize) {
                selectedURLRequest = image.fullResPath
                selectedSize = size
            }
        }

        // NOP if no image can be downloaded
        if selectedURLRequest.isEmpty {
            return nil
        }

        if let url = URL(string: selectedURLRequest) {
            return URLRequest(url: url)
        }
        
        return nil
    }
    
    
    // URL of the image file stored in /tmp before the share
    class func getFileUrl(ofImage image: PiwigoImageData?,
                          withURLrequest urlRequest: URLRequest?) -> URL {
        // Get filename from URL request
        var fileName = urlRequest?.url?.lastPathComponent

        // Is filename of original image a PHP request?
        if fileName?.contains(".php") ?? false {
            // The URL does not contain a file name but a PHP request
            // Sometimes happening with full resolution images, try with medium resolution file
            fileName = URL(string: image?.mediumPath ?? "")?.lastPathComponent
            
            // Is filename of medium size image still a PHP request?
            if fileName?.contains(".php") ?? false {
                // The URL does not contain a unique file name but a PHP request
                // Try using the filename stored in Piwigo image data
                if (image?.fileName.count ?? 0) > 0 {
                    // Use the image file name returned by Piwigo
                    fileName = image?.fileName
                } else {
                    // Try to build filename from creation date
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyyMMdd-HHmmssSSSS"
                    if let creationDate = image?.dateCreated {
                        fileName = dateFormatter.string(from: creationDate)
                    } else if let postedDate = image?.datePosted {
                        fileName = dateFormatter.string(from: postedDate)
                    } else {
                        fileName = dateFormatter.string(from: Date())
                    }
                }
            }
        }
        
        // Check that the filename has an extension
        if URL(string: fileName!)?.pathExtension.count == 0 {
            // And append guessed extension
            if image?.isVideo ?? false {
                // Videos are generally exported in MP4 format
                fileName = fileName?.appending(".mp4")
            } else  {
                // Adopt JPEG photo format by default, will be rechecked
                fileName = fileName?.appending(".jpg")
            }
        }
        
        // Shared files are saved in the /Share directory and will be deleted:
        // - by the app if the user kills it
        // - by the system after a certain amount of time
        let tempDirectoryUrl = URL(fileURLWithPath: NSTemporaryDirectory())
        return tempDirectoryUrl.appendingPathComponent(fileName ?? "PiwigoImage.jpg")
    }

    
    // Download image from the Piwigo server
    class func downloadImage(with piwigoData: PiwigoImageData, at urlRequest: URLRequest,
                             onProgress progress: @escaping (Progress?) -> Void,
                             completionHandler: @escaping (_ response: URLResponse?, _ filePath: URL?, _ error: Error?) -> Void
                             ) -> URLSessionDownloadTask? {
        // Download and save image in /tmp directory
        guard let manager = NetworkVars.shared.imagesSessionManager else { return nil}
        let task = manager.downloadTask(
            with: urlRequest,
            progress: progress,
            destination: { targetPath, response in
                return self.getFileUrl(ofImage: piwigoData, withURLrequest: urlRequest)
            },
            completionHandler: completionHandler)
        task.resume()
        return task
    }
}


// MARK: - UIActivityType Extensions
extension UIActivity.ActivityType: Comparable {
    
    // Allows to compare and sort activity types
    public static func < (lhs: UIActivity.ActivityType, rhs: UIActivity.ActivityType) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    // Return the maximum resolution accepted for some activity types
    func imageMaxSize() -> Int {
        // Get the maximum image size according to the activity type (infinity if no limit)
        /// - See https://makeawebsitehub.com/social-media-image-sizes-cheat-sheet/
        /// - High resolution for: AirDrop, Copy, Mail, Message, iBooks, Flickr, Print, SaveToCameraRoll
        var maxSize = Int.max
        if #available(iOS 10, *) {
            switch self {
            case .assignToContact:
                maxSize = 1024
            case .postToFacebook:
                maxSize = 1200
            case .postToTencentWeibo:
                maxSize = 640 // 9 images max + 1 video
            case .postToTwitter:
                maxSize = 880 // 4 images max
            case .postToWeibo:
                maxSize = 640 // 9 images max + 1 video
            case kPiwigoActivityTypePostToWhatsApp:
                maxSize = 1920
            case kPiwigoActivityTypePostToSignal:
                maxSize = 1920
            case kPiwigoActivityTypeMessenger:
                maxSize = 1920
            case kPiwigoActivityTypePostInstagram:
                maxSize = 1080
            default:
                maxSize = Int.max
            }
        }
        return maxSize
    }

    func shouldStripMetadata() -> Bool {
        // Return whether the user wants to strip metadata
        /// - The flag are set in Settings / Images / Share Metadata
        if #available(iOS 10, *) {
            switch self {
            case .airDrop:
                if !ImageVars.shared.shareMetadataTypeAirDrop {
                    return true
                }
            case .assignToContact:
                if !ImageVars.shared.shareMetadataTypeAssignToContact {
                    return true
                }
            case .copyToPasteboard:
                if !ImageVars.shared.shareMetadataTypeCopyToPasteboard {
                    return true
                }
            case .mail:
                if !ImageVars.shared.shareMetadataTypeMail {
                    return true
                }
            case .message:
                if !ImageVars.shared.shareMetadataTypeMessage {
                    return true
                }
            case .postToFacebook:
                if !ImageVars.shared.shareMetadataTypePostToFacebook {
                    return true
                }
            case kPiwigoActivityTypeMessenger:
                if !ImageVars.shared.shareMetadataTypeMessenger {
                    return true
                }
            case .postToFlickr:
                if !ImageVars.shared.shareMetadataTypePostToFlickr {
                    return true
                }
            case kPiwigoActivityTypePostInstagram:
                if !ImageVars.shared.shareMetadataTypePostInstagram {
                    return true
                }
            case kPiwigoActivityTypePostToSignal:
                if !ImageVars.shared.shareMetadataTypePostToSignal {
                    return true
                }
            case kPiwigoActivityTypePostToSnapchat:
                if !ImageVars.shared.shareMetadataTypePostToSnapchat {
                    return true
                }
            case .postToTencentWeibo:
                if !ImageVars.shared.shareMetadataTypePostToTencentWeibo {
                    return true
                }
            case .postToTwitter:
                if !ImageVars.shared.shareMetadataTypePostToTwitter {
                    return true
                }
            case .postToVimeo:
                if !ImageVars.shared.shareMetadataTypePostToVimeo {
                    return true
                }
            case .postToWeibo:
                if !ImageVars.shared.shareMetadataTypePostToWeibo {
                    return true
                }
            case kPiwigoActivityTypePostToWhatsApp:
                if !ImageVars.shared.shareMetadataTypePostToWhatsApp {
                    return true
                }
            case .saveToCameraRoll:
                if !ImageVars.shared.shareMetadataTypeSaveToCameraRoll {
                    return true
                }
            default:
                if !ImageVars.shared.shareMetadataTypeOther {
                    return true
                }
            }
        } else {
            // Single On/Off share metadata option (use first boolean)
            if !ImageVars.shared.shareMetadataTypeAirDrop {
                return true
            }
        }
        return false
    }
}
