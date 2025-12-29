//
//  UploadUtilities.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 19/06/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation
import MobileCoreServices
import Photos
import piwigoKit

extension UploadManager {
    
    // MARK: - Upload File Utilities
    // Returns the original filename or a name based on a date
    func getFilename(fromName originalFilename: String, ofAsset originalAsset: PHAsset) -> String {
        // Piwigo 2.10.2 supports the 3-byte UTF-8, not the standard UTF-8 (4 bytes)
        var utf8mb3Filename = originalFilename.utf8mb3Encoded
        
        // Snapchat creates filenames containning ":" characters,
        // which prevents the app from storing the converted file
        if #available(iOS 16.0, *) {
            utf8mb3Filename = utf8mb3Filename.replacing(":", with: "")
        } else {
            // Fallback on earlier versions
            utf8mb3Filename = utf8mb3Filename.replacingOccurrences(of: ":", with: "")
        }
        
        // If filename is empty, create one from the current date
        if utf8mb3Filename.isEmpty {
            // No filename => Build filename from creation date
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd-HHmmssSSSS"
            if let creation = originalAsset.creationDate {
                utf8mb3Filename = dateFormatter.string(from: creation)
            } else {
                utf8mb3Filename = dateFormatter.string(from: Date())
            }
            
            // Filename extension required by Piwigo so that it knows how to deal with it
            if originalAsset.mediaType == .image {
                // Adopt JPEG photo format by default, will be rechecked
                utf8mb3Filename = URL(fileURLWithPath: utf8mb3Filename).appendingPathExtension("jpg").lastPathComponent
            } else if originalAsset.mediaType == .video {
                // Videos are exported in MP4 format
                utf8mb3Filename = URL(fileURLWithPath: utf8mb3Filename).appendingPathExtension("mp4").lastPathComponent
            } else if originalAsset.mediaType == .audio {
                // Arbitrary extension, not managed yet
                utf8mb3Filename = URL(fileURLWithPath: utf8mb3Filename).appendingPathExtension("m4a").lastPathComponent
            }
        }
        
        return utf8mb3Filename
    }

    // Returns the URL of final upload file to be stored into Piwigo/Uploads directory
    // and delete existing file if demanded (case of a failed previous attempt)
    public func getUploadFileURL(from upload: Upload, withSuffix suffix: String = "",
                                  deleted deleteIt: Bool = false) -> URL {
        // File name of image data to be stored into Piwigo/Uploads directory
        var fileName = ""
        if #available(iOS 16.0, *) {
            fileName = upload.localIdentifier.replacing("/", with: "-")
        } else {
            // Fallback on earlier versions
            fileName = upload.localIdentifier.replacingOccurrences(of: "/", with: "-")
        }
        if fileName.isEmpty {
            fileName = "file-".appending(String(Int64(upload.creationDate)))
        }
        fileName.append(suffix)
        let fileURL = DataDirectories.appUploadsDirectory.appendingPathComponent(fileName)
        
        // Should we delete it?
        if deleteIt {
            // Deletes temporary image file if it exists (incomplete previous attempt?)
            try? FileManager.default.removeItem(at: fileURL)
        }
        
        return fileURL
    }
    
    /// - Rename Upload file if needed
    /// - Get MD5 checksum and MIME type
    /// - Update upload session counter
    /// -> return updated upload properties w/ or w/o error
    public func finalizeImageFile(atURL originalFileURL: URL, with upload: Upload) throws(PwgKitError) {

        // File name of image data to be stored into Piwigo/Uploads directory
        let fileURL = getUploadFileURL(from: upload)
        
        // Should we rename the file to adopt the Upload Manager convention?
        if originalFileURL != fileURL {
            // Deletes temporary Upload file if it exists (incomplete previous attempt?)
            try? FileManager.default.removeItem(at: fileURL)

            // Adopts Upload filename convention (e.g. removes the "-original" suffix)
            do {
                try FileManager.default.moveItem(at: originalFileURL, to: fileURL)
            }
            catch let error as CocoaError {
                // Update upload request state
                throw .fileOperationFailed(innerError: error)
            }
            catch {
                throw .otherError(innerError: error)
            }
        }
        
        // Set creation date as the photo creation date
        let creationDate = NSDate(timeIntervalSinceReferenceDate: upload.creationDate)
        let attrs = [FileAttributeKey.creationDate     : creationDate,
                     FileAttributeKey.modificationDate : creationDate]
        try? FileManager.default.setAttributes(attrs, ofItemAtPath: fileURL.path)
        
        // Determine MD5 checksum of image file to upload
        upload.md5Sum = try fileURL.MD5checksum()
        
        // Get MIME type from file extension
        let fileExt = (URL(fileURLWithPath: upload.fileName).pathExtension).lowercased()
        guard let uti = UTType(filenameExtension: fileExt),
              let mimeType = uti.preferredMIMEType
        else {
            throw .missingAsset
        }
        upload.mimeType = mimeType

        // Done -> append file size to counter
        countOfBytesPrepared += UInt64(fileURL.fileSize)
    }

    /// - Delete Upload files w/ or w/o prefix
    public func deleteFilesInUploadsDirectory(withPrefix prefix: String = "", completion: (() -> Void)? = nil) {
        let fileManager = FileManager.default
        do {
            // Get list of files
            let uploadsDirectory = DataDirectories.appUploadsDirectory
            var filesToDelete = try fileManager.contentsOfDirectory(at: uploadsDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
            if prefix.isEmpty == false {
                // Will delete files with given prefix only
                filesToDelete.removeAll(where: { !$0.lastPathComponent.hasPrefix(prefix) })
            }

            // Delete files
            for file in filesToDelete {
                try fileManager.removeItem(at: file)
            }
            
            // Release memory
            filesToDelete.removeAll()
            
            // For debugging
//            let leftFiles = try fileManager.contentsOfDirectory(at: uploadsDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
//            debugPrint("\(dbg()) Remaining files in cache: \(leftFiles)")
        } catch {
            UploadManager.logger.notice("Could not clear the Uploads folder: \(error)")
        }

        // Job done
        if let completion = completion {
            completion()
        }
    }
}
