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

        // Download image of optimum size (depends on Piwigo server settings)
        /// - Check available image sizes from the smallest to the highest resolution
        /// - Note: image.width and .height are always > 1
        var selectedURLRequest = ""
        var selectedSize = Int.zero

        // Square Size (should always be available)
        if let squarePath = image.squarePath, !squarePath.isEmpty {
            // Max dimension of this image
            let size = max(image.squareWidth, image.squareHeight)
            // Ensure that at least an URL will be returned
            if selectedURLRequest.isEmpty {
                selectedURLRequest = squarePath
                selectedSize = size
            }
        }

        // Thumbnail Size (should always be available)
        if let thumbPath = image.thumbPath, !thumbPath.isEmpty {
            // Max dimension of this image
            let size = max(image.thumbWidth, image.thumbHeight)
            // Ensure that at least an URL will be returned
            if selectedURLRequest.isEmpty {
                selectedURLRequest = thumbPath
                selectedSize = size
            }
            // Is this resolution more appropriate?
            if size < wantedSize, abs(wantedSize - size) < abs(wantedSize - selectedSize) {
                selectedURLRequest = thumbPath
                selectedSize = size
            }
        }

        // XX Small Size
        if let xxSmallPath = image.xxSmallPath, !xxSmallPath.isEmpty {
            // Max dimension of this image
            let size = max(image.xxSmallWidth, image.xxSmallHeight)
            // Ensure that at least an URL will be returned
            if selectedURLRequest.isEmpty {
                selectedURLRequest = xxSmallPath
                selectedSize = size
            }
            // Is this resolution more appropriate?
            if size < wantedSize, abs(wantedSize - size) < abs(wantedSize - selectedSize) {
                selectedURLRequest = xxSmallPath
                selectedSize = size
            }
        }

        // X Small Size
        if let xSmallPath = image.xSmallPath, !xSmallPath.isEmpty {
            // Max dimension of this image
            let size = max(image.xSmallWidth, image.xSmallHeight)
            // Ensure that at least an URL will be returned
            if selectedURLRequest.isEmpty {
                selectedURLRequest = xSmallPath
                selectedSize = size
            }
            // Is this resolution more appropriate?
            if size < wantedSize, abs(wantedSize - size) < abs(wantedSize - selectedSize) {
                selectedURLRequest = xSmallPath
                selectedSize = size
            }
        }

        // Small Size
        if let smallPath = image.smallPath, !smallPath.isEmpty {
            // Max dimension of this image
            let size = max(image.smallWidth, image.smallHeight)
            // Ensure that at least an URL will be returned
            if selectedURLRequest.isEmpty {
                selectedURLRequest = smallPath
                selectedSize = size
            }
            // Is this resolution more appropriate?
            if size < wantedSize, abs(wantedSize - size) < abs(wantedSize - selectedSize) {
                selectedURLRequest = smallPath
                selectedSize = size
            }
        }

        // Medium Size (should always be available)
        if let mediumPath = image.mediumPath, !mediumPath.isEmpty {
            // Max dimension of this image
            let size = max(image.mediumWidth, image.mediumHeight)
            // Ensure that at least an URL will be returned
            if selectedURLRequest.isEmpty {
                selectedURLRequest = mediumPath
                selectedSize = size
            }
            // Is this resolution more appropriate?
            if size < wantedSize, abs(wantedSize - size) < abs(wantedSize - selectedSize) {
                selectedURLRequest = mediumPath
                selectedSize = size
            }
        }

        // Large Size
        if let largePath = image.largePath, !largePath.isEmpty {
            // Max dimension of this image
            let size = max(image.largeWidth, image.largeHeight)
            // Ensure that at least an URL will be returned
            if selectedURLRequest.isEmpty {
                selectedURLRequest = largePath
                selectedSize = size
            }
            // Is this resolution more appropriate?
            if size < wantedSize, abs(wantedSize - size) < abs(wantedSize - selectedSize) {
                selectedURLRequest = largePath
                selectedSize = size
            }
        }

        // X Large Size
        if let xLargePath = image.xLargePath, !xLargePath.isEmpty {
            // Max dimension of this image
            let size = max(image.xLargeWidth, image.xLargeHeight)
            // Ensure that at least an URL will be returned
            if selectedURLRequest.isEmpty {
                selectedURLRequest = xLargePath
                selectedSize = size
            }
            // Is this resolution more appropriate?
            if size < wantedSize, abs(wantedSize - size) < abs(wantedSize - selectedSize) {
                selectedURLRequest = xLargePath
                selectedSize = size
            }
        }

        // XX Large Size
        if let xxLargePath = image.xxLargePath, !xxLargePath.isEmpty {
            // Max dimension of this image
            let size = max(image.xxLargeWidth, image.xxLargeHeight)
            // Ensure that at least an URL will be returned
            if selectedURLRequest.isEmpty {
                selectedURLRequest = xxLargePath
                selectedSize = size
            }
            // Is this resolution more appropriate?
            if size < wantedSize, abs(wantedSize - size) < abs(wantedSize - selectedSize) {
                selectedURLRequest = xxLargePath
                selectedSize = size
            }
        }

        // Full Resolution
        if let fullResPath = image.fullResPath, !fullResPath.isEmpty {
            // Max dimension of this image
            let size = max(image.fullResWidth, image.fullResHeight)
            // Ensure that at least an URL will be returned
            if selectedURLRequest.isEmpty {
                selectedURLRequest = fullResPath
                selectedSize = size
            }
            // Is this resolution more appropriate?
            if size < wantedSize, abs(wantedSize - size) < abs(wantedSize - selectedSize) {
                selectedURLRequest = fullResPath
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
        let task = Model.sharedInstance().imagesSessionManager.downloadTask(
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
                if !Model.sharedInstance().shareMetadataTypeAirDrop {
                    return true
                }
            case .assignToContact:
                if !Model.sharedInstance().shareMetadataTypeAssignToContact {
                    return true
                }
            case .copyToPasteboard:
                if !Model.sharedInstance().shareMetadataTypeCopyToPasteboard {
                    return true
                }
            case .mail:
                if !Model.sharedInstance().shareMetadataTypeMail {
                    return true
                }
            case .message:
                if !Model.sharedInstance().shareMetadataTypeMessage {
                    return true
                }
            case .postToFacebook:
                if !Model.sharedInstance().shareMetadataTypePostToFacebook {
                    return true
                }
            case kPiwigoActivityTypeMessenger:
                if !Model.sharedInstance().shareMetadataTypeMessenger {
                    return true
                }
            case .postToFlickr:
                if !Model.sharedInstance().shareMetadataTypePostToFlickr {
                    return true
                }
            case kPiwigoActivityTypePostInstagram:
                if !Model.sharedInstance().shareMetadataTypePostInstagram {
                    return true
                }
            case kPiwigoActivityTypePostToSignal:
                if !Model.sharedInstance().shareMetadataTypePostToSignal {
                    return true
                }
            case kPiwigoActivityTypePostToSnapchat:
                if !Model.sharedInstance().shareMetadataTypePostToSnapchat {
                    return true
                }
            case .postToTencentWeibo:
                if !Model.sharedInstance().shareMetadataTypePostToTencentWeibo {
                    return true
                }
            case .postToTwitter:
                if !Model.sharedInstance().shareMetadataTypePostToTwitter {
                    return true
                }
            case .postToVimeo:
                if !Model.sharedInstance().shareMetadataTypePostToVimeo {
                    return true
                }
            case .postToWeibo:
                if !Model.sharedInstance().shareMetadataTypePostToWeibo {
                    return true
                }
            case kPiwigoActivityTypePostToWhatsApp:
                if !Model.sharedInstance().shareMetadataTypePostToWhatsApp {
                    return true
                }
            case .saveToCameraRoll:
                if !Model.sharedInstance().shareMetadataTypeSaveToCameraRoll {
                    return true
                }
            default:
                if !Model.sharedInstance().shareMetadataTypeOther {
                    return true
                }
            }
        } else {
            // Single On/Off share metadata option (use first boolean)
            if !Model.sharedInstance().shareMetadataTypeAirDrop {
                return true
            }
        }
        return false
    }
}
