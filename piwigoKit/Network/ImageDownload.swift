//
//  ImageDownload.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 22/01/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit

public enum pwgImageType {
    case album, image
}

extension pwgImageType {
    public var placeHolder: UIImage {
        switch self {
        case .album:
            return UIImage(named: "unknownAlbum")!
        case .image:
            return UIImage(named: "unknownImage")!
        }
    }
}

class ImageDownload {
    
    // MARK: - Variables and Properties
    var imageURL: URL!
    var fileSize: Int64
    var fileURL: URL!
    var placeHolder: UIImage!
    var progressHandler: ((Float) -> Void)?
    var completionHandler: ((URL) -> Void)!
    var failureHandler: ((Error) -> Void)!
    var task: URLSessionDownloadTask?
    var resumeData: Data?
    var progress = Float.zero
    
    
    // MARK: - Initialization
    init(type: pwgImageType, atURL imageURL: URL, fileSize: Int64 = .zero, toCacheAt fileURL: URL,
         progress: ((Float) -> Void)? = nil, completion: @escaping (URL) -> Void, failure: @escaping (Error) -> Void) {
        
        // Store place holder according to image type
        self.placeHolder = type.placeHolder
        
        // Store file size
        self.imageURL = imageURL
        self.fileSize = fileSize
        self.fileURL = fileURL
        
        // Store handlers
        self.progressHandler = progress
        self.completionHandler = completion
        self.failureHandler = failure
    }
    
    deinit {
//        debugPrint("••> release ImageDownload of image \(self.fileURL.lastPathComponent)")
        self.task?.cancel()
    }
}

// MARK: - Image Cached File URL and Thumbnail
extension Image
{
    public func cacheURL(ofSize size: pwgImageSize) -> URL? {
        // Retrieve server ID
        let serverID = self.server?.uuid ?? ""
        if serverID.isEmpty { return nil }
        
        // Return the URL of the thumbnail file
        let cacheDir = DataDirectories.shared.cacheDirectory.appendingPathComponent(serverID)
        return cacheDir.appendingPathComponent(size.path)
            .appendingPathComponent(String(self.pwgID))
    }
    
    public func cachedThumbnail(ofSize size: pwgImageSize) -> UIImage? {
        autoreleasepool {
            guard let fileURL = self.cacheURL(ofSize: size),
                  let image = UIImage(contentsOfFile: fileURL.path)
            else { return nil }
            return image
        }
    }
}
