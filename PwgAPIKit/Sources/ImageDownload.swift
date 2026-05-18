//
//  ImageDownload.swift
//  PwgAPIKit
//
//  Created by Eddy Lelièvre-Berna on 22/01/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import PwgKit

final class ImageDownload {
    
    // MARK: - Variables and Properties
    let imageURL: URL!
    let fileSize: Int64
    let fileURL: URL!
    let placeHolder: UIImage!
    var task: URLSessionDownloadTask?
    var resumeData: Data?
    var progress = Float.zero
    var progressHandler: ((Float) -> Void)?
    var failureHandler: ((PwgKitError) -> Void)!
    var completionHandler: ((URL) -> Void)!

    
    // MARK: - Initialization
    init(type: pwgImageType, atURL imageURL: URL, fileSize: Int64 = .zero, toCacheAt fileURL: URL,
         progress: ((Float) -> Void)? = nil, completion: @escaping (URL) -> Void, failure: @escaping (PwgKitError) -> Void) {
        
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
