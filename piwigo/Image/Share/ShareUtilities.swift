//
//  ShareUtilities.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 07/01/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit

class ShareUtilities {
    
    // MARK: - Image Download
    /// - Get the URL of the image file stored on the Piwigo server whose resolution matches the one expected by the activity type
    /// - Get the URL of image file that will be stored temporarily on the device before the share
    /// - Download the image file and store it in /tmp.
    
    // URL request of image to download
    class func getUrlRequest(forImage image: Image,
                             withMaxSize wantedSize: Int) -> URLRequest? {
        // If this is a video, always select the full resolution file, i.e. the video.
        if image.isVideo {
            // NOP if no image can be downloaded
            guard let fileURL = image.fullRes?.url as? URL else {
                return nil
            }
            return URLRequest(url: fileURL)
        }
        
        // Download image of optimum size (depends on Piwigo server settings)
        /// - Check available image sizes from the smallest to the highest resolution
        /// - Note: image.width and .height are always > 1
        var selectedURL: URL?
        var selectedSize = Int.zero

        // Square Size (should always be available)
        if let fileURL = image.squareRes?.url as? URL {
            // Max dimension of this image
            let size = max(image.squareRes?.width ?? 1, image.squareRes?.height ?? 1)
            // Ensure that at least an URL will be returned
            if selectedURL == nil {
                selectedURL = fileURL
                selectedSize = size
            }
        }

        // Thumbnail Size (should always be available)
        if let fileURL = image.thumbRes?.url as? URL {
            // Max dimension of this image
            let size = max(image.thumbRes?.width ?? 1, image.thumbRes?.height ?? 1)
            // Ensure that at least an URL will be returned
            if selectedURL == nil {
                selectedURL = fileURL
                selectedSize = size
            }
            // Is this resolution more appropriate?
            if size < wantedSize, abs(wantedSize - size) < abs(wantedSize - selectedSize) {
                selectedURL = fileURL
                selectedSize = size
            }
        }

        // XX Small Size
        if let fileURL = image.xxsmallRes?.url as? URL {
            // Max dimension of this image
            let size = max(image.xxsmallRes?.width ?? 1, image.xxsmallRes?.height ?? 1)
            // Ensure that at least an URL will be returned
            if selectedURL == nil {
                selectedURL = fileURL
                selectedSize = size
            }
            // Is this resolution more appropriate?
            if size < wantedSize, abs(wantedSize - size) < abs(wantedSize - selectedSize) {
                selectedURL = fileURL
                selectedSize = size
            }
        }

        // X Small Size
        if let fileURL = image.xsmallRes?.url as? URL {
            // Max dimension of this image
            let size = max(image.xsmallRes?.width ?? 1, image.xsmallRes?.height ?? 1)
            // Ensure that at least an URL will be returned
            if selectedURL == nil {
                selectedURL = fileURL
                selectedSize = size
            }
            // Is this resolution more appropriate?
            if size < wantedSize, abs(wantedSize - size) < abs(wantedSize - selectedSize) {
                selectedURL = fileURL
                selectedSize = size
            }
        }

        // Small Size
        if let fileURL = image.smallRes?.url as? URL {
            // Max dimension of this image
            let size = max(image.smallRes?.width ?? 1, image.smallRes?.height ?? 1)
            // Ensure that at least an URL will be returned
            if selectedURL == nil {
                selectedURL = fileURL
                selectedSize = size
            }
            // Is this resolution more appropriate?
            if size < wantedSize, abs(wantedSize - size) < abs(wantedSize - selectedSize) {
                selectedURL = fileURL
                selectedSize = size
            }
        }

        // Medium Size (should always be available)
        if let fileURL = image.mediumRes?.url as? URL {
            // Max dimension of this image
            let size = max(image.mediumRes?.width ?? 1, image.mediumRes?.height ?? 1)
            // Ensure that at least an URL will be returned
            if selectedURL == nil {
                selectedURL = fileURL
                selectedSize = size
            }
            // Is this resolution more appropriate?
            if size < wantedSize, abs(wantedSize - size) < abs(wantedSize - selectedSize) {
                selectedURL = fileURL
                selectedSize = size
            }
        }

        // Large Size
        if let fileURL = image.largeRes?.url as? URL {
            // Max dimension of this image
            let size = max(image.largeRes?.width ?? 1, image.largeRes?.height ?? 1)
            // Ensure that at least an URL will be returned
            if selectedURL == nil {
                selectedURL = fileURL
                selectedSize = size
            }
            // Is this resolution more appropriate?
            if size < wantedSize, abs(wantedSize - size) < abs(wantedSize - selectedSize) {
                selectedURL = fileURL
                selectedSize = size
            }
        }

        // X Large Size
        if let fileURL = image.xlargeRes?.url as? URL {
            // Max dimension of this image
            let size = max(image.xlargeRes?.width ?? 1, image.xlargeRes?.height ?? 1)
            // Ensure that at least an URL will be returned
            if selectedURL == nil {
                selectedURL = fileURL
                selectedSize = size
            }
            // Is this resolution more appropriate?
            if size < wantedSize, abs(wantedSize - size) < abs(wantedSize - selectedSize) {
                selectedURL = fileURL
                selectedSize = size
            }
        }

        // XX Large Size
        if let fileURL = image.xxlargeRes?.url as? URL {
            // Max dimension of this image
            let size = max(image.xxlargeRes?.width ?? 1, image.xxlargeRes?.height ?? 1)
            // Ensure that at least an URL will be returned
            if selectedURL == nil {
                selectedURL = fileURL
                selectedSize = size
            }
            // Is this resolution more appropriate?
            if size < wantedSize, abs(wantedSize - size) < abs(wantedSize - selectedSize) {
                selectedURL = fileURL
                selectedSize = size
            }
        }

        // Full Resolution
        if let fileURL = image.fullRes?.url as? URL {
            // Max dimension of this image
            let size = max(image.fullRes?.width ?? 1, image.fullRes?.height ?? 1)
            // Ensure that at least an URL will be returned
            if selectedURL == nil {
                selectedURL = fileURL
                selectedSize = size
            }
            // Is this resolution more appropriate?
            if size < wantedSize, abs(wantedSize - size) < abs(wantedSize - selectedSize) {
                selectedURL = fileURL
                selectedSize = size
            }
        }

        // NOP if no image can be downloaded
        if let fileURL = selectedURL {
            return URLRequest(url: fileURL)
        }
        return nil
    }
    
    
    // URL of the image file stored in /tmp before the share
    class func getFileUrl(ofImage image: Image?,
                          withURLrequest urlRequest: URLRequest?) -> URL {
        // Get filename from URL request
        var fileName = urlRequest?.url?.lastPathComponent

        // Is filename of original image a PHP request?
        if fileName?.contains(".php") ?? false {
            // The URL does not contain a file name but a PHP request
            // Sometimes happening with full resolution images, try with medium resolution file
            fileName = image?.mediumRes?.url?.lastPathComponent
            
            // Is filename of medium size image still a PHP request?
            if fileName?.contains(".php") ?? false {
                // The URL does not contain a unique file name but a PHP request
                // Try using the filename stored in Piwigo image data
                if image?.fileName.isEmpty == false {
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
    class func downloadImage(with imageData: Image, at urlRequest: URLRequest,
                             onProgress progress: @escaping (Progress?) -> Void,
                             completionHandler: @escaping (_ response: URLResponse?, _ filePath: URL?, _ error: Error?) -> Void
                             ) -> URLSessionDownloadTask? {
        // Download and save image in /tmp directory
        guard let manager = NetworkVarsObjc.imagesSessionManager else { return nil}
        let task = manager.downloadTask(
            with: urlRequest,
            progress: progress,
            destination: { targetPath, response in
                return self.getFileUrl(ofImage: imageData, withURLrequest: urlRequest)
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
