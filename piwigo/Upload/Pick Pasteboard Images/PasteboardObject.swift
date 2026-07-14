//
//  PasteboardObject.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 20/02/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Photos
import Foundation
import UIKit
import PwgKit
import PwgCacheKit
import PwgUploadKit

// This enum contains all the possible states of a pasteboard object
enum PasteboardObjectState {
    case new, stored, ready, failed
}

final class PasteboardObject {
    let itemIndex: Int          // Index of the item in the pasteboard
    let types: [String]
    var md5Sum: String
    var identifier: String
    var fileName: String
    var state = PasteboardObjectState.new
    var image: UIImage = pwgImageType.image.placeHolder

    init(identifier: String, fileName: String, types: [String], itemIndex: Int) {
        self.itemIndex = itemIndex
        self.md5Sum = ""
        self.identifier = identifier
        self.fileName = fileName
        self.types = types
    }
}

final class PendingOperations {
    lazy var preparationsInProgress: [IndexPath: Operation] = [:]
    lazy var preparationQueue: OperationQueue = {
        var queue = OperationQueue()
        queue.name = "Preparation queue"
        queue.maxConcurrentOperationCount = .max
        queue.qualityOfService = .userInteractive
        return queue
    }()
}

final class ObjectPreparation : Operation, @unchecked Sendable {
    let pbObject: PasteboardObject
    let scale: CGFloat

    init(_ pbObject: PasteboardObject, scale: CGFloat) {
        self.pbObject = pbObject
        self.scale = scale
    }
    
    override func main () {
        // Operation cancelled?
        if isCancelled { return }
      
        // Object already stored?
        guard pbObject.state == .new else {
            return
        }
        
        // Task depends on data type
        if pbObject.identifier.contains(kMovieSuffix) {
            // Get movie data and file extension
            guard let (movieData, fileExt) = self.getDataOfPasteboardMovie(at: pbObject.itemIndex) else {
                pbObject.state = .failed
                return
            }
            
            // Update object
            pbObject.md5Sum = movieData.MD5checksum
            pbObject.fileName.append(".\(fileExt)")

            // Store movie data
            storePasteboardObject(movieData)
        }
        else {
            // Get image data and file extension
            guard let (imageData, fileExt) = self.getDataOfPasteboardImage(at: pbObject.itemIndex) else {
                pbObject.state = .failed
                return
            }

            // Update object
            pbObject.md5Sum = imageData.MD5checksum
            pbObject.fileName.append(".\(fileExt)")

            // Store image data
            storePasteboardObject(imageData)
        }
    }
    
    private func getDataOfPasteboardMovie(at index:Int) -> (movieData: Data, fileExt: String)? {
        let indexSet = IndexSet(integer: index)
        for movieType in acceptedMovieTypes {
            if pbObject.types.contains(movieType.identifier),
               let fileExt = movieType.preferredFilenameExtension,
               let movieData = UIPasteboard.general.data(forPasteboardType: movieType.identifier, inItemSet: indexSet)?.first {
                return (movieData, fileExt)
            }
        }
        return nil  // Unknown movie format
    }
    
    private func getDataOfPasteboardImage(at index:Int) -> (imageData: Data, fileExt: String)? {
        // PNG format in priority in case where JPEG is also available
        let indexSet = IndexSet(integer: index)
        for imageType in acceptedImageTypes {
            if pbObject.types.contains(imageType.identifier),
               let fileExt = imageType.preferredFilenameExtension,
               let imageData = UIPasteboard.general.data(forPasteboardType: imageType.identifier, inItemSet: indexSet)?.first {
                return (imageData, fileExt)
            }
        }
        return nil  // Unknown image format
    }
    
    private func storePasteboardObject(_ data: Data) -> Void {
        // For debugging purposes
//        let start = CFAbsoluteTimeGetCurrent()

        // Set file URL
        let fileURL = DataDirectories.appUploadsDirectory
            .appendingPathComponent(pbObject.identifier)

        // Delete file if it already exists (incomplete previous attempt?)
        try? FileManager.default.removeItem(at: fileURL)

        // Store pasteboard image/video data into Piwigo/Uploads directory
        do {
            try data.write(to: fileURL, options: .atomic)
            pbObject.state = .stored
            if pbObject.identifier.contains(kMovieSuffix) {
                pbObject.image = (AVURLAsset(url: fileURL)
                    .extractedImage()?
                    .crop(width: 1.0, height: 1.0) ?? pwgImageType.image.placeHolder)
                    .resize(to: AlbumVars.shared.kThumbnailFileSize, opaque: true, scale: scale)
            } else {
                pbObject.image = ((UIImage(data: data) ?? pwgImageType.image.placeHolder)
                    .fixOrientation()
                    .crop(width: 1.0, height: 1.0) ?? pwgImageType.image.placeHolder)
                    .resize(to: AlbumVars.shared.kThumbnailFileSize, opaque: true, scale: scale)
            }
        }
        catch let error {
            // Disk full?
            debugPrint("could not save image file: \(error.localizedDescription)")
            pbObject.state = .failed
        }
        
//        let diff = (CFAbsoluteTimeGetCurrent() - start)*1000
//        debugPrint("   did try to write clipboard object at index \(index) on disk in \(diff) ms")
    }
}
