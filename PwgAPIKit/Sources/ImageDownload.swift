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
    ///
    /// They are keyed by requester: a view which requests the same image again — as a collection
    /// view does when it reconfigures its cells while the download is still pending — replaces
    /// its own handlers instead of adding another set. Without this, the image was decoded and
    /// delivered once per request, i.e. up to eleven times during an upload of 36 files.
    /// Requests made without a requester keep their own key, so none of them is ever discarded.
    enum RequesterKey: Hashable {
        case view(ObjectIdentifier)
        case anonymous(UUID)
    }
    
    private struct Handlers {
        let progress: ((Float) -> Void)?
        let completion: ((URL) -> Void)?
        let failure: ((PwgKitError) -> Void)?
    }
    
    private var handlers: [RequesterKey : Handlers] = [:]
    
    var requesterCount: Int { handlers.count }
    var progressHandlers: [(Float) -> Void] { handlers.values.compactMap(\.progress) }
    var failureHandlers: [(PwgKitError) -> Void] { handlers.values.compactMap(\.failure) }
    var completionHandlers: [(URL) -> Void] { handlers.values.compactMap(\.completion) }


    // MARK: - Initialization
    init(type: pwgImageType, atURL imageURL: URL, fileSize: Int64 = .zero, toCacheAt fileURL: URL,
         requestedBy requester: ObjectIdentifier? = nil,
         progress: ((Float) -> Void)? = nil, completion: ((URL) -> Void)? = nil, failure: ((PwgKitError) -> Void)? = nil) {

        // Store place holder according to image type
        self.placeHolder = type.placeHolder
        
        // Store file size
        self.imageURL = imageURL
        self.fileSize = fileSize
        self.fileURL = fileURL
        
        // Store handlers of the view requesting this image
        addHandlers(requestedBy: requester, progress: progress, completion: completion, failure: failure)
    }


    // MARK: - Handlers
    // Adds the handlers of another view requesting this image,
    // or replaces those which this view provided for a previous request.
    func addHandlers(requestedBy requester: ObjectIdentifier?,
                     progress: ((Float) -> Void)?, completion: ((URL) -> Void)?, failure: ((PwgKitError) -> Void)?) {
        // Anything to store?
        if progress == nil, completion == nil, failure == nil { return }
        
        // Store the handlers under the key of the view, if it provided one
        let key: RequesterKey = requester.map({ .view($0) }) ?? .anonymous(UUID())
        handlers[key] = Handlers(progress: progress, completion: completion, failure: failure)
    }
    
    deinit {
//        debugPrint("••> release ImageDownload of image \(self.fileURL.lastPathComponent)")
        self.task?.cancel()
    }
}
