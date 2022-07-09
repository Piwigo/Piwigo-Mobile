//
//  PasteboardObject.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 20/02/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Photos
import Foundation
import piwigoKit

// This enum contains all the possible states of a pasteboard object
enum PasteboardObjectState {
    case new, stored, ready, failed
}

class PasteboardObject {
    let types: [String]
    var md5Sum: String
    var identifier: String
    var state = PasteboardObjectState.new
    var image: UIImage! = UIImage(named: "placeholder")!
    
    init(identifier: String, types: [String]) {
        self.md5Sum = ""
        self.identifier = identifier
        self.types = types
    }
}

class PendingOperations {
    lazy var preparationsInProgress: [IndexPath: Operation] = [:]
    lazy var preparationQueue: OperationQueue = {
        var queue = OperationQueue()
        queue.name = "Preparation queue"
        queue.maxConcurrentOperationCount = .max
        queue.qualityOfService = .userInteractive
        return queue
    }()
}

class ObjectPreparation : Operation {
    let pbObject: PasteboardObject
    let index: Int

    init(_ pbObject: PasteboardObject, at index:Int) {
        self.pbObject = pbObject
        self.index = index
    }
    
    override func main () {
        // Operation cancelled?
        if isCancelled { return }
      
        // Object already stored?
        guard pbObject.state == .new else {
            return
        }
        
        // Task depends on data type
        if pbObject.identifier.contains("mov") {
            // Get movie data and file extension
            guard let (movieData, fileExt) = self.getDataOfPasteboardMovie(at: index) else {
                pbObject.state = .failed
                return
            }
            
            // Update object
            pbObject.md5Sum = movieData.MD5checksum()
            pbObject.identifier.append(".\(fileExt)")

            // Store movie data
            storePasteboardObject(movieData)
        }
        else {
            // Get image data and file extension
            guard let (imageData, fileExt) = self.getDataOfPasteboardImage(at: index) else {
                pbObject.state = .failed
                return
            }

            // Update object
            pbObject.md5Sum = imageData.MD5checksum()
            pbObject.identifier.append(".\(fileExt)")

            // Store image data
            storePasteboardObject(imageData)
        }
    }


    /// https://developer.apple.com/documentation/uniformtypeidentifiers/uttype/system_declared_types
    private func getDataOfPasteboardMovie(at index:Int) -> (movieData: Data, fileExt: String)? {
        // IndexSet of current image
        let indexSet = IndexSet(integer: index)
        // Movie type?
        if pbObject.types.contains("com.apple.quicktime-movie"),
               let imageData = UIPasteboard.general.data(forPasteboardType: "com.apple.quicktime-movie", inItemSet: indexSet)?.first {
            return (imageData, "mov")
        }
        else if pbObject.types.contains("public.mpeg"),
               let imageData = UIPasteboard.general.data(forPasteboardType: "public.mpeg", inItemSet: indexSet)?.first {
            return (imageData, "mpeg")
        }
        else if pbObject.types.contains("public.mpeg-2-video"),
               let imageData = UIPasteboard.general.data(forPasteboardType: "public.mpeg-2-video", inItemSet: indexSet)?.first {
            return (imageData, "mpeg2")
        }
        else if pbObject.types.contains("public.mpeg-4"),
               let imageData = UIPasteboard.general.data(forPasteboardType: "public.mpeg-4", inItemSet: indexSet)?.first {
            return (imageData, "mp4")
        }
        else if pbObject.types.contains("public.avi"),
               let imageData = UIPasteboard.general.data(forPasteboardType: "public.avi", inItemSet: indexSet)?.first {
            return (imageData, "avi")
        }
        else {
            // Unknown movie format
            return nil
        }
    }

    private func getDataOfPasteboardImage(at index:Int) -> (imageData: Data, fileExt: String)? {
        // IndexSet of current image
        let indexSet = IndexSet(integer: index)

        // Image type?
        // PNG format in priority in case where JPEG is also available
        if pbObject.types.contains("public.png"),
           let imageData = UIPasteboard.general.data(forPasteboardType: "public.png", inItemSet: indexSet)?.first {
            return (imageData, "png")
        }
        else if pbObject.types.contains("public.heic"),
               let imageData = UIPasteboard.general.data(forPasteboardType: "public.heic", inItemSet: indexSet)?.first {
            return (imageData, "heic")
        }
        else if pbObject.types.contains("public.heif"),
               let imageData = UIPasteboard.general.data(forPasteboardType: "public.heif", inItemSet: indexSet)?.first {
            return (imageData, "heif")
        }
        else if pbObject.types.contains("public.tiff"),
               let imageData = UIPasteboard.general.data(forPasteboardType: "public.tiff", inItemSet: indexSet)?.first {
            return (imageData, "tiff")
        }
        else if pbObject.types.contains("public.jpeg"),
            let imageData = UIPasteboard.general.data(forPasteboardType: "public.jpeg", inItemSet: indexSet)?.first {
            return (imageData, "jpg")
        }
        else if pbObject.types.contains("public.camera-raw-image"),
            let imageData = UIPasteboard.general.data(forPasteboardType: "public.camera-raw-image", inItemSet: indexSet)?.first {
            return (imageData, "raw")
        }
        else if pbObject.types.contains("com.google.webp"),
               let imageData = UIPasteboard.general.data(forPasteboardType: "com.google.webp", inItemSet: indexSet)?.first {
            return (imageData, "webp")
        }
        else if pbObject.types.contains("com.compuserve.gif"),
               let imageData = UIPasteboard.general.data(forPasteboardType: "com.compuserve.gif", inItemSet: indexSet)?.first {
            return (imageData, "gif")
        }
        else if pbObject.types.contains("com.microsoft.bmp"),
               let imageData = UIPasteboard.general.data(forPasteboardType: "com.microsoft.bmp", inItemSet: indexSet)?.first {
            return (imageData, "bmp")
        }
        else if pbObject.types.contains("com.microsoft.ico"),
               let imageData = UIPasteboard.general.data(forPasteboardType: "com.microsoft.ico", inItemSet: indexSet)?.first {
            return (imageData, "ico")
        }
        else {
            // Unknown image format
            return nil
        }
    }

    private func storePasteboardObject(_ data: Data) -> Void {
        // For debugging purposes
        let start = CFAbsoluteTimeGetCurrent()

        // Set file URL
        let fileURL = UploadManager.shared.applicationUploadsDirectory
            .appendingPathComponent(pbObject.identifier)

        // Delete file if it already exists (incomplete previous attempt?)
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch {
        }

        // Store pasteboard image/video data into Piwigo/Uploads directory
        do {
            try data.write(to: fileURL)
            pbObject.state = .stored
            if pbObject.identifier.contains("mov") {
                pbObject.image = AVURLAsset(url: fileURL)
                    .extractedImage()
                    .crop(width: 1.0, height: 1.0)?
                    .resize(to: CGFloat(AlbumUtilities.kThumbnailFileSize) * UIScreen.main.scale, opaque: true)
            } else {
                pbObject.image = (UIImage(data: data) ?? UIImage(named: "placeholder")!)
                    .fixOrientation()
                    .crop(width: 1.0, height: 1.0)?
                    .resize(to: CGFloat(AlbumUtilities.kThumbnailFileSize) * UIScreen.main.scale, opaque: true)
            }
        }
        catch let error as NSError {
            // Disk full?
            print("could not save image file: \(error)")
            pbObject.state = .failed
        }
        
        let diff = (CFAbsoluteTimeGetCurrent() - start)*1000
        print("   did try to write clipboard object at index \(index) on disk in \(diff) ms")
    }
}
