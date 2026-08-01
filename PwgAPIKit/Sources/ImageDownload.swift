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

final class ImageDownload: @unchecked Sendable {
    
    // MARK: - Variables and Properties
    let imageURL: URL!
    let fileSize: Int64
    let fileURL: URL!
    let placeHolder: UIImage!
    var task: URLSessionDownloadTask?
    var isCancelled: Bool = false
    var resumeData: Data?
    var progress = Float.zero

    /// The same image can be requested by several views at the same time, e.g. by an album cell
    /// and by an image cell when album and image thumbnails have the same size.
    /// The handlers of all of them are stored so that no view is left waiting for the image.
    private(set) var progressHandlers: [(Float) -> Void] = []
    private(set) var failureHandlers: [(PwgKitError) -> Void] = []
    private(set) var completionHandlers: [(URL) -> Void] = []


    // MARK: - Initialization
    init(type: pwgImageType, atURL imageURL: URL, fileSize: Int64 = .zero, toCacheAt fileURL: URL,
         progress: ((Float) -> Void)? = nil, completion: ((URL) -> Void)? = nil, failure: ((PwgKitError) -> Void)? = nil) {

        // Store place holder according to image type
        self.placeHolder = type.placeHolder
        
        // Store file size
        self.imageURL = imageURL
        self.fileSize = fileSize
        self.fileURL = fileURL
        
        // Store handlers of the view requesting this image
        addHandlers(progress: progress, completion: completion, failure: failure)
    }


    // MARK: - Handlers
    // Adds the handlers of another view requesting this image
    func addHandlers(progress: ((Float) -> Void)?, completion: ((URL) -> Void)?, failure: ((PwgKitError) -> Void)?) {
        if let progress {
            progressHandlers.append(progress)
        }
        if let completion {
            completionHandlers.append(completion)
        }
        if let failure {
            failureHandlers.append(failure)
        }
    }
    
    deinit {
//        debugPrint("••> release ImageDownload of image \(self.fileURL.lastPathComponent)")
        self.task?.cancel()
    }
}
