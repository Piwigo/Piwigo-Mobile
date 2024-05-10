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
    /// - Get URL of final upload file to be stored into Piwigo/Uploads directory
    /// - Delete existing file if demanded (failed previous attempt?)
    public func getUploadFileURL(from upload: Upload, withSuffix suffix: String = "",
                                  deleted deleteIt: Bool = false) -> URL {
        // File name of image data to be stored into Piwigo/Uploads directory
        var fileName = upload.localIdentifier.replacingOccurrences(of: "/", with: "-")
        if fileName.isEmpty {
            fileName = "file-".appending(String(Int64(upload.creationDate)))
        }
        fileName.append(suffix)
        let fileURL = uploadsDirectory.appendingPathComponent(fileName)
        
        // Should we delete it?
        if deleteIt {
            // Deletes temporary image file if it exists (incomplete previous attempt?)
            do { try FileManager.default.removeItem(at: fileURL) } catch { }
        }
        
        return fileURL
    }

    /// - Rename Upload file if needed
    /// - Get MD5 checksum and MIME type
    /// - Update upload session counter
    /// -> return updated upload properties w/ or w/o error
    public func finalizeImageFile(atURL originalFileURL: URL, with upload: Upload,
                                  completion: @escaping () -> Void,
                                  failure: @escaping (Error?) -> Void) {

        // File name of image data to be stored into Piwigo/Uploads directory
        let fileURL = getUploadFileURL(from: upload)

        // Should we rename the file to adopt the Upload Manager convention?
        if originalFileURL != fileURL {
            // Deletes temporary Upload file if it exists (incomplete previous attempt?)
            do { try FileManager.default.removeItem(at: fileURL) } catch { }

            // Adopts Upload filename convention (e.g. removes the "-original" suffix)
            do {
                try FileManager.default.moveItem(at: originalFileURL, to: fileURL)
            }
            catch {
                // Update upload request
                failure(error)
            }
        }
        
        // Set creation date as the photo creation date
        let creationDate = NSDate(timeIntervalSinceReferenceDate: upload.creationDate)
        let attrs = [FileAttributeKey.creationDate     : creationDate,
                     FileAttributeKey.modificationDate : creationDate]
        do { try FileManager.default.setAttributes(attrs, ofItemAtPath: fileURL.path) } catch { }
        
        // Determine MD5 checksum of image file to upload
        let error: NSError?
        (upload.md5Sum, error) = fileURL.MD5checksum()
        print("\(dbg()) MD5: \(String(describing: upload.md5Sum))")
        if error != nil {
            // Could not determine the MD5 checksum
            failure(error)
            return
        }

        // Get MIME type from file extension
        let fileExt = (URL(fileURLWithPath: upload.fileName).pathExtension).lowercased()
        if #available(iOS 14, *) {
            guard let uti = UTType(filenameExtension: fileExt),
                  let mimeType = uti.preferredMIMEType
            else {
                let error = NSError(domain: "Piwigo", code: 0, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                failure(error)
                return
            }
            upload.mimeType = mimeType
        } else {
            // Fallback on previous version
            guard let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, fileExt as NSString, nil)?.takeRetainedValue(),
                  let mimeType = (UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType)?.takeRetainedValue()) as String?
            else {
                let error = NSError(domain: "Piwigo", code: 0, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                failure(error)
                return
            }
            upload.mimeType = mimeType
        }

        // Done -> append file size to counter
        countOfBytesPrepared += UInt64(fileURL.fileSize)
        completion()
    }

    /// - Delete Upload files w/ or w/o prefix
    public func deleteFilesInUploadsDirectory(withPrefix prefix: String = "", completion: (() -> Void)? = nil) {
        let fileManager = FileManager.default
        do {
            // Get list of files
            var filesToDelete = try fileManager.contentsOfDirectory(at: self.uploadsDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
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
//            let leftFiles = try fileManager.contentsOfDirectory(at: self.uploadsDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
//            print("\(dbg()) Remaining files in cache: \(leftFiles)")
        } catch {
            print("\(dbg()) could not clear the Uploads folder: \(error)")
        }

        // Job done
        if let completion = completion {
            completion()
        }
    }
    
    public func getUploadsDirectorySize() -> String {
        return ByteCountFormatter.string(fromByteCount: Int64(uploadsDirectory.folderSize), countStyle: .file)
    }
    
    
    // MARK: - Debug Utilities
    public func dbg() -> String  {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "'••> 'dd'@'HH:mm:ss |"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: Date())
    }
}

// MARK: - For checking operation queue
/// The name/description of the current queue (Operation or Dispatch), if that can be found. Else, the name/description of the thread.
public func queueName() -> String {
    if let currentOperationQueue = OperationQueue.current {
        if let currentDispatchQueue = currentOperationQueue.underlyingQueue {
            return "dispatch queue: \(currentDispatchQueue.label.nonEmpty ?? currentDispatchQueue.description)"
        }
        else {
            return "operation queue: \(currentOperationQueue.name?.nonEmpty ?? currentOperationQueue.description)"
        }
    }
    else {
        let currentThread = Thread.current
        return "thread: \(currentThread.name?.nonEmpty ?? currentThread.description)"
    }
}

public extension String {
    /// Returns this string if it is not empty, else `nil`.
    var nonEmpty: String? {
        if self.isEmpty {
            return nil
        }
        else {
            return self
        }
    }
}

