//
//  ShareUtilities.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 07/01/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation

class ShareUtilities {
    
    class func urlRequest(forImage image: PiwigoImageData,
                          withMnimumSize minSize: CGFloat) -> URLRequest? {

        // Download image of optimum size (depends on availability)
        // Note: image.width and .height are always > 1
        var anURLRequest = ""
        var scaleFactor = CGFloat.greatestFiniteMagnitude
        if let thumbPath = image.thumbPath {
            // Path should always be provided (thumbnail size)
            anURLRequest = thumbPath
            scaleFactor = minSize / CGFloat(min(image.xxSmallWidth, image.xxSmallHeight))
        }
        if let xxSmallPath = image.xxSmallPath, scaleFactor > 1.0 {
            anURLRequest = xxSmallPath
            scaleFactor = minSize / CGFloat(min(image.xxSmallWidth, image.xxSmallHeight))
        }
        if let xSmallPath = image.xSmallPath, scaleFactor > 1.0 {
            anURLRequest = xSmallPath
            scaleFactor = minSize / CGFloat(min(image.xSmallWidth, image.xSmallHeight))
        }
        if let smallPath = image.smallPath, scaleFactor > 1.0 {
            anURLRequest = smallPath
            scaleFactor = minSize / CGFloat(min(image.smallWidth, image.smallHeight))
        }
        if let mediumPath = image.mediumPath, scaleFactor > 1.0 {
            // Path should always be provided (medium size)
            anURLRequest = mediumPath
            scaleFactor = minSize / CGFloat(min(image.mediumWidth, image.mediumHeight))
        }
        if let largePath = image.largePath, scaleFactor > 1.0 {
            anURLRequest = largePath
            scaleFactor = minSize / CGFloat(min(image.largeWidth, image.largeHeight))
        }
        if let xLargePath = image.xLargePath, scaleFactor > 1.0 {
            anURLRequest = xLargePath
            scaleFactor = minSize / CGFloat(min(image.xLargeWidth, image.xLargeHeight))
        }
        if let xxLargePath = image.xxLargePath, scaleFactor > 1.0 {
            anURLRequest = xxLargePath
            scaleFactor = minSize / CGFloat(min(image.xxLargeWidth, image.xxLargeHeight))
        }
        if let fullResPath = image.fullResPath, (scaleFactor > 1.0) || (anURLRequest.count == 0) {
            anURLRequest = fullResPath
        }

        // NOP if image cannot be downloaded
        if anURLRequest.count == 0 {
            return nil
        }

        if let url = URL(string: anURLRequest) {
            return URLRequest(url: url)
        }
        return nil
    }
    
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

    class func downloadImage(with piwigoData: PiwigoImageData, and urlRequest: URLRequest,
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

extension UIActivity.ActivityType: Comparable {
    public static func < (lhs: UIActivity.ActivityType, rhs: UIActivity.ActivityType) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
