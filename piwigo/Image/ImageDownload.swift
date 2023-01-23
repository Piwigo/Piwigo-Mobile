//
//  ImageDownload.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 22/01/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit

class ImageDownload {
    
    // MARK: - Variables and Properties
    var imageURL: URL!
    var fileSize: Int64
    var fileURL: URL!
    var placeHolder: UIImage!
    var progressHandler: ((Float) -> Void)?
    var completionHandler: ((UIImage) -> Void)!
    var failureHandler: ((Error) -> Void)?
    var task: URLSessionDownloadTask?
    
    
    // MARK: - Initialization
    init(imageID: Int64, ofSize imageSize: pwgImageSize, atURL imageURL: URL,
         fromServer serverID: String, fileSize: Int64 = NSURLSessionTransferSizeUnknown,
         placeHolder: UIImage, progress: ((Float) -> Void)? = nil,
         completion: @escaping (UIImage) -> Void, failure: ((Error) -> Void)? = nil) {
        
        // Set URLs of image in cache
        let cacheDir = DataController.cacheDirectory.appendingPathComponent(serverID)
        self.fileURL = cacheDir.appendingPathComponent(imageSize.path)
            .appendingPathComponent(String(imageID))
        
        // Store file size and handlers
        self.imageURL = imageURL
        self.fileSize = fileSize == Int64.zero ? NSURLSessionTransferSizeUnknown : fileSize
        self.placeHolder = placeHolder
        self.progressHandler = progress
        self.completionHandler = completion
        self.failureHandler = failure
    }
    
    deinit {
        self.task?.cancel()
    }
    
    
    // MARK: - Get Image from Cache or Download it
    func getImage() {
        // Do we already have this image in cache?
        if let cachedImage: UIImage = UIImage(contentsOfFile: self.fileURL.path),
           let cgImage = cachedImage.cgImage, cgImage.height * cgImage.bytesPerRow > 0,
           cachedImage != self.placeHolder {
            print("••> Image \(fileURL.lastPathComponent) retrieved from cache.")
            self.completionHandler(cachedImage)
            return
        }
        
        ImageSession.shared.startDownload(self)
    }
}
